# A flipped scatter plot names each point by the category its axis shows.
#
# coord_flip() draws the x scale up the side, in the panel's `y` slot, and
# the category names were read from the slot. `aes(group, value)` flipped
# gave the values the group names, 1, 2 and 3 read "a", "b" and "c", and
# left the groups as their positions.

groups <- data.frame(group = c("a", "b", "c"), value = c(1, 2, 3))

#' The first panel's points
first_points <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  figure$subplots[[1]][[1]]$layers[[1]]$data
}

#' One field of every point, "" where a point has none
point_field <- function(points, field) {
  vapply(points, function(point) {
    value <- point[[field]]
    if (is.null(value)) "" else as.character(value)
  }, character(1))
}

test_that("a flipped scatter plot names its points by their categories", {
  plot <- ggplot2::ggplot(groups, ggplot2::aes(group, value)) +
    ggplot2::geom_point() +
    ggplot2::coord_flip()
  points <- first_points(plot)
  testthat::expect_identical(point_field(points, "xLabel"), c("a", "b", "c"))
  testthat::expect_identical(point_field(points, "yLabel"), rep("", 3))
})

test_that("a flipped scatter plot with categories on y names its points by them", {
  plot <- ggplot2::ggplot(groups, ggplot2::aes(value, group)) +
    ggplot2::geom_point() +
    ggplot2::coord_flip()
  points <- first_points(plot)
  testthat::expect_identical(point_field(points, "yLabel"), c("a", "b", "c"))
  testthat::expect_identical(point_field(points, "xLabel"), rep("", 3))
})

test_that("jittered points on a flipped category axis keep their categories", {
  plot <- ggplot2::ggplot(groups, ggplot2::aes(group, value)) +
    ggplot2::geom_jitter(width = 0.2, height = 0) +
    ggplot2::coord_flip()
  points <- first_points(plot)
  testthat::expect_identical(point_field(points, "xLabel"), c("a", "b", "c"))
  testthat::expect_identical(point_field(points, "yLabel"), rep("", 3))
})
