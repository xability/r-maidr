# `geom_smooth()` drew its confidence band and MAIDR dropped it (#135).
#
# `se = TRUE` is the default, and the band is the reason the layer is drawn
# rather than a plain line: it says how much of the fitted trend the data
# supports. `StatSmooth` computes it into `ymin`/`ymax` alongside the fitted
# `y`, and the processor read only `y` -- so a chart that otherwise worked was
# silently missing the half a reader needs to judge it.
#
# The band rides on the fitted samples as `yMin`/`yMax` (#172). It was emitted
# as a separate `error_bar` layer at first, because that was the only shape the
# core read; xability/maidr#920 put the bounds on `LinePoint`, `SmoothTrace`
# extends `LineTrace`, and maidr 4.3.0 shipped it. So the value and its
# interval are now heard at one x rather than by switching layers, and three
# pieces of scaffolding went away with the second layer:
#
#   * the per-curve `name`, needed only because an `ErrorBarPoint` carries no
#     `z` and a hue-split chart therefore needed one band layer per curve;
#   * the facet guard, which suppressed the band entirely on a faceted chart
#     because the facet path collapses a panel to a single layer;
#   * the empty selector list, which existed to say a ribbon has no per-sample
#     element to highlight -- the smooth layer's own selectors now serve.
#
# The Python binding emits the same shape for `sns.regplot`
# (xability/py-maidr#425), so the two bindings describe an interval alike.

smooth_band_df <- function() {
  set.seed(1)
  data.frame(x = 1:20, y = (1:20) + stats::rnorm(20, sd = 3))
}

hue_df <- function() {
  set.seed(2)
  data.frame(
    x = rep(1:10, 2),
    y = c((1:10) + stats::rnorm(10), (10:1) + stats::rnorm(10)),
    g = rep(c("a", "b"), each = 10)
  )
}

# Drive the whole orchestrator rather than the processor alone: what a reader
# receives is what the assembling path emitted, not what one processor built.
emitted_layers <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  out <- list()
  for (sp in res$subplots) {
    for (cell in sp) {
      for (ly in cell$layers) out[[length(out) + 1L]] <- ly
    }
  }
  out
}

layer_types <- function(plot) {
  vapply(emitted_layers(plot), function(ly) ly$type, character(1))
}

#' Every series of the first smooth layer, as a list of point lists.
smooth_series <- function(plot) {
  for (ly in emitted_layers(plot)) {
    if (identical(ly$type, "smooth")) {
      data <- ly$data
      if (length(data) && is.list(data[[1]]) && is.null(data[[1]]$x)) {
        return(data)
      }
      return(list(data))
    }
  }
  NULL
}

#' The point list a layer carries, whether or not it is wrapped as one series.
points_of <- function(data) {
  if (length(data) && is.list(data[[1]]) && is.null(data[[1]]$x)) {
    return(data[[1]])
  }
  data
}

bounded <- function(points) {
  sum(vapply(points, function(p) !is.null(p$yMin) && !is.null(p$yMax), logical(1)))
}

test_that("the band rides on the fitted curve rather than a second layer", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)

  testthat::expect_equal(layer_types(plot), "smooth")
})

test_that("every sample of the curve carries its interval", {
  testthat::skip_if_not_installed("ggplot2")

  # Not "most of them": a reader arrives at an arbitrary x, and a curve whose
  # bounds are present only in places is worse than one with none, because
  # nothing announces which kind of sample they landed on.
  series <- smooth_series(
    ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
      ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)
  )

  testthat::expect_length(series, 1)
  testthat::expect_equal(bounded(series[[1]]), length(series[[1]]))
})

test_that("the bounds bracket the fitted value", {
  testthat::skip_if_not_installed("ggplot2")

  # The band is around the curve. A sample outside its own interval would mean
  # the two edges had been read the wrong way round, which is the failure that
  # looks entirely plausible in the payload.
  series <- smooth_series(
    ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
      ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)
  )

  for (point in series[[1]]) {
    testthat::expect_lte(point$yMin, point$y)
    testthat::expect_lte(point$y, point$yMax)
  }
})

test_that("the interval narrows where the data is dense", {
  testthat::skip_if_not_installed("ggplot2")

  # What separates a band that was read from one that was invented. A
  # confidence band on a linear fit is narrowest near the centre of x and
  # widest at the ends; if the bounds were taken from the wrong rows, or
  # untransformed against a mismatched grid, that shape is the first thing to
  # go.
  points <- smooth_series(
    ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
      ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)
  )[[1]]
  widths <- vapply(points, function(p) p$yMax - p$yMin, numeric(1))
  middle <- widths[[ceiling(length(widths) / 2)]]

  testthat::expect_lt(middle, widths[[1]])
  testthat::expect_lt(middle, widths[[length(widths)]])
})

