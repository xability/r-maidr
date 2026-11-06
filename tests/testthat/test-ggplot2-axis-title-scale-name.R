# An axis titled by its scale's name is read under that name.
#
# ggplot2 titles an axis by its scale's name before `labs()` and the
# mapping: `scale_x_continuous("Month")` draws "Month". maidr titled the
# axes of points, lines, bars, histograms and box plots from `labs()` and the
# mapping only, so a chart titled through its scales was read "month is 1"
# under an axis that shows "Month", and `labs(x = "Old")`, which the scale's
# name replaces on the chart, was read in its place.

sales <- data.frame(
  month = c(1, 2, 3, 4), sales = c(3, 1, 4, 2),
  group = c("a", "b", "a", "b"), half = c("H1", "H1", "H2", "H2")
)
titled <- list(
  ggplot2::scale_x_continuous("Month"),
  ggplot2::scale_y_continuous("Sales ($)")
)

#' The x and y titles of the first layer of each panel
layer_titles <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  lapply(unlist(figure$subplots, recursive = FALSE), function(cell) {
    axes <- cell$layers[[1]]$axes
    c(x = axes$x$label, y = axes$y$label)
  })
}

test_that("points, a line and a smooth are read under their scales' names", {
  geoms <- list(
    ggplot2::geom_point(),
    ggplot2::geom_line(),
    ggplot2::geom_smooth(method = "lm", formula = y ~ x)
  )
  for (geom in geoms) {
    plot <- ggplot2::ggplot(sales, ggplot2::aes(month, sales)) + geom + titled
    testthat::expect_equal(layer_titles(plot), list(c(x = "Month", y = "Sales ($)")))
  }
})

test_that("bars, a histogram and a box plot are read under their scales' names", {
  bars <- ggplot2::ggplot(sales, ggplot2::aes(group, sales)) +
    ggplot2::geom_col() +
    ggplot2::scale_x_discrete("Group") +
    ggplot2::scale_y_continuous("Sales ($)")
  testthat::expect_equal(layer_titles(bars), list(c(x = "Group", y = "Sales ($)")))

  box <- ggplot2::ggplot(sales, ggplot2::aes(group, sales)) +
    ggplot2::geom_boxplot() +
    ggplot2::scale_x_discrete("Group") +
    ggplot2::scale_y_continuous("Sales ($)")
  testthat::expect_equal(layer_titles(box), list(c(x = "Group", y = "Sales ($)")))

  histogram <- ggplot2::ggplot(sales, ggplot2::aes(sales)) +
    ggplot2::geom_histogram(bins = 3) +
    ggplot2::scale_x_continuous("Sales ($)") +
    ggplot2::scale_y_continuous("Months")
  testthat::expect_equal(layer_titles(histogram), list(c(x = "Sales ($)", y = "Months")))
})

test_that("a scale's name is read over labs(), as ggplot2 draws it", {
  plot <- ggplot2::ggplot(sales, ggplot2::aes(month, sales)) +
    ggplot2::geom_point() +
    ggplot2::labs(x = "Old") +
    ggplot2::scale_x_continuous("Month")
  testthat::expect_equal(layer_titles(plot), list(c(x = "Month", y = "sales")))
})

test_that("a scale named by a function is read by the title it returns", {
  # ggplot2 3.5 and later title the axis by what the function, or a formula
  # for one, returns for the title the axis would otherwise have. Coerced as
  # a string, the function stopped the reading with "cannot coerce type
  # 'closure' to vector of type 'character'". ggplot2 3.4 cannot draw one.
  testthat::skip_if(
    utils::packageVersion("ggplot2") < "3.5.0",
    "ggplot2 3.4 cannot draw a function as a scale's name"
  )
  points <- ggplot2::ggplot(sales, ggplot2::aes(month, sales)) + ggplot2::geom_point()
  named <- points +
    ggplot2::scale_x_continuous(toupper) +
    ggplot2::scale_y_continuous(function(title) "Sales ($)")
  testthat::expect_equal(layer_titles(named), list(c(x = "MONTH", y = "Sales ($)")))

  lambda <- points + ggplot2::scale_x_continuous(~ paste(.x, "(1 to 4)"))
  testthat::expect_equal(layer_titles(lambda), list(c(x = "month (1 to 4)", y = "sales")))
})

test_that("a scale's name follows its axis under coord_flip(), as labs() does", {
  bars <- ggplot2::ggplot(sales, ggplot2::aes(group, sales)) +
    ggplot2::geom_col() +
    ggplot2::coord_flip()
  scales <- bars + ggplot2::scale_x_discrete("Group") + ggplot2::scale_y_continuous("Sales ($)")
  testthat::expect_equal(
    layer_titles(scales),
    layer_titles(bars + ggplot2::labs(x = "Group", y = "Sales ($)"))
  )
})

test_that("each facet panel and each plot of a patchwork is read under its scales' names", {
  faceted <- ggplot2::ggplot(sales, ggplot2::aes(month, sales)) +
    ggplot2::geom_point() +
    titled +
    ggplot2::facet_wrap(~half)
  testthat::expect_equal(layer_titles(faceted), rep(list(c(x = "Month", y = "Sales ($)")), 2))

  testthat::skip_if_not_installed("patchwork")
  pair <- patchwork::wrap_plots(
    ggplot2::ggplot(sales, ggplot2::aes(month, sales)) + ggplot2::geom_line() + titled,
    ggplot2::ggplot(sales, ggplot2::aes(month, sales)) + ggplot2::geom_point()
  )
  testthat::expect_equal(
    layer_titles(pair),
    list(c(x = "Month", y = "Sales ($)"), c(x = "month", y = "sales"))
  )
})
