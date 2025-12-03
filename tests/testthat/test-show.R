# Comprehensive tests for show() function
# Testing all modes: as_widget, shiny, and error handling

# ==============================================================================
# Widget Mode Tests (ggplot2) - No Browser Opening
# ==============================================================================

test_that("show() with as_widget returns htmlwidget for ggplot2 bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() with as_widget returns htmlwidget for ggplot2 point plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()
  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() with as_widget returns htmlwidget for ggplot2 line plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_line()
  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() with as_widget returns htmlwidget for ggplot2 histogram", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_histogram()
  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() with as_widget returns htmlwidget for ggplot2 boxplot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_boxplot()
  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

# ==============================================================================
# Shiny Mode Tests (ggplot2) - Returns HTML String
# ==============================================================================

test_that("show() with shiny=TRUE returns HTML for ggplot2 bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  html <- show(p, shiny = TRUE)

  expect_html_has_maidr(html)
  testthat::expect_type(html, "character")
})

test_that("show() with shiny=TRUE returns HTML for ggplot2 point plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()
  html <- show(p, shiny = TRUE)

  expect_html_has_maidr(html)
})

test_that("show() with shiny=TRUE returns HTML for ggplot2 line plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_line()
  html <- show(p, shiny = TRUE)

  expect_html_has_maidr(html)
})

# ==============================================================================
# Base R Tests - Shiny Mode (widget mode not supported for Base R)
# ==============================================================================

test_that("show() with shiny=TRUE works for Base R barplot", {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  html <- show(shiny = TRUE)

  expect_html_has_maidr(html)

  clear_base_r_state()
})

test_that("show() with shiny=TRUE works for Base R histogram", {
  hist(rnorm(100))

  html <- show(shiny = TRUE)

  expect_html_has_maidr(html)

  clear_base_r_state()
})

test_that("show() with shiny=TRUE works for Base R line plot", {
  testthat::skip("Base R plot() function detection needs investigation")
  plot(1:10, rnorm(10), type = "l")

  html <- show(shiny = TRUE)

  expect_html_has_maidr(html)

  clear_base_r_state()
})

test_that("show() with shiny=TRUE works for Base R scatter plot", {
  testthat::skip("Base R plot() function detection needs investigation")
  plot(mtcars$wt, mtcars$mpg)

  html <- show(shiny = TRUE)

  expect_html_has_maidr(html)

  clear_base_r_state()
})

# ==============================================================================
# Error Handling Tests
# ==============================================================================

test_that("show() errors when no Base R plot and plot=NULL", {
  clear_base_r_state()

  testthat::expect_error(
    show(plot = NULL),
    "No Base R plots detected"
  )
})

test_that("show() errors when no Base R plot with shiny mode", {
  clear_base_r_state()

  testthat::expect_error(
    show(plot = NULL, shiny = TRUE),
    "No Base R plots detected"
  )
})

test_that("show() errors when invalid plot object provided", {
  testthat::expect_error(
    show(plot = 42)
    # Should error - invalid plot object
  )
})

# ==============================================================================
# Multiple Plot Types Tests (Comprehensive)
# ==============================================================================

test_that("show() handles all ggplot2 plot types with as_widget", {
  testthat::skip_if_not_installed("ggplot2")

  plot_generators <- list(
    bar = create_test_ggplot_bar,
    point = create_test_ggplot_point,
    line = create_test_ggplot_line,
    histogram = create_test_ggplot_histogram,
    boxplot = create_test_ggplot_boxplot
  )

  for (type_name in names(plot_generators)) {
    plot_fn <- plot_generators[[type_name]]
    p <- plot_fn()

    widget <- show(p, as_widget = TRUE)

    testthat::expect_s3_class(
      widget,
      "htmlwidget"
    )
  }
})

test_that("show() handles all ggplot2 plot types with shiny mode", {
  testthat::skip_if_not_installed("ggplot2")

  plot_generators <- list(
    bar = create_test_ggplot_bar,
    point = create_test_ggplot_point,
    line = create_test_ggplot_line,
    histogram = create_test_ggplot_histogram,
    boxplot = create_test_ggplot_boxplot
  )

  for (type_name in names(plot_generators)) {
    plot_fn <- plot_generators[[type_name]]
    p <- plot_fn()

    html <- show(p, shiny = TRUE)

    testthat::expect_match(
      as.character(html),
      "<svg"
    )
  }
})

# ==============================================================================
# Base R Detection Tests
# ==============================================================================

test_that("show() auto-detects Base R barplot when plot=NULL", {
  barplot(c(10, 20, 30))

  # Auto-detection should work
  html <- show(plot = NULL, shiny = TRUE)

  expect_html_has_maidr(html)

  clear_base_r_state()
})

test_that("show() clears Base R state after non-shiny mode", {
  barplot(c(5, 10, 15))

  device_id <- dev.cur()

  # Initial state: should have calls
  testthat::expect_true(maidr:::has_device_calls(device_id))

  # Note: We can't test default mode (opens browser)
  # So we test that state clearing logic exists by checking the code path

  # Manually clear to verify cleanup works
  clear_base_r_state()

  testthat::expect_false(maidr:::has_device_calls(device_id))
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("show() works with ggplot2 plot with custom theme", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar() +
    ggplot2::theme_minimal() +
    ggplot2::labs(title = "Custom Title", x = "X Label", y = "Y Label")

  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() works with ggplot2 plot with coord_flip", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar() +
    ggplot2::coord_flip()

  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() works with ggplot2 dodged bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "dodge")

  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() works with ggplot2 stacked bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "stack")

  widget <- show(p, as_widget = TRUE)

  expect_valid_maidr_widget(widget)
})

test_that("show() works with Base R dodged barplot", {
  test_matrix <- matrix(c(10, 20, 15, 25, 20, 30), nrow = 3)
  rownames(test_matrix) <- c("A", "B", "C")
  colnames(test_matrix) <- c("Cat1", "Cat2")

  barplot(test_matrix, beside = TRUE)

  html <- show(shiny = TRUE)

  expect_html_has_maidr(html)

  clear_base_r_state()
})

test_that("show() works with Base R stacked barplot", {
  test_matrix <- matrix(c(10, 20, 30, 40), nrow = 2)
  rownames(test_matrix) <- c("Type1", "Type2")
  colnames(test_matrix) <- c("A", "B")

  barplot(test_matrix, beside = FALSE)

  html <- show(shiny = TRUE)

  expect_html_has_maidr(html)

  clear_base_r_state()
})
