# Comprehensive tests for BaseRLineLayerProcessor
# Testing single line, multiline, abline (regression, h, v), data extraction

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("BaseRLineLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "BaseRLineLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("BaseRLineLayerProcessor extract_data() works with single line", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(
      function_name = "plot",
      args = list(
        c(1, 2, 3, 4, 5),  # x
        c(2, 4, 6, 8, 10)  # y
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)  # Single series
  testthat::expect_equal(length(data[[1]]), 5)  # 5 points

  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 2)
})

test_that("BaseRLineLayerProcessor extract_data() works with multiline", {
  # Create matrix y for multiple lines
  x <- c(1, 2, 3)
  y_matrix <- matrix(c(10, 20, 30, 15, 25, 35), nrow = 3, ncol = 2)
  colnames(y_matrix) <- c("SeriesA", "SeriesB")

  layer_info <- list(
    index = 1,
    function_name = "matplot",
    plot_call = list(
      function_name = "matplot",
      args = list(x, y_matrix)
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 2)  # Two series
  testthat::expect_equal(length(data[[1]]), 3)  # 3 points per series

  # Check fill field
  testthat::expect_true("fill" %in% names(data[[1]][[1]]))
  testthat::expect_equal(data[[1]][[1]]$fill, "SeriesA")
  testthat::expect_equal(data[[2]][[1]]$fill, "SeriesB")
})

test_that("BaseRLineLayerProcessor process() returns correct structure", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(
      function_name = "plot",
      args = list(
        c(1, 2, 3),
        c(4, 5, 6),
        main = "Test Line",
        xlab = "X Axis",
        ylab = "Y Axis"
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)

  # Process with NULL gt (skip selector generation)
  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$type, "line")
  testthat::expect_equal(result$title, "Test Line")
  testthat::expect_equal(result$axes$x, "X Axis")
  testthat::expect_equal(result$axes$y, "Y Axis")
  testthat::expect_equal(length(result$data), 1)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("BaseRLineLayerProcessor handles NULL layer_info", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(NULL)
  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 0)
})

test_that("BaseRLineLayerProcessor handles mismatched x and y lengths", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(
      function_name = "plot",
      args = list(
        c(1, 2, 3, 4, 5),  # 5 elements
        c(10, 20, 30)      # 3 elements
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should use minimum length
  testthat::expect_equal(length(data[[1]]), 3)
})

test_that("BaseRLineLayerProcessor handles matrix without column names", {
  x <- c(1, 2, 3)
  y_matrix <- matrix(c(10, 20, 30, 15, 25, 35), nrow = 3, ncol = 2)
  # No colnames set

  layer_info <- list(
    index = 1,
    function_name = "matplot",
    plot_call = list(args = list(x, y_matrix))
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should generate default names
  testthat::expect_match(data[[1]][[1]]$fill, "Col")
  testthat::expect_match(data[[2]][[1]]$fill, "Col")
})

test_that("BaseRLineLayerProcessor handles single point line", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(args = list(5, 10))
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data[[1]]), 1)
  testthat::expect_equal(data[[1]][[1]]$x, "5")
  testthat::expect_equal(data[[1]][[1]]$y, 10)
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("BaseRLineLayerProcessor needs_reordering() returns FALSE", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))
  testthat::expect_false(processor$needs_reordering())
})

test_that("BaseRLineLayerProcessor extract_axis_titles() works", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(
      args = list(
        c(1, 2, 3),
        c(4, 5, 6),
        xlab = "Time",
        ylab = "Value"
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x, "Time")
  testthat::expect_equal(axes$y, "Value")
})

test_that("BaseRLineLayerProcessor extract_axis_titles() handles defaults", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(args = list(c(1, 2), c(3, 4)))
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x, "")
  testthat::expect_equal(axes$y, "")
})

test_that("BaseRLineLayerProcessor extract_main_title() works", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(
      args = list(
        c(1, 2, 3),
        c(4, 5, 6),
        main = "My Line Plot"
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "My Line Plot")
})

test_that("BaseRLineLayerProcessor extract_main_title() handles no title", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(args = list(c(1, 2), c(3, 4)))
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "")
})

# ==============================================================================
# Tier 4: Line-Specific Logic (abline support)
# ==============================================================================

test_that("BaseRLineLayerProcessor extract_single_line_data() returns correct structure", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))

  x <- c(1, 2, 3, 4)
  y <- c(10, 20, 15, 25)

  result <- processor$extract_single_line_data(x, y)

  testthat::expect_equal(length(result), 1)  # Single series
  testthat::expect_equal(length(result[[1]]), 4)  # 4 points
  testthat::expect_false("fill" %in% names(result[[1]][[1]]))  # No fill for single line
})

test_that("BaseRLineLayerProcessor extract_multiline_data() handles multiple columns", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))

  x <- c(1, 2, 3)
  y_matrix <- matrix(c(10, 20, 30, 15, 25, 35, 12, 22, 32), nrow = 3, ncol = 3)
  colnames(y_matrix) <- c("A", "B", "C")

  result <- processor$extract_multiline_data(x, y_matrix)

  testthat::expect_equal(length(result), 3)  # Three series
  testthat::expect_equal(result[[1]][[1]]$fill, "A")
  testthat::expect_equal(result[[2]][[1]]$fill, "B")
  testthat::expect_equal(result[[3]][[1]]$fill, "C")
})

