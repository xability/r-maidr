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
  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$type, "heat")
  testthat::expect_equal(result$title, "Test Heatmap")
  testthat::expect_equal(result$axes$x, "X Axis")
  testthat::expect_equal(result$axes$y, "Y Axis")
  testthat::expect_equal(result$axes$fill, "value")
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
  testthat::expect_equal(axes$x, "Columns")
  testthat::expect_equal(axes$y, "Rows")
  testthat::expect_equal(axes$fill, "value") # Default fill label
})

test_that("BaseRHeatmapLayerProcessor extract_axis_titles() handles defaults", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "image",
      args = structure(list(matrix(1:4, 2, 2)), names = "")
    )
  )

  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x, "")
  testthat::expect_equal(axes$y, "")
  testthat::expect_equal(axes$fill, "value")
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
  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info)

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
  testthat::expect_equal(axes$x, "X Label")
  testthat::expect_equal(axes$y, "Y Label")
  testthat::expect_equal(axes$fill, "value")
})

# Selector tests skipped - tested at orchestrator level
