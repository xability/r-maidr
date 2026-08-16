# A point on a discrete scale announced a slot index, not a category name.
#
# ggplot2 maps a discrete scale onto consecutive integers and marks the result
# `mapped_discrete`, so a point in category "a" arrives as `x = 1`. That
# integer is what the point layer emitted. Measured on a three-category chart
# whose axis is labelled `g` and whose ticks read `a`, `b`, `c`:
#
#     geom_jitter(x = g)   first point  x = 1 (mapped_discrete)
#     geom_point(x = g)    first point  x = 1 (mapped_discrete)
#
# A reader heard "g is 1" where the chart says "a". Not a partial reading: the
# number is an internal coordinate, announced under the axis' own label as
# though it were the observation.
#
# #174 fixed the neighbouring half for `geom_jitter` -- the *displacement* was
# being announced as the measurement -- and left the naming open because the
# grammar had nowhere to put it. xability/maidr#927 added
# `ScatterPoint.xLabel` / `yLabel`, so the name now travels alongside the
# position rather than in place of it. The position stays numeric because the
# core sorts on it, measures distance with it and groups columns by it.
#
# The Python binding emits the same two fields for `sns.stripplot` and
# `sns.swarmplot` (xability/py-maidr#439).

testthat::skip_if_not_installed("ggplot2")

df <- function() {
  set.seed(42)
  data.frame(
    g = rep(c("a", "b", "c"), each = 8),
    v = stats::rnorm(24),
    stringsAsFactors = FALSE
  )
}

emitted_points <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  out <- list()
  for (subplot in res$subplots) {
    for (cell in subplot) {
      for (layer in cell$layers) {
        if (!identical(layer$type, "point")) next
        data <- layer$data
        points <- if (length(data) && is.list(data[[1]]) &&
          is.null(data[[1]]$x)) {
          data[[1]]
        } else {
          data
        }
        for (point in points) out[[length(out) + 1L]] <- point
      }
    }
  }
  out
}

field_of <- function(points, name) {
  vapply(
    points,
    function(point) {
      value <- point[[name]]
      if (is.null(value)) NA_character_ else as.character(value)
    },
    character(1)
  )
}

# ==============================================================================
# The discrete axis is named
# ==============================================================================

test_that("geom_point on a discrete x names every category", {
  points <- emitted_points(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) + ggplot2::geom_point()
  )

  testthat::expect_setequal(unique(field_of(points, "xLabel")), c("a", "b", "c"))
})

test_that("geom_jitter names them too", {
  # The chart #174 was filed about: the jitter is undone to recover the
  # position, and the position is now named.
  points <- emitted_points(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) + ggplot2::geom_jitter()
  )

  testthat::expect_setequal(unique(field_of(points, "xLabel")), c("a", "b", "c"))
})

test_that("each name is paired with the slot it belongs to", {
  # Stronger than the set: a layer that named every point "a" would satisfy
  # the tests above and be useless.
  points <- emitted_points(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) + ggplot2::geom_point()
  )
  pairs <- unique(paste(
    vapply(points, function(p) as.numeric(p$x), numeric(1)),
    field_of(points, "xLabel")
  ))

  testthat::expect_setequal(pairs, c("1 a", "2 b", "3 c"))
})

test_that("the measurement axis is not named", {
  points <- emitted_points(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) + ggplot2::geom_point()
  )

  testthat::expect_true(all(is.na(field_of(points, "yLabel"))))
})

test_that("a chart turned on its side names y instead", {
  # Asking about x alone was the shape of an earlier defect; the categories
  # move to y the moment the chart is horizontal.
  points <- emitted_points(
    ggplot2::ggplot(df(), ggplot2::aes(v, g)) + ggplot2::geom_point()
  )

  testthat::expect_setequal(unique(field_of(points, "yLabel")), c("a", "b", "c"))
  testthat::expect_true(all(is.na(field_of(points, "xLabel"))))
})

# ==============================================================================
# A continuous axis must stay untouched
# ==============================================================================

test_that("a numeric scatter carries no names at all", {
  # The guard that matters most. A continuous axis has breaks and labels too
  # -- "0", "25", "1.00" -- but those are formatted renderings of the numbers
  # rather than names for them, so substituting one would cost the value both
  # its type and its precision.
  points <- emitted_points(
    ggplot2::ggplot(
      data.frame(x = c(1.5, 2.5), y = c(10, 20)),
      ggplot2::aes(x, y)
    ) + ggplot2::geom_point()
  )

  testthat::expect_true(all(is.na(field_of(points, "xLabel"))))
  testthat::expect_true(all(is.na(field_of(points, "yLabel"))))
})

