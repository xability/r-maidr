# A raster is the tile grid ggplot2 recommends for regular spacing (issue #192)
#
# `geom_raster()` is what ggplot2's own documentation steers users to whenever
# a heatmap's cells are evenly spaced -- it draws the grid as one raster grob
# instead of one rectangle per cell, which is much faster. The chart is the
# same chart, and `ggplot_build` computes the same columns for both: `fill`,
# `x`, `y`, and the `xmin`/`xmax`/`ymin`/`ymax` cell bounds.
#
# It was read as nothing at all, because the classifier matches the geom's
# class name and `GeomRaster` was not one of the names. Nor would inheritance
# have caught it:
#
#   GeomRaster   <  Geom      <  ggproto  <  gg
#   GeomTile     <  GeomRect  <  Geom     <  ggproto  <  gg
#
# `GeomRaster` is a sibling of `GeomTile`, not a subclass -- it reimplements
# drawing from scratch. So the fix is the third name on the same branch, for
# the reason the comment above it already gives for the second: ggplot2 4.0
# gave `geom_bin_2d()` its own `GeomBin2d` where 3.x used a plain `GeomTile`,
# and "it is the same tile grid and still a heatmap, so both names land here".
#
# What does NOT transfer is the highlighting, and that is asserted here rather
# than left to be discovered. A raster is one `<image>` element for the whole
# grid, so there is no per-cell element for a selector to name. The values are
# announced and nothing lights up. That is strictly better than the static
# image it was before -- a blind reader gains every number -- but it is a real
# limit, and the way to have both is `geom_tile()`, which draws a `<rect>` per
# cell and reads identically.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

# Built at top level: inside a closure the bare column names in `aes()` read as
# undefined globals to static analysis.
raster_aes <- ggplot2::aes(x = g, y = h, fill = v)

#' A small grid with a distinct value in every cell
raster_frame <- function() {
  frame <- expand.grid(g = c("A", "B", "C"), h = c("x", "y"))
  frame$v <- seq_len(nrow(frame))
  frame
}

raster_plot <- function(geom) {
  ggplot2::ggplot(raster_frame(), raster_aes) + geom()
}

#' Render a plot and return the one layer it emits, or NULL when it emits none
raster_layer <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(NULL)
  }
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

test_that("a raster is read as the heatmap it draws", {
  skip_if_no_render()

  layer <- raster_layer(raster_plot(ggplot2::geom_raster))

  testthat::expect_false(is.null(layer))
  testthat::expect_equal(layer$type, "heat")
})

test_that("a raster and a tile announce the same grid", {
  skip_if_no_render()

  # The assertion is the agreement, because what was wrong was the
  # disagreement: one spelling of the same chart was accessible and the other
  # was a picture. Asserted against each other rather than against literals so
  # it keeps holding if the grid's own representation ever changes.
  raster <- raster_layer(raster_plot(ggplot2::geom_raster))
  tile <- raster_layer(raster_plot(ggplot2::geom_tile))

  testthat::expect_equal(raster$data$points, tile$data$points)
  testthat::expect_equal(raster$data$x, tile$data$x)
  testthat::expect_equal(raster$data$y, tile$data$y)
})

test_that("a raster announces its values but has nothing to highlight", {
  skip_if_no_render()

  # The limit, pinned rather than described. `geom_raster()` draws the whole
  # grid as one raster grob, so the SVG holds one `<image>` where the tile
  # spelling holds a `<rect>` per cell -- and a selector needs an element per
  # cell to name. This is the highlight-only blind spot xability/maidr#814
  # names: audio, text and braille all read correctly, so nothing that listens
  # to announcements can see that nothing lit up.
  #
  # If a later ggplot2 or renderer does start emitting per-cell elements for a
  # raster, this test fails -- which is the reminder to give it selectors and
  # delete this.
  raster <- raster_layer(raster_plot(ggplot2::geom_raster))
  tile <- raster_layer(raster_plot(ggplot2::geom_tile))

  # Asserted first, or the rest passes vacuously: `NULL$selectors` is `NULL`
  # too, so a chart that emitted no layer at all would look like a chart that
  # emitted one without selectors.
  testthat::expect_false(is.null(raster))

  testthat::expect_true(is.null(raster$selectors) || length(raster$selectors) == 0)
  testthat::expect_false(is.null(tile$selectors))
})
