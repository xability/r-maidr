# Reading ComplexHeatmap heat maps (#381, #391)
#
# A `Heatmap`, or a `HeatmapList` holding one, is drawn once with
# ComplexHeatmap::draw(); the cells are read from the heat map's own matrix
# in the order that draw put them in, and selected in the SVG exported from
# the same drawing. Each test checks the reading against sources it does not
# compute: the input matrix, reordered by the row and column order of a
# separate draw, for the values and labels, and the exported SVG for the
# marks -- every selector must name exactly one cell, painted the colour
# ComplexHeatmap's own colour mapping gives that cell's value.

skip_if_not_installed("ComplexHeatmap")

ch_matrix <- function() {
  set.seed(381)
  matrix(
    rnorm(30, sd = 2), 5, 6,
    dimnames = list(paste0("gene", 1:5), paste0("sample", 1:6))
  )
}

ch_heatmap <- function(m = ch_matrix(), ...) {
  ComplexHeatmap::Heatmap(m, ...)
}

# Drawn as ComplexHeatmap draws it, for the order to check against.
ch_drawn <- function(x) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  ComplexHeatmap::draw(x)
}

ch_orchestrator <- function(x) {
  get_global_registry()$get_adapter_for_plot(x)$create_orchestrator(x)
}

# The grid with only the subplots holding a heat layer, rows with none left
# out: where the heat maps are among their dendrograms' subplots (#390).
ch_heat_subplots <- function(subplots) {
  heat <- function(s) length(s$layers) && identical(s$layers[[1]]$type, "heat")
  rows <- lapply(subplots, function(row) Filter(heat, row))
  Filter(length, rows)
}

ch_layer <- function(x) {
  orchestrator <- ch_orchestrator(x)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  ch_heat_subplots(orchestrator$generate_maidr_data()$subplots)[[1]][[1]]$layers[[1]]
}

ch_points <- function(layer) {
  do.call(rbind, lapply(layer$data$points, function(row) {
    vapply(row, function(v) if (is.null(v)) NA_real_ else v, numeric(1))
  }))
}

ch_order <- function(drawn) {
  list(
    rows = unlist(ComplexHeatmap::row_order(drawn), use.names = FALSE),
    cols = unlist(ComplexHeatmap::column_order(drawn), use.names = FALSE)
  )
}

# Every selector of a layer names one SVG element, inside the body of the
# heat map read, filled with the colour that heat map's colour mapping
# gives the value read for that cell.
expect_layer_paints_values <- function(svg, layer, heatmap) {
  mapping <- heatmap@matrix_color_mapping
  body <- paste0("::", heatmap@name, "_heatmap_body_")
  values <- ch_points(layer)
  n <- nrow(values)
  expect_length(layer$selectors, n)
  for (r in seq_len(n)) {
    # The selector grid runs bottom row first; the points top first.
    top_row <- n - r + 1L
    for (c in seq_len(ncol(values))) {
      id <- gsub("\\\\", "", sub("^#", "", layer$selectors[[r]][[c]]))
      cell <- xml2::xml_find_all(svg, sprintf("//*[@id='%s']", id))
      expect_length(cell, 1L)
      ancestors <- xml2::xml_attr(xml2::xml_find_all(cell, "ancestor::*"), "id")
      expect_true(any(grepl(body, ancestors, fixed = TRUE)))
      colour <- ComplexHeatmap::map_to_colors(mapping, values[top_row, c])
      rgb <- grDevices::col2rgb(colour)
      expect_identical(
        xml2::xml_attr(cell, "fill"),
        sprintf("rgb(%d,%d,%d)", rgb[1], rgb[2], rgb[3])
      )
    }
  }
}

ch_svg <- function(orchestrator) {
  xml2::read_xml(paste(build_interactive_svg(orchestrator), collapse = "\n"))
}

expect_selectors_paint_values <- function(x) {
  orchestrator <- ch_orchestrator(x)
  layer <- ch_heat_subplots(orchestrator$generate_maidr_data()$subplots)[[1]][[1]]$layers[[1]]
  expect_layer_paints_values(ch_svg(orchestrator), layer, ch_drawn(x)@ht_list[[1]])
}

test_that("a Heatmap and a HeatmapList are claimed by the ComplexHeatmap system", {
  ht <- ch_heatmap()
  expect_true(is_maidr_plot_object(ht))
  expect_identical(get_global_registry()$detect_system(ht), "complexheatmap")
  expect_false(BaseRAdapter$new()$can_handle(ht))

  htl <- ch_drawn(ht)
  expect_true(is_maidr_plot_object(htl))
  expect_identical(get_global_registry()$detect_system(htl), "complexheatmap")

  # A class of the same name from another package is not ComplexHeatmap's.
  other <- asS4(structure(list(), class = structure("Heatmap", package = "other")))
  expect_false(is_complexheatmap(other))
  expect_false(is_maidr_plot_object(other))
})

