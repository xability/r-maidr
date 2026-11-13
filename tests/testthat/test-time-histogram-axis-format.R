# A histogram over dates or times was read in its axis's own numbers.
#
# R's `Date` counts days since 1970-01-01, `POSIXct` seconds since then and
# `hms` seconds since midnight, and a histogram's bins carry those numbers.
# ggplot2's `geom_histogram()` over dates announced a bin as "d is 20,457.5
# through 20,464.5", one over date-times in seconds since 1970 and one over
# clock times as "h is 300 through 900", and Base R's `hist(days, "weeks")`
# as "days is 20,458 through 20,465". The layer now carries a format that
# draws each number as the date, date-time or clock time it stands for, and
# the unit one number counts, from which a maidr.js that reads it
# (xability/maidr#1695) reads a bin's width as a span of time.

days <- as.Date("2026-01-01") + c(3, 7, 8, 9, 15, 16, 30, 31, 32, 33)
new_york <- as.POSIXct("2026-01-01", tz = "America/New_York") +
  3600 * c(0, 1, 1, 2, 2, 2, 5)

ggplot2_layer <- function(plot, panel = 1) {
  schema <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  schema$subplots[[1]][[panel]]$layers[[1]]
}

base_r_layer <- function(draw) {
  base_r_figure(draw)$subplots[[1]][[1]]$layers[[1]]
}

test_that("a time axis format names the unit one of its numbers counts", {
  # The bodies run in the browser as `new Function('value', body)`, and what
  # they print is checked there; here, what each converts and in which zone.
  date <- maidr:::time_axis_format("date")
  testthat::expect_identical(date$unit, "day")
  testthat::expect_match(date$`function`, "new Date(Number(value) * 864e5)", fixed = TRUE)

  datetime <- maidr:::time_axis_format("datetime", "America/New_York")
  testthat::expect_identical(datetime$unit, "second")
  testthat::expect_match(datetime$`function`, "new Date(Number(value) * 1000)", fixed = TRUE)
  testthat::expect_match(datetime$`function`, "timeZone: \"America/New_York\"", fixed = TRUE)

  time <- maidr:::time_axis_format("time")
  testthat::expect_identical(time$unit, "second")
  testthat::expect_match(time$`function`, "Math.floor(s / 3600)", fixed = TRUE)

  testthat::expect_null(maidr:::time_axis_format("number"))
})

test_that("the kind of time is read from the values' class", {
  clock <- structure(600, units = "secs", class = c("hms", "difftime"))

  testthat::expect_identical(maidr:::time_kind_of(days), "date")
  testthat::expect_identical(maidr:::time_kind_of(new_york), "datetime")
  testthat::expect_identical(maidr:::time_kind_of(clock), "time")
  testthat::expect_null(maidr:::time_kind_of(as.difftime(10, units = "mins")))
  testthat::expect_null(maidr:::time_kind_of(c(1, 2)))
})

test_that("a date-time is drawn in its own zone, else in the session's", {
  withr::local_envvar(TZ = "Asia/Tokyo")

  testthat::expect_identical(maidr:::time_zone_of("America/New_York"), "America/New_York")
  testthat::expect_identical(maidr:::time_zone_of(""), "Asia/Tokyo")
  testthat::expect_identical(maidr:::time_zone_of(NULL), "Asia/Tokyo")
  testthat::expect_identical(maidr:::time_zone_of("Not/A_Zone"), "Asia/Tokyo")
})

test_that("a ggplot2 histogram over dates reads its bins as dates, a day per unit", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- ggplot2_layer(
    ggplot2::ggplot(data.frame(d = days), ggplot2::aes(d)) +
      ggplot2::geom_histogram(binwidth = 7)
  )

  testthat::expect_identical(layer$axes$x$format$unit, "day")
  testthat::expect_identical(layer$axes$x$format, maidr:::time_axis_format("date"))
  testthat::expect_null(layer$axes$y$format)
  # The bins stay the axis's numbers; the format is what draws them.
  testthat::expect_type(layer$data[[1]]$x, "double")
})

