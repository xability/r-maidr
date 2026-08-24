# A base R Q-Q plot fell back to a picture (#251).
#
# `qqnorm` and `qqplot` are classified HIGH, so their calls were recorded --
# #216 put them there so that `save_html()` would not stop with "No Base R
# plots detected" on a chart that was plainly on the device -- but the
# adapter had no branch for either and the factory no processor, so the
# figure took the static-image path. Not a wrong reading, but a whole chart
# unread, and it is a scatter, which MAIDR has had all along.
#
# **The coordinates are not the arguments.** That is what makes a Q-Q plot
# different from every other base R scatter, and it is why reusing
# `BaseRPointLayerProcessor` unchanged would have been worse than the
# fallback rather than better. Every base R processor reads a call's
# recorded arguments rather than the drawn grob, and a Q-Q plot's arguments
# are samples, not positions:
#
#   qqnorm(y)      one sample, drawn against theoretical quantiles the
#                  function computes -- so the raw sample on the x axis
#                  would announce standard deviations that are measurements
#   qqplot(x, y)   two samples, possibly of different lengths, drawn as one
#                  interpolated pair per point of the shorter -- so eight
#                  values against five would announce eight points over a
#                  chart that draws five
#
# Nothing here re-derives them. Both functions hand over exactly what they
# would have drawn when asked not to draw it, and the recorded arguments are
# forwarded whole rather than picked apart, which is what makes the awkward
# cases free. Measured on the eight and five values below, R 4.x:
#
#   qqnorm(x, plot.it = FALSE)$x   0.1525 -0.8525 0.8525 ... in the caller's
#                                  order, not sorted
#   qqnorm(x, datax = TRUE, ...)   the same pair, swapped
#   qqplot(x, y, plot.it = FALSE)  both length 5; x interpolated to
#                                  1.20 3.05 4.00 5.00 6.90
#
# Two shapes are still declined, and deliberately:
#
#   qqplot(conf.level = )  draws a confidence band as well, through a
#                          `polygon()` call from inside `stats` that the
#                          wrapper never sees and that the payload has
#                          nowhere to put
#   qqline()               the reference line nearly every Q-Q plot is
#                          finished with, likewise an `abline()` from inside
#                          `stats`
#
# Both would otherwise ship a chart with a drawn mark silently missing from
# it, which is worse than the picture, because a picture at least says what
# it is. `qqline` is now recorded (LOW) purely so that it can be declined;
# reading it is #252.

# `base_r_layers` and `base_r_layer_types` live in `helper.R` (#241).
qq_layers <- base_r_layers
qq_types <- base_r_layer_types

# Deliberately unsorted, so that a reading which sorted would show up, and
# with no value repeated, so that a pairing which lost its order would.
SAMPLE <- c(4.1, 2.3, 5.6, 3.3, 6.9, 1.2, 4.8, 3.9)
# Five against the eight above: `qqplot` draws one point per value of the
# shorter sample, so a reading that kept both would be the wrong length.
OTHER <- c(2.0, 3.1, 4.4, 5.0, 6.2)

#' The x and y of a layer's points, as two numeric vectors
coordinates <- function(layer) {
  list(
    x = vapply(layer$data, function(point) point$x, 0),
    y = vapply(layer$data, function(point) point$y, 0)
  )
}

#' Whether a drawing carries a layer maidr declines to read
declines <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)

  draw()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)
  orchestrator$generate_maidr_data()
  orchestrator$has_unsupported_layers()
}


test_that("a base R Q-Q plot is read rather than pictured", {
  testthat::expect_equal(qq_types(function() qqnorm(SAMPLE)), "point")
  testthat::expect_equal(qq_types(function() qqplot(SAMPLE, OTHER)), "point")
})


test_that("qqnorm announces the quantiles it drew, not the sample twice", {
  # The whole point of the chart. `stats` computed one axis; a reading that
  # took the recorded argument for both would put the sample on x, where the
  # chart draws standard deviations.
  drawn <- stats::qqnorm(SAMPLE, plot.it = FALSE)
  got <- coordinates(qq_layers(function() qqnorm(SAMPLE))[[1]])

  testthat::expect_equal(got$x, drawn$x)
  testthat::expect_equal(got$y, SAMPLE)
  testthat::expect_false(isTRUE(all.equal(got$x, SAMPLE)))
})


