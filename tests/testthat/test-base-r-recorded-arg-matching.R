# A recorded argument is looked up by name, and `$` on a list partial-matches
# (#245).
#
# Every Base R processor resolving its data with `args$x` was asking for an
# element named `x`, and R hands back `xlab` when there is no exact `x`:
#
#   args <- list(c(a = 1, b = 2), xlab = "Value")
#   args$x      #> "Value"
#   args[["x"]] #> NULL
#
# `match_recorded_args()` deliberately leaves the dispatch argument exactly
# as the user wrote it, so a positional first argument stays unnamed and the
# partial match is what a lookup finds. `dotchart(v, xlab = "Value")` read
# "Value" as its values, `is.numeric()` rejected it, and the chart rendered
# with a `dot` layer holding no points -- typed, titled, and empty.
#
# `resolve_xy_args()` already existed for this: exact `args[["x"]]`, then the
# first *unnamed* argument. These tests drive the arguments that trip the
# partial match rather than the helper, so a site that goes back to `args$x`
# fails here.

# `base_r_layers` and `base_r_layer_types` live in `helper.R` (#241).
arg_layers <- base_r_layers
arg_types <- base_r_layer_types

FRUIT <- local({
  v <- c(30, 70, 50, 20)
  names(v) <- c("apple", "banana", "cherry", "date")
  v
})

test_that("a dot chart given an xlab still reads its values", {
  # The reported case. `xlab` is the ordinary way to name that axis, so this
  # is not an exotic call -- it is the documented one.
  layer <- arg_layers(function() dotchart(FRUIT, xlab = "Value"))[[1]]

  testthat::expect_length(layer$data, 4)
  testthat::expect_equal(
    vapply(layer$data, function(p) p$x, 0),
    unname(FRUIT)
  )
})

test_that("the xlab the values were nearly mistaken for is still the title", {
  # The fix must not read past the argument to reach the data: the author's
  # `xlab` is what names the axis, and losing it would trade one silent
  # failure for another.
  axes <- arg_layers(function() dotchart(FRUIT, xlab = "Value"))[[1]]$axes

  testthat::expect_equal(axes$x$label, "Value")
})

test_that("any x-prefixed argument leaves the values alone", {
  # `xlab` is the common one, but the partial match fires for whatever the
  # caller writes -- so this names a second one rather than resting on the
  # first. `xlim` reaches the drawing, not the data.
  layer <- arg_layers(function() dotchart(FRUIT, xlim = c(0, 100)))[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(p) p$x, 0),
    unname(FRUIT)
  )
})

test_that("two x-prefixed arguments leave the values alone", {
  # The failure was not uniform: two candidates make the partial match
  # ambiguous and `$` returns NULL, which fell through to the positional
  # branch and read correctly by accident. A chart's correctness should not
  # depend on how many arguments the author happened to write.
  layer <- arg_layers(function() {
    dotchart(FRUIT, xlab = "Value", xlim = c(0, 100))
  })[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(p) p$x, 0),
    unname(FRUIT)
  )
})

test_that("a dot chart with no x-prefixed argument is unchanged", {
  # The control. Everything above has to be a statement about `xlab`, not
  # about dot charts, so the plain call is asserted alongside it.
  layer <- arg_layers(function() dotchart(FRUIT))[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(p) p$x, 0),
    unname(FRUIT)
  )
})

test_that("a named x argument still wins over a positional one", {
  # `resolve_xy_args()` prefers an exact `x`, which is the arrangement the
  # partial match was standing in for. Spelling it out keeps the fix from
  # being read as "always take the first argument".
  layer <- arg_layers(function() dotchart(x = FRUIT, xlab = "Value"))[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(p) p$x, 0),
    unname(FRUIT)
  )
})

test_that("a grouped dot chart given an xlab is still declined", {
  # The decline reads the same argument. Under the partial match it saw
  # "Value", which is neither a matrix nor a data frame, so a grouped chart
  # with an `xlab` was accepted and then read as an empty flat layer --
  # the two halves of the bug meeting.
  adapter <- maidr:::BaseRAdapter$new()
  grouped <- matrix(
    c(1, 2, 3, 4, 5, 6),
    nrow = 3,
    dimnames = list(c("a", "b", "c"), c("g1", "g2"))
  )

  testthat::expect_equal(
    adapter$detect_layer_type(list(
      function_name = "dotchart",
      args = list(grouped, xlab = "Value")
    )),
    "unknown"
  )
  testthat::expect_equal(
    adapter$detect_layer_type(list(
      function_name = "dotchart",
      args = list(FRUIT, xlab = "Value")
    )),
    "dot"
  )
})

test_that("resolve_xy_args does not partial-match", {
  # The helper the sites now go through, asserted directly: the property
  # every one of them depends on, in one line, so a change to the helper
  # names itself here rather than as four unrelated chart failures.
  args <- list(c(a = 1, b = 2), xlab = "Value")

  testthat::expect_identical(args$x, "Value")
  testthat::expect_identical(maidr:::resolve_xy_args(args)$x, c(a = 1, b = 2))
})
