# A box is named by the label the scale writes, not the level it maps
#
# `scale_x_discrete(labels = )` renames the categories on the axis. The box
# reader took the panel scale's `breaks` -- the raw limits -- so a box was
# announced as `a` while the axis said `Alpha`, and while the line reader on
# the same panel already said `Alpha`.

test_that("scale_x_discrete(labels = ) names the boxes", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(
    data.frame(g = c("a", "a", "b", "b"), y = 1:4),
    ggplot2::aes(g, y)
  ) +
    ggplot2::geom_boxplot() +
    ggplot2::scale_x_discrete(labels = c(a = "Alpha", b = "Beta"))

  layer <- maidr:::Ggplot2PlotOrchestrator$new(p)$generate_maidr_data()$
    subplots[[1]][[1]]$layers[[1]]

  testthat::expect_identical(
    vapply(layer$data, function(box) box$z, character(1)),
    c("Alpha", "Beta")
  )
})
