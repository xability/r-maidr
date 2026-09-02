# `acf()`, `pacf()` and `ccf()` drew a correlogram that nothing read (#276).
#
# All three are recorded -- `save_html()` succeeds rather than reporting "No
# Base R plots detected", which #262 fixed -- but `detect_layer_type()` had
# no branch for them, so each fell through to `unknown` and the chart came
# out as a static image:
#
#   acf(v)   Plot contains unsupported elements. Rendering as static image.
#   pacf(v)  Plot contains unsupported elements. Rendering as static image.
#   ccf(v,w) Plot contains unsupported elements. Rendering as static image.
#
# A correlogram is one vertical spike per lag, from the zero line to the
# correlation at that lag, joining nothing to anything -- the shape
# `plot(type = "h")` already reads as a `lollipop` for, and under the same
# `spike` grob name, measured: `graphics-plot-1-spike-1`.
#
# What is new is where the numbers come from. The recorded call holds the
# *series*, not the correlogram, so the reading replays the call with
# `plot = FALSE` and takes `$lag` and `$acf` off the result.

correlogram_layers <- base_r_layers
correlogram_types <- base_r_layer_types

# A fixed series, so the correlations below are the same on every run.
set.seed(1)
V <- as.numeric(stats::arima.sim(list(ar = 0.6), n = 60))
W <- rev(V)

lags_of <- function(layer) vapply(layer$data, function(p) p$x, numeric(1))
values_of <- function(layer) vapply(layer$data, function(p) p$y, numeric(1))

test_that("a correlogram is read rather than falling back to a picture", {
  expect_equal(correlogram_types(function() acf(V, lag.max = 4)), "lollipop")
  expect_equal(correlogram_types(function() pacf(V, lag.max = 4)), "lollipop")
  expect_equal(correlogram_types(function() ccf(V, W, lag.max = 2)), "lollipop")
})

test_that("the spikes carry the correlations the call computed", {
  layer <- correlogram_layers(function() acf(V, lag.max = 4))[[1]]
  expected <- stats::acf(V, lag.max = 4, plot = FALSE)

  expect_equal(values_of(layer), as.numeric(drop(expected$acf)))
})

test_that("acf starts at lag zero, which it draws and which is one", {
  # The correlation of a series with itself. `plot.acf` draws the spike, so
  # dropping it would leave the reader a chart one spike shorter than the
  # one on screen.
  layer <- correlogram_layers(function() acf(V, lag.max = 4))[[1]]

  expect_equal(lags_of(layer), c(0, 1, 2, 3, 4))
  expect_equal(values_of(layer)[[1]], 1)
})

test_that("pacf has no lag zero at all", {
  # A partial autocorrelation at lag 0 is not defined, and `stats` does not
  # compute one. Announcing the same lags for both would misname every spike
  # on one of the two charts.
  layer <- correlogram_layers(function() pacf(V, lag.max = 4))[[1]]

  expect_equal(lags_of(layer), c(1, 2, 3, 4))
})

test_that("a cross-correlation's lags are signed", {
  # "x leads y" and "y leads x" are different statements, and the chart draws
  # both halves. Reading only the positive side, or reading the signs as
  # positions, would announce half the chart or the wrong half.
  layer <- correlogram_layers(function() ccf(V, W, lag.max = 2))[[1]]

  expect_equal(lags_of(layer), c(-2, -1, 0, 1, 2))
})

test_that("the lag axis is named, and so is what is drawn against it", {
  acf_layer <- correlogram_layers(function() acf(V, lag.max = 3))[[1]]
  pacf_layer <- correlogram_layers(function() pacf(V, lag.max = 3))[[1]]
  ccf_layer <- correlogram_layers(function() ccf(V, W, lag.max = 2))[[1]]

  expect_equal(acf_layer$axes$x$label, "Lag")
  expect_equal(acf_layer$axes$y$label, "ACF")
  expect_equal(pacf_layer$axes$y$label, "Partial ACF")
  expect_equal(ccf_layer$axes$y$label, "CCF")
})

test_that("a covariance correlogram is not announced as a correlation", {
  # `acf(type = "covariance")` draws covariances, which are not scaled to
  # [-1, 1]. Calling them correlations would announce a normalisation the
  # chart never applied.
  layer <- correlogram_layers(function() {
    acf(V, lag.max = 3, type = "covariance")
  })[[1]]
  expected <- stats::acf(V, lag.max = 3, type = "covariance", plot = FALSE)

  expect_equal(layer$axes$y$label, "Autocovariance")
  expect_equal(values_of(layer), as.numeric(drop(expected$acf)))
})

test_that("the chart is titled after the series the caller named", {
  # `plot.acf` writes "Series v" and "v & w". The replayed object's own
  # `$series` cannot say it: both it and `$snames` are
  # `deparse(substitute(x))`, and the replay is handed the recorded values,
  # so measured they come back as the whole series pasted in --
  # "Series c(-2.0715334064552, -0.117989125730012, ...)".
  acf_layer <- correlogram_layers(function() acf(V, lag.max = 3))[[1]]
  ccf_layer <- correlogram_layers(function() ccf(V, W, lag.max = 2))[[1]]

  expect_equal(acf_layer$title, "Series V")
  expect_equal(ccf_layer$title, "V & W")
})

test_that("a caller who named nothing gets no invented title", {
  # `acf(rnorm(60))` names no series. Titling the chart with the expression
  # that produced it would announce a call rather than a series.
  layer <- correlogram_layers(function() acf(rnorm(60), lag.max = 3))[[1]]

  # The processor answers NULL; the layer carries the empty string, which is
  # what the multipanel path already emits for it and what the JSON encoder
  # can write -- a NULL serialised as `{}`, which is not a title either.
  expect_identical(layer$title, "")
})

test_that("the caller's own main wins", {
  layer <- correlogram_layers(function() {
    acf(V, lag.max = 3, main = "Daily returns")
  })[[1]]

  expect_equal(layer$title, "Daily returns")
})

test_that("base R will not draw a correlogram with no finite correlation", {
  # The premise behind the reading's `is.finite` guard, pinned rather than
  # assumed. A constant series has no autocorrelation -- `acf(rep(1, 20))`
  # computes `NaN` at every lag -- and `plot.acf` refuses the chart outright
  # rather than drawing empty spikes. So no such chart reaches the reading,
  # and the guard is defensive. If a release ever starts drawing them, this
  # fails here instead of the payload failing to parse in a browser (#427).
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  computed <- suppressWarnings(stats::acf(rep(1, 20), lag.max = 3, plot = FALSE))
  expect_true(all(is.nan(drop(computed$acf))))
  expect_error(
    suppressWarnings(graphics::plot(computed)),
    "finite",
    fixed = TRUE
  )
})

test_that("the spikes are addressable", {
  # gridGraphics names a correlogram's spikes after what drew them, which is
  # the same `spike` grob a `type = "h"` chart produces -- so the selector
  # the spike processor already builds resolves here unchanged.
  layer <- correlogram_layers(function() acf(V, lag.max = 3))[[1]]

  expect_true(length(layer$selectors) >= 1)
  expect_match(layer$selectors[[1]], "spike", fixed = TRUE)
})
