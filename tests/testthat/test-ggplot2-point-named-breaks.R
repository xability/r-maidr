# A scatter plot's points on breaks the author named are read by the names.
#
# `scale_x_continuous(breaks = 1:12, labels = month.abb)` codes a month with
# a number, and the axis shows "Feb" where the data holds 2. A line's points
# have been read by those names (#414); a scatter plot's were read by the
# numbers, "month is 2". The number stays the point's position, and the
# name travels beside it in `xLabel` or `yLabel`, as a discrete axis's does.

sales <- data.frame(month = 1:12, sales = c(5, 7, 6, 9, 11, 10, 12, 14, 13, 15, 16, 18))
months <- ggplot2::scale_x_continuous(breaks = 1:12, labels = month.abb)

#' Each panel's points, from the layer at `layer`
panel_points <- function(plot, layer = 1L) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  lapply(unlist(figure$subplots, recursive = FALSE), function(cell) cell$layers[[layer]]$data)
}

#' One field of every point, "" where a point has none
point_field <- function(points, field) {
  vapply(points, function(point) {
    value <- point[[field]]
    if (is.null(value)) "" else as.character(value)
  }, character(1))
}

test_that("points on breaks the author named are read by the names", {
  plot <- ggplot2::ggplot(sales, ggplot2::aes(month, sales)) + ggplot2::geom_point() + months
  points <- panel_points(plot)[[1]]
  testthat::expect_identical(point_field(points, "xLabel"), month.abb)
  # The position is still the number.
  testthat::expect_identical(vapply(points, function(point) point$x, numeric(1)), as.numeric(1:12))

  ratings <- data.frame(item = 1:5, score = c(2, 5, 1, 4, 3))
  rated <- ggplot2::ggplot(ratings, ggplot2::aes(item, score)) +
    ggplot2::geom_point() +
    ggplot2::scale_y_continuous(
      breaks = 1:5, labels = c("Poor", "Fair", "Good", "Very good", "Excellent")
    )
  testthat::expect_identical(
    point_field(panel_points(rated)[[1]], "yLabel"),
    c("Fair", "Excellent", "Poor", "Very good", "Good")
  )
})

test_that("each panel of a facet reads its points by the names", {
  halves <- transform(sales, half = rep(c("H1", "H2"), each = 6))
  plot <- ggplot2::ggplot(halves, ggplot2::aes(month, sales)) +
    ggplot2::geom_point() +
    months +
    ggplot2::facet_wrap(~half)
  panels <- panel_points(plot)
  testthat::expect_identical(point_field(panels[[1]], "xLabel"), month.abb[1:6])
  testthat::expect_identical(point_field(panels[[2]], "xLabel"), month.abb[7:12])
})

test_that("points not all on named breaks, or on labels a function makes, keep their numbers", {
  between <- ggplot2::ggplot(transform(sales, month = month + 0.5), ggplot2::aes(month, sales)) +
    ggplot2::geom_point() +
    months
  testthat::expect_identical(point_field(panel_points(between)[[1]], "xLabel"), rep("", 12))

  formatted <- ggplot2::ggplot(sales, ggplot2::aes(month, sales)) +
    ggplot2::geom_point() +
    ggplot2::scale_x_continuous(breaks = 1:12, labels = function(b) paste0("M", b))
  testthat::expect_identical(point_field(panel_points(formatted)[[1]], "xLabel"), rep("", 12))
})

test_that("points drawn over a line are named as the line's are", {
  plot <- ggplot2::ggplot(sales, ggplot2::aes(month, sales)) +
    ggplot2::geom_line() +
    ggplot2::geom_point() +
    months
  line <- panel_points(plot, 1L)[[1]][[1]]
  testthat::expect_identical(point_field(line, "x"), month.abb)
  testthat::expect_identical(point_field(panel_points(plot, 2L)[[1]], "xLabel"), month.abb)
})
