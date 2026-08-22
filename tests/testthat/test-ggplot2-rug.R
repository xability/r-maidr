# `geom_rug()` read as nothing at all (issue #222)
#
# A rug draws one short tick per row against the panel's edge, and what it
# states is the raw data -- exactly what the density curve or histogram it
# usually accompanies does not. `GeomRug` matched no dispatch branch, so the
# layer reached `Ggplot2UnknownLayerProcessor`: a rug-only chart emitted one
# empty layer and a rug beside a scatter added an empty one a reader could
# land on and find nothing in.
#
#   rug alone     layers: 1   type=unknown  n=0  selectors=
#
# Read as points, which is the reading py-maidr settled on for
# `seaborn.rugplot` (xability/py-maidr#250): `length` is one number for the
# whole layer, so a tick's length is decoration and only its position is data.
#
# Two things had to be measured rather than assumed, and both are asserted
# here.
#
# **A rug can mark both axes.** `sides` defaults to `"bl"`, so on a chart with
# both aesthetics mapped it marks the x observations *and* the y ones, and the
# built data carries both columns. Two layers, not one -- and not one per
# drawn grob either, because `sides = "trbl"` draws the same x observations
# twice.
#
# **Which axes are marked needs both halves.** Reading the built data's
# columns alone emitted a y layer for `geom_rug(sides = "b")` on `aes(v, w)`:
# observations the chart never marked, invented out of an aesthetic mapped for
# the scatter underneath. Reading `sides` alone fails the other way, since it
# says `"bl"` on a rug that has no `y` to mark.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

VALUES <- c(1.5, 2.5, 3.5, 7.0)
HEIGHTS <- c(10, 20, 30, 40)

frame <- function() {
  data.frame(v = VALUES, w = HEIGHTS)
}

rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

#' Every layer a plot emits
#'
#' Read out of the **rendered** page rather than from a second orchestrator
#' call, and that distinction is load-bearing rather than incidental. A rug's
#' grobs carry grid's automatic names, whose numbers come from a global
#' counter that `ggplotGrob()` advances -- so building the schema separately
#' from the render gives two different sets of ids and every selector names an
#' element that does not exist in the page under test. Which is a property of
#' the test, not of the layer: the processor is handed the gtable being
#' exported and reads the names off that.
layers_from <- function(html) {
  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(list())
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

layers_of <- function(plot) {
  layers_from(rendered(plot))
}

#' `(x, y)` per emitted entry, in emission order
positions <- function(layer) {
  lapply(layer$data, function(point) c(point$x, point$y))
}

test_that("a rug is no longer an empty unknown layer", {
  skip_if_no_render()

  layers <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(x = v)) +
    ggplot2::geom_rug())

  testthat::expect_length(layers, 1L)
  testthat::expect_identical(layers[[1]]$type, "point")
  testthat::expect_length(layers[[1]]$data, length(VALUES))
})

test_that("the observations are the ones the data has", {
  skip_if_no_render()

  layer <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(x = v)) +
    ggplot2::geom_rug())[[1]]

  # The tick's position is the observation; the coordinate across it is a
  # constant, because the tick's own base is a fraction of the panel and
  # would read as data at whatever scale the other axis happens to use.
  testthat::expect_equal(positions(layer), lapply(VALUES, function(v) c(v, 0)))
})

test_that("a rug up the y axis puts its observations on y", {
  skip_if_no_render()

  layer <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(y = v)) +
    ggplot2::geom_rug())[[1]]

  testthat::expect_equal(positions(layer), lapply(VALUES, function(v) c(0, v)))
})

test_that("the strip the ticks sit in is named rather than left as a value", {
  skip_if_no_render()

  # Renamed even where the caller labelled it: a rug under a density curve has
  # a real "density" label on that axis, and every entry sits at 0 rather than
  # at any density.
  layer <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(x = v)) +
    ggplot2::geom_rug() + ggplot2::labs(x = "speed", y = "density"))[[1]]

  testthat::expect_identical(layer$axes$x$label, "speed")
  testthat::expect_identical(layer$axes$y$label, "Rug")
})

