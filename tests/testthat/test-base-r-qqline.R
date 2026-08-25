# `qqline()` was recorded only so it could be declined (#252).
#
# `qqnorm()` and `qqplot()` became readable in #251. `qqline()` -- how nearly
# every Q-Q plot in the wild is finished -- reaches `graphics::abline()` from
# inside the `stats` namespace, where maidr's search-path wrapper never sees
# it. Unrecorded, the line left no trace at all, so a readable `qqnorm`
# would have shipped a scatter with a drawn mark silently missing from it.
# So it went into `LOW` with no `detect_layer_type()` branch, typed
# `unknown`, and held the whole chart at the static image. Measured, before
# this: `qqnorm(x); qqline(x)` rendered as `<img>` with no payload at all.
#
# The endpoints are read rather than re-derived. `stats::qqline`'s body is
# four lines, and the line it draws is the one through two anchors:
#
#     y <- quantile(y, probs, names = FALSE, type = qtype, na.rm = TRUE)
#     x <- distribution(probs)
#
# so the processor asks the same question of the *call's own* arguments.
# Every test below that varies one of `probs`, `qtype`, `distribution` or
# `datax` checks the answer against `stats`' computation rather than against
# a number copied out of a previous run.
#
# The x range is the trap. `BaseRLineLayerProcessor$extract_abline_data()`
# takes its range from `get_x_range_from_group()`, which reads the group's
# HIGH call's first argument as the x data -- and on a `qqnorm` group that
# argument is the *sample*, not the theoretical quantiles the chart puts on
# x. Inheriting it would stretch the line across the wrong interval, which
# is the class of mistake the Q-Q reading exists to avoid, so the range
# comes from the drawn pairs instead.

# `base_r_layers` and `base_r_layer_types` live in `helper.R` (#241).
qqline_layers <- base_r_layers
qqline_types <- base_r_layer_types

# The same sample the Q-Q tests use: unsorted, no value repeated.
SAMPLE <- c(4.1, 2.3, 5.6, 3.3, 6.9, 1.2, 4.8, 3.9)

#' The two endpoints of the reference line a drawing produced
#'
#' @param draw A function that draws a Q-Q plot and its line
#' @return List with x and y, each numeric of length two, or NULL
reference_endpoints <- function(draw) {
  layers <- qqline_layers(draw)
  lines <- Filter(function(layer) identical(layer$type, "line"), layers)
  if (length(lines) == 0) {
    return(NULL)
  }
  points <- lines[[1]]$data
  if (!is.null(points[[1]][[1]]$x)) {
    points <- points[[1]]
  }
  list(
    x = vapply(points, function(point) point$x, 0),
    y = vapply(points, function(point) point$y, 0)
  )
}

#' What `stats::qqline` itself would draw at the given x
#'
#' A transcription of `stats::qqline`'s four lines, so a test compares the
#' reading against the function rather than against a recorded constant.
#'
#' @param sample The sample the line was fitted to
#' @param at The x coordinates to evaluate the line at
#' @param datax Whether the sample is on x
#' @param probs The two quantile probabilities
#' @param qtype The `quantile()` type
#' @param distribution The theoretical quantile function
#' @return Numeric, the y at each x
qqline_at <- function(sample, at, datax = FALSE, probs = c(0.25, 0.75),
                      qtype = 7, distribution = stats::qnorm) {
  quantiles <- as.vector(stats::quantile(
    sample, probs,
    names = FALSE, type = qtype, na.rm = TRUE
  ))
  theoretical <- distribution(probs)
  if (datax) {
    slope <- diff(theoretical) / diff(quantiles)
    intercept <- theoretical[[1]] - slope * quantiles[[1]]
  } else {
    slope <- diff(quantiles) / diff(theoretical)
    intercept <- quantiles[[1]] - slope * theoretical[[1]]
  }
  intercept + slope * at
}


test_that("a Q-Q plot and its reference line are two layers, not a picture", {
  testthat::expect_equal(
    qqline_types(function() {
      qqnorm(SAMPLE)
      qqline(SAMPLE)
    }),
    c("point", "line")
  )
})


test_that("the line is drawn between exactly two endpoints", {
  # What `abline()` renders: the SVG carries the two ends and nothing
  # between them, so a reading that sampled the line would announce points
  # the chart never drew.
  got <- reference_endpoints(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE)
  })

  testthat::expect_length(got$x, 2)
  testthat::expect_length(got$y, 2)
})


test_that("the endpoints are the ones stats::qqline computes", {
  got <- reference_endpoints(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE)
  })

  testthat::expect_equal(got$y, qqline_at(SAMPLE, got$x))
})


test_that("the line spans the quantiles the chart drew, not the sample", {
  # The crux. `get_x_range_from_group()` would hand back `range(SAMPLE)` --
  # 1.2 to 6.9 -- because the recorded first argument of a `qqnorm` call is
  # the sample. The chart's x axis carries theoretical quantiles, which for
  # eight values run about -1.53 to 1.53.
  drawn <- stats::qqnorm(SAMPLE, plot.it = FALSE)
  got <- reference_endpoints(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE)
  })

  testthat::expect_equal(got$x, range(drawn$x))
  testthat::expect_false(isTRUE(all.equal(got$x, range(SAMPLE))))
})


