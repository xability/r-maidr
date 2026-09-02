# A recorded formula was resolved at render time, so rebinding its variables
# silently changed the reading (#254).
#
# Base R calls are recorded and read later, at `show()`/`save_html()` time.
# For every argument but one that is harmless, because the wrapper records
# *evaluated values*: a vector recorded is a vector, and rebinding the name
# it came from afterwards changes nothing.
#
# A formula is the exception. It is a reference rather than a value -- it
# carries the environment it was written in -- and the processors that read
# one called `stats::model.frame()` on it at render time, resolving the
# variables *then*. Measured before the fix:
#
#     len  <- c(1, 2, 3, 10, 11, 12); supp <- rep(c("OJ", "VC"), each = 3)
#     stripchart(len ~ supp)              # draws 1,2,3 under OJ
#     len  <- c(99, 98, 97, 96, 95, 94)   # the user carries on working
#     supp <- rep(c("XX", "YY"), each = 3)
#     save_html(file = f)
#
#     announced   fill=XX  values=99,98,97
#     drawn       fill=OJ  values=1,2,3
#
# Every value and both group names belonged to bindings made after the
# drawing, and it was silent: the figure rendered as an interactive chart
# rather than as a fallback, so nothing said the numbers had moved.
#
# Fixed at the **recording** layer rather than per processor, because
# anything that reads a formula later inherits the same defect: the model
# frame is built while the call is being recorded, when the bindings are
# still the ones the chart was drawn from.

snapshot_layers <- base_r_layers

#' Every point of every layer, in order
#'
#' A stripchart emits **one layer per group** (#251), so a reading is only
#' whole when the layers are taken together.
all_points <- function(layers) {
  unlist(lapply(layers, function(layer) layer$data), recursive = FALSE)
}

#' Draw with one set of bindings, rebind, then read
#'
#' The whole point of the test: the two must disagree, and the reading must
#' follow the drawing.
rebind_then_read <- function(draw, rebind) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)

  draw()
  rebind()
  maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
}


test_that("a stripchart reads the data it was drawn from, not what the names now hold", {
  len <- c(1, 2, 3, 10, 11, 12)
  supp <- rep(c("OJ", "VC"), each = 3)

  schema <- rebind_then_read(
    function() stripchart(len ~ supp),
    function() {
      len <<- c(99, 98, 97, 96, 95, 94)
      supp <<- rep(c("XX", "YY"), each = 3)
    }
  )
  points <- all_points(schema$subplots[[1]][[1]]$layers)

  testthat::expect_equal(
    vapply(points, function(point) point$x, 0),
    c(1, 2, 3, 10, 11, 12)
  )
  testthat::expect_equal(
    unique(vapply(points, function(point) point$yLabel, "")),
    c("OJ", "VC")
  )
})


test_that("a rebound data frame does not move the reading either", {
  # The issue notes that declining a formula with no `data =` would not have
  # fixed this: a frame can be rebound just as easily as a loose vector.
  frame <- data.frame(len = c(1, 2, 3, 10, 11, 12),
                      supp = rep(c("OJ", "VC"), each = 3))

  schema <- rebind_then_read(
    function() stripchart(len ~ supp, data = frame),
    function() {
      frame <<- data.frame(len = c(99, 98, 97, 96, 95, 94),
                           supp = rep(c("XX", "YY"), each = 3))
    }
  )
  points <- all_points(schema$subplots[[1]][[1]]$layers)

  testthat::expect_equal(
    vapply(points, function(point) point$x, 0),
    c(1, 2, 3, 10, 11, 12)
  )
})


test_that("a box plot's axis titles survive their variables going away", {
  # The milder half of the same defect -- a stale axis name rather than
  # stale values -- and it has been there since the formula titles landed.
  # `extract_formula_labels()` rebuilds the model frame to read the drawn
  # titles off its column names, so once the formula's variables are gone
  # that rebuild fails and both titles fall back to the generic pair.
  #
  # The formula is built in an environment this test owns, so emptying it
  # really does unbind them -- an `rm()` aimed at a parent frame silently
  # found nothing, which made an earlier version of this test pass without
  # testing anything.
  scope <- new.env(parent = baseenv())
  scope$mpg <- c(21, 22, 23, 30, 31, 32)
  scope$cyl <- rep(c(4, 6), each = 3)
  drawn <- eval(quote(mpg ~ cyl), scope)

  schema <- rebind_then_read(
    function() boxplot(drawn),
    function() rm(list = c("mpg", "cyl"), envir = scope)
  )
  axes <- schema$subplots[[1]][[1]]$layers[[1]]$axes

  testthat::expect_false(exists("mpg", envir = scope, inherits = FALSE))
  testthat::expect_equal(axes$x$label, "cyl")
  testthat::expect_equal(axes$y$label, "mpg")
})


