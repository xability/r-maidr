# A heatmap whose grid its stat computes is read from what the stat computed.
#
# `geom_bin_2d()` was read that way (#136), and only by its counts. The other
# stats that compute a grid -- `stat_summary_2d()` and a density drawn as a
# raster, `stat_density_2d(geom = "raster", contour = FALSE)` -- were read as
# tidy heatmaps, one row of the data per tile. Their data is the
# observations, so every cell was read missing, on a grid of one row and one
# column per observation. And the reordering that sorts a tidy heatmap's
# tiles, by making its x and y factors, changed what they drew: the summary
# drew a tile per observation, and the density no tiles at all.

set.seed(1)
cloud <- data.frame(x = stats::rnorm(60), y = stats::rnorm(60), z = stats::runif(60))
cloud_aes <- ggplot2::aes(x, y)

#' The layer maidr reads from the first panel of a plot
heat_layer <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  figure$subplots[[1]][[1]]$layers[[1]]
}

#' A layer's cells, top row first, as maidr emits them
layer_cells <- function(layer) {
  do.call(rbind, lapply(layer$data$points, function(row) {
    vapply(row, function(value) if (is.null(value)) NA_real_ else as.numeric(value), numeric(1))
  }))
}

#' A column of what ggplot2 drew in the first panel, on the same grid
drawn_cells <- function(plot, column) {
  drawn <- ggplot2::ggplot_build(plot)$data[[1]]
  drawn <- drawn[drawn$PANEL == 1, , drop = FALSE]
  xs <- sort(unique(drawn$x))
  ys <- sort(unique(drawn$y), decreasing = TRUE)
  cells <- matrix(NA_real_, length(ys), length(xs))
  cells[cbind(match(drawn$y, ys), match(drawn$x, xs))] <- drawn[[column]]
  cells
}

#' How many tiles ggplot2 draws once maidr has reordered the plot's data
tiles_drawn <- function(plot) {
  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(list(index = 1))
  plot$data <- processor$reorder_layer_data(plot$data, plot)
  nrow(ggplot2::ggplot_build(plot)$data[[1]])
}

test_that("a density raster draws its tiles and is read by their densities", {
  raster <- ggplot2::ggplot(cloud, cloud_aes) +
    ggplot2::stat_density_2d(
      ggplot2::aes(fill = ggplot2::after_stat(density)),
      geom = "raster", contour = FALSE, n = 4
    )
  testthat::expect_equal(tiles_drawn(raster), 16)
  testthat::expect_no_warning(layer <- heat_layer(raster))
  testthat::expect_equal(layer_cells(layer), drawn_cells(raster, "density"))
  testthat::expect_equal(layer$axes$z$label, "density")
})

test_that("a binned summary draws its bins and is read by their values", {
  summary <- ggplot2::ggplot(cloud, ggplot2::aes(x, y, z = z)) + ggplot2::stat_summary_2d(bins = 3)
  testthat::expect_equal(tiles_drawn(summary), nrow(ggplot2::ggplot_build(summary)$data[[1]]))
  layer <- heat_layer(summary)
  testthat::expect_equal(layer_cells(layer), drawn_cells(summary, "value"))
  testthat::expect_equal(layer$axes$z$label, "value")
})

test_that("a binned scatter is read by the variable its fill shows", {
  # It was read by its counts whatever the fill showed, under the fill's
  # title: "density is 4" for a bin holding a fifteenth of the points.
  binned <- ggplot2::ggplot(cloud, cloud_aes) +
    ggplot2::geom_bin_2d(ggplot2::aes(fill = ggplot2::after_stat(density)), bins = 3)
  layer <- heat_layer(binned)
  testthat::expect_equal(layer_cells(layer), drawn_cells(binned, "density"))
  testthat::expect_equal(layer$axes$z$label, "density")

  counted <- ggplot2::ggplot(cloud, cloud_aes) + ggplot2::geom_bin_2d(bins = 3)
  testthat::expect_equal(layer_cells(heat_layer(counted)), drawn_cells(counted, "count"))
})

test_that("a fill computed over the stat's output is evaluated over every panel", {
  # ggplot2 evaluates `after_stat()` once for the whole layer, so each bin is
  # a share of the largest count in any panel.
  sided <- transform(cloud, side = rep(c("left", "right"), 30))
  shares <- ggplot2::ggplot(sided, cloud_aes) +
    ggplot2::geom_bin_2d(ggplot2::aes(fill = ggplot2::after_stat(count / max(count))), bins = 2) +
    ggplot2::facet_wrap(~side)
  drawn <- ggplot2::ggplot_build(shares)$data[[1]]
  figure <- maidr:::Ggplot2PlotOrchestrator$new(shares)$generate_maidr_data()
  panels <- unlist(figure$subplots, recursive = FALSE)
  for (panel in seq_along(panels)) {
    read <- unlist(lapply(panels[[panel]]$layers[[1]]$data$points, unlist))
    counts <- drawn$count[drawn$PANEL == panel]
    testthat::expect_equal(sort(read), sort(counts / max(drawn$count)))
  }
})

test_that("a computed grid with no fill of the stat's is read as missing under no title", {
  # Drawn in one colour, under no legend.
  plain <- ggplot2::ggplot(cloud, cloud_aes) +
    ggplot2::stat_density_2d(geom = "raster", contour = FALSE, n = 3)
  layer <- heat_layer(plain)
  testthat::expect_equal(dim(layer_cells(layer)), c(3, 3))
  testthat::expect_true(all(is.na(layer_cells(layer))))
  testthat::expect_null(layer$axes$z)

  # Read under "value", the title the stat gives the legend it would draw.
  steelblue <- ggplot2::ggplot(cloud, ggplot2::aes(x, y, z = z)) +
    ggplot2::stat_summary_2d(bins = 3, fill = "steelblue")
  layer <- heat_layer(steelblue)
  testthat::expect_true(all(is.na(layer_cells(layer))))
  testthat::expect_null(layer$axes$z)
})

test_that("each cell of a computed grid names the tile drawn for it", {
  # Every bin holds a point, so one selector named all four rects, and the
  # frontend paired them a column at a time with a grid drawn a row at a
  # time: each highlight off the diagonal landed on the other's cell.
  corners <- data.frame(x = c(1, 1, 2, 2, 2, 1), y = c(1, 2, 1, 2, 2, 2))
  full <- ggplot2::ggplot(corners, ggplot2::aes(x, y)) + ggplot2::geom_bin_2d(bins = 2)
  drawn <- ggplot2::ggplot_build(full)$data[[1]]
  selectors <- heat_layer(full)$selectors
  testthat::expect_type(selectors, "list")
  # The grid's rows run from the bottom, as the frontend reads them.
  xs <- sort(unique(drawn$x))
  ys <- sort(unique(drawn$y))
  for (row in seq_along(ys)) {
    for (col in seq_along(xs)) {
      tile <- which(drawn$x == xs[col] & drawn$y == ys[row])
      testthat::expect_match(selectors[[row]][[col]], paste0(":nth-of-type\\(", tile, "\\)$"))
    }
  }
})
