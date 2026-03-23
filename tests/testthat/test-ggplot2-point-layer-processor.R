# Comprehensive tests for Ggplot2PointLayerProcessor
# Testing scatter plot processing, data extraction, axes with grid navigation,
# and selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2PointLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2PointLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2PointLayerProcessor extract_data() works with basic scatter", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = c(1, 2, 3, 4, 5), y = c(2, 4, 6, 8, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 5)

  # Check first point
  testthat::expect_equal(data[[1]]$x, 1)
  testthat::expect_equal(data[[1]]$y, 2)
})

test_that("Ggplot2PointLayerProcessor extract_data() handles color mapping", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = c(1, 2, 3),
    y = c(4, 5, 6),
    colour = c("A", "B", "A")
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, colour = colour)) +
    ggplot2::geom_point()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_equal(length(data), 3)
  # Color field should be present when colour column matches mapping name
  testthat::expect_true("color" %in% names(data[[1]]))
})

# ==============================================================================
# Tier 2: Axes with Grid Navigation Info
# ==============================================================================

test_that("Ggplot2PointLayerProcessor axes returns per-axis objects with labels", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:5, y = c(2, 4, 6, 8, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::labs(x = "X Variable", y = "Y Variable")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  axes <- processor$extract_axes_labels(p, built)

  # Should return per-axis objects
  testthat::expect_type(axes, "list")
  testthat::expect_type(axes$x, "list")
  testthat::expect_type(axes$y, "list")

  # Labels should be present
  testthat::expect_equal(axes$x$label, "X Variable")
  testthat::expect_equal(axes$y$label, "Y Variable")
})

test_that("Ggplot2PointLayerProcessor axes includes grid info for continuous scales", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = c(1, 2, 3, 4, 5), y = c(10, 20, 30, 40, 50))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::labs(x = "X", y = "Y")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  axes <- processor$extract_axes_labels(p, built)

  # Grid fields should be present for continuous numeric data
  testthat::expect_true(!is.null(axes$x$min))
  testthat::expect_true(!is.null(axes$x$max))
  testthat::expect_true(!is.null(axes$x$tickStep))
  testthat::expect_true(!is.null(axes$y$min))
  testthat::expect_true(!is.null(axes$y$max))
  testthat::expect_true(!is.null(axes$y$tickStep))

  # Validate constraints
  testthat::expect_true(axes$x$min < axes$x$max)
  testthat::expect_true(axes$y$min < axes$y$max)
  testthat::expect_true(axes$x$tickStep > 0)
  testthat::expect_true(axes$y$tickStep > 0)
  testthat::expect_true(axes$x$tickStep <= (axes$x$max - axes$x$min))
  testthat::expect_true(axes$y$tickStep <= (axes$y$max - axes$y$min))
})

test_that("Ggplot2PointLayerProcessor extract_axis_grid_info returns valid values", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = seq(4.3, 7.9, length.out = 50), y = seq(2, 4.4, length.out = 50))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)

  x_grid <- processor$extract_axis_grid_info(built, "x")
  y_grid <- processor$extract_axis_grid_info(built, "y")

  # Both should return non-NULL results
  testthat::expect_true(!is.null(x_grid))
  testthat::expect_true(!is.null(y_grid))

  # Validate structure
  testthat::expect_true(is.numeric(x_grid$min))
  testthat::expect_true(is.numeric(x_grid$max))
  testthat::expect_true(is.numeric(x_grid$tickStep))
  testthat::expect_true(x_grid$min < x_grid$max)
  testthat::expect_true(x_grid$tickStep > 0)
})

test_that("Ggplot2PointLayerProcessor grid info works with iris-like data", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(iris, ggplot2::aes(x = Sepal.Length, y = Sepal.Width)) +
    ggplot2::geom_point() +
    ggplot2::labs(x = "Sepal Length", y = "Sepal Width")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  axes <- processor$extract_axes_labels(p, built)

  testthat::expect_equal(axes$x$label, "Sepal Length")
  testthat::expect_equal(axes$y$label, "Sepal Width")

  # Grid info should be present
  testthat::expect_true(!is.null(axes$x$min))
  testthat::expect_true(!is.null(axes$x$max))
  testthat::expect_true(!is.null(axes$x$tickStep))

  # Data range should be reasonable for iris Sepal.Length
  testthat::expect_true(axes$x$min <= min(iris$Sepal.Length))
  testthat::expect_true(axes$x$max >= max(iris$Sepal.Length))
})

test_that("Ggplot2PointLayerProcessor process() returns axes with grid info", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:10, y = (1:10)^2)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::labs(x = "X", y = "Y", title = "Test")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layout <- list(
    title = "Test",
    axes = list(x = "X", y = "Y")
  )

  result <- processor$process(p, layout, built)

  # Check result structure
  testthat::expect_type(result, "list")
  testthat::expect_true("axes" %in% names(result))

  # Axes should have per-axis objects
  testthat::expect_type(result$axes$x, "list")
  testthat::expect_type(result$axes$y, "list")
  testthat::expect_equal(result$axes$x$label, "X")
  testthat::expect_equal(result$axes$y$label, "Y")

  # Grid fields should be present
  testthat::expect_true(!is.null(result$axes$x$min))
  testthat::expect_true(!is.null(result$axes$x$tickStep))
})

# ==============================================================================
# Tier 3: Edge Cases
# ==============================================================================

test_that("Ggplot2PointLayerProcessor axes without explicit labels", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(myvar = 1:5, othervar = c(2, 4, 6, 8, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = myvar, y = othervar)) +
    ggplot2::geom_point()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2PointLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  axes <- processor$extract_axes_labels(p, built)

  # Should fall back to mapping variable names
  testthat::expect_equal(axes$x$label, "myvar")
  testthat::expect_equal(axes$y$label, "othervar")
})
