# A bare `geom_ribbon()` was read as nothing at all (#135).
#
# It is the other way to draw a confidence band, and the one a user gets when
# they assemble `geom_smooth()`'s two halves by hand. It fell through to
# `Ggplot2UnknownLayerProcessor`, so the interval was dropped -- the same loss
# the other uncertainty geoms had before they were supported.
#
# What makes it its own case rather than one more name in the membership test
# is that a ribbon is not automatically an interval:
# `geom_ribbon(aes(ymin = 0, ymax = y))` is an area chart. Reading that as an
# uncertainty would announce the whole magnitude as a bound; reading a real
# band as an area would announce `ymax` as a magnitude and drop `ymin`
# entirely. The baseline is what separates them, which is the same rule the
# Python binding draws for `fill_between()`.

ribbon_df <- function() {
  data.frame(x = 1:10, y = 1:10, lo = (1:10) - 1, hi = (1:10) + 1)
}

detect <- function(plot, index = 1L) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

layer_types <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  out <- character(0)
  for (sp in res$subplots) {
    for (cell in sp) {
      for (ly in cell$layers) out <- c(out, ly$type)
    }
  }
  out
}

test_that("a ribbon spanning two curves is read as an interval", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(ribbon_df(), ggplot2::aes(x)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi), alpha = 0.3) +
    ggplot2::geom_line(ggplot2::aes(y = y))

  testthat::expect_equal(detect(plot), "error_bar")
})

test_that("the line beside a band keeps its own reading", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(ribbon_df(), ggplot2::aes(x)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi), alpha = 0.3) +
    ggplot2::geom_line(ggplot2::aes(y = y))

  testthat::expect_equal(detect(plot, 2L), "line")
  testthat::expect_equal(layer_types(plot), c("error_bar", "line"))
})

test_that("a ribbon filling from zero is read as an area", {
  testthat::skip_if_not_installed("ggplot2")

  # The failure this guard prevents runs the other way: announcing a filled
  # magnitude as an uncertainty tells a reader the chart is less certain than
  # it is, about data that carries no uncertainty at all.
  plot <- ggplot2::ggplot(ribbon_df(), ggplot2::aes(x)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = 0, ymax = y), alpha = 0.3)

  testthat::expect_equal(detect(plot), "area")
  testthat::expect_equal(layer_types(plot), "area")
})

test_that("geom_area still reaches its own branch", {
  testthat::skip_if_not_installed("ggplot2")

  # `GeomArea` inherits `GeomRibbon`, so the ribbon rule has to be a
  # `class(...)[1]` test rather than an `inherits()` one. Pinned because an
  # `inherits()` check would look correct and silently swallow every area
  # chart into the ribbon branch.
  plot <- ggplot2::ggplot(ribbon_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_area()

  testthat::expect_equal(detect(plot), "area")
})

test_that("a stacked area is unaffected", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(1:5, 2),
    y = c(1:5, 5:1),
    g = rep(c("a", "b"), each = 5)
  )
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y, fill = g)) +
    ggplot2::geom_area()

  # Asserted on what is *emitted*, not on what `detect_layer_type()` returns.
  # Whether the bands stack is not knowable from the geom and position alone
  # -- a single-series area is drawn with `PositionStack` too -- so detection
  # answers `area` and the orchestrator resolves the stacking afterwards.
  testthat::expect_equal(detect(plot), "area")
  testthat::expect_equal(layer_types(plot), "stacked_area")
})

test_that("geom_smooth is unaffected", {
  testthat::skip_if_not_installed("ggplot2")

  # It draws a ribbon internally, but the layer's geom is `GeomSmooth`, so it
  # never reaches the ribbon branch -- its band is carried by the smooth
  # processor instead.
  plot <- ggplot2::ggplot(ribbon_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)

  testthat::expect_equal(detect(plot), "smooth")
})

test_that("a one-sided ribbon whose lower edge is a constant is a band", {
  testthat::skip_if_not_installed("ggplot2")

  # Only an identically-*zero* lower edge is an area. A ribbon measured from
  # some other constant still draws the gap between two curves, and its
  # heights are measured from somewhere the announcement would not mention.
  plot <- ggplot2::ggplot(ribbon_df(), ggplot2::aes(x)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = 2, ymax = hi), alpha = 0.3)

  testthat::expect_equal(detect(plot), "error_bar")
})
