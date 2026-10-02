# A layer is read under the plot's axis title unless it is one of several
# layers that plot different things on that axis (#349)
#
# A layer's own `aes(y = ...)` used to replace the axis title outright, so
# `geom_histogram(aes(y = after_stat(density))) + labs(y = "Density")` was
# announced as "after_stat(density) is 0.07" while the axis said "Density".
# The layer's own name is only worth more than the title when another layer
# plots something else on the same axis, as in
# `geom_col(aes(y = sales)) + geom_line(aes(y = target))`.

layer_axis_labels <- function(plot) {
  layers <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()$
    subplots[[1]][[1]]$layers
  lapply(layers, function(layer) {
    c(x = layer$axes$x$label, y = layer$axes$y$label)
  })
}

y_labels <- function(plot) {
  vapply(layer_axis_labels(plot), function(axes) axes[["y"]], character(1))
}

density_labs <- function() {
  ggplot2::labs(
    title = "Highway mileage",
    x = "Highway miles per gallon",
    y = "Density"
  )
}

test_that("a one-layer plot keeps its labs() title for a stat mapping", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 15
    ) +
    density_labs()

  testthat::expect_identical(y_labels(p), "Density")
})

test_that("the same mapping at the top level reads the same", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(
    ggplot2::mpg,
    ggplot2::aes(hwy, ggplot2::after_stat(density))
  ) +
    ggplot2::geom_histogram(bins = 15) +
    density_labs()

  testthat::expect_identical(y_labels(p), "Density")
})

test_that("a histogram's stat mapping agrees with the density curve over it", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 15
    ) +
    ggplot2::geom_density() +
    density_labs()

  labels <- layer_axis_labels(p)
  testthat::expect_length(labels, 2)
  for (axes in labels) {
    testthat::expect_identical(
      axes,
      c(x = "Highway miles per gallon", y = "Density")
    )
  }
})

test_that("the two layers with the mapping at the top level read the same", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(
    ggplot2::mpg,
    ggplot2::aes(hwy, ggplot2::after_stat(density))
  ) +
    ggplot2::geom_histogram(bins = 15) +
    ggplot2::geom_density() +
    density_labs()

  testthat::expect_identical(y_labels(p), c("Density", "Density"))
})

test_that("two layers mapping the same stat each keep the labs() title", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(count)),
      bins = 15
    ) +
    ggplot2::geom_freqpoly(
      ggplot2::aes(y = ggplot2::after_stat(count)),
      bins = 15
    ) +
    ggplot2::labs(y = "Number of cars")

  testthat::expect_identical(
    y_labels(p),
    c("Number of cars", "Number of cars")
  )
})

test_that("a layer mapping x itself keeps the labs() x title", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg) +
    ggplot2::geom_histogram(ggplot2::aes(x = hwy), bins = 15) +
    ggplot2::labs(x = "Highway miles per gallon")

  testthat::expect_identical(
    layer_axis_labels(p)[[1]][["x"]],
    "Highway miles per gallon"
  )
})

sales <- function() {
  data.frame(
    month = factor(month.abb[1:6], levels = month.abb[1:6]),
    sales = c(10, 12, 9, 14, 15, 13),
    target = c(11, 11, 12, 12, 13, 13)
  )
}

test_that("layers that agree on what they plot share the labs() title", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(sales()) +
    ggplot2::geom_line(ggplot2::aes(month, sales, group = 1)) +
    ggplot2::geom_point(ggplot2::aes(month, sales)) +
    ggplot2::labs(x = "Month", y = "Units sold")

  for (axes in layer_axis_labels(p)) {
    testthat::expect_identical(axes, c(x = "Month", y = "Units sold"))
  }
})

test_that("layers plotting different variables are each named for theirs", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(sales(), ggplot2::aes(month)) +
    ggplot2::geom_col(ggplot2::aes(y = sales)) +
    ggplot2::geom_line(ggplot2::aes(y = target, group = 1))

  testthat::expect_identical(y_labels(p), c("sales", "target"))

  # The one axis title cannot tell them apart, so it does not replace them.
  testthat::expect_identical(
    y_labels(p + ggplot2::labs(y = "Units")),
    c("sales", "target")
  )
})

test_that("a stat mapping named for itself is named as ggplot2 names it", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 15
    ) +
    ggplot2::geom_line(ggplot2::aes(y = cty / 100))

  testthat::expect_identical(y_labels(p), c("density", "cty/100"))
})

test_that("mapping_label() drops the stage and the old computed spellings", {
  testthat::skip_if_not_installed("ggplot2")

  label <- function(mapping) maidr:::mapping_label(mapping)

  testthat::expect_identical(label(rlang::quo(after_stat(density))), "density")
  testthat::expect_identical(label(rlang::quo(after_scale(fill))), "fill")
  testthat::expect_identical(label(rlang::quo(stat(density))), "density")
  testthat::expect_identical(label(rlang::quo(..density..)), "density")
  testthat::expect_identical(
    label(rlang::quo(..count.. / sum(..count..))),
    "count/sum(count)"
  )
  testthat::expect_identical(
    label(rlang::quo(stage(hwy, after_stat = density))),
    "density"
  )
  testthat::expect_identical(label(rlang::quo(stage(hwy))), "hwy")
  testthat::expect_identical(label(rlang::quo(.data$hwy)), "hwy")
  testthat::expect_identical(label(rlang::quo(.data[["hwy"]])), "hwy")
  testthat::expect_identical(label(rlang::quo(log(hwy))), "log(hwy)")
  testthat::expect_identical(label(rlang::quo(x[, 1])), "x[, 1]")
  testthat::expect_null(label(NULL))
})

test_that("mapping_label() names what ggplot2 names the axis after", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 15
    )

  testthat::expect_identical(
    maidr:::mapping_label(p$layers[[1]]$mapping$y),
    ggplot2::ggplot_build(p)$plot$labels$y
  )
})

test_that("a layer with no axis title is named for its own mapping", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg) +
    ggplot2::geom_histogram(
      ggplot2::aes(hwy, ggplot2::after_stat(density)),
      bins = 15
    )

  testthat::expect_identical(maidr:::layer_axis_label(p, 1, "y", ""), "density")
  testthat::expect_identical(
    maidr:::layer_axis_label(p, 1, "y", "Density"),
    "Density"
  )
})
