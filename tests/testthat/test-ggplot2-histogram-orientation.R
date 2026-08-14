# A horizontal ggplot2 histogram was announced with its bins and counts
# swapped (#163).
#
# The emitted data was never wrong. `ggplot_build()` fills a flipped layer's
# `ymin`/`ymax` with the bin bounds and its `x` with the count, and the
# processor passes both through as they come, so the payload was already
# transposed correctly. What was missing is the `orientation` key saying so.
#
# Without it the frontend defaults to vertical and reads the bin range from
# `xMin`/`xMax` -- which on a flipped layer hold the count bounds. Measured by
# putting the emitted layer through the real `Histogram` model:
#
#                   announced        actually is       truth
#   Bin range       0 to 5           the count range   -2.4226 to -1.1012
#   Min value       -2.2024          a bin centre      1
#   Max value       -1.3214          a bin centre      5
#   Table headers   count, v, ...    reversed          v, count, ...
#
# Every number real, every one on the wrong axis, and nothing erroring. That
# is why the tests below assert the orientation key rather than the data: the
# data was already right, and a test over it would have passed throughout.

schema_of <- function(plot) {
  maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
}

layer_of <- function(plot) {
  schema_of(plot)$subplots[[1]][[1]]$layers[[1]]
}

hist_frame <- function() {
  set.seed(3)
  data.frame(v = stats::rnorm(60), g = rep(c("a", "b"), each = 30))
}

test_that("a histogram binned on y says it is horizontal", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- layer_of(
    ggplot2::ggplot(hist_frame(), ggplot2::aes(y = v)) +
      ggplot2::geom_histogram(bins = 10)
  )

  testthat::expect_equal(layer$orientation, "horz")
})

test_that("a histogram binned on x still says it is vertical", {
  testthat::skip_if_not_installed("ggplot2")

  # Emitted either way rather than left off for the default, so a reader of
  # the schema never has to infer it.
  layer <- layer_of(
    ggplot2::ggplot(hist_frame(), ggplot2::aes(x = v)) +
      ggplot2::geom_histogram(bins = 10)
  )

  testthat::expect_equal(layer$orientation, "vert")
})

test_that("the bin bounds sit on the axis the orientation names", {
  testthat::skip_if_not_installed("ggplot2")

  frame <- hist_frame()
  upright <- layer_of(
    ggplot2::ggplot(frame, ggplot2::aes(x = v)) +
      ggplot2::geom_histogram(bins = 10)
  )
  sideways <- layer_of(
    ggplot2::ggplot(frame, ggplot2::aes(y = v)) +
      ggplot2::geom_histogram(bins = 10)
  )

  # The pairing is what matters: the key has to name the axis the bounds are
  # actually on, or the frontend reads the count range as the bin range. Same
  # sample, so the two are the same numbers transposed.
  first_up <- upright$data[[1]]
  first_side <- sideways$data[[1]]

  testthat::expect_equal(first_side$yMin, first_up$xMin)
  testthat::expect_equal(first_side$yMax, first_up$xMax)
  testthat::expect_equal(first_side$x, first_up$y)
  testthat::expect_equal(first_side$xMax, first_up$yMax)
})

test_that("coord_flip is left vertical, because its data is not flipped", {
  testthat::skip_if_not_installed("ggplot2")

  # `coord_flip()` rotates the coordinate system and leaves `flipped_aes`
  # alone, so the bin bounds stay in `xmin`/`xmax`. Calling it horizontal
  # would swap a pair that is already the right way round -- the announcement
  # would break in exactly the way this issue is about, from the other side.
  #
  # Whether a reader of a rotated chart should be told "horizontal" is a
  # separate question that spans every processor; see #162.
  plot <- ggplot2::ggplot(hist_frame(), ggplot2::aes(x = v)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::coord_flip()
  layer <- layer_of(plot)

  testthat::expect_equal(layer$orientation, "vert")
  testthat::expect_true(layer$data[[1]]$yMin == 0)
})

test_that("a faceted horizontal histogram carries the orientation on every panel", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(hist_frame(), ggplot2::aes(y = v)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::facet_wrap(~g)
  panels <- unlist(schema_of(plot)$subplots, recursive = FALSE)
  testthat::expect_gt(length(panels), 1)

  # The orientation is read from the layer rather than from a panel's own
  # data, so a panel that drew no bins cannot come out disagreeing with its
  # neighbours about which axis the reader is on.
  for (panel in panels) {
    testthat::expect_equal(panel$layers[[1]]$orientation, "horz")
  }
})

test_that("determine_orientation declines rather than erroring on a missing layer", {
  testthat::skip_if_not_installed("ggplot2")

  # `get_layer_index()` addresses `built$data`, and a processor built for an
  # index that layer list does not reach would otherwise subscript out of
  # bounds inside a rendering path.
  processor <- maidr:::Ggplot2HistogramLayerProcessor$new(list(index = 99))
  plot <- ggplot2::ggplot(hist_frame(), ggplot2::aes(x = v)) +
    ggplot2::geom_histogram(bins = 10)

  testthat::expect_equal(processor$determine_orientation(plot), "vert")
})
