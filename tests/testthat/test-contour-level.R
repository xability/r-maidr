# `geom_contour()` computes its levels as numbers, and read as nothing (#198)
#
# A contour draws a scalar field as curves of constant value, and this is the
# one chart of its family whose value is a **number rather than a colour**:
# `ggplot_build()` puts `level` on every row. That is what left the same chart
# unread in the Observable adapter (xability/maidr#1084), where the magnitude
# survives only in a continuous fill, and what makes it readable here.
#
# ggplot2 hands over more than matplotlib does. A field with two peaks crosses
# a level twice, and `piece` already separates the two islands -- so there is
# nothing to split apart, unlike xability/py-maidr#540, where both arrive in
# one compound path and reading them as one series would announce a straight
# line across the saddle between the peaks.
#
# The **filled** forms are a different chart and say so in the frame: their
# `level` is a factor of band intervals -- "(0.0, 0.1]" -- because they draw
# the bands between levels rather than the levels. Announcing one of those
# outlines as a level's own curve would be right for half of its points.
#
# One interaction needed care. `GeomContour` draws a bare `polylineGrob`, so a
# contour layer joins the auto-named candidates a `geom_line()` is indexed
# among. A count that skipped it would give each layer the other's curves --
# both charts reading correctly and both outlining the wrong thing, which is
# the blind spot xability/maidr#814 names.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

peaks_aes <- ggplot2::aes(x = x, y = y, z = z)
points_aes <- ggplot2::aes(x = a, y = b)
line_aes <- ggplot2::aes(x = x, y = y)

#' A field with two peaks, so every level crosses it twice
two_peaks <- function() {
  frame <- expand.grid(
    x = seq(-4, 4, length.out = 60),
    y = seq(-3, 3, length.out = 60)
  )
  frame$z <- exp(-((frame$x - 1.8)^2 + frame$y^2)) +
    exp(-((frame$x + 1.8)^2 + frame$y^2))
  frame
}

scattered <- function() {
  set.seed(1)
  data.frame(a = stats::rnorm(200), b = stats::rnorm(200))
}

a_line <- function() {
  frame <- data.frame(x = seq(-4, 4, length.out = 20))
  frame$y <- sin(frame$x)
  frame
}

field_plot <- function(breaks = c(0.3, 0.6)) {
  ggplot2::ggplot(two_peaks(), peaks_aes) + ggplot2::geom_contour(breaks = breaks)
}

rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

layers_of <- function(plot, html = NULL) {
  if (is.null(html)) {
    html <- rendered(plot)
  }
  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(NULL)
  }
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  for (pair in list(
    c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"),
    c("&amp;", "&"), c("&#39;", "'")
  )) {
    json <- gsub(pair[1], pair[2], json, fixed = TRUE)
  }
  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers
}

#' The element id a selector names, whichever of the two forms it is in
#'
#' This package emits both: `*[id='GRID.polyline.1.1.1']`, which needs no
#' escaping, and `#GRID\\.polyline\\.1\\.1\\.1`, which the line processor has
#' always written. Both are valid CSS and both resolve; a test that knew only
#' one would report the other as naming nothing.
selector_id <- function(selector) {
  bracketed <- sub("^\\*\\[id='", "", sub("'\\]$", "", selector))
  if (!identical(bracketed, selector)) {
    return(bracketed)
  }
  gsub("\\\\", "", sub("^#", "", selector))
}


#' The level each emitted curve runs at
levels_of <- function(layer) {
  vapply(layer$data, function(curve) curve[[1]]$level, numeric(1))
}


test_that("a contour layer reaches the contour processor at all", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- field_plot()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "contour"
  )

  density <- ggplot2::ggplot(scattered(), points_aes) + ggplot2::geom_density_2d()

  testthat::expect_equal(
    adapter$detect_layer_type(density$layers[[1]], density), "contour"
  )
})

test_that("a filled contour is not claimed", {
  testthat::skip_if_not_installed("ggplot2")

  # It draws the bands between levels rather than the levels, so `level`
  # arrives as a factor of intervals instead of a number.
  adapter <- maidr:::Ggplot2Adapter$new()
  filled <- ggplot2::ggplot(two_peaks(), peaks_aes) + ggplot2::geom_contour_filled()
  filled_density <- ggplot2::ggplot(scattered(), points_aes) +
    ggplot2::geom_density_2d_filled()

  testthat::expect_equal(
    adapter$detect_layer_type(filled$layers[[1]], filled), "unknown"
  )
  testthat::expect_equal(
    adapter$detect_layer_type(filled_density$layers[[1]], filled_density), "unknown"
  )
})

test_that("a field is read as the curves it draws", {
  skip_if_no_render()

  layers <- layers_of(field_plot())

  testthat::expect_false(is.null(layers))
  testthat::expect_equal(length(layers), 1L)
  testthat::expect_equal(layers[[1]]$type, "contour")
})

test_that("every curve carries the level it runs at, constant down the curve", {
  skip_if_no_render()

  layer <- layers_of(field_plot())[[1]]

  # Two levels, each crossing the field twice.
  testthat::expect_equal(levels_of(layer), c(0.3, 0.3, 0.6, 0.6))
  for (curve in layer$data) {
    testthat::expect_equal(
      length(unique(vapply(curve, function(p) p$level, numeric(1)))), 1L
    )
  }
})