test_that("the ordinary spellings are unaffected", {
  # Four charts that read correctly before this and must still. The issue
  # records that declining a formula with no `data =` would have traded
  # these for a picture.
  local_len <- c(1, 2, 3, 10, 11, 12)
  local_supp <- rep(c("OJ", "VC"), each = 3)

  from_globals <- snapshot_layers(function() stripchart(local_len ~ local_supp))
  from_frame <- snapshot_layers(function() {
    stripchart(len ~ supp,
               data = data.frame(len = local_len, supp = local_supp))
  })
  from_closure <- snapshot_layers((function() {
    inner_len <- local_len
    inner_supp <- local_supp
    function() stripchart(inner_len ~ inner_supp)
  })())

  for (layers in list(from_globals, from_frame, from_closure)) {
    testthat::expect_length(layers, 2)
    testthat::expect_equal(
      vapply(all_points(layers), function(point) point$x, 0),
      c(1, 2, 3, 10, 11, 12)
    )
  }
})


test_that("a call carrying no formula records no frame", {
  testthat::expect_null(maidr:::recorded_formula_frame(list(x = 1:3)))
  testthat::expect_null(maidr:::recorded_formula_frame(list()))
  testthat::expect_null(maidr:::recorded_formula_frame(NULL))
})


test_that("a formula that cannot be resolved records nothing rather than erroring", {
  # A reader that stops takes the whole figure with it, so an unresolvable
  # formula leaves the frame empty and the processor falls back to its own
  # attempt -- which is what a call recorded before this existed does too.
  testthat::expect_null(
    maidr:::recorded_formula_frame(list(nowhere_at_all ~ missing_entirely))
  )
})


test_that("the frame is found whether the formula is named or positional", {
  # `stripchart()` names its first formal `x` and `boxplot()` names its own
  # `formula`, and a positional call records it unnamed -- so the search is
  # by class rather than by name, with the name preferred when there is one.
  values <- c(1, 2, 3, 10, 11, 12)
  groups <- rep(c("OJ", "VC"), each = 3)

  positional <- maidr:::recorded_formula_frame(list(values ~ groups))
  named <- maidr:::recorded_formula_frame(list(formula = values ~ groups))

  testthat::expect_s3_class(positional, "data.frame")
  testthat::expect_s3_class(named, "data.frame")
  testthat::expect_equal(positional[[1]], values)
  testthat::expect_equal(named[[1]], values)
})


test_that("`data =` still masks variables of the same name in scope", {
  # Masking is what `data =` is for, so a column and a loose variable of the
  # same name may disagree -- measured, `stripchart(len ~ supp, data = df)`
  # builds its frame from the columns and draws them.
  #
  # This is the one place the recorded `data` cannot be left out. The other
  # ways of losing it end in a failed `model.frame()`, and a failure is safe:
  # nothing is recorded and the processor falls back to resolving the formula
  # itself, with the recorded `data` -- a value -- still in hand. Resolving
  # without `data` does not fail here. It finds the loose variables, and a
  # frame built from the wrong ones is still a frame, so it is recorded and
  # then believed.
  len <- c(99, 98, 97, 96, 95, 94)
  supp <- rep(c("XX", "YY"), each = 3)

  layers <- snapshot_layers(function() {
    stripchart(
      len ~ supp,
      data = data.frame(
        len = c(1, 2, 3, 10, 11, 12),
        supp = rep(c("OJ", "VC"), each = 3)
      )
    )
  })
  points <- all_points(layers)

  testthat::expect_equal(
    vapply(points, function(point) point$x, 0),
    c(1, 2, 3, 10, 11, 12)
  )
  testthat::expect_equal(
    unique(vapply(points, function(point) point$yLabel, "")),
    c("OJ", "VC")
  )
})


test_that("a recorded subset keeps the rows the chart left out of the frame", {
  # `stripchart.formula` hands `subset` to `model.frame()`, so the frame
  # kept at record time has to as well; without it the reading carried every
  # row of the data against a chart that drew a fraction of them.
  tg <- datasets::ToothGrowth
  layers <- base_r_layers(function() {
    stripchart(len ~ supp, data = tg, subset = tg$dose == 0.5)
  })

  # One point layer per group, each holding the ten observations drawn for
  # it rather than the thirty the data has.
  testthat::expect_length(layers, 2L)
  testthat::expect_identical(
    vapply(layers, function(layer) layer$type, character(1)),
    c("point", "point")
  )
  testthat::expect_identical(
    vapply(layers, function(layer) length(layer$data), integer(1)),
    c(10L, 10L)
  )
})
