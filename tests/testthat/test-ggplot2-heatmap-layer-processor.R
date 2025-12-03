# Comprehensive tests for Ggplot2HeatmapLayerProcessor
# Testing heatmap layer processing, data extraction, and selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2HeatmapLayerProcessor initializes correctly", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2HeatmapLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2HeatmapLayerProcessor extract_data() works", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_true("points" %in% names(data))
  testthat::expect_true("x" %in% names(data))
  testthat::expect_true("y" %in% names(data))
  testthat::expect_true("fill_label" %in% names(data))
  testthat::expect_type(data$points, "list")
  testthat::expect_type(data$x, "character")
  testthat::expect_type(data$y, "character")
})

test_that("Ggplot2HeatmapLayerProcessor generate_selectors() works", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  expect_valid_selectors(selectors)
  testthat::expect_match(selectors, "rect")
})

test_that("Ggplot2HeatmapLayerProcessor process() integrates correctly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  result <- processor$process(p, layout, built, gt)

  expect_processor_output(result)
  testthat::expect_true("axes" %in% names(result))
  testthat::expect_type(result$axes, "list")
  testthat::expect_true("x" %in% names(result$axes))
  testthat::expect_true("y" %in% names(result$axes))
  testthat::expect_true("fill" %in% names(result$axes))
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("Ggplot2HeatmapLayerProcessor handles single cell heatmap", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1, y = 1, z = 10)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data$points), 1)
  testthat::expect_equal(length(data$x), 1)
  testthat::expect_equal(length(data$y), 1)
})

test_that("Ggplot2HeatmapLayerProcessor handles NA values", {
  testthat::skip_if_not_installed("ggplot2")

  df <- expand.grid(x = 1:3, y = 1:3)
  df$z <- c(1, 2, NA, 4, 5, 6, 7, 8, 9)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_true(any(sapply(data$points, function(row) any(is.na(row)))))
})

test_that("Ggplot2HeatmapLayerProcessor handles large heatmap", {
  testthat::skip_if_not_installed("ggplot2")

  df <- expand.grid(x = 1:20, y = 1:20)
  df$z <- runif(400)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data$points), 20)
  testthat::expect_equal(length(data$x), 20)
  testthat::expect_equal(length(data$y), 20)
})

test_that("Ggplot2HeatmapLayerProcessor handles character axes", {
  testthat::skip_if_not_installed("ggplot2")

  df <- expand.grid(
    x = c("A", "B", "C"),
    y = c("X", "Y", "Z")
  )
  df$z <- 1:9

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data$x), 3)
  testthat::expect_equal(length(data$y), 3)
  testthat::expect_true(all(c("A", "B", "C") %in% data$x))
})

# ==============================================================================
# Tier 3: Integration & Data Reordering
# ==============================================================================

test_that("Ggplot2HeatmapLayerProcessor needs_reordering() returns TRUE", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  testthat::expect_true(processor$needs_reordering())
})

test_that("Ggplot2HeatmapLayerProcessor reorder_layer_data() works", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  # Get original layer data
  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  reordered <- processor$reorder_layer_data(layer_data, p)

  testthat::expect_s3_class(reordered, "data.frame")
  testthat::expect_equal(nrow(reordered), nrow(layer_data))
})

test_that("Ggplot2HeatmapLayerProcessor reorder handles empty data", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  empty_data <- data.frame()
  reordered <- processor$reorder_layer_data(empty_data, p)

  testthat::expect_s3_class(reordered, "data.frame")
  testthat::expect_equal(nrow(reordered), 0)
})

test_that("Ggplot2HeatmapLayerProcessor axes extraction works", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  result <- processor$process(p, layout, built, gt)

  testthat::expect_equal(result$axes$x, "x")
  testthat::expect_equal(result$axes$y, "y")
  testthat::expect_equal(result$axes$fill, "z")
})

# ==============================================================================
# Tier 4: Heatmap-Specific Logic
# ==============================================================================

test_that("Ggplot2HeatmapLayerProcessor detects column mappings correctly", {
  testthat::skip_if_not_installed("ggplot2")

  df <- expand.grid(row = 1:3, col = 1:3)
  df$value <- 1:9

  # Custom column names
  p <- ggplot2::ggplot(df, ggplot2::aes(x = col, y = row, fill = value)) +
    ggplot2::geom_tile()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_equal(data$fill_label, "value")
})

test_that("Ggplot2HeatmapLayerProcessor handles layer-level mapping", {
  testthat::skip_if_not_installed("ggplot2")

  df <- expand.grid(x = 1:3, y = 1:3)
  df$z <- 1:9

  # Mapping in geom_tile instead of ggplot()
  p <- ggplot2::ggplot(df) +
    ggplot2::geom_tile(ggplot2::aes(x = x, y = y, fill = z))

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_true("points" %in% names(data))
})

test_that("Ggplot2HeatmapLayerProcessor matrix reversal works", {
  testthat::skip_if_not_installed("ggplot2")

  # Create simple 2x2 heatmap with known values
  df <- expand.grid(x = c(1, 2), y = c(1, 2))
  df$z <- c(1, 2, 3, 4)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # y_values should be reversed for DOM order
  testthat::expect_equal(length(data$y), 2)
  # Points should be reversed too
  testthat::expect_equal(length(data$points), 2)
})

test_that("Ggplot2HeatmapLayerProcessor handles scale limits", {
  testthat::skip_if_not_installed("ggplot2")

  df <- expand.grid(x = 1:5, y = 1:5)
  df$z <- df$x * df$y

  # Add custom scale limits
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile() +
    ggplot2::scale_x_continuous(limits = c(1, 5)) +
    ggplot2::scale_y_continuous(limits = c(1, 5))

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  reordered <- processor$reorder_layer_data(layer_data, p)

  testthat::expect_s3_class(reordered, "data.frame")
})

test_that("Ggplot2HeatmapLayerProcessor selector escapes dots", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  # CSS selector should have escaped dots (\\.)
  testthat::expect_match(selectors, "\\\\\\.")
})

test_that("Ggplot2HeatmapLayerProcessor handles NULL gt gracefully", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 0)
})

test_that("Ggplot2HeatmapLayerProcessor matrix construction is correct", {
  testthat::skip_if_not_installed("ggplot2")

  # Create 3x3 grid with specific pattern
  df <- expand.grid(x = 1:3, y = 1:3)
  df$z <- 1:9

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # Should have 3 rows (y-dimension)
  testthat::expect_equal(length(data$points), 3)
  # Each row should have 3 values (x-dimension)
  testthat::expect_equal(length(data$points[[1]]), 3)
})

# ==============================================================================
# Integration with Process Flow
# ==============================================================================

test_that("Ggplot2HeatmapLayerProcessor works in full pipeline", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_heatmap()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  result <- processor$process(p, layout, built, gt)

  # Validate full result
  expect_processor_output(result)
  testthat::expect_true("axes" %in% names(result))

  # Validate data format
  expect_maidr_data_format(result$data$points, "heatmap")
})
