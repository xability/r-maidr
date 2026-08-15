# `geom_smooth()` drew its confidence band and MAIDR dropped it (#135).
#
# `se = TRUE` is the default, and the band is the reason the layer is drawn
# rather than a plain line: it says how much of the fitted trend the data
# supports. `StatSmooth` computes it into `ymin`/`ymax` alongside the fitted
# `y`, and the processor read only `y` -- so a chart that otherwise worked was
# silently missing the half a reader needs to judge it.
#
# The band is emitted as its own `error_bar` layer, which is the shape MAIDR
# reads today (`ErrorBarTrace` consumes `y`/`yMin`/`yMax`; `SmoothTrace`
# extends `LineTrace` and reads neither) and what the Python binding already
# produces for `sns.pointplot`.

smooth_band_df <- function() {
  set.seed(1)
  data.frame(x = 1:20, y = (1:20) + stats::rnorm(20, sd = 3))
}

# Drive the whole orchestrator rather than the processor alone: the band is a
# second layer, and whether a second layer survives is a question about the
# path that assembles them.
band_layers <- function(plot) {
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
  vapply(band_layers(plot), function(ly) ly$type, character(1))
}

test_that("a geom_smooth confidence band is emitted as its own layer", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)

  testthat::expect_equal(layer_types(plot), c("point", "smooth", "error_bar"))
})

test_that("the band carries the bounds MAIDR reads", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)

  band <- Filter(function(ly) identical(ly$type, "error_bar"), band_layers(plot))
  testthat::expect_length(band, 1)

  point <- band[[1]]$data[[1]]
  testthat::expect_named(point, c("x", "y", "yMin", "yMax"))
  # The interval brackets the fit rather than sitting to one side of it.
  testthat::expect_lt(point$yMin, point$y)
  testthat::expect_gt(point$yMax, point$y)
})

test_that("every sample of the fitted curve carries an interval", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)

  band <- Filter(function(ly) identical(ly$type, "error_bar"), band_layers(plot))
  bounded <- vapply(
    band[[1]]$data,
    function(p) is.numeric(p$yMin) && is.numeric(p$yMax),
    logical(1)
  )
  testthat::expect_true(all(bounded))
})

test_that("se = FALSE draws no band and emits none", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "lm", se = FALSE, formula = y ~ x)

  testthat::expect_equal(layer_types(plot), c("point", "smooth"))
})

test_that("a loess fit carries its band too", {
  testthat::skip_if_not_installed("ggplot2")

  # The band is read off the stat's output, so it is not specific to `lm`.
  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "loess", se = TRUE, formula = y ~ x)

  testthat::expect_true("error_bar" %in% layer_types(plot))
})

test_that("the band emits no selectors rather than a fabricated one", {
  testthat::skip_if_not_installed("ggplot2")

  # A ribbon is one polygon covering every sample, so there is no per-sample
  # element to address. Emitting the same selector for each point would
  # highlight the whole band everywhere and look like it worked.
  plot <- ggplot2::ggplot(smooth_band_df(), ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x)

  band <- Filter(function(ly) identical(ly$type, "error_bar"), band_layers(plot))
  testthat::expect_length(band[[1]]$selectors, 0)
})

# ---------------------------------------------------------------------------
# The failure that matters more than the missing feature.
# ---------------------------------------------------------------------------

test_that("a density curve is not read as having a confidence band", {
  testthat::skip_if_not_installed("ggplot2")

  # `StatDensity` also fills `ymin`/`ymax`, and means something else entirely:
  # measured on this plot, all 1536 built rows carry `ymin = 0` and
  # `ymax = density` -- the extent of the fill, not an uncertainty. Keying the
  # band on those columns announced every density curve as having an interval
  # running from zero, which is a false claim about the data rather than a
  # missing feature. The rule therefore asks the stat, never the columns.
  set.seed(1)
  df <- data.frame(y = stats::rnorm(60), g = rep(c("a", "b", "c"), each = 20))
  plot <- ggplot2::ggplot(df, ggplot2::aes(x = y, fill = g)) +
    ggplot2::geom_density(alpha = 0.3)

  testthat::expect_false("error_bar" %in% layer_types(plot))
})

test_that("a filled density drawn with geom_area is not read as a band", {
  testthat::skip_if_not_installed("ggplot2")

  set.seed(1)
  df <- data.frame(y = stats::rnorm(60))
  plot <- ggplot2::ggplot(df, ggplot2::aes(x = y)) +
    ggplot2::geom_area(stat = "density")

  testthat::expect_false("error_bar" %in% layer_types(plot))
})

# ---------------------------------------------------------------------------
# The limitation, pinned so it is a choice rather than a discovery.
# ---------------------------------------------------------------------------

test_that("a faceted smooth is unchanged, band and all", {
  testthat::skip_if_not_installed("ggplot2")

  # `combine_facet_layer_data()` collapses every layer of a panel into one
  # payload entry and types it from the first result that produced one, so a
  # panel holds a single layer type by construction. Handing it a multi-layer
  # result does not add the band -- it reads `result$data`, finds nothing
  # there, and drops the fitted curve as well. Measured before the guard: a
  # faceted point + smooth went from 11 entries per panel to 10.
  #
  # So a faceted regression chart still loses its band. That is a real
  # limitation of the facet path rather than of this processor, and it is
  # pinned here so widening it later is deliberate.
  set.seed(1)
  df <- data.frame(
    x = rep(1:10, 2),
    y = stats::rnorm(20),
    g = rep(c("a", "b"), each = 10)
  )
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "lm", se = TRUE, formula = y ~ x) +
    ggplot2::facet_wrap(~g)

  layers <- band_layers(plot)
  testthat::expect_false("error_bar" %in% vapply(layers, function(l) l$type, character(1)))
  # The fitted curve still reaches the payload -- the point of the guard.
  testthat::expect_true(all(vapply(layers, function(l) length(l$data), integer(1)) == 11L))
})
