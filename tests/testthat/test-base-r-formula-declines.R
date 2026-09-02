# A formula call is read from the frame it drew, or declined outright
#
# Two defects the release-notes audit measured (#294). A formula recorded
# with a `subset` written as an expression -- `stripchart(len ~ supp, data =
# tg, subset = dose == 0.5)` -- had no frame, because the expression reached
# the recorder unevaluated and nothing evaluated it; the reader then declined
# at read time, and a declined layer of a claimed type exported as an
# interactive chart with no layers and no warning. `vioplot(y ~ g)` and
# `plot(y ~ f)` on a factor did the same for their own reasons.
#
# The frame is now built at record time through the snapshot a deferred
# call carries, the way `model.frame()` builds it, and a formula call that
# still has no frame -- or whose frame is not the scatter `plot.formula()`
# draws -- is typed `unknown`, which is the picture.

formula_figure <- function(draw) {
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
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)
  list(
    fallback = orchestrator$should_fallback(),
    subplots = orchestrator$generate_maidr_data()$subplots
  )
}

test_that("a stripchart with an expression subset reads the rows it drew", {
  tg <- datasets::ToothGrowth
  figure <- formula_figure(function() {
    stripchart(len ~ supp, data = tg, subset = dose == 0.5)
  })
  layers <- figure$subplots[[1]][[1]]$layers

  expect_false(figure$fallback)
  expect_length(layers, 2L)
  expect_identical(
    vapply(layers, function(layer) length(layer$data), integer(1)),
    c(10L, 10L)
  )
})

test_that("a formula scatter with an expression subset reads its rows", {
  figure <- formula_figure(function() {
    plot(mpg ~ wt, data = mtcars, subset = cyl == 4)
  })
  layer <- figure$subplots[[1]][[1]]$layers[[1]]

  expect_identical(layer$type, "point")
  expect_length(layer$data, sum(mtcars$cyl == 4))
})

test_that("a formula scatter drawn in a loop keeps each iteration's rows", {
  # The expression names a loop variable, so each recording carries its own
  # snapshot, and the frame is built from that snapshot rather than from
  # whatever the variable holds by render time (#71).
  counts <- integer(0)
  for (cylinders in c(4, 6, 8)) {
    figure <- formula_figure(function() {
      plot(mpg ~ wt, data = mtcars, subset = cyl == cylinders)
    })
    counts <- c(counts, length(figure$subplots[[1]][[1]]$layers[[1]]$data))
  }

  expect_identical(counts, as.integer(table(mtcars$cyl)))
})

test_that("a pairs formula with an expression subset reads its rows", {
  figure <- formula_figure(function() {
    pairs(~ mpg + wt + hp, data = mtcars, subset = cyl == 4)
  })
  cell <- figure$subplots[[1]][[2]]$layers[[1]]

  expect_identical(cell$type, "point")
  expect_length(cell$data, sum(mtcars$cyl == 4))
})

test_that("a formula plot on a factor falls back rather than reading as points", {
  # `plot(y ~ f)` reaches `plot.factor()`, which draws a box plot.
  figure <- formula_figure(function() plot(mpg ~ factor(cyl), data = mtcars))

  expect_true(figure$fallback)
})

test_that("a vioplot formula call falls back rather than exporting no layers", {
  testthat::skip_if_not_installed("vioplot")

  figure <- formula_figure(function() vioplot(mpg ~ cyl, data = mtcars))

  expect_true(figure$fallback)
})

test_that("recorded_formula_frame resolves a deferred call through its snapshot", {
  snapshot <- new.env()
  snapshot$d <- data.frame(y = 1:6, g = rep(c("a", "b"), 3), k = 1:6)
  snapshot$limit <- 4L

  frame <- maidr:::recorded_formula_frame(
    list(quote(y ~ g), data = quote(d), subset = quote(k <= limit)),
    call_env = snapshot
  )

  expect_s3_class(frame, "data.frame")
  expect_identical(nrow(frame), 4L)

  # Without a snapshot an expression cannot be evaluated, so the frame is
  # declined rather than built over every row.
  expect_null(maidr:::recorded_formula_frame(
    list(y ~ g, data = snapshot$d, subset = quote(k <= limit))
  ))
})
