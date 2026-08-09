# Regression tests for issue #98: a Base R argument supplied positionally
# must reach the processors under the name R matched it to.
#
# The wrapper is declared `function(...)`, so `list(...)` keeps only the names
# the user typed. Two defects followed from that, plus one that reimplemented
# R's own coordinate resolution by hand:
#
#   hist(x, 20)  announced 9 Sturges bins over a 22-bar picture
#   plot(m)      announced an x grid of 0..10 over an axis drawn 1..5
#
# The fix names the recorded arguments centrally and lets grDevices::xy.coords()
# resolve matrix / data frame / ts inputs. These tests pin both, and pin the
# property that makes the central fix safe: the argument R dispatches on is
# left exactly as the user wrote it, so replay still reaches the same method.

setup_positional <- function() {
  maidr:::clear_all_device_storage()
}

# The single recorded high-level call for `function_name`.
recorded_call <- function(function_name) {
  calls <- maidr:::get_device_calls(grDevices::dev.cur())
  matches <- Filter(
    function(entry) identical(entry$function_name, function_name),
    calls
  )
  testthat::expect_gte(length(matches), 1)
  matches[[1]]
}

# The layer a fresh orchestrator builds for the current device.
first_layer <- function() {
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(grDevices::dev.cur())
  layers <- orchestrator$get_layers()
  testthat::expect_gte(length(layers), 1)
  layers[[1]]
}

# ==============================================================================
# B. hist(x, 20): a positional `breaks`
# ==============================================================================

test_that("a positional breaks is recorded under the name R matched", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  set.seed(1)
  values <- stats::rnorm(60)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)

  hist(values, 20)

  args <- recorded_call("hist")$args
  testthat::expect_equal(args[["breaks"]], 20)
})

test_that("hist(x, 20) announces the bins hist(x, 20) draws", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  set.seed(1)
  values <- stats::rnorm(60)
  drawn_bins <- length(graphics::hist(values, 20, plot = FALSE)$counts)
  # Guard the fixture itself: the defect is invisible if 20 happens to round
  # back to the Sturges default.
  testthat::expect_false(
    identical(drawn_bins, length(graphics::hist(values, plot = FALSE)$counts))
  )

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)

  hist(values, 20)

  layer <- first_layer()
  processor <- maidr:::BaseRHistogramLayerProcessor$new(layer)
  data <- processor$extract_data(layer)

  testthat::expect_equal(length(data), drawn_bins)
})

test_that("positional and named breaks describe the same histogram", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  set.seed(1)
  values <- stats::rnorm(60)

  extract <- function(expr) {
    setup_positional()
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(expr)
    layer <- first_layer()
    maidr:::BaseRHistogramLayerProcessor$new(layer)$extract_data(layer)
  }

  positional <- extract(hist(values, 20))
  named <- extract(hist(values, breaks = 20))

  testthat::expect_equal(positional, named)
})

# ==============================================================================
# A. plot(matrix): the announced grid must be the drawn grid
# ==============================================================================

test_that("plot(matrix) announces the axis grid R draws", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  m <- cbind(c(1, 2, 3, 4, 5), c(100, 200, 300, 400, 500))

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)

  graphics::plot(m)
  drawn_x <- graphics::axTicks(1)
  drawn_y <- graphics::axTicks(2)

  plot(m)
  layer <- first_layer()
  axes <- maidr:::BaseRPointLayerProcessor$new(layer)$extract_axis_titles(layer)

  testthat::expect_equal(axes$x$min, min(drawn_x))
  testthat::expect_equal(axes$x$max, max(drawn_x))
  testthat::expect_equal(axes$x$tickStep, diff(drawn_x)[1])
  testthat::expect_equal(axes$y$min, min(drawn_y))
  testthat::expect_equal(axes$y$max, max(drawn_y))
  testthat::expect_equal(axes$y$tickStep, diff(drawn_y)[1])
})

test_that("plot(matrix) grid spans the points it announces, not twice as many", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  m <- cbind(c(1, 2, 3, 4, 5), c(100, 200, 300, 400, 500))

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)

  plot(m)
  layer <- first_layer()
  processor <- maidr:::BaseRPointLayerProcessor$new(layer)
  data <- processor$extract_data(layer)
  axes <- processor$extract_axis_titles(layer)

  # The flattened-matrix fallback read all 10 cells as y and indexed x over
  # 1:10, so the grid ran to 10 while only 5 points were announced.
  testthat::expect_equal(length(data), nrow(m))
  testthat::expect_lte(axes$x$max, nrow(m))
})

test_that("plot(data.frame) and plot(ts) announce their own x grid", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)

  plot(data.frame(a = c(1, 2, 3, 4, 5), b = c(100, 200, 300, 400, 500)))
  frame_axes <- {
    layer <- first_layer()
    maidr:::BaseRPointLayerProcessor$new(layer)$extract_axis_titles(layer)
  }
  testthat::expect_equal(frame_axes$x$min, 1)
  testthat::expect_equal(frame_axes$x$max, 5)

  setup_positional()
  plot(stats::ts(c(5, 7, 9, 11, 13), start = 2001))
  series_axes <- {
    layer <- first_layer()
    maidr:::BaseRPointLayerProcessor$new(layer)$extract_axis_titles(layer)
  }
  # A ts carries its own time axis; indexing it 1..5 announced every point at
  # the wrong place on a plot labelled 2001..2005.
  testthat::expect_equal(series_axes$x$min, 2001)
  testthat::expect_equal(series_axes$x$max, 2005)
})

# ==============================================================================
# The property that keeps the central fix safe
# ==============================================================================

test_that("match_recorded_args names the dots but never the dispatch argument", {
  set.seed(1)
  values <- stats::rnorm(60)

  matched <- maidr:::match_recorded_args(
    "hist", graphics::hist, list(values, 20, col = "grey")
  )

  # `breaks` is a formal of hist.default, not of the hist generic: matching
  # against the generic alone would leave the 20 inside the dots.
  testthat::expect_equal(names(matched), c("", "breaks", "col"))
  # Order is preserved, so positional access in the wrappers still holds.
  testthat::expect_equal(matched[[1]], values)
})

test_that("match_recorded_args leaves a formula call able to dispatch", {
  d <- data.frame(x = 1:10, y = (1:10)^1.5)

  matched <- maidr:::match_recorded_args(
    "plot", graphics::plot, list(y ~ x, data = d)
  )

  # plot.formula() calls its first formal `formula`; the generic calls it `x`.
  # Naming it either way sends the replayed call to the wrong place, so it
  # must stay positional.
  testthat::expect_equal(names(matched)[1], "")

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  testthat::expect_silent(do.call(graphics::plot, matched))
})

test_that("a recorded formula plot still replays after matching", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  d <- data.frame(x = 1:10, y = (1:10)^1.5)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)

  plot(y ~ x, data = d)
  boxplot(y ~ x, data = d)

  for (name in c("plot", "boxplot")) {
    entry <- recorded_call(name)
    testthat::expect_error(
      maidr:::replay_plot_call(entry$function_name, entry$args, entry$call_env),
      NA
    )
  }
})

test_that("a positional names.arg labels the bars it was written for", {
  setup_positional()
  on.exit(setup_positional(), add = TRUE)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)

  barplot(c(10, 20, 30), 1, 0.2, c("A", "B", "C"))

  layer <- first_layer()
  data <- maidr:::BaseRBarplotLayerProcessor$new(layer)$extract_data(layer)

  testthat::expect_equal(vapply(data, function(p) p$x, character(1)), c("A", "B", "C"))
})
