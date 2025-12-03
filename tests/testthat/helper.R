# Helper functions for tests
# These functions are available to all test files

# ============================================================================
# ggplot2 Test Plot Generators
# ============================================================================

#' Create a simple ggplot2 bar plot for testing
#' @return A ggplot object with bar chart
create_test_ggplot_bar <- function() {
  testthat::skip_if_not_installed("ggplot2")

  ggplot2::ggplot(
    data.frame(x = c("A", "B", "C"), y = c(10, 20, 30)),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_bar(stat = "identity") +
    ggplot2::labs(title = "Test Bar Plot")
}

#' Create a simple ggplot2 point plot for testing
#' @return A ggplot object with scatter plot
create_test_ggplot_point <- function() {
  testthat::skip_if_not_installed("ggplot2")

  ggplot2::ggplot(
    mtcars[1:10, ],
    ggplot2::aes(x = wt, y = mpg)
  ) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Test Point Plot")
}

#' Create a simple ggplot2 line plot for testing
#' @return A ggplot object with line plot
create_test_ggplot_line <- function() {
  testthat::skip_if_not_installed("ggplot2")

  ggplot2::ggplot(
    data.frame(x = 1:10, y = rnorm(10)),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_line() +
    ggplot2::labs(title = "Test Line Plot")
}

#' Create a ggplot2 histogram for testing
#' @return A ggplot object with histogram
create_test_ggplot_histogram <- function() {
  testthat::skip_if_not_installed("ggplot2")

  ggplot2::ggplot(
    data.frame(x = rnorm(100)),
    ggplot2::aes(x = x)
  ) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "Test Histogram")
}

#' Create a ggplot2 boxplot for testing
#' @return A ggplot object with boxplot
create_test_ggplot_boxplot <- function() {
  testthat::skip_if_not_installed("ggplot2")

  # Use iris dataset with simple column mapping (no factor() call)
  # This matches the pattern used in examples
  ggplot2::ggplot(
    datasets::iris,
    ggplot2::aes(x = Petal.Length, y = Species)
  ) +
    ggplot2::geom_boxplot() +
    ggplot2::labs(title = "Test Boxplot")
}

# ============================================================================
# Base R Test Plot Generators
# ============================================================================

#' Create a simple Base R barplot for testing
#' @return NULL (creates plot on current device)
create_test_base_r_barplot <- function() {
  barplot(
    c(10, 20, 30),
    names.arg = c("A", "B", "C"),
    main = "Test Bar Plot"
  )
}

#' Create a simple Base R histogram for testing
#' @return NULL (creates plot on current device)
create_test_base_r_histogram <- function() {
  hist(
    rnorm(100),
    main = "Test Histogram",
    xlab = "Value"
  )
}

#' Create a simple Base R line plot for testing
#' @return NULL (creates plot on current device)
create_test_base_r_line <- function() {
  plot(
    1:10,
    rnorm(10),
    type = "l",
    main = "Test Line Plot"
  )
}

#' Create a simple Base R scatter plot for testing
#' @return NULL (creates plot on current device)
create_test_base_r_point <- function() {
  plot(
    mtcars$wt[1:10],
    mtcars$mpg[1:10],
    main = "Test Scatter Plot"
  )
}

#' Create a simple Base R boxplot for testing
#' @return NULL (creates plot on current device)
create_test_base_r_boxplot <- function() {
  boxplot(
    mpg ~ cyl,
    data = mtcars,
    main = "Test Boxplot"
  )
}

# ============================================================================
# Cleanup Functions
# ============================================================================

#' Clear Base R plot state for testing
#'
#' This function clears the device storage and state tracking
#' to ensure tests start with a clean slate.
#'
#' @return NULL
clear_base_r_state <- function() {
  if (maidr:::is_patching_active()) {
    device_id <- dev.cur()
    if (maidr:::has_device_calls(device_id)) {
      maidr:::clear_device_storage(device_id)
    }
  }
}

#' Setup function to run before each test
#'
#' Ensures clean state before each test runs
#'
#' @return NULL
test_setup <- function() {
  clear_base_r_state()
}

#' Teardown function to run after each test
#'
#' Cleans up after each test
#'
#' @return NULL
test_teardown <- function() {
  clear_base_r_state()
}

# ============================================================================
# Custom Assertion Helpers
# ============================================================================

#' Expect MAIDR data structure is valid
#'
#' @param maidr_data The MAIDR data object to check
#' @return NULL (throws error if invalid)
expect_maidr_data_structure <- function(maidr_data) {
  testthat::expect_type(maidr_data, "list")
  testthat::expect_true("id" %in% names(maidr_data))
  testthat::expect_true("subplots" %in% names(maidr_data))
  testthat::expect_type(maidr_data$subplots, "list")
}

#' Expect layer has data
#'
#' @param layer The layer object to check
#' @return NULL (throws error if invalid)
expect_layer_has_data <- function(layer) {
  testthat::expect_true("data" %in% names(layer))
  testthat::expect_type(layer$data, "list")
  testthat::expect_true(length(layer$data) > 0)
}

#' Expect layer has selectors
#'
#' @param layer The layer object to check
#' @return NULL (throws error if invalid)
expect_layer_has_selectors <- function(layer) {
  testthat::expect_true("selectors" %in% names(layer))
  testthat::expect_type(layer$selectors, "character")
  testthat::expect_true(length(layer$selectors) > 0)
}

#' Expect HTML contains MAIDR elements
#'
#' @param html The HTML string to check
#' @return NULL (throws error if invalid)
expect_html_has_maidr <- function(html) {
  html_str <- as.character(html)
  testthat::expect_match(html_str, "<svg")
  testthat::expect_match(html_str, "maidr")
}

#' Expect widget is valid htmlwidget
#'
#' @param widget The widget object to check
#' @return NULL (throws error if invalid)
expect_valid_maidr_widget <- function(widget) {
  testthat::expect_s3_class(widget, "htmlwidget")
  testthat::expect_s3_class(widget, "maidr")
  testthat::expect_true("x" %in% names(widget))
}
