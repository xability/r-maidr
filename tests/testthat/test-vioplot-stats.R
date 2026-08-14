# Base R violin support: the statistics must be the ones vioplot drew (#132)
#
# `vioplot::vioplot()` returns its box summary but not the density curve, so
# maidr recovers both by replaying the `sm.density` call vioplot makes
# internally. That is only honest if it reproduces the curve vioplot drew
# rather than a defensible curve of maidr's own -- a kernel density estimate
# computed with different defaults is not wrong in any way a reader could
# detect. It simply describes a shape the chart does not draw.
#
# This issue was listed as blocked on exactly that concern. It is not, and the
# reason is that both halves are checkable from directions that do not touch
# each other:
#
#   * the box statistics against vioplot's own return value, which is
#     `identical()` rather than merely close;
#   * the curve against the drawn polygon, whose vertex count is exactly twice
#     the number of evaluation points `sm.density` returns -- the curve
#     mirrored about the category position.
#
# The second is the one worth keeping. It ties the replayed call to the
# rendered SVG without going through any of maidr's own code.

skip_if_no_vioplot <- function() {
  testthat::skip_if_not_installed("vioplot")
  testthat::skip_if_not_installed("sm")
}

sample_a <- function() {
  set.seed(11)
  stats::rnorm(40, 10, 2)
}

sample_b <- function() {
  set.seed(12)
  stats::rnorm(30, 14, 3)
}

# Draw a vioplot off-screen and hand back both its return value and its grobs.
drawn_vioplot <- function(...) {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path, width = 7, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  grDevices::dev.control("enable")
  returned <- vioplot::vioplot(...)
  grobs <- tryCatch(
    {
      suppressMessages(gridGraphics::grid.echo())
      grid::grid.grab()
    },
    error = function(e) NULL
  )
  list(returned = returned, grobs = grobs)
}

test_that("every box statistic is the one vioplot itself reports", {
  skip_if_no_vioplot()
  a <- sample_a()
  b <- sample_b()

  drawn <- drawn_vioplot(a, b, names = c("A", "B"))
  returned <- drawn$returned

  for (i in seq_len(2)) {
    computed <- compute_vioplot_stats(list(a, b)[[i]])

    # `identical`, not `expect_equal`. These are recomputed by the same
    # arithmetic vioplot uses, so anything short of bit equality would mean
    # the recipe had drifted rather than that floating point had.
    expect_identical(computed$q1, returned$q1[i])
    expect_identical(computed$q3, returned$q3[i])
    expect_identical(computed$median, returned$median[i])
    expect_identical(computed$min, returned$lower[i])
    expect_identical(computed$max, returned$upper[i])
  }
})

test_that("the recovered curve is the one the violin was drawn from", {
  skip_if_no_vioplot()
  a <- sample_a()

  drawn <- drawn_vioplot(a)
  skip_if(is.null(drawn$grobs), "grid.echo unavailable")

  body <- NULL
  find_body <- function(g) {
    if (!is.null(g$name) && identical(as.character(g$name), "graphics-plot-1-polygon-1")) {
      body <<- g
    }
    if (inherits(g, "gList")) for (i in seq_along(g)) find_body(g[[i]])
    if (inherits(g, "gTree") && !is.null(g$children)) {
      for (i in seq_along(g$children)) find_body(g$children[[i]])
    }
    if (!is.null(g$grobs)) for (i in seq_along(g$grobs)) find_body(g$grobs[[i]])
  }
  find_body(drawn$grobs)

  expect_false(is.null(body))

  computed <- compute_vioplot_stats(a)

  # The drawn body is the curve mirrored about the category position, so it
  # carries exactly twice the evaluation points. This is the assertion that
  # ties the replayed `sm.density` call to the rendered geometry without
  # passing through any of maidr's own code.
  expect_identical(length(body$x), length(computed$positions) * 2L)
})

test_that("the curve is evaluated across the whole sample, not the whiskers", {
  skip_if_no_vioplot()

  # vioplot spells its span `c(min(lower, data.min), max(upper, data.max))`,
  # which collapses to the data range. Evaluating over the whiskers instead
  # looks equivalent and is not: the whiskers pull in from the extremes
  # whenever a point sits beyond the fence, so the curve would stop short of
  # values the violin visibly reaches.
  #
  # The point count cannot catch this -- `sm.density` returns the same number
  # of evaluation points whatever span it is given -- so the endpoints are
  # asserted directly.
  sample <- c(stats::rnorm(40, 10, 1), 40, -15)
  computed <- compute_vioplot_stats(sample)

  expect_equal(computed$positions[1], min(sample))
  expect_equal(computed$positions[length(computed$positions)], max(sample))

  # And the whiskers really do differ here, so the assertion above has
  # something to catch rather than passing because the two coincide.
  expect_gt(computed$min, min(sample))
  expect_lt(computed$max, max(sample))
})

