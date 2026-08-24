# A base R strip chart fell back to a picture (#251).
#
# `stripchart()` is classified HIGH, so its calls were recorded, but the
# adapter had no branch for it and the factory no processor, and the figure
# took the static-image path. It is a scatter of one dimension -- every
# observation as its own mark, laid along a value axis at its group's
# position -- and MAIDR has read scatters all along.
#
# **One layer per group, and the drawing decides that, not tidiness.**
# Measured on a three-group chart, gridGraphics exports one `points` grob per
# group:
#
#     graphics-plot-1-points-1     5 observations
#     graphics-plot-1-points-2     4
#     graphics-plot-1-points-3     2
#
# and `find_graphics_plot_grob()` answers with the first match, so a single
# layer would announce all eleven observations and highlight only the first
# group's five. Every emitted selector was resolved against a real
# `save_html()` rendering in Chromium: `g#graphics-plot-1-points-N\.1 > use`
# matched 5, 4 and 2 elements respectively -- one per observation, correctly
# partitioned.
#
# **The groups are read, not re-derived.** `stripchart` forms them in two
# places, and both are called rather than imitated:
#
#     stripchart.default   groups <- if (is.list(x)) x
#                                    else if (is.numeric(x)) list(x)
#     stripchart.formula   split(mf[[response]], mf[-response])
#
# A formula with no `data =` is read too, and the first shape of this reading
# refused it on the theory that the caller's environment was gone. It is not:
# a formula carries the environment it was written in and the recorded call
# holds the formula, so `model.frame()` resolves the variables exactly as
# `stripchart.formula` did when it drew them. Measured with the variables
# local to a function, global, and in a closure whose call had returned --
# all three read back the drawn groups and values.
#
# What that inherits is a late lookup: rebinding the variables between the
# drawing and the rendering makes the payload follow the new bindings. That
# is #254, it belongs to every recorded formula in the package rather than to
# this processor, and the case below pins the current behaviour so the day it
# is fixed the case turns red.
#
# **The inherited axis helper had to go.** `BaseRPointLayerProcessor` reads a
# call's recorded `x` as a pair of coordinates, and on a stripchart that is
# wrong in both directions at once. Measured on
# `stripchart(c(3.1, 4.2, 5.0, 2.2, 6.9))` before the override:
#
#     announced   x  1 .. 5        y  2 .. 7
#     drawn       x  2.2 .. 6.9    y  one group, at 1
#
# -- the value range offered on the group axis, and a bare index on the value
# axis. A stripchart is one categorical axis against one measured axis, the
# shape `boxplot()` and `barplot()` draw, so it is named by the same helper.
#
# **`method = "jitter"` is not a reading problem here**, which is worth a case
# because it is one for `geom_jitter()` (#174). A stripchart jitters along the
# *group* axis only, so every number announced is the observation itself.

# `base_r_layers` and `base_r_layer_types` live in `helper.R` (#241).
strip_types <- base_r_layer_types
strip_layers <- base_r_layers

# Three groups of different sizes, no value repeated across them, and the
# first group deliberately unsorted -- so a reading that sorted, pooled or
# lost its order would show up rather than coincide.
GROUPS <- list(
  First = c(3.1, 4.2, 5.0, 2.2, 6.9),
  Second = c(6.1, 7.2, 8.0, 5.5),
  Third = c(1.1, 9.4)
)

#' The layers a recorded `stripchart()` argument list produces
#'
#' Called on the processor directly, so that one case is one spelling of the
#' call rather than one drawing.
processed <- function(args) {
  info <- list(plot_call = list(args = args), group_index = 1)
  BaseRStripchartLayerProcessor$new(info)$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, info
  )
}

#' One field of every point of a layer
field <- function(layer, name) {
  vapply(layer$data, function(point) point[[name]], layer$data[[1]][[name]])
}

test_that("a stripchart is read rather than pictured", {
  expect_equal(strip_types(function() stripchart(GROUPS)), rep("point", 3))
})

test_that("each group becomes its own layer, in the order drawn", {
  result <- processed(list(GROUPS))

  expect_true(isTRUE(result$multi_layer))
  expect_equal(
    vapply(result$layers, function(l) l$fill, character(1)),
    c("First", "Second", "Third")
  )
  expect_equal(
    vapply(result$layers, function(l) length(l$data), integer(1)),
    c(5L, 4L, 2L)
  )
})

test_that("a group carries its own observations, unsorted and unpooled", {
  layer <- processed(list(GROUPS))$layers[[1]]

  expect_equal(field(layer, "x"), GROUPS$First)
})

