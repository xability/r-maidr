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

test_that("maidr_widget() widget contains iframe content", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  testthat::expect_true("x" %in% names(widget))
  testthat::expect_type(widget$x, "list")
  # With iframe-based approach, we use iframe_content instead of svg_content
  testthat::expect_true("iframe_content" %in% names(widget$x))
})

test_that("maidr_widget() widget has correct structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  # With iframe-based approach, dependencies are bundled inside the iframe
  # so we check for the widget binding dependency instead
  testthat::expect_true("dependencies" %in% names(widget))
  # Dependencies may be NULL or list with iframe approach
  testthat::expect_true(is.null(widget$dependencies) || is.list(widget$dependencies))
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
    maidr_widget(plot = 42),
    "Input must be a ggplot object"
  )

  testthat::expect_error(
    maidr_widget(plot = list(a = 1)),
    "Input must be a ggplot object"
  )
})

test_that("maidr_widget(NULL) requires recorded Base R plots", {
  # NULL now means Base R auto-detection (mirroring show()); without any
  # recorded plot calls it must fail with a clear message.
  maidr:::clear_all_device_storage()

  testthat::expect_error(
    maidr_widget(plot = NULL),
    "No Base R plots detected"
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

test_that("widget iframe carries its content in srcdoc, not a data URL", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  iframe_content <- widget$x$iframe_content

  # `srcdoc` rather than `data:`, because a `data:` document has an opaque
  # origin and Web Bluetooth and Web Serial are unavailable to one whatever
  # the `allow` attribute says --- so a Dot Pad could not be connected from an
  # R chart at all. Measured in Chromium: a `data:` frame carrying
  # `allow="serial"` reports the feature allowed and still has no
  # `navigator.serial`; a `srcdoc` frame has it.
  testthat::expect_match(iframe_content, "<iframe", fixed = TRUE)
  testthat::expect_match(iframe_content, "srcdoc=\"", fixed = TRUE)
  testthat::expect_false(grepl("data:text/html", iframe_content, fixed = TRUE))
})

test_that("widget iframe delegates bluetooth and serial", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  widget <- maidr_widget(p)

  # Inheritance covers the same-origin case on its own; `allow` is what
  # carries the features into a chart that is itself inside a cross-origin
  # frame. It delegates rather than creates: a frame cannot receive a feature
  # the embedding page lacks, and the browser still asks the reader to pick
  # the device.
  testthat::expect_match(
    widget$x$iframe_content,
    'allow="bluetooth; serial"',
    fixed = TRUE
  )
})

# ==============================================================================
# Integration with create_maidr_html()
# ==============================================================================

test_that("widget uses create_maidr_html() internally", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()

  # Get HTML from create_maidr_html
  html_direct <- maidr:::create_maidr_html(p, shiny = TRUE)

  # Get HTML from widget (iframe-based approach)
  widget <- maidr_widget(p)
  iframe_content <- widget$x$iframe_content

  # Direct HTML should contain SVG
  testthat::expect_match(as.character(html_direct), "<svg")


  # iframe_content should contain the iframe tag with embedded content
  testthat::expect_match(iframe_content, "<iframe", fixed = TRUE)
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

# ==============================================================================
# Non-ASCII labels survive the trip into the frame
#
# They did not before. `enc2utf8()` on an unmarked string assumes the native
# encoding, and under a C locale — a container, a CI runner, plenty of servers
# — it cannot represent the bytes it finds and rewrites each one as the text
# `<ed>`, `<95>`, `<9c>`. A Korean title reached the reader as that, and it did
# so through the base64 encoding `srcdoc` replaced as well.
# ==============================================================================

test_that("a non-ASCII title reaches the frame intact", {
  title <- "éü 한글"
  svg <- paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" maidr-data=\'{"id":"x","title":"',
    title, '"}\'><rect/></svg>'
  )

  iframe <- maidr:::create_maidr_iframe(svg, use_cdn = TRUE, plot_id = "enc")

  # The bytes themselves, not a rendering of them: `grepl` would compare a
  # marked needle against unmarked hay and convert one of them on the way.
  testthat::expect_true(
    length(grepRaw(charToRaw(title), charToRaw(iframe), fixed = TRUE)) > 0
  )
  testthat::expect_false(grepl("&lt;ed&gt;", iframe, fixed = TRUE))
})

test_that("attribute-significant characters in a label are escaped, not dropped", {
  svg <- paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" maidr-data=\'{"id":"x",',
    '"title":"A &amp; B"}\'><rect/></svg>'
  )

  iframe <- maidr:::create_maidr_iframe(svg, use_cdn = TRUE, plot_id = "esc")

  # A raw quote would end the attribute and spill the rest of the document
  # into the page as markup.
  testthat::expect_match(iframe, "&quot;", fixed = TRUE)
  testthat::expect_match(iframe, "&lt;rect/&gt;", fixed = TRUE)
})

test_that("an online widget frame falls back to the page's copy of the bundle", {
  testthat::skip_if_not_installed("ggplot2")

  # The frame's `<script src>` sits inside `srcdoc`, out of reach of R
  # Markdown's `self_contained` and Quarto's `embed-resources`; the page's
  # copy, declared in the widget's yaml, is what they embed.
  online <- maidr_widget(create_test_ggplot_bar(), use_cdn = TRUE)$x$iframe_content
  testthat::expect_true(grepl("s.onerror = fromPage;", online, fixed = TRUE))
  testthat::expect_true(grepl(maidr:::MAIDR_PAGE_JS_TYPE, online, fixed = TRUE))

  # Offline the bundle travels in the frame, with nothing to fall back to.
  offline <- maidr_widget(create_test_ggplot_bar(), use_cdn = FALSE)$x$iframe_content
  testthat::expect_false(grepl("fromPage", offline, fixed = TRUE))
})

test_that("a self-contained R Markdown document carries a widget's bundle once", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")

  dir <- tempfile("maidr-widget-rmd-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  rmd <- file.path(dir, "widgets.Rmd")
  writeLines(c(
    "---",
    "title: widgets",
    "output:",
    "  html_document:",
    "    self_contained: true",
    "---",
    "```{r, echo = FALSE}",
    "library(ggplot2)",
    "p <- ggplot(mtcars, aes(factor(cyl))) + geom_bar()",
    "maidr::show(p, as_widget = TRUE, use_cdn = TRUE)",
    "maidr::show(p, as_widget = TRUE, use_cdn = TRUE)",
    "```"
  ), rmd)

  out <- rmarkdown::render(rmd, quiet = TRUE, envir = new.env())
  html <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  testthat::expect_false(dir.exists(file.path(dir, "widgets_files")))
  pattern <- sprintf('<script[^>]*type="%s"', maidr:::MAIDR_PAGE_JS_TYPE)
  testthat::expect_identical(lengths(regmatches(html, gregexpr(pattern, html))), 1L)

  # The page's copy is the only one, and it is inert: no script the browser
  # runs carries the bundle.
  bundle <- substr(readLines(maidr:::maidr_local_assets()$js, n = 1L, warn = FALSE), 1L, 200L)
  testthat::expect_identical(lengths(regmatches(html, gregexpr(bundle, html, fixed = TRUE))), 1L)
})
