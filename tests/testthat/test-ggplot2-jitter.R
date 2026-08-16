# `geom_jitter` announced the jitter as the data (#174).
#
# `position_jitter()` displaces every point at random so overlapping
# observations stay separable. The displacement is a drawing decision, and it
# is what the built frame carries -- so it is what was announced.
#
# Two things were wrong and the second is the serious one. `x` was a random
# number where a discrete axis has a level; and `geom_jitter()` displaces
# **both** axes by default, so the number announced as the measurement was not
# the measurement. Measured on the overplotted integer data the geom exists
# for -- 60 responses on a 1-5 scale -- the first point was announced as
# 1.1477 where the respondent answered 1. On a five-point scale that is not a
# possible answer.
#
# A random displacement cannot be inverted, so the fix asks ggplot2 to lay the
# layer out again with `position_identity()`. These tests check the announced
# values against the **source column**, not against a rebuild, so they would
# fail if the recovery drifted rather than agreeing with itself.

set.seed(1)

likert_df <- function() {
  set.seed(42)
  data.frame(
    g = rep(c("a", "b", "c"), each = 20),
    score = sample(1:5, 60, replace = TRUE),
    h = rep(c("p", "q"), 30),
    stringsAsFactors = FALSE
  )
}

continuous_df <- function() {
  set.seed(7)
  data.frame(x = stats::rnorm(40), y = stats::rnorm(40))
}

# Drive the orchestrator rather than the processor, so what is asserted is what
# a reader receives.
emitted_points <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  out <- list()
  for (sp in res$subplots) {
    for (cell in sp) {
      for (ly in cell$layers) {
        if (!identical(ly$type, "point")) next
        data <- ly$data
        pts <- if (length(data) && is.list(data[[1]]) && is.null(data[[1]]$x)) {
          data[[1]]
        } else {
          data
        }
        for (p in pts) out[[length(out) + 1L]] <- p
      }
    }
  }
  out
}

ys_of <- function(plot) {
  vapply(emitted_points(plot), function(p) as.numeric(p$y), numeric(1))
}

xs_of <- function(plot) {
  vapply(emitted_points(plot), function(p) as.numeric(p$x), numeric(1))
}

test_that("a jittered point announces the value the respondent gave", {
  testthat::skip_if_not_installed("ggplot2")

  # The assertion the whole issue rests on. Compared against the source column
  # in its own order, so it catches a recovery that is merely self-consistent.
  df <- likert_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(g, score)) + ggplot2::geom_jitter()

  testthat::expect_equal(ys_of(plot), as.numeric(df$score))
})

test_that("no announced answer is off the scale it was measured on", {
  testthat::skip_if_not_installed("ggplot2")

  # A different way of asking, and the one that describes the harm: a
  # five-point scale has five possible answers, and 1.1477 is not one of them.
  ys <- ys_of(
    ggplot2::ggplot(likert_df(), ggplot2::aes(g, score)) + ggplot2::geom_jitter()
  )

  testthat::expect_true(all(ys == round(ys)))
  testthat::expect_true(all(ys >= 1 & ys <= 5))
})

test_that("an explicit jitter height is undone too", {
  testthat::skip_if_not_installed("ggplot2")

  # `height = 0.5` moved a point by up to 0.4969, so this is the same defect
  # with the dial turned up rather than a separate one.
  df <- likert_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(g, score)) +
    ggplot2::geom_jitter(height = 0.5, width = 0.4)

  testthat::expect_equal(ys_of(plot), as.numeric(df$score))
})

test_that("position_jitter on a plain geom_point is undone", {
  testthat::skip_if_not_installed("ggplot2")

  # `geom_jitter()` is sugar for this, so the rule has to be about the
  # position adjustment rather than about the geom's name.
  df <- likert_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(g, score)) +
    ggplot2::geom_point(position = ggplot2::position_jitter())

  testthat::expect_equal(ys_of(plot), as.numeric(df$score))
})