test_that("a rug marking both axes reads as one layer each", {
  skip_if_no_render()

  layers <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(v, w)) +
    ggplot2::geom_rug())

  testthat::expect_length(layers, 2L)
  testthat::expect_equal(positions(layers[[1]]), lapply(VALUES, function(v) c(v, 0)))
  testthat::expect_equal(positions(layers[[2]]), lapply(HEIGHTS, function(h) c(0, h)))
  testthat::expect_identical(layers[[1]]$axes$y$label, "Rug")
  testthat::expect_identical(layers[[2]]$axes$x$label, "Rug")
})

test_that("an axis the rug does not mark gets no layer", {
  skip_if_no_render()

  # The defect the first draft had: `y` is mapped for the chart, and
  # `sides = "b"` draws no left rug, so announcing the heights would be a
  # whole layer of observations this rug never marked.
  layers <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(v, w)) +
    ggplot2::geom_rug(sides = "b"))

  testthat::expect_length(layers, 1L)
  testthat::expect_equal(positions(layers[[1]]), lapply(VALUES, function(v) c(v, 0)))
})

test_that("an axis with no aesthetic gets no layer, though sides names it", {
  skip_if_no_render()

  # The other half. `sides` defaults to "bl" on every rug, including one drawn
  # over `aes(x = v)` alone, which has no `y` to mark.
  layers <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(x = v)) +
    ggplot2::geom_rug())

  testthat::expect_length(layers, 1L)
  testthat::expect_identical(layers[[1]]$axes$x$label, "v")
})

test_that("an axis drawn on both edges is announced once", {
  skip_if_no_render()

  # `sides = "trbl"` draws the x observations at top *and* bottom. They are
  # one set of observations drawn twice, and emitting both would have a reader
  # navigate the same numbers under two names.
  layers <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(v, w)) +
    ggplot2::geom_rug(sides = "trbl"))

  testthat::expect_length(layers, 2L)
  testthat::expect_equal(positions(layers[[1]]), lapply(VALUES, function(v) c(v, 0)))
  testthat::expect_equal(positions(layers[[2]]), lapply(HEIGHTS, function(h) c(0, h)))
})

test_that("each tick is addressed by its own drawn element", {
  skip_if_no_render()

  html <- rendered(ggplot2::ggplot(frame(), ggplot2::aes(x = v)) +
    ggplot2::geom_rug())
  selectors <- unlist(layers_from(html)[[1]]$selectors)

  testthat::expect_equal(length(selectors), length(VALUES))
  ids <- sub("^\\*\\[id='", "", sub("'\\]$", "", selectors))
  testthat::expect_equal(sub("^.*\\.", "", ids), c("1", "2", "3", "4"))
  testthat::expect_equal(length(unique(ids)), length(VALUES))

  # And the elements are really there. A selector naming nothing is the
  # highlight-only blind spot: audio, text and braille all read correctly and
  # nothing lights up, which no assertion about the payload alone can see.
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0('id="', id, '"'), html, fixed = TRUE),
      info = paste("selector resolves to no element:", id)
    )
  }
})

test_that("the two axes of one rug address different elements", {
  skip_if_no_render()

  html <- rendered(ggplot2::ggplot(frame(), ggplot2::aes(v, w)) +
    ggplot2::geom_rug())
  layers <- layers_from(html)
  ids <- unlist(lapply(layers, function(l) {
    sub("^\\*\\[id='", "", sub("'\\]$", "", unlist(l$selectors)))
  }))

  # Eight ticks, eight distinct elements. Sharing a grob between the two would
  # highlight an x observation while announcing a y one.
  testthat::expect_equal(length(ids), 8L)
  testthat::expect_equal(length(unique(ids)), 8L)
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0('id="', id, '"'), html, fixed = TRUE),
      info = paste("selector resolves to no element:", id)
    )
  }
})

