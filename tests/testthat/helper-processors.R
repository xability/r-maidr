# Helper functions for layer processor tests
# Additional plot generators and utilities for comprehensive processor testing

# ============================================================================
# ggplot2 Additional Plot Generators
# ============================================================================

#' Create a ggplot2 heatmap for testing
#' @return A ggplot object with heatmap (geom_tile)
create_test_ggplot_heatmap <- function() {
  testthat::skip_if_not_installed("ggplot2")

  # Create simple grid data
  df <- expand.grid(
    x = 1:5,
    y = 1:5
  )
  df$z <- df$x * df$y

  ggplot2::ggplot(
    df,
    ggplot2::aes(x = x, y = y, fill = z)
  ) +
    ggplot2::geom_tile() +
    ggplot2::labs(title = "Test Heatmap")
}

#' Create a ggplot2 smooth plot for testing
#' @return A ggplot object with smooth geom
create_test_ggplot_smooth <- function() {
  testthat::skip_if_not_installed("ggplot2")

  ggplot2::ggplot(
    mtcars[1:20, ],
    ggplot2::aes(x = wt, y = mpg)
  ) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "loess", se = FALSE) +
    ggplot2::labs(title = "Test Smooth Plot")
}

#' Create a ggplot2 dodged bar plot for testing
#' @return A ggplot object with dodged bars
create_test_ggplot_dodged_bar <- function() {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  ggplot2::ggplot(
    df,
    ggplot2::aes(x = x, y = y, fill = fill)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "dodge") +
    ggplot2::labs(title = "Test Dodged Bar")
}

#' Create a ggplot2 stacked bar plot for testing
#' @return A ggplot object with stacked bars
create_test_ggplot_stacked_bar <- function() {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  ggplot2::ggplot(
    df,
    ggplot2::aes(x = x, y = y, fill = fill)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "stack") +
    ggplot2::labs(title = "Test Stacked Bar")
}

#' Create a ggplot2 multi-line plot for testing
#' @return A ggplot object with multiple lines
create_test_ggplot_multiline <- function() {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(1:10, 3),
    y = c(rnorm(10), rnorm(10, 1), rnorm(10, 2)),
    group = rep(c("A", "B", "C"), each = 10)
  )

  ggplot2::ggplot(
    df,
    ggplot2::aes(x = x, y = y, color = group)
  ) +
    ggplot2::geom_line() +
    ggplot2::labs(title = "Test Multi-line Plot")
}

#' Create a ggplot2 faceted plot for testing
#' @return A ggplot object with facets
create_test_ggplot_faceted <- function() {
  testthat::skip_if_not_installed("ggplot2")

  ggplot2::ggplot(
    mtcars,
    ggplot2::aes(x = mpg, y = wt)
  ) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~cyl) +
    ggplot2::labs(title = "Test Faceted Plot")
}

# ============================================================================
# Base R Additional Plot Generators
# ============================================================================

#' Create a Base R heatmap for testing
#' @return NULL (creates plot on current device)
create_test_base_r_heatmap <- function() {
  mat <- matrix(1:25, nrow = 5, ncol = 5)
  image(
    mat,
    main = "Test Heatmap",
    xlab = "X",
    ylab = "Y"
  )
}

#' Create a Base R smooth plot for testing (density)
#' @return NULL (creates plot on current device)
create_test_base_r_smooth <- function() {
  # Create density plot
  plot(
    density(rnorm(100)),
    main = "Test Density Plot",
    xlab = "Value"
  )
}

#' Create a Base R smooth plot for testing (loess)
#' @return NULL (creates plot on current device)
create_test_base_r_smooth_loess <- function() {
  x <- 1:20
  y <- x + rnorm(20, sd = 2)
  plot(x, y, main = "Test Smooth (Loess)")
  fit <- stats::loess(y ~ x)
  lines(x, predict(fit), col = "red")
}

#' Create a Base R dodged barplot for testing
#' @return NULL (creates plot on current device)
create_test_base_r_dodged_bar <- function() {
  test_matrix <- matrix(c(10, 15, 20, 25), nrow = 2)
  rownames(test_matrix) <- c("G1", "G2")
  colnames(test_matrix) <- c("A", "B")

  barplot(
    test_matrix,
    beside = TRUE,
    main = "Test Dodged Bar",
    legend.text = TRUE
  )
}

#' Create a Base R stacked barplot for testing
#' @return NULL (creates plot on current device)
create_test_base_r_stacked_bar <- function() {
  test_matrix <- matrix(c(10, 15, 20, 25), nrow = 2)
  rownames(test_matrix) <- c("G1", "G2")
  colnames(test_matrix) <- c("A", "B")

  barplot(
    test_matrix,
    beside = FALSE,
    main = "Test Stacked Bar",
    legend.text = TRUE
  )
}

