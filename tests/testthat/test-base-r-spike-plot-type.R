# `plot(type = "h")` was announced as a line chart of its values (#239).
#
# `type = "h"` draws a vertical from the baseline to each value and joins
# nothing to anything. Announced as a `line` layer it read identically to
# `type = "l"`:
#
#   type=h    line    n=6   (1,3) (2,5) (3,2) ...
#   type=l    line    n=6   (1,3) (2,5) (3,2) ...
#
# The values were right, so nothing read as broken. What was wrong is the
# relationship: a line tells the reader the samples are joined and that the
# space between them can be interpolated, which is the one thing a spike
# chart is drawn to deny. The same class of loss #413 was about for a stepped
# area -- the numbers survive and the shape does not.
#
# Read as `lollipop`, which the core builds on `BarTrace`: one value per
# position, no claim about the space between two of them. The marker head a
# lollipop conventionally carries is the only difference from what base R
# draws, and it is not something a reader hears.

# `base_r_layers` and `base_r_layer_types` live in `helper.R` (#241). The
# local names stay so the tests read in this file's own words.
spike_layers <- base_r_layers
spike_types <- base_r_layer_types

X <- 1:6
Y <- c(3, 5, 2, 8, 4, 6)

# A line layer's `data` is a list of *series*; a bar-shaped layer's is one
# point per position. Reported separately so a reading at the wrong depth
# cannot pass by having the right point count one level down.
shape_of <- function(layer) {
  points <- layer$data
  nested <- length(points) > 0 &&
    is.list(points[[1]]) &&
    is.null(names(points[[1]]))
  list(nested = nested, n = length(if (nested) points[[1]] else points))
}

test_that("a base R spike chart is not announced as a line", {
  testthat::expect_equal(spike_types(function() plot(X, Y, type = "h")), "lollipop")
})

test_that("the spike type is read positionally too", {
  # `plot(x, y, "h")` is the same call written without the argument name, and
  # the third positional argument is `type`.
  testthat::expect_equal(spike_types(function() plot(X, Y, "h")), "lollipop")
})

test_that("a spike layer carries one point per sample, not one series", {
  # The half a check on the type alone would not catch. A `lollipop` layer
  # shipped in the line layer's nested shape puts every value one level too
  # deep, and the frontend then reads the whole chart as a single point.
  layer <- spike_layers(function() plot(X, Y, type = "h"))[[1]]
  shape <- shape_of(layer)

  testthat::expect_false(shape$nested)
  testthat::expect_equal(shape$n, length(Y))
})

test_that("a spike layer's values are the call's own", {
  points <- spike_layers(function() plot(X, Y, type = "h"))[[1]]$data

  testthat::expect_equal(vapply(points, function(p) as.numeric(p$y), 0), Y)
  testthat::expect_equal(
    vapply(points, function(p) as.character(p$x), ""),
    as.character(X)
  )
})

test_that("a spike layer addresses the spikes gridSVG actually drew", {
  # gridGraphics names the grob after what drew it, so the verticals land
  # under `-spike-` and never under the `-lines-` name the inherited line
  # search looks for. A layer that emits no selector loses its highlighting
  # entirely, which is what #145 was about for error bars.
  #
  # Measured on the rendered chart: the group this names holds six
  # `<polyline>` elements, one per point, in data order --
  # `graphics-plot-1-spike-1.1.1` at x=74.4 through `...1.1.6` at x=458.4.
  selectors <- spike_layers(function() plot(X, Y, type = "h"))[[1]]$selectors

  testthat::expect_equal(
    unlist(selectors),
    "#graphics-plot-1-spike-1\\.1 polyline"
  )
})

test_that("spikes drawn over a chart are their own layer", {
  # `lines(type = "h")` runs the same ladder, so an overlay reads as the
  # shape it draws rather than as a plain line -- and the chart underneath
  # keeps its own reading.
  types <- spike_types(function() {
    plot(X, Y)
    lines(X, Y, type = "h")
  })

  testthat::expect_equal(types, c("point", "lollipop"))
})

test_that("every other plot type is untouched", {
  # The control. `h` sits in a ladder with `n`, the step types and the
  # catch-all, so a test that claimed too much would show up here rather
  # than in a chart nobody ran.
  testthat::expect_equal(spike_types(function() plot(X, Y, type = "l")), "line")
  testthat::expect_equal(spike_types(function() plot(X, Y, type = "p")), "point")
  testthat::expect_equal(spike_types(function() plot(X, Y, type = "b")), "point")
  testthat::expect_equal(spike_types(function() plot(X, Y, type = "o")), "line")
  testthat::expect_equal(spike_types(function() plot(X, Y, type = "s")), "step")
  testthat::expect_equal(spike_types(function() plot(X, Y, type = "S")), "step")
})

test_that("a line layer keeps its series shape", {
  # The other half of the control above: `lollipop` had to flatten, and
  # `line` had to not. Both readings come from one extraction, so a flatten
  # applied a level too high would pass every type check and break every
  # line chart.
  shape <- shape_of(spike_layers(function() plot(X, Y, type = "l"))[[1]])

  testthat::expect_true(shape$nested)
  testthat::expect_equal(shape$n, length(Y))
})

test_that("the spike test is case-sensitive", {
  # `plot()` has no `"H"`, and the step test beside this one distinguishes
  # `"s"` from `"S"` -- so a case-insensitive match here would be a claim
  # about a type base R does not have.
  testthat::expect_true(maidr:::is_spike_plot_type("h"))
  testthat::expect_false(maidr:::is_spike_plot_type("H"))
  testthat::expect_false(maidr:::is_spike_plot_type("l"))
  testthat::expect_false(maidr:::is_spike_plot_type(NULL))
  testthat::expect_false(maidr:::is_spike_plot_type(character(0)))
})