test_that("the cells are read exactly, in clustered order, rows top first", {
  m <- ch_matrix()
  ht <- ch_heatmap(m, name = "expression", column_title = "Expression")
  layer <- ch_layer(ht)
  order <- ch_order(ch_drawn(ht))

  expect_identical(layer$type, "heat")
  expect_identical(layer$title, "Expression")
  expect_identical(layer$axes$z$label, "expression")
  drawn <- m[order$rows, order$cols]
  expect_identical(unlist(layer$data$y), rownames(drawn))
  expect_identical(unlist(layer$data$x), colnames(drawn))
  expect_identical(ch_points(layer), unname(drawn))
})

test_that("split slices are read side by side, in drawn order, without gaps", {
  m <- ch_matrix()
  ht <- ch_heatmap(
    m,
    row_split = c("a", "a", "b", "b", "b"),
    column_split = rep(c("x", "y"), each = 3)
  )
  layer <- ch_layer(ht)
  order <- ch_order(ch_drawn(ht))

  expect_length(layer$data$points, 5L)
  expect_identical(unlist(layer$data$y), rownames(m)[order$rows])
  expect_identical(unlist(layer$data$x), colnames(m)[order$cols])
  expect_identical(ch_points(layer), unname(m[order$rows, order$cols]))
})

test_that("each selector names the one cell drawn for it", {
  skip_if_not_installed("xml2")
  m <- ch_matrix()
  m[2, 3] <- NA
  expect_selectors_paint_values(ch_heatmap(m))
  expect_selectors_paint_values(ch_heatmap(
    m,
    row_split = c("a", "a", "b", "b", "b"),
    column_split = rep(c("x", "y"), each = 3)
  ))
})

test_that("a drawn HeatmapList is read as drawn, its own titles included", {
  m <- ch_matrix()
  set.seed(1)
  htl <- ch_drawn(ch_heatmap(m, row_km = 2, name = "z") + ComplexHeatmap::rowAnnotation(n = 1:5))
  htl@column_title <- "Overall"
  layer <- ch_layer(htl)
  order <- ch_order(htl)

  expect_identical(layer$title, "Overall")
  # The k-means that drew it, not a new one.
  expect_identical(unlist(layer$data$y), rownames(m)[order$rows])
  expect_identical(ch_points(layer), unname(m[order$rows, order$cols]))
})

test_that("a missing cell is a hole, and labels follow what is drawn", {
  m <- unname(ch_matrix())
  m[2, 3] <- NA
  layer <- ch_layer(ch_heatmap(m, cluster_rows = FALSE, cluster_columns = FALSE))
  expect_identical(unlist(layer$data$y), as.character(1:5))
  expect_identical(unlist(layer$data$x), as.character(1:6))
  expect_identical(ch_points(layer), m)
  expect_identical(layer$axes$z$label, "value")

  m <- ch_matrix()
  layer <- ch_layer(ch_heatmap(
    m,
    cluster_rows = FALSE, cluster_columns = FALSE,
    row_labels = paste("Gene", 1:5), show_column_names = FALSE
  ))
  expect_identical(unlist(layer$data$y), paste("Gene", 1:5))
  expect_identical(unlist(layer$data$x), colnames(m))
})

# Whether ComplexHeatmap can rasterize a body here at all. Its raster path
# draws the cells into a temporary PNG with grDevices::png() (type "cairo"
# when R reports cairo) and reads it back; where no bitmap device can be
# opened -- macOS without XQuartz, as on the CI runners, where png() falls
# back to an X11 module that cannot load -- the PNG is never written and
# draw() itself stops, with or without maidr. Probed as ComplexHeatmap's own
# draw() of a tiny raster heat map on a null device.
ch_raster_works <- function() {
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  # A failed raster draw can take this device down with it.
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device))
  tryCatch(
    {
      suppressWarnings(suppressMessages(ComplexHeatmap::draw(
        ComplexHeatmap::Heatmap(matrix(1:4, 2), use_raster = TRUE)
      )))
      TRUE
    },
    error = function(e) FALSE
  )
}

test_that("a raster body is read without highlighting, and says so", {
  skip_if_not(ch_raster_works(), "ComplexHeatmap cannot rasterize a heat map body here")
  m <- ch_matrix()
  ht <- ch_heatmap(m, use_raster = TRUE, cluster_rows = FALSE, cluster_columns = FALSE)
  expect_message(layer <- ch_layer(ht), "use_raster", class = "maidr_complexheatmap_raster")
  expect_length(layer$selectors, 0L)
  expect_identical(ch_points(layer), unname(m))
})