test_that("the pairs stay in the order the chart drew them", {
  # Not sorted. The `points` grob lays its marks down in the call's order
  # and the selector list pairs with them positionally, so sorting the
  # payload would highlight a different point from the one announced.
  got <- coordinates(qq_layers(function() qqnorm(SAMPLE))[[1]])

  testthat::expect_equal(got$y, SAMPLE)
  testthat::expect_false(isTRUE(all.equal(got$y, sort(SAMPLE))))
})


test_that("datax = TRUE swaps the axes, because the chart does", {
  # Forwarded rather than handled: `qqnorm` is asked for the pairs with the
  # caller's own arguments, so an argument that changes what it draws
  # changes what is read without anything here knowing the argument exists.
  # `qqnorm.default` swaps its labels along with its axes, and so does this.
  layer <- qq_layers(function() qqnorm(SAMPLE, datax = TRUE))[[1]]
  got <- coordinates(layer)

  testthat::expect_equal(got$x, SAMPLE)
  testthat::expect_equal(got$y, stats::qqnorm(SAMPLE, plot.it = FALSE)$x)
  testthat::expect_equal(layer$axes$x$label, "Sample Quantiles")
  testthat::expect_equal(layer$axes$y$label, "Theoretical Quantiles")
})


test_that("qqplot draws one point per value of the shorter sample", {
  # Eight against five. `qqplot` interpolates the longer sample down to the
  # shorter one's quantiles, so a reading that announced the recorded
  # arguments would be three points longer than the chart, and would name
  # values -- 4.1, 3.3, 3.9 -- that no mark on the page stands for.
  drawn <- stats::qqplot(SAMPLE, OTHER, plot.it = FALSE)
  got <- coordinates(qq_layers(function() qqplot(SAMPLE, OTHER))[[1]])

  testthat::expect_length(got$x, length(OTHER))
  testthat::expect_equal(got$x, drawn$x)
  testthat::expect_equal(got$y, drawn$y)
})


test_that("a Q-Q plot carries the labels it writes for itself", {
  # `qqnorm`'s defaults are constants in its own signature and are drawn on
  # the chart, so announcing them reports the figure rather than naming it.
  layer <- qq_layers(function() qqnorm(SAMPLE))[[1]]

  testthat::expect_equal(layer$axes$x$label, "Theoretical Quantiles")
  testthat::expect_equal(layer$axes$y$label, "Sample Quantiles")
  testthat::expect_equal(layer$title, "Normal Q-Q Plot")
})


test_that("the caller's own labels win over the defaults", {
  layer <- qq_layers(function() {
    qqnorm(SAMPLE, main = "Residuals", xlab = "Normal", ylab = "Observed")
  })[[1]]

  testthat::expect_equal(layer$axes$x$label, "Normal")
  testthat::expect_equal(layer$axes$y$label, "Observed")
  testthat::expect_equal(layer$title, "Residuals")
})


test_that("qqplot invents no labels, because its defaults are expressions", {
  # `qqplot`'s are `deparse1(substitute(x))` -- the caller's expression --
  # which is gone by the time the wrapper has recorded evaluated values.
  # Reconstructing one would name the axis after whatever variable this
  # test happened to use. The point processor already declines to guess for
  # the same reason, and the renderer's generic covers it.
  layer <- qq_layers(function() qqplot(SAMPLE, OTHER))[[1]]

  testthat::expect_null(layer$axes$x$label)
  testthat::expect_null(layer$axes$y$label)
})


test_that("the axis grid is built from the drawn pairs", {
  # Not from the recorded arguments: on `qqnorm` one of the two axes is not
  # a sample at all, so a grid taken from the arguments would announce a
  # range from about 1 to 7 for an axis the chart draws from -2 to 2.
  layer <- qq_layers(function() qqnorm(SAMPLE))[[1]]
  drawn <- stats::qqnorm(SAMPLE, plot.it = FALSE)

  testthat::expect_lt(layer$axes$x$min, 0)
  testthat::expect_gte(layer$axes$x$max, max(drawn$x))
  testthat::expect_gt(layer$axes$y$max, max(SAMPLE) - 1)
})


test_that("the points are bound to the grob the chart drew them in", {
  # `qqnorm` exports its marks under `graphics-plot-N-points-1`, measured,
  # which is the grob the point processor already looks for -- so the
  # selector needed nothing said about Q-Q plots at all.
  layer <- qq_layers(function() qqnorm(SAMPLE))[[1]]

  testthat::expect_match(
    unlist(layer$selectors)[1], "graphics-plot-1-points-1", fixed = TRUE
  )
})


