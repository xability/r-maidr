# Comprehensive tests for BaseRPointLayerProcessor
# Testing Base R scatter plot processing, data extraction, and selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("BaseRPointLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "BaseRPointLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("BaseRPointLayerProcessor extract_data() works with basic points", {
  # Create mock layer_info
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3, 4, 5),
        y = c(2, 4, 6, 8, 10)
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 5)

  # Check first point
  testthat::expect_equal(data[[1]]$x, 1)
  testthat::expect_equal(data[[1]]$y, 2)
})

test_that("BaseRPointLayerProcessor extract_data() handles colors", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3),
        y = c(4, 5, 6),
        col = c("red", "blue", "green")
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 3)
  testthat::expect_equal(data[[1]]$color, "red")
  testthat::expect_equal(data[[2]]$color, "blue")
  testthat::expect_equal(data[[3]]$color, "green")
})

# Skipping process() test - grob infrastructure tested at orchestrator level
test_that("BaseRPointLayerProcessor process() returns correct type", {
  # Test that process() calls extract_data and extract_axis_titles correctly
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3),
        y = c(4, 5, 6),
        xlab = "X",
        ylab = "Y",
        main = "Test"
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)

  # Process with NULL gt will skip selector generation
  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$type, "point")
  testthat::expect_equal(result$title, "Test")
  testthat::expect_equal(result$axes$x, "X")
  testthat::expect_equal(result$axes$y, "Y")
  testthat::expect_equal(length(result$data), 3)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("BaseRPointLayerProcessor handles single point", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(x = 5, y = 10)
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(data[[1]]$x, 5)
  testthat::expect_equal(data[[1]]$y, 10)
})

test_that("BaseRPointLayerProcessor handles NULL layer_info", {
  processor <- maidr:::BaseRPointLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(NULL)
  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 0)
})

test_that("BaseRPointLayerProcessor handles mismatched x and y lengths", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3, 4, 5),
        y = c(10, 20, 30) # Shorter
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should use minimum length
  testthat::expect_equal(length(data), 3)
})

test_that("BaseRPointLayerProcessor handles single color for multiple points", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3),
        y = c(4, 5, 6),
        col = "blue" # Single color
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # All points should have the same color
  testthat::expect_equal(data[[1]]$color, "blue")
  testthat::expect_equal(data[[2]]$color, "blue")
  testthat::expect_equal(data[[3]]$color, "blue")
})

test_that("BaseRPointLayerProcessor handles NULL or missing values", {
  # Test with NULL x value
  layer_info_null_x <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(NULL, c(1, 2, 3))
    )
  )

  # Test with NULL y value
  layer_info_null_y <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(c(1, 2, 3), NULL)
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(list(index = 1))

  # Should return empty list for NULL values
  data1 <- processor$extract_data(layer_info_null_x)
  data2 <- processor$extract_data(layer_info_null_y)

  testthat::expect_equal(length(data1), 0)
  testthat::expect_equal(length(data2), 0)
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("BaseRPointLayerProcessor needs_reordering() returns FALSE", {
  processor <- maidr:::BaseRPointLayerProcessor$new(list(index = 1))
  testthat::expect_false(processor$needs_reordering())
})

test_that("BaseRPointLayerProcessor extract_axis_titles() works", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3),
        y = c(4, 5, 6),
        xlab = "X Axis",
        ylab = "Y Axis"
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_type(axes, "list")
  testthat::expect_equal(axes$x, "X Axis")
  testthat::expect_equal(axes$y, "Y Axis")
})

test_that("BaseRPointLayerProcessor extract_axis_titles() handles defaults", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(x = c(1, 2), y = c(3, 4))
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x, "")
  testthat::expect_equal(axes$y, "")
})

test_that("BaseRPointLayerProcessor extract_main_title() works", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3),
        y = c(4, 5, 6),
        main = "Test Scatter Plot"
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "Test Scatter Plot")
})

test_that("BaseRPointLayerProcessor extract_main_title() handles no title", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(x = c(1, 2), y = c(3, 4))
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "")
})

# ==============================================================================
# Tier 4: Point-Specific Logic
# ==============================================================================

# Selector generation tests skipped - tested at orchestrator level

test_that("BaseRPointLayerProcessor handles NULL gt parameter", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(x = c(1, 2), y = c(3, 4))
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  selectors <- processor$generate_selectors(layer_info, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 0)
})

# Additional selector tests skipped - tested at orchestrator level

test_that("BaseRPointLayerProcessor handles points() function", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "points", # points() instead of plot()
      args = list(
        x = c(5, 6, 7),
        y = c(8, 9, 10)
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 3)
  testthat::expect_equal(data[[1]]$x, 5)
  testthat::expect_equal(data[[1]]$y, 8)
})

test_that("BaseRPointLayerProcessor color handling with partial vector", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = c(1, 2, 3, 4, 5),
        y = c(2, 4, 6, 8, 10),
        col = c("red", "blue") # Partial color vector
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # First two points should have colors
  testthat::expect_equal(data[[1]]$color, "red")
  testthat::expect_equal(data[[2]]$color, "blue")

  # Points 3-5 should not have color field (or handle appropriately)
  testthat::expect_false("color" %in% names(data[[3]]))
})

# ==============================================================================
# Integration with Full Pipeline
# ==============================================================================

test_that("BaseRPointLayerProcessor extracts all metadata correctly", {
  # Test data extraction, axis titles, and main title together
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        x = 1:5,
        y = c(2, 4, 6, 8, 10),
        main = "Complete Test",
        xlab = "X Values",
        ylab = "Y Values",
        col = "red"
      )
    )
  )

  processor <- maidr:::BaseRPointLayerProcessor$new(layer_info)

  # Test data extraction
  data <- processor$extract_data(layer_info)
  testthat::expect_equal(length(data), 5)
  testthat::expect_equal(data[[1]]$color, "red")

  # Test title extraction
  title <- processor$extract_main_title(layer_info)
  testthat::expect_equal(title, "Complete Test")

  # Test axes extraction
  axes <- processor$extract_axis_titles(layer_info)
  testthat::expect_equal(axes$x, "X Values")
  testthat::expect_equal(axes$y, "Y Values")
})
