# A base R `dotchart()` fell back to a picture (#237).
#
# `dotchart` is classified HIGH, so its calls are recorded, but the adapter
# had no branch for it and the factory no processor -- which is the
# documented decline: the figure takes the static-image path with a "Plot
# contains unsupported elements" warning. Not a wrong reading, but a whole
# chart unread, and MAIDR has had `TraceType.DOT` for exactly this shape
# since xability/maidr#792.
#
# A Cleveland dot plot is a bar chart's reading with a different mark, which
# is what the core builds `DOT` on. Two things have to be right beyond the
# values:
#
#   * `orientation = "horz"`, because `dotchart()` puts the categories on the
#     vertical axis. The core reads a `horz` layer's magnitude from `x` and
#     its category from `y`; without the key the layer defaults to vertical
#     and reads the category name where the magnitude belongs, which is #184
#     and #480 in one.
#   * only the one-value-per-category form. A grouped `dotchart()` draws
#     every group's dots into one shared grob with a header per group in the
#     left margin, and a flat `dot` layer has nowhere to carry the grouping.

dot_layers <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      if (maidr:::has_device_calls(device_id)) {
        maidr:::clear_device_storage(device_id)
      }
      grDevices::dev.off()
    },
    add = TRUE
  )
  if (maidr:::has_device_calls(device_id)) {
    maidr:::clear_device_storage(device_id)
  }
  draw()
  schema <- maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
  schema$subplots[[1]][[1]]$layers
}

dot_types <- function(draw) {
  vapply(dot_layers(draw), function(layer) layer$type, character(1))
}

FRUIT <- local({
  v <- c(30, 70, 50, 20)
  names(v) <- c("apple", "banana", "cherry", "date")
  v
})

GROUPED <- matrix(
  c(1, 2, 3, 4, 5, 6),
  nrow = 3,
  dimnames = list(c("a", "b", "c"), c("g1", "g2"))
)

test_that("a base R dot chart is read rather than pictured", {
  testthat::expect_equal(dot_types(function() dotchart(FRUIT)), "dot")
})

test_that("a dot chart says which way round it is", {
  # The key and the arrangement are one answer. `horz` over a vertical
  # payload is the combination #184 was about, so this and the field test
  # below have to move together.
  layer <- dot_layers(function() dotchart(FRUIT))[[1]]

  testthat::expect_equal(layer$orientation, "horz")
})

test_that("a dot chart puts the measure in x and the category in y", {
  # What `horz` means to the core. Reading the fields positionally would pass
  # on a layer that had the pair backwards, so this names them outright.
  first <- dot_layers(function() dotchart(FRUIT))[[1]]$data[[1]]

  testthat::expect_type(first$x, "double")
  testthat::expect_type(first$y, "character")
  testthat::expect_equal(first$x, 30)
  testthat::expect_identical(first$y, "apple")
})

test_that("a dot chart carries every value the call was given", {
  points <- dot_layers(function() dotchart(FRUIT))[[1]]$data

  testthat::expect_equal(vapply(points, function(p) p$x, 0), unname(FRUIT))
  testthat::expect_identical(
    vapply(points, function(p) p$y, ""),
    names(FRUIT)
  )
})

test_that("explicit labels win over the vector's names", {
  # `dotchart(x, labels = ...)` is how a caller names an unnamed vector, and
  # how they rename a named one. The margin shows the labels either way, so
  # that is what the reader has to be told.
  layer <- dot_layers(function() {
    dotchart(FRUIT, labels = c("one", "two", "three", "four"))
  })[[1]]

  testthat::expect_identical(
    vapply(layer$data, function(p) p$y, ""),
    c("one", "two", "three", "four")
  )
})

test_that("an unnamed vector is still navigable", {
  # Base R draws it against a blank margin. Positions are not labels, but a
  # reader with nothing at all cannot tell one dot from the next.
  layer <- dot_layers(function() dotchart(c(5, 9, 2)))[[1]]

  testthat::expect_identical(
    vapply(layer$data, function(p) p$y, ""),
    c("1", "2", "3")
  )
})

test_that("a grouped dot chart is declined rather than flattened", {
  # Every group's dots land in one points grob with a header per group in
  # the left margin. Read flat, the reader gets one run of six dots with
  # nothing to say where g1 ends and g2 begins, and the group names dropped
  # entirely -- worse than the picture it falls back to today.
  # No layer at all, which is what "unknown" produces: the type never
  # reaches the schema, it routes the figure to the static-image fallback
  # (#176). Asserted on the adapter as well, so a call that yielded nothing
  # for some *other* reason could not pass this.
  testthat::expect_length(dot_types(function() dotchart(GROUPED)), 0)
  testthat::expect_length(
    dot_types(function() dotchart(c(1, 2, 3), groups = factor(c("a", "a", "b")))),
    0
  )

  adapter <- maidr:::BaseRAdapter$new()
  declines <- function(args) {
    adapter$detect_layer_type(list(function_name = "dotchart", args = args))
  }

  testthat::expect_equal(declines(list(GROUPED)), "unknown")
  testthat::expect_equal(
    declines(list(c(1, 2, 3), groups = factor(c("a", "a", "b")))),
    "unknown"
  )
  testthat::expect_equal(declines(list(FRUIT)), "dot")
})

test_that("a scatter is unchanged", {
  # The control. A dot chart's marks are addressed through the same points
  # grob a scatter's are, so this shares `BaseRPointLayerProcessor` -- and a
  # change made one level too high would show up here.
  layer <- dot_layers(function() plot(1:4, FRUIT))[[1]]

  testthat::expect_equal(layer$type, "point")
  testthat::expect_null(layer$orientation)
  testthat::expect_equal(layer$data[[1]]$x, 1)
  testthat::expect_equal(layer$data[[1]]$y, 30)
})

test_that("a dot chart addresses the dots it drew", {
  # Measured on the rendered chart: `dotchart` draws its marks into
  # `graphics-plot-1-points-1`, the same grob a scatter uses, and the group
  # this names held 4 `<use>` elements for 4 dots. The guide lines
  # (`-abline-h-`) and the margin labels (`-mtext-left-`) are frame, and
  # neither is addressed.
  selectors <- dot_layers(function() dotchart(FRUIT))[[1]]$selectors

  testthat::expect_equal(
    unlist(selectors),
    "g#graphics-plot-1-points-1\\.1 > use"
  )
})
