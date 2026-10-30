# A scatter plot coloured by a number is read with each point's colour value.
#
# `aes(colour = depth)` draws each point in a colour read off the legend's
# colour bar. The point carried its value only as text in `color`, which
# maidr.js does not read, so a reader heard nothing of it and the legend had
# no title in the reading. Each point now carries the value as its `z`,
# under the legend's title.

soundings <- data.frame(
  x = 1:6, y = c(2, 4, 3, 5, 4, 6),
  depth = c(1.5, 2, 3.5, 4, 5.5, 6),
  half = rep(c("H1", "H2"), each = 3),
  kind = rep(c("u", "v"), 3)
)

#' Each panel's first layer
panel_layers <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  lapply(unlist(figure$subplots, recursive = FALSE), function(cell) cell$layers[[1]])
}

#' The `z` of every point, NA where a point has none
point_z <- function(layer) {
  vapply(layer$data, function(point) if (is.null(point$z)) NA_real_ else point$z, numeric(1))
}

test_that("points coloured by a number carry it as z, under the legend's title", {
  plot <- ggplot2::ggplot(soundings, ggplot2::aes(x, y, colour = depth)) + ggplot2::geom_point()
  layer <- panel_layers(plot)[[1]]
  testthat::expect_identical(point_z(layer), soundings$depth)
  testthat::expect_identical(layer$axes$z$label, "depth")

  titled <- panel_layers(plot + ggplot2::labs(colour = "Depth (m)"))[[1]]
  testthat::expect_identical(titled$axes$z$label, "Depth (m)")
})

test_that("each facet panel's points carry their own colour values", {
  plot <- ggplot2::ggplot(soundings, ggplot2::aes(x, y, colour = depth)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~half)
  layers <- panel_layers(plot)
  testthat::expect_identical(point_z(layers[[1]]), soundings$depth[1:3])
  testthat::expect_identical(point_z(layers[[2]]), soundings$depth[4:6])
  testthat::expect_identical(layers[[1]]$axes$z$label, "depth")
})

test_that("points coloured by group are still read as a layer per group, with no z", {
  plot <- ggplot2::ggplot(soundings, ggplot2::aes(x, y, colour = kind)) + ggplot2::geom_point()
  layers <- panel_layers(plot)
  testthat::expect_true(all(is.na(point_z(layers[[1]]))))
  testthat::expect_null(layers[[1]]$axes$z)
})
