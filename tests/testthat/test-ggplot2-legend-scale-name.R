# A legend titled by its scale's name is read under that name.
#
# ggplot2 titles a legend by the scale's name before `labs()`:
# `scale_fill_gradient(name = "Correlation")`, or `scale_fill_viridis_c(
# "Correlation")` with the name given first. maidr read only `labs()` and the
# mapping, so a heatmap's values were announced under the mapped column,
# "score", where the legend says "Correlation", and a scale's name lost to a
# `labs()` title ggplot2 does not draw.

tiles <- expand.grid(x = c("a", "b"), y = c("p", "q"), stringsAsFactors = FALSE)
tiles$score <- 1:4
counts <- data.frame(g = rep(c("A", "B"), each = 2), k = rep(c("u", "v"), 2), n = c(3, 5, 2, 4))

#' The z axis title of the plot's first layer
z_title <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  figure$subplots[[1]][[1]]$layers[[1]]$axes$z$label
}

test_that("a heatmap's legend titled by its scale's name is read under it", {
  heat <- ggplot2::ggplot(tiles, ggplot2::aes(x, y, fill = score)) + ggplot2::geom_tile()
  testthat::expect_identical(
    z_title(heat + ggplot2::scale_fill_gradient(name = "Correlation")),
    "Correlation"
  )
  testthat::expect_identical(
    z_title(heat + ggplot2::scale_fill_viridis_c("Correlation")),
    "Correlation"
  )

  # The scale's name is drawn over a `labs()` title.
  testthat::expect_identical(
    z_title(
      heat + ggplot2::labs(fill = "From labs") +
        ggplot2::scale_fill_gradient(name = "From scale")
    ),
    "From scale"
  )

  # A scale given no name leaves the title to `labs()` and the mapping.
  testthat::expect_identical(z_title(heat + ggplot2::scale_fill_gradient(name = NULL)), "score")
  testthat::expect_identical(
    z_title(heat + ggplot2::labs(fill = "From labs") + ggplot2::scale_fill_gradient()),
    "From labs"
  )
})

test_that("bars grouped by fill are read under the fill scale's name", {
  bars <- ggplot2::ggplot(counts, ggplot2::aes(g, n, fill = k))
  testthat::expect_identical(
    z_title(
      bars + ggplot2::geom_col(position = "dodge") +
        ggplot2::scale_fill_manual(name = "Kind", values = c("red", "blue"))
    ),
    "Kind"
  )
  testthat::expect_identical(
    z_title(bars + ggplot2::geom_col() + ggplot2::scale_fill_brewer("Kind")),
    "Kind"
  )
})

test_that("an area is titled by the fill scale only where it maps fill", {
  series <- data.frame(
    x = rep(1:5, 2), y = c(2, 4, 3, 5, 4, 1, 2, 2, 3, 2), k = rep(c("u", "v"), each = 5)
  )
  stacked <- ggplot2::ggplot(series, ggplot2::aes(x, y, fill = k)) +
    ggplot2::geom_area() +
    ggplot2::scale_fill_manual(name = "Kind", values = c("red", "blue"))
  testthat::expect_identical(z_title(stacked), "Kind")

  # Without a mapped fill there is no legend, so neither a scale nor
  # `labs()` given for one titles anything.
  single <- ggplot2::ggplot(series[series$k == "u", ], ggplot2::aes(x, y)) +
    ggplot2::geom_area(fill = "steelblue")
  testthat::expect_null(
    z_title(single + ggplot2::scale_fill_manual(name = "Unmapped", values = "red"))
  )
  testthat::expect_null(suppressMessages(z_title(single + ggplot2::labs(fill = "Unmapped"))))
})
