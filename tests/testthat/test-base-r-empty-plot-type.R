# `plot(type = "n")` draws nothing and was announced as a line (#237)
#
# `type = "n"` means: set up the axes, plot no points and no lines. It is how
# a custom chart is started -- establish the coordinate system, then add the
# marks with `segments`, `polygon` or `rect`.
#
# `base_r_adapter`'s catch-all claimed it as a line, so the panel came out
# carrying the values `plot()` was handed and deliberately did not draw.
# Measured before the fix, on ten observations:
#
#     plot(type='p')    point   n=10  x=[1,2,3,4,5,6] y=[3,5,2,8,4,6]
#     plot(type='l')    line    n=10  x=[1,2,3,4,5,6] y=[3,5,2,8,4,6]
#     plot(type='n')    line    n=10  x=[1,2,3,4,5,6] y=[3,5,2,8,4,6]
#
# A sighted reader sees an empty panel; a MAIDR reader was handed ten points
# to walk and sonify. Worse than being unread, for the reason #572 gives
# about `triplot`: the data is real, the axes are real, and the only false
# thing is the claim that any of it was drawn.
#
# The shapes drawn over such a panel were never the problem -- they
# contribute no layer of their own, which the last case here pins.

X <- 1:10
Y <- c(3, 5, 2, 8, 4, 6, 7, 1, 9, 5)

#' The layers a base R drawing produces, read straight from the orchestrator
#'
#' @param draw A function that draws on the current device
#' @return The layers of the first cell, possibly empty
drawn_layers <- function(draw) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  device_id <- grDevices::dev.cur()
  if (maidr:::has_device_calls(device_id)) {
    maidr:::clear_device_storage(device_id)
  }
  draw()
  schema <- maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
  schema$subplots[[1]][[1]]$layers
}

#' The trace types a base R drawing produces
#'
#' @param draw A function that draws on the current device
#' @return One type per layer, in order
drawn_types <- function(draw) {
  vapply(drawn_layers(draw), function(layer) as.character(layer$type), character(1))
}


test_that("a plot that draws nothing announces nothing", {
  # The whole of #237. Not "reads as an empty line" -- reads as no layer, so
  # the figure falls back to a picture of the empty panel it is.
  expect_length(drawn_types(function() plot(X, Y, type = "n")), 0)
})


test_that("the type is read positionally too", {
  # `plot(x, y, "n")` is the same call. A check that only looked at a named
  # `type =` would leave the commoner spelling announcing a series.
  expect_length(drawn_types(function() plot(X, Y, "n")), 0)
})


test_that("every type that does draw is untouched", {
  # The guard on the change: declining one draw type must not decline its
  # neighbours. These are the readings measured before the fix, unchanged.
  expect_equal(drawn_types(function() plot(X, Y)), "point")
  expect_equal(drawn_types(function() plot(X, Y, type = "p")), "point")
  expect_equal(drawn_types(function() plot(X, Y, type = "l")), "line")
  expect_equal(drawn_types(function() plot(X, Y, type = "b")), "point")
  expect_equal(drawn_types(function() plot(X, Y, type = "o")), "line")
  expect_equal(drawn_types(function() plot(X, Y, type = "s")), "step")
})


test_that("a shape drawn over an empty panel adds no layer of its own", {
  # The half that was already right, and worth pinning: `segments`,
  # `polygon`, `arrows` and `rect` contribute nothing. Every one of them
  # appeared to read as a line in the first sweep, and every one of those
  # readings was the `plot()` call's layer being reported, not the shape's.
  expect_length(
    drawn_types(function() {
      plot(X, Y, type = "n")
      segments(1, 1, 9, 9)
      polygon(c(1, 5, 9), c(1, 9, 1))
      rect(1, 1, 5, 5)
    }),
    0
  )
})


test_that("a shape over a real chart leaves that chart's reading alone", {
  # The same shapes over a scatter: the scatter still reads, and the
  # annotation still adds nothing.
  expect_equal(
    drawn_types(function() {
      plot(X, Y)
      segments(1, 1, 9, 9)
    }),
    "point"
  )
})
