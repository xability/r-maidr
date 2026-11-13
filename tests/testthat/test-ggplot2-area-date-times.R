# An area over dates or date-times was read in its axis's own numbers.
#
# ggplot2 builds a date axis in days since 1970 and a date-time axis in
# seconds, and `geom_area()` wrote its x straight from the built data: a
# band over `POSIXct` read "t is 1,767,243,600" and one over `Date` "d is
# 20,454", where a line over the same column read the date. The area now
# writes each x back through the scale as the line does (`time_text()`), so
# a move between the two lands on the same x.

times <- as.POSIXct("2026-01-01", tz = "America/New_York") + 3600 * (0:3)
with_times <- c(
  "2026-01-01 00:00:00", "2026-01-01 01:00:00",
  "2026-01-01 02:00:00", "2026-01-01 03:00:00"
)

area_layers <- function(plot) {
  maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()$subplots[[1]][[1]]$layers
}

# The x of every point of a layer, series after series.
layer_xs <- function(layer) {
  rows <- layer$data
  if (length(rows) && is.list(rows[[1]]) && is.null(names(rows[[1]]))) {
    rows <- unlist(rows, recursive = FALSE)
  }
  vapply(rows, function(point) as.character(point$x), character(1))
}

test_that("an area over date-times writes them as date-times", {
  testthat::skip_if_not_installed("ggplot2")

  layers <- area_layers(
    ggplot2::ggplot(data.frame(t = times, y = c(3, 1, 4, 1)), ggplot2::aes(t, y)) +
      ggplot2::geom_area()
  )

  testthat::expect_identical(layers[[1]]$type, "area")
  testthat::expect_identical(layer_xs(layers[[1]]), with_times)
})

test_that("an area over dates writes them as dates", {
  testthat::skip_if_not_installed("ggplot2")

  layers <- area_layers(
    ggplot2::ggplot(
      data.frame(d = as.Date("2026-01-01") + 0:2, y = c(3, 1, 4)),
      ggplot2::aes(d, y)
    ) +
      ggplot2::geom_area()
  )

  testthat::expect_identical(
    layer_xs(layers[[1]]),
    c("2026-01-01", "2026-01-02", "2026-01-03")
  )
})

test_that("an area and a line over the same date-times write the same x", {
  skip_if_no_render()

  # A move between layers finds the same x in the next one. Read from the
  # page, as maidr.js is given it.
  html <- rendered(
    ggplot2::ggplot(data.frame(t = times, y = c(3, 1, 4, 1)), ggplot2::aes(t, y)) +
      ggplot2::geom_area() +
      ggplot2::geom_line()
  )
  testthat::expect_false(fell_back(html))
  layers <- layers_from(html)

  testthat::expect_identical(layer_xs(layers[[1]]), with_times)
  testthat::expect_identical(layer_xs(layers[[2]]), with_times)
})

test_that("an area drawn in the scale's time zone writes the line's x", {
  testthat::skip_if_not_installed("ggplot2")

  layers <- area_layers(
    ggplot2::ggplot(data.frame(t = times, y = c(3, 1, 4, 1)), ggplot2::aes(t, y)) +
      ggplot2::geom_area() +
      ggplot2::geom_line() +
      ggplot2::scale_x_datetime(timezone = "Asia/Tokyo")
  )

  testthat::expect_identical(layer_xs(layers[[1]])[1], "2026-01-01 14:00:00")
  testthat::expect_identical(layer_xs(layers[[1]]), layer_xs(layers[[2]]))
})

test_that("each band of a stacked area over date-times writes them as date-times", {
  testthat::skip_if_not_installed("ggplot2")

  frame <- data.frame(
    t = rep(times, 2),
    y = c(3, 1, 4, 1, 2, 2, 2, 2),
    g = rep(c("a", "b"), each = 4)
  )
  layers <- area_layers(
    ggplot2::ggplot(frame, ggplot2::aes(t, y, fill = g)) + ggplot2::geom_area()
  )

  testthat::expect_identical(layers[[1]]$type, "stacked_area")
  for (series in layers[[1]]$data) {
    testthat::expect_identical(
      vapply(series, function(point) as.character(point$x), character(1)),
      with_times
    )
  }
})

test_that("each facet panel of an area over dates writes them as dates", {
  testthat::skip_if_not_installed("ggplot2")

  frame <- data.frame(
    d = rep(as.Date("2026-01-01") + 0:2, 2),
    y = c(3, 1, 4, 2, 2, 2),
    g = rep(c("a", "b"), each = 3)
  )
  schema <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(frame, ggplot2::aes(d, y)) +
      ggplot2::geom_area() +
      ggplot2::facet_wrap(~g)
  )$generate_maidr_data()

  testthat::expect_length(schema$subplots[[1]], 2L)
  for (cell in schema$subplots[[1]]) {
    testthat::expect_identical(
      layer_xs(cell$layers[[1]]),
      c("2026-01-01", "2026-01-02", "2026-01-03")
    )
  }
})

test_that("an area over plain numbers still writes numbers", {
  testthat::skip_if_not_installed("ggplot2")

  layers <- area_layers(
    ggplot2::ggplot(data.frame(x = 1:3, y = c(3, 1, 4)), ggplot2::aes(x, y)) +
      ggplot2::geom_area()
  )

  testthat::expect_identical(
    vapply(layers[[1]]$data[[1]], function(point) point$x, numeric(1)),
    c(1, 2, 3)
  )
})