test_that("a ggplot2 histogram binned on y over dates formats y", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- ggplot2_layer(
    ggplot2::ggplot(data.frame(d = days), ggplot2::aes(y = d)) +
      ggplot2::geom_histogram(binwidth = 7)
  )

  testthat::expect_identical(layer$orientation, "horz")
  testthat::expect_identical(layer$axes$y$format, maidr:::time_axis_format("date"))
  testthat::expect_null(layer$axes$x$format)
})

test_that("each panel of a faceted ggplot2 histogram over dates reads them as dates", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(
    data.frame(d = days, g = rep(c("a", "b"), 5)),
    ggplot2::aes(d)
  ) +
    ggplot2::geom_histogram(binwidth = 7) +
    ggplot2::facet_wrap(~g)

  for (panel in 1:2) {
    testthat::expect_identical(
      ggplot2_layer(plot, panel)$axes$x$format,
      maidr:::time_axis_format("date")
    )
  }
})

test_that("a ggplot2 histogram over date-times reads them in the scale's zone, a second per unit", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(data.frame(t = new_york), ggplot2::aes(t)) +
    ggplot2::geom_histogram(binwidth = 3600)
  layer <- ggplot2_layer(plot)

  testthat::expect_identical(layer$axes$x$format$unit, "second")
  testthat::expect_identical(
    layer$axes$x$format,
    maidr:::time_axis_format("datetime", "America/New_York")
  )

  # A zone given to the scale is the one its axis is drawn in.
  tokyo <- ggplot2_layer(plot + ggplot2::scale_x_datetime(timezone = "Asia/Tokyo"))
  testthat::expect_identical(
    tokyo$axes$x$format,
    maidr:::time_axis_format("datetime", "Asia/Tokyo")
  )
})

test_that("a ggplot2 histogram over clock times reads them as hh:mm:ss, a second per unit", {
  testthat::skip_if_not_installed("ggplot2")
  # scale_x_time() maps its breaks back through hms.
  testthat::skip_if_not_installed("hms")

  clock <- structure(
    c(600, 900, 1200, 1210, 1800),
    units = "secs",
    class = c("hms", "difftime")
  )
  layer <- ggplot2_layer(
    ggplot2::ggplot(data.frame(h = clock), ggplot2::aes(h)) +
      ggplot2::geom_histogram(binwidth = 600)
  )

  testthat::expect_identical(layer$axes$x$format$unit, "second")
  testthat::expect_identical(layer$axes$x$format, maidr:::time_axis_format("time"))
})

test_that("a Base R histogram over dates reads its bins as dates, a day per unit", {
  layer <- base_r_layer(function() hist(days, "weeks"))

  testthat::expect_identical(layer$axes$x$format$unit, "day")
  testthat::expect_identical(layer$axes$x$format, maidr:::time_axis_format("date"))
  testthat::expect_null(layer$axes$y$format)

  # The values given by name are read as well.
  named <- base_r_layer(function() hist(x = days, breaks = "weeks"))
  testthat::expect_identical(named$axes$x$format, maidr:::time_axis_format("date"))
})

test_that("a Base R histogram over date-times reads them in their zone, a second per unit", {
  # hist() itself refuses clock times ("'x' must be numeric"), so a Base R
  # histogram is of dates or date-times only.
  layer <- base_r_layer(function() hist(new_york, "hours"))

  testthat::expect_identical(layer$axes$x$format$unit, "second")
  testthat::expect_identical(
    layer$axes$x$format,
    maidr:::time_axis_format("datetime", "America/New_York")
  )
})

test_that("a histogram of plain numbers carries no time format", {
  testthat::skip_if_not_installed("ggplot2")

  values <- c(1, 2, 2, 3, 3, 3)
  layer <- ggplot2_layer(
    ggplot2::ggplot(data.frame(v = values), ggplot2::aes(v)) +
      ggplot2::geom_histogram(binwidth = 1)
  )
  testthat::expect_null(layer$axes$x$format)

  testthat::expect_null(base_r_layer(function() hist(values))$axes$x$format)
})
