# Comprehensive tests for BaseRHeatmapLayerProcessor
# Testing Base R heatmap processing, matrix data extraction, and structure

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("BaseRHeatmapLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "BaseRHeatmapLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("BaseRHeatmapLayerProcessor extract_data() works with matrix", {
  # Create simple 3x3 matrix
  test_matrix <- matrix(1:9, nrow = 3, ncol = 3)
  rownames(test_matrix) <- c("R1", "R2", "R3")
  colnames(test_matrix) <- c("C1", "C2", "C3")

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "") # First arg is unnamed matrix
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_type(data, "list")
  testthat::expect_true("points" %in% names(data))
  testthat::expect_true("x" %in% names(data))
  testthat::expect_true("y" %in% names(data))

  # Should have 3 rows (reversed for bottom-to-top visual order)
  testthat::expect_equal(length(data$points), 3)
  # Each row should have 3 columns
  testthat::expect_equal(length(data$points[[1]]), 3)

  # Check row and column names
  testthat::expect_equal(length(data$x), 3)
  testthat::expect_equal(length(data$y), 3)
})

test_that("BaseRHeatmapLayerProcessor process() returns correct structure", {
  test_matrix <- matrix(1:4, nrow = 2, ncol = 2)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = list(
        test_matrix,
        main = "Test Heatmap",
        xlab = "X Axis",
        ylab = "Y Axis"
      )
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  # Process with NULL gt (skip selector generation)
  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$type, "heat")
  testthat::expect_equal(result$title, "Test Heatmap")
  testthat::expect_equal(result$axes$x$label, "X Axis")
  testthat::expect_equal(result$axes$y$label, "Y Axis")
  testthat::expect_equal(result$axes$z$label, "value")
  testthat::expect_equal(result$domMapping$order, "row")
  testthat::expect_equal(length(result$data$points), 2)
})

test_that("BaseRHeatmapLayerProcessor handles NULL gt parameter", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(matrix(1:4, 2, 2)), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  selectors <- processor$generate_selectors(layer_info, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 0)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("BaseRHeatmapLayerProcessor handles single cell matrix", {
  test_matrix <- matrix(42, nrow = 1, ncol = 1)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data$points), 1)
  testthat::expect_equal(length(data$points[[1]]), 1)
  testthat::expect_equal(data$points[[1]][[1]], 42)
})

test_that("BaseRHeatmapLayerProcessor handles NULL layer_info", {
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(NULL)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data$points), 0)
  testthat::expect_equal(length(data$x), 0)
  testthat::expect_equal(length(data$y), 0)
})

test_that("BaseRHeatmapLayerProcessor handles non-matrix input", {
  # Pass a vector instead of matrix
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = list(c(1, 2, 3, 4)) # Vector, not matrix
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should return empty structure
  testthat::expect_equal(length(data$points), 0)
  testthat::expect_equal(length(data$x), 0)
  testthat::expect_equal(length(data$y), 0)
})

test_that("BaseRHeatmapLayerProcessor handles matrix without row/col names", {
  # Matrix with no names
  test_matrix <- matrix(1:6, nrow = 2, ncol = 3)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should generate default names (1, 2, 3, ...)
  testthat::expect_equal(length(data$x), 3)
  testthat::expect_equal(length(data$y), 2)
  testthat::expect_type(data$x[[1]], "character")
  testthat::expect_type(data$y[[1]], "character")
})

test_that("BaseRHeatmapLayerProcessor handles large matrix", {
  test_matrix <- matrix(runif(400), nrow = 20, ncol = 20)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data$points), 20)
  testthat::expect_equal(length(data$points[[1]]), 20)
  testthat::expect_equal(length(data$x), 20)
  testthat::expect_equal(length(data$y), 20)
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("BaseRHeatmapLayerProcessor extract_axis_titles() works", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = list(
        matrix(1:4, 2, 2),
        xlab = "Columns",
        ylab = "Rows"
      )
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_type(axes, "list")
  testthat::expect_equal(axes$x$label, "Columns")
  testthat::expect_equal(axes$y$label, "Rows")
  testthat::expect_equal(axes$z$label, "value") # Default z label
})

