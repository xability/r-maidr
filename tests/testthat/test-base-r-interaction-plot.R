# `interaction.plot()` drew a multi-line chart that nothing read (#278)
#
# It is recorded -- `save_html()` succeeds rather than reporting "No Base R
# plots detected", which #262 fixed -- but `detect_layer_type()` had no branch
# for it, so it fell through to `unknown` and the chart came out as a static
# image with "Plot contains unsupported elements".
#
# What it draws is not new. `stats::interaction.plot` computes
#
#   cells <- tapply(response, list(x.factor, trace.factor), fun)
#
# and hands the matrix to `matplot`, which is the shape the line processor
# already reads: one series per column, each point carrying its column name
# as `z`. So the reading recomputes `cells` and reuses that extraction, and
# these tests are about the numbers landing where the drawing put them and
# about the three deparsed labels, which are the part that is genuinely new.

interaction_layers <- base_r_layers
interaction_types <- base_r_layer_types

DOSE <- factor(
  rep(c("low", "mid", "high"), each = 4),
  levels = c("low", "mid", "high")
)
SUPP <- factor(rep(c("VC", "OJ"), 6))
GROWTH <- c(4, 8, 9, 13, 15, 17, 20, 22, 25, 29, 30, 34)

# The grid `interaction.plot` itself computes, kept here so the expectations
# below are the drawing's numbers rather than restatements of the code:
#
#        OJ   VC
#   low  10.5  6.5
#   mid  19.5 17.5
#   high 31.5 27.5

series_of <- function(layer, index) {
  vapply(layer$data[[index]], function(point) point$y, numeric(1))
}

labels_of <- function(layer, index) {
  vapply(layer$data[[index]], function(point) point$x, character(1))
}

groups_of <- function(layer, index) {
  vapply(layer$data[[index]], function(point) point$z, character(1))
}

test_that("an interaction plot is read rather than falling back to a picture", {
  expect_equal(
    interaction_types(function() interaction.plot(DOSE, SUPP, GROWTH)),
    "line"
  )
})

test_that("the call routes to the processor that recomputes the cell means", {
  # The name the adapter types it as and the name the factory answers to have
  # to be the same string, and the registry has to list it: a type the factory
  # builds but does not claim is refused by `supports_plot_type()` before the
  # processor is ever reached (#200, #214).
  adapter <- BaseRAdapter$new()

  expect_equal(
    adapter$detect_layer_type(
      list(function_name = "interaction.plot", args = list())
    ),
    "interaction"
  )

  factory <- BaseRProcessorFactory$new()
  expect_true("interaction" %in% factory$get_supported_types())
  expect_s3_class(
    factory$create_processor("interaction", list(plot_call = list(args = list()))),
    "BaseRInteractionLayerProcessor"
  )
})

test_that("each trace level is its own series of cell means", {
  layer <- interaction_layers(
    function() interaction.plot(DOSE, SUPP, GROWTH)
  )[[1]]

  expect_length(layer$data, 2)
  expect_equal(series_of(layer, 1), c(10.5, 19.5, 31.5))
  expect_equal(series_of(layer, 2), c(6.5, 17.5, 27.5))
})

test_that("every point says which trace it belongs to", {
  # Without it the two lines are one undifferentiated set of six readings,
  # and which supplement a mean belongs to is the whole point of the chart.
  layer <- interaction_layers(
    function() interaction.plot(DOSE, SUPP, GROWTH)
  )[[1]]

  expect_equal(groups_of(layer, 1), rep("OJ", 3))
  expect_equal(groups_of(layer, 2), rep("VC", 3))
})

test_that("the x positions are named by the factor's levels, in its own order", {
  layer <- interaction_layers(
    function() interaction.plot(DOSE, SUPP, GROWTH)
  )[[1]]

  # `low, mid, high` rather than the alphabetical `high, low, mid`: the
  # drawing walks the factor's levels, and a reader told otherwise would
  # hear a rising dose as a jumbled one.
  expect_equal(labels_of(layer, 1), c("low", "mid", "high"))
})

test_that("the axes are named the way the drawing names them", {
  layer <- interaction_layers(
    function() interaction.plot(DOSE, SUPP, GROWTH)
  )[[1]]

  # All three of `interaction.plot`'s defaults are
  # `deparse1(substitute(...))`, so they name the expression the caller
  # wrote -- recovered from the recorded call text, since the wrapper stores
  # evaluated values and a factor's levels are not its name. The double
  # space in the y label is the function's own: it pastes "of " onto a
  # separator.
  expect_equal(layer$axes$x$label, "DOSE")
  expect_equal(layer$axes$y$label, "mean of  GROWTH")
  expect_equal(layer$axes$z$label, "SUPP")
})

test_that("an explicit label wins over the deparsed default", {
  layer <- interaction_layers(function() {
    interaction.plot(
      DOSE, SUPP, GROWTH,
      xlab = "Dose", ylab = "Mean growth", trace.label = "Supplement"
    )
  })[[1]]

  expect_equal(layer$axes$x$label, "Dose")
  expect_equal(layer$axes$y$label, "Mean growth")
  expect_equal(layer$axes$z$label, "Supplement")
})

test_that("a non-default summary is the one the series carry", {
  layer <- interaction_layers(
    function() interaction.plot(DOSE, SUPP, GROWTH, fun = max)
  )[[1]]

  # `fun` is what the chart plots; reading the means of a chart drawn from
  # maxima would announce numbers that are nowhere on it.
  expect_equal(series_of(layer, 1), c(13, 22, 34))
  expect_equal(layer$axes$y$label, "max of  GROWTH")
})

test_that("the marks the type draws do not change the reading", {
  # `type = "p"` draws points instead of lines, over the same cell means in
  # the same two series. Reading it as loose points would drop the trace
  # grouping that makes it an interaction plot.
  for (mark in c("l", "p", "b")) {
    layer <- interaction_layers(function() {
      interaction.plot(DOSE, SUPP, GROWTH, type = mark)
    })[[1]]

    expect_equal(series_of(layer, 1), c(10.5, 19.5, 31.5), info = mark)
    expect_equal(groups_of(layer, 2), rep("VC", 3), info = mark)
  }
})

test_that("a chart with one trace level is still one series", {
  layer <- interaction_layers(function() {
    interaction.plot(DOSE, factor(rep("only", 12)), GROWTH)
  })[[1]]

  expect_length(layer$data, 1)
  expect_equal(groups_of(layer, 1), rep("only", 3))
})

test_that("a cell no observation falls in has no value rather than a zero", {
  # `tapply` returns NA for an empty cell, and the chart draws a gap there.
  # A zero would be a mean the data never produced.
  layer <- interaction_layers(function() {
    interaction.plot(
      factor(c("a", "a", "b")),
      factor(c("x", "y", "x")),
      c(1, 2, 3)
    )
  })[[1]]

  # b/y is empty: no observation is both.
  expect_true(is.na(series_of(layer, 2)[[2]]))
})
