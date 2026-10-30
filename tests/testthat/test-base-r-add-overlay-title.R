# A chart drawn onto a plot has no titles of its own.
#
# A high-level call given `add = TRUE`, as `hist(y, add = TRUE)` or
# `contour(add = TRUE)`, draws onto the plot before it, against its axes,
# and draws no title or axis title, neither those it is given nor those its
# function gives a plot: R draws none for hist(), boxplot(), barplot(),
# image(), contour(), curve(), symbols(), stripchart(), matplot(),
# sunflowerplot(), smoothScatter(), stars() or the ecdf and stepfun plot
# methods. maidr read its layer under those titles, "Histogram of y" over an
# x axis "y", and titled a chart of one panel after its `main`, in place of
# the plot's own. A `main` given to a low-level call such as `lines()`, which
# R ignores with a warning, titled its layer too.

sales <- c(3, 1, 4, 1, 5, 9, 2, 6)
costs <- sales + 2

test_that("a chart drawn onto a plot with add = TRUE has no title", {
  hist_figure <- base_r_figure(function() {
    hist(sales, main = "Sales")
    hist(costs, add = TRUE)
  })
  testthat::expect_identical(hist_figure$title, "Sales")
  testthat::expect_identical(layer_titles(hist_figure), list(c("Sales", "")))

  # Nor the `main` it is given, which R does not draw either.
  given <- base_r_figure(function() {
    boxplot(sales, main = "Sales", xlim = c(0, 3))
    boxplot(costs, add = TRUE, at = 2, main = "Costs")
  })
  testthat::expect_identical(given$title, "Sales")
  testthat::expect_identical(layer_titles(given), list(c("Sales", "")))

  contoured <- base_r_figure(function() {
    image(volcano, main = "Maunga Whau")
    contour(volcano, add = TRUE, main = "Contours")
  })
  testthat::expect_identical(contoured$title, "Maunga Whau")
  testthat::expect_identical(layer_titles(contoured), list(c("Maunga Whau", "")))

  lines_like <- base_r_figure(function() {
    matplot(cbind(sales, costs), type = "l", main = "Sales")
    matplot(cbind(costs, sales), type = "l", add = TRUE, main = "Costs")
  })
  testthat::expect_identical(lines_like$title, "Sales")
  testthat::expect_identical(layer_titles(lines_like), list(c("Sales", "")))
})

test_that("a chart drawn onto a plot with add = TRUE is read under the plot's axis titles", {
  # It writes none of its own, so R shows the plot's. The second histogram
  # was read under "costs", the x axis title `hist(costs)` writes.
  over <- base_r_figure(function() {
    hist(sales, xlab = "Drawn X")
    hist(costs, add = TRUE)
  })
  axes <- over$subplots[[1]][[1]]$layers[[2]]$axes
  testthat::expect_identical(axes$x$label, "Drawn X")
  testthat::expect_identical(axes$y$label, "Frequency")

  # Nor the ones it is given, which R does not draw either.
  given <- base_r_figure(function() {
    boxplot(sales, xlim = c(0, 3), ylab = "Units")
    boxplot(costs, add = TRUE, at = 2, ylab = "Undrawn")
  })
  testthat::expect_identical(given$subplots[[1]][[1]]$layers[[2]]$axes$y$label, "Units")

  # A title written after it titles the plot's axis, and so the chart's.
  written <- base_r_figure(function() {
    hist(sales, xlab = "")
    hist(costs, add = TRUE)
    title(xlab = "Weight")
  })
  labels <- vapply(written$subplots[[1]][[1]]$layers, function(layer) layer$axes$x$label, "")
  testthat::expect_identical(labels, c("Weight", "Weight"))
})

test_that("a title() written after such a chart titles the plot under it", {
  titled <- base_r_figure(function() {
    hist(sales, main = "")
    hist(costs, add = TRUE)
    title("Sales and costs")
  })
  testthat::expect_identical(titled$title, "Sales and costs")
  testthat::expect_identical(layer_titles(titled), list(c("Sales and costs", "")))
})

test_that("a page of panels is not titled after what their overlays would be called", {
  grid <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    for (i in 1:2) {
      hist(sales * i, main = "")
      hist(costs, add = TRUE)
    }
  })
  testthat::expect_null(grid$title)
  testthat::expect_identical(layer_titles(grid), list(c("", ""), c("", "")))
})

test_that("a plot that ignores add draws a plot of its own, and its title", {
  # plot() of a vector has no `add`: given one, R warns and starts a plot.
  apart <- suppressWarnings(base_r_figure(function() {
    par(mfrow = c(1, 2))
    plot(sales, main = "Sales")
    plot(costs, add = TRUE, main = "Costs")
  }))
  testthat::expect_identical(layer_titles(apart), list("Sales", "Costs"))
})

test_that("a low-level call is not titled by a main given to it", {
  stray <- suppressWarnings(base_r_figure(function() {
    plot(sales, main = "Sales")
    lines(costs, main = "Costs")
    points(costs, main = "Costs")
  }))
  testthat::expect_identical(stray$title, "Sales")
  testthat::expect_identical(layer_titles(stray), list(c("Sales", "", "")))

  # abline() is read under its plot's title, which R draws.
  with_line <- base_r_figure(function() {
    plot(sales, main = "Sales")
    abline(h = mean(sales))
  })
  testthat::expect_identical(layer_titles(with_line), list(c("Sales", "Sales")))
})