test_that("BaseRHeatmapLayerProcessor extract_axis_titles() leaves image() axes unnamed", {
  # image(x, y, z) puts the caller's own coordinates on the axes, so nothing
  # about the call establishes what they hold. The axes are omitted rather
  # than blanked, which leaves the generic to the renderer.
  layer_info <- list(
    index = 1,
    function_name = "image",
    plot_call = list(
      function_name = "image",
      args = structure(list(matrix(1:4, 2, 2)), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_null(axes$x)
  testthat::expect_null(axes$y)
  testthat::expect_equal(axes$z$label, "value")
})

test_that("BaseRHeatmapLayerProcessor names the dimensions heatmap() draws", {
  # heatmap() lays a matrix out one way round only: columns along x, rows up
  # the y axis. Neither is a guess about the data.
  layer_info <- list(
    index = 1,
    function_name = "heatmap",
    plot_call = list(
      function_name = "heatmap",
      args = list(matrix(1:4, 2, 2))
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x$label, "Columns")
  testthat::expect_equal(axes$y$label, "Rows")
  testthat::expect_equal(axes$z$label, "value")
})

test_that("BaseRHeatmapLayerProcessor lets a heatmap() caller's labels win", {
  layer_info <- list(
    index = 1,
    function_name = "heatmap",
    plot_call = list(
      function_name = "heatmap",
      args = list(matrix(1:4, 2, 2), xlab = "Samples", ylab = "Genes")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x$label, "Samples")
  testthat::expect_equal(axes$y$label, "Genes")
})

test_that("BaseRHeatmapLayerProcessor extract_main_title() works", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = list(
        matrix(1:4, 2, 2),
        main = "My Heatmap"
      )
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "My Heatmap")
})

test_that("BaseRHeatmapLayerProcessor extract_main_title() handles no title", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(matrix(1:4, 2, 2)), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "")
})

# ==============================================================================
# Tier 4: Heatmap-Specific Logic
# ==============================================================================

test_that("BaseRHeatmapLayerProcessor reverses rows for bottom-to-top order", {
  # Create matrix with specific values to test reversal
  test_matrix <- matrix(c(1, 2, 3, 4, 5, 6), nrow = 3, ncol = 2, byrow = TRUE)
  rownames(test_matrix) <- c("Top", "Middle", "Bottom")
  colnames(test_matrix) <- c("Left", "Right")

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Rows should be reversed: Bottom, Middle, Top
  testthat::expect_equal(data$y[[1]], "Bottom")
  testthat::expect_equal(data$y[[2]], "Middle")
  testthat::expect_equal(data$y[[3]], "Top")

  # First row in data should be bottom row of original matrix (5, 6)
  testthat::expect_equal(data$points[[1]][[1]], 5)
  testthat::expect_equal(data$points[[1]][[2]], 6)
})

test_that("BaseRHeatmapLayerProcessor matrix structure is correct", {
  test_matrix <- matrix(c(11, 12, 21, 22, 31, 32), nrow = 3, ncol = 2, byrow = TRUE)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should have 3 rows (reversed)
  testthat::expect_equal(length(data$points), 3)

  # Each row should have 2 columns
  testthat::expect_equal(length(data$points[[1]]), 2)
  testthat::expect_equal(length(data$points[[2]]), 2)
  testthat::expect_equal(length(data$points[[3]]), 2)

  # After reversal: bottom row (31, 32), middle (21, 22), top (11, 12)
  testthat::expect_equal(data$points[[1]][[1]], 31)
  testthat::expect_equal(data$points[[2]][[1]], 21)
  testthat::expect_equal(data$points[[3]][[1]], 11)
})

test_that("BaseRHeatmapLayerProcessor handles NA values", {
  test_matrix <- matrix(c(1, NA, 3, 4), nrow = 2, ncol = 2)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should preserve NA values
  has_na <- any(sapply(data$points, function(row) any(sapply(row, is.na))))
  testthat::expect_true(has_na)
})

test_that("BaseRHeatmapLayerProcessor domMapping order is 'row'", {
  test_matrix <- matrix(1:4, 2, 2)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info)

  testthat::expect_true("domMapping" %in% names(result))
  testthat::expect_equal(result$domMapping$order, "row")
})

