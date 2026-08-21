# A layer with nothing to announce still cost the whole chart (#211)
#
# `detect_layer_type()` returning "unknown" is what makes
# `has_unsupported_layers()` true, which drops the **whole plot** to a static
# image -- the cost #176 measured for a reference line and #197 for an
# annotation, both since answered with "skip". Two more layers were paying it,
# and neither carries an observation to lose.
#
# Measured on ggplot2 3.4.4 through `save_html()`, the same three-bar chart in
# every row:
#
#     geom_col()                                interactive   39,116 bytes
#     geom_col() + geom_text(aes(label = v))    interactive   41,339 bytes
#     geom_col() + geom_label(aes(label = v))   base64 image  17,220 bytes
#     geom_col() + geom_blank()                 base64 image  13,380 bytes
#
# `geom_label()` is `geom_text()` with a rounded rectangle behind it, and
# `GeomText` was already skipped -- but `GeomLabel` is a *sibling* of it, both
# direct `Geom` children, so the exact class test missed it. Which of the two
# spellings the author happened to reach for decided whether the chart kept
# any interactivity.
#
# `geom_blank()` draws nothing whatsoever. It is how one forces a scale limit,
# so it lands on charts that are otherwise entirely readable.
#
# What these cases pin is both halves: that the two are skipped, and that
# skipping them does not invent a reading for a plot which has nothing else in
# it.

skip_unless_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

bars_frame <- function() {
  data.frame(g = c("a", "b", "c"), v = c(3, 7, 5), stringsAsFactors = FALSE)
}

detected <- function(plot, index) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

# Render through `save_html()` and report what a reader actually receives.
rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  warnings_seen <- character(0)
  withCallingHandlers(
    maidr::save_html(plot, file = file),
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  list(
    interactive = grepl("<svg", html, fixed = TRUE) &&
      !grepl("base64", html, fixed = TRUE),
    fell_back = any(grepl("static image", warnings_seen, fixed = TRUE))
  )
}

bar_with <- function(extra) {
  ggplot2::ggplot(bars_frame(), ggplot2::aes(g, v)) +
    ggplot2::geom_col() +
    extra
}


test_that("a text label is skipped whichever geom drew it", {
  skip_unless_ggplot2()

  text <- bar_with(ggplot2::geom_text(ggplot2::aes(label = v)))
  label <- bar_with(ggplot2::geom_label(ggplot2::aes(label = v)))

  # The asymmetry itself: the same annotation, the same answer.
  testthat::expect_equal(detected(text, 2), "skip")
  testthat::expect_equal(detected(label, 2), "skip")
})

test_that("a layer that draws nothing is skipped", {
  skip_unless_ggplot2()

  testthat::expect_equal(detected(bar_with(ggplot2::geom_blank()), 2), "skip")
})

test_that("the bar beside them is still read as a bar", {
  skip_unless_ggplot2()

  # Skipping must take the layer out of the way, not out of the chart. If the
  # first layer stopped being read, the cases above would pass while the
  # reader lost the very thing they were meant to keep.
  testthat::expect_equal(detected(bar_with(ggplot2::geom_label(ggplot2::aes(label = v))), 1), "bar")
  testthat::expect_equal(detected(bar_with(ggplot2::geom_blank()), 1), "bar")
})

test_that("neither layer costs the chart its interactivity any more", {
  skip_unless_ggplot2()

  for (extra in list(
    ggplot2::geom_label(ggplot2::aes(label = v)),
    ggplot2::geom_blank()
  )) {
    result <- rendered(bar_with(extra))
    testthat::expect_true(result$interactive)
    testthat::expect_false(result$fell_back)
  }
})

test_that("a plot that is nothing but a drawless layer still falls back", {
  skip_unless_ggplot2()

  # The other half, and the one a "skip" can get wrong: a chart whose every
  # layer is skipped has no data to announce, and must fall back rather than
  # present itself as an empty but navigable chart. It falls back because it
  # reads as no layers at all, not because of a rule about geoms -- the same
  # reasoning #197 recorded for a plot made only of annotations.
  plot <- ggplot2::ggplot(bars_frame(), ggplot2::aes(g, v)) +
    ggplot2::geom_blank()

  testthat::expect_equal(detected(plot, 1), "skip")
  testthat::expect_false(rendered(plot)$interactive)
})
