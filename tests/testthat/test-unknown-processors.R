# Comprehensive tests for Unknown Layer Processors
# Testing Ggplot2UnknownLayerProcessor and BaseRUnknownLayerProcessor

# ==============================================================================
# Ggplot2UnknownLayerProcessor Tests
# ==============================================================================

test_that("Ggplot2UnknownLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  testthat::expect_s3_class(processor, "Ggplot2UnknownLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
  testthat::expect_true(R6::is.R6(processor))
})

test_that("Ggplot2UnknownLayerProcessor inherits from LayerProcessor", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  testthat::expect_true(inherits(processor, "LayerProcessor"))
})

test_that("Ggplot2UnknownLayerProcessor stores layer_info", {
  layer_info <- list(index = 5, type = "unknown")
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  testthat::expect_equal(processor$get_layer_index(), 5)
})

test_that("Ggplot2UnknownLayerProcessor extract_data returns empty list", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  result <- processor$extract_data(NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("Ggplot2UnknownLayerProcessor extract_data with built returns empty list", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  # Create a real built object
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  built <- ggplot2::ggplot_build(p)

  result <- processor$extract_data(p, built)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("Ggplot2UnknownLayerProcessor generate_selectors returns empty list", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  result <- processor$generate_selectors(NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("Ggplot2UnknownLayerProcessor generate_selectors with gt returns empty list", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  gt <- ggplot2::ggplotGrob(p)

  result <- processor$generate_selectors(p, gt)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("Ggplot2UnknownLayerProcessor process returns proper structure", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- list(
    title = "Test Plot",
    axes = list(x = "mpg", y = "wt")
  )

  result <- processor$process(p, layout, gt)

  testthat::expect_type(result, "list")
  testthat::expect_true("data" %in% names(result))
  testthat::expect_true("selectors" %in% names(result))
  testthat::expect_true("title" %in% names(result))
  testthat::expect_true("axes" %in% names(result))

  # Data and selectors should be empty
  testthat::expect_equal(length(result$data), 0)
  testthat::expect_equal(length(result$selectors), 0)

  # Title should be passed through
  testthat::expect_equal(result$title, "Test Plot")
})

test_that("Ggplot2UnknownLayerProcessor process handles NULL layout title", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  layout <- list(axes = list(x = "mpg", y = "wt"))

  result <- processor$process(p, layout, NULL)

  testthat::expect_equal(result$title, "")
})

test_that("Ggplot2UnknownLayerProcessor process extracts axes", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  layout <- list(axes = list(x = "X Axis", y = "Y Axis"))

  result <- processor$process(p, layout, NULL)

  testthat::expect_type(result$axes, "list")
  testthat::expect_true("x" %in% names(result$axes))
  testthat::expect_true("y" %in% names(result$axes))
})

# ==============================================================================
# BaseRUnknownLayerProcessor Tests
# ==============================================================================

test_that("BaseRUnknownLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  testthat::expect_s3_class(processor, "BaseRUnknownLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
  testthat::expect_true(R6::is.R6(processor))
})

test_that("BaseRUnknownLayerProcessor inherits from LayerProcessor", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  testthat::expect_true(inherits(processor, "LayerProcessor"))
})

test_that("BaseRUnknownLayerProcessor stores layer_info", {
  layer_info <- list(index = 3, type = "unknown")
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  testthat::expect_equal(processor$get_layer_index(), 3)
})

test_that("BaseRUnknownLayerProcessor needs_reordering returns FALSE", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$needs_reordering()

  testthat::expect_false(result)
})

test_that("BaseRUnknownLayerProcessor extract_data returns empty list", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$extract_data(NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("BaseRUnknownLayerProcessor extract_data with layer_info returns empty list", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "unknown_plot",
      args = list(1:10)
    )
  )
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$extract_data(layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("BaseRUnknownLayerProcessor generate_selectors returns empty list", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$generate_selectors(NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("BaseRUnknownLayerProcessor generate_selectors with layer_info returns empty list", {
  layer_info <- list(
    index = 1,
    plot_call = list(function_name = "unknown")
  )
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$generate_selectors(layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("BaseRUnknownLayerProcessor process returns proper structure", {
  layer_info <- list(
    index = 1,
    plot_call = list(
      function_name = "unknown_plot",
      args = list(1:10)
    )
  )
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_type(result, "list")
  testthat::expect_true("data" %in% names(result))
  testthat::expect_true("selectors" %in% names(result))
  testthat::expect_true("type" %in% names(result))
  testthat::expect_true("title" %in% names(result))
  testthat::expect_true("axes" %in% names(result))
})

test_that("BaseRUnknownLayerProcessor process returns correct type", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_equal(result$type, "unknown")
})

test_that("BaseRUnknownLayerProcessor process returns default title", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_equal(result$title, "Unknown Plot Type")
})

test_that("BaseRUnknownLayerProcessor process returns default axes", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_type(result$axes, "list")
  testthat::expect_equal(result$axes$x, "X")
  testthat::expect_equal(result$axes$y, "Y")
})

test_that("BaseRUnknownLayerProcessor process returns empty data", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_type(result$data, "list")
  testthat::expect_equal(length(result$data), 0)
})

test_that("BaseRUnknownLayerProcessor process returns empty selectors", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_type(result$selectors, "list")
  testthat::expect_equal(length(result$selectors), 0)
})

# ==============================================================================
# Factory Integration Tests
# ==============================================================================

test_that("Ggplot2ProcessorFactory creates unknown processor for unsupported types", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("nonexistent_type", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2UnknownLayerProcessor")
})

test_that("BaseRProcessorFactory creates unknown processor for unsupported types", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("nonexistent_type", layer_info)

  testthat::expect_s3_class(processor, "BaseRUnknownLayerProcessor")
})

test_that("Unknown processors can be used in processing pipeline", {
  testthat::skip_if_not_installed("ggplot2")

  # Create unknown processor
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  # Create a minimal plot
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  layout <- list(axes = list(x = "mpg", y = "wt"))

  # Process should work without error
  result <- processor$process(p, layout, NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result$data), 0)
  testthat::expect_equal(length(result$selectors), 0)
})

# ==============================================================================
# Edge Cases Tests
# ==============================================================================

test_that("Ggplot2UnknownLayerProcessor handles NULL everything", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info)

  # Should not error
  result <- processor$process(NULL, list(), NULL)

  testthat::expect_type(result, "list")
})

test_that("BaseRUnknownLayerProcessor handles NULL everything", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRUnknownLayerProcessor$new(layer_info)

  # Should not error
  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
  )

  testthat::expect_type(result, "list")
})

test_that("Unknown processors are independent instances", {
  layer_info1 <- list(index = 1)
  layer_info2 <- list(index = 2)

  processor1 <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info1)
  processor2 <- maidr:::Ggplot2UnknownLayerProcessor$new(layer_info2)

  testthat::expect_equal(processor1$get_layer_index(), 1)
  testthat::expect_equal(processor2$get_layer_index(), 2)

  # Setting result on one should not affect the other
  processor1$set_last_result(list(test = "value1"))

  testthat::expect_equal(processor1$get_last_result()$test, "value1")
  testthat::expect_null(processor2$get_last_result())
})
