# A title() written after a plot titles that plot.
#
# `plot(x); title("Sales")` titles a plot as `plot(x, main = "Sales")` does,
# and is how a plot drawn with `ann = FALSE` is titled. maidr read such a
# title only as the chart's own, on a chart of one panel, and only when
# given as `main =`. The plot's layer was left untitled, so each panel of a
# grid titled this way was read without a title, and `title("Sales")` was
# not read at all.

sales <- c(3, 1, 4, 1, 5, 9, 2, 6)

test_that("a title() written after a plot titles it", {
  named <- base_r_figure(function() {
    plot(sales)
    title(main = "Sales")
  })
  testthat::expect_identical(named$title, "Sales")
  testthat::expect_identical(layer_titles(named), list("Sales"))

  # Given first, a title's `main` is recorded unnamed.
  first <- base_r_figure(function() {
    plot(sales, ann = FALSE)
    title("Sales", xlab = "Week", ylab = "Units")
  })
  testthat::expect_identical(first$title, "Sales")
  testthat::expect_identical(layer_titles(first), list("Sales"))
  axes <- first$subplots[[1]][[1]]$layers[[1]]$axes
  testthat::expect_identical(c(axes$x$label, axes$y$label), c("Week", "Units"))

  bars <- base_r_figure(function() {
    barplot(sales)
    title("Sales")
  })
  testthat::expect_identical(layer_titles(bars), list("Sales"))

  # It titles the plot, as its `main` does, and not the lines drawn on it.
  with_lines <- base_r_figure(function() {
    plot(sales)
    lines(sales)
    title("Sales")
  })
  testthat::expect_identical(layer_titles(with_lines), list(c("Sales", "")))
})

test_that("a title() written over a plot's own title is the one read", {
  # R draws it where the plot's own title goes, so it is the one on top.
  # `hist(ann = FALSE)` draws no title, but its layer was read under the
  # one `hist()` would have drawn.
  hist_figure <- base_r_figure(function() {
    hist(sales, ann = FALSE)
    title("Sales")
  })
  testthat::expect_identical(layer_titles(hist_figure), list("Sales"))

  qq <- base_r_figure(function() {
    qqnorm(sales)
    title("Sales")
  })
  testthat::expect_identical(qq$title, "Sales")
  testthat::expect_identical(layer_titles(qq), list("Sales"))

  # A blank one draws nothing, and leaves the plot's own.
  blank <- base_r_figure(function() {
    plot(sales, main = "Sales")
    title(main = "")
  })
  testthat::expect_identical(layer_titles(blank), list("Sales"))

  # One in the outer margin titles the page, not the plot.
  outer <- base_r_figure(function() {
    par(oma = c(0, 0, 2, 0))
    plot(sales)
    title("Overall", outer = TRUE)
  })
  testthat::expect_identical(outer$title, "Overall")
  testthat::expect_identical(layer_titles(outer), list(""))
})

test_that("each panel of a grid is titled by the title() written on it", {
  apart <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    plot(sales)
    title("Sales")
    plot(rev(sales))
    title(main = "Costs")
  })
  testthat::expect_identical(layer_titles(apart), list("Sales", "Costs"))
  testthat::expect_null(apart$title)

  same <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    for (i in 1:2) {
      plot(sales * i)
      title("Sales")
    }
  })
  testthat::expect_identical(layer_titles(same), list("Sales", "Sales"))
  testthat::expect_identical(same$title, "Sales")

  # Sent back to the first panel with `par(mfg = )`, it is drawn there.
  sent_back <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    plot(sales)
    plot(rev(sales))
    par(mfg = c(1, 1))
    title("Sales")
  })
  testthat::expect_identical(layer_titles(sent_back), list("Sales", ""))
})

test_that("a title() written after a plot drawn over another titles that one", {
  # After `par(new = TRUE)` the next plot is drawn in the same panel, over
  # the first, and a title() written after it is drawn on it.
  overdrawn <- base_r_figure(function() {
    plot(sales)
    par(new = TRUE)
    plot(rev(sales), axes = FALSE, ann = FALSE)
    title("Sales")
  })
  testthat::expect_identical(overdrawn$title, "Sales")
  testthat::expect_identical(layer_titles(overdrawn), list(c("", "Sales")))

  grid <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    for (i in 1:2) {
      plot(sales * i)
      par(new = TRUE)
      plot(rev(sales), axes = FALSE, ann = FALSE)
      title("Sales")
    }
  })
  testthat::expect_identical(layer_titles(grid), list(c("", "Sales"), c("", "Sales")))
  testthat::expect_identical(grid$title, "Sales")
})
