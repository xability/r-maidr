# A cdplot() is a 100% stacked area chart (#251)
#
# `cdplot()` had no branch in `detect_layer_type()`, so the switch fell
# through to "unknown" and the chart degraded to the static image #216
# arranged for it. It draws the conditional distribution of a factor across a
# numeric x as bands that fill the height, which is what
# `stacked_normalized_area` is for -- the type `geom_area(position = "fill")`
# already produces, so both adapters describe one chart alike.
#
# What the tests below pin is the part that is not obvious from the picture:
# `cdplot()` returns the *boundaries* between the bands, named for the level
# below each, in a level order it has reversed; and the grid those boundaries
# interpolate over is longer than the one that was drawn, because
# `stats::density()` pads past the data and `cdplot()` trims the padding off
# before drawing.

set.seed(20240824)
N <- 200
SCORE <- stats::rnorm(N, 50, 12)
GRADE <- factor(sample(c("a", "b", "c"), N, TRUE, prob = c(0.5, 0.3, 0.2)))
PASSED <- factor(ifelse(SCORE > 50, "yes", "no"))

#' Draw a conditional density plot off-screen and return its grob tree
#'
#' `grid.echo()` comes from gridGraphics, which reaches this package only as
#' a transitive dependency, so it is skipped rather than assumed -- the same
#' line `spine_grobs()` draws in `test-base-r-spineplot.R`.
cdplot_grobs <- function(x, y) {
  if (!requireNamespace("gridGraphics", quietly = TRUE)) {
    return(NULL)
  }
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path, width = 7, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  grDevices::dev.control("enable")
  graphics::cdplot(x, y)
  tryCatch(
    {
      suppressMessages(gridGraphics::grid.echo())
      grid::grid.grab()
    },
    error = function(e) NULL
  )
}

#' The layer a recorded `cdplot()` argument list produces
processed <- function(args, gt = NULL) {
  info <- list(plot_call = list(args = args), group_index = 1)
  BaseRCdplotLayerProcessor$new(info)$process(
    NULL, NULL, NULL, gt, NULL, NULL, NULL, info
  )
}

#' Each band's name, bottom to top
band_names <- function(layer) {
  vapply(layer$data, function(series) series[[1]]$z, character(1))
}

#' The shares of every band at one x, in band order
column <- function(layer, index) {
  vapply(layer$data, function(series) series[[index]]$y, numeric(1))
}

test_that("a cdplot is read as a normalized stacked area", {
  layer <- processed(list(x = SCORE, y = GRADE))

  expect_equal(layer$type, "stacked_normalized_area")
  expect_length(layer$data, nlevels(GRADE))
})

test_that("every column of bands sums to one", {
  layer <- processed(list(x = SCORE, y = GRADE))

  totals <- vapply(
    seq_along(layer$data[[1]]),
    function(i) sum(column(layer, i)),
    numeric(1)
  )

  expect_equal(totals, rep(1, length(totals)))
})

test_that("no band is announced with a negative share", {
  layer <- processed(list(x = SCORE, y = GRADE))

  shares <- unlist(lapply(layer$data, function(series) {
    vapply(series, function(point) point$y, numeric(1))
  }))

  expect_true(all(shares >= 0))
})

test_that("the bands are named bottom to top, in the order cdplot draws them", {
  # `cdplot()` reverses the factor's levels before drawing, so the first
  # level is the *top* band. A reading that followed `levels()` would name
  # every band after the one drawn opposite it.
  layer <- processed(list(x = SCORE, y = GRADE))

  expect_equal(band_names(layer), rev(levels(GRADE)))
})

test_that("a two-level factor is read as two bands", {
  layer <- processed(list(x = SCORE, y = PASSED))

  expect_equal(band_names(layer), rev(levels(PASSED)))
})

test_that("ylevels reorders the bands, and the reading follows", {
  layer <- processed(list(x = SCORE, y = GRADE, ylevels = c("b", "a", "c")))

  # `cdplot()` takes `rev(ylevels)` as its drawing order.
  expect_equal(band_names(layer), c("c", "a", "b"))
})