test_that("a non-default probs is read from the call", {
  got <- reference_endpoints(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE, probs = c(0.1, 0.9))
  })

  testthat::expect_equal(got$y, qqline_at(SAMPLE, got$x, probs = c(0.1, 0.9)))
  # And it is not simply the default reading under another name.
  testthat::expect_false(isTRUE(all.equal(got$y, qqline_at(SAMPLE, got$x))))
})


test_that("a non-default qtype is read from the call", {
  got <- reference_endpoints(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE, qtype = 1)
  })

  testthat::expect_equal(got$y, qqline_at(SAMPLE, got$x, qtype = 1))
  testthat::expect_false(isTRUE(all.equal(got$y, qqline_at(SAMPLE, got$x))))
})


test_that("a non-default distribution is read from the call", {
  uniform <- function(p) stats::qunif(p, -2, 2)
  got <- reference_endpoints(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE, distribution = uniform)
  })

  testthat::expect_equal(
    got$y,
    qqline_at(SAMPLE, got$x, distribution = uniform)
  )
  testthat::expect_false(isTRUE(all.equal(got$y, qqline_at(SAMPLE, got$x))))
})


test_that("datax is read from the qqline call rather than the plot's", {
  # `qqline()` takes its own copy of the argument rather than inheriting the
  # plot's, so the two can disagree and the line is read from its own.
  got <- reference_endpoints(function() {
    qqnorm(SAMPLE, datax = TRUE)
    qqline(SAMPLE, datax = TRUE)
  })

  testthat::expect_equal(got$y, qqline_at(SAMPLE, got$x, datax = TRUE))
  # `datax = TRUE` puts the sample on x, so the span moves with it.
  testthat::expect_equal(got$x, range(SAMPLE))
})


test_that("a qqline over a qqplot reads against that chart's own pairs", {
  other <- c(2.0, 3.1, 4.4, 5.0, 6.2)
  drawn <- stats::qqplot(SAMPLE, other, plot.it = FALSE)
  got <- reference_endpoints(function() {
    qqplot(SAMPLE, other)
    qqline(other)
  })

  testthat::expect_equal(got$x, range(drawn$x))
  testthat::expect_equal(got$y, qqline_at(other, got$x))
})


test_that("a constant sample draws the flat line stats draws, and is read", {
  # Measured rather than assumed, because the first guess was wrong. Both
  # anchors are the same quantile, so `diff(quantiles)` is zero -- but that
  # is the *numerator* under the default, giving a slope of 0 and an
  # intercept of the constant. `stats::qqline` draws a horizontal line at 3,
  # and reading it is right; declining would drop a mark the chart made.
  flat <- rep(3.0, 8)
  got <- reference_endpoints(function() {
    qqnorm(flat)
    qqline(flat)
  })

  testthat::expect_equal(got$y, c(3, 3))
  testthat::expect_equal(got$y, qqline_at(flat, got$x))
})


test_that("a slope that is not finite declines rather than emitting a line", {
  # The genuinely degenerate case: `datax = TRUE` divides *by*
  # `diff(quantiles)`, so a constant sample gives a slope of `Inf`.
  #
  # Asked of the processor rather than of a drawing, because R refuses to
  # draw it at all -- `stats::qqline(rep(3, 8), datax = TRUE)` stops with
  # "'a' and 'b' must be finite" from `int_abline`. So no chart can reach
  # this branch, and it exists to keep a hand-built or future-recorded call
  # from putting `Inf` in the payload.
  flat <- rep(3.0, 8)
  processor <- maidr:::BaseRQqlineLayerProcessor$new(NULL)

  testthat::expect_null(processor$reference_line(list(
    function_name = "qqline",
    plot_call = list(args = list(flat, datax = TRUE))
  )))
})


test_that("a call carrying no sample declines", {
  processor <- maidr:::BaseRQqlineLayerProcessor$new(NULL)

  testthat::expect_null(processor$reference_line(list(
    function_name = "qqline",
    plot_call = list(args = list())
  )))
  testthat::expect_null(processor$reference_line(list(
    function_name = "qqline",
    plot_call = list(args = list("not a sample"))
  )))
})


test_that("the line is bound to the grob the chart drew it in", {
  # `qqnorm(x); qqline(x)` and `plot(x, y); abline(0, 1)` export the same
  # grob, so the parent's abline selector reaches it unchanged.
  layers <- qqline_layers(function() {
    qqnorm(SAMPLE)
    qqline(SAMPLE)
  })
  line <- Filter(function(layer) identical(layer$type, "line"), layers)[[1]]

  testthat::expect_true(grepl("abline", paste(unlist(line$selectors), collapse = " ")))
})


test_that("a Q-Q plot with no line is unchanged", {
  testthat::expect_equal(qqline_types(function() qqnorm(SAMPLE)), "point")
})
