# A legend titled by its guide is read under that title.
#
# ggplot2 titles a legend by its guide's title first, then by the scale's
# name, then by `labs()`: `guides(fill = guide_colourbar(title =
# "Correlation"))`, or the same guide given to the scale. maidr read none of
# the guide, so the values were announced under the scale's name, `labs()` or
# the mapped column, where the legend says "Correlation".

tiles <- expand.grid(x = c("a", "b"), y = c("p", "q"), stringsAsFactors = FALSE)
tiles$score <- 1:4
heat <- ggplot2::ggplot(tiles, ggplot2::aes(x, y, fill = score)) + ggplot2::geom_tile()

# The z axis title of the plot's first layer, or its name where it has none.
# testthat sources each test file into an environment of its own, so this
# and the `z_title()` in test-ggplot2-legend-scale-name.R do not clash.
z_title <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  layer <- figure$subplots[[1]][[1]]$layers[[1]]
  layer$axes$z$label %||% layer$name
}

test_that("a legend titled by its guide is read under the guide's title", {
  testthat::expect_identical(
    z_title(heat + ggplot2::guides(fill = ggplot2::guide_colourbar(title = "Correlation"))),
    "Correlation"
  )
  testthat::expect_identical(
    z_title(
      heat + ggplot2::scale_fill_gradient(guide = ggplot2::guide_colourbar(title = "Correlation"))
    ),
    "Correlation"
  )

  counts <- data.frame(g = rep(c("A", "B"), each = 2), k = rep(c("u", "v"), 2), n = c(3, 5, 2, 4))
  dodged <- ggplot2::ggplot(counts, ggplot2::aes(g, n, fill = k)) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::guides(fill = ggplot2::guide_legend(title = "Kind"))
  testthat::expect_identical(z_title(dodged), "Kind")
  # The table the description shows is headed by the layer's axis titles.
  figure <- maidr:::Ggplot2PlotOrchestrator$new(dodged)$generate_maidr_data()
  layer <- figure$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_identical(
    vapply(layer$axes, function(axis) axis$label, character(1)),
    c(x = "g", y = "n", z = "Kind")
  )
})

test_that("the guide's title is read over the scale's name and labs(), as drawn", {
  testthat::expect_identical(
    z_title(
      heat + ggplot2::labs(fill = "From labs") +
        ggplot2::scale_fill_gradient(
          name = "From scale", guide = ggplot2::guide_colourbar(title = "From guide")
        )
    ),
    "From guide"
  )

  # A guide named by the plot is the one drawn, so a title given to the
  # scale's guide is not; a guide named by a string has no title of its own.
  testthat::expect_identical(
    z_title(
      heat + ggplot2::guides(fill = "colourbar") +
        ggplot2::scale_fill_gradient(
          name = "From scale", guide = ggplot2::guide_colourbar(title = "Not drawn")
        )
    ),
    "From scale"
  )

  # A guide given no title leaves it to the scale's name.
  testthat::expect_identical(
    z_title(
      heat + ggplot2::scale_fill_gradient(
        name = "From scale", guide = ggplot2::guide_colourbar(title = NULL)
      )
    ),
    "From scale"
  )
})

test_that("a guide for an aesthetic nothing maps gives no title", {
  # ggplot2 3.4 keeps the plot's guide for an aesthetic no layer maps, and a
  # heatmap drawn in one colour was read under the guide's title.
  plain <- ggplot2::ggplot(tiles, ggplot2::aes(x, y)) +
    ggplot2::geom_tile(fill = "steelblue") +
    ggplot2::guides(fill = ggplot2::guide_colourbar(title = "Correlation"))
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plain)$generate_maidr_data()
  layer <- figure$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_null(layer$axes$z)
})

test_that("a plotmath guide title given as a call is read as written", {
  plot <- heat + ggplot2::guides(fill = ggplot2::guide_colourbar(title = bquote(alpha^2)))
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  layer <- figure$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_identical(layer$axes$z$label, "alpha^2")
})

test_that("a title given as a function is read as the title it returns", {
  # ggplot2 3.5 and later title a legend by what a function, or a formula for
  # one, given as the scale's name or the guide's title returns for the title
  # it would otherwise have. Coerced as a string, the function stopped the
  # reading with "cannot coerce type 'closure' to vector of type
  # 'character'"; the scale's name did so before this change, and a guide's
  # title with it. ggplot2 3.4 cannot draw one.
  testthat::skip_if(
    utils::packageVersion("ggplot2") < "3.5.0",
    "ggplot2 3.4 cannot draw a function as a title"
  )
  axes_of <- function(plot) {
    figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
    figure$subplots[[1]][[1]]$layers[[1]]$axes
  }
  testthat::expect_identical(
    axes_of(heat + ggplot2::scale_fill_gradient(name = toupper))$z$label,
    "SCORE"
  )
  testthat::expect_identical(
    axes_of(
      heat + ggplot2::guides(fill = ggplot2::guide_colourbar(title = ~ paste(.x, "(%)")))
    )$z$label,
    "score (%)"
  )
  # The guide's function is handed the scale's name.
  testthat::expect_identical(
    axes_of(
      heat + ggplot2::scale_fill_gradient(name = "Share") +
        ggplot2::guides(fill = ggplot2::guide_colourbar(title = toupper))
    )$z$label,
    "SHARE"
  )
  # A heatmap's axes are titled through the same reading.
  testthat::expect_identical(
    axes_of(heat + ggplot2::scale_x_discrete(toupper))$x$label,
    "X"
  )
})
