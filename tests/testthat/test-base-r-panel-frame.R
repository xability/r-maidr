# Each panel of a Base R figure of several is named by the frame R drew
# round it.
#
# In the lobby of a figure of several panels the frontend outlines the panel
# the reader is on: the element a subplot's own `selector` names, or else the
# one element holding all of the subplot's marks and no other panel's. A Base
# R panel named nothing, and a box plot's boxes, whiskers and outliers are
# several grobs that nothing on the page held apart from the other panels'
# marks, so the lobby of `par(mfrow = c(2, 2))` box plots outlined no panel.
# `box()`, which `plot()` and `boxplot()` draw by default, outlines the plot
# region; it is named as lattice's panel borders are.

#' The MAIDR data of the Base R page `draw` draws, and the page
#'
#' `draw` calls the plotting functions unqualified, as a script does:
#' maidr records them through its own bindings, which `graphics::` passes by.
render_base_page <- function(draw) {
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
      clear_all_device_storage()
    },
    add = TRUE
  )
  draw()
  suppressWarnings(suppressMessages(maidr::save_html(plot = NULL, file = file)))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  list(html = html, figure = schema_from(html))
}

#' Each subplot's own selector, row by row, NA where it names none
panel_selectors <- function(figure) {
  unlist(lapply(figure$subplots, function(row) {
    vapply(row, function(cell) cell$selector %||% NA_character_, character(1))
  }))
}

#' Whether the page holds the element a `g#<id>` selector names
names_an_element <- function(html, selector) {
  id <- gsub("\\\\", "", sub("^g#", "", selector))
  grepl(sprintf('<g id="%s"', id), html, fixed = TRUE)
}

test_that("each box plot of a 2x2 figure is named by its frame", {
  skip_if_no_render()
  page <- render_base_page(function() {
    par(mfrow = c(2, 2))
    for (measure in c("mpg", "hp", "wt", "qsec")) {
      boxplot(mtcars[[measure]] ~ mtcars$cyl, main = measure)
    }
  })

  selectors <- panel_selectors(page$figure)
  expect_identical(selectors, sprintf("g#graphics-plot-%d-box-1\\.1", 1:4))
  for (selector in selectors) {
    expect_true(names_an_element(page$html, selector), info = selector)
  }
})

test_that("a panel drawn with no frame names none", {
  skip_if_no_render()
  # The bars and the histogram are drawn with no frame; the scatter plot and
  # the box plot are framed.
  page <- render_base_page(function() {
    par(mfrow = c(2, 2))
    barplot(table(mtcars$cyl))
    hist(mtcars$mpg)
    plot(mtcars$wt, mtcars$mpg)
    boxplot(hp ~ gear, data = mtcars)
  })

  expect_identical(
    panel_selectors(page$figure),
    c(NA, NA, "g#graphics-plot-3-box-1\\.1", "g#graphics-plot-4-box-1\\.1")
  )
})

test_that("a frame is named by its plot's number on the page", {
  skip_if_no_render()
  # The first plot is drawn on a page of its own, before the layout: the two
  # box plots are the first and second plots of the page shown.
  page <- render_base_page(function() {
    plot(1:3)
    par(mfrow = c(1, 2))
    boxplot(mpg ~ cyl, data = mtcars)
    boxplot(hp ~ cyl, data = mtcars)
  })

  selectors <- panel_selectors(page$figure)
  expect_identical(selectors, sprintf("g#graphics-plot-%d-box-1\\.1", 1:2))
  for (selector in selectors) {
    expect_true(names_an_element(page$html, selector), info = selector)
  }
})

test_that("a figure of one plot names no panel", {
  skip_if_no_render()
  page <- render_base_page(function() boxplot(mpg ~ cyl, data = mtcars))
  expect_identical(panel_selectors(page$figure), NA_character_)
})
