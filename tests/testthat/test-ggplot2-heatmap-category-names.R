# A heatmap filled by categories is read by the names its legend shows.
#
# `aes(fill = grade)` colours each tile by its grade, and the legend names
# the colours "high", "low" and "mid". The cells were read as missing,
# "grade is missing" on every tile: the frontend's heatmap holds numbers, and
# a name is not one. Each cell now holds its category's place in the
# legend, and the layer's z axis names each place, so the tile is read as
# "grade is low".

scores <- data.frame(x = rep(c("a", "b", "c"), 2), y = rep(c("p", "q"), each = 3))
scores$grade <- c("low", "low", "mid", "mid", "high", "high")

#' The first layer the plot is read as
first_layer <- function(plot) {
  maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]
}

#' The names a layer's z axis gives the places of its categories, or NULL
z_names <- function(layer) {
  body <- layer$axes$z$format[["function"]]
  if (is.null(body)) {
    return(NULL)
  }
  jsonlite::fromJSON(sub("^var names = (\\[.*?\\]);.*$", "\\1", body, perl = TRUE))
}

#' Each cell of the layer, top row first, as the name it is read by
read_cells <- function(layer) {
  names <- z_names(layer)
  lapply(layer$data$points, function(row) {
    vapply(row, function(value) {
      if (is.null(value) || is.na(value)) NA_character_ else names[[value]]
    }, character(1))
  })
}

# As drawn: q, the top row, holds rows 4 to 6 of the data; p rows 1 to 3.
drawn <- list(c("mid", "high", "high"), c("low", "low", "mid"))

test_that("a fill of categories named otherwise is read by its legend's names", {
  plot <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = grade)) + ggplot2::geom_tile()
  layer <- first_layer(plot)

  testthat::expect_identical(read_cells(layer), drawn)
  testthat::expect_identical(layer$axes$z$label, "grade")
  # The places are the legend's: ggplot2 lists the grades alphabetically.
  testthat::expect_identical(z_names(layer), c("high", "low", "mid"))
})

test_that("the categories are placed in the order the legend lists them", {
  # A factor's own order, and a scale's limits, are the legend's.
  ordered <- ggplot2::ggplot(
    scores, ggplot2::aes(x, y, fill = factor(grade, levels = c("low", "mid", "high")))
  ) + ggplot2::geom_tile()
  layer <- first_layer(ordered)
  testthat::expect_identical(z_names(layer), c("low", "mid", "high"))
  testthat::expect_identical(read_cells(layer), drawn)
  # The lowest cell is the first category the legend lists.
  testthat::expect_identical(min(unlist(layer$data$points)), 1)

  limited <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = grade)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_discrete(limits = c("mid", "low", "high"))
  layer <- first_layer(limited)
  testthat::expect_identical(z_names(layer), c("mid", "low", "high"))
  testthat::expect_identical(read_cells(layer), drawn)
})

test_that("a colour drawn under no legend is still read as missing", {
  coloured <- ggplot2::ggplot(
    scores, ggplot2::aes(x, y, fill = ggplot2::after_scale(scales::alpha("steelblue", 0.5)))
  ) + ggplot2::geom_tile()
  layer <- first_layer(coloured)
  testthat::expect_true(all(is.na(unlist(layer$data$points))))
  testthat::expect_null(z_names(layer))
})

test_that("each panel of a faceted heatmap names its categories alike", {
  faceted <- ggplot2::ggplot(scores, ggplot2::aes(x, grade, fill = grade)) +
    ggplot2::geom_tile() +
    ggplot2::facet_wrap(~y)
  figure <- maidr:::Ggplot2PlotOrchestrator$new(faceted)$generate_maidr_data()
  panels <- unlist(figure$subplots, recursive = FALSE)
  testthat::expect_length(panels, 2L)
  for (panel in panels) {
    testthat::expect_identical(z_names(panel$layers[[1]]), c("high", "low", "mid"))
  }
})
