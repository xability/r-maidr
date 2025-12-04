# Comprehensive tests for BaseRSmoothLayerProcessor
# Testing Base R smooth/density processing, multiple object types, data extraction

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("BaseRSmoothLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "BaseRSmoothLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("BaseRSmoothLayerProcessor extract_data() works with density object", {
  # Create density object
  test_data <- rnorm(100)
  dens_obj <- density(test_data)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(dens_obj)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_type(data[[1]], "list")
  testthat::expect_true(length(data[[1]]) > 0)

  # Check first point structure
  first_point <- data[[1]][[1]]
  testthat::expect_true("x" %in% names(first_point))
  testthat::expect_true("y" %in% names(first_point))
})

test_that("BaseRSmoothLayerProcessor process() returns correct structure", {
  dens_obj <- density(rnorm(50))

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        dens_obj,
        main = "Test Smooth",
        xlab = "X Axis",
        ylab = "Density"
      )
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)

  # Process with NULL gt (skip selector generation)
  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$type, "smooth")
  testthat::expect_equal(result$title, "Test Smooth")
  testthat::expect_equal(result$axes$x, "X Axis")
  testthat::expect_equal(result$axes$y, "Density")
  testthat::expect_equal(length(result$data), 1)
  testthat::expect_true(length(result$data[[1]]) > 0)
})

test_that("BaseRSmoothLayerProcessor handles NULL gt parameter", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list(density(rnorm(50)))
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  selectors <- processor$generate_selectors(layer_info, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 0)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("BaseRSmoothLayerProcessor handles NULL layer_info", {
  processor <- maidr:::BaseRSmoothLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(NULL)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 0)
})

test_that("BaseRSmoothLayerProcessor handles empty args", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list()
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 0)
})

test_that("BaseRSmoothLayerProcessor handles unrecognized object type", {
  # Pass something that's not a smooth object
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list("not a smooth object")
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 0)
})

test_that("BaseRSmoothLayerProcessor handles small density", {
  # Very small sample
  dens_obj <- density(rnorm(10))

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(dens_obj)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_true(length(data[[1]]) > 0)
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("BaseRSmoothLayerProcessor extract_axis_titles() works", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        density(rnorm(50)),
        xlab = "Value",
        ylab = "Density"
      )
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_type(axes, "list")
  testthat::expect_equal(axes$x, "Value")
  testthat::expect_equal(axes$y, "Density")
})

test_that("BaseRSmoothLayerProcessor extract_axis_titles() handles defaults", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list(density(rnorm(50)))
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x, "")
  testthat::expect_equal(axes$y, "")
})

test_that("BaseRSmoothLayerProcessor extract_main_title() works", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        density(rnorm(50)),
        main = "My Density Plot"
      )
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "My Density Plot")
})

test_that("BaseRSmoothLayerProcessor extract_main_title() handles no title", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list(density(rnorm(50)))
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "")
})

# ==============================================================================
# Tier 4: Smooth-Specific Logic (Multiple Object Types)
# ==============================================================================

test_that("BaseRSmoothLayerProcessor handles smooth.spline object", {
  # Create smooth.spline object
  x <- 1:20
  y <- sin(x / 3) + rnorm(20, sd = 0.1)
  spline_obj <- smooth.spline(x, y)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list(spline_obj)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_true(length(data[[1]]) > 0)

  # Check data structure
  first_point <- data[[1]][[1]]
  testthat::expect_type(first_point$x, "double")
  testthat::expect_type(first_point$y, "double")
})

test_that("BaseRSmoothLayerProcessor handles loess object", {
  # Create loess object
  x <- 1:20
  y <- x + rnorm(20, sd = 2)
  loess_obj <- loess(y ~ x)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list(loess_obj)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_true(length(data[[1]]) > 0)
})

test_that("BaseRSmoothLayerProcessor handles list with x,y (loess.smooth)", {
  # loess.smooth returns a list with x and y
  x <- 1:20
  y <- x + rnorm(20, sd = 2)
  smooth_list <- loess.smooth(x, y)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list(smooth_list)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_true(length(data[[1]]) > 0)
})

test_that("BaseRSmoothLayerProcessor handles two numeric vectors", {
  # Simulate predict(loess) result passed as two vectors
  x <- 1:10
  y <- seq(2, 20, by = 2)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "lines",
      args = list(x, y)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 10)

  # Check values
  testthat::expect_equal(data[[1]][[1]]$x, 1)
  testthat::expect_equal(data[[1]][[1]]$y, 2)
  testthat::expect_equal(data[[1]][[10]]$x, 10)
  testthat::expect_equal(data[[1]][[10]]$y, 20)
})

test_that("BaseRSmoothLayerProcessor data points have correct structure", {
  dens_obj <- density(rnorm(100))

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(dens_obj)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Outer list
  testthat::expect_equal(length(data), 1)

  # Inner list of points
  points <- data[[1]]
  testthat::expect_type(points, "list")

  # Each point should have x and y
  for (point in points[1:10]) { # Check first 10 points
    testthat::expect_type(point, "list")
    testthat::expect_true("x" %in% names(point))
    testthat::expect_true("y" %in% names(point))
    testthat::expect_type(point$x, "double")
    testthat::expect_type(point$y, "double")
  }
})

test_that("BaseRSmoothLayerProcessor density object preserves all points", {
  test_data <- rnorm(100)
  dens_obj <- density(test_data)
  n_points <- length(dens_obj$x)

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(dens_obj)
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should preserve all density points
  testthat::expect_equal(length(data[[1]]), n_points)
})

test_that("BaseRSmoothLayerProcessor extracts all metadata correctly", {
  dens_obj <- density(rnorm(100))

  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "plot",
      args = list(
        dens_obj,
        main = "Complete Smooth",
        xlab = "X Label",
        ylab = "Y Label"
      )
    )
  )

  processor <- maidr:::BaseRSmoothLayerProcessor$new(layer_info)

  # Test data extraction
  data <- processor$extract_data(layer_info)
  testthat::expect_equal(length(data), 1)
  testthat::expect_true(length(data[[1]]) > 0)

  # Test title extraction
  title <- processor$extract_main_title(layer_info)
  testthat::expect_equal(title, "Complete Smooth")

  # Test axes extraction
  axes <- processor$extract_axis_titles(layer_info)
  testthat::expect_equal(axes$x, "X Label")
  testthat::expect_equal(axes$y, "Y Label")
})

# Selector tests skipped - tested at orchestrator level
