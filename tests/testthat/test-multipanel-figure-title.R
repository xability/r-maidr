# A figure of several panels is titled by what is drawn over all of them.
#
# A Base R `par(mfrow)` or `layout()` page was titled after the `main` of its
# last panel, and subtitled after that panel's `sub`: the orchestrator read
# every plot's `main` in turn and kept the last. A grid of three species
# plots was called "Species: virginica" in its accessible name and its
# description, while the reader stood on setosa, and a title drawn over the
# panels with `title("Overall", outer = TRUE)` was lost to it. A patchwork
# composition was titled after the plot added last, whose `labels` the
# composition carries, and `plot_annotation()`, which titles a composition,
# was not read at all.
#
# A page or composition with nothing drawn over its panels is titled by the
# title all of them carry, when they carry one, and is otherwise untitled.
# Each panel keeps its own title as its layer's, as before.

three_species <- function() {
  par(mfrow = c(1, 3))
  for (species in levels(iris$Species)) {
    rows <- iris[iris$Species == species, ]
    plot(rows$Petal.Length, rows$Petal.Width,
      main = paste("Species:", species), sub = "Petal size"
    )
  }
}

test_that("a par(mfrow) grid is not titled after its last panel", {
  figure <- base_r_figure(three_species)

  testthat::expect_null(figure$title)
  testthat::expect_null(figure$subtitle)
  testthat::expect_identical(
    panel_titles(figure),
    c("Species: setosa", "Species: versicolor", "Species: virginica")
  )
})

test_that("a layout() page is not titled after its last panel", {
  figure <- base_r_figure(function() {
    layout(matrix(1:2, 1))
    hist(mtcars$mpg, main = "Miles per gallon")
    hist(mtcars$hp, main = "Horsepower")
  })

  testthat::expect_null(figure$title)
  testthat::expect_identical(panel_titles(figure), c("Miles per gallon", "Horsepower"))
})

test_that("a title drawn over a grid's panels titles the figure", {
  with_outer_title <- base_r_figure(function() {
    par(mfrow = c(1, 2), oma = c(2, 0, 2, 0))
    hist(mtcars$mpg, main = "Miles per gallon")
    hist(mtcars$hp, main = "Horsepower")
    title("Cars", sub = "From mtcars", outer = TRUE)
  })
  testthat::expect_identical(with_outer_title$title, "Cars")
  testthat::expect_identical(with_outer_title$subtitle, "From mtcars")

  with_outer_mtext <- base_r_figure(function() {
    par(mfrow = c(1, 2), oma = c(0, 0, 2, 0))
    hist(mtcars$mpg, main = "Miles per gallon")
    hist(mtcars$hp, main = "Horsepower")
    mtext("Cars", outer = TRUE)
  })
  testthat::expect_identical(with_outer_mtext$title, "Cars")
  testthat::expect_identical(
    panel_titles(with_outer_mtext),
    c("Miles per gallon", "Horsepower")
  )
})

test_that("a title every panel carries titles the figure", {
  same <- base_r_figure(function() {
    par(mfrow = c(2, 2))
    for (i in 1:4) plot(1:10, (1:10) * i, main = "Weekly sales")
  })
  testthat::expect_identical(same$title, "Weekly sales")

  # The spaces around a title are not seen, and do not set panels apart.
  spaced <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    plot(1:10, main = "Weekly sales")
    plot(1:10, main = "Weekly sales ")
  })
  testthat::expect_identical(spaced$title, "Weekly sales")

  # A page of two panels with one drawn: its one plot's title is the page's.
  one_drawn <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    barplot(1:3, main = "Only plot")
  })
  testthat::expect_identical(one_drawn$title, "Only plot")

  untitled_panel <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    plot(1:10, main = "Weekly sales")
    plot(1:10)
  })
  testthat::expect_null(untitled_panel$title)
})

test_that("a plot drawn over an untitled one titles its panel", {
  # After `par(new = TRUE)` the next plot is drawn in the same panel, and
  # its title is the one R draws there. Only each panel's first plot was
  # read, so a page of these had no title.
  overdrawn <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    for (i in 1:2) {
      plot(1:10)
      par(new = TRUE)
      plot(10:1 * i, main = "Weekly sales")
    }
  })
  testthat::expect_identical(overdrawn$title, "Weekly sales")

  # The panels are still titled apart when the plots over them are.
  apart <- base_r_figure(function() {
    par(mfrow = c(1, 2))
    for (i in 1:2) {
      plot(1:10)
      par(new = TRUE)
      plot(10:1, main = paste("Week", i))
    }
  })
  testthat::expect_null(apart$title)
})

test_that("a chart of one panel, or one that draws its own grid, keeps its title", {
  single <- base_r_figure(function() plot(1:10, main = "Single", sub = "One panel"))
  testthat::expect_identical(single$title, "Single")
  testthat::expect_identical(single$subtitle, "One panel")

  pairs_figure <- base_r_figure(function() pairs(iris[1:4], main = "Iris measurements"))
  testthat::expect_identical(pairs_figure$title, "Iris measurements")
})

test_that("a patchwork composition is titled by plot_annotation(), or what all its plots share", {
  testthat::skip_if_not_installed("patchwork")
  line <- ggplot2::ggplot(data.frame(x = 1:4, y = c(2, 4, 1, 5)), ggplot2::aes(x, y)) +
    ggplot2::geom_line() +
    ggplot2::labs(title = "Line Plot")
  bars <- ggplot2::ggplot(data.frame(x = c("A", "B"), y = c(3, 5)), ggplot2::aes(x, y)) +
    ggplot2::geom_col() +
    ggplot2::labs(title = "Bar Plot")
  figure <- function(plot) maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()

  untitled <- figure(patchwork::wrap_plots(line, bars))
  testthat::expect_null(untitled$title)
  testthat::expect_identical(panel_titles(untitled), c("Line Plot", "Bar Plot"))

  titled <- figure(
    patchwork::wrap_plots(line, bars) +
      patchwork::plot_annotation(
        title = "Two plots", subtitle = "Side by side", caption = "Made up data"
      )
  )
  testthat::expect_identical(titled$title, "Two plots")
  testthat::expect_identical(titled$subtitle, "Side by side")
  testthat::expect_identical(titled$caption, "Made up data")
  testthat::expect_identical(panel_titles(titled), c("Line Plot", "Bar Plot"))

  # patchwork draws the annotation of the outermost composition only
  nested <- figure(
    (patchwork::wrap_plots(line, bars) + patchwork::plot_annotation(title = "Inner")) /
      line
  )
  testthat::expect_null(nested$title)

  # A title every plot carries is the composition's.
  testthat::expect_identical(figure(patchwork::wrap_plots(line, line))$title, "Line Plot")
})
