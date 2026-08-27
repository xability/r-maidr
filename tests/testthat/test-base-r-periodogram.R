# `spectrum()` and `cpgram()` drew curves that nothing read (#262)
#
# Both are recorded -- `save_html()` succeeds rather than reporting "No Base R
# plots detected", which #262 fixed -- but `detect_layer_type()` had no branch
# for either, so they fell through to `unknown` and the chart came out as a
# static image with "Plot contains unsupported elements".
#
# Each takes a time series, computes a periodogram from it, and plots one
# curve against frequency. They are separate readings because they differ in
# both halves: `spectrum()` draws a smoothed spectral density as a line, and
# `cpgram()` draws a cumulative periodogram as a staircase from an estimate it
# computes itself.
#
# Two things are worth asserting hardest.
#
# **Only the first curve is the chart.** Each call makes three `plot.xy()`
# calls; the two after the first are two-point reference marks -- a confidence
# crosshair and a pair of Kolmogorov-Smirnov bounds -- and announcing them
# would add series the caller never computed.
#
# **`cpgram()` does not use `spectrum()`'s estimate.** They disagree, and the
# disagreement is small enough to look like rounding: measured, the second
# step of the drawn curve is 0.0801 while `spectrum()`'s estimate gives
# 0.0817. A reading built on the wrong one is a chart of the right shape
# carrying the wrong numbers.

periodogram_layers <- base_r_layers

#' The values of a layer, keyed by nothing -- position is the whole of it
xs_of <- function(layer) vapply(layer$data, function(p) p$x, numeric(1))
ys_of <- function(layer) vapply(layer$data, function(p) p$y, numeric(1))

#' The series both fixtures are built from
SERIES <- local({
  set.seed(5)
  stats::rnorm(60)
})


test_that("a spectral density reads as a line rather than as nothing", {
  # The reproduction: before this, no layer at all, so the figure fell back
  # to a picture.
  layers <- periodogram_layers(function() spectrum(SERIES))

  testthat::expect_length(layers, 1)
  testthat::expect_equal(layers[[1]]$type, "line")
})


test_that("a cumulative periodogram reads as the staircase it draws", {
  # `cpgram()` plots with `type = "s"`, and the export writes `step-1` rather
  # than `lines-1`. A line would imply the value slides between frequencies,
  # which is not what a cumulative sum does.
  layers <- periodogram_layers(function() cpgram(SERIES))

  testthat::expect_length(layers, 1)
  testthat::expect_equal(layers[[1]]$type, "step")
  testthat::expect_equal(layers[[1]]$stepDirection, "hv")
})


test_that("both calls route to the processors that recompute them", {
  # The name the adapter types each as and the name the factory answers to
  # have to be the same string, and the registry has to list both (#200, #214).
  adapter <- BaseRAdapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "spectrum", args = list())),
    "spectral_density"
  )
  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "cpgram", args = list())),
    "cumulative_periodogram"
  )

  factory <- BaseRProcessorFactory$new()
  supported <- factory$get_supported_types()
  testthat::expect_true("spectral_density" %in% supported)
  testthat::expect_true("cumulative_periodogram" %in% supported)
  testthat::expect_s3_class(
    factory$create_processor("spectral_density", list(plot_call = list(args = list()))),
    "BaseRSpectrumLayerProcessor"
  )
  testthat::expect_s3_class(
    factory$create_processor(
      "cumulative_periodogram", list(plot_call = list(args = list()))
    ),
    "BaseRCpgramLayerProcessor"
  )
})


test_that("the density is the estimate the call computed", {
  # Against `spectrum()`'s own answer rather than against literals, so the
  # test says what the reading claims -- that the announced series IS the
  # estimate -- rather than pinning numbers that would drift with the seed.
  layer <- periodogram_layers(function() spectrum(SERIES))[[1]]
  expected <- stats::spectrum(SERIES, plot = FALSE)

  testthat::expect_equal(xs_of(layer), as.numeric(expected$freq))
  testthat::expect_equal(ys_of(layer), as.numeric(expected$spec))
})


test_that("the density is the raw spectrum, not its logarithm", {
  # `plot.spec` draws on a log y axis, but it puts the log on the AXIS and
  # hands the untransformed values to the drawing. Taking a logarithm here
  # would announce a series the caller never computed -- and, since every
  # value here is positive, would do it without erroring.
  layer <- periodogram_layers(function() spectrum(SERIES))[[1]]

  testthat::expect_true(all(ys_of(layer) > 0))
  testthat::expect_gt(max(ys_of(layer)), 1)
})


test_that("the caller's estimation arguments change the curve they drew", {
  # `spans` smooths the periodogram, so recomputing with defaults would
  # announce a different curve from the one on the page.
  plain <- periodogram_layers(function() spectrum(SERIES))[[1]]
  smoothed <- periodogram_layers(function() spectrum(SERIES, spans = 5))[[1]]

  testthat::expect_false(isTRUE(all.equal(ys_of(plain), ys_of(smoothed))))
  testthat::expect_equal(
    ys_of(smoothed),
    as.numeric(stats::spectrum(SERIES, spans = 5, plot = FALSE)$spec)
  )
})


