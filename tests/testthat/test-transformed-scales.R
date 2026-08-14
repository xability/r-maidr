# A transformed scale must not be announced in transformed space (issue #158)
#
# ggplot2 applies a scale transformation *before* the stat runs, so
# `ggplot_build()`'s data is in the transformed space. Read straight through,
# a `scale_x_log10()` chart announces log10 coordinates under the original
# axis label: a scatter of prices from $5.50 to $9,403 reads as 0.744 to
# 3.973 under "Price (USD)".
#
# This is the failure mode that is worse than an unsupported chart. Nothing
# is missing, nothing errors, the structure is right, the point count is
# right, the label is right, and the numbers are false -- with no signal a
# reader could catch, because "these look small" is not checkable without the
# chart you cannot see.
#
# Three things are asserted, and the third is the one that is easy to get
# wrong:
#
#   * the announced value matches the *source column*, not a literal, so the
#     test keeps meaning if ggplot2 changes where it puts the breaks;
#   * `coord_trans()` is left alone. It transforms at draw time, after the
#     stat, so its built data is already in data space -- inverting it would
#     break a chart that currently reads correctly;
#   * a transformed axis emits no grid. Grid navigation walks equal
#     increments, and 10/100/1000 are equally spaced only in the space the
#     points are no longer announced in. Emitting the transformed range
#     instead would leave the grid and the announcement in different spaces,
#     which is worse than today, where the two are at least wrong together.
#
# `reverse` earns its place in every case below: it negates rather than
# compresses, so a plausibility check on the announced range passes it while
# every value has the wrong sign.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

#' Prices spanning three orders of magnitude, so a log scale is natural
price_frame <- function(n = 40) {
  set.seed(2)
  data.frame(price = 10^stats::runif(n, 0.7, 4), size = stats::runif(n, 1, 9))
}

scatter_plot <- function(scale = NULL) {
  plot <- ggplot2::ggplot(price_frame(), ggplot2::aes(price, size)) +
    ggplot2::geom_point() +
    ggplot2::labs(x = "Price (USD)", y = "Size")
  if (is.null(scale)) plot else plot + scale
}

#' Render a plot and return the one layer it emits
transformed_layer <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  testthat::expect_length(raw, 1)
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

#' The x values a layer announces
announced_x <- function(layer) {
  vapply(layer$data, function(point) as.numeric(point$x), numeric(1))
}

transform_cases <- list(
  log10 = ggplot2::scale_x_log10(),
  sqrt = ggplot2::scale_x_sqrt(),
  reverse = ggplot2::scale_x_reverse()
)

test_that("a scatter on a transformed scale announces the values it was given", {
  skip_if_no_render()

  source_prices <- sort(price_frame()$price)

  for (name in names(transform_cases)) {
    layer <- transformed_layer(scatter_plot(transform_cases[[name]]))
    testthat::expect_equal(
      sort(announced_x(layer)), source_prices,
      tolerance = 1e-8, info = name
    )
  }
})

test_that("an untransformed scatter is unchanged", {
  skip_if_no_render()

  # The control, and the overwhelmingly common case. `identity` has to cost
  # nothing and change nothing.
  layer <- transformed_layer(scatter_plot())

  testthat::expect_equal(
    sort(announced_x(layer)), sort(price_frame()$price),
    tolerance = 1e-8
  )
  testthat::expect_false(is.null(layer$axes$x$min))
})

test_that("a transformed axis emits no navigation grid", {
  skip_if_no_render()

  # The half that would otherwise disagree with itself. Inverting the points
  # while leaving the range transformed is worse than leaving both alone.
  for (name in names(transform_cases)) {
    layer <- transformed_layer(scatter_plot(transform_cases[[name]]))
    testthat::expect_null(layer$axes$x$min, info = name)
    testthat::expect_null(layer$axes$x$max, info = name)
    testthat::expect_null(layer$axes$x$tickStep, info = name)

    # The label survives. An axis with no name is a worse outcome than an
    # axis with no grid.
    testthat::expect_equal(layer$axes$x$label, "Price (USD)", info = name)
  }

  # The untransformed y axis keeps its own grid: this is per axis, not per
  # chart, so a chart with one transformed axis does not lose both.
  layer <- transformed_layer(scatter_plot(ggplot2::scale_x_log10()))
  testthat::expect_false(is.null(layer$axes$y$min))
})

test_that("coord_trans() is left alone", {
  skip_if_no_render()

  # It transforms at draw time, after the stat, so the built data is already
  # in data space *and* the scale reports `identity`. One comparison covers
  # both mechanisms -- a test for "is there a log axis" would have inverted
  # this a second time and broken a chart that reads correctly today.
  plot <- ggplot2::ggplot(price_frame(), ggplot2::aes(price, size)) +
    ggplot2::geom_point() +
    ggplot2::coord_trans(x = "log10")

  layer <- transformed_layer(suppressWarnings(plot))

  testthat::expect_equal(
    sort(announced_x(layer)), sort(price_frame()$price),
    tolerance = 1e-8
  )
})

test_that("a fitted curve is announced in data space too", {
  skip_if_no_render()

  # `geom_smooth()` reads through a different processor, and a log-scaled
  # scatter with a fit is the shape this most often appears in.
  frame <- price_frame(60)
  plot <- ggplot2::ggplot(frame, ggplot2::aes(price, size)) +
    ggplot2::geom_smooth(se = FALSE, method = "loess", formula = y ~ x) +
    ggplot2::scale_x_log10()

  layer <- transformed_layer(plot)
  points <- if (!is.null(layer$data[[1]]$x)) layer$data else layer$data[[1]]
  xs <- vapply(points, function(point) as.numeric(point$x), numeric(1))

  # The curve spans the data rather than its logarithm. Asserted as a range
  # rather than point-by-point, since the fit chooses its own positions.
  testthat::expect_gt(max(xs), 1000)
  testthat::expect_lt(min(xs), 100)
})

test_that("the transformation helper answers for each case in turn", {
  testthat::skip_if_not_installed("ggplot2")

  # Driven directly, because the render tests above cannot show that
  # `identity` and `coord_trans()` take the *same* branch -- they only show
  # that both come out unchanged, which a broken helper could also manage by
  # failing in two different ways.
  frame <- price_frame()
  build <- function(extra = NULL) {
    plot <- ggplot2::ggplot(frame, ggplot2::aes(price, size)) + ggplot2::geom_point()
    suppressWarnings(ggplot2::ggplot_build(if (is.null(extra)) plot else plot + extra))
  }

  testthat::expect_null(maidr:::panel_transformation(build(), "x"))
  testthat::expect_null(
    maidr:::panel_transformation(build(ggplot2::coord_trans(x = "log10")), "x")
  )
  testthat::expect_false(
    is.null(maidr:::panel_transformation(build(ggplot2::scale_x_log10()), "x"))
  )

  # A discrete position is an index into the scale's levels, not a
  # measurement, and is returned untouched whatever the axis carries.
  testthat::expect_equal(
    maidr:::untransform_positions(c("a", "b"), build(), "x"), c("a", "b")
  )
})
