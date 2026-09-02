# A facet panel with no rows is read as empty, and a faceted layer is read
# as the type it was detected as
#
# `facet_wrap(~ g, drop = FALSE)` draws a panel for a level the data never
# reaches. `get_layer_built_data()` answered the whole frame for it -- every
# other panel's rows -- so an empty panel described the rest of the grid as
# its own series.
#
# The facet and patchwork paths also handed each processor the geom's class
# as `layer_info$type`, where the single-plot path hands the detected type.
# The stacked bar reader announces proportions only when that type is
# `stacked_normalized_bar`, so a faceted `position = "fill"` chart announced
# counts.

facet_layers <- function(p) {
  subplots <- maidr:::Ggplot2PlotOrchestrator$new(p)$generate_maidr_data()$subplots
  lapply(subplots[[1]], function(cell) cell$layers)
}

test_that("an area panel with no rows has no series in it", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(1:4, 2),
    y = 1:8,
    g = factor(rep(c("a", "b"), each = 4), levels = c("a", "b", "c"))
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_area() +
    ggplot2::facet_wrap(~g, drop = FALSE)

  cells <- facet_layers(p)
  testthat::expect_length(cells, 3L)
  testthat::expect_length(cells[[1]][[1]]$data[[1]], 4L)
  testthat::expect_length(cells[[2]][[1]]$data[[1]], 4L)
  testthat::expect_length(cells[[3]], 0L)
})

test_that("a faceted position = 'fill' bar announces proportions", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    f = rep(c("u", "v"), 2),
    n = c(2, 1, 1, 2),
    g = "one"
  )
  base <- ggplot2::ggplot(df, ggplot2::aes(x, n, fill = f)) +
    ggplot2::geom_col(position = "fill")

  values_of <- function(layer) {
    unname(unlist(lapply(layer$data, function(series) {
      vapply(series, function(point) point$y, numeric(1))
    })))
  }
  plain <- maidr:::Ggplot2PlotOrchestrator$new(base)$generate_maidr_data()$
    subplots[[1]][[1]]$layers[[1]]
  faceted <- facet_layers(base + ggplot2::facet_wrap(~g))[[1]][[1]]

  testthat::expect_identical(faceted$type, "stacked_normalized_bar")
  testthat::expect_equal(values_of(faceted), values_of(plain))
  testthat::expect_true(all(values_of(faceted) <= 1))
})

test_that("a smooth or line panel with no rows has no series in it", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = 1:10,
    y = (1:10)^1.5,
    g = factor("a", levels = c("a", "b"))
  )
  base <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::facet_wrap(~g, drop = FALSE)

  smooth <- facet_layers(
    base + ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE)
  )
  testthat::expect_length(smooth[[1]][[1]]$data, 1L)
  testthat::expect_length(smooth[[2]], 0L)

  line <- facet_layers(base + ggplot2::geom_line())
  testthat::expect_length(line[[1]][[1]]$data[[1]], 10L)
  testthat::expect_length(line[[2]], 0L)
})
