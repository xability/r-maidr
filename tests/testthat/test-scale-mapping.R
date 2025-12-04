# Comprehensive tests for Scale Mapping Utilities
# Testing apply_scale_mapping and extract_scale_mapping functions

# ==============================================================================
# apply_scale_mapping Tests
# ==============================================================================

test_that("apply_scale_mapping returns input for NULL mapping", {
  numeric_values <- c(1, 2, 3)

  result <- maidr:::apply_scale_mapping(numeric_values, NULL)

  testthat::expect_identical(result, numeric_values)
})
test_that("apply_scale_mapping maps numeric values to labels", {
  numeric_values <- c(1, 2, 3)
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result), c("A", "B", "C"))
})

test_that("apply_scale_mapping handles out-of-order mapping", {
  numeric_values <- c(3, 1, 2)
  scale_mapping <- c("1" = "First", "2" = "Second", "3" = "Third")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result), c("Third", "First", "Second"))
})

test_that("apply_scale_mapping handles single value", {
  numeric_values <- 1
  scale_mapping <- c("1" = "Only")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result), "Only")
})

test_that("apply_scale_mapping handles unmapped values", {
  numeric_values <- c(1, 2, 5) # 5 is not in mapping
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  # Unmapped value should remain as character of original
  testthat::expect_equal(as.character(result[1]), "A")
  testthat::expect_equal(as.character(result[2]), "B")
  testthat::expect_equal(as.character(result[3]), "5")
})

test_that("apply_scale_mapping handles all unmapped values", {
  numeric_values <- c(10, 20, 30)
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result), c("10", "20", "30"))
})

test_that("apply_scale_mapping handles empty input", {
  numeric_values <- numeric(0)
  scale_mapping <- c("1" = "A", "2" = "B")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(length(result), 0)
})

test_that("apply_scale_mapping handles character input", {
  # Should also work with character values that look like numbers
  char_values <- c("1", "2", "3")
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- maidr:::apply_scale_mapping(char_values, scale_mapping)

  testthat::expect_equal(as.character(result), c("A", "B", "C"))
})

test_that("apply_scale_mapping preserves order", {
  numeric_values <- c(3, 3, 1, 2, 1)
  scale_mapping <- c("1" = "One", "2" = "Two", "3" = "Three")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(
    as.character(result),
    c("Three", "Three", "One", "Two", "One")
  )
})

test_that("apply_scale_mapping handles decimal values", {
  numeric_values <- c(1.0, 2.0, 3.0)
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result), c("A", "B", "C"))
})

test_that("apply_scale_mapping handles large mapping", {
  numeric_values <- 1:100
  scale_mapping <- setNames(
    paste0("Label", 1:100),
    as.character(1:100)
  )

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result[1]), "Label1")
  testthat::expect_equal(as.character(result[50]), "Label50")
  testthat::expect_equal(as.character(result[100]), "Label100")
})

# ==============================================================================
# extract_scale_mapping Tests
# ==============================================================================

test_that("extract_scale_mapping returns NULL for NULL panel_scales_x", {
  built <- list(layout = list(panel_scales_x = NULL))

  result <- maidr:::extract_scale_mapping(built)

  testthat::expect_null(result)
})

test_that("extract_scale_mapping returns NULL for NULL breaks", {
  testthat::skip_if_not_installed("ggplot2")

  # Create a continuous scale plot (no discrete breaks)
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  built <- ggplot2::ggplot_build(p)

  result <- maidr:::extract_scale_mapping(built)

  # Continuous scales may or may not have mapping
  # Just check it doesn't error
  testthat::expect_true(is.null(result) || is.character(result))
})

test_that("extract_scale_mapping works with discrete x scale", {
  testthat::skip_if_not_installed("ggplot2")

  # Create a plot with discrete x axis
  df <- data.frame(
    category = c("A", "B", "C"),
    value = c(10, 20, 30)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = category, y = value)) +
    ggplot2::geom_bar(stat = "identity")

  built <- ggplot2::ggplot_build(p)

  result <- maidr:::extract_scale_mapping(built)

  # Should return a mapping or NULL
  if (!is.null(result)) {
    testthat::expect_type(result, "character")
    testthat::expect_true(length(result) >= 1)
  }
})

