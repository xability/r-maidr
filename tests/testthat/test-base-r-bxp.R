# `bxp()` draws a box plot and was read as no chart at all (#262)
#
# `bxp()` is `boxplot()`'s drawing half: `boxplot.default()` computes the
# five-number summaries and hands them to `bxp()`, which puts the boxes,
# whiskers, medians and outliers on the page. Calling it directly is how a
# caller draws boxes from summaries they already have. It was one of the
# twelve names #262 found drawing while the save reported no plot; #263 put
# it in HIGH, which stopped the save failing and left it degrading to a
# picture. This is the reading.
#
# What makes it cheap is that the marks are identical. Echoed through
# `gridGraphics`, `bxp(z)` and the `boxplot()` call that produced `z` emit the
# same grob names in the same order -- the only names that differ are the
# `xlab` and `ylab` grobs, which a bare `bxp()` genuinely does not draw. So
# every selector `BaseRBoxplotLayerProcessor` builds addresses a `bxp()` chart
# unchanged, including the index shift each box with no outliers puts on the
# boxes after it, and the subclass overrides one method: where the summaries
# come from.
#
# The tests below therefore assert equality against the `boxplot()` reading
# rather than restating it. A reading that drifted from the box plot's would
# be a defect whatever it said.

SPRAY_STATS <- graphics::boxplot(
  count ~ spray,
  data = InsectSprays, plot = FALSE
)

#' Draw a box plot off-screen and return its grob tree
#'
#' `grid.echo()` comes from gridGraphics, which reaches this package only as
#' a transitive dependency, so it is skipped rather than assumed -- the same
#' line `cdplot_grobs()` draws in `test-base-r-cdplot.R`.
bxp_grobs <- function(draw) {
  if (!requireNamespace("gridGraphics", quietly = TRUE)) {
    return(NULL)
  }
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path, width = 7, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  grDevices::dev.control("enable")
  draw()
  tryCatch(
    {
      suppressMessages(gridGraphics::grid.echo())
      grid::grid.grab()
    },
    error = function(e) NULL
  )
}

#' The layer a recorded `bxp()` argument list produces
bxp_layer <- function(args, gt = NULL) {
  info <- list(
    plot_call = list(function_name = "bxp", args = args),
    group_index = 1
  )
  BaseRBxpLayerProcessor$new(info)$process(NULL, NULL, NULL, gt, info)
}

#' The layer the equivalent recorded `boxplot()` argument list produces
boxplot_layer <- function(args, gt = NULL) {
  info <- list(
    plot_call = list(function_name = "boxplot", args = args),
    group_index = 1
  )
  BaseRBoxplotLayerProcessor$new(info)$process(NULL, NULL, NULL, gt, info)
}


test_that("bxp() routes to the processor that reads its summaries", {
  adapter <- BaseRAdapter$new()

  expect_equal(
    adapter$detect_layer_type(list(function_name = "bxp", args = list())),
    "box_stats"
  )

  factory <- BaseRProcessorFactory$new()
  expect_true("box_stats" %in% factory$get_supported_types())
  expect_s3_class(
    factory$create_processor("box_stats", list(plot_call = list(args = list()))),
    "BaseRBxpLayerProcessor"
  )
})

test_that("the layer it emits is a box plot, not a type of its own", {
  # The routing name is internal. What reaches the frontend has to be the
  # type it already knows, or the core's trace factory has nothing to build.
  layer <- bxp_layer(list(SPRAY_STATS))

  expect_equal(layer$type, "box")
  expect_equal(layer$orientation, "vert")
  expect_equal(layer$domMapping$iqrDirection, "reverse")
})

test_that("it reads the same boxes boxplot() does", {
  gt <- bxp_grobs(function() graphics::bxp(SPRAY_STATS))
  skip_if(is.null(gt), "gridGraphics not available")

  from_stats <- bxp_layer(list(SPRAY_STATS), gt)
  from_data <- boxplot_layer(list(count ~ spray, data = InsectSprays), gt)

  # The whole claim in one line: same summaries, same names, same outliers.
  expect_equal(from_stats$data, from_data$data)
  # And the same elements pointed at -- the part that would silently
  # highlight the wrong box if the two readings ever diverged.
  expect_equal(from_stats$selectors, from_data$selectors)
})

test_that("the boxes carry the summaries bxp() was handed", {
  # Pinned against the values themselves as well as against `boxplot()`, so
  # a change that broke both alike still fails.
  layer <- bxp_layer(list(SPRAY_STATS))

  expect_length(layer$data, 6L)
  expect_equal(
    vapply(layer$data, function(box) box$z, character(1)),
    c("A", "B", "C", "D", "E", "F")
  )
  expect_equal(
    unlist(layer$data[[1]][c("min", "q1", "q2", "q3", "max")]),
    c(min = 7, q1 = 11, q2 = 14, q3 = 18.5, max = 23)
  )
})

test_that("an outlier lands on the box it belongs to", {
  # `z$out` and `z$group` are parallel vectors, so a reading that ignored
  # `group` would hand every outlier to the first box.
  layer <- bxp_layer(list(SPRAY_STATS))

  carried <- vapply(
    layer$data,
    function(box) length(box$lowerOutliers) + length(box$upperOutliers),
    integer(1)
  )

  expect_equal(sum(carried), length(SPRAY_STATS$out))
  expect_equal(which(carried > 0), unique(SPRAY_STATS$group))
})

