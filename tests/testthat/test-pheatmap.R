# Reading the object pheatmap::pheatmap() returns (#376)
#
# pheatmap() returns the trees and the drawn gtable, not the matrix, so each
# test checks the reading against sources it does not compute: the input
# matrix reordered by the trees for the values and labels, and the exported
# SVG for the marks -- every selector must name exactly one cell, painted the
# colour pheatmap gave that cell.

skip_if_not_installed("pheatmap")

ph_draw <- function(...) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  pheatmap::pheatmap(..., silent = TRUE)
}

ph_layer <- function(p) {
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  orchestrator$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]
}

ph_points <- function(layer) {
  do.call(rbind, lapply(layer$data$points, function(row) {
    vapply(row, function(v) if (is.null(v)) NA_real_ else v, numeric(1))
  }))
}

ph_matrix <- function() {
  set.seed(376)
  matrix(
    rnorm(20, sd = 2), 4, 5,
    dimnames = list(paste0("gene", 1:4), paste0("sample", 1:5))
  )
}

test_that("a pheatmap is claimed by the pheatmap system and no other", {
  p <- ph_draw(ph_matrix())
  expect_true(is_maidr_plot_object(p))
  expect_identical(get_global_registry()$detect_system(p), "pheatmap")
  expect_false(BaseRAdapter$new()$can_handle(p))
})

test_that("the cells are read in clustered order, rows top first", {
  m <- ph_matrix()
  p <- ph_draw(m, main = "Expression")
  layer <- ph_layer(p)

  expect_identical(layer$type, "heat")
  expect_identical(layer$title, "Expression")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_identical(unlist(layer$data$y), rownames(drawn))
  expect_identical(unlist(layer$data$x), colnames(drawn))

  # Read back from the colours: each value is the middle of its legend
  # band, so it lies within a band's width (1/100 of the range) of the
  # input, rounded to that width.
  band <- diff(range(m)) / 100
  expect_lt(max(abs(ph_points(layer) - drawn)), band)
  # The extremes sit in the end bands.
  expect_lt(abs(max(ph_points(layer)) - max(m)), band)
  expect_lt(abs(min(ph_points(layer)) - min(m)), band)
})

test_that("printed numbers are read as drawn, scaled, in input order when not clustered", {
  m <- ph_matrix()
  p <- ph_draw(m, scale = "row", display_numbers = TRUE, cluster_rows = FALSE)
  layer <- ph_layer(p)

  scaled <- t(scale(t(m)))[, p$tree_col$order]
  expect_identical(unlist(layer$data$y), rownames(m))
  expect_identical(unlist(layer$data$x), colnames(scaled))
  expect_equal(ph_points(layer), unname(round(scaled, 2)), ignore_attr = TRUE)
})

test_that("a missing cell is a hole, and an unnamed matrix is named by position", {
  m <- unname(ph_matrix())
  m[2, 3] <- NA
  layer <- ph_layer(ph_draw(m, cluster_rows = FALSE, cluster_cols = FALSE))

  expect_identical(unlist(layer$data$y), as.character(1:4))
  expect_identical(unlist(layer$data$x), as.character(1:5))
  points <- ph_points(layer)
  expect_identical(which(is.na(points)), which(is.na(m)))
  expect_lt(max(abs(points - m), na.rm = TRUE), diff(range(m, na.rm = TRUE)) / 100)
})

test_that("each selector names the one cell drawn for it", {
  m <- ph_matrix()
  p <- ph_draw(m)
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  svg <- xml2::read_xml(paste(build_interactive_svg(orchestrator), collapse = "\n"))
  layer <- orchestrator$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]

  fill <- pheatmap_child(pheatmap_grob(p$gtable, "matrix"), "rect")$gp$fill
  n <- nrow(fill)
  expect_length(layer$selectors, n)
  for (r in seq_len(n)) {
    # The selector grid runs bottom row first; the fill matrix top first.
    top_row <- n - r + 1L
    for (c in seq_len(ncol(fill))) {
      id <- gsub("\\\\", "", sub("^#", "", layer$selectors[[r]][[c]]))
      cell <- xml2::xml_find_all(svg, sprintf("//*[@id='%s']", id))
      expect_length(cell, 1L)
      rgb <- grDevices::col2rgb(fill[top_row, c])
      expect_identical(
        xml2::xml_attr(cell, "fill"),
        sprintf("rgb(%d,%d,%d)", rgb[1], rgb[2], rgb[3])
      )
    }
  }
})

test_that("a pheatmap with no legend and no numbers falls back", {
  p <- ph_draw(ph_matrix(), legend = FALSE)
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  expect_match(orchestrator$unsupported_reasons(), "cannot be read")
  expect_true(orchestrator$has_unsupported_layers())

  # Printed numbers stand in for the legend.
  p <- ph_draw(ph_matrix(), legend = FALSE, display_numbers = TRUE)
  expect_identical(ph_layer(p)$type, "heat")
})

test_that("save_html() writes a heat layer for a pheatmap", {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(ph_draw(ph_matrix()), file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;heat&quot;", fixed = TRUE)
  expect_match(html, "id=\"maidr-pheatmap-cells.1.20\"", fixed = TRUE)
})
