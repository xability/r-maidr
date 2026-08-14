# A heatmap has to say what its axes are (issue #156)
#
# `Ggplot2HeatmapLayerProcessor` built its axes from two string literals:
#
#   axes <- build_axes(x = "x", y = "y", z = fill_label)
#
# so a cell was announced as "x: y, y: a, score: 3" -- where the first `y` is
# a category value and the second is the axis name that should have been
# "Model". The colour axis was resolved properly; the other two were not.
#
# A `labs()` override was discarded, and so was the mapped column name that
# ggplot2 itself falls back to. There was nothing a caller could write from
# their own code that would reach the reader, and nothing in the output to
# suggest anything was missing: the numbers were right, the categories were
# right, and the names were letters.
#
# The base R adapter had always read real labels off the recorded call, so
# the two adapters disagreed and the ggplot2 one was the wrong half. Both
# now go through the same chain the rest of the package uses.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

#' A tidy heatmap whose column names are not the aesthetic names
tile_frame <- function() {
  frame <- expand.grid(row = c("a", "b"), col = c("x", "y", "z"))
  frame$score <- c(1, 2, 3, 4, 5, 6)
  frame
}

tile_plot <- function() {
  ggplot2::ggplot(
    tile_frame(), ggplot2::aes(col, row, fill = score)
  ) + ggplot2::geom_tile()
}

#' Render a plot and return the axes its one layer emits
tile_axes <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  testthat::expect_length(raw, 1)
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  schema <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  schema$subplots[[1]][[1]]$layers[[1]]$axes
}

test_that("a labs() override reaches the reader", {
  skip_if_no_render()

  axes <- tile_axes(tile_plot() + ggplot2::labs(x = "Task", y = "Model"))

  testthat::expect_equal(axes$x$label, "Task")
  testthat::expect_equal(axes$y$label, "Model")
  testthat::expect_equal(axes$z$label, "score")
})

test_that("without labs(), the mapped column names are used", {
  skip_if_no_render()

  # The case a `labs()`-only test would miss, and the more common one: most
  # charts never call `labs()` at all, and ggplot2 prints the column name.
  # It is also the case that reads *closest* to the old behaviour -- an axis
  # mapped to a column called `x` would have looked correct throughout.
  axes <- tile_axes(tile_plot())

  testthat::expect_equal(axes$x$label, "col")
  testthat::expect_equal(axes$y$label, "row")
})

test_that("a mapping on the layer is used when the plot has none", {
  skip_if_no_render()

  frame <- tile_frame()
  plot <- ggplot2::ggplot(frame) +
    ggplot2::geom_tile(ggplot2::aes(col, row, fill = score))

  axes <- tile_axes(plot)

  testthat::expect_equal(axes$x$label, "col")
  testthat::expect_equal(axes$y$label, "row")
})

test_that("a binned scatter names its axes too", {
  skip_if_no_render()

  # `geom_bin_2d()` reaches the same processor, so #155 made the grid right
  # while the axes still said "x" and "y". A count is not much use under an
  # axis with no name.
  set.seed(1)
  frame <- data.frame(width = stats::rnorm(200), height = stats::rnorm(200))
  plot <- ggplot2::ggplot(frame, ggplot2::aes(width, height)) +
    ggplot2::geom_bin_2d(bins = 4)

  axes <- tile_axes(plot)

  testthat::expect_equal(axes$x$label, "width")
  testthat::expect_equal(axes$y$label, "height")
  testthat::expect_equal(axes$z$label, "count")
})

test_that("an axis with nothing to go on falls back to its aesthetic name", {
  testthat::skip_if_not_installed("ggplot2")

  # A label is emitted whatever happens. A positional axis always has a name
  # printed on the chart, so announcing nothing would leave a number with no
  # name at all -- worse than a poor name.
  #
  # `labs(x = "")` lands here as well: a blank axis name is not a name.
  frame <- tile_frame()
  plot <- ggplot2::ggplot(frame, ggplot2::aes(col, row, fill = score)) +
    ggplot2::geom_tile() +
    ggplot2::labs(x = "")

  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(list(index = 1))
  built <- ggplot2::ggplot_build(plot)

  testthat::expect_equal(
    maidr:::positional_axis_label(plot, built, "x", 1), "col"
  )

  # And with neither a label nor a mapping, the aesthetic name itself.
  bare <- ggplot2::ggplot(frame)
  testthat::expect_equal(maidr:::positional_axis_label(bare, NULL, "x"), "x")
  testthat::expect_equal(maidr:::positional_axis_label(bare, NULL, "y"), "y")

  testthat::expect_s3_class(processor, "Ggplot2HeatmapLayerProcessor")
})