test_that("the announced grid is the one that was drawn, not the padded one", {
  # `density()` runs three bandwidths past the data at each end and
  # `cdplot()` trims that off. Announcing the untrimmed grid would put
  # readings either side of the data, where the chart has no marks.
  layer <- processed(list(x = SCORE, y = GRADE))

  xs <- vapply(layer$data[[1]], function(point) point$x, numeric(1))

  expect_gte(min(xs), min(SCORE))
  expect_lte(max(xs), max(SCORE))
  expect_lt(length(xs), 512)
})

test_that("every band is announced over the same grid", {
  layer <- processed(list(x = SCORE, y = GRADE))

  grids <- lapply(layer$data, function(series) {
    vapply(series, function(point) point$x, numeric(1))
  })

  expect_equal(grids[[2]], grids[[1]])
  expect_equal(grids[[3]], grids[[1]])
})

test_that("the formula form reads the same chart", {
  frame <- data.frame(score = SCORE, grade = GRADE)

  direct <- processed(list(x = SCORE, y = GRADE))
  formula <- processed(list(grade ~ score, data = frame))

  expect_equal(band_names(formula), band_names(direct))
  expect_equal(column(formula, 1), column(direct, 1))
})

test_that("a formula call names its axes from the model frame", {
  # `cdplot.formula` labels its axes with `names(mf)`, which is the one form
  # of the call where the variables' names survive into the recording.
  frame <- data.frame(score = SCORE, grade = GRADE)

  layer <- processed(list(grade ~ score, data = frame))

  expect_equal(layer$axes$x$label, "score")
  expect_equal(layer$axes$z$label, "grade")
})

test_that("the band's number is named on y and the factor on z", {
  # The drawn y axis carries the level names -- the fill dimension, shown
  # positionally -- so `ylab` names `z`, and `y` says what its numbers are.
  layer <- processed(list(x = SCORE, y = GRADE, xlab = "score", ylab = "grade"))

  expect_equal(layer$axes$x$label, "score")
  expect_equal(layer$axes$y$label, "Proportion")
  expect_equal(layer$axes$z$label, "grade")
})

test_that("a written label wins over the model frame's name", {
  frame <- data.frame(score = SCORE, grade = GRADE)

  layer <- processed(list(grade ~ score, data = frame, xlab = "Exam score"))

  expect_equal(layer$axes$x$label, "Exam score")
})

test_that("a call with no labels leaves the axes to the renderer", {
  # `cdplot()` deparses the caller's expressions for its defaults and the
  # wrapper records evaluated values, so there is no name to offer.
  layer <- processed(list(x = SCORE, y = GRADE))

  expect_null(layer$axes$x)
  expect_null(layer$axes$z)
  expect_equal(layer$axes$y$label, "Proportion")
})

test_that("the title is the one the call was given", {
  layer <- processed(list(x = SCORE, y = GRADE, main = "Grades by score"))

  expect_equal(layer$title, "Grades by score")
})

test_that("a call with no title is announced without one", {
  expect_equal(processed(list(x = SCORE, y = GRADE))$title, "")
})

test_that("each band is addressed by the polygon that drew it", {
  grobs <- cdplot_grobs(SCORE, GRADE)
  skip_if(is.null(grobs), "grid.echo unavailable")

  layer <- processed(list(x = SCORE, y = GRADE), grobs)

  expect_equal(
    unlist(layer$selectors),
    c(
      "#graphics-plot-1-polygon-1\\.1 polygon",
      "#graphics-plot-1-polygon-2\\.1 polygon",
      "#graphics-plot-1-polygon-3\\.1 polygon"
    )
  )
})

test_that("the frame around the plot is not collected as a band", {
  # `cdplot()` draws a box, which is a polygon too. gridGraphics names it
  # `-box-1`, and an unanchored pattern would take it for a fourth band and
  # withhold every selector.
  grobs <- cdplot_grobs(SCORE, GRADE)
  skip_if(is.null(grobs), "grid.echo unavailable")

  expect_length(processed(list(x = SCORE, y = GRADE), grobs)$selectors, 3)
})

