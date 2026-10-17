# Reading ComplexHeatmap simple annotation tracks (#392)
#
# Each simple annotation track -- `HeatmapAnnotation(df = ...)`,
# `rowAnnotation(df = ...)`, `anno_simple()` -- is read as a layer of the
# heat map's subplot, after the `heat` layer: a continuous track as a 1-row
# `heat`, a discrete one as a `step` whose points carry the level as
# `label`. The tests check the reading against sources it does not compute:
# the annotation's own data frame, reordered by the column or row order of a
# separate draw, and the exported SVG, where every selector must name one
# cell painted the colour the track's own colour mapping gives its value.

skip_if_not_installed("ComplexHeatmap")

cha_matrix <- function() {
  set.seed(392)
  matrix(
    rnorm(30, sd = 2), 5, 6,
    dimnames = list(paste0("gene", 1:5), paste0("sample", 1:6))
  )
}

cha_columns <- function() {
  data.frame(
    group = c("ctrl", "ctrl", "trt", "trt", "trt", "ctrl"),
    dose = c(0.5, 1, NA, 2, 4.25, 8),
    stringsAsFactors = FALSE
  )
}

cha_drawn <- function(x) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  ComplexHeatmap::draw(x)
}

cha_orchestrator <- function(x) {
  get_global_registry()$get_adapter_for_plot(x)$create_orchestrator(x)
}

# The layers of the (first) heat map's subplot; the trees have their own.
cha_heat_subplot <- function(orchestrator) {
  subplots <- unlist(orchestrator$generate_maidr_data()$subplots, recursive = FALSE)
  heat <- Filter(function(s) length(s$layers) && identical(s$layers[[1]]$type, "heat"), subplots)
  heat[[1]]$layers
}

cha_layers <- function(x) {
  orchestrator <- cha_orchestrator(x)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  cha_heat_subplot(orchestrator)
}

cha_heat_values <- function(layer) {
  vapply(layer$data$points[[1]], function(v) if (is.null(v)) NA_real_ else v, numeric(1))
}

cha_step_field <- function(layer, field) {
  vapply(layer$data[[1]], function(p) {
    v <- p[[field]]
    if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
  }, character(1))
}

cha_order <- function(drawn) {
  list(
    rows = unlist(ComplexHeatmap::row_order(drawn), use.names = FALSE),
    cols = unlist(ComplexHeatmap::column_order(drawn), use.names = FALSE)
  )
}

test_that("column tracks are read exactly, in the drawn column order", {
  m <- cha_matrix()
  df <- cha_columns()
  ht <- ComplexHeatmap::Heatmap(
    m,
    top_annotation = ComplexHeatmap::HeatmapAnnotation(df = df),
    column_split = rep(c("x", "y"), each = 3)
  )
  layers <- cha_layers(ht)
  order <- cha_order(cha_drawn(ht))

  expect_length(layers, 3L)
  expect_identical(layers[[1]]$type, "heat")
  # Numbered after the heat and tree layers, uniquely.
  expect_false(anyDuplicated(vapply(layers, function(l) l$id, "")) > 0)

  group <- layers[[2]]
  expect_identical(group$type, "step")
  expect_identical(group$name, "group")
  expect_identical(group$axes$x$label, "Columns")
  expect_identical(group$axes$y$label, "group")
  expect_identical(cha_step_field(group, "x"), colnames(m)[order$cols])
  expect_identical(cha_step_field(group, "label"), df$group[order$cols])
  # The level's place among the colour mapping's levels.
  expect_identical(cha_step_field(group, "y"), as.character(match(df$group, c("ctrl", "trt"))[order$cols]))

  dose <- layers[[3]]
  expect_identical(dose$type, "heat")
  expect_identical(dose$name, "dose")
  expect_identical(dose$axes$z$label, "dose")
  expect_identical(unlist(dose$data$x), colnames(m)[order$cols])
  expect_identical(unlist(dose$data$y), "dose")
  expect_identical(cha_heat_values(dose), df$dose[order$cols])
  # The heat layer's columns, so a layer switch keeps the column.
  expect_identical(dose$data$x, layers[[1]]$data$x)
})

test_that("row tracks are read top first, beside and inside the heat map", {
  m <- cha_matrix()
  set.seed(7)
  htl <- cha_drawn(
    ComplexHeatmap::Heatmap(
      m,
      row_km = 2, row_title = "Genes",
      left_annotation = ComplexHeatmap::rowAnnotation(
        df = data.frame(kind = c("a", NA, "b", "a", "b"))
      )
    ) + ComplexHeatmap::rowAnnotation(score = c(5, 4, 3, 2, 1))
  )
  layers <- cha_layers(htl)
  order <- cha_order(htl)

  expect_identical(vapply(layers, function(l) l$type, ""), c("heat", "step", "heat"))
  kind <- layers[[2]]
  expect_identical(kind$axes$x$label, "Genes")
  expect_identical(cha_step_field(kind, "x"), rownames(m)[order$rows])
  expect_identical(cha_step_field(kind, "label"), c("a", NA, "b", "a", "b")[order$rows])
  # A missing level is a gap, without a label.
  expect_true(any(is.na(cha_step_field(kind, "y"))))

  score <- layers[[3]]
  expect_identical(score$name, "score")
  expect_identical(unlist(score$data$x), rownames(m)[order$rows])
  expect_identical(cha_heat_values(score), c(5, 4, 3, 2, 1)[order$rows])
})

