# Reading the object pheatmap::pheatmap() returns (#376)
#
# pheatmap() returns the trees and the drawn gtable, not the matrix. maidr's
# own pheatmap() keeps the matrix as drawn with the result, and the reading
# then announces it exactly; a chart drawn by pheatmap::pheatmap() directly
# is read from its colours, approximately, and says so. Each test checks the
# reading against sources it does not compute: the input matrix, scaled and
# reordered here by R's own functions, for the values and labels, and the
# exported SVG for the marks -- every selector must name exactly one cell,
# painted the colour pheatmap gave that cell.

skip_if_not_installed("pheatmap")

# Drawn through maidr's wrapper: a bare pheatmap() in a test resolves to
# maidr's namespace.
ph_draw <- function(...) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  pheatmap(..., silent = TRUE)
}

# Drawn by pheatmap itself, as when 'pheatmap' masks maidr's wrapper.
ph_draw_direct <- function(...) {
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

test_that("maidr's pheatmap() draws what pheatmap draws and returns it", {
  m <- ph_matrix()
  p <- ph_draw(m, main = "Expression")
  q <- ph_draw_direct(m, main = "Expression")
  expect_s3_class(p, "pheatmap")
  expect_identical(p$tree_row$order, q$tree_row$order)
  expect_identical(p$tree_col$order, q$tree_col$order)
  expect_identical(
    pheatmap_child(pheatmap_grob(p$gtable, "matrix"), "rect")$gp$fill,
    pheatmap_child(pheatmap_grob(q$gtable, "matrix"), "rect")$gp$fill
  )
  expect_null(attr(q, "maidr_matrix"))
})

test_that("the cells are read exactly, in clustered order, rows top first", {
  m <- ph_matrix()
  p <- ph_draw(m, main = "Expression")
  expect_no_message(layer <- ph_layer(p), class = "maidr_pheatmap_values")

  expect_identical(layer$type, "heat")
  expect_identical(layer$title, "Expression")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_identical(unlist(layer$data$y), rownames(drawn))
  expect_identical(unlist(layer$data$x), colnames(drawn))
  expect_identical(ph_points(layer), unname(drawn))
})

test_that("a scaled pheatmap is read as drawn: the scaled matrix, exactly", {
  m <- ph_matrix()

  p <- ph_draw(m, scale = "row")
  rows <- t(scale(t(m)))[p$tree_row$order, p$tree_col$order]
  expect_equal(ph_points(ph_layer(p)), unname(rows), tolerance = 1e-12)

  p <- ph_draw(m, scale = "column", cluster_rows = FALSE)
  columns <- scale(m)[, p$tree_col$order]
  layer <- ph_layer(p)
  expect_identical(unlist(layer$data$y), rownames(m))
  expect_equal(ph_points(layer), unname(columns), tolerance = 1e-12)
})

test_that("with kmeans_k the cluster centres it draws are read", {
  set.seed(1)
  m <- matrix(rnorm(200), 40, 5)
  set.seed(2)
  p <- ph_draw(m, kmeans_k = 3)
  layer <- ph_layer(p)
  centres <- p$kmeans$centers[p$tree_row$order, p$tree_col$order]
  expect_identical(ph_points(layer), unname(centres))
  expect_match(unlist(layer$data$y), "^Cluster: [0-9]+ Size: [0-9]+$")
})

test_that("a missing cell is a hole, and an unnamed matrix is named by position", {
  m <- unname(ph_matrix())
  m[2, 3] <- NA
  layer <- ph_layer(ph_draw(m, cluster_rows = FALSE, cluster_cols = FALSE))

  expect_identical(unlist(layer$data$y), as.character(1:4))
  expect_identical(unlist(layer$data$x), as.character(1:5))
  expect_identical(ph_points(layer), m)
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

test_that("drawn by pheatmap itself, values are read from the legend and said to be approximate", {
  m <- ph_matrix()
  p <- ph_draw_direct(m, main = "Expression")
  expect_message(layer <- ph_layer(p), "approximate", class = "maidr_pheatmap_values")

  expect_match(layer$title, "^Expression \\(approximate values")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_identical(unlist(layer$data$y), rownames(drawn))
  # The middle of each cell's legend band: within a band's width (1/100 of
  # the range) of the input.
  band <- diff(range(m)) / 100
  expect_lt(max(abs(ph_points(layer) - drawn)), band)
})

test_that("a kept matrix that does not match the colours is not trusted", {
  m <- ph_matrix()
  p <- ph_draw(m)
  attr(p, "maidr_matrix") <- attr(p, "maidr_matrix") * 10
  expect_message(layer <- ph_layer(p), "approximate", class = "maidr_pheatmap_values")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_lt(max(abs(ph_points(layer) - drawn)), diff(range(m)) / 100)
})

test_that("without the matrix, printed numbers are read only when they are the values", {
  m <- ph_matrix()
  p <- ph_draw_direct(m, scale = "row", display_numbers = TRUE, cluster_rows = FALSE)
  expect_message(layer <- ph_layer(p), "as printed", class = "maidr_pheatmap_values")
  scaled <- t(scale(t(m)))[, p$tree_col$order]
  expect_equal(ph_points(layer), unname(round(scaled, 2)), ignore_attr = TRUE)

  # Numbers printed over the cells that are not their values -- p-values --
  # are not announced as them.
  p_values <- matrix(round(stats::runif(20), 3), 4, 5)
  p <- ph_draw_direct(m, display_numbers = p_values)
  expect_message(layer <- ph_layer(p), "approximate", class = "maidr_pheatmap_values")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_lt(max(abs(ph_points(layer) - drawn)), diff(range(m)) / 100)
})

test_that("a pheatmap with no legend is read from its kept matrix, or falls back", {
  m <- ph_matrix()
  p <- ph_draw(m, legend = FALSE)
  expect_identical(ph_points(ph_layer(p)), unname(m[p$tree_row$order, p$tree_col$order]))

  p <- ph_draw_direct(m, legend = FALSE)
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  expect_match(orchestrator$unsupported_reasons(), "cannot be read")
  expect_true(orchestrator$has_unsupported_layers())
})

test_that("save_html() writes a heat layer for a pheatmap", {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(ph_draw(ph_matrix()), file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;heat&quot;", fixed = TRUE)
  expect_match(html, "id=\"maidr-pheatmap-cells.1.20\"", fixed = TRUE)
})

test_that("pheatmap attached after maidr is reported as masking its wrapper", {
  local_mocked_bindings(package_masks_maidr = function(package) identical(package, "pheatmap"))
  expect_message(.maidr_pheatmap_attach_hook(), "maidr::pheatmap\\(\\)")
  withr::local_options(maidr.startup_message = FALSE)
  expect_silent(.maidr_pheatmap_attach_hook())
})