test_that("the cumulative periodogram is cpgram's estimate, not spectrum's", {
  # The trap this reading exists to avoid. The two estimates differ by about
  # 2% on the second step -- small enough to pass a loose eye and large
  # enough to be wrong. Asserted from both sides: it matches cpgram's own
  # computation and does NOT match one built from `spectrum()`.
  layer <- periodogram_layers(function() cpgram(SERIES))[[1]]

  taper <- 0.1
  x <- stats::spec.taper(scale(SERIES, TRUE, FALSE), p = taper)
  y <- Mod(stats::fft(x))^2 / length(x)
  y[1L] <- 0
  n <- length(x)
  fr <- (0:(n / 2)) * stats::frequency(SERIES) / n
  if (length(fr) %% 2 == 0) {
    n <- length(fr) - 1
    y <- y[1L:n]
    fr <- fr[1L:n]
  } else {
    y <- y[seq_along(fr)]
  }

  testthat::expect_equal(xs_of(layer), as.numeric(fr))
  testthat::expect_equal(ys_of(layer), as.numeric(cumsum(y) / sum(y)))

  from_spectrum <- stats::spectrum(SERIES, plot = FALSE)
  testthat::expect_false(isTRUE(all.equal(
    ys_of(layer),
    as.numeric(cumsum(from_spectrum$spec) / sum(from_spectrum$spec))
  )))
})


test_that("the cumulative curve starts at nothing and ends at everything", {
  # What makes it cumulative, and the cheapest way a wrong normalisation
  # shows up.
  layer <- periodogram_layers(function() cpgram(SERIES))[[1]]
  values <- ys_of(layer)

  testthat::expect_equal(values[[1]], 0)
  testthat::expect_equal(values[[length(values)]], 1)
  testthat::expect_false(is.unsorted(values))
})


test_that("neither reference mark is announced as a reading", {
  # Each call draws two more two-point curves -- a confidence crosshair and
  # the KS bounds. They are reference marks, so one layer each, not three.
  testthat::expect_length(periodogram_layers(function() spectrum(SERIES)), 1)
  testthat::expect_length(periodogram_layers(function() cpgram(SERIES)), 1)
})


test_that("each curve is outlined by the grob it was drawn as", {
  # Measured against a real export: `spectrum` writes the density as
  # `lines-1` and `cpgram` writes the staircase as `step-1`, both with the
  # reference marks after them under different names.
  testthat::expect_equal(
    periodogram_layers(function() spectrum(SERIES))[[1]]$selectors,
    list("g#graphics-plot-1-lines-1\\.1")
  )
  testthat::expect_equal(
    periodogram_layers(function() cpgram(SERIES))[[1]]$selectors,
    list("g#graphics-plot-1-step-1\\.1")
  )
})


test_that("the axes are named the way the drawing names them", {
  # `cpgram()` writes an empty `ylab`: there is no name for a cumulative
  # share of the total, and inventing one would be a claim the chart does
  # not make.
  density <- periodogram_layers(function() spectrum(SERIES))[[1]]
  cumulative <- periodogram_layers(function() cpgram(SERIES))[[1]]

  testthat::expect_equal(density$axes$x$label, "frequency")
  testthat::expect_equal(density$axes$y$label, "spectrum")
  testthat::expect_equal(cumulative$axes$x$label, "frequency")
  testthat::expect_null(cumulative$axes$y$label)
})


test_that("a non-numeric series is declined rather than coerced", {
  # The arguments of a call that stopped are recorded all the same, and
  # `as.numeric()` on them would announce a curve computed from NAs.
  spectral <- BaseRSpectrumLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(plot_call = list(args = list(c("a", "b", "c"))))
  )
  cumulative <- BaseRCpgramLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(plot_call = list(args = list(c("a", "b", "c"))))
  )

  testthat::expect_null(spectral)
  testthat::expect_null(cumulative)
})


test_that("a call with no series to read is declined", {
  testthat::expect_null(
    BaseRSpectrumLayerProcessor$new(NULL)$process(
      NULL, NULL,
      layer_info = list(plot_call = list(args = list()))
    )
  )
  testthat::expect_null(
    BaseRCpgramLayerProcessor$new(NULL)$process(
      NULL, NULL,
      layer_info = list(plot_call = list(args = list()))
    )
  )
})


test_that("a series too short to have a periodogram is declined", {
  # One observation has no frequency to speak of, and the taper divides by a
  # length that is then zero.
  testthat::expect_null(
    BaseRCpgramLayerProcessor$new(NULL)$process(
      NULL, NULL,
      layer_info = list(plot_call = list(args = list(1)))
    )
  )
})