test_that("every observation sits at its group's position", {
  layers <- processed(list(GROUPS))$layers

  expect_equal(field(layers[[1]], "y"), rep(1, 5))
  expect_equal(field(layers[[2]], "y"), rep(2, 4))
  expect_equal(field(layers[[3]], "y"), rep(3, 2))
})

test_that("the position travels with the group's name beside it", {
  # `ScatterPoint.x` is typed `number` in the grammar and `ScatterTrace` does
  # arithmetic on it, so the name goes in the label rather than the
  # coordinate -- the lesson of #178.
  layer <- processed(list(GROUPS))$layers[[2]]

  expect_equal(field(layer, "yLabel"), rep("Second", 4))
  expect_type(layer$data[[1]]$y, "double")
})

test_that("a bare vector is the one group stripchart draws it as", {
  result <- processed(list(c(3.1, 4.2, 5.0)))

  expect_equal(length(result$layers), 1)
  expect_equal(field(result$layers[[1]], "x"), c(3.1, 4.2, 5.0))
  expect_equal(result$layers[[1]]$fill, "1")
})

test_that("vertical = TRUE swaps which axis holds the values", {
  layers <- processed(list(GROUPS, vertical = TRUE))$layers

  expect_equal(field(layers[[1]], "y"), GROUPS$First)
  expect_equal(field(layers[[1]], "x"), rep(1, 5))
  expect_equal(field(layers[[1]], "xLabel"), rep("First", 5))
})

test_that("a formula is split by the grouping column it names", {
  layers <- processed(list(len ~ supp, data = ToothGrowth))$layers

  expect_equal(vapply(layers, function(l) l$fill, character(1)), c("OJ", "VC"))
  expect_equal(
    field(layers[[1]], "x"),
    ToothGrowth$len[ToothGrowth$supp == "OJ"]
  )
})

test_that("a formula with no data is read from the environment it was written in", {
  formula <- local({
    len <- c(1, 2, 3, 10, 11, 12)
    supp <- rep(c("OJ", "VC"), each = 3)
    len ~ supp
  })

  layers <- processed(list(formula))$layers

  expect_equal(vapply(layers, function(l) l$fill, character(1)), c("OJ", "VC"))
  expect_equal(field(layers[[1]], "x"), c(1, 2, 3))
  expect_equal(field(layers[[2]], "x"), c(10, 11, 12))
})

test_that("a rebound variable moves the reading with it (#254)", {
  # Pinning the defect rather than asserting it is right: the lookup happens
  # when the chart is read, so a name rebound in between takes the payload
  # with it. Every value and both group names here belong to bindings made
  # after the drawing. Fixing it means snapshotting the model frame while
  # the chart is drawn, which is the recording layer's job -- when that
  # lands, this case fails and is replaced by the drawn values.
  env <- new.env()
  assign("len", c(1, 2, 3, 10, 11, 12), envir = env)
  assign("supp", rep(c("OJ", "VC"), each = 3), envir = env)
  formula <- stats::as.formula("len ~ supp", env = env)

  assign("len", c(99, 98, 97, 96, 95, 94), envir = env)
  assign("supp", rep(c("XX", "YY"), each = 3), envir = env)
  layers <- processed(list(formula))$layers

  expect_equal(vapply(layers, function(l) l$fill, character(1)), c("XX", "YY"))
  expect_equal(field(layers[[1]], "x"), c(99, 98, 97))
})

test_that("a one-sided formula names no groups and is declined", {
  # `stripchart(~ len)` does not draw -- `stripchart.formula` stops with
  # "formula missing or incorrect" -- so this shape cannot be recorded. It
  # is asserted rather than guarded against, because a guard nothing can
  # reach is a branch no test can hold to account.
  formula <- local({
    len <- c(1, 2, 3)
    ~len
  })

  expect_null(processed(list(formula)))
})

test_that("group.names renames the groups the way the axis shows them", {
  layers <- processed(list(GROUPS, group.names = c("L", "M", "R")))$layers

  expect_equal(vapply(layers, function(l) l$fill, character(1)), c("L", "M", "R"))
  expect_equal(field(layers[[1]], "yLabel"), rep("L", 5))
})

test_that("group.names of the wrong length is ignored, as stripchart ignores it", {
  layers <- processed(list(GROUPS, group.names = c("L", "M")))$layers

  expect_equal(vapply(layers, function(l) l$fill, character(1)), names(GROUPS))
})

