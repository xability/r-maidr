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

test_that("a category is read by the label its legend shows for it", {
  plain <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = grade)) + ggplot2::geom_tile()
  relabelled <- function(...) first_layer(plain + ggplot2::scale_fill_discrete(...))
  as_drawn <- function(labels) {
    lapply(drawn, function(row) unname(labels[row]))
  }

  given <- c(high = "High grade", low = "Low grade", mid = "Mid grade")
  layer <- relabelled(labels = unname(given))
  testthat::expect_identical(z_names(layer), unname(given))
  testthat::expect_identical(read_cells(layer), as_drawn(given))

  manual <- plain + ggplot2::scale_fill_manual(
    values = c("red", "green", "blue"), labels = c("Hi", "Lo", "Md")
  )
  testthat::expect_identical(z_names(first_layer(manual)), c("Hi", "Lo", "Md"))

  layer <- relabelled(labels = toupper)
  testthat::expect_identical(z_names(layer), c("HIGH", "LOW", "MID"))

  layer <- relabelled(labels = expression(alpha, beta, gamma))
  testthat::expect_identical(z_names(layer), c("alpha", "beta", "gamma"))

  # Categories named by numbers are read by their labels where the scale
  # gives them some, in place of the numbers the legend no longer shows.
  scores$score <- c(10, 20, 30, 40, 50, 60)
  numbered <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = factor(score))) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_discrete(labels = paste("level", 1:6))
  layer <- first_layer(numbered)
  testthat::expect_identical(z_names(layer), paste("level", 1:6))
  testthat::expect_identical(
    read_cells(layer),
    list(paste("level", 4:6), paste("level", 1:3))
  )
})

test_that("one category is read by its name, and a missing one as missing", {
  scores$kind <- "only"
  single <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = kind)) + ggplot2::geom_tile()
  layer <- first_layer(single)
  testthat::expect_identical(z_names(layer), "only")
  testthat::expect_identical(read_cells(layer), rep(list(rep("only", 3)), 2))

  # ggplot2 draws an NA grey, under its legend's "NA", which is no category.
  scores$grade[2] <- NA
  gap <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = grade)) + ggplot2::geom_tile()
  layer <- first_layer(gap)
  testthat::expect_identical(z_names(layer), c("high", "low", "mid"))
  testthat::expect_identical(read_cells(layer), list(drawn[[1]], c("low", NA, "mid")))
})

test_that("a category named like markup stays inside the page's escaped attribute", {
  skip_if_no_render()
  # The names reach the page in the chart's `maidr-data` attribute, whose
  # "<" is written "&lt;", so a name cannot end a script there.
  # A factor's levels give the order, which sorting such a name would leave
  # to the locale.
  names <- c("</script>", "low", "mid", "high")
  scores$grade <- factor(c("</script>", "low", "mid", "mid", "high", "high"), levels = names)
  plot <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = grade)) + ggplot2::geom_tile()
  html <- rendered(plot)
  count <- function(text) lengths(regmatches(html, gregexpr(text, html, fixed = TRUE)))
  testthat::expect_identical(count("</script>"), count("<script"))
  layer <- schema_from(html)$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_identical(z_names(layer), names)
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
