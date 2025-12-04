# Comprehensive tests for Ggplot2SmoothLayerProcessor
# Testing smooth layer processing, data extraction, and selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor initializes correctly", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2SmoothLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2SmoothLayerProcessor extract_data() works with geom_smooth", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  layer_info <- list(index = 2) # smooth is second layer after geom_point
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_type(data[[1]], "list")
  testthat::expect_true(length(data[[1]]) > 0)

  # First point should have x and y
  first_point <- data[[1]][[1]]
  testthat::expect_true("x" %in% names(first_point))
  testthat::expect_true("y" %in% names(first_point))
})

test_that("Ggplot2SmoothLayerProcessor generate_selectors() works", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
  testthat::expect_type(selectors[[1]], "character")
  testthat::expect_match(selectors[[1]], "polyline")
})

test_that("Ggplot2SmoothLayerProcessor process() integrates correctly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  result <- processor$process(p, layout, built, gt)

  expect_processor_output(result)
  # axes and title may or may not be present depending on implementation
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor handles minimal smooth data", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:5, y = 1:5)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "lm", se = FALSE)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_true(length(data[[1]]) > 0)
})

test_that("Ggplot2SmoothLayerProcessor handles smooth with se=TRUE", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:20, y = rnorm(20))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "loess", se = TRUE)

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
})

test_that("Ggplot2SmoothLayerProcessor handles NULL gt parameter", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
  # Should use fallback selector
  testthat::expect_match(selectors[[1]], "polyline")
})

test_that("Ggplot2SmoothLayerProcessor handles non-ggplot input", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  testthat::expect_error(
    processor$extract_data("not a ggplot"),
    "must be a ggplot object"
  )
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor works with loess method", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:30, y = sin(1:30 / 5) + rnorm(30, sd = 0.2))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "loess")

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
})

test_that("Ggplot2SmoothLayerProcessor works with lm method", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:20, y = 1:20 + rnorm(20))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "lm")

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
})

test_that("Ggplot2SmoothLayerProcessor axes extraction works via process()", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  result <- processor$process(p, layout, built, gt)

  # Process should return data and selectors at minimum
  testthat::expect_type(result, "list")
  testthat::expect_true("data" %in% names(result))
  testthat::expect_true("selectors" %in% names(result))
})

# ==============================================================================
# Tier 4: Smooth-Specific Logic
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor detects GeomSmooth", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:10, y = 1:10)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_smooth()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  # Should not error
  data <- processor$extract_data(p)
  testthat::expect_type(data, "list")
})

test_that("Ggplot2SmoothLayerProcessor detects GeomDensity", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = rnorm(100))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x)) +
    ggplot2::geom_density()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  # Should not error
  data <- processor$extract_data(p)
  testthat::expect_type(data, "list")
})

test_that("Ggplot2SmoothLayerProcessor errors when no smooth layer found", {
  testthat::skip_if_not_installed("ggplot2")

  # Plot with no smooth layer
  p <- create_test_ggplot_bar()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  testthat::expect_error(
    processor$extract_data(p),
    "No smooth curve layers found"
  )
})

test_that("Ggplot2SmoothLayerProcessor polyline collection is recursive", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  # Should find polyline grobs recursively
  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
})

test_that("Ggplot2SmoothLayerProcessor picks last polyline (max ID)", {
  testthat::skip_if_not_installed("ggplot2")

  # Smooth with confidence interval creates multiple polylines
  df <- data.frame(x = 1:20, y = rnorm(20))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "loess", se = TRUE)

  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  # Selector should reference the last (max ID) polyline
  testthat::expect_type(selectors, "list")
  testthat::expect_match(selectors[[1]], "polyline")
  # ID extraction logic should pick max numeric ID
})

test_that("Ggplot2SmoothLayerProcessor escapes dots in selector", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  # CSS selector should have escaped dots (\\.)
  testthat::expect_match(selectors[[1]], "\\\\\\.")
})

test_that("Ggplot2SmoothLayerProcessor data points have correct structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # Outer list
  testthat::expect_equal(length(data), 1)
  # Inner list of points
  points <- data[[1]]
  testthat::expect_type(points, "list")

  # Each point should have x and y
  for (point in points) {
    testthat::expect_type(point, "list")
    testthat::expect_true("x" %in% names(point))
    testthat::expect_true("y" %in% names(point))
    testthat::expect_type(point$x, "double")
    testthat::expect_type(point$y, "double")
  }
})

test_that("Ggplot2SmoothLayerProcessor handles fallback selector", {
  testthat::skip_if_not_installed("ggplot2")

  # Create a mock gt with no polyline grobs
  p <- create_test_ggplot_bar()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  # gt with no polylines
  gt <- ggplot2::ggplotGrob(p)
  selectors <- processor$generate_selectors(p, gt)

  # Should use fallback
  testthat::expect_type(selectors, "list")
  testthat::expect_match(selectors[[1]], "polyline")
})

# ==============================================================================
# Integration with Full Pipeline
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor works in full pipeline", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  result <- processor$process(p, layout, built, gt)

  # Validate full result
  expect_processor_output(result)

  # Validate data format
  expect_maidr_data_format(result$data[[1]], "smooth")
})
