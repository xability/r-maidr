# A date-time at midnight was read without its time.
#
# `format()` leaves the time off a date-time when every value it is given
# falls at midnight, and the layers wrote their x values one at a time, so a
# series over `POSIXct` read its midnight point as "2026-01-01" beside
# "2026-01-01 01:00:00": in ggplot2's lines, steps, points and bars, and in
# Base R's lines. A series that was all midnights read as dates. Each
# date-time is now written with its time, in its own zone; a `Date` is still
# written as a date.

midnight_series <- function() {
  data.frame(
    t = as.POSIXct("2026-01-01", tz = "America/New_York") + 3600 * (0:3),
    y = c(3, 1, 4, 1)
  )
}

with_times <- c(
  "2026-01-01 00:00:00", "2026-01-01 01:00:00",
  "2026-01-01 02:00:00", "2026-01-01 03:00:00"
)

# The x of every point of a layer, as the page carries it.
page_xs <- function(layer) {
  rows <- layer$data
  if (length(rows) && is.list(rows[[1]]) && is.null(names(rows[[1]]))) {
    rows <- unlist(rows, recursive = FALSE)
  }
  vapply(rows, function(point) as.character(point$x), character(1))
}

page_layers <- function(plot) {
  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  layers_from(html)
}

test_that("a date-time is written with its time, in its own zone", {
  midnight <- as.POSIXct("2026-01-01", tz = "America/New_York")

  testthat::expect_identical(maidr:::time_text(midnight), "2026-01-01 00:00:00")
  testthat::expect_identical(
    maidr:::time_text(as.POSIXlt(midnight)),
    "2026-01-01 00:00:00"
  )
  # The same instant, kept in UTC.
  testthat::expect_identical(
    maidr:::time_text(structure(midnight, tzone = "UTC")),
    "2026-01-01 05:00:00"
  )
  testthat::expect_identical(maidr:::time_text(as.Date("2026-01-01")), "2026-01-01")
  testthat::expect_identical(maidr:::time_text(c(1, 2)), c(1, 2))
})

test_that("a ggplot2 line over date-times keeps the time at midnight", {
  skip_if_no_render()

  layers <- page_layers(
    ggplot2::ggplot(midnight_series(), ggplot2::aes(t, y)) + ggplot2::geom_line()
  )

  testthat::expect_identical(page_xs(layers[[1]]), with_times)
})

test_that("a ggplot2 point over date-times keeps the time at midnight", {
  skip_if_no_render()

  layers <- page_layers(
    ggplot2::ggplot(midnight_series(), ggplot2::aes(t, y)) + ggplot2::geom_point()
  )

  testthat::expect_identical(page_xs(layers[[1]]), with_times)
})

test_that("ggplot2 bars, a line and points over the same date-times write the same x", {
  skip_if_no_render()

  # A move between layers finds the same x in the next one, so they have to
  # be written alike.
  layers <- page_layers(
    ggplot2::ggplot(midnight_series(), ggplot2::aes(t, y)) +
      ggplot2::geom_col() +
      ggplot2::geom_line() +
      ggplot2::geom_point()
  )

  testthat::expect_length(layers, 3L)
  for (layer in layers) {
    testthat::expect_identical(page_xs(layer), with_times)
  }
})

test_that("a ggplot2 line of date-times all at midnight keeps the time", {
  skip_if_no_render()

  daily <- data.frame(
    t = as.POSIXct("2026-01-01", tz = "UTC") + 86400 * (0:2),
    y = c(3, 1, 4)
  )
  layers <- page_layers(
    ggplot2::ggplot(daily, ggplot2::aes(t, y)) + ggplot2::geom_line()
  )

  testthat::expect_identical(
    page_xs(layers[[1]]),
    c("2026-01-01 00:00:00", "2026-01-02 00:00:00", "2026-01-03 00:00:00")
  )
})

test_that("a facet panel of date-times all at midnight keeps the time", {
  testthat::skip_if_not_installed("ggplot2")

  frame <- data.frame(
    t = as.POSIXct("2026-01-01", tz = "UTC") + 3600 * c(0, 24, 1, 2),
    y = c(3, 1, 4, 1),
    g = c("a", "a", "b", "b")
  )
  plot <- ggplot2::ggplot(frame, ggplot2::aes(t, y)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~g)
  schema <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()

  testthat::expect_identical(
    page_xs(schema$subplots[[1]][[1]]$layers[[1]]),
    c("2026-01-01 00:00:00", "2026-01-02 00:00:00")
  )
})

test_that("a ggplot2 line over dates is still read as dates", {
  skip_if_no_render()

  dates <- data.frame(d = as.Date("2026-01-01") + 0:2, y = c(3, 1, 4))
  layers <- page_layers(
    ggplot2::ggplot(dates, ggplot2::aes(d, y)) + ggplot2::geom_line()
  )

  testthat::expect_identical(
    page_xs(layers[[1]]),
    c("2026-01-01", "2026-01-02", "2026-01-03")
  )
})

test_that("a Base R line over date-times keeps the time at midnight", {
  series <- midnight_series()
  figure <- base_r_figure(function() plot(series$t, series$y, type = "l"))

  testthat::expect_identical(page_xs(figure$subplots[[1]][[1]]$layers[[1]]), with_times)

  days <- as.Date("2026-01-01") + 0:2
  dated <- base_r_figure(function() plot(days, c(3, 1, 4), type = "l"))
  testthat::expect_identical(
    page_xs(dated$subplots[[1]][[1]]$layers[[1]]),
    c("2026-01-01", "2026-01-02", "2026-01-03")
  )
})

test_that("a candle at midnight keeps its time", {
  midnight <- as.POSIXct("2026-01-01", tz = "UTC") + 86400 * (0:1)

  ggplot2_candles <- maidr:::Ggplot2CandlestickProcessor$new(list(index = 1))
  testthat::expect_identical(
    ggplot2_candles$format_x_value(midnight[1]),
    "2026-01-01 00:00:00"
  )

  base_r_candles <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1))
  testthat::expect_identical(
    base_r_candles$format_x_values(midnight),
    c("2026-01-01 00:00:00", "2026-01-02 00:00:00")
  )
})
