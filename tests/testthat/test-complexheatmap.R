# Reading ComplexHeatmap heat maps (#381)
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

ch_layer <- function(x) {
  orchestrator <- ch_orchestrator(x)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  orchestrator$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]
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

# Every selector names one SVG element, filled with the colour the heat
# map's colour mapping gives the value read for that cell.
expect_selectors_paint_values <- function(x) {
  orchestrator <- ch_orchestrator(x)
  svg <- xml2::read_xml(paste(build_interactive_svg(orchestrator), collapse = "\n"))
  layer <- orchestrator$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]
  mapping <- ch_drawn(x)@ht_list[[1]]@matrix_color_mapping
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
      colour <- ComplexHeatmap::map_to_colors(mapping, values[top_row, c])
      rgb <- grDevices::col2rgb(colour)
      expect_identical(
        xml2::xml_attr(cell, "fill"),
        sprintf("rgb(%d,%d,%d)", rgb[1], rgb[2], rgb[3])
      )
    }
  }
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

test_that("a raster body is read without highlighting, and says so", {
  m <- ch_matrix()
  ht <- ch_heatmap(m, use_raster = TRUE, cluster_rows = FALSE, cluster_columns = FALSE)
  expect_message(layer <- ch_layer(ht), "use_raster", class = "maidr_complexheatmap_raster")
  expect_length(layer$selectors, 0L)
  expect_identical(ch_points(layer), unname(m))
})

test_that("more than one heat map, or a discrete one, falls back", {
  m <- ch_matrix()
  orchestrator <- ch_orchestrator(ch_heatmap(m) + ch_heatmap(m))
  expect_match(orchestrator$unsupported_reasons(), "2 heat maps")
  expect_true(orchestrator$has_unsupported_layers())

  discrete <- matrix(sample(c("lo", "hi"), 30, replace = TRUE), 5, 6)
  orchestrator <- ch_orchestrator(ch_heatmap(discrete))
  expect_match(orchestrator$unsupported_reasons(), "not a non-empty numeric matrix")
})

test_that("save_html() and the widget write a heat layer for a Heatmap", {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(ch_heatmap(ch_matrix()), file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;heat&quot;", fixed = TRUE)
  expect_match(html, "id=\"maidr-complexheatmap-cells-1-1.1.30\"", fixed = TRUE)

  widget <- maidr_widget(ch_heatmap(ch_matrix()))
  expect_s3_class(widget, "htmlwidget")
})
