# A binned scatter is a heatmap whose grid was computed for it (issue #136)
#
# `geom_bin_2d()` is `GeomTile` + `StatBin2d`, so it was already classified
# `heat` and handed to `Ggplot2HeatmapLayerProcessor`. That classification is
# right -- a rectangular bin grid is a heatmap -- but everything the processor
# did assumed a `geom_tile()` chart built from tidy data, one row per cell.
#
# Two assumptions broke, and between them they produced a complete,
# well-formed, entirely empty answer:
#
#   * `reorder_layer_data()` made the first two columns into factors so the
#     tiles would sort into DOM order. On raw continuous observations that
#     maps 200 data points to 200 *discrete* positions, and `StatBin2d` then
#     bins the integers -- one bin per observation.
#   * `extract_data()` rebuilt the grid from the source columns, so the axis
#     levels were one per data point and the built x was a bin centre that
#     matched none of them. Every lookup missed.
#
# A four-by-four binned scatter came out as a 200x200 grid in which every cell
# announced missing, on a colour axis named `NA`, against eighteen tiles on
# screen. Falling through to the unknown processor would have been the honest
# outcome; this claimed to be a heatmap and described nothing.
#
# So these assert the grid against what ggplot2 actually drew, rather than
# against a shape chosen here.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

# Built at top level: inside a closure the bare column names in `aes()` read as
# undefined globals to static analysis.
bin2d_aes <- ggplot2::aes(x = x, y = y)

#' A reproducible cloud of points, dense enough to leave some bins empty
bin2d_frame <- function(n = 200) {
  set.seed(1)
  data.frame(x = stats::rnorm(n), y = stats::rnorm(n))
}

bin2d_plot <- function(bins = 4, n = 200) {
  ggplot2::ggplot(bin2d_frame(n), bin2d_aes) + ggplot2::geom_bin_2d(bins = bins)
}

#' Render a plot and return the one layer it emits
bin2d_layer <- function(plot) {
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

  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

#' The counts the layer announces, in no particular order
bin2d_counts <- function(layer) {
  cells <- unlist(layer$data$points, recursive = FALSE)
  sort(as.numeric(Filter(Negate(is.null), cells)))
}

test_that("a binned scatter announces the grid ggplot2 drew", {
  skip_if_no_render()

  plot <- bin2d_plot()
  drawn <- ggplot2::ggplot_build(plot)$data[[1]]
  layer <- bin2d_layer(plot)

  testthat::expect_equal(layer$type, "heat")

  # The grid is the bin lattice, not the observations. Before, both axes
  # carried one entry per data point.
  testthat::expect_equal(length(layer$data$x), length(unique(drawn$x)))
  testthat::expect_equal(length(layer$data$y), length(unique(drawn$y)))
  testthat::expect_lt(length(layer$data$x), nrow(bin2d_frame()))

  # Every drawn tile is announced, with its own count, and nothing else is.
  testthat::expect_equal(bin2d_counts(layer), sort(as.numeric(drawn$count)))
})

test_that("an empty bin reads as missing rather than as a count of zero", {
  skip_if_no_render()

  # The lattice is rectangular and the data is not, so some cells hold no
  # tile. Scoring those 0 would be a claim the chart does not make -- and
  # the frontend reads a 0 as "no rect here" for highlighting, which every
  # cell of a heatmap has.
  layer <- bin2d_layer(bin2d_plot())
  cells <- unlist(layer$data$points, recursive = FALSE)

  filled <- length(layer$data$x) * length(layer$data$y)
  testthat::expect_equal(length(cells), filled)
  testthat::expect_gt(sum(vapply(cells, is.null, logical(1))), 0)
  testthat::expect_false(any(vapply(
    cells, function(v) !is.null(v) && identical(as.numeric(v), 0), logical(1)
  )))
})

test_that("each bin is named by the range it covers", {
  skip_if_no_render()

  # "a count of 4" means nothing without "between -2.3 and -1.2". The range
  # is what a sighted reader takes from the axis, and `xmin`/`xmax` are
  # computed alongside the count, so it costs nothing to report.
  layer <- bin2d_layer(bin2d_plot())

  for (label in unlist(layer$data$x)) {
    testthat::expect_match(label, "^-?[0-9.]+ to -?[0-9.]+$", info = label)
  }
  for (label in unlist(layer$data$y)) {
    testthat::expect_match(label, "^-?[0-9.]+ to -?[0-9.]+$", info = label)
  }

  # Read against the built data rather than against literals, so this keeps
  # meaning if ggplot2 changes how it places bin edges.
  drawn <- ggplot2::ggplot_build(bin2d_plot())$data[[1]]
  lowest <- drawn$xmin[which.min(drawn$x)]
  testthat::expect_match(
    layer$data$x[[1]],
    paste0("^", format(signif(lowest, 4), trim = TRUE, scientific = FALSE), " to ")
  )
})

test_that("the colour axis is named for what it counts", {
  skip_if_no_render()

  # It was `NA`: `fill_col` fell back to the third column of the source
  # frame, and a binned scatter has two.
  layer <- bin2d_layer(bin2d_plot())

  testthat::expect_equal(layer$axes$z$label, "count")
})

test_that("bin count follows what the caller asked for", {
  skip_if_no_render()

  # The grid is read from the computed layer, so a different `bins` gives a
  # different lattice. A fixed 200x200 would not have moved.
  coarse <- bin2d_layer(bin2d_plot(bins = 3))
  fine <- bin2d_layer(bin2d_plot(bins = 10))

  testthat::expect_lt(length(coarse$data$x), length(fine$data$x))
})

test_that("a tidy geom_tile heatmap is unchanged", {
  skip_if_no_render()

  # The control, and the thing most at risk: the binned path is reached
  # from inside the processor every tile heatmap uses. A tidy chart carries
  # its own grid and its own fill column, and must still be read that way.
  frame <- expand.grid(row = c("a", "b"), col = c("x", "y", "z"))
  frame$score <- c(1, 2, 3, 4, 5, 6)
  plot <- ggplot2::ggplot(frame, ggplot2::aes(col, row, fill = score)) +
    ggplot2::geom_tile()

  layer <- bin2d_layer(plot)

  testthat::expect_equal(layer$type, "heat")
  testthat::expect_equal(layer$axes$z$label, "score")
  testthat::expect_setequal(unlist(layer$data$x), c("x", "y", "z"))
  testthat::expect_setequal(unlist(layer$data$y), c("a", "b"))
  testthat::expect_equal(bin2d_counts(layer), c(1, 2, 3, 4, 5, 6))
})

test_that("the binned path is chosen by the stat, not by a column name", {
  testthat::skip_if_not_installed("ggplot2")

  # A tidy heatmap whose value column happens to be called `count` is not a
  # binned layer, and must not be read as one -- which is why the test is
  # on `StatBin2d` rather than on `"count" %in% names(built_data)`.
  frame <- expand.grid(row = c("a", "b"), col = c("x", "y"))
  frame$count <- c(1, 2, 3, 4)
  tidy <- ggplot2::ggplot(frame, ggplot2::aes(col, row, fill = count)) +
    ggplot2::geom_tile()

  processor <- maidr:::Ggplot2HeatmapLayerProcessor$new(list(index = 1))

  testthat::expect_false(processor$is_binned_layer(tidy, 1))
  testthat::expect_true(processor$is_binned_layer(bin2d_plot(), 1))
  # Out of range rather than an error: a caller asking about a layer that
  # is not there gets "no", not a crash.
  testthat::expect_false(processor$is_binned_layer(tidy, 5))
})