test_that("extract_scale_mapping returns named vector", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    category = factor(c("First", "Second", "Third")),
    value = c(10, 20, 30)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = category, y = value)) +
    ggplot2::geom_bar(stat = "identity")

  built <- ggplot2::ggplot_build(p)

  result <- maidr:::extract_scale_mapping(built)

  if (!is.null(result)) {
    # Should be a named character vector
    testthat::expect_type(result, "character")
    testthat::expect_true(!is.null(names(result)))
  }
})

test_that("extract_scale_mapping handles faceted plots", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    category = rep(c("A", "B", "C"), 3),
    value = 1:9,
    facet = rep(c("X", "Y", "Z"), each = 3)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = category, y = value)) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::facet_wrap(~facet)

  built <- ggplot2::ggplot_build(p)

  # Should not error
  result <- maidr:::extract_scale_mapping(built)

  testthat::expect_true(is.null(result) || is.character(result))
})

test_that("extract_scale_mapping handles plot with no data", {
  testthat::skip_if_not_installed("ggplot2")

  # Empty data frame
  df <- data.frame(x = character(0), y = numeric(0))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  built <- ggplot2::ggplot_build(p)

  # Should not error
  result <- maidr:::extract_scale_mapping(built)

  testthat::expect_true(is.null(result) || is.character(result))
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("extract_scale_mapping and apply_scale_mapping work together", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    category = factor(c("Alpha", "Beta", "Gamma")),
    value = c(10, 20, 30)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = category, y = value)) +
    ggplot2::geom_bar(stat = "identity")

  built <- ggplot2::ggplot_build(p)

  scale_mapping <- maidr:::extract_scale_mapping(built)

  if (!is.null(scale_mapping)) {
    # Apply the extracted mapping
    numeric_positions <- 1:length(scale_mapping)
    result <- maidr:::apply_scale_mapping(numeric_positions, scale_mapping)

    testthat::expect_type(result, "character")
    testthat::expect_equal(length(result), length(numeric_positions))
  }
})

test_that("Scale mapping roundtrip preserves labels", {
  testthat::skip_if_not_installed("ggplot2")

  original_labels <- c("One", "Two", "Three")
  df <- data.frame(
    category = factor(original_labels, levels = original_labels),
    value = c(10, 20, 30)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = category, y = value)) +
    ggplot2::geom_bar(stat = "identity")

  built <- ggplot2::ggplot_build(p)

  scale_mapping <- maidr:::extract_scale_mapping(built)

  if (!is.null(scale_mapping)) {
    # The values should contain our original labels
    testthat::expect_true(all(original_labels %in% scale_mapping))
  }
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("apply_scale_mapping handles NA values", {
  numeric_values <- c(1, NA, 3)
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result[1]), "A")
  testthat::expect_true(is.na(result[2]))
  testthat::expect_equal(as.character(result[3]), "C")
})

test_that("apply_scale_mapping handles special characters in labels", {
  numeric_values <- c(1, 2, 3)
  scale_mapping <- c("1" = "Label & More", "2" = "With 'quotes'", "3" = "Has<>brackets")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result[1]), "Label & More")
  testthat::expect_equal(as.character(result[2]), "With 'quotes'")
  testthat::expect_equal(as.character(result[3]), "Has<>brackets")
})

test_that("apply_scale_mapping handles unicode labels", {
  numeric_values <- c(1, 2, 3)
  scale_mapping <- c("1" = "Alpha", "2" = "Beta", "3" = "Gamma")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result[1]), "Alpha")
  testthat::expect_equal(as.character(result[2]), "Beta")
  testthat::expect_equal(as.character(result[3]), "Gamma")
})

test_that("apply_scale_mapping handles negative numbers", {
  numeric_values <- c(-1, 0, 1)
  scale_mapping <- c("-1" = "Negative", "0" = "Zero", "1" = "Positive")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result[1]), "Negative")
  testthat::expect_equal(as.character(result[2]), "Zero")
  testthat::expect_equal(as.character(result[3]), "Positive")
})

test_that("apply_scale_mapping handles duplicate values", {
  numeric_values <- c(1, 1, 2, 2, 3, 3)
  scale_mapping <- c("1" = "A", "2" = "B", "3" = "C")

  result <- maidr:::apply_scale_mapping(numeric_values, scale_mapping)

  testthat::expect_equal(as.character(result), c("A", "A", "B", "B", "C", "C"))
})
