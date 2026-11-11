# A chart whose axes or title are written in plotmath is read, each title as
# it is written.
#
# ggplot2 takes any title as plotmath -- an `expression()`, or a call as
# `quote()` and `bquote()` make one -- and draws it as mathematics. An axis
# titled so stopped the reading ("Axis value must be a list, string, numeric,
# or NULL"), and no page was written; a title, subtitle or caption in
# plotmath drew the chart as a picture ("'length = 3' in coercion to
# 'logical(1)'" for a call, "No method asJSON S3 class: expression" for an
# `expression()`). A reader got no chart. A scale's name or a patchwork
# annotation in plotmath was dropped instead.

pts <- data.frame(wt = c(1, 2, 3, 4), mpg = c(3, 1, 2, 4), g = c("a", "a", "b", "b"))
point <- ggplot2::ggplot(pts, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
math_axes <- ggplot2::labs(x = expression(x^2), y = quote(mu[i]))

#' The schema a plot is written with; a picture fails the test
written_schema <- function(plot) {
  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  schema_from(html)
}

#' The x and y titles of the first layer of every panel
axis_titles <- function(schema) {
  lapply(unlist(schema$subplots, recursive = FALSE), function(cell) {
    axes <- cell$layers[[1]]$axes
    c(x = axes$x$label, y = axes$y$label)
  })
}

test_that("an axis config reads a plotmath label as written, given alone or in a list", {
  testthat::expect_identical(
    maidr:::as_axis_config(list(label = quote(x^2), min = 0)),
    list(label = "x^2", min = 0)
  )
  testthat::expect_identical(maidr:::as_axis_config(expression(x[1])), list(label = "x[1]"))
  testthat::expect_identical(
    maidr:::extract_axis_label(list(label = quote(mu[i]))),
    "mu[i]"
  )
  testthat::expect_identical(maidr:::extract_axis_label(quote(beta[1])), "beta[1]")
  testthat::expect_identical(maidr:::build_axis_config(label = quote(gamma^2))$label, "gamma^2")
})

test_that("an axis titled in plotmath is read as written, in every kind of layer", {
  skip_if_no_render()
  charts <- list(
    point = point,
    bar = ggplot2::ggplot(pts, ggplot2::aes(g, mpg)) + ggplot2::geom_col(),
    line = ggplot2::ggplot(pts, ggplot2::aes(wt, mpg)) + ggplot2::geom_line(),
    box = ggplot2::ggplot(pts, ggplot2::aes(g, mpg)) + ggplot2::geom_boxplot()
  )
  for (kind in names(charts)) {
    titles <- axis_titles(written_schema(charts[[kind]] + math_axes))
    testthat::expect_identical(titles, list(c(x = "x^2", y = "mu[i]")), info = kind)
  }

  hist <- ggplot2::ggplot(pts, ggplot2::aes(mpg)) +
    ggplot2::geom_histogram(bins = 2) +
    ggplot2::xlab(expression(x[1]))
  testthat::expect_identical(axis_titles(written_schema(hist))[[1]][["x"]], "x[1]")
})

test_that("a scale named in plotmath titles its axis as written", {
  skip_if_no_render()
  width <- 2
  chart <- point +
    ggplot2::scale_x_continuous(quote(alpha^2)) +
    ggplot2::scale_y_continuous(name = bquote(Delta ~ .(width) ~ m))
  testthat::expect_identical(
    axis_titles(written_schema(chart)),
    list(c(x = "alpha^2", y = "Delta ~ 2 ~ m"))
  )
})

test_that("a title, subtitle and caption in plotmath are read as written", {
  skip_if_no_render()
  schema <- written_schema(point + ggplot2::labs(
    title = quote(alpha^2), subtitle = expression(beta[1]), caption = quote(gamma)
  ))
  testthat::expect_identical(schema$title, "alpha^2")
  testthat::expect_identical(schema$subtitle, "beta[1]")
  testthat::expect_identical(schema$caption, "gamma")

  schema <- written_schema(point + ggplot2::ggtitle(expression("Rate (%)")))
  testthat::expect_identical(schema$title, "Rate (%)")
})

test_that("each facet panel and each plot of a patchwork reads its plotmath titles", {
  skip_if_no_render()
  faceted <- written_schema(point + ggplot2::facet_wrap(~g) + math_axes)
  testthat::expect_identical(
    axis_titles(faceted),
    rep(list(c(x = "x^2", y = "mu[i]")), 2)
  )

  testthat::skip_if_not_installed("patchwork")
  first <- point + math_axes + ggplot2::labs(title = quote(alpha))
  composed <- patchwork::wrap_plots(first, point) +
    patchwork::plot_annotation(title = expression(beta^2))
  schema <- written_schema(composed)
  testthat::expect_identical(schema$title, "beta^2")
  testthat::expect_identical(axis_titles(schema)[[1]], c(x = "x^2", y = "mu[i]"))
  testthat::expect_identical(schema$subplots[[1]][[1]]$layers[[1]]$title, "alpha")
})
