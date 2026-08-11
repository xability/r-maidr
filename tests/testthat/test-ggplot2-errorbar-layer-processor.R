# Tests for Ggplot2ErrorbarLayerProcessor
#
# ggplot2's built data carries BOTH pairs of bounds for most uncertainty
# geoms, and only one of them is the interval: for a vertical geom_errorbar,
# xmin/xmax are the cap width, a styling parameter that is not data at all.
# These tests are written against the cases that distinguish the two, so an
# implementation reading the wrong pair fails rather than looking plausible.

skip_if_not_installed("ggplot2")

library(ggplot2)

#: Three group means with asymmetric intervals. Every number is distinct so a
#: reading that took the wrong bound, or the wrong sample, cannot coincide
#: with the right one -- and no bound equals a cap extent (0.55 / 1.45).
eb_data <- function() {
  data.frame(
    g = c("control", "low", "high"),
    y = c(4.2, 5.1, 7.3),
    lo = c(3.8, 4.0, 7.1),
    hi = c(4.6, 6.6, 7.4)
  )
}

# Build a layer's MAIDR payload.
eb_process <- function(plot) {
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  processor$process(plot, NULL, ggplot2::ggplot_build(plot))
}

# Classify a layer the way the adapter does.
eb_detect <- function(plot) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[1]], plot)
}

# ==============================================================================
# Detection
# ==============================================================================

test_that("every uncertainty geom is detected as an error bar layer", {
  df <- eb_data()
  mapping <- aes(g, y, ymin = lo, ymax = hi)

  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_errorbar()), "error_bar")
  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_linerange()), "error_bar")
  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_pointrange()), "error_bar")
  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_crossbar()), "error_bar")
  testthat::expect_equal(
    eb_detect(ggplot(df, aes(y, g, xmin = lo, xmax = hi)) + geom_errorbarh()),
    "error_bar"
  )
})

test_that("detection does not swallow neighbouring geoms", {
  # GeomCrossbar and GeomPointrange do not inherit GeomErrorbar, so the
  # membership test could not be loosened to inherits() -- and this is what
  # says the loosening did not take other layer types with it.
  df <- eb_data()

  testthat::expect_equal(eb_detect(ggplot(df, aes(g, y)) + geom_point()), "point")
  testthat::expect_equal(eb_detect(ggplot(df, aes(g, y)) + geom_col()), "bar")
})

# ==============================================================================
# Vertical intervals
# ==============================================================================

test_that("a vertical error bar emits the interval, not the cap width", {
  # The trap: built data carries xmin = 0.55 and xmax = 1.45 for the first
  # sample, which is how wide the cap is drawn. Reading that pair would
  # produce a navigable chart describing the styling.
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(result$type, "error_bar")
  testthat::expect_equal(result$orientation, "vert")
  testthat::expect_equal(result$data[[1]]$yMin, 3.8)
  testthat::expect_equal(result$data[[1]]$yMax, 4.6)
})

test_that("asymmetric intervals survive both sides", {
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_pointrange()
  )

  bounds <- lapply(result$data, function(point) c(point$yMin, point$yMax))
  testthat::expect_equal(bounds[[2]], c(4.0, 6.6))
  testthat::expect_equal(bounds[[3]], c(7.1, 7.4))
})

test_that("a discrete category is named, not numbered", {
  # ggplot2 maps a discrete axis onto integer positions before computing the
  # layer, and the positions follow the scale's order rather than the data's:
  # here "low" is drawn third and "high" second. Announcing 1/2/3 would name
  # something the reader cannot find on the chart, and would not even read as
  # a row number.
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(
    vapply(result$data, function(point) as.character(point$x), character(1)),
    c("control", "low", "high")
  )
})

test_that("a continuous category axis keeps its numbers", {
  # The label lookup must not fire on a continuous axis: its break labels
  # ("0", "25", ...) are not an index into anything, and treating them as one
  # would rename every point.
  df <- data.frame(x = c(10, 20, 30), y = c(1, 2, 3), lo = c(0.5, 1.5, 2.5),
                   hi = c(1.5, 2.5, 3.5))
  result <- eb_process(ggplot(df, aes(x, y, ymin = lo, ymax = hi)) + geom_errorbar())

  testthat::expect_equal(
    vapply(result$data, function(point) as.numeric(point$x), numeric(1)),
    c(10, 20, 30)
  )
})

# ==============================================================================
# Horizontal intervals
# ==============================================================================

test_that("geom_errorbarh reads the x pair, and says it is horizontal", {
  # geom_errorbarh carries no flipped_aes column at all, so an implementation
  # reading only that flag would call this vertical and emit ymin/ymax --
  # which here are the cap HEIGHTS (0.55 / 1.45), not the interval.
  result <- eb_process(
    ggplot(eb_data(), aes(y, g, xmin = lo, xmax = hi)) + geom_errorbarh()
  )

  testthat::expect_equal(result$orientation, "horz")
  testthat::expect_equal(result$data[[1]]$yMin, 3.8)
  testthat::expect_equal(result$data[[1]]$yMax, 4.6)
})

test_that("an explicitly flipped error bar is horizontal too", {
  result <- eb_process(
    ggplot(eb_data(), aes(y, g, xmin = lo, xmax = hi)) +
      geom_errorbar(orientation = "y")
  )

  testthat::expect_equal(result$orientation, "horz")
  testthat::expect_equal(result$data[[1]]$yMin, 3.8)
  testthat::expect_equal(result$data[[1]]$yMax, 4.6)
})

test_that("a horizontal layer reads the same magnitudes as a vertical one", {
  # The emitted shape names the category x and the magnitude y in BOTH
  # orientations -- that is what MAIDR's ErrorBarTrace consumes -- so the two
  # payloads must agree on every number and differ only in `orientation`.
  df <- eb_data()
  vertical <- eb_process(ggplot(df, aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar())
  horizontal <- eb_process(
    ggplot(df, aes(y, g, xmin = lo, xmax = hi)) + geom_errorbarh()
  )

  testthat::expect_equal(
    lapply(vertical$data, function(p) c(p$y, p$yMin, p$yMax)),
    lapply(horizontal$data, function(p) c(p$y, p$yMin, p$yMax))
  )
})

# ==============================================================================
# Degenerate inputs
# ==============================================================================

test_that("a layer with no bounds still emits its estimates", {
  # A one-sided or bound-less layer is a real chart, and dropping the points
  # for want of their bounds would lose the estimates too.
  df <- eb_data()
  result <- eb_process(
    ggplot(df, aes(g, y, ymin = lo, ymax = hi)) + geom_pointrange()
  )

  testthat::expect_length(result$data, 3)
  testthat::expect_equal(
    vapply(result$data, function(point) point$y, numeric(1)),
    c(4.2, 5.1, 7.3)
  )
})

test_that("an empty layer yields no points rather than erroring", {
  empty <- data.frame(
    g = character(0), y = numeric(0), lo = numeric(0), hi = numeric(0)
  )
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1)
  )

  testthat::expect_equal(processor$extract_interval_data(NULL, NULL, FALSE), list())
})
