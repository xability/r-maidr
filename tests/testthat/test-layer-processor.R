# Comprehensive tests for LayerProcessor base class
# Testing abstract interface, default implementations, and utility methods

# ==============================================================================
# LayerProcessor Initialization Tests
# ==============================================================================

test_that("LayerProcessor can be instantiated", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_s3_class(processor, "LayerProcessor")
  testthat::expect_true(R6::is.R6(processor))
})

test_that("LayerProcessor stores layer_info correctly", {
  layer_info <- list(index = 3, type = "bar", extra = "data")
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_identical(processor$layer_info, layer_info)
  testthat::expect_equal(processor$layer_info$index, 3)
  testthat::expect_equal(processor$layer_info$type, "bar")
  testthat::expect_equal(processor$layer_info$extra, "data")
})

test_that("LayerProcessor handles NULL layer_info", {
  processor <- maidr:::LayerProcessor$new(NULL)

  testthat::expect_null(processor$layer_info)
})

# ==============================================================================
# Abstract Method Tests
# ==============================================================================

test_that("LayerProcessor process() is abstract", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_error(
    processor$process(NULL, NULL),
    "process\\(\\) method must be implemented by subclasses"
  )
})

test_that("LayerProcessor extract_data() is abstract", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_error(
    processor$extract_data(NULL),
    "extract_data\\(\\) method must be implemented by subclasses"
  )
})

test_that("LayerProcessor generate_selectors() is abstract", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_error(
    processor$generate_selectors(NULL),
    "generate_selectors\\(\\) method must be implemented by subclasses"
  )
})

# ==============================================================================
# Default Method Tests
# ==============================================================================

test_that("LayerProcessor needs_reordering() returns FALSE by default", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  result <- processor$needs_reordering()
  testthat::expect_false(result)
})

test_that("LayerProcessor reorder_layer_data() returns data unchanged by default", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  test_data <- data.frame(x = 1:5, y = 6:10)
  result <- processor$reorder_layer_data(test_data, NULL)

  testthat::expect_identical(result, test_data)
})

test_that("LayerProcessor reorder_layer_data() handles NULL data", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  result <- processor$reorder_layer_data(NULL, NULL)
  testthat::expect_null(result)
})

# ==============================================================================
# get_layer_index Tests
# ==============================================================================

test_that("LayerProcessor get_layer_index() returns correct index", {
  layer_info <- list(index = 5)
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_equal(processor$get_layer_index(), 5)
})

test_that("LayerProcessor get_layer_index() returns NULL for missing index", {
  layer_info <- list(type = "bar")
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_null(processor$get_layer_index())
})

test_that("LayerProcessor get_layer_index() returns NULL for NULL layer_info", {
  processor <- maidr:::LayerProcessor$new(NULL)

  testthat::expect_null(processor$get_layer_index())
})

# ==============================================================================
# Last Result Storage Tests
# ==============================================================================

test_that("LayerProcessor set_last_result() stores result", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  test_result <- list(data = list(x = 1), selectors = "test")
  processor$set_last_result(test_result)

  testthat::expect_identical(processor$get_last_result(), test_result)
})

test_that("LayerProcessor get_last_result() returns NULL initially", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_null(processor$get_last_result())
})

test_that("LayerProcessor set_last_result() returns result invisibly", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  test_result <- list(data = list(x = 1))
  returned <- processor$set_last_result(test_result)

  testthat::expect_identical(returned, test_result)
})

test_that("LayerProcessor set_last_result() can overwrite previous result", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  result1 <- list(data = "first")
  result2 <- list(data = "second")

  processor$set_last_result(result1)
  testthat::expect_equal(processor$get_last_result()$data, "first")

  processor$set_last_result(result2)
  testthat::expect_equal(processor$get_last_result()$data, "second")
})

# ==============================================================================
# extract_layer_axes Tests
# ==============================================================================

test_that("LayerProcessor extract_layer_axes() uses layout axes as fallback", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  layout <- list(axes = list(x = "X Label", y = "Y Label"))

  # Create a minimal ggplot object
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- processor$extract_layer_axes(p, layout)

  testthat::expect_type(result, "list")
  testthat::expect_true("x" %in% names(result))
  testthat::expect_true("y" %in% names(result))
})