test_that("BaseRHeatmapLayerProcessor handles numeric row/col names", {
  test_matrix <- matrix(1:9, nrow = 3, ncol = 3)
  rownames(test_matrix) <- c(10, 20, 30)
  colnames(test_matrix) <- c(100, 200, 300)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(test_matrix), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Names should be converted to character
  testthat::expect_type(data$x[[1]], "character")
  testthat::expect_type(data$y[[1]], "character")
})

test_that("BaseRHeatmapLayerProcessor extracts all metadata correctly", {
  test_matrix <- matrix(1:6, nrow = 2, ncol = 3)
  rownames(test_matrix) <- c("Row1", "Row2")
  colnames(test_matrix) <- c("Col1", "Col2", "Col3")

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = list(
        test_matrix,
        main = "Complete Heatmap",
        xlab = "X Label",
        ylab = "Y Label"
      )
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  # Test data extraction
  data <- processor$extract_data(layer_info)
  testthat::expect_equal(length(data$points), 2)
  testthat::expect_equal(length(data$x), 3)
  testthat::expect_equal(length(data$y), 2)

  # Test title extraction
  title <- processor$extract_main_title(layer_info)
  testthat::expect_equal(title, "Complete Heatmap")

  # Test axes extraction
  axes <- processor$extract_axis_titles(layer_info)
  testthat::expect_equal(axes$x$label, "X Label")
  testthat::expect_equal(axes$y$label, "Y Label")
  testthat::expect_equal(axes$z$label, "value")
})

# Selector tests skipped - tested at orchestrator level

# ==============================================================================
# heatmap(revC = TRUE) draws its rows the other way up (issue #60)
#
# heatmap() puts reordered row 1 at the BOTTOM of the y axis, so the emitted
# grid, which reads top-down, is the reverse of the reordered matrix. `revC`
# flips the drawing, and it is TRUE for every symm = TRUE call because Colv
# defaults to "Rowv" there. revC is not part of the ordering heatmap()
# returns, so the payload used to come out vertically mirrored: two calls
# differing only in revC emitted byte-identical data for mirror-image
# figures.
# ==============================================================================

heatmap_layer_info <- function(m, ...) {
  list(
    index = 1,
    function_name = "heatmap",
    plot_call = list(
      function_name = "heatmap",
      args = c(list(x = m), list(...))
    )
  )
}

heatmap_matrix <- function() {
  matrix(
    c(1, 2, 3, 4, 5, 6, 7, 8, 9),
    nrow = 3, byrow = TRUE,
    dimnames = list(c("R1", "R2", "R3"), c("C1", "C2", "C3"))
  )
}

test_that("heatmap_applies_revc() resolves revC the way heatmap() does", {
  m <- heatmap_matrix()

  # Plain call: Colv defaults to NULL, so revC is FALSE.
  testthat::expect_false(maidr:::heatmap_applies_revc(list(x = m)))
  # symm = TRUE makes Colv default to "Rowv", which makes revC TRUE.
  testthat::expect_true(maidr:::heatmap_applies_revc(list(x = m, symm = TRUE)))
  # Colv = "Rowv" does the same without symm.
  testthat::expect_true(
    maidr:::heatmap_applies_revc(list(x = m, Colv = "Rowv"))
  )
  # An explicit revC always wins.
  testthat::expect_false(
    maidr:::heatmap_applies_revc(list(x = m, symm = TRUE, revC = FALSE))
  )
  testthat::expect_true(maidr:::heatmap_applies_revc(list(x = m, revC = TRUE)))
  # Colv = NA is not "Rowv".
  testthat::expect_false(
    maidr:::heatmap_applies_revc(list(x = m, symm = TRUE, Colv = NA))
  )
})

