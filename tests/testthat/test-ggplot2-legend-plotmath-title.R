# A legend titled in plotmath is read by the title as it is written.
#
# ggplot2 takes a legend title as plotmath -- an `expression()`, or a call as
# `quote()` and `bquote()` make one -- and draws it as mathematics. Given to
# `labs()` or a scale as a call, the title was coerced to one string per
# part, taken for no title, and the values were read under the mapped
# column. A two-sided formula, as `bquote(Delta ~ .(n) ~ m)` makes, was taken
# for a function and dropped the same way, and so was an expression of two.

tiles <- expand.grid(x = c("a", "b"), y = c("p", "q"), stringsAsFactors = FALSE)
tiles$score <- 1:4
heat <- ggplot2::ggplot(tiles, ggplot2::aes(x, y, fill = score)) + ggplot2::geom_tile()

#' The z axis title of the plot's first layer
legend_title <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  figure$subplots[[1]][[1]]$layers[[1]]$axes$z$label
}

test_that("a legend title given as a call is read as written", {
  testthat::expect_identical(
    legend_title(heat + ggplot2::labs(fill = quote(alpha^2))),
    "alpha^2"
  )
  testthat::expect_identical(
    legend_title(heat + ggplot2::scale_fill_gradient(name = quote(alpha^2))),
    "alpha^2"
  )
  # A bare symbol is a call's simplest case.
  testthat::expect_identical(legend_title(heat + ggplot2::labs(fill = quote(alpha))), "alpha")

  # The groups of stacked bars are read under the same title.
  counts <- data.frame(g = rep(c("A", "B"), each = 2), k = rep(c("u", "v"), 2), n = c(3, 5, 2, 4))
  stacked <- ggplot2::ggplot(counts, ggplot2::aes(g, n, fill = k)) +
    ggplot2::geom_col() +
    ggplot2::labs(fill = quote(beta[i]))
  testthat::expect_identical(legend_title(stacked), "beta[i]")
})

test_that("a two-sided formula is plotmath, not a function", {
  # `~` is plotmath's space. ggplot2 takes a formula for a function only
  # when it is one-sided and evaluated, as `~ toupper(.x)` is.
  width <- 2
  testthat::expect_identical(
    legend_title(heat + ggplot2::scale_fill_gradient(name = bquote(Delta ~ .(width) ~ m))),
    "Delta ~ 2 ~ m"
  )
  # A one-sided `~` quoted, as `quote()` returns it, is a call: plotmath too.
  testthat::expect_identical(
    legend_title(heat + ggplot2::scale_fill_gradient(name = quote(~alpha))),
    "~alpha"
  )

  # The same `~`, evaluated, is a function, as ggplot2 3.5 and later take it.
  testthat::skip_if(
    utils::packageVersion("ggplot2") < "3.5.0",
    "ggplot2 before 3.5 takes no function as a scale's name"
  )
  testthat::expect_identical(
    legend_title(heat + ggplot2::scale_fill_gradient(name = ~ toupper(.x))),
    "SCORE"
  )
})

test_that("an expression of several is read one after another", {
  testthat::expect_identical(
    legend_title(heat + ggplot2::labs(fill = expression(alpha, beta))),
    "alpha beta"
  )
})

test_that("an expression of one is read as before, a string in it unquoted", {
  testthat::expect_identical(
    legend_title(heat + ggplot2::labs(fill = expression(alpha^2))),
    "alpha^2"
  )
  testthat::expect_identical(
    legend_title(heat + ggplot2::labs(fill = expression("Rate (%)"))),
    "Rate (%)"
  )
  guide <- ggplot2::guide_colourbar(title = expression(alpha^2))
  testthat::expect_identical(
    legend_title(heat + ggplot2::guides(fill = guide)),
    "alpha^2"
  )
})