# Lists of several heat maps (#391): each heat map is read from its own
# matrix into a subplot of its own, in the order the list shares.

ch_list_matrices <- function() {
  set.seed(391)
  list(
    a = ch_matrix(),
    # The rows of `a`, other columns, other values: its own colours.
    b = matrix(
      rnorm(20, mean = 50, sd = 10), 5, 4,
      dimnames = list(paste0("gene", 1:5), paste0("drug", 1:4))
    ),
    # The columns of `a`, other rows.
    c = matrix(
      rnorm(18, mean = -20, sd = 5), 3, 6,
      dimnames = list(paste0("protein", 1:3), paste0("sample", 1:6))
    )
  )
}

ch_grid <- function(x) {
  orchestrator <- ch_orchestrator(x)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  ch_heat_subplots(orchestrator$generate_maidr_data()$subplots)
}

ch_subplot_ids <- function(subplots) {
  lapply(subplots, function(row) vapply(row, function(s) s$id, character(1)))
}

test_that("a horizontal list is one row of heat maps, each read exactly", {
  m <- ch_list_matrices()
  x <- ComplexHeatmap::Heatmap(m$a, name = "a", column_title = "A", row_title = "Genes") +
    ComplexHeatmap::Heatmap(m$b, name = "b", column_title = "B")
  subplots <- ch_grid(x)
  drawn <- ch_drawn(x)
  rows <- ComplexHeatmap::row_order(drawn)
  cols <- lapply(ComplexHeatmap::column_order(drawn), unlist, use.names = FALSE)

  # The row tree first, left of `a`.
  expect_identical(ch_subplot_ids(subplots), list(c("maidr-subplot-1-2", "maidr-subplot-1-3")))
  a <- subplots[[1]][[1]]$layers[[1]]
  b <- subplots[[1]][[2]]$layers[[1]]
  expect_identical(c(a$id, b$id), c("maidr-layer-1", "maidr-layer-2"))
  expect_identical(c(a$title, b$title), c("A", "B"))
  expect_identical(c(a$axes$z$label, b$axes$z$label), c("a", "b"))
  # The rows are shared, and so is the row title drawn for them.
  expect_identical(c(a$axes$y$label, b$axes$y$label), c("Genes", "Genes"))
  expect_identical(ch_points(a), unname(m$a[rows, cols$a]))
  expect_identical(ch_points(b), unname(m$b[rows, cols$b]))
  expect_identical(unlist(b$data$y), rownames(m$b)[rows])
  expect_identical(unlist(b$data$x), colnames(m$b)[cols$b])
})

test_that("a vertical list is one column of heat maps, bottom first", {
  m <- ch_list_matrices()
  x <- ComplexHeatmap::`%v%`(
    ComplexHeatmap::Heatmap(m$a, name = "a"),
    ComplexHeatmap::Heatmap(m$c, name = "c", row_title = "Proteins")
  )
  subplots <- ch_grid(x)
  drawn <- ch_drawn(x)
  rows <- ComplexHeatmap::row_order(drawn)
  cols <- unlist(ComplexHeatmap::column_order(drawn), use.names = FALSE)

  # `c` is drawn below `a`; the grid's rows run bottom first, and each
  # heat map's row tree is left of it.
  expect_identical(ch_subplot_ids(subplots), list("maidr-subplot-1-2", "maidr-subplot-2-2"))
  c <- subplots[[1]][[1]]$layers[[1]]
  a <- subplots[[2]][[1]]$layers[[1]]
  expect_identical(c(a$axes$z$label, c$axes$z$label), c("a", "c"))
  expect_identical(c(a$axes$y$label, c$axes$y$label), c("Rows", "Proteins"))
  # The columns are shared.
  expect_identical(ch_points(a), unname(m$a[unlist(rows$a), cols]))
  expect_identical(ch_points(c), unname(m$c[unlist(rows$c), cols]))
  expect_identical(unlist(c$data$y), rownames(m$c)[unlist(rows$c)])
  expect_identical(unlist(c$data$x), colnames(m$a)[cols])
})

