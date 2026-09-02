# plot(y ~ x, data = d) is read as the scatter it draws
#
# The recording keeps the model frame of a formula call (#254), but the point
# reader resolved its coordinates from the arguments alone, where the formula
# is a language object, so `plot(mpg ~ wt, data = mtcars)` emitted a point
# layer with no points in it -- and, being typed, no static picture either.

test_that("a formula scatter carries its observations and its variable names", {
  layer <- base_r_layers(function() plot(mpg ~ wt, data = mtcars))[[1]]

  expect_identical(layer$type, "point")
  expect_length(layer$data, nrow(mtcars))
  expect_equal(
    vapply(layer$data, function(point) point$x, numeric(1)),
    mtcars$wt
  )
  expect_equal(
    vapply(layer$data, function(point) point$y, numeric(1)),
    mtcars$mpg
  )
  # `plot.formula()` names the axes after the two variables.
  expect_identical(layer$axes$x$label, "wt")
  expect_identical(layer$axes$y$label, "mpg")
})

test_that("a caller's own axis titles still win on a formula scatter", {
  layer <- base_r_layers(function() {
    plot(mpg ~ wt, data = mtcars, xlab = "Weight", ylab = "Miles per gallon")
  })[[1]]

  expect_identical(layer$axes$x$label, "Weight")
  expect_identical(layer$axes$y$label, "Miles per gallon")
})

test_that("a vector subset on a formula scatter keeps only the rows drawn", {
  layer <- base_r_layers(function() {
    plot(mpg ~ wt, data = mtcars, subset = mtcars$cyl == 4)
  })[[1]]

  expect_length(layer$data, sum(mtcars$cyl == 4))
})

test_that("a formula on a factor is not read as a scatter", {
  # `plot(y ~ f)` dispatches to `plot.factor()`, which draws a box plot.
  layers <- base_r_layers(function() plot(mpg ~ factor(cyl), data = mtcars))

  for (layer in layers) {
    expect_length(layer$data, 0L)
  }
})