test_that("heatmap without revC still emits rows bottom-up", {
  m <- heatmap_matrix()
  info <- heatmap_layer_info(m, Rowv = NA, Colv = NA, scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)

  data <- processor$extract_data(info)

  testthat::expect_equal(unlist(data$y), c("R3", "R2", "R1"))
  testthat::expect_equal(unlist(data$points[[1]]), c(7, 8, 9))
  testthat::expect_equal(unlist(data$points[[3]]), c(1, 2, 3))
})

test_that("heatmap with revC emits rows the way they are drawn", {
  m <- heatmap_matrix()
  info <- heatmap_layer_info(m, Rowv = NA, Colv = "Rowv", scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)

  data <- processor$extract_data(info)

  # Same matrix and same ordering as the test above; only revC differs, so
  # the grid must come out the other way up rather than identical.
  testthat::expect_equal(unlist(data$y), c("R1", "R2", "R3"))
  testthat::expect_equal(unlist(data$points[[1]]), c(1, 2, 3))
  testthat::expect_equal(unlist(data$points[[3]]), c(7, 8, 9))
})

test_that("a symm heatmap emits its dendrogram rows in drawn order", {
  testthat::skip_if_not_installed("xml2")

  m <- heatmap_matrix()
  sym <- (m + t(m)) / 2

  # The ordering heatmap() itself will use, taken from the function under
  # test's own throwaway-device trick so the expectation is not hard-coded
  # to one clustering implementation.
  null_pdf <- tempfile(fileext = ".pdf")
  on.exit(unlink(null_pdf), add = TRUE)
  grDevices::pdf(null_pdf)
  ordering <- stats::heatmap(sym, symm = TRUE, scale = "none")
  grDevices::dev.off()

  info <- heatmap_layer_info(sym, symm = TRUE, scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)
  data <- processor$extract_data(info)

  # revC applies, so the drawn rows read top-down in rowInd order.
  testthat::expect_equal(
    unlist(data$y),
    rownames(sym)[ordering$rowInd]
  )
  testthat::expect_equal(
    unlist(data$points[[1]]),
    unname(sym[ordering$rowInd[1], ordering$colInd])
  )
})

test_that("a rendered revC heatmap lists rows in drawn top-to-bottom order", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  m <- heatmap_matrix()

  maidr:::clear_all_device_storage()
  grDevices::pdf(NULL)
  heatmap(m, Rowv = NA, Colv = "Rowv", scale = "none")
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  suppressWarnings(save_html(file = file))
  grDevices::dev.off()

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  raw <- regmatches(
    html, gregexpr('maidr-data="([^"]*)"', html, perl = TRUE)
  )[[1]]
  testthat::expect_gt(length(raw), 0)

  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  layer <- payload$subplots[[1]][[1]]$layers[[1]]

  # Row labels as drawn: axis(4) text nodes, read visually top to bottom.
  # gridSVG wraps the whole tree in translate(0, h) scale(1, -1), so a
  # LARGER y is higher up the page.
  doc <- xml2::read_html(html)
  nodes <- xml2::xml_find_all(
    doc,
    "//*[contains(@id,'right-axis-labels')][local-name()='text']"
  )
  testthat::expect_equal(length(nodes), 3L)
  label_y <- vapply(nodes, function(nd) {
    tf <- xml2::xml_attr(xml2::xml_parent(xml2::xml_parent(nd)), "transform")
    as.numeric(regmatches(tf, gregexpr("-?[0-9.]+", tf))[[1]])[2]
  }, numeric(1))
  drawn <- vapply(nodes, xml2::xml_text, character(1))[order(-label_y)]

  testthat::expect_equal(unlist(layer$data$y), drawn)
})

