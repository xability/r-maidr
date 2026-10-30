# A line is read by the names its axis gives the ticks its points sit on.
#
# An axis whose ticks the author named with text codes a category with a
# number. ggplot2's `scale_x_continuous(breaks = 1:12, labels = month.abb)`
# draws "Feb" under the point whose x is 2, and Base R's `axis(2, at = 1:5,
# labels = c("N3", "N2", "N1", "REM", "Awake"))` draws "N1" beside the point
# whose y is 3. maidr announced the numbers, "Month is 2" and "Sleep stage is
# 3", where the axes show the names. When every point sits on a named tick,
# the points are now read by the names; a point between ticks, or labels a
# function formats the numbers with, keep every point's number.

#' The x of every point of each series of each subplot's first layer
gg_line_x <- function(plot) {
  data <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  cells <- unlist(data$subplots, recursive = FALSE)
  lapply(cells, function(cell) {
    lapply(cell$layers[[1]]$data, function(series) lapply(series, function(point) point$x))
  })
}

MONTHS <- data.frame(
  month = rep(1:12, 2),
  sales = c(120, 150, 180, 200, 220, 250, 230, 210, 190, 170, 160, 180, 80:91),
  product = rep(c("A", "B"), each = 12)
)

test_that("a ggplot2 line on breaks the author named is read by the names", {
  named <- ggplot2::scale_x_continuous(breaks = 1:12, labels = month.abb)

  single <- gg_line_x(
    ggplot2::ggplot(MONTHS[MONTHS$product == "A", ], ggplot2::aes(month, sales)) +
      ggplot2::geom_line() + named
  )
  testthat::expect_identical(unlist(single), month.abb)

  # Each series, and each facet's panel, the same way.
  series <- gg_line_x(
    ggplot2::ggplot(MONTHS, ggplot2::aes(month, sales, colour = product)) +
      ggplot2::geom_line() + named
  )
  testthat::expect_length(series[[1]], 2)
  testthat::expect_identical(unlist(series), rep(month.abb, 2))

  panels <- gg_line_x(
    ggplot2::ggplot(MONTHS, ggplot2::aes(month, sales)) +
      ggplot2::geom_line() + ggplot2::facet_wrap(~product) + named
  )
  testthat::expect_length(panels, 2)
  testthat::expect_identical(unlist(panels[[1]]), month.abb)
  testthat::expect_identical(unlist(panels[[2]]), month.abb)
})

test_that("a ggplot2 line keeps its numbers unless every point is on a named break", {
  between <- gg_line_x(
    ggplot2::ggplot(data.frame(x = c(1, 1.5, 2, 3), y = 1:4), ggplot2::aes(x, y)) +
      ggplot2::geom_line() +
      ggplot2::scale_x_continuous(breaks = 1:3, labels = c("one", "two", "three"))
  )
  testthat::expect_identical(unlist(between), c(1, 1.5, 2, 3))

  # Labels a function makes from the numbers format them; they name nothing.
  formatted <- gg_line_x(
    ggplot2::ggplot(data.frame(x = c(2.5, 5, 7.5, 10), y = 1:4), ggplot2::aes(x, y)) +
      ggplot2::geom_line() +
      ggplot2::scale_x_continuous(labels = function(b) paste(b, "km"))
  )
  testthat::expect_identical(unlist(formatted), c(2.5, 5, 7.5, 10))
})

STAGES <- c("N3", "N2", "N1", "REM", "Awake")

test_that("a Base R line on y ticks the author named is read by the names", {
  layer <- base_r_layers(function() {
    hours <- seq(0, 3, by = 0.5)
    stage <- c(5, 3, 2, 1, 2, 4, 5)
    plot(hours, stage, type = "s", yaxt = "n")
    axis(2, at = seq_along(STAGES), labels = STAGES, las = 1)
  })[[1]]

  points <- layer$data[[1]]
  testthat::expect_identical(layer$type, "step")
  # Read by the stage's name; the number stays, for the tone and braille.
  testthat::expect_identical(
    vapply(points, function(point) point$label, character(1)),
    c("Awake", "N1", "N2", "N3", "N2", "REM", "Awake")
  )
  testthat::expect_identical(
    vapply(points, function(point) point$y, numeric(1)),
    c(5, 3, 2, 1, 2, 4, 5)
  )
})

test_that("a Base R line on ticks named by a factor is read by the names R draws", {
  # R draws a factor given as `labels` by its values' names, and a date as
  # it prints (`as.graphicsAnnot()`). Only text labels were read, so these
  # lines were read by their numbers.
  stage_labels <- function(layer) {
    vapply(layer$data[[1]], function(point) {
      if (is.null(point$label)) "" else point$label
    }, character(1))
  }
  as_factor <- base_r_layers(function() {
    plot(1:4, c(3, 1, 2, 3), type = "l", yaxt = "n")
    axis(2, at = 1:3, labels = factor(c("low", "mid", "high"), levels = c("high", "mid", "low")))
  })[[1]]
  testthat::expect_identical(stage_labels(as_factor), c("high", "low", "mid", "high"))

  as_dates <- base_r_layers(function() {
    plot(1:3, c(2, 1, 3), type = "l", yaxt = "n")
    axis(2, at = 1:3, labels = as.Date("2024-01-01") + 0:2)
  })[[1]]
  testthat::expect_identical(
    stage_labels(as_dates),
    c("2024-01-02", "2024-01-01", "2024-01-03")
  )
})

test_that("a Base R line keeps its numbers unless every point is on a named tick", {
  labels_of <- function(layer) {
    unlist(lapply(layer$data[[1]], function(point) point$label))
  }

  between <- base_r_layers(function() {
    plot(1:4, c(10, 25, 50, 75), type = "l", yaxt = "n")
    axis(2, at = c(0, 50, 100), labels = c("low", "mid", "high"))
  })[[1]]
  testthat::expect_null(labels_of(between))

  numbered <- base_r_layers(function() {
    plot(1:5, c(1, 3, 2, 5, 4), type = "l", yaxt = "n")
    axis(2, at = 1:5)
  })[[1]]
  testthat::expect_null(labels_of(numbered))
})

test_that("the lines of one Base R layer are named only when all of them can be", {
  # matplot() draws its columns as one layer of several lines, read as one:
  # a point off the ticks in one line leaves every line its numbers.
  labels_of <- function(layer) {
    unlist(lapply(layer$data, function(series) lapply(series, function(point) point$label)))
  }
  levels_drawn <- function(b) {
    function() {
      matplot(1:3, cbind(a = c(1, 2, 3), b = b), type = "l", yaxt = "n")
      axis(2, at = 1:3, labels = c("low", "mid", "high"))
    }
  }

  on_ticks <- base_r_layers(levels_drawn(c(3, 2, 1)))[[1]]
  testthat::expect_length(on_ticks$data, 2)
  testthat::expect_identical(
    labels_of(on_ticks),
    c("low", "mid", "high", "high", "mid", "low")
  )

  one_off <- base_r_layers(levels_drawn(c(3, 2.5, 1)))[[1]]
  testthat::expect_length(one_off$data, 2)
  testthat::expect_null(labels_of(one_off))
})