test_that("a list of split heat maps reads each one's slices in drawn order", {
  m <- ch_list_matrices()
  x <- ComplexHeatmap::Heatmap(
    m$a,
    name = "a",
    row_split = c("p", "p", "q", "q", "q"),
    column_split = rep(c("x", "y"), each = 3)
  ) + ComplexHeatmap::Heatmap(m$b, name = "b", column_split = c(1, 2, 1, 2))
  subplots <- ch_grid(x)
  drawn <- ch_drawn(x)
  rows <- unlist(ComplexHeatmap::row_order(drawn), use.names = FALSE)
  cols <- lapply(ComplexHeatmap::column_order(drawn), unlist, use.names = FALSE)

  expect_length(subplots[[1]], 2L)
  expect_identical(ch_points(subplots[[1]][[1]]$layers[[1]]), unname(m$a[rows, cols$a]))
  expect_identical(ch_points(subplots[[1]][[2]]$layers[[1]]), unname(m$b[rows, cols$b]))
})

test_that("each heat map's selectors name its own cells", {
  skip_if_not_installed("xml2")
  m <- ch_list_matrices()
  m$b[2, 3] <- NA
  lists <- list(
    ComplexHeatmap::Heatmap(m$a, name = "a") + ComplexHeatmap::Heatmap(m$b, name = "b"),
    ComplexHeatmap::`%v%`(
      ComplexHeatmap::Heatmap(m$a, name = "a"),
      ComplexHeatmap::Heatmap(m$c, name = "c")
    ),
    ComplexHeatmap::Heatmap(
      m$a,
      name = "a",
      row_split = c("p", "p", "q", "q", "q"),
      column_split = rep(c("x", "y"), each = 3)
    ) + ComplexHeatmap::Heatmap(m$b, name = "b", column_split = c(1, 2, 1, 2))
  )
  for (x in lists) {
    orchestrator <- ch_orchestrator(x)
    svg <- ch_svg(orchestrator)
    subplots <- ch_heat_subplots(orchestrator$generate_maidr_data()$subplots)
    heatmaps <- ch_drawn(x)@ht_list
    # In drawn order: the one row left to right, or the column's rows,
    # written bottom first, top to bottom.
    drawn_order <- if (length(subplots) == 1L) subplots[[1]] else rev(lapply(subplots, `[[`, 1L))
    layers <- lapply(drawn_order, function(s) s$layers[[1]])
    expect_length(layers, 2L)
    for (k in 1:2) {
      expect_layer_paints_values(svg, layers[[k]], heatmaps[[k]])
    }
  }
})

test_that("a list with annotations between heat maps reads the heat maps", {
  m <- ch_list_matrices()
  x <- ComplexHeatmap::Heatmap(m$a, name = "a") +
    ComplexHeatmap::rowAnnotation(n = 1:5) +
    ComplexHeatmap::Heatmap(m$b, name = "b")
  subplots <- ch_grid(x)
  rows <- ComplexHeatmap::row_order(ch_drawn(x))
  expect_length(subplots[[1]], 2L)
  b <- subplots[[1]][[2]]$layers[[1]]
  expect_identical(b$axes$z$label, "b")
  expect_identical(unlist(b$data$y), rownames(m$b)[rows])
})

test_that("a discrete heat map in a list is skipped, and alone falls back", {
  m <- ch_list_matrices()
  discrete <- matrix(sample(c("lo", "hi"), 5, replace = TRUE), 5, 1)
  x <- ComplexHeatmap::Heatmap(m$a, name = "a") +
    ComplexHeatmap::Heatmap(discrete, name = "kind")
  expect_message(
    orchestrator <- ch_orchestrator(x),
    "'kind' is a heat map of categories",
    class = "maidr_complexheatmap_skipped"
  )
  subplots <- ch_heat_subplots(orchestrator$generate_maidr_data()$subplots)
  # Beside its row tree, below its column tree.
  expect_identical(ch_subplot_ids(subplots), list("maidr-subplot-1-2"))
  expect_identical(subplots[[1]][[1]]$layers[[1]]$axes$z$label, "a")

  discrete <- matrix(sample(c("lo", "hi"), 30, replace = TRUE), 5, 6)
  orchestrator <- ch_orchestrator(ch_heatmap(discrete))
  expect_match(orchestrator$unsupported_reasons(), "not a non-empty numeric matrix")
  expect_true(orchestrator$has_unsupported_layers())

  orchestrator <- suppressMessages(ch_orchestrator(
    ch_heatmap(discrete, name = "x") + ch_heatmap(discrete, name = "y")
  ))
  expect_match(orchestrator$unsupported_reasons(), "none of its 2 heat maps")
})

test_that("save_html() and the widget write a heat layer for a Heatmap", {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(ch_heatmap(ch_matrix()), file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;heat&quot;", fixed = TRUE)
  expect_match(html, "id=\"maidr-complexheatmap-cells-1-1-1.1.30\"", fixed = TRUE)

  widget <- maidr_widget(ch_heatmap(ch_matrix()))
  expect_s3_class(widget, "htmlwidget")
})