test_that("se = FALSE draws no band and emits none", {
  testthat::skip_if_not_installed("ggplot2")

  # The columns are still there, filled with NA, so their presence cannot be
  # the test.
  series <- smooth_series(
    ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
      ggplot2::geom_smooth(method = "lm", se = FALSE, formula = y ~ x)
  )

  testthat::expect_equal(bounded(series[[1]]), 0)
  testthat::expect_gt(length(series[[1]]), 0)
})

test_that("a loess fit carries its band too", {
  testthat::skip_if_not_installed("ggplot2")

  series <- smooth_series(
    ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
      ggplot2::geom_smooth(method = "loess", se = TRUE, formula = y ~ x)
  )

  testthat::expect_equal(bounded(series[[1]]), length(series[[1]]))
})

test_that("each curve of a hue-split smooth carries its own band", {
  testthat::skip_if_not_installed("ggplot2")

  # This is what removed the per-curve naming. A band used to need a layer of
  # its own per curve, because `ErrorBarPoint` carries no `z` and concatenating
  # the curves would have walked a reader off the end of one into the start of
  # the next. Riding on the smooth points, each curve keeps its own `z` and the
  # question does not arise.
  series <- smooth_series(
    ggplot2::ggplot(hue_df(), ggplot2::aes(x, y, colour = g)) +
      ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)
  )

  testthat::expect_length(series, 2)
  for (points in series) {
    testthat::expect_equal(bounded(points), length(points))
  }
  testthat::expect_equal(
    sort(unique(vapply(series, function(pts) as.character(pts[[1]]$z), ""))),
    c("a", "b")
  )
})

test_that("no curve walks backwards into the next", {
  testthat::skip_if_not_installed("ggplot2")

  # The seam this guards was real when the bands were concatenated into one
  # flat sequence: x jumped from the end of one curve back to the start of the
  # next with nothing announced between.
  for (points in smooth_series(
    ggplot2::ggplot(hue_df(), ggplot2::aes(x, y, colour = g)) +
      ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)
  )) {
    xs <- vapply(points, function(p) as.numeric(p$x), numeric(1))
    testthat::expect_false(is.unsorted(xs))
  }
})

test_that("a density curve is not read as having a confidence band", {
  testthat::skip_if_not_installed("ggplot2")

  # `StatDensity` fills the same two columns with the *extent of its fill* --
  # `ymin = 0`, `ymax = density` -- rather than an uncertainty. Measured: all
  # of its rows carry finite bounds, so the columns cannot be the test and the
  # layer's stat is asked instead. Announcing a density curve as having a
  # confidence band from zero is a claim about the data rather than a missing
  # feature, which is the worse of the two failures.
  series <- smooth_series(
    ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x)) + ggplot2::geom_density()
  )

  testthat::expect_equal(bounded(series[[1]]), 0)
})

test_that("a filled density drawn with geom_area is not read as a band", {
  testthat::skip_if_not_installed("ggplot2")

  series <- smooth_series(
    ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x)) +
      ggplot2::geom_area(stat = "density")
  )

  testthat::expect_equal(bounded(series[[1]]), 0)
})

test_that("a faceted smooth keeps its band", {
  testthat::skip_if_not_installed("ggplot2")

  # This case asserted the opposite until #172. The band used to be a second
  # layer, and the facet path collapses a panel to one layer type, so a guard
  # suppressed the band entirely rather than lose the fitted curve with it --
  # a real limitation, written down as one. Riding on the points, there is no
  # second layer to lose.
  #
  # Measured across the change: 80 samples per panel, 0 with bounds before and
  # 80 after.
  df <- hue_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x) +
    ggplot2::facet_wrap(~g)

  panels <- emitted_layers(plot)
  testthat::expect_length(panels, 2)
  for (panel in panels) {
    testthat::expect_equal(panel$type, "smooth")
    points <- points_of(panel$data)
    testthat::expect_gt(length(points), 0)
    testthat::expect_equal(bounded(points), length(points))
  }
})

test_that("the smooth layer keeps the selectors it always had", {
  testthat::skip_if_not_installed("ggplot2")

  # The band layer used to carry a deliberately empty selector list, since a
  # ribbon is one polygon with no per-sample element to address. That layer is
  # gone; the fitted curve's own selector is unaffected by any of this.
  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)

  testthat::expect_length(emitted_layers(plot)[[1]]$selectors, 1)
})
