# A colour mapped to an expression announces the level, not the hex code
#
# `aes(colour = factor(cyl))` names no column of the data, so the lookup by
# column name found nothing and every point announced the colour it was
# drawn in. The expression is evaluated over the data the way ggplot2
# evaluates it, in the plain and the faceted chart alike.

colours_announced <- function(p) {
  subplots <- maidr:::Ggplot2PlotOrchestrator$new(p)$generate_maidr_data()$subplots
  unlist(lapply(subplots[[1]], function(cell) {
    vapply(cell$layers[[1]]$data, function(point) point$color, character(1))
  }))
}

test_that("a scatter coloured by an expression announces the level names", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) +
    ggplot2::geom_point()
  expect_setequal(unique(colours_announced(p)), c("4", "6", "8"))

  faceted <- colours_announced(p + ggplot2::facet_wrap(~am))
  expect_length(faceted, nrow(mtcars))
  expect_setequal(unique(faceted), c("4", "6", "8"))
})

test_that("a colour that is a column still announces its value", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(iris, ggplot2::aes(Sepal.Length, Sepal.Width, colour = Species)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~Species)
  expect_identical(colours_announced(p), as.character(iris$Species))
})