test_that("anno_simple() is read, other annotations are drawn and named", {
  m <- cha_matrix()
  ha <- ComplexHeatmap::HeatmapAnnotation(
    simple = ComplexHeatmap::anno_simple(1:6),
    bars = ComplexHeatmap::anno_barplot(6:1),
    flag = c(TRUE, FALSE, TRUE, TRUE, FALSE, FALSE),
    level = 1:6,
    col = list(level = stats::setNames(grDevices::rainbow(6), 1:6))
  )
  ht <- ComplexHeatmap::Heatmap(m, top_annotation = ha, cluster_columns = FALSE)
  expect_message(
    layers <- cha_layers(ht),
    "'bars' is drawn but not read",
    class = "maidr_complexheatmap_annotation"
  )
  expect_identical(vapply(layers, function(l) l$name %||% "", ""), c("", "simple", "flag", "level"))
  expect_identical(cha_heat_values(layers[[2]]), as.double(1:6))
  expect_identical(cha_step_field(layers[[3]], "label"), c("TRUE", "FALSE", "TRUE", "TRUE", "FALSE", "FALSE"))
  # Numbers given discrete colours are levels.
  expect_identical(layers[[4]]$type, "step")
  expect_identical(cha_step_field(layers[[4]], "label"), as.character(1:6))
})

# Every cell a track's selectors name, in order, with the colour of the
# value read for it.
cha_selected_fills <- function(svg, layer) {
  if (identical(layer$type, "heat")) {
    expect_length(layer$selectors, 1L)
    nodes <- lapply(layer$selectors[[1]], function(selector) {
      id <- gsub("\\\\", "", sub("^#", "", selector))
      cell <- xml2::xml_find_all(svg, sprintf("//*[@id='%s']", id))
      expect_length(cell, 1L)
      cell
    })
  } else {
    expect_length(layer$selectors, 1L)
    parts <- strsplit(layer$selectors[[1]], ", ", fixed = TRUE)[[1]]
    nodes <- unlist(lapply(parts, function(part) {
      id <- gsub("\\\\", "", sub("^g#(.*) > rect$", "\\1", part))
      cells <- xml2::xml_find_all(
        svg, sprintf("//*[local-name()='g'][@id='%s']/*[local-name()='rect']", id)
      )
      lapply(seq_along(cells), function(i) cells[[i]])
    }), recursive = FALSE)
  }
  vapply(nodes, function(node) xml2::xml_attr(node, "fill"), character(1))
}

cha_rgb <- function(colours) {
  rgb <- grDevices::col2rgb(colours)
  sprintf("rgb(%d,%d,%d)", rgb[1, ], rgb[2, ], rgb[3, ])
}

expect_tracks_paint_values <- function(x) {
  orchestrator <- cha_orchestrator(x)
  svg <- xml2::read_xml(paste(build_interactive_svg(orchestrator), collapse = "\n"))
  layers <- cha_heat_subplot(orchestrator)[-1]
  drawn <- cha_drawn(x)
  heatmap <- drawn@ht_list[[1]]
  order <- cha_order(drawn)
  annotations <- c(
    heatmap@top_annotation@anno_list, heatmap@left_annotation@anno_list
  )
  expect_length(layers, length(annotations))
  for (layer in layers) {
    single <- annotations[[layer$name]]
    mapping <- single@color_mapping
    index <- if (identical(single@which, "column")) order$cols else order$rows
    value <- single@fun@var_env$value[index]
    expect_identical(
      cha_selected_fills(svg, layer),
      cha_rgb(ComplexHeatmap::map_to_colors(mapping, value))
    )
  }
}

test_that("each track's selectors name the cells drawn for it", {
  skip_if_not_installed("xml2")
  m <- cha_matrix()
  df <- cha_columns()
  annotated <- function(...) {
    ComplexHeatmap::Heatmap(
      m,
      top_annotation = ComplexHeatmap::HeatmapAnnotation(df = df),
      left_annotation = ComplexHeatmap::rowAnnotation(
        df = data.frame(kind = c("a", "a", "b", "a", "b"), size = 1:5)
      ),
      ...
    )
  }
  expect_tracks_paint_values(annotated())
  expect_tracks_paint_values(annotated(
    row_split = c("p", "p", "q", "q", "q"),
    column_split = rep(c("x", "y"), each = 3)
  ))
})