test_that("horizontal = TRUE reads bottom to top, as boxplot() does", {
  # `bxp()` and `boxplot()` spell it the same way and mean the same thing,
  # so the reversal the box processor already applies is inherited whole.
  layer <- bxp_layer(list(SPRAY_STATS, horizontal = TRUE))

  expect_equal(layer$orientation, "horz")
  expect_equal(
    vapply(layer$data, function(box) box$z, character(1)),
    rev(c("A", "B", "C", "D", "E", "F"))
  )
  expect_equal(layer$domMapping$iqrDirection, "forward")
})

test_that("a bare bxp() names its axes generically, and a labelled one does not", {
  # `boxplot(y ~ g)` derives both titles from the formula and draws them.
  # `bxp(z)` has no formula and draws no `xlab` or `ylab` grob at all, so
  # naming the axes after anything in particular would announce text that is
  # not on the page.
  bare <- bxp_layer(list(SPRAY_STATS))
  expect_equal(bare$axes$x$label, "Category")
  expect_equal(bare$axes$y$label, "Value")

  labelled <- bxp_layer(
    list(SPRAY_STATS, xlab = "spray", ylab = "count", main = "Sprays")
  )
  expect_equal(labelled$axes$x$label, "spray")
  expect_equal(labelled$axes$y$label, "count")
  expect_equal(labelled$title, "Sprays")
})

test_that("it takes the summaries from z, named or positional", {
  # `match_recorded_args()` names a recorded call's arguments but keeps the
  # *author's* order, and leaves the dispatch argument unnamed when it was
  # written positionally. Measured on the three spellings:
  #
  #     bxp(Z)                          names=[]                 slot 1 is z
  #     bxp(z = Z)                      names=[z]                slot 1 is z
  #     bxp(horizontal = TRUE, z = Z)   names=[horizontal, z]    slot 1 is not
  #     bxp(horizontal = TRUE, Z)       names=[horizontal, ""]   slot 1 is not
  #
  # so neither half of the lookup covers the other, and the positional half
  # cannot assume slot 1. The last is a call R itself accepts and draws --
  # an unnamed argument binds to the first *remaining* formal, which is `z`
  # -- and it is the one that made `args[[1L]]` wrong (review of #265).
  processor <- BaseRBxpLayerProcessor$new(list(plot_call = list(args = list())))

  expect_equal(processor$read_stats(list(SPRAY_STATS)), SPRAY_STATS)
  expect_equal(processor$read_stats(list(z = SPRAY_STATS)), SPRAY_STATS)
  expect_equal(
    processor$read_stats(list(horizontal = TRUE, z = SPRAY_STATS)),
    SPRAY_STATS
  )
  expect_equal(
    processor$read_stats(stats::setNames(
      list(TRUE, SPRAY_STATS), c("horizontal", "")
    )),
    SPRAY_STATS
  )
})

test_that("a call written out of order still reads its boxes", {
  # The whole reading through the out-of-order spellings, not just
  # `read_stats()`: nothing downstream may assume the summaries are in
  # slot 1 either. Both the named and the positional `z` are driven, since
  # they reach the lookup through different halves of it.
  named <- bxp_layer(list(horizontal = TRUE, z = SPRAY_STATS))
  positional <- bxp_layer(stats::setNames(
    list(TRUE, SPRAY_STATS), c("horizontal", "")
  ))

  expect_equal(named$orientation, "horz")
  expect_equal(
    vapply(named$data, function(box) box$z, character(1)),
    rev(c("A", "B", "C", "D", "E", "F"))
  )
  expect_equal(positional$data, named$data)
  expect_equal(positional$orientation, "horz")
})

test_that("it declines a first argument that is not a boxplot.stats list", {
  # Not reachable through a call `bxp()` itself accepted -- it draws nothing
  # without a five-row numeric `stats`, and a call that errors is never
  # recorded. Kept because what it stands between is a layer announcing a
  # box plot with no boxes in it.
  processor <- BaseRBxpLayerProcessor$new(list(plot_call = list(args = list())))

  expect_null(processor$read_stats(list()))
  expect_null(processor$read_stats(list(1:10)))
  expect_null(processor$read_stats(list(list(stats = "x"))))
  expect_null(processor$read_stats(list(list(stats = matrix(1:8, nrow = 4)))))

  expect_equal(bxp_layer(list(1:10))$data, list())
})

test_that("boxplot() still recomputes its own summaries", {
  # The seam the subclass overrides is on the parent, so a mistake there
  # would break every `boxplot()` chart rather than only this one.
  processor <- BaseRBoxplotLayerProcessor$new(list(plot_call = list(args = list())))
  recomputed <- processor$read_stats(list(count ~ spray, data = InsectSprays))

  expect_equal(recomputed$stats, SPRAY_STATS$stats)
  expect_equal(recomputed$names, SPRAY_STATS$names)
})

test_that("recomputing the summaries draws nothing", {
  # `boxplot()` is a drawing function that happens to return the summaries,
  # so the replay has to say `plot = FALSE` or it puts a second chart on the
  # device it is reading. Measured on the same call either way: 0 display
  # list entries added with it, 47 without. The line predates this change
  # and was untested, which is why it is pinned here rather than trusted --
  # the seam moved it, and moving an invariant is when it gets dropped.
  processor <- BaseRBoxplotLayerProcessor$new(list(plot_call = list(args = list())))

  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit(
    {
      grDevices::dev.off()
      unlink(path)
    },
    add = TRUE
  )
  grDevices::dev.control("enable")

  before <- length(grDevices::recordPlot()[[1]])
  processor$read_stats(list(count ~ spray, data = InsectSprays))
  after <- length(grDevices::recordPlot()[[1]])

  expect_equal(after, before)
})