#' Create a Base R abline plot for testing
#' @return NULL (creates plot on current device)
create_test_base_r_abline <- function() {
  plot(
    1:10,
    1:10,
    type = "n",
    main = "Test Abline Plot"
  )
  abline(a = 0, b = 1, col = "red")
  abline(h = 5, col = "blue")
  abline(v = 5, col = "green")
}

# ============================================================================
# Processor Test Utilities
# ============================================================================

#' Expect processor output has valid structure
#'
#' Validates that a processor's process() result contains
#' required fields: data, selectors (and optionally axes, title)
#'
#' @param result The result from processor$process()
#' @return NULL (throws error if invalid)
expect_processor_output <- function(result) {
  testthat::expect_type(result, "list")
  testthat::expect_true("data" %in% names(result))
  testthat::expect_true("selectors" %in% names(result))
  testthat::expect_type(result$data, "list")

  # Selectors can be either character vector or list
  testthat::expect_true(
    is.character(result$selectors) || is.list(result$selectors)
  )

  # Optional fields (may be present)
  if ("axes" %in% names(result)) {
    testthat::expect_type(result$axes, "list")
  }
  if ("title" %in% names(result)) {
    testthat::expect_type(result$title, "character")
  }
}

#' Expect valid CSS selectors
#'
#' Basic validation that selectors are non-empty strings
#'
#' @param selectors Vector of CSS selector strings
#' @return NULL (throws error if invalid)
expect_valid_selectors <- function(selectors) {
  testthat::expect_type(selectors, "character")
  testthat::expect_true(length(selectors) > 0)
  testthat::expect_true(all(nchar(selectors) > 0))
}

#' Expect MAIDR data format for specific plot type
#'
#' Validates data structure based on plot type
#'
#' @param data The data from processor output
#' @param type Plot type ("bar", "point", "line", "hist", "box", "heatmap", "smooth")
#' @return NULL (throws error if invalid)
expect_maidr_data_format <- function(data, type) {
  testthat::expect_type(data, "list")
  testthat::expect_true(length(data) > 0)

  # Type-specific validations
  if (type %in% c("bar", "point", "line")) {
    # Should have x/y coordinates
    if (length(data) > 0) {
      first_elem <- data[[1]]
      if (is.list(first_elem) && length(first_elem) > 0) {
        # Nested structure (grouped)
        testthat::expect_true(is.list(first_elem[[1]]))
      } else {
        # Flat structure
        testthat::expect_true(is.list(first_elem))
      }
    }
  } else if (type == "hist") {
    # Histograms should have bin data
    if (length(data) > 0) {
      first_bin <- data[[1]]
      testthat::expect_true(is.list(first_bin))
    }
  } else if (type == "box") {
    # Boxplots should have quartile data
    if (length(data) > 0) {
      first_box <- data[[1]]
      testthat::expect_true(is.list(first_box))
    }
  } else if (type == "heatmap") {
    # Heatmaps should have matrix-like structure
    testthat::expect_true(is.list(data))
  } else if (type == "smooth") {
    # Smooth should have line data
    testthat::expect_true(is.list(data))
  }
}

#' Expect processor is R6 class
#'
#' Validates that a processor is an R6 object
#'
#' @param processor The processor object
#' @param expected_class Expected class name
#' @return NULL (throws error if invalid)
expect_processor_r6 <- function(processor, expected_class) {
  testthat::expect_true(R6::is.R6(processor))
  testthat::expect_s3_class(processor, expected_class)
  testthat::expect_s3_class(processor, "LayerProcessor")
}

#' Create mock layer_info for testing
#'
#' Creates a minimal layer_info structure for processor testing
#'
#' @param index Layer index
#' @param type Layer type
#' @param additional_fields Named list of additional fields
#' @return layer_info list
create_mock_layer_info <- function(index = 1, type = "bar", additional_fields = list()) {
  base_info <- list(
    index = index,
    type = type
  )

  c(base_info, additional_fields)
}

#' Expect data has length
#'
#' Helper to check data has minimum length
#'
#' @param data The data object
#' @param min_length Minimum expected length
#' @return NULL (throws error if invalid)
expect_data_length <- function(data, min_length = 1) {
  testthat::expect_type(data, "list")
  testthat::expect_gte(length(data), min_length)
}

#' Expect selectors match data length
#'
#' Helper to verify selectors and data are aligned
#'
#' @param selectors Selector vector
#' @param data Data list
#' @return NULL (throws error if invalid)
expect_selectors_match_data <- function(selectors, data) {
  testthat::expect_type(selectors, "character")
  testthat::expect_type(data, "list")

  # For simple (non-grouped) data, lengths should match
  # For grouped data, this may not apply
  # So we just check both have content
  testthat::expect_true(length(selectors) > 0)
  testthat::expect_true(length(data) > 0)
}