test_that("BaseRLineLayerProcessor extract_abline_data() with lm object", {
  # Create simple linear model
  x_data <- c(1, 2, 3, 4, 5)
  y_data <- c(2, 4, 6, 8, 10)
  lm_model <- lm(y_data ~ x_data)

  layer_info <- list(
    index = 1,
    function_name = "abline",
    plot_call = list(args = list(lm_model)),
    group = list(
      high_call = list(args = list(x_data, y_data))
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_abline_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 2)  # abline has 2 endpoints
  testthat::expect_true("x" %in% names(data[[1]][[1]]))
  testthat::expect_true("y" %in% names(data[[1]][[1]]))
})

test_that("BaseRLineLayerProcessor extract_abline_data() with a and b parameters", {
  layer_info <- list(
    index = 1,
    function_name = "abline",
    plot_call = list(args = list(a = 0, b = 2)),  # y = 2x
    group = list(
      high_call = list(args = list(c(1, 2, 3), c(2, 4, 6)))
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_abline_data(layer_info)

  testthat::expect_equal(length(data[[1]]), 2)
})

test_that("BaseRLineLayerProcessor extract_abline_data() with h parameter (horizontal line)", {
  layer_info <- list(
    index = 1,
    function_name = "abline",
    plot_call = list(args = list(h = 5)),
    group = list(
      high_call = list(args = list(c(1, 2, 3, 4), c(2, 4, 6, 8)))
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_abline_data(layer_info)

  testthat::expect_equal(length(data[[1]]), 2)
  # Horizontal line: y should be constant
  testthat::expect_equal(data[[1]][[1]]$y, 5)
  testthat::expect_equal(data[[1]][[2]]$y, 5)
})

test_that("BaseRLineLayerProcessor extract_abline_data() with v parameter (vertical line)", {
  layer_info <- list(
    index = 1,
    function_name = "abline",
    plot_call = list(args = list(v = 2.5)),
    group = list(
      high_call = list(args = list(c(1, 2, 3, 4), c(10, 20, 30, 40)))
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_abline_data(layer_info)

  testthat::expect_equal(length(data[[1]]), 2)
  # Vertical line: x should be constant
  testthat::expect_equal(data[[1]][[1]]$x, 2.5)
  testthat::expect_equal(data[[1]][[2]]$x, 2.5)
})

test_that("BaseRLineLayerProcessor get_x_range_from_group() calculates with padding", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))

  group <- list(
    high_call = list(args = list(c(10, 20, 30), c(1, 2, 3)))
  )

  x_range <- processor$get_x_range_from_group(group)

  testthat::expect_length(x_range, 2)
  # Should have padding (5% on each side)
  testthat::expect_lt(x_range[1], 10)  # Min with padding < 10
  testthat::expect_gt(x_range[2], 30)  # Max with padding > 30
})

test_that("BaseRLineLayerProcessor get_x_range_from_group() handles NULL group", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))

  x_range <- processor$get_x_range_from_group(NULL)
  testthat::expect_null(x_range)
})

test_that("BaseRLineLayerProcessor get_y_range_from_group() calculates with padding", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))

  group <- list(
    high_call = list(args = list(c(1, 2, 3), c(100, 200, 300)))
  )

  y_range <- processor$get_y_range_from_group(group)

  testthat::expect_length(y_range, 2)
  testthat::expect_lt(y_range[1], 100)
  testthat::expect_gt(y_range[2], 300)
})

test_that("BaseRLineLayerProcessor extract_axis_titles() from high_call for low-level functions", {
  layer_info <- list(
    index = 1,
    function_name = "abline",
    plot_call = list(args = list(a = 0, b = 1)),
    group = list(
      high_call = list(
        args = list(
          c(1, 2, 3),
          c(1, 2, 3),
          xlab = "X from High",
          ylab = "Y from High"
        )
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  axes <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(axes$x, "X from High")
  testthat::expect_equal(axes$y, "Y from High")
})

test_that("BaseRLineLayerProcessor extract_main_title() from high_call for abline", {
  layer_info <- list(
    index = 1,
    function_name = "abline",
    plot_call = list(args = list(a = 0, b = 1)),
    group = list(
      high_call = list(
        args = list(c(1, 2, 3), c(1, 2, 3), main = "Title from High")
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  title <- processor$extract_main_title(layer_info)

  testthat::expect_equal(title, "Title from High")
})

test_that("BaseRLineLayerProcessor generate_selectors() handles NULL gt", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(args = list(c(1, 2), c(3, 4)))
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  selectors <- processor$generate_selectors(layer_info, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 0)
})

test_that("BaseRLineLayerProcessor handles abline detection", {
  layer_info <- list(
    index = 1,
    function_name = "abline",
    plot_call = list(args = list(a = 1, b = 2)),
    group = list(
      high_call = list(args = list(c(1, 2, 3), c(2, 4, 6)))
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  # Should route to extract_abline_data
  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 2)
})

test_that("BaseRLineLayerProcessor extracts all metadata correctly", {
  layer_info <- list(
    index = 1,
    function_name = "plot",
    plot_call = list(
      args = list(
        c(1, 2, 3, 4, 5),
        c(2, 4, 6, 8, 10),
        main = "Complete Line",
        xlab = "X Values",
        ylab = "Y Values"
      )
    )
  )

  processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)

  # Test data
  data <- processor$extract_data(layer_info)
  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 5)

  # Test title
  title <- processor$extract_main_title(layer_info)
  testthat::expect_equal(title, "Complete Line")

  # Test axes
  axes <- processor$extract_axis_titles(layer_info)
  testthat::expect_equal(axes$x, "X Values")
  testthat::expect_equal(axes$y, "Y Values")
})

# Selector tests with grob tree skipped - tested at orchestrator level