test_that("selectors are withheld when the polygon count disagrees", {
  # A partial list hands a band its neighbour's element, which a reader
  # cannot tell apart from a correct one.
  two <- grid::grobTree(
    grid::polygonGrob(name = "graphics-plot-1-polygon-1"),
    grid::polygonGrob(name = "graphics-plot-1-polygon-2")
  )

  expect_length(processed(list(x = SCORE, y = GRADE), two)$selectors, 0)
})

test_that("a chart with no grob tree is announced without selectors", {
  layer <- processed(list(x = SCORE, y = GRADE))

  expect_length(layer$selectors, 0)
  expect_length(layer$data, 3)
})

test_that("a plot argument the caller wrote does not displace ours", {
  # `c(args, list(plot = FALSE))` would leave two `plot`s in the call, and a
  # positional one would then be matched against `tol.ylab` instead.
  layer <- processed(list(x = SCORE, y = GRADE, plot = TRUE))

  expect_equal(band_names(layer), rev(levels(GRADE)))
})

test_that("a call that cannot be replayed is announced as nothing", {
  # `cdplot()` requires a factor and stops otherwise. The layer then carries
  # no data and the figure keeps the static image it produces today.
  layer <- processed(list(x = SCORE, y = SCORE))

  expect_length(layer$data, 0)
  expect_length(layer$selectors, 0)
})

test_that("an empty recorded call is announced as nothing", {
  expect_length(processed(list())$data, 0)
})

test_that("a layer with no recorded call is announced as nothing", {
  info <- list(plot_call = NULL, group_index = 1)
  layer <- BaseRCdplotLayerProcessor$new(info)$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, info
  )

  expect_length(layer$data, 0)
  expect_equal(layer$title, "")
  expect_equal(layer$axes$y$label, "Proportion")
})

test_that("the adapter types a cdplot call as a conditional density", {
  adapter <- BaseRAdapter$new()

  expect_equal(
    adapter$detect_layer_type(list(function_name = "cdplot", args = list())),
    "conditional_density"
  )
})

test_that("the factory builds a cdplot processor for that type", {
  info <- list(plot_call = list(args = list()), group_index = 1)

  processor <- BaseRProcessorFactory$new()$create_processor(
    "conditional_density", info
  )

  expect_s3_class(processor, "BaseRCdplotLayerProcessor")
  expect_true("conditional_density" %in%
    BaseRProcessorFactory$new()$get_supported_types())
})

test_that("a subset call is read over the range the subset drew", {
  # `cdplot.formula` builds its model frame with `subset`, so everything
  # downstream is the subset's. Read without it, the grid would be trimmed to
  # the whole column's range and a fifth of the announced points would sit
  # left of the leftmost mark.
  frame <- data.frame(score = SCORE, grade = GRADE)
  cut <- stats::quantile(SCORE, 0.4)

  layer <- processed(list(grade ~ score, data = frame, subset = SCORE > cut))

  xs <- vapply(layer$data[[1]], function(point) point$x, numeric(1))
  expect_gte(min(xs), min(SCORE[SCORE > cut]))
  expect_gt(min(xs), min(SCORE))
})

test_that("an ylevels naming a strict subset is declined", {
  # Two levels left over rather than one, so the top band cannot be named --
  # and a reading missing a band would give every selector after it its
  # neighbour's element.
  layer <- processed(list(x = SCORE, y = GRADE, ylevels = c("a", "b")))

  expect_length(layer$data, 0)
})

test_that("a level with an empty name is still announced", {
  # An empty level name is a level like any other and the chart draws a band
  # for it, so it is announced with the name the axis shows rather than
  # dropped.
  blank <- factor(ifelse(SCORE > 50, "", "b"), levels = c("b", ""))

  layer <- processed(list(x = SCORE, y = blank))

  expect_equal(band_names(layer), c("", "b"))
})