test_that("a numeric scatter keeps its exact values", {
  points <- emitted_points(
    ggplot2::ggplot(
      data.frame(x = c(1.5, 2.5), y = c(10, 20)),
      ggplot2::aes(x, y)
    ) + ggplot2::geom_point()
  )

  testthat::expect_equal(
    vapply(points, function(p) as.numeric(p$x), numeric(1)),
    c(1.5, 2.5)
  )
})

test_that("the helper declines a continuous axis outright", {
  built <- ggplot2::ggplot_build(
    ggplot2::ggplot(
      data.frame(x = c(1, 2), y = c(3, 4)),
      ggplot2::aes(x, y)
    ) + ggplot2::geom_point()
  )

  testthat::expect_null(maidr:::discrete_axis_labels(built, "x"))
  testthat::expect_null(maidr:::discrete_axis_labels(built, "y"))
})

# ==============================================================================
# Reading the scale
# ==============================================================================

test_that("the helper reads positions from the breaks' pos attribute", {
  # `get_breaks()` returns the level *names* on a discrete scale, carrying the
  # integer positions in a `pos` attribute. `break_positions()` is the other
  # candidate and is the wrong one -- it rescales to 0..1 (0.1875, 0.5, 0.8125
  # for three levels), which is not the space the layer's own `x` is in.
  built <- ggplot2::ggplot_build(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) + ggplot2::geom_point()
  )
  labels <- maidr:::discrete_axis_labels(built, "x")

  testthat::expect_identical(labels[["1"]], "a")
  testthat::expect_identical(labels[["3"]], "c")
})

test_that("a displaced point is named by the slot it was moved within", {
  # `position_dodge` shifts a point sideways to make room for a sibling
  # series and `position_jitter` scatters it, and both stay *within* the
  # category's own slot -- so the tick it was moved from is the category it
  # is in, not one it is being falsely assigned to.
  labels <- c("1" = "a", "2" = "b")

  testthat::expect_identical(maidr:::category_at(2, labels), "b")
  testthat::expect_identical(maidr:::category_at(1.125, labels), "a")
  testthat::expect_identical(maidr:::category_at(1.875, labels), "b")
})

test_that("a position further than half a tick is left unnamed", {
  # The bound is what keeps rounding honest. ggplot2 keeps both displacements
  # inside the slot, so anything further out is not a displaced member of
  # that category.
  labels <- c("1" = "a", "2" = "b")

  testthat::expect_null(maidr:::category_at(1.5, labels))
  testthat::expect_null(maidr:::category_at(0.2, labels))
  testthat::expect_null(maidr:::category_at(2.9, labels))
})

test_that("a dodged scatter is named rather than silently unlabelled", {
  # Measured before the bound was introduced: `x` arrived as 0.875, 1.125,
  # 1.875, 2.125 and an exact match named none of the 24 points.
  frame <- data.frame(
    g = rep(c("a", "b"), each = 12),
    h = rep(c("p", "q"), 12),
    v = stats::rnorm(24)
  )
  points <- emitted_points(
    ggplot2::ggplot(frame, ggplot2::aes(g, v, colour = h)) +
      ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.5))
  )

  testthat::expect_setequal(unique(field_of(points, "xLabel")), c("a", "b"))
})

test_that("looking up a missing position answers rather than erroring", {
  # `[[` throws "subscript out of bounds" on a missing name where `[` answers
  # NA, and a point between ticks is the ordinary case, not the odd one.
  testthat::expect_null(maidr:::category_at(99, c("1" = "a")))
  testthat::expect_null(maidr:::category_at(NA_real_, c("1" = "a")))
  testthat::expect_null(maidr:::category_at(1, NULL))
})

test_that("a position that is already the category name is left alone", {
  # The faceted path replaces the position with the category itself before
  # emission (`apply_scale_mapping`), so `x` arrives as "a" rather than 1.
  # There is nothing to name, and coercing it warned "NAs introduced by
  # coercion" once per point -- 220 warnings across the jitter suite alone.
  #
  # That the two paths disagree is a defect of its own, filed separately: the
  # grammar types `ScatterPoint.x` as a number.
  testthat::expect_null(maidr:::category_at("a", c("1" = "a")))
  testthat::expect_silent(maidr:::category_at("a", c("1" = "a")))
})

test_that("a faceted categorical scatter emits no warnings", {
  # The regression this guards is mine: the lookup ran on every point of
  # every panel, and a faceted jitter alone produced 220 of them.
  testthat::expect_silent(
    maidr:::Ggplot2PlotOrchestrator$new(
      ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
        ggplot2::geom_jitter() +
        ggplot2::facet_wrap(~ rep(c("p", "q"), 12))
    )$generate_maidr_data()
  )
})
