# Tests that a layer processor reads its index the way production writes it.
#
# `layer_info` is built in six places, all of them naming the field `index`.
# `get_layer_index()` reads that; two shared helpers were written reading
# `layer_info$layer_index` instead, which resolves to NULL for every processor
# the orchestrator builds.
#
# Nothing caught it. Every unit test constructs its own `layer_info`, and the
# ones covering those helpers supplied `layer_index` -- so the helpers found
# their layer in the tests and found nothing in the product. `geom_area` and
# `geom_errorbar` both shipped emitting an empty `data` array: not a wrong
# reading, no reading at all, and no error anywhere on the path.
#
# So these tests go through the real pipeline rather than through a processor
# holding a hand-built `layer_info`. That is the only place the key agreement
# is actually exercised, and a unit test cannot substitute for it however
# thorough it is: the bug lives precisely in the gap between what the tests
# construct and what the orchestrator constructs.

skip_if_not_installed("ggplot2")

library(ggplot2)

#: Two series over four years, values distinct from every running total.
area_frame <- function() {
  data.frame(
    year = rep(2000:2003, 2),
    grp = rep(c("a", "b"), each = 4),
    val = c(3, 5, 4, 7, 2, 3, 6, 5)
  )
}

#' The first layer of the payload a plot actually renders.
#'
#' Goes through `save_html()` rather than through a processor, so the
#' `layer_info` under test is the one the orchestrator built.
#'
#' @param plot A ggplot2 object
#' @return The layer's emitted list
rendered_layer <- function(plot) {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(plot, file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  attr <- regmatches(html, regexpr("maidr-data=\"[^\"]*\"", html))
  testthat::expect_length(attr, 1)
  json <- gsub("&quot;", "\"", substr(attr, 13, nchar(attr) - 1), fixed = TRUE)

  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

test_that("a rendered area chart carries its data, not an empty array", {
  layer <- rendered_layer(
    ggplot(area_frame(), aes(year, val, fill = grp, group = grp)) + geom_area()
  )

  testthat::expect_equal(layer$type, "stacked_area")
  testthat::expect_length(layer$data, 2)
  testthat::expect_equal(
    vapply(layer$data[[1]], function(point) point$y, numeric(1)),
    c(3, 5, 4, 7)
  )
})

test_that("a rendered filled area chart resolves its own position", {
  # `resolve_area_type()` reads the position off the layer, so an unresolved
  # index reports every filled chart as a plain stacked one -- announcing
  # shares as though they were values.
  layer <- rendered_layer(
    ggplot(area_frame(), aes(year, val, fill = grp, group = grp)) +
      geom_area(position = "fill")
  )

  testthat::expect_equal(layer$type, "stacked_normalized_area")
  testthat::expect_equal(
    vapply(layer$data[[1]], function(point) point$y, numeric(1))[1:2],
    c(0.6, 0.625)
  )
})

test_that("a rendered error bar chart carries its points", {
  # The same two helpers, reached from a different processor: whatever the
  # key disagreement breaks, it breaks for every caller at once.
  df <- data.frame(g = c("a", "b", "c"), v = c(3, 5, 4),
                   lo = c(2, 4, 3), hi = c(4, 6, 5))
  layer <- rendered_layer(
    ggplot(df, aes(g, v)) + geom_errorbar(aes(ymin = lo, ymax = hi))
  )

  testthat::expect_equal(layer$type, "error_bar")
  testthat::expect_length(layer$data, 3)
})

test_that("the shared helpers read the index production writes", {
  # The unit-level statement of the same thing, so a failure says which key
  # disagreed rather than only that a chart came out empty.
  processor <- Ggplot2AreaLayerProcessor$new(list(index = 2L))

  testthat::expect_equal(processor$get_layer_index(), 2L)

  plot <- ggplot(area_frame(), aes(year, val)) +
    geom_line() +
    geom_area(alpha = 0.3)
  built <- ggplot2::ggplot_build(plot)

  # Both helpers resolve layer 2 -- the area -- rather than answering NULL.
  testthat::expect_true(inherits(processor$get_own_layer(plot)$geom, "GeomArea"))
  testthat::expect_false(is.null(processor$get_layer_built_data(built)))
})