test_that("a second rug layer addresses its own ticks", {
  skip_if_no_render()

  # Each rug wraps its grobs in a gTree of its own, so the second reaches the
  # second wrapper. Counting grobs alone could not do it: one layer draws one
  # to four of them.
  html <- rendered(ggplot2::ggplot(frame(), ggplot2::aes(v, w)) +
    ggplot2::geom_rug(sides = "b") +
    ggplot2::geom_rug(sides = "l"))
  layers <- layers_from(html)

  testthat::expect_length(layers, 2L)
  ids <- unlist(lapply(layers, function(l) {
    sub("^\\*\\[id='", "", sub("'\\]$", "", unlist(l$selectors)))
  }))
  testthat::expect_equal(length(unique(ids)), 8L)
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0('id="', id, '"'), html, fixed = TRUE),
      info = paste("selector resolves to no element:", id)
    )
  }
})

test_that("a segment layer's grob is not mistaken for a rug's", {
  skip_if_no_render()

  # `geom_segment()` draws a bare `segments` grob directly under the panel,
  # while a rug wraps its own in a gTree -- which is what tells them apart.
  # Matching on the class alone would give the rug the segment layer's
  # elements, so its ticks would announce and the schedule would light up.
  # The segments lay intervals in lanes, so the layer reads as a gantt. A
  # segment layer whose ends share nothing reads as `unknown`, and one
  # unknown layer takes the whole chart down to a picture -- so that chart
  # would test the fallback rather than this.
  html <- rendered(ggplot2::ggplot(
    data.frame(start = VALUES, finish = VALUES + 1, task = c("a", "b", "c", "d")),
    ggplot2::aes(x = start, xend = finish, y = task, yend = task)
  ) +
    ggplot2::geom_segment() +
    ggplot2::geom_rug(sides = "b"))

  rug <- Filter(function(l) identical(l$axes$y$label, "Rug"), layers_from(html))
  testthat::expect_length(rug, 1L)

  ids <- sub("^\\*\\[id='", "", sub("'\\]$", "", unlist(rug[[1]]$selectors)))
  testthat::expect_equal(length(ids), length(VALUES))
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0('id="', id, '"'), html, fixed = TRUE),
      info = paste("selector resolves to no element:", id)
    )
  }
})

test_that("a rug beside a scatter leaves the scatter alone", {
  skip_if_no_render()

  layers <- layers_of(ggplot2::ggplot(frame(), ggplot2::aes(v, w)) +
    ggplot2::geom_point() +
    ggplot2::geom_rug(sides = "b"))

  testthat::expect_length(layers, 2L)
  testthat::expect_identical(layers[[1]]$type, "point")
  testthat::expect_equal(
    positions(layers[[1]]),
    Map(function(v, w) c(v, w), VALUES, HEIGHTS),
    ignore_attr = TRUE
  )
  testthat::expect_identical(layers[[2]]$axes$y$label, "Rug")
})

test_that("the layer withdraws its selectors rather than guess at a grob", {
  skip_if_no_render()

  # A selector list that does not match the point count is withdrawn wholesale
  # by the frontend rather than applied in part (#145), so a guess at the
  # grob's name is worse than no highlighting. Asserted directly: no chart
  # measured reaches it, because every rug wraps its grobs.
  processor <- maidr:::Ggplot2RugLayerProcessor$new(list(index = 1))
  plot <- ggplot2::ggplot(frame(), ggplot2::aes(x = v)) + ggplot2::geom_point()

  testthat::expect_length(
    processor$generate_selectors(plot, ggplot2::ggplotGrob(plot), "x", 4L), 0L
  )
  # And no ticks means no selectors, whatever the grob says.
  rug <- ggplot2::ggplot(frame(), ggplot2::aes(x = v)) + ggplot2::geom_rug()
  testthat::expect_length(
    processor$generate_selectors(rug, ggplot2::ggplotGrob(rug), "x", 0L), 0L
  )
})

