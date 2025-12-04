# Comprehensive tests for maidr_widget() and Shiny integration
# Testing widget creation, Shiny UI/server functions

# ==============================================================================
# maidr_widget() Tests
# ==============================================================================

test_that("maidr_widget() creates valid htmlwidget for bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  expect_valid_maidr_widget(widget)
})

test_that("maidr_widget() creates valid htmlwidget for point plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()
  widget <- maidr_widget(p)

  expect_valid_maidr_widget(widget)
})

test_that("maidr_widget() creates valid htmlwidget for line plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_line()
  widget <- maidr_widget(p)

  expect_valid_maidr_widget(widget)
})

test_that("maidr_widget() widget contains SVG content", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  testthat::expect_true("x" %in% names(widget))
  testthat::expect_type(widget$x, "list")
  testthat::expect_true("svg_content" %in% names(widget$x))
})

test_that("maidr_widget() widget has correct dependencies", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  testthat::expect_true("dependencies" %in% names(widget))
  testthat::expect_type(widget$dependencies, "list")

  # Check for maidr-js dependency
  dep_names <- sapply(widget$dependencies, function(d) d$name)
  testthat::expect_true("maidr-js" %in% dep_names)
})

test_that("maidr_widget() respects width and height parameters", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p, width = "800px", height = "600px")

  testthat::expect_equal(widget$width, "800px")
  testthat::expect_equal(widget$height, "600px")
})

test_that("maidr_widget() accepts element_id parameter", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p, element_id = "my-plot-123")

  testthat::expect_equal(widget$elementId, "my-plot-123")
})

test_that("maidr_widget() errors for non-ggplot objects", {
  testthat::expect_error(
    maidr_widget(plot = NULL),
    "Input must be a ggplot object"
  )

  testthat::expect_error(
    maidr_widget(plot = 42),
    "Input must be a ggplot object"
  )

  testthat::expect_error(
    maidr_widget(plot = list(a = 1)),
    "Input must be a ggplot object"
  )
})

# ==============================================================================
# Shiny Integration Tests - maidr_output()
# ==============================================================================

test_that("maidr_output() creates Shiny widget output", {
  output <- maidr_output("plot1")

  testthat::expect_s3_class(output, "shiny.tag.list")
})

test_that("maidr_output() uses correct output_id", {
  output <- maidr_output("myplot")

  # Convert to character to inspect
  output_str <- as.character(output)

  testthat::expect_match(output_str, "myplot")
})

test_that("maidr_output() accepts width and height", {
  output <- maidr_output("plot1", width = "100%", height = "500px")

  testthat::expect_s3_class(output, "shiny.tag.list")

  # Verify dimensions are applied
  output_str <- as.character(output)
  testthat::expect_match(output_str, "100%")
  testthat::expect_match(output_str, "500px")
})

test_that("maidr_output() creates different outputs for different IDs", {
  output1 <- maidr_output("plot1")
  output2 <- maidr_output("plot2")

  str1 <- as.character(output1)
  str2 <- as.character(output2)

  testthat::expect_match(str1, "plot1")
  testthat::expect_match(str2, "plot2")
})

# ==============================================================================
# Shiny Integration Tests - render_maidr()
# ==============================================================================

test_that("render_maidr() creates render function", {
  testthat::skip_if_not_installed("ggplot2")

  render_fn <- render_maidr({
    create_test_ggplot_bar()
  })

  testthat::expect_type(render_fn, "closure")
  testthat::expect_true(is.function(render_fn))
})

test_that("render_maidr() accepts quoted expressions", {
  testthat::skip_if_not_installed("ggplot2")

  expr <- quote(create_test_ggplot_bar())

  render_fn <- render_maidr(expr, quoted = TRUE)

  testthat::expect_type(render_fn, "closure")
})

test_that("render_maidr() works with environment parameter", {
  testthat::skip_if_not_installed("ggplot2")

  env <- new.env()
  env$my_plot <- create_test_ggplot_bar()

  render_fn <- render_maidr(
    {
      my_plot
    },
    env = env
  )

  testthat::expect_type(render_fn, "closure")
})

# ==============================================================================
# Alternative Widget Functions (Internal)
# ==============================================================================

test_that("maidr_widget_output() creates Shiny output", {
  output <- maidr_widget_output("plot1")

  testthat::expect_s3_class(output, "shiny.tag.list")
})

test_that("maidr_widget_output() accepts dimensions", {
  output <- maidr_widget_output("plot1", width = "90%", height = "450px")

  testthat::expect_s3_class(output, "shiny.tag.list")

  output_str <- as.character(output)
  testthat::expect_match(output_str, "90%")
  testthat::expect_match(output_str, "450px")
})

test_that("render_maidr_widget() creates render function", {
  testthat::skip_if_not_installed("ggplot2")

  render_fn <- render_maidr_widget({
    create_test_ggplot_bar()
  })

  testthat::expect_type(render_fn, "closure")
})

# ==============================================================================
# Widget Structure Tests
# ==============================================================================

test_that("widget has correct class structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  classes <- class(widget)

  testthat::expect_true("maidr" %in% classes)
  testthat::expect_true("htmlwidget" %in% classes)
})

test_that("widget has sizing policy", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  testthat::expect_true("sizingPolicy" %in% names(widget))
  testthat::expect_type(widget$sizingPolicy, "list")
})

test_that("widget dependencies include CSS", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  deps <- widget$dependencies

  # Find maidr-js dependency
  maidr_dep <- Find(function(d) d$name == "maidr-js", deps)

  testthat::expect_false(is.null(maidr_dep))
  testthat::expect_true("stylesheet" %in% names(maidr_dep))
})

test_that("widget dependencies include JavaScript", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  deps <- widget$dependencies

  # Find maidr-js dependency
  maidr_dep <- Find(function(d) d$name == "maidr-js", deps)

  testthat::expect_false(is.null(maidr_dep))
  testthat::expect_true("script" %in% names(maidr_dep))
  testthat::expect_equal(maidr_dep$script, "maidr.js")
})

# ==============================================================================
# Integration with create_maidr_html()
# ==============================================================================

test_that("widget uses create_maidr_html() internally", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()

  # Get HTML from create_maidr_html
  html_direct <- maidr:::create_maidr_html(p, shiny = TRUE)

  # Get HTML from widget
  widget <- maidr_widget(p)
  html_from_widget <- widget$x$svg_content

  # Both should contain SVG
  testthat::expect_match(as.character(html_direct), "<svg")
  testthat::expect_match(as.character(html_from_widget), "<svg")
})

# ==============================================================================
# Multiple Plot Types
# ==============================================================================

test_that("maidr_widget() works for all plot types", {
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

    widget <- maidr_widget(p)

    testthat::expect_s3_class(
      widget,
      "htmlwidget"
    )
  }
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("widget handles NULL width and height", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p, width = NULL, height = NULL)

  testthat::expect_s3_class(widget, "htmlwidget")
  testthat::expect_null(widget$width)
  testthat::expect_null(widget$height)
})

test_that("widget handles complex ggplot2 objects", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar() +
    ggplot2::theme_minimal() +
    ggplot2::labs(title = "Complex Plot", subtitle = "With Subtitle") +
    ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5))

  widget <- maidr_widget(p)

  expect_valid_maidr_widget(widget)
})

test_that("widget works with dodged bar plots", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "dodge")

  widget <- maidr_widget(p)

  expect_valid_maidr_widget(widget)
})
