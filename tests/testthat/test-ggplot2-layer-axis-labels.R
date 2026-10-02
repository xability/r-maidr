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
  testthat::expect_identical(label(rlang::quo(log(.data$hwy))), "log(hwy)")
  column <- "hwy"
  testthat::expect_identical(label(rlang::quo(log(.data[[column]]))), "log(hwy)")
  testthat::expect_identical(label(rlang::quo(log(hwy))), "log(hwy)")
  testthat::expect_identical(label(rlang::quo(x[, 1])), "x[, 1]")
  testthat::expect_null(label(NULL))
})

test_that("a long mapping is named past where rlang::as_label() would stop", {
  testthat::skip_if_not_installed("ggplot2")

  week <- rlang::quo(rolling_mean(daily_new_cases_per_100k, window = 7, align = "right"))
  month <- rlang::quo(rolling_mean(daily_new_cases_per_100k, window = 28, align = "right"))

  testthat::expect_false(identical(maidr:::mapping_label(week), maidr:::mapping_label(month)))
  testthat::expect_false(identical(maidr:::mapping_key(week), maidr:::mapping_key(month)))
  testthat::expect_identical(
    maidr:::mapping_key(rlang::quo(after_stat(.data$density))),
    maidr:::mapping_key(rlang::quo(..density..))
  )
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

test_that("decoration does not make a one-layer chart a several-layer one", {
  testthat::skip_if_not_installed("ggplot2")

  histogram <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 15
    ) +
    ggplot2::annotate("segment", x = 30, xend = 35, y = 0.05, yend = 0.07) +
    density_labs()
  testthat::expect_identical(y_labels(histogram), "Density")

  annotated <- ggplot2::ggplot(sales()) +
    ggplot2::geom_col(ggplot2::aes(month, sales)) +
    ggplot2::annotate("text", x = 3, y = 16, label = "peak") +
    ggplot2::labs(x = "Month", y = "Units sold")
  testthat::expect_identical(
    layer_axis_labels(annotated)[[1]],
    c(x = "Month", y = "Units sold")
  )

  labelled <- ggplot2::ggplot(sales()) +
    ggplot2::geom_col(ggplot2::aes(month, sales)) +
    ggplot2::geom_text(ggplot2::aes(month, sales + 0.5, label = sales)) +
    ggplot2::labs(x = "Month", y = "Units sold")
  testthat::expect_identical(
    layer_axis_labels(labelled)[[1]],
    c(x = "Month", y = "Units sold")
  )

  # Layers that do plot different things keep their names beside it
  two <- ggplot2::ggplot(sales(), ggplot2::aes(month)) +
    ggplot2::geom_col(ggplot2::aes(y = sales)) +
    ggplot2::geom_line(ggplot2::aes(y = target, group = 1)) +
    ggplot2::annotate("text", x = 3, y = 16, label = "peak")
  testthat::expect_identical(y_labels(two), c("sales", "target"))
})

test_that("a function curve over a density histogram shares its title", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 15
    ) +
    ggplot2::stat_function(
      fun = stats::dnorm,
      args = list(mean = mean(ggplot2::mpg$hwy), sd = stats::sd(ggplot2::mpg$hwy))
    ) +
    density_labs()

  testthat::expect_identical(y_labels(p), c("Density", "Density"))
})

test_that("a layer mapping y itself beside one inheriting another y is named for it", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(displ, cty)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(
      ggplot2::aes(y = hwy),
      method = "lm", formula = y ~ x, se = FALSE
    ) +
    ggplot2::labs(y = "City miles per gallon")

  testthat::expect_identical(y_labels(p), c("City miles per gallon", "hwy"))
})

test_that("line layers read as one are named by the axis title when they differ", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(sales(), ggplot2::aes(month, group = 1)) +
    ggplot2::geom_line(ggplot2::aes(y = sales)) +
    ggplot2::geom_line(ggplot2::aes(y = target), linetype = 2)

  # Both series are in the one layer, so neither name describes it
  testthat::expect_identical(y_labels(p + ggplot2::labs(y = "Units")), "Units")
  testthat::expect_identical(y_labels(p), "sales")
})

test_that("a title from a plot mapping no layer plots does not name the layer", {
  testthat::skip_if_not_installed("ggplot2")

  # ggplot2 before 4.0 titled this axis "sales", after the unused plot mapping
  p <- ggplot2::ggplot(sales(), ggplot2::aes(month, sales)) +
    ggplot2::geom_col(ggplot2::aes(y = target))

  testthat::expect_identical(maidr:::layer_axis_label(p, 1, "y", "sales"), "target")
  testthat::expect_identical(maidr:::layer_axis_label(p, 1, "y", "Target"), "Target")
})

test_that("facet and patchwork panels read as one entry are named by the axis title", {
  testthat::skip_if_not_installed("ggplot2")

  two_lines <- function(data) {
    ggplot2::ggplot(data, ggplot2::aes(month, group = 1)) +
      ggplot2::geom_line(ggplot2::aes(y = sales)) +
      ggplot2::geom_line(ggplot2::aes(y = target), linetype = 2) +
      ggplot2::labs(y = "Units")
  }
  panel_y_labels <- function(plot) {
    data <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
    unlist(lapply(data$subplots, function(row) {
      lapply(row, function(cell) {
        vapply(cell$layers, function(layer) layer$axes$y$label, character(1))
      })
    }))
  }

  faceted <- rbind(
    transform(sales(), region = "North"),
    transform(sales(), region = "South")
  )
  testthat::expect_identical(
    panel_y_labels(two_lines(faceted) + ggplot2::facet_wrap(~region)),
    c("Units", "Units")
  )

  testthat::skip_if_not_installed("patchwork")
  bars <- ggplot2::ggplot(sales()) +
    ggplot2::geom_col(ggplot2::aes(month, sales)) +
    ggplot2::labs(y = "Units sold")
  testthat::expect_identical(
    panel_y_labels(two_lines(sales()) + bars),
    c("Units", "Units sold")
  )
})