test_that("at places the groups where the caller put them", {
  layers <- processed(list(GROUPS, at = c(2, 5, 9)))$layers

  expect_equal(field(layers[[1]], "y"), rep(2, 5))
  expect_equal(field(layers[[2]], "y"), rep(5, 4))
  expect_equal(field(layers[[3]], "y"), rep(9, 2))
})

test_that("an at of the wrong length falls back to 1..n", {
  layers <- processed(list(GROUPS, at = c(2, 5)))$layers

  expect_equal(field(layers[[1]], "y"), rep(1, 5))
  expect_equal(field(layers[[3]], "y"), rep(3, 2))
})

test_that("jitter displaces the position, so the values announced are the data", {
  # The distinction from `geom_jitter()` (#174), which displaces both. Here
  # the value axis is untouched and the displaced axis is the one whose name
  # is already carried as a label, so nothing announced is invented.
  jittered <- processed(list(GROUPS, method = "jitter"))$layers[[1]]
  plain <- processed(list(GROUPS))$layers[[1]]

  expect_equal(field(jittered, "x"), GROUPS$First)
  expect_equal(field(jittered, "x"), field(plain, "x"))
})

test_that("each group points at the grob it was drawn into", {
  # Built rather than searched for: `find_graphics_plot_grob()` answers with
  # the first match, and a stripchart draws one `points` grob per group.
  # Resolved in Chromium against a real rendering: 5, 4 and 2 elements.
  layers <- processed(list(GROUPS))$layers

  expect_equal(
    vapply(layers, function(l) l$selectors[[1]], character(1)),
    c(
      "g#graphics-plot-1-points-1\\.1 > use",
      "g#graphics-plot-1-points-2\\.1 > use",
      "g#graphics-plot-1-points-3\\.1 > use"
    )
  )
})

test_that("a second plot in the figure addresses its own grobs", {
  info <- list(plot_call = list(args = list(GROUPS)), group_index = 2)
  layers <- BaseRStripchartLayerProcessor$new(info)$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, info
  )$layers

  expect_equal(layers[[1]]$selectors[[1]], "g#graphics-plot-2-points-1\\.1 > use")
})

test_that("the axes are named for what they hold, and swap when the chart does", {
  horizontal <- processed(list(GROUPS))$layers[[1]]$axes
  vertical <- processed(list(GROUPS, vertical = TRUE))$layers[[1]]$axes

  expect_equal(horizontal, build_axes(x = "Value", y = "Category"))
  expect_equal(vertical, build_axes(x = "Category", y = "Value"))
})

test_that("the caller's own axis titles win", {
  axes <- processed(list(GROUPS, xlab = "Tooth length", ylab = "Supplement"))
  axes <- axes$layers[[1]]$axes

  expect_equal(axes$x$label, "Tooth length")
  expect_equal(axes$y$label, "Supplement")
})

test_that("no range is offered on either axis", {
  # The regression the override exists for. The inherited scatter helper fed
  # the recorded vector to `xy.coords()`, which read it as y and indexed x
  # over `1:5`, announcing x 1..5 and y 2..7 over a chart drawn 2.2..6.9
  # against a single group at 1.
  axes <- processed(list(c(3.1, 4.2, 5.0, 2.2, 6.9)))$layers[[1]]$axes

  expect_equal(names(axes$x), "label")
  expect_equal(names(axes$y), "label")
})

test_that("main titles every layer of the chart", {
  layers <- processed(list(GROUPS, main = "Spread by group"))$layers

  expect_equal(
    vapply(layers, function(l) l$title, character(1)),
    rep("Spread by group", 3)
  )
})

test_that("a non-numeric group is declined rather than coerced", {
  expect_null(processed(list(list(A = c(1, 2), B = c("x", "y")))))
})

test_that("a missing observation is dropped rather than announced", {
  layer <- processed(list(list(A = c(3.1, NA, 5.0))))$layers[[1]]

  expect_equal(field(layer, "x"), c(3.1, 5.0))
})

test_that("a call with nothing to read leaves the chart on the fallback", {
  expect_null(processed(list()))
  expect_null(processed(list(character(0))))
})

test_that("a drawn stripchart reaches the schema with its groups intact", {
  layers <- strip_layers(function() {
    stripchart(GROUPS, main = "Spread", xlab = "Value", ylab = "Group")
  })

  expect_equal(vapply(layers, function(l) l$fill, character(1)), names(GROUPS))
  expect_equal(vapply(layers, function(l) length(l$data), integer(1)), c(5L, 4L, 2L))
  expect_equal(layers[[1]]$axes$x$label, "Value")
  expect_equal(layers[[1]]$title, "Spread")
})
