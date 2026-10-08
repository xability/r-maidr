# A Base R or lattice line titled Recall against Precision is a
# precision-recall curve.
#
# Neither system draws a precision-recall curve of its own: one is a line of
# rates, `plot(recall, precision, type = "l")` or
# `xyplot(precision ~ recall, type = "l")`, and both title their axes after
# the variables drawn. Those titles, with every point a fraction of one, are
# the claim `titled_pr_curve()` reads, as the column names are for a ggplot2
# line and the axis titles are in py-maidr. Nothing short of it is read as
# one.

skip_slow_file_on_cran()

recall <- c(0, 0.25, 0.5, 1)
precision <- c(1, 0.9, 0.7, 0.4)

#' Draw `plot_fun` off-screen, save it as a user would, return its layers
base_r_layers <- function(plot_fun) {
  testthat::skip_if_not_installed("jsonlite")
  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  plot_fun()
  suppressWarnings(suppressMessages(maidr::save_html(plot = NULL, file = file)))
  layers_from(paste(readLines(file, warn = FALSE), collapse = "\n"))
}

test_that("titled_pr_curve() reads the titles and the rates, nothing else", {
  testthat::local_mocked_bindings(pr_curve_trace_available = function() TRUE)
  axes <- maidr:::build_axes(x = " Recall ", y = "PRECISION")
  rates <- list(list(list(x = 0, y = 1), list(x = 0.5, y = 0.7)))

  testthat::expect_true(maidr:::titled_pr_curve(axes, rates))
  testthat::expect_false(maidr:::titled_pr_curve(
    maidr:::build_axes(x = "Epoch", y = "Precision"), rates
  ))
  testthat::expect_false(maidr:::titled_pr_curve(
    axes, list(list(list(x = 0, y = 1.4)))
  ))
  testthat::expect_false(maidr:::titled_pr_curve(
    axes, list(list(list(x = "0", y = 1)))
  ))
  testthat::expect_false(maidr:::titled_pr_curve(axes, list()))

  testthat::local_mocked_bindings(pr_curve_trace_available = function() FALSE)
  testthat::expect_false(maidr:::titled_pr_curve(axes, rates))
})

test_that("plot(recall, precision, type = 'l') is a precision-recall curve", {
  layers <- base_r_layers(function() plot(recall, precision, type = "l"))

  testthat::expect_length(layers, 1)
  testthat::expect_identical(layers[[1]]$type, "pr_curve")
  testthat::expect_identical(layers[[1]]$axes$x$label, "recall")
  points <- layers[[1]]$data[[1]]
  testthat::expect_equal(vapply(points, function(p) p$x, 0), recall)
  testthat::expect_equal(vapply(points, function(p) p$y, 0), precision)
  testthat::expect_true(length(layers[[1]]$selectors) > 0)
})

test_that("a staircase titled so is one too, without a step direction", {
  layers <- base_r_layers(function() {
    plot(recall, precision, type = "s", xlab = "Recall", ylab = "Precision")
  })

  testthat::expect_identical(layers[[1]]$type, "pr_curve")
  testthat::expect_null(layers[[1]]$stepDirection)
})

test_that("a Base R line short of the claim keeps its reading", {
  epochs <- base_r_layers(function() {
    plot(recall, precision, type = "l", xlab = "Epoch")
  })
  testthat::expect_identical(epochs[[1]]$type, "line")

  counts <- base_r_layers(function() {
    plot(recall, precision * 10, type = "l", ylab = "Precision")
  })
  testthat::expect_identical(counts[[1]]$type, "line")
})

test_that("xyplot(precision ~ recall, type = 'l') is a precision-recall curve", {
  skip_if_no_lattice()
  rendered <- render_lattice(
    lattice::xyplot(precision ~ recall, type = "l")
  )

  layers <- lattice_rendered_layers(rendered)
  testthat::expect_length(layers, 1)
  testthat::expect_identical(layers[[1]]$type, "pr_curve")
  testthat::expect_equal(
    lattice_selector_counts(rendered$doc, layers[[1]]$selectors), 1
  )
})

test_that("grouped lattice curves are one curve per group", {
  skip_if_no_lattice()
  curves <- data.frame(
    recall = rep(recall, 2),
    precision = c(precision, precision * 0.9),
    model = rep(c("logistic", "forest"), each = 4)
  )
  rendered <- render_lattice(
    lattice::xyplot(precision ~ recall, data = curves, groups = model, type = "l")
  )

  layers <- lattice_rendered_layers(rendered)
  testthat::expect_identical(layers[[1]]$type, "pr_curve")
  testthat::expect_length(layers[[1]]$data, 2)
})

test_that("a lattice line short of the claim keeps its reading", {
  skip_if_no_lattice()
  rendered <- render_lattice(
    lattice::xyplot(precision ~ recall, type = "l", xlab = "Epoch")
  )

  testthat::expect_identical(lattice_rendered_layers(rendered)[[1]]$type, "line")
})
