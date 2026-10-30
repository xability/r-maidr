# A heatmap is reordered by its own x and y, not by its data's first columns.
#
# Before drawing, maidr sorts a heatmap's rows and makes its x and y factors,
# so the tiles come out in the order the reading pairs them with. It took x
# and y to be the data's first two columns. In `data.frame(score, x, y)` the
# fill was made a factor and drawn with a discrete legend, and the rows were
# sorted by the fill, so moving between cells highlighted the wrong tiles.
# Where the tiles draw data of their own, the plot's data is another layer's,
# and that layer's points were moved to discrete positions.

moved <- data.frame(
  score = c(10, 20, 30, 40),
  x = c("a", "b", "a", "b"),
  y = c("p", "p", "q", "q")
)
drawn <- matrix(
  c(30, 40, 10, 20),
  nrow = 2, byrow = TRUE, dimnames = list(c("q", "p"), c("a", "b"))
)

#' Each panel's cells, as a y-by-x matrix named by the axis labels
heat_cells <- function(plot, layer = 1L) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  lapply(unlist(figure$subplots, recursive = FALSE), function(cell) {
    data <- cell$layers[[layer]]$data
    matrix(
      unlist(data$points),
      nrow = length(data$y), byrow = TRUE,
      dimnames = list(unlist(data$y), unlist(data$x))
    )
  })
}

test_that("a heatmap whose x and y are not its data's first columns reads its fill", {
  plot <- ggplot2::ggplot(moved, ggplot2::aes(x, y, fill = score)) + ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(plot), list(drawn))

  shuffled <- ggplot2::ggplot(moved[c("y", "score", "x")], ggplot2::aes(x, y, fill = score)) +
    ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(shuffled), list(drawn))

  column <- "y"
  pronouns <- ggplot2::ggplot(moved, ggplot2::aes(.data$x, .data[[column]], fill = score)) +
    ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(pronouns), list(drawn))
})

test_that("the reordering makes factors of the heatmap's x and y only", {
  plot <- ggplot2::ggplot(moved, ggplot2::aes(x, y, fill = score)) + ggplot2::geom_tile()
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(list(index = 1L))
  reordered <- processor$reorder_layer_data(moved, plot)
  # Sorted by x and then y, the order the tiles are paired with the cells.
  testthat::expect_equal(reordered$score, c(10, 30, 20, 40))
  testthat::expect_type(reordered$score, "double")
  testthat::expect_s3_class(reordered$x, "factor")
  testthat::expect_s3_class(reordered$y, "factor")
})

test_that("tiles drawn from data of their own leave the plot's data alone", {
  points <- data.frame(u = c(1.5, 2.5), v = c(0.7, 1.3))
  tiles <- data.frame(x = c(1, 2, 1, 2), y = c(1, 1, 2, 2), z = c(5, 6, 7, 8))
  plot <- ggplot2::ggplot(points, ggplot2::aes(u, v)) +
    ggplot2::geom_point() +
    ggplot2::geom_tile(data = tiles, ggplot2::aes(x, y, fill = z), inherit.aes = FALSE)
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  scatter <- figure$subplots[[1]][[1]]$layers[[1]]$data
  testthat::expect_equal(vapply(scatter, function(point) point$x, numeric(1)), c(1.5, 2.5))
  testthat::expect_equal(vapply(scatter, function(point) point$y, numeric(1)), c(0.7, 1.3))
})