# ==============================================================================
# Unnamed matrices: heatmap() labels the reordered matrix with the ORIGINAL
# indices, `(1L:nr)[rowInd]`, because it takes labRow after `x <- x[rowInd,
# colInd]` has already dropped the (absent) dimnames. maidr used to fall back
# to a plain 1..n position sequence there, so an unnamed matrix announced a
# systematically permuted identity while sonifying the right values.
# ==============================================================================

# Unnamed, and clustered into a non-identity ROW order (colInd stays 1..4).
heatmap_unnamed_matrix <- function() {
  matrix(
    c(
      10, 11, 12, 13,
      90, 91, 92, 93,
      50, 51, 52, 53,
      20, 21, 22, 23,
      70, 71, 72, 73
    ),
    nrow = 5, ncol = 4, byrow = TRUE
  )
}

# Unnamed, and clustered into a non-identity order on BOTH axes.
heatmap_unnamed_matrix_2d <- function() {
  matrix(
    c(
      10, 40, 30, 20,
      90, 60, 70, 80,
      50, 20, 30, 40,
      20, 80, 70, 30,
      70, 10, 15, 60
    ),
    nrow = 5, ncol = 4, byrow = TRUE
  )
}

# The ordering heatmap() itself uses, taken on a throwaway device so the
# expectations are not hard-coded to one clustering implementation.
heatmap_true_ordering <- function(m, ...) {
  null_pdf <- tempfile(fileext = ".pdf")
  grDevices::pdf(null_pdf)
  on.exit(
    {
      grDevices::dev.off()
      unlink(null_pdf)
    },
    add = TRUE
  )
  stats::heatmap(m, ...)
}

test_that("an unnamed reordered heatmap labels rows with the original indices", {
  m <- heatmap_unnamed_matrix()
  ordering <- heatmap_true_ordering(m, scale = "none")

  info <- heatmap_layer_info(m, scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)
  data <- processor$extract_data(info)

  # No revC here, so drawn top-to-bottom is the reverse of rowInd.
  testthat::expect_equal(
    unlist(data$y),
    rev(as.character(ordering$rowInd))
  )
  # The whole point: this is NOT the plain positional sequence.
  testthat::expect_false(
    identical(unlist(data$y), rev(as.character(seq_len(nrow(m)))))
  )
  # The values stay what they already were: drawn row 1 is original row
  # rowInd[nrow], because the grid reads top-down.
  testthat::expect_equal(
    unlist(data$points[[1]]),
    unname(m[ordering$rowInd[nrow(m)], ordering$colInd])
  )
})

test_that("an unnamed heatmap labels both axes from the ordering it draws", {
  m <- heatmap_unnamed_matrix_2d()
  ordering <- heatmap_true_ordering(m, scale = "none")

  # Guard the fixture: this matrix must reorder its COLUMNS too, otherwise
  # the x-axis half of this test proves nothing.
  testthat::expect_false(identical(ordering$colInd, seq_len(ncol(m))))

  info <- heatmap_layer_info(m, scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)
  data <- processor$extract_data(info)

  testthat::expect_equal(unlist(data$x), as.character(ordering$colInd))
  testthat::expect_equal(unlist(data$y), rev(as.character(ordering$rowInd)))
})

test_that("an unnamed symm heatmap labels rows top-down in rowInd order", {
  # symm = TRUE makes Colv default to "Rowv", so revC applies and the drawn
  # rows already read top-down -- labels must NOT be reversed here.
  m <- matrix(
    c(
      0, 9, 1, 8,
      9, 0, 7, 2,
      1, 7, 0, 6,
      8, 2, 6, 0
    ),
    nrow = 4, ncol = 4, byrow = TRUE
  )
  ordering <- heatmap_true_ordering(m, symm = TRUE, scale = "none")
  testthat::expect_false(identical(ordering$rowInd, seq_len(nrow(m))))

  info <- heatmap_layer_info(m, symm = TRUE, scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)
  data <- processor$extract_data(info)

  testthat::expect_equal(unlist(data$y), as.character(ordering$rowInd))
  testthat::expect_equal(unlist(data$x), as.character(ordering$colInd))
})

