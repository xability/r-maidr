# Comprehensive tests for Ggplot2LineLayerProcessor
# Testing single line, multiline, faceted plots, selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2LineLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2LineLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2LineLayerProcessor extract_data() works with single line", {
  # Create simple line plot
  df <- data.frame(x = 1:5, y = c(2, 4, 6, 8, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1) # Single line series
  testthat::expect_equal(length(data[[1]]), 5) # 5 points

  # Check first point structure
  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 2)
})

test_that("Ggplot2LineLayerProcessor extract_data() works with multiline", {
  # Create multiline plot
  df <- data.frame(
    x = rep(1:5, 2),
    y = c(1, 2, 3, 4, 5, 5, 4, 3, 2, 1),
    group = rep(c("A", "B"), each = 5)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = group)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 2) # Two line series
  testthat::expect_equal(length(data[[1]]), 5) # 5 points per series

  # Check fill field exists (group name)
  testthat::expect_true("fill" %in% names(data[[1]][[1]]))
  testthat::expect_equal(data[[1]][[1]]$fill, "A")
  testthat::expect_equal(data[[2]][[1]]$fill, "B")
})

test_that("Ggplot2LineLayerProcessor process() returns correct structure", {
  df <- data.frame(x = 1:3, y = c(2, 4, 6))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::labs(title = "Test Line", x = "X Axis", y = "Y Axis")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  layout <- list(
    title = "Test Line",
    axes = list(x = "X Axis", y = "Y Axis")
  )

  # Process with NULL gt (skip selector generation for unit test)
  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL, NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$title, "Test Line")
  testthat::expect_equal(result$axes$x, "X Axis")
  testthat::expect_equal(result$axes$y, "Y Axis")
  testthat::expect_equal(length(result$data), 1)
  testthat::expect_equal(length(result$data[[1]]), 3)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("Ggplot2LineLayerProcessor handles NULL built parameter", {
  df <- data.frame(x = 1:3, y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  # Should build plot internally
  data <- processor$extract_data(p, built = NULL)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 3)
})

test_that("Ggplot2LineLayerProcessor handles single point line", {
  df <- data.frame(x = 1, y = 5)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_equal(length(data[[1]]), 1)
  # Single-point plots use ggplot2's auto-generated scale with decimal formatting
  testthat::expect_equal(data[[1]][[1]]$x, "1.000")
  testthat::expect_equal(data[[1]][[1]]$y, 5)
})

test_that("Ggplot2LineLayerProcessor handles panel filtering", {
  # Create faceted plot
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    facet = rep(c("A", "B"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~facet)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)

  # Extract data for panel 1
  data_panel1 <- processor$extract_data(p, built, panel_id = 1)

  testthat::expect_type(data_panel1, "list")
  testthat::expect_equal(length(data_panel1), 1)
  testthat::expect_equal(length(data_panel1[[1]]), 3)
})

test_that("Ggplot2LineLayerProcessor handles group -1 (default)", {
  # Single line with default group = -1 should be treated as single line
  df <- data.frame(x = 1:4, y = c(2, 4, 3, 5))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  # Should return single series (not multiline)
  testthat::expect_equal(length(data), 1)
  # First point should not have 'fill' field
  testthat::expect_false("fill" %in% names(data[[1]][[1]]))
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("Ggplot2LineLayerProcessor extract_layer_axes() works", {
  df <- data.frame(x = 1:3, y = c(5, 10, 15))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::labs(x = "Time", y = "Value")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  layout <- list(axes = list(x = "Time", y = "Value"))
  axes <- processor$extract_layer_axes(p, layout)

  testthat::expect_type(axes, "list")
  testthat::expect_equal(axes$x, "Time")
  testthat::expect_equal(axes$y, "Value")
})

test_that("Ggplot2LineLayerProcessor needs_reordering() returns FALSE", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  testthat::expect_false(processor$needs_reordering())
})

test_that("Ggplot2LineLayerProcessor get_group_column() finds colour mapping", {
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    cat = rep(c("X", "Y"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, colour = cat)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  group_col <- processor$get_group_column(p)

  testthat::expect_equal(group_col, "cat")
})

test_that("Ggplot2LineLayerProcessor get_group_column() finds color mapping", {
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    cat = rep(c("X", "Y"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = cat)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  group_col <- processor$get_group_column(p)

  testthat::expect_equal(group_col, "cat")
})

test_that("Ggplot2LineLayerProcessor get_group_column() defaults to 'group'", {
  df <- data.frame(x = 1:3, y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  group_col <- processor$get_group_column(p)

  testthat::expect_equal(group_col, "group")
})

# ==============================================================================
# Tier 4: Line-Specific Logic
# ==============================================================================

test_that("Ggplot2LineLayerProcessor extract_single_line_data() returns correct structure", {
  df <- data.frame(x = 1:4, y = c(10, 20, 15, 25))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  result <- processor$extract_single_line_data(layer_data)

  testthat::expect_equal(length(result), 1) # Single series
  testthat::expect_equal(length(result[[1]]), 4) # 4 points

  # Check structure of first point
  testthat::expect_true("x" %in% names(result[[1]][[1]]))
  testthat::expect_true("y" %in% names(result[[1]][[1]]))
  testthat::expect_false("fill" %in% names(result[[1]][[1]])) # No fill for single line
})

test_that("Ggplot2LineLayerProcessor extract_multiline_data() handles multiple groups", {
  df <- data.frame(
    x = rep(1:3, 3),
    y = 1:9,
    series = rep(c("A", "B", "C"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = series)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  result <- processor$extract_multiline_data(layer_data, p)

  testthat::expect_equal(length(result), 3) # Three series
  testthat::expect_equal(length(result[[1]]), 3) # 3 points per series

  # Check fill field contains series names
  testthat::expect_equal(result[[1]][[1]]$fill, "A")
  testthat::expect_equal(result[[2]][[1]]$fill, "B")
  testthat::expect_equal(result[[3]][[1]]$fill, "C")
})

test_that("Ggplot2LineLayerProcessor multiline fallback to group numbers", {
  # Create plot without explicit grouping column in data
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line(ggplot2::aes(group = rep(c(1, 2), each = 3)))

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  result <- processor$extract_multiline_data(layer_data, p)

  testthat::expect_equal(length(result), 2)
  # Should use fallback "Series N" naming
  testthat::expect_match(result[[1]][[1]]$fill, "Series")
})

test_that("Ggplot2LineLayerProcessor handles NULL gt in generate_selectors", {
  df <- data.frame(x = 1:3, y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  # NULL gt should still work (will build grob internally)
  selectors <- processor$generate_selectors(p, gt = NULL)

  testthat::expect_type(selectors, "list")
  # Should have at least one selector
  testthat::expect_true(length(selectors) > 0)
})

test_that("Ggplot2LineLayerProcessor generate_multiline_selectors() creates correct format", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  selectors <- processor$generate_multiline_selectors("61", 3)

  testthat::expect_equal(length(selectors), 3)
  testthat::expect_match(selectors[[1]], "#GRID\\\\.polyline\\\\.61\\\\.1\\\\.1")
  testthat::expect_match(selectors[[2]], "#GRID\\\\.polyline\\\\.61\\\\.1\\\\.2")
  testthat::expect_match(selectors[[3]], "#GRID\\\\.polyline\\\\.61\\\\.1\\\\.3")
})

test_that("Ggplot2LineLayerProcessor generate_single_line_selector() creates correct format", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  selector <- processor$generate_single_line_selector("42")

  testthat::expect_equal(length(selector), 1)
  testthat::expect_match(selector[[1]], "#GRID\\\\.polyline\\\\.42\\\\.1\\\\.1")
})

test_that("Ggplot2LineLayerProcessor handles faceted plot with grob_id", {
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    facet = rep(c("A", "B"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~facet)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  # Faceted plots use grob_id parameter
  selectors <- processor$generate_selectors(p, gt = NULL, grob_id = "GRID.polyline.100")

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
  testthat::expect_match(selectors[[1]], "#GRID\\\\.polyline\\\\.100\\\\.1\\\\.1")
})

test_that("Ggplot2LineLayerProcessor x values converted to character", {
  df <- data.frame(x = c(10, 20, 30), y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # x values should be character strings
  testthat::expect_type(data[[1]][[1]]$x, "character")
  testthat::expect_equal(data[[1]][[1]]$x, "10")
  testthat::expect_equal(data[[1]][[2]]$x, "20")
})

test_that("Ggplot2LineLayerProcessor multiline detection works correctly", {
  # Single line (group = -1)
  df_single <- data.frame(x = 1:3, y = c(1, 2, 3))
  p_single <- ggplot2::ggplot(df_single, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  data_single <- processor$extract_data(p_single)
  testthat::expect_false("fill" %in% names(data_single[[1]][[1]]))

  # Multiline (multiple groups)
  df_multi <- data.frame(
    x = rep(1:3, 2),
    y = 1:6,
    g = rep(c("A", "B"), each = 3)
  )
  p_multi <- ggplot2::ggplot(df_multi, ggplot2::aes(x = x, y = y, color = g)) +
    ggplot2::geom_line()

  data_multi <- processor$extract_data(p_multi)
  testthat::expect_true("fill" %in% names(data_multi[[1]][[1]]))
  testthat::expect_equal(length(data_multi), 2)
})

test_that("Ggplot2LineLayerProcessor extracts all metadata correctly", {
  df <- data.frame(x = 1:5, y = c(10, 20, 15, 25, 30))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::labs(title = "Complete Line", x = "X Values", y = "Y Values")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  layout <- list(
    title = "Complete Line",
    axes = list(x = "X Values", y = "Y Values")
  )
  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL, NULL)

  # Test data extraction
  testthat::expect_equal(length(result$data), 1)
  testthat::expect_equal(length(result$data[[1]]), 5)

  # Test title
  testthat::expect_equal(result$title, "Complete Line")

  # Test axes
  testthat::expect_equal(result$axes$x, "X Values")
  testthat::expect_equal(result$axes$y, "Y Values")
})

# Selector tests with grob tree skipped - tested at orchestrator level