test_that("position_jitterdodge is undone on the axis it displaces", {
  testthat::skip_if_not_installed("ggplot2")

  # `PositionJitterdodge` does not inherit from `PositionJitter` -- both
  # descend straight from `Position` -- so it is caught by being named rather
  # than by an inheritance test.
  #
  # Asserted on **x**, which is the axis it moves: `jitter.height` defaults to
  # 0, so a y assertion here passes whether or not the position is recognised
  # and pins nothing. Measured raw, x spanned 0.6379 to 3.3539 across three
  # categories.
  df <- likert_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(g, score, colour = h)) +
    ggplot2::geom_point(position = ggplot2::position_jitterdodge())

  testthat::expect_equal(xs_of(plot), rep(c(1, 2, 3), each = 20))
  testthat::expect_equal(ys_of(plot), as.numeric(df$score))
})

test_that("a jitterdodge keeps the grouping its dodge was drawing", {
  testthat::skip_if_not_installed("ggplot2")

  # What licenses removing the dodge along with the jitter. The dodge offset
  # separates the hue levels visually, so collapsing it would lose the split
  # -- except that the level travels as an aesthetic of its own, and that is
  # where a reader hears it. If it did not, this fix would be trading one
  # missing fact for another.
  df <- likert_df()
  points <- emitted_points(
    ggplot2::ggplot(df, ggplot2::aes(g, score, colour = h)) +
      ggplot2::geom_point(position = ggplot2::position_jitterdodge())
  )
  hues <- vapply(points, function(p) as.character(p$color %||% ""), character(1))

  testthat::expect_length(unique(hues), 2)
})

test_that("an explicit jitterdodge height is undone too", {
  testthat::skip_if_not_installed("ggplot2")

  # The y half of jitterdodge, which its defaults never exercise.
  df <- likert_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(g, score, colour = h)) +
    ggplot2::geom_point(position = ggplot2::position_jitterdodge(jitter.height = 0.4))

  testthat::expect_equal(ys_of(plot), as.numeric(df$score))
})

test_that("every point lands on its category rather than beside it", {
  testthat::skip_if_not_installed("ggplot2")

  # The x half. The jitter reached 0.399 of a category width, so a point could
  # be announced almost halfway to its neighbour.
  xs <- xs_of(
    ggplot2::ggplot(likert_df(), ggplot2::aes(g, score)) + ggplot2::geom_jitter()
  )

  testthat::expect_setequal(unique(xs), c(1, 2, 3))
  testthat::expect_equal(xs, rep(c(1, 2, 3), each = 20))
})

test_that("a faceted jitter is undone in every panel", {
  testthat::skip_if_not_installed("ggplot2")

  df <- likert_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(g, score)) +
    ggplot2::geom_jitter() +
    ggplot2::facet_wrap(~g)

  ys <- ys_of(plot)
  testthat::expect_length(ys, nrow(df))
  testthat::expect_true(all(ys == round(ys)))
  testthat::expect_setequal(ys, as.numeric(unique(df$score)))
})

test_that("reading the plot does not change it", {
  testthat::skip_if_not_installed("ggplot2")

  # ggplot2 `Layer` objects are ggproto and have reference semantics, so
  # assigning to `plot$layers[[i]]$position` would strip the jitter from the
  # caller's own object -- the one they still hold and may draw. The recovery
  # builds a child that shadows the field instead, and this is what says so.
  plot <- ggplot2::ggplot(likert_df(), ggplot2::aes(g, score)) +
    ggplot2::geom_jitter()

  invisible(emitted_points(plot))

  testthat::expect_s3_class(plot$layers[[1]]$position, "PositionJitter")
})

builds_during <- function(expr) {
  calls <- 0
  trace(ggplot2::ggplot_build,
    tracer = function() calls <<- calls + 1,
    print = FALSE, where = asNamespace("maidr")
  )
  on.exit(
    try(untrace(ggplot2::ggplot_build, where = asNamespace("maidr")), silent = TRUE),
    add = TRUE
  )
  force(expr)
  calls
}

