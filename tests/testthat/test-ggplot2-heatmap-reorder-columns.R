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

# Each panel's cells, as a y-by-x matrix named by the axis labels
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

test_that("an axis given as an expression is sorted by what it evaluates to", {
  # Unsorted, the rows kept the order they came in, and the tiles were paired
  # with the cells column-major all the same: in an x-fast grid drawn as
  # `aes(toupper(x), y)`, -> from (A, p) highlighted (A, q).
  grid <- data.frame(x = c("a", "b", "a", "b"), y = c("p", "p", "q", "q"), score = c(1, 2, 3, 4))
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(list(index = 1L))
  upper <- ggplot2::ggplot(grid, ggplot2::aes(toupper(x), y, fill = score)) + ggplot2::geom_tile()
  sorted <- processor$reorder_layer_data(grid, upper)
  testthat::expect_identical(paste0(toupper(sorted$x), sorted$y), c("Ap", "Aq", "Bp", "Bq"))
  # The columns themselves are left as they are.
  testthat::expect_type(sorted$x, "character")

  numbers <- data.frame(z = c(5, 6, 7, 8), x = c(2, 1, 2, 1), y = c(1, 1, 2, 2))
  shifted <- ggplot2::ggplot(numbers, ggplot2::aes(x + 0, y, fill = z)) + ggplot2::geom_tile()
  testthat::expect_equal(processor$reorder_layer_data(numbers, shifted)$z, c(6, 8, 5, 7))
})

test_that("a constant position, or .data[[ ]] of a call, leaves the data alone", {
  numbers <- data.frame(z = c(5, 6, 7, 8), x = c(2, 1, 2, 1), y = c(1, 1, 2, 2))
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(list(index = 1L))

  # `aes(x = 1)` stores the constant itself, not a quosure, and reading it
  # as one stopped the chart with "`quo` must be a quosure".
  one <- data.frame(score = c(1, 2, 3), y = c("p", "q", "r"))
  column <- ggplot2::ggplot(one, ggplot2::aes(x = 1, y = y, fill = score)) + ggplot2::geom_tile()
  testthat::expect_identical(processor$reorder_layer_data(one, column), one)
  testthat::expect_equal(unname(heat_cells(column)[[1]][, 1]), c(3, 2, 1))

  # rlang evaluates the index of `.data[[ ]]` when an `aes()` is captured, so
  # a mapping holds `.data[["x"]]`. One built by hand can still hold a call,
  # which names its column only by being called; the reordering does not
  # call it, and leaves the data as it is.
  calls <- 0
  named <- function() {
    calls <<- calls + 1
    "x"
  }
  mapping <- ggplot2::aes(y = y, fill = z)
  mapping$x <- rlang::new_quosure(quote(.data[[named()]]), environment())
  called <- ggplot2::ggplot(numbers, mapping) + ggplot2::geom_tile()
  calls <- 0
  testthat::expect_identical(processor$reorder_layer_data(numbers, called), numbers)
  testthat::expect_equal(calls, 0)
})

test_that("a continuous scale keeps its column numeric, and the chart draws", {
  # Made a factor, a column under `scale_x_continuous()` stopped the chart
  # with "Discrete value supplied to a continuous scale", and no page was
  # written.
  numbers <- data.frame(
    score = c(10, 20, 30, 40), aux = 1:4, x = c(1, 2, 1, 2), y = c(1, 1, 2, 2)
  )
  cells <- matrix(
    c(30, 40, 10, 20),
    nrow = 2, byrow = TRUE, dimnames = list(c("2", "1"), c("1", "2"))
  )
  for (data in list(numbers, numbers[c("x", "y", "score", "aux")])) {
    plot <- ggplot2::ggplot(data, ggplot2::aes(x, y, fill = score)) +
      ggplot2::geom_tile() +
      ggplot2::scale_x_continuous() +
      ggplot2::scale_y_continuous()
    testthat::expect_equal(heat_cells(plot), list(cells))
  }

  # On a continuous scale a tile is drawn at its value, not at an index, so
  # positions that are not 1, 2, ... are matched by value.
  tens <- transform(numbers, x = x * 10)
  plot <- ggplot2::ggplot(tens, ggplot2::aes(x, y, fill = score)) +
    ggplot2::geom_tile(width = 10) +
    ggplot2::scale_x_continuous()
  dimnames(cells)[[2]] <- c("10", "20")
  testthat::expect_equal(heat_cells(plot), list(cells))
})

test_that("tiles drawn from a function of the plot's data leave it alone", {
  # The function is handed the plot's data: made a factor first, its x gave
  # `x + 1` as missing, and the tiles were not drawn.
  numbers <- data.frame(
    score = c(10, 20, 30, 40), aux = c(5, 6, 7, 8), x = c(1, 2, 1, 2), y = c(1, 1, 2, 2)
  )
  plot <- ggplot2::ggplot(numbers) +
    ggplot2::geom_tile(data = function(d) transform(d, x = x + 1), ggplot2::aes(x, y, fill = score))
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(list(index = 1L))
  testthat::expect_identical(processor$reorder_layer_data(numbers, plot), numbers)
  shifted <- matrix(
    c(30, 40, 10, 20),
    nrow = 2, byrow = TRUE, dimnames = list(c("2", "1"), c("2", "3"))
  )
  testthat::expect_equal(heat_cells(plot), list(shifted))
})

test_that("x mapped in the layer and y in the plot, or inherit.aes = FALSE, are both read", {
  split <- ggplot2::ggplot(moved, ggplot2::aes(y = y, fill = score)) +
    ggplot2::geom_tile(ggplot2::aes(x = x))
  testthat::expect_equal(heat_cells(split), list(drawn))

  own <- ggplot2::ggplot(moved, ggplot2::aes(x = score, y = score)) +
    ggplot2::geom_tile(ggplot2::aes(x, y, fill = score), inherit.aes = FALSE)
  testthat::expect_equal(heat_cells(own), list(drawn))
})

test_that("each facet panel of a heatmap whose x and y are not first reads its fill", {
  halves <- rbind(transform(moved, half = "H1"), transform(moved, score = score + 1, half = "H2"))
  plot <- ggplot2::ggplot(halves, ggplot2::aes(x, y, fill = score)) +
    ggplot2::geom_tile() +
    ggplot2::facet_wrap(~half)
  testthat::expect_equal(heat_cells(plot), list(drawn, drawn + 1))
})
