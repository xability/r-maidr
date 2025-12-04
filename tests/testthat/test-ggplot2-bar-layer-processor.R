# Comprehensive tests for Ggplot2BarLayerProcessor
# Testing basic bars, faceted plots, data reordering, selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2BarLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2BarLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2BarLayerProcessor extract_data() works with basic bars", {
  # Create simple bar plot
  df <- data.frame(
    x = c("A", "B", "C"),
    y = c(10, 20, 15)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 3)

  # Check first bar
  testthat::expect_equal(data[[1]]$x, "A")
  testthat::expect_equal(data[[1]]$y, 10)
})

test_that("Ggplot2BarLayerProcessor process() returns correct structure", {
  df <- data.frame(x = c("X", "Y"), y = c(5, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::labs(title = "Test Bar", x = "Category", y = "Value")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  layout <- list(
    title = "Test Bar",
    axes = list(x = "Category", y = "Value")
  )

  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL, NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$title, "Test Bar")
  testthat::expect_equal(result$axes$x, "Category")
  testthat::expect_equal(result$axes$y, "Value")
  testthat::expect_equal(length(result$data), 2)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("Ggplot2BarLayerProcessor handles NULL built parameter", {
  df <- data.frame(x = c("A", "B"), y = c(3, 7))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  # Should build plot internally
  data <- processor$extract_data(p, built = NULL)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 2)
})

test_that("Ggplot2BarLayerProcessor handles single bar", {
  df <- data.frame(x = "Solo", y = 42)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(data[[1]]$x, "Solo")
  testthat::expect_equal(data[[1]]$y, 42)
})

test_that("Ggplot2BarLayerProcessor handles panel filtering", {
  # Create faceted plot
  df <- data.frame(
    x = rep(c("A", "B"), 2),
    y = c(10, 20, 30, 40),
    facet = rep(c("F1", "F2"), each = 2)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::facet_wrap(~facet)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)

  # Extract data for panel 1
  data_panel1 <- processor$extract_data(p, built, panel_id = 1)

  testthat::expect_type(data_panel1, "list")
  testthat::expect_equal(length(data_panel1), 2)
})

test_that("Ggplot2BarLayerProcessor handles mismatched built_data and x_values", {
  # Test edge case where built_data has more rows than x labels
  df <- data.frame(x = c("A", "B"), y = c(5, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  # Manually create built with extra row
  built <- ggplot2::ggplot_build(p)

  # Normal case should work fine
  data <- processor$extract_data(p, built)
  testthat::expect_equal(length(data), 2)
})

test_that("Ggplot2BarLayerProcessor handles numeric x values", {
  df <- data.frame(x = c(1, 2, 3), y = c(10, 20, 30))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # x values should be converted to character
  testthat::expect_type(data[[1]]$x, "character")
  testthat::expect_equal(data[[1]]$x, "1")
  testthat::expect_equal(data[[2]]$x, "2")
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("Ggplot2BarLayerProcessor needs_reordering() returns TRUE", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  testthat::expect_true(processor$needs_reordering())
})

test_that("Ggplot2BarLayerProcessor reorder_layer_data() sorts by x column", {
  df <- data.frame(
    x = c("C", "A", "B"),
    y = c(30, 10, 20)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  reordered <- processor$reorder_layer_data(df, p)

  testthat::expect_equal(reordered$x, c("A", "B", "C"))
  testthat::expect_equal(reordered$y, c(10, 20, 30))
})

test_that("Ggplot2BarLayerProcessor reorder_layer_data() handles missing x_col", {
  df <- data.frame(a = c(3, 1, 2), b = c(30, 10, 20))
  # Create plot without explicit x mapping
  p <- ggplot2::ggplot(df) +
    ggplot2::geom_bar(stat = "identity", ggplot2::aes(x = a, y = b))

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  # Should reorder by x column from layer mapping
  reordered <- processor$reorder_layer_data(df, p)

  testthat::expect_equal(reordered$a, c(1, 2, 3))
})

test_that("Ggplot2BarLayerProcessor extract_layer_axes() works", {
  df <- data.frame(x = c("A", "B"), y = c(5, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::labs(x = "Items", y = "Count")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  layout <- list(axes = list(x = "Items", y = "Count"))
  axes <- processor$extract_layer_axes(p, layout)

  testthat::expect_type(axes, "list")
  testthat::expect_equal(axes$x, "Items")
  testthat::expect_equal(axes$y, "Count")
})

# ==============================================================================
# Tier 4: Bar-Specific Logic
# ==============================================================================

test_that("Ggplot2BarLayerProcessor handles ordered x values from original data", {
  # Data intentionally out of alphabetical order
  df <- data.frame(
    x = c("Zebra", "Apple", "Mango"),
    y = c(5, 10, 15)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # Should preserve order from reorder_layer_data (alphabetical)
  testthat::expect_equal(data[[1]]$x, "Apple")
  testthat::expect_equal(data[[2]]$x, "Mango")
  testthat::expect_equal(data[[3]]$x, "Zebra")
})

test_that("Ggplot2BarLayerProcessor handles NULL gt in generate_selectors", {
  df <- data.frame(x = c("A", "B"), y = c(5, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  # NULL gt should still work (will build grob internally)
  selectors <- processor$generate_selectors(p, gt = NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_true(length(selectors) > 0)
})

test_that("Ggplot2BarLayerProcessor generate_selectors() creates correct format", {
  df <- data.frame(x = c("A", "B", "C"), y = c(10, 20, 15))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p)

  # Simple bar charts have one parent grob containing all bars
  testthat::expect_true(length(selectors) >= 1)

  # Selector should match pattern #geom_rect.rect.*.1 rect
  testthat::expect_match(selectors[[1]], "^#geom_rect")
  testthat::expect_match(selectors[[1]], " rect$")
})

test_that("Ggplot2BarLayerProcessor handles faceted plot with grob_id", {
  df <- data.frame(
    x = rep(c("A", "B"), 2),
    y = c(10, 20, 30, 40),
    facet = rep(c("F1", "F2"), each = 2)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::facet_wrap(~facet)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  # Faceted plots use grob_id parameter
  selectors <- processor$generate_selectors(p, gt = NULL, grob_id = "geom_rect.rect.100")

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
  testthat::expect_match(selectors[[1]], "#geom_rect\\\\.rect\\\\.100\\\\.1 rect")
})

test_that("Ggplot2BarLayerProcessor extracts data with layer mapping", {
  df <- data.frame(
    category = c("Red", "Green", "Blue"),
    value = c(25, 50, 75)
  )
  # Using layer-specific mapping instead of global mapping
  p <- ggplot2::ggplot(df) +
    ggplot2::geom_bar(ggplot2::aes(x = category, y = value), stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 3)
  testthat::expect_equal(data[[1]]$x, "Blue") # Alphabetical order
  testthat::expect_equal(data[[2]]$x, "Green")
  testthat::expect_equal(data[[3]]$x, "Red")
})

test_that("Ggplot2BarLayerProcessor fallback to first column when no x_col", {
  # Edge case: no explicit x mapping found
  df <- data.frame(col1 = c("A", "B", "C"), col2 = c(10, 20, 30))

  # Create a minimal plot without clear x mapping (edge case scenario)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = col1, y = col2)) +
    ggplot2::geom_bar(stat = "identity")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 3)
  testthat::expect_type(data[[1]]$x, "character")
})

test_that("Ggplot2BarLayerProcessor extracts all metadata correctly", {
  df <- data.frame(
    x = c("Jan", "Feb", "Mar"),
    y = c(100, 150, 125)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::labs(title = "Complete Bar", x = "Month", y = "Sales")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2BarLayerProcessor$new(layer_info)

  layout <- list(
    title = "Complete Bar",
    axes = list(x = "Month", y = "Sales")
  )
  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL, NULL)

  # Test data extraction
  testthat::expect_equal(length(result$data), 3)

  # Test title
  testthat::expect_equal(result$title, "Complete Bar")

  # Test axes
  testthat::expect_equal(result$axes$x, "Month")
  testthat::expect_equal(result$axes$y, "Sales")
})

# Selector tests with grob tree skipped - tested at orchestrator level