test_that("a faceted chart is not rebuilt once per panel", {
  testthat::skip_if_not_installed("ggplot2")

  # `process_facet_panel()` runs per panel, so the recovery was asked for per
  # panel too -- and each answer rebuilt the whole plot, every panel of it.
  # Counted through facets of 2, 4 and 8 panels: 3, 5 and 9 builds. The answer
  # never varies with the panel, so all but one were the same work repeated.
  #
  # Asserted as a constant rather than as "fewer than before", because the
  # defect is that it *scales* with the panel count.
  df <- likert_df()
  counts <- vapply(c(2, 4, 8), function(panels) {
    frame <- df[df$g %in% rep(c("a", "b", "c"), length.out = panels), ]
    plot <- ggplot2::ggplot(frame, ggplot2::aes(g, score)) +
      ggplot2::geom_jitter() +
      ggplot2::facet_wrap(~g)
    builds_during(emitted_points(plot))
  }, numeric(1))

  testthat::expect_equal(counts, rep(counts[[1]], 3))
})

test_that("a cached frame is never handed to a different plot", {
  testthat::skip_if_not_installed("ggplot2")

  # Two plots built from their own `geom_jitter()` calls. The entry carries
  # the layer it came from, and these are different environments, so the
  # second misses.
  first <- likert_df()
  second <- first
  second$score <- rev(second$score)

  ys_first <- ys_of(
    ggplot2::ggplot(first, ggplot2::aes(g, score)) + ggplot2::geom_jitter()
  )
  ys_second <- ys_of(
    ggplot2::ggplot(second, ggplot2::aes(g, score)) + ggplot2::geom_jitter()
  )

  testthat::expect_equal(ys_first, as.numeric(first$score))
  testthat::expect_equal(ys_second, as.numeric(second$score))
})

test_that("two plots sharing one layer object are read separately", {
  testthat::skip_if_not_installed("ggplot2")

  # The case the layer check cannot catch, and the one the case above only
  # looked like. ggplot2 documents a layer as reusable across plots, and
  # `+.gg` appends the same ggproto object rather than a clone -- so these two
  # plots are `identical()` at their layer, and a cache keyed on it answers
  # the second with the first's data.
  #
  # Measured before the per-run reset: every one of `second`'s announced
  # values was `first`'s, and the row-count check waved it through because the
  # two frames are the same length. Equal lengths are therefore the point of
  # the fixture, not an accident of it.
  first <- likert_df()
  second <- first
  second$score <- rev(second$score)
  testthat::expect_false(identical(first$score, second$score))

  shared <- ggplot2::geom_jitter()
  p1 <- ggplot2::ggplot(first, ggplot2::aes(g, score)) + shared
  p2 <- ggplot2::ggplot(second, ggplot2::aes(g, score)) + shared
  testthat::expect_true(identical(p1$layers[[1]], p2$layers[[1]]))

  testthat::expect_equal(ys_of(p1), as.numeric(first$score))
  testthat::expect_equal(ys_of(p2), as.numeric(second$score))
})

test_that("an unjittered chart is left exactly alone", {
  testthat::skip_if_not_installed("ggplot2")

  # The guard. On a continuous scatter the drawn position *is* the value, and
  # a recovery that fired here would be substituting one frame's columns into
  # another's for no reason.
  df <- continuous_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) + ggplot2::geom_point()

  testthat::expect_equal(xs_of(plot), df$x)
  testthat::expect_equal(ys_of(plot), df$y)
})

test_that("a jittered continuous scatter keeps its real coordinates", {
  testthat::skip_if_not_installed("ggplot2")

  # Jitter on continuous data moves x by a visible amount and y by almost
  # nothing, because the default height is a fraction of the data's
  # resolution. Both are still displacements, and both are undone.
  df <- continuous_df()
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_jitter(width = 0.3, height = 0.3)

  testthat::expect_equal(xs_of(plot), df$x)
  testthat::expect_equal(ys_of(plot), df$y)
})