test_that("LayerProcessor extract_layer_axes() handles NULL layout axes", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  layout <- list(axes = NULL)

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- processor$extract_layer_axes(p, layout)

  testthat::expect_type(result, "list")
  testthat::expect_true("x" %in% names(result))
  testthat::expect_true("y" %in% names(result))
})

test_that("LayerProcessor extract_layer_axes() handles empty layout", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  layout <- list()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- processor$extract_layer_axes(p, layout)

  testthat::expect_type(result, "list")
})

test_that("LayerProcessor extract_layer_axes() extracts layer-specific mapping", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  layout <- list(axes = list(x = "default_x", y = "default_y"))

  # Layer-specific mapping should override plot mapping
  p <- ggplot2::ggplot(mtcars) +
    ggplot2::geom_point(ggplot2::aes(x = disp, y = hp))

  result <- processor$extract_layer_axes(p, layout)

  testthat::expect_equal(result$x, "disp")
  testthat::expect_equal(result$y, "hp")
})

# ==============================================================================
# apply_scale_mapping Tests
# ==============================================================================

test_that("LayerProcessor apply_scale_mapping() works with valid mapping", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  numeric_values <- c(1, 2, 3)
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- processor$apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result), c("A", "B", "C"))
})

test_that("LayerProcessor apply_scale_mapping() returns input for NULL mapping", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  numeric_values <- c(1, 2, 3)

  result <- processor$apply_scale_mapping(numeric_values, NULL)

  testthat::expect_equal(result, numeric_values)
})

# ==============================================================================
# Subclass Inheritance Tests
# ==============================================================================

test_that("Subclasses inherit LayerProcessor interface", {
  # Test with a real subclass
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  testthat::expect_s3_class(processor, "LayerProcessor")
  testthat::expect_true(R6::is.R6(processor))

  # Should be able to call inherited methods
  testthat::expect_equal(processor$get_layer_index(), 1)
  testthat::expect_type(processor$needs_reordering(), "logical")
})

test_that("Subclasses can override default methods", {
  testthat::skip_if_not_installed("ggplot2")

  # Heatmap processor overrides needs_reordering
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(layer_info)

  # Heatmap processor typically returns TRUE for needs_reordering
  result <- processor$needs_reordering()
  testthat::expect_type(result, "logical")
})

test_that("Multiple subclass instances are independent", {
  layer_info1 <- list(index = 1)
  layer_info2 <- list(index = 2)

  processor1 <- maidr:::LayerProcessor$new(layer_info1)
  processor2 <- maidr:::LayerProcessor$new(layer_info2)

  processor1$set_last_result(list(data = "first"))
  processor2$set_last_result(list(data = "second"))

  testthat::expect_equal(processor1$get_last_result()$data, "first")
  testthat::expect_equal(processor2$get_last_result()$data, "second")
})

# ==============================================================================
# Edge Case Tests
# ==============================================================================

test_that("LayerProcessor handles complex layer_info", {
  layer_info <- list(
    index = 1,
    type = "bar",
    geom_class = "GeomBar",
    stat_class = "StatCount",
    position_class = "PositionStack",
    nested = list(a = 1, b = 2)
  )
  processor <- maidr:::LayerProcessor$new(layer_info)

  testthat::expect_equal(processor$layer_info$geom_class, "GeomBar")
  testthat::expect_equal(processor$layer_info$nested$a, 1)
})

test_that("LayerProcessor can store arbitrary result types", {
  layer_info <- list(index = 1)
  processor <- maidr:::LayerProcessor$new(layer_info)

  # Store a complex result
  complex_result <- list(
    data = list(
      points = list(list(x = 1, y = 2), list(x = 3, y = 4)),
      labels = c("A", "B")
    ),
    selectors = c("g.geom-bar rect:nth-child(1)", "g.geom-bar rect:nth-child(2)"),
    type = "bar",
    axes = list(x = "category", y = "count")
  )

  processor$set_last_result(complex_result)
  retrieved <- processor$get_last_result()

  testthat::expect_identical(retrieved, complex_result)
  testthat::expect_equal(length(retrieved$data$points), 2)
  testthat::expect_equal(length(retrieved$selectors), 2)
})