test_that("each island of a level is its own curve", {
  skip_if_no_render()

  # Read as one series per level, the two islands would be joined by a
  # straight line across the saddle -- a curve announced over ground the
  # field never took.
  layer <- layers_of(field_plot())[[1]]

  sides <- vapply(layer$data, function(curve) {
    xs <- vapply(curve, function(p) p$x, numeric(1))
    length(unique(sign(xs[xs != 0])))
  }, numeric(1))

  testthat::expect_equal(length(layer$data), 4L)
  testthat::expect_true(all(sides == 1))
})

test_that("the curves run where the field reaches that value", {
  skip_if_no_render()

  # A single gaussian bump centred on the origin: the 0.5 contour is the
  # circle of radius sqrt(-ln 0.5). Checked against the field rather than
  # against ggplot2's own output.
  frame <- expand.grid(
    x = seq(-3, 3, length.out = 60), y = seq(-3, 3, length.out = 60)
  )
  frame$z <- exp(-(frame$x^2 + frame$y^2))
  layer <- layers_of(
    ggplot2::ggplot(frame, peaks_aes) + ggplot2::geom_contour(breaks = 0.5)
  )[[1]]

  radius <- sqrt(-log(0.5))
  distances <- vapply(layer$data[[1]], function(p) sqrt(p$x^2 + p$y^2), numeric(1))

  testthat::expect_lt(max(abs(distances - radius)), 0.05)
})

test_that("a density estimate is read the same way", {
  skip_if_no_render()

  layer <- layers_of(
    ggplot2::ggplot(scattered(), points_aes) + ggplot2::geom_density_2d()
  )[[1]]

  testthat::expect_equal(layer$type, "contour")
  # Computed levels rather than asked-for ones, and more than one of them.
  testthat::expect_gt(length(unique(levels_of(layer))), 1L)
  testthat::expect_true(all(levels_of(layer) > 0))
})

test_that("each curve is addressed by its own drawn element", {
  skip_if_no_render()

  html <- rendered(field_plot())
  layer <- layers_of(NULL, html)[[1]]
  selectors <- unlist(layer$selectors)

  # One per curve, numbered by piece, and each really in the SVG. A selector
  # naming nothing is the highlight-only blind spot xability/maidr#814
  # describes: everything reads and nothing lights up.
  testthat::expect_equal(length(selectors), length(layer$data))

  ids <- vapply(selectors, selector_id, character(1))
  testthat::expect_equal(unname(sub("^.*\\.", "", ids)), c("1", "2", "3", "4"))
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0('id="', id, '"'), html, fixed = TRUE),
      info = paste("selector resolves to no element:", id)
    )
  }
})

test_that("a line beside a contour keeps its own curves", {
  skip_if_no_render()

  # Both draw a bare `polylineGrob`, so they share the candidate list a layer
  # is indexed among. A count that skipped the contour would hand each layer
  # the other's elements -- read correctly, outlined wrongly.
  for (order in list("line first", "contour first")) {
    plot <- if (identical(order, "line first")) {
      ggplot2::ggplot() +
        ggplot2::geom_line(data = a_line(), mapping = line_aes) +
        ggplot2::geom_contour(data = two_peaks(), mapping = peaks_aes, breaks = c(0.3, 0.6))
    } else {
      ggplot2::ggplot() +
        ggplot2::geom_contour(data = two_peaks(), mapping = peaks_aes, breaks = c(0.3, 0.6)) +
        ggplot2::geom_line(data = a_line(), mapping = line_aes)
    }
    html <- rendered(plot)
    layers <- layers_of(NULL, html)

    testthat::expect_equal(
      sort(vapply(layers, function(l) l$type, character(1))),
      c("contour", "line"),
      info = order
    )

    grobs <- lapply(layers, function(l) {
      ids <- vapply(unlist(l$selectors), selector_id, character(1))
      unique(sub("\\.1(\\.[0-9]+)?$", "", ids))
    })
    testthat::expect_false(identical(grobs[[1]], grobs[[2]]), info = order)

    for (id in unlist(lapply(layers, function(l) {
      vapply(unlist(l$selectors), selector_id, character(1))
    }))) {
      testthat::expect_true(
        grepl(paste0('id="', id, '"'), html, fixed = TRUE),
        info = paste(order, "-- selector resolves to no element:", id)
      )
    }
  }
})

test_that("polyline_layer_position counts a contour alongside a line", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot() +
    ggplot2::geom_line(data = a_line(), mapping = line_aes) +
    ggplot2::geom_contour(data = two_peaks(), mapping = peaks_aes, breaks = 0.3)

  testthat::expect_equal(maidr:::polyline_layer_position(plot, 1), 1L)
  testthat::expect_equal(maidr:::polyline_layer_position(plot, 2), 2L)
})

test_that("a frame whose level is a band is refused by the reader too", {
  testthat::skip_if_not_installed("ggplot2")

  # The classification names the two filled geoms, but the reader asks the
  # frame as well -- so a stat that ever produced banded levels under a line
  # geom is declined rather than announced with a factor where a number goes.
  built <- ggplot2::ggplot_build(
    ggplot2::ggplot(two_peaks(), peaks_aes) + ggplot2::geom_contour_filled()
  )

  testthat::expect_equal(
    length(maidr:::contour_curves(built$data[[1]])$data), 0L
  )
})
