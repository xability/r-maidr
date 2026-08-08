# Axis labels of faceted subplots.
#
# The facet path used to rebuild each subplot's axes from the UNBUILT
# `plot$labels`, which under ggplot2 v4 holds only explicit `labs()`
# overrides. Everything ggplot2 derives at build time was therefore lost: the
# stat-computed "count" of geom_bar(), the mapped column names, and the legend
# title a grouped layer needs so MAIDR announces it instead of "Group".

facet_payload <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(
    html, gregexpr('maidr-data="([^"]*)"', html, perl = TRUE)
  )[[1]]
  testthat::expect_gt(length(raw), 0)

  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

facet_layers <- function(payload) {
  out <- list()
  for (row in payload$subplots) {
    for (subplot in row) {
      for (layer in subplot$layers) {
        out[[length(out) + 1L]] <- layer
      }
    }
  }
  out
}

test_that("faceted bar panels keep the stat-computed y label", {
  testthat::skip_if_not_installed("jsonlite")

  p <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) +
    ggplot2::geom_bar() +
    ggplot2::facet_wrap(~drv)

  layers <- facet_layers(facet_payload(p))

  testthat::expect_gt(length(layers), 0)
  for (layer in layers) {
    testthat::expect_equal(layer$axes$x$label, "class")
    testthat::expect_equal(layer$axes$y$label, "count")
  }
})

test_that("faceted grouped line panels keep the legend title as z", {
  testthat::skip_if_not_installed("jsonlite")

  df <- data.frame(
    x = rep(1:5, 4),
    y = as.numeric(1:20),
    series = rep(c("A", "B"), each = 10),
    panel = rep(c("P1", "P2"), 10)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x, y, colour = series)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~panel) +
    ggplot2::labs(colour = "Cohort")

  layers <- facet_layers(facet_payload(p))

  testthat::expect_gt(length(layers), 0)
  for (layer in layers) {
    testthat::expect_equal(layer$axes$x$label, "x")
    testthat::expect_equal(layer$axes$y$label, "y")
    testthat::expect_equal(layer$axes$z$label, "Cohort")
    maidr:::validate_axes(layer$axes, "facet subplot")
  }
})

test_that("a facet panel takes z from a grouped layer that is not first", {
  # A faceted panel collapses every layer into ONE payload entry, so its axes
  # have to be assembled from all of them rather than from whichever happens
  # to be processed first. Here layer 1 (points) is ungrouped and layer 2
  # (lines) is grouped, but the shared data still carries the group as z --
  # so a first-layer-wins rule emits z VALUES with no z LABEL, and MAIDR
  # announces the generic word "Group" instead of the legend title.
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")

  df <- data.frame(
    x = rep(1:4, 4),
    y = as.numeric(1:16),
    series = rep(c("alpha", "beta"), each = 8),
    panel = rep(c("P1", "P2"), 8)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::geom_line(ggplot2::aes(colour = series)) +
    ggplot2::facet_wrap(~panel) +
    ggplot2::labs(colour = "Cohort")

  layers <- facet_layers(facet_payload(p))

  testthat::expect_gt(length(layers), 0)
  for (layer in layers) {
    testthat::expect_equal(layer$axes$x$label, "x")
    testthat::expect_equal(layer$axes$y$label, "y")
    testthat::expect_equal(layer$axes$z$label, "Cohort")
    maidr:::validate_axes(layer$axes, "facet subplot")
  }
})