test_that("an unnamed unreordered heatmap keeps its 1..n labels", {
  m <- heatmap_unnamed_matrix()
  info <- heatmap_layer_info(m, Rowv = NA, Colv = NA, scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)

  data <- processor$extract_data(info)

  # Rowv/Colv = NA means rowInd/colInd are the identity, so the labels are
  # the plain sequence -- reversed on y, because revC does not apply.
  testthat::expect_equal(unlist(data$y), c("5", "4", "3", "2", "1"))
  testthat::expect_equal(unlist(data$x), c("1", "2", "3", "4"))
})

test_that("a named heatmap still carries its dimnames through unchanged", {
  m <- heatmap_unnamed_matrix()
  rownames(m) <- paste0("R", seq_len(nrow(m)))
  colnames(m) <- paste0("C", seq_len(ncol(m)))
  ordering <- heatmap_true_ordering(m, scale = "none")

  info <- heatmap_layer_info(m, scale = "none")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)
  data <- processor$extract_data(info)

  testthat::expect_equal(unlist(data$y), rev(rownames(m)[ordering$rowInd]))
  testthat::expect_equal(unlist(data$x), colnames(m)[ordering$colInd])
})

test_that("image() of an unnamed matrix keeps plain positional labels", {
  # image() does no reordering, so 1..n is genuinely what it draws.
  m <- heatmap_unnamed_matrix()
  info <- list(
    index = 1,
    function_name = "image",
    plot_call = list(function_name = "image", args = list(x = m))
  )
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(info)
  data <- processor$extract_data(info)

  # image() transposes: matrix rows run along x, columns along y.
  testthat::expect_equal(unlist(data$x), as.character(seq_len(nrow(m))))
  testthat::expect_equal(unlist(data$y), rev(as.character(seq_len(ncol(m)))))
})

test_that("a rendered unnamed heatmap lists the row labels it draws", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  m <- heatmap_unnamed_matrix()

  maidr:::clear_all_device_storage()
  grDevices::pdf(NULL)
  heatmap(m, scale = "none")
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  suppressWarnings(save_html(file = file))
  grDevices::dev.off()

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  raw <- regmatches(
    html, gregexpr('maidr-data="([^"]*)"', html, perl = TRUE)
  )[[1]]
  testthat::expect_gt(length(raw), 0)

  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  layer <- payload$subplots[[1]][[1]]$layers[[1]]

  # Row labels as drawn: axis(4) text nodes, read visually top to bottom.
  # gridSVG wraps the whole tree in translate(0, h) scale(1, -1), so a
  # LARGER y is higher up the page.
  doc <- xml2::read_html(html)
  nodes <- xml2::xml_find_all(
    doc,
    "//*[contains(@id,'right-axis-labels')][local-name()='text']"
  )
  testthat::expect_equal(length(nodes), 5L)
  label_y <- vapply(nodes, function(nd) {
    tf <- xml2::xml_attr(xml2::xml_parent(xml2::xml_parent(nd)), "transform")
    as.numeric(regmatches(tf, gregexpr("-?[0-9.]+", tf))[[1]])[2]
  }, numeric(1))
  drawn <- vapply(nodes, xml2::xml_text, character(1))[order(-label_y)]

  testthat::expect_equal(unlist(layer$data$y), drawn)
  # Guard: the drawing really is reordered, so this is not a trivial pass.
  testthat::expect_false(identical(drawn, c("5", "4", "3", "2", "1")))
})