test_that("a caller's bandwidth is carried through rather than defaulted", {
  skip_if_no_vioplot()
  a <- sample_a()

  chosen <- compute_vioplot_stats(a)
  wider <- compute_vioplot_stats(a, h = chosen$bandwidth * 3)

  # vioplot passes `h` straight to `sm.density`, so ignoring it would announce
  # a smoother curve than the one drawn -- and a smoother curve can show one
  # mode where the chart shows two.
  expect_equal(wider$bandwidth, chosen$bandwidth * 3)
  expect_false(identical(wider$density, chosen$density))
})

test_that("the whisker reach follows vioplot's range argument", {
  skip_if_no_vioplot()
  a <- sample_a()

  default <- compute_vioplot_stats(a)
  tight <- compute_vioplot_stats(a, range = 0.1)

  # `range` decides where the whiskers stop even though it does not affect the
  # span the density is evaluated over, so it has to be read from the call.
  expect_gt(default$max, tight$max)
  expect_lt(default$min, tight$min)
})

test_that("a sample with no spread has no curve to announce", {
  skip_if_no_vioplot()

  # vioplot draws a degenerate mark for it. Inventing a curve would claim a
  # spread the chart does not show, so this declines and lets the processor
  # decide -- which it does by leaving the category out entirely.
  expect_null(compute_vioplot_stats(c(5, 5, 5)))
  expect_null(compute_vioplot_stats(5))
  expect_null(compute_vioplot_stats(numeric(0)))
})

test_that("missing values are dropped rather than poisoning the curve", {
  skip_if_no_vioplot()

  with_gaps <- compute_vioplot_stats(c(1, NA, 2, 3, 4, NA))
  without <- compute_vioplot_stats(c(1, 2, 3, 4))

  # An `NA` left in the sample propagates through the kernel sum to every
  # density point; treated as zero it would place an observation where nothing
  # was measured.
  expect_equal(with_gaps$density, without$density)
  expect_equal(with_gaps$positions, without$positions)
})

test_that("groups are split the way vioplot accepts them", {
  a <- sample_a()
  b <- sample_b()

  named_by_position <- extract_vioplot_samples(list(a, b))
  expect_equal(names(named_by_position), c("1", "2"))
  expect_equal(lengths(named_by_position), c(`1` = 40L, `2` = 30L))

  # An explicit `names =` wins, because that is what vioplot draws on the axis.
  explicit <- extract_vioplot_samples(list(a, b, names = c("A", "B")))
  expect_equal(names(explicit), c("A", "B"))

  # One list or data frame holding every group.
  as_list <- extract_vioplot_samples(list(list(x = a, y = b)))
  expect_equal(names(as_list), c("x", "y"))

  as_frame <- extract_vioplot_samples(list(data.frame(p = 1:10, q = 11:20)))
  expect_equal(names(as_frame), c("p", "q"))
})

test_that("a group passed as the named first argument is not lost", {
  a <- sample_a()
  b <- sample_b()

  # `vioplot()`'s first formal is named `x`, so `vioplot(x = a, b)` records it
  # as a named argument. Reading only the unnamed ones dropped that group
  # entirely -- and `vioplot(x = a)` alone then yielded nothing at all, so a
  # single-violin chart written that way announced nothing.
  both <- extract_vioplot_samples(list(x = a, b))
  expect_length(both, 2)
  expect_equal(lengths(both), c(`1` = 40L, `2` = 30L))

  alone <- extract_vioplot_samples(list(x = a))
  expect_length(alone, 1)
})

test_that("groups are labelled the way vioplot labels them", {
  a <- sample_a()
  b <- sample_b()

  # Measured against the axis labels vioplot actually draws. The distinction
  # is that a name is a label only when it came from inside a list or a data
  # frame -- for separate vectors it is the *argument's* name, which vioplot
  # does not draw:
  #
  #   vioplot(a, b)                 -> "1", "2"
  #   vioplot(x = a, b)             -> "1", "2"
  #   vioplot(list(p = , q = ))     -> "p", "q"
  expect_equal(names(extract_vioplot_samples(list(a, b))), c("1", "2"))
  expect_equal(names(extract_vioplot_samples(list(x = a, b))), c("1", "2"))
  expect_equal(names(extract_vioplot_samples(list(list(p = a, q = b)))), c("p", "q"))
})

test_that("a call with nothing numeric in it yields no violins", {
  expect_length(extract_vioplot_samples(list()), 0)
  expect_length(extract_vioplot_samples(list(names = c("A", "B"))), 0)
  expect_length(extract_vioplot_samples(list("not numeric")), 0)
})
