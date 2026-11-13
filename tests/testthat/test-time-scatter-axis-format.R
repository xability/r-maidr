# A scatter over dates or times is sent the axis's own numbers, drawn by its
# format.
#
# maidr.js reads a scatter point's x and y as numbers: it orders the points
# by them, finds the extremes `[` and `]` move to, measures the correlation
# and pitches each tone. ggplot2's `geom_point()` over a `Date` or `POSIXct`
# sent strings, so its points were walked in the order of their y values,
# `[` and `]` found no extreme, the correlation and the x range went, and
# each tone failed. Base R's `plot(times, y)` sent seconds since 1970 and read
# them so, "t is 1,767,243,600". Both now send the numbers, days or seconds
# as the histograms do, and the axis carries the format that draws them.

times <- as.POSIXct("2026-01-01", tz = "America/New_York") + 3600 * (0:3)
days <- as.Date("2026-01-01") + 0:3
ys <- c(3, 1, 4, 1)

# The values of one coordinate of a layer's points, as the page carries them.
page_values <- function(layer, axis = "x") {
  vapply(layer$data, function(point) point[[axis]], numeric(1))
}

page_layers <- function(plot) {
  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  layers_from(html)
}

test_that("a ggplot2 scatter over date-times sends seconds and draws them in the scale's zone", {
  skip_if_no_render()

  layers <- page_layers(
    ggplot2::ggplot(data.frame(t = times, y = ys), ggplot2::aes(t, y)) + ggplot2::geom_point()
  )

  # Numbers, so maidr.js orders the points, finds their extremes and their
  # correlation, in time order.
  testthat::expect_identical(page_values(layers[[1]]), as.numeric(times))
  testthat::expect_identical(order(page_values(layers[[1]])), order(times))
  testthat::expect_identical(
    layers[[1]]$axes$x$format,
    maidr:::time_axis_format("datetime", "America/New_York")
  )
  testthat::expect_null(layers[[1]]$axes$y$format)
})

test_that("a ggplot2 scatter over dates sends days", {
  skip_if_no_render()

  layers <- page_layers(
    ggplot2::ggplot(data.frame(d = days, y = ys), ggplot2::aes(d, y)) + ggplot2::geom_point()
  )

  testthat::expect_identical(page_values(layers[[1]]), as.numeric(days))
  testthat::expect_identical(layers[[1]]$axes$x$format, maidr:::time_axis_format("date"))
})

test_that("a ggplot2 scatter over clock times sends seconds", {
  testthat::skip_if_not_installed("ggplot2")
  # scale_x_time() maps its breaks back through hms.
  testthat::skip_if_not_installed("hms")

  clock <- structure(c(600, 1200, 1800), units = "secs", class = c("hms", "difftime"))
  layer <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(data.frame(h = clock, y = ys[1:3]), ggplot2::aes(h, y)) +
      ggplot2::geom_point()
  )$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_identical(page_values(layer), c(600, 1200, 1800))
  testthat::expect_identical(layer$axes$x$format, maidr:::time_axis_format("time"))
})

test_that("a ggplot2 scatter with date-times on y sends them as numbers there", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(data.frame(t = times, y = ys), ggplot2::aes(y, t)) + ggplot2::geom_point()
  )$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_identical(page_values(layer, "y"), as.numeric(times))
  testthat::expect_identical(
    layer$axes$y$format,
    maidr:::time_axis_format("datetime", "America/New_York")
  )
  testthat::expect_null(layer$axes$x$format)
})

test_that("every colour group and facet panel of a scatter over date-times has the format", {
  testthat::skip_if_not_installed("ggplot2")

  frame <- data.frame(t = times, y = ys, g = c("a", "b", "a", "b"))
  zone <- maidr:::time_axis_format("datetime", "America/New_York")

  grouped <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(frame, ggplot2::aes(t, y, colour = g)) + ggplot2::geom_point()
  )$generate_maidr_data()$subplots[[1]][[1]]$layers
  testthat::expect_length(grouped, 2L)
  for (layer in grouped) {
    testthat::expect_identical(layer$axes$x$format, zone)
  }

  faceted <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(frame, ggplot2::aes(t, y)) +
      ggplot2::geom_point() +
      ggplot2::facet_wrap(~g)
  )$generate_maidr_data()$subplots[[1]]
  for (cell in faceted) {
    testthat::expect_identical(cell$layers[[1]]$axes$x$format, zone)
    testthat::expect_true(is.numeric(cell$layers[[1]]$data[[1]]$x))
  }
})

test_that("a ggplot2 scatter keeps a time zone given to its scale", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(data.frame(t = times, y = ys), ggplot2::aes(t, y)) +
      ggplot2::geom_point() +
      ggplot2::scale_x_datetime(timezone = "Asia/Tokyo")
  )$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_identical(page_values(layer), as.numeric(times))
  testthat::expect_identical(
    layer$axes$x$format,
    maidr:::time_axis_format("datetime", "Asia/Tokyo")
  )

  # In each facet panel too, whether the panels share the scale or not.
  frame <- data.frame(t = times, y = ys, g = c("a", "b", "a", "b"))
  for (scales in c("fixed", "free_x")) {
    cells <- maidr:::Ggplot2PlotOrchestrator$new(
      ggplot2::ggplot(frame, ggplot2::aes(t, y)) +
        ggplot2::geom_point() +
        ggplot2::facet_wrap(~g, scales = scales) +
        ggplot2::scale_x_datetime(timezone = "Asia/Tokyo")
    )$generate_maidr_data()$subplots[[1]]
    for (cell in cells) {
      testthat::expect_identical(
        cell$layers[[1]]$axes$x$format,
        maidr:::time_axis_format("datetime", "Asia/Tokyo")
      )
    }
  }
})

test_that("a Base R scatter over date-times draws its seconds in their zone", {
  figure <- base_r_figure(function() plot(times, ys))
  layer <- figure$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_identical(page_values(layer), as.numeric(times))
  testthat::expect_identical(
    layer$axes$x$format,
    maidr:::time_axis_format("datetime", "America/New_York")
  )
  testthat::expect_null(layer$axes$y$format)

  dated <- base_r_figure(function() plot(days, ys))$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_identical(page_values(dated), as.numeric(days))
  testthat::expect_identical(dated$axes$x$format, maidr:::time_axis_format("date"))

  # Date-times on y are drawn there.
  flipped <- base_r_figure(function() plot(ys, times))$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_identical(
    flipped$axes$y$format,
    maidr:::time_axis_format("datetime", "America/New_York")
  )
  testthat::expect_null(flipped$axes$x$format)
})

test_that("a scatter of plain numbers carries no time format", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(data.frame(a = ys, b = ys), ggplot2::aes(a, b)) + ggplot2::geom_point()
  )$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_null(layer$axes$x$format)
  testthat::expect_null(layer$axes$y$format)

  base <- base_r_figure(function() plot(1:4, ys))$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_null(base$axes$x$format)
})
