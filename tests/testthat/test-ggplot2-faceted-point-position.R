# A faceted categorical scatter put a string where the grammar wants a number.
#
# The same chart emitted two different shapes depending on whether it was
# facetted:
#
#     ggplot(df, aes(g, v)) + geom_jitter()                    x = 1
#     ggplot(df, aes(g, v)) + geom_jitter() + facet_wrap(~f)    x = "a"
#
# The faceted path indexed the panel's sorted category values by the drawn
# position and emitted the name it landed on, so the position was gone and the
# name was in its place. (#178 attributes this to `apply_scale_mapping()`,
# which never ran: no caller passed a scale mapping, and the plumbing that
# would have has since been removed.)
#
# `ScatterPoint.x` is typed `number` in the grammar, and `ScatterTrace` does
# arithmetic on it: it sorts with `a.x - b.x`, indexes columns by the value,
# and resolves the nearest point with `Math.hypot`. A string makes the
# subtraction NaN, and a comparator returning NaN leaves `Array.prototype.sort`
# with no ordering to apply -- so the points stay in input order rather than
# the x order every downstream index assumes, and `findNearestPoint` has no
# nearest point to find. The faceted chart announced the right name while
# handing the core a payload it could not sort, index or highlight against
# (#178).
#
# The fix is a removal rather than a conversion: `ScatterPoint.xLabel` exists
# as of xability/maidr#927 and the point processor already fills it from
# `discrete_axis_labels()`, so the name never had to displace the position.
#
# The bar processor still announces its category as `x`, and is right to: a
# bar's `x` is `string | number` in the grammar and a bar chart is navigated by
# category rather than by distance, so nothing subtracts one x from another
# there -- which is why the last test in this file pins it as unchanged.

testthat::skip_if_not_installed("ggplot2")

faceted_frame <- function() {
  set.seed(178)
  data.frame(
    g = rep(c("a", "b", "c"), each = 8),
    v = stats::rnorm(24),
    panel = rep(c("p", "q"), 12),
    stringsAsFactors = FALSE
  )
}

layers_of <- function(plot, type) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  out <- list()
  for (subplot in res$subplots) {
    for (cell in subplot) {
      for (layer in cell$layers) {
        if (!identical(layer$type, type)) next
        data <- layer$data
        samples <- if (length(data) && is.list(data[[1]]) &&
          is.null(data[[1]]$x)) {
          data[[1]]
        } else {
          data
        }
        out[[length(out) + 1L]] <- samples
      }
    }
  }
  out
}

xs_of <- function(samples) {
  vapply(samples, function(sample) sample$x, numeric(1))
}

labels_of <- function(samples) {
  vapply(
    samples,
    function(sample) if (is.null(sample$xLabel)) NA_character_ else sample$xLabel,
    character(1)
  )
}

testthat::test_that("a faceted point's x is the number the core can sort", {
  plot <- ggplot2::ggplot(faceted_frame(), ggplot2::aes(g, v)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~panel)

  panels <- layers_of(plot, "point")

  testthat::expect_length(panels, 2L)
  for (samples in panels) {
    # `expect_type` on the values rather than a class check, because
    # `mapped_discrete` inherits numeric and either is a usable position.
    testthat::expect_true(all(vapply(samples, function(s) is.numeric(s$x), logical(1))))
    testthat::expect_false(any(vapply(samples, function(s) is.character(s$x), logical(1))))
  }
})

testthat::test_that("a faceted jitter keeps its name alongside the position", {
  plot <- ggplot2::ggplot(faceted_frame(), ggplot2::aes(g, v)) +
    ggplot2::geom_jitter() +
    ggplot2::facet_wrap(~panel)

  panels <- layers_of(plot, "point")

  testthat::expect_length(panels, 2L)
  for (samples in panels) {
    testthat::expect_true(all(!is.na(labels_of(samples))))
    testthat::expect_true(all(labels_of(samples) %in% c("a", "b", "c")))
  }
})

testthat::test_that("facetting does not change the shape a point is emitted in", {
  # The property being fixed, stated directly. Faceting splits the rows across
  # panels, so the values differ -- what must not differ is the *kind* of
  # thing `x` and `xLabel` hold.
  frame <- faceted_frame()
  plain <- ggplot2::ggplot(frame, ggplot2::aes(g, v)) + ggplot2::geom_point()
  facetted <- plain + ggplot2::facet_wrap(~panel)

  unfaceted <- layers_of(plain, "point")[[1]]
  panels <- layers_of(facetted, "point")

  testthat::expect_true(all(vapply(unfaceted, function(s) is.numeric(s$x), logical(1))))
  for (samples in panels) {
    testthat::expect_identical(
      vapply(samples, function(s) class(s$x)[1], character(1)),
      rep(class(unfaceted[[1]]$x)[1], length(samples))
    )
  }
})

testthat::test_that("every panel's points still name their own categories", {
  # Each panel holds all three categories here, so a panel that reused
  # another's labels would still look complete.
  frame <- faceted_frame()
  plot <- ggplot2::ggplot(frame, ggplot2::aes(g, v)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~panel)

  for (samples in layers_of(plot, "point")) {
    positions <- xs_of(samples)
    names <- labels_of(samples)
    # Position 1 is "a", 2 is "b", 3 is "c" -- the map ggplot2 built, and the
    # thing the label has to agree with rather than merely be present.
    testthat::expect_identical(names, c("a", "b", "c")[round(positions)])
  }
})

testthat::test_that("a faceted continuous scatter is untouched", {
  # The branch that used to stringify an x it could not find a column for.
  # A continuous axis has no categories, so the position is the value and
  # there is no name to carry.
  frame <- faceted_frame()
  plot <- ggplot2::ggplot(frame, ggplot2::aes(v, v)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~panel)

  for (samples in layers_of(plot, "point")) {
    testthat::expect_true(all(vapply(samples, function(s) is.numeric(s$x), logical(1))))
    testthat::expect_true(all(is.na(labels_of(samples))))
  }
})

testthat::test_that("a faceted bar still announces its category as x", {
  # The scope of the change. `Ggplot2BarLayerProcessor` calls the same helper
  # and is right to: a bar's `x` is `string | number` in the grammar, and a
  # bar chart is navigated by category rather than by distance.
  frame <- faceted_frame()
  plot <- ggplot2::ggplot(frame, ggplot2::aes(g)) +
    ggplot2::geom_bar() +
    ggplot2::facet_wrap(~panel)

  panels <- layers_of(plot, "bar")

  testthat::expect_length(panels, 2L)
  for (samples in panels) {
    testthat::expect_identical(
      vapply(samples, function(s) as.character(s$x), character(1)),
      c("a", "b", "c")
    )
  }
})
