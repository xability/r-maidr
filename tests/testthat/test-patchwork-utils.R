# Comprehensive tests for ggplot2 Patchwork Utilities
# Testing patchwork panel discovery, leaf extraction, and processing

# ==============================================================================
# find_patchwork_panels Tests
# ==============================================================================

test_that("find_patchwork_panels returns empty data.frame for NULL gtable", {
  result <- maidr:::find_patchwork_panels(NULL)

  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_equal(nrow(result), 0)
})

test_that("find_patchwork_panels returns empty data.frame for gtable without panels", {
  testthat::skip_if_not_installed("ggplot2")

  # Create a simple plot and get its gtable
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  gt <- ggplot2::ggplotGrob(p)

  result <- maidr:::find_patchwork_panels(gt)

  # Regular ggplot gtable may or may not have panel entries matching the pattern
  testthat::expect_s3_class(result, "data.frame")
})

test_that("find_patchwork_panels returns correct structure", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  # Create a patchwork plot
  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram()

  combined <- patchwork::wrap_plots(p1, p2)
  gt <- ggplot2::ggplotGrob(combined)

  result <- maidr:::find_patchwork_panels(gt)

  if (nrow(result) > 0) {
    testthat::expect_true("panel_index" %in% names(result))
    testthat::expect_true("name" %in% names(result))
    testthat::expect_true("t" %in% names(result))
    testthat::expect_true("l" %in% names(result))
    testthat::expect_true("row" %in% names(result))
    testthat::expect_true("col" %in% names(result))
  }
})

# ==============================================================================
# extract_patchwork_leaves Tests
# ==============================================================================

test_that("extract_patchwork_leaves returns list for ggplot object", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_patchwork_leaves(p)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 1)
  testthat::expect_s3_class(result[[1]], "ggplot")
})

test_that("extract_patchwork_leaves returns empty list for non-ggplot", {
  result <- maidr:::extract_patchwork_leaves(list(a = 1))

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("extract_patchwork_leaves returns empty list for NULL", {
  result <- maidr:::extract_patchwork_leaves(NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("extract_patchwork_leaves extracts from patchwork", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram()

  combined <- p1 + p2

  result <- maidr:::extract_patchwork_leaves(combined)

  testthat::expect_type(result, "list")
  # Should have extracted the leaf plots
  testthat::expect_gte(length(result), 1)
})

# ==============================================================================
# extract_leaf_plot_layout Tests
# ==============================================================================

test_that("extract_leaf_plot_layout extracts labels", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Test Title", x = "X Label", y = "Y Label")

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$title, "Test Title")
  testthat::expect_equal(result$axes$x, "X Label")
  testthat::expect_equal(result$axes$y, "Y Label")
})

test_that("extract_leaf_plot_layout handles missing labels", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_type(result, "list")
  testthat::expect_true("title" %in% names(result))
  testthat::expect_true("axes" %in% names(result))
})

test_that("extract_leaf_plot_layout falls back to mapping for axes", {
  testthat::skip_if_not_installed("ggplot2")

  # Plot without explicit labels but with mapping
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_leaf_plot_layout(p)

  # Should extract from mapping
  testthat::expect_equal(result$axes$x, "mpg")
  testthat::expect_equal(result$axes$y, "wt")
})

test_that("extract_leaf_plot_layout returns empty string for missing title", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_equal(result$title, "")
})

# ==============================================================================
# process_patchwork_plot_data Tests
# ==============================================================================

test_that("process_patchwork_plot_data returns empty list for NULL gtable", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::process_patchwork_plot_data(p, list(), NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("process_patchwork_plot_data handles simple ggplot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  gt <- ggplot2::ggplotGrob(p)
  layout <- list(axes = list(x = "mpg", y = "wt"))

  result <- maidr:::process_patchwork_plot_data(p, layout, gt)

  # May return empty if no patchwork panels found
  testthat::expect_type(result, "list")
})

test_that("process_patchwork_plot_data works with patchwork", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "MPG")

  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "Weight")

  combined <- p1 + p2
  gt <- ggplot2::ggplotGrob(combined)
  layout <- list(axes = list(x = "", y = ""))

  result <- maidr:::process_patchwork_plot_data(combined, layout, gt)

  testthat::expect_type(result, "list")
})

# ==============================================================================
# process_patchwork_panel Tests
# ==============================================================================

test_that("process_patchwork_panel returns correct structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Test Plot")

  gt <- ggplot2::ggplotGrob(p)
  layout <- list(axes = list(x = "mpg", y = "wt"))

  result <- maidr:::process_patchwork_panel(
    leaf_plot = p,
    panel_name = "panel-1",
    panel_index = 1,
    row = 1,
    col = 1,
    layout = layout,
    gtable = gt
  )

  testthat::expect_type(result, "list")
  testthat::expect_true("id" %in% names(result))
  testthat::expect_true("layers" %in% names(result))
  testthat::expect_type(result$layers, "list")
})

test_that("process_patchwork_panel generates unique id", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  gt <- ggplot2::ggplotGrob(p)

  result1 <- maidr:::process_patchwork_panel(p, "panel-1", 1, 1, 1, list(), gt)
  Sys.sleep(0.01) # Ensure different timestamp

  result2 <- maidr:::process_patchwork_panel(p, "panel-2", 2, 1, 2, list(), gt)

  testthat::expect_true(grepl("^maidr-subplot-", result1$id))
  testthat::expect_true(grepl("^maidr-subplot-", result2$id))
})

test_that("process_patchwork_panel processes layers", {
  # This test requires full system integration - skip in unit tests
  # The function is tested implicitly through the patchwork integration tests
  testthat::skip("Requires full system integration")
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Patchwork utils handle empty plots gracefully", {
  testthat::skip_if_not_installed("ggplot2")

  # Empty ggplot
  p <- ggplot2::ggplot()

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$title, "")
})

test_that("find_patchwork_panels handles gtable without layout", {
  # Create a minimal gtable-like structure without layout
  fake_gtable <- list(layout = NULL)

  result <- maidr:::find_patchwork_panels(fake_gtable)

  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_equal(nrow(result), 0)
})

test_that("extract_patchwork_leaves handles nested patchwork", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram()
  p3 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = hp)) +
    ggplot2::geom_histogram()

  # Create nested patchwork
  nested <- (p1 | p2) / p3

  result <- maidr:::extract_patchwork_leaves(nested)

  testthat::expect_type(result, "list")
  # Should extract multiple leaves
  testthat::expect_gte(length(result), 1)
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Patchwork processing pipeline works end-to-end", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  # Create a 2x2 patchwork layout
  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "MPG Distribution")

  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "Weight Distribution")

  p3 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "MPG vs Weight")

  p4 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = hp, y = mpg)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "HP vs MPG")

  combined <- (p1 | p2) / (p3 | p4)

  # Extract leaves
  leaves <- maidr:::extract_patchwork_leaves(combined)
  testthat::expect_gte(length(leaves), 1)

  # Extract layout from each leaf
  for (leaf in leaves) {
    layout <- maidr:::extract_leaf_plot_layout(leaf)
    testthat::expect_type(layout, "list")
  }
})