test_that("no other geom draws a gTree of nothing but segments", {
  skip_if_no_render()

  # What makes the name test in `wraps_a_rug()` a guard rather than a live
  # branch: the class test alone already excludes every other geom, because
  # none of them wraps segments in a gTree at all. Pinned rather than
  # asserted of the processor, because it is a fact about ggplot2 -- so the
  # release that ends it turns this red and the guard becomes load-bearing,
  # instead of the processor quietly claiming another layer's grob.
  all_segment_trees <- function(plot) {
    hits <- character(0)
    walk <- function(node) {
      if (!inherits(node, "gTree")) {
        return(invisible(NULL))
      }
      children <- node$children
      if (length(children) > 0 &&
        all(vapply(children, function(k) inherits(k, "segments"), logical(1)))) {
        hits <<- c(hits, node$name)
      }
      for (child in children) walk(child)
      invisible(NULL)
    }
    for (grob in ggplot2::ggplotGrob(plot)$grobs) walk(grob)
    hits
  }

  df <- data.frame(
    g = rep(c("a", "b"), each = 4), v = c(VALUES, HEIGHTS),
    lo = c(VALUES, HEIGHTS) - 1, hi = c(VALUES, HEIGHTS) + 1
  )
  drawn_with_segments <- list(
    boxplot = ggplot2::ggplot(df, ggplot2::aes(g, v)) + ggplot2::geom_boxplot(),
    violin = ggplot2::ggplot(df, ggplot2::aes(g, v)) + ggplot2::geom_violin(),
    errorbar = ggplot2::ggplot(df, ggplot2::aes(g, v, ymin = lo, ymax = hi)) +
      ggplot2::geom_errorbar(),
    crossbar = ggplot2::ggplot(df, ggplot2::aes(g, v, ymin = lo, ymax = hi)) +
      ggplot2::geom_crossbar(),
    pointrange = ggplot2::ggplot(df, ggplot2::aes(g, v, ymin = lo, ymax = hi)) +
      ggplot2::geom_pointrange(),
    linerange = ggplot2::ggplot(df, ggplot2::aes(g, ymin = lo, ymax = hi)) +
      ggplot2::geom_linerange(),
    reference = ggplot2::ggplot(df, ggplot2::aes(v, v)) + ggplot2::geom_line() +
      ggplot2::geom_hline(yintercept = 5)
  )

  for (name in names(drawn_with_segments)) {
    testthat::expect_length(all_segment_trees(drawn_with_segments[[name]]), 0L)
  }

  # And a rug does draw one, so the check above is of the right property.
  rug <- ggplot2::ggplot(df, ggplot2::aes(x = v)) + ggplot2::geom_rug()
  trees <- all_segment_trees(rug)
  testthat::expect_length(trees, 1L)
  testthat::expect_true(startsWith(trees[[1]], "GRID.gTree"))
})

test_that("a layer carrying no sides falls back to ggplot2's own default", {
  skip_if_no_render()

  # `geom_rug()` always populates `sides` -- measured, its `geom_params` are
  # `outside, sides, length, na.rm` -- so the fallback is for a layer built by
  # hand, and no chart reaches it. Asserted directly, because a default that
  # no test pins is a default that can drift to anything: "b" instead of "bl"
  # passes every chart-level test in this file and silently drops the y half
  # of every rug that omits the parameter.
  processor <- maidr:::Ggplot2RugLayerProcessor$new(list(index = 1))
  rows <- data.frame(x = VALUES, y = HEIGHTS)

  testthat::expect_identical(
    processor$marked_axes(rows, list(geom_params = list())), c("x", "y")
  )
  # And it is a fallback, not an override: a layer that does say gets its say.
  testthat::expect_identical(
    processor$marked_axes(rows, list(geom_params = list(sides = "b"))), "x"
  )
})
