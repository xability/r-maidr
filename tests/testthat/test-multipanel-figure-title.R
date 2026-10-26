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
# Each panel keeps its own title as its layer's, as before.

#' The MAIDR data of the Base R page `draw` draws
base_r_figure <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)

  draw()
  maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
}

#' The title of each subplot's first layer, row by row
layer_titles <- function(figure) {
  unlist(lapply(figure$subplots, function(row) {
    vapply(row, function(cell) {
      title <- cell$layers[[1]]$title
      if (is.null(title)) "" else title
    }, character(1))
  }))
}

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
    layer_titles(figure),
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
  testthat::expect_identical(layer_titles(figure), c("Miles per gallon", "Horsepower"))
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
    layer_titles(with_outer_mtext),
    c("Miles per gallon", "Horsepower")
  )
})

test_that("a chart of one panel, or one that draws its own grid, keeps its title", {
  single <- base_r_figure(function() plot(1:10, main = "Single", sub = "One panel"))
  testthat::expect_identical(single$title, "Single")
  testthat::expect_identical(single$subtitle, "One panel")

  pairs_figure <- base_r_figure(function() pairs(iris[1:4], main = "Iris measurements"))
  testthat::expect_identical(pairs_figure$title, "Iris measurements")
})

test_that("a patchwork composition is titled by plot_annotation() alone", {
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
  testthat::expect_identical(layer_titles(untitled), c("Line Plot", "Bar Plot"))

  titled <- figure(
    patchwork::wrap_plots(line, bars) +
      patchwork::plot_annotation(
        title = "Two plots", subtitle = "Side by side", caption = "Made up data"
      )
  )
  testthat::expect_identical(titled$title, "Two plots")
  testthat::expect_identical(titled$subtitle, "Side by side")
  testthat::expect_identical(titled$caption, "Made up data")
  testthat::expect_identical(layer_titles(titled), c("Line Plot", "Bar Plot"))

  # patchwork draws the annotation of the outermost composition only
  nested <- figure(
    (patchwork::wrap_plots(line, bars) + patchwork::plot_annotation(title = "Inner")) /
      line
  )
  testthat::expect_null(nested$title)
})