test_that("a track whose cells cannot be told apart is read without highlighting", {
  m <- cha_matrix()
  # A discrete track given a `gp` without `col` is drawn a rect per run.
  ht <- ComplexHeatmap::Heatmap(
    m,
    cluster_columns = FALSE,
    top_annotation = ComplexHeatmap::HeatmapAnnotation(
      runs = ComplexHeatmap::anno_simple(
        c("a", "a", "a", "b", "b", "a"),
        gp = grid::gpar(lwd = 2)
      )
    )
  )
  layers <- cha_layers(ht)
  expect_length(layers[[2]]$selectors, 0L)
  expect_identical(cha_step_field(layers[[2]], "label"), c("a", "a", "a", "b", "b", "a"))

  # Two tracks of one name, top and bottom, draw viewports of one name.
  ht <- ComplexHeatmap::Heatmap(
    m,
    top_annotation = ComplexHeatmap::HeatmapAnnotation(same = 1:6),
    bottom_annotation = ComplexHeatmap::HeatmapAnnotation(same = 6:1)
  )
  layers <- cha_layers(ht)
  expect_length(layers, 3L)
  expect_length(layers[[2]]$selectors, 0L)
  expect_length(layers[[3]]$selectors, 0L)
})

test_that("save_html() writes the annotation layers", {
  file <- withr::local_tempfile(fileext = ".html")
  ht <- ComplexHeatmap::Heatmap(
    cha_matrix(),
    top_annotation = ComplexHeatmap::HeatmapAnnotation(df = cha_columns())
  )
  save_html(ht, file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;step&quot;", fixed = TRUE)
  expect_match(html, "&quot;name&quot;:&quot;dose&quot;", fixed = TRUE)
  expect_match(html, "id=\"maidr-complexheatmap-annotation-1-1-1.1\"", fixed = TRUE)
})

test_that("in a list, each heat map's tracks are layers of its own subplot", {
  skip_if_not_installed("xml2")
  m <- cha_matrix()
  df <- cha_columns()
  htl <- cha_drawn(
    ComplexHeatmap::Heatmap(
      m, name = "first",
      top_annotation = ComplexHeatmap::HeatmapAnnotation(group = df$group)
    ) +
      ComplexHeatmap::rowAnnotation(score = c(5, 4, 3, 2, 1)) +
      ComplexHeatmap::Heatmap(
        -m, name = "second",
        # The same annotation name as the first heat map's, in its own viewport.
        top_annotation = ComplexHeatmap::HeatmapAnnotation(group = rev(df$group), dose = df$dose)
      )
  )
  orchestrator <- cha_orchestrator(htl)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  subplots <- unlist(orchestrator$generate_maidr_data()$subplots, recursive = FALSE)
  with_heat <- Filter(function(s) length(s$layers) && identical(s$layers[[1]]$type, "heat"), subplots)
  expect_length(with_heat, 2L)
  first <- with_heat[[1]]$layers
  second <- with_heat[[2]]$layers
  # The list's row annotation belongs to the heat map before it.
  expect_identical(vapply(first, function(l) l$name %||% "", ""), c("", "group", "score"))
  expect_identical(vapply(second, function(l) l$name %||% "", ""), c("", "group", "dose"))

  ids <- unlist(lapply(subplots, function(s) vapply(s$layers, function(l) l$id, "")))
  expect_false(anyDuplicated(ids) > 0)

  order <- cha_order(htl)
  second_cols <- unlist(ComplexHeatmap::column_order(htl)[["second"]], use.names = FALSE)
  first_cols <- unlist(ComplexHeatmap::column_order(htl)[["first"]], use.names = FALSE)
  expect_identical(cha_step_field(first[[2]], "label"), df$group[first_cols])
  expect_identical(cha_step_field(second[[2]], "label"), rev(df$group)[second_cols])
  expect_identical(cha_heat_values(second[[3]]), df$dose[second_cols])
  expect_identical(cha_heat_values(first[[3]]), c(5, 4, 3, 2, 1)[order$rows])

  # Each selector names a cell of its own heat map's track, in its colours.
  svg <- xml2::read_xml(paste(build_interactive_svg(orchestrator), collapse = "\n"))
  heatmaps <- htl@ht_list[c("first", "second")]
  check <- function(layer, single, index) {
    expect_identical(
      cha_selected_fills(svg, layer),
      cha_rgb(ComplexHeatmap::map_to_colors(single@color_mapping, single@fun@var_env$value[index]))
    )
  }
  check(first[[2]], heatmaps$first@top_annotation@anno_list$group, first_cols)
  check(first[[3]], htl@ht_list[[2]]@anno_list$score, order$rows)
  check(second[[2]], heatmaps$second@top_annotation@anno_list$group, second_cols)
  check(second[[3]], heatmaps$second@top_annotation@anno_list$dose, second_cols)
})