test_that("a reference line is declined rather than dropped", {
  # `qqline()` is how nearly every Q-Q plot in the wild is finished, and it
  # reaches `graphics::abline()` from inside `stats`, where the wrapper
  # never sees it. Left unrecorded it left no trace at all, so making
  # `qqnorm` readable would have turned this chart into a scatter with a
  # drawn line silently missing from it. Recorded, it declines -- the same
  # answer as before the reading existed. Reading the line is #252.
  testthat::expect_false(declines(function() qqnorm(SAMPLE)))
  testthat::expect_true(declines(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE)
  }))
})


test_that("a confidence band is declined rather than dropped", {
  # `qqplot(conf.level = )` draws a band as well as the points, through a
  # `polygon()` from inside `stats`. The points alone would be a true
  # reading of an untrue chart.
  testthat::expect_false(declines(function() qqplot(SAMPLE, OTHER)))
  testthat::expect_true(
    declines(function() qqplot(SAMPLE, OTHER, conf.level = 0.95))
  )
})


test_that("qqplot's own default really is no band", {
  # Raised in review of #253. `detect_layer_type()` reads the band off the
  # *recorded argument*, so a call that says nothing about `conf.level` is
  # taken to draw no band -- which infers a fact about the chart from the
  # caller's silence. That is sound only while `stats::qqplot`'s own default
  # is NULL, and the honest way to hold it is to assert it rather than to
  # write a `formals()` lookup into the adapter: with a NULL default the two
  # spellings are observationally identical, so the extra branch would be
  # code no test on this R could exercise.
  #
  # Asserted against `formals()` rather than written down as a constant, so
  # an R release that changed the default fails here instead of silently
  # turning every plain `qqplot()` into a chart with a drawn region missing
  # from its reading. Measured on R 4.3.3.
  testthat::expect_null(eval(formals(stats::qqplot)[["conf.level"]]))

  # The other half of the same fact, read off what the function returns: a
  # plain call comes back with the pairs alone, while a call that asks for a
  # band comes back with the bounds it would have drawn.
  plain <- stats::qqplot(SAMPLE, OTHER, plot.it = FALSE)
  banded <- stats::qqplot(SAMPLE, OTHER, conf.level = 0.95, plot.it = FALSE)

  testthat::expect_setequal(names(plain), c("x", "y"))
  testthat::expect_true(all(c("lwr", "upr") %in% names(banded)))
})


test_that("a computation that cannot run leaves the layer empty", {
  # `qqplot` needs two samples. Handed one, `stats` raises, and the guard
  # answers with no points rather than with a partial chart -- which makes
  # the layer empty, and an empty recognised layer is itself declined
  # (#232), so the figure falls back.
  processor <- maidr:::BaseRQqLayerProcessor$new(list())

  testthat::expect_equal(processor$extract_data(NULL), list())
  testthat::expect_null(processor$quantile_pairs(list(
    function_name = "qqplot",
    plot_call = list(args = list(SAMPLE))
  )))
  testthat::expect_null(processor$quantile_pairs(list(
    function_name = "barplot",
    plot_call = list(args = list(SAMPLE))
  )))
})


test_that("an unevaluated argument is not a sample", {
  # The point processor guards the same way before handing anything to
  # `xy.coords()`. A promise recorded from the NSE path is an expression,
  # and forcing it here would evaluate the caller's code a second time.
  processor <- maidr:::BaseRQqLayerProcessor$new(list())

  testthat::expect_null(processor$quantile_pairs(list(
    function_name = "qqnorm",
    plot_call = list(args = list(quote(rnorm(10))))
  )))
})


test_that("a caller who asked not to plot is not asked twice", {
  # `plot.it` is the argument this processor supplies, and `do.call` refuses
  # a formal matched twice. A caller who wrote it explicitly must not make
  # the reading raise.
  processor <- maidr:::BaseRQqLayerProcessor$new(list())
  pairs <- processor$quantile_pairs(list(
    function_name = "qqnorm",
    plot_call = list(args = list(SAMPLE, plot.it = TRUE))
  ))

  testthat::expect_equal(pairs$y, SAMPLE)
})
