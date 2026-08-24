# `geom_polygon()` cost a readable chart everything (issue #225)
#
# A polygon is `geom_path()` with its ends joined and its interior filled, and
# `GeomPath` has read as `"line"` for as long as the dispatch has existed. It
# was still the last geom in the #225 sweep left `"unknown"`, which is what
# makes `has_unsupported_layers()` true and drops the *whole plot* to a static
# image (#176). Measured on ggplot2 3.4.4 with `save_html()`:
#
#     geom_point()                     interactive SVG   52,708 bytes
#     geom_point() + geom_polygon()    base64 image      30,913 bytes
#     geom_polygon() alone             base64 image      18,353 bytes
#
# Read rather than skipped, which is the decision #225 asked for rather than
# guessed at: every geom skipped today carries no observations, and a
# polygon's vertices are rows the author supplied. Skipping one that is the
# data would drop it silently, which is worse than the honest picture -- the
# reader is not told anything is missing.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

#' A quadrilateral: four rows, four corners, five drawn edges
#'
#' The fifth edge is the closure and carries no observation, which is why
#' nothing below expects five points.
square <- function() {
  data.frame(x = c(1, 3, 3, 1), y = c(1, 1, 3, 3))
}

#' Two shapes in one layer, split by a column with names in it
two_shapes <- function() {
  data.frame(
    x = c(1, 3, 3, 1, 5, 8, 8, 5),
    y = c(1, 1, 3, 3, 2, 2, 5, 5),
    g = rep(c("a", "b"), each = 4)
  )
}

#' A square with a square hole, written the way ggplot2 asks for one
holed <- function() {
  data.frame(
    x = c(0, 4, 4, 0, 1, 3, 3, 1),
    y = c(0, 0, 4, 4, 1, 1, 3, 3),
    sub = rep(c(1, 2), each = 4)
  )
}

rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

#' Every layer a plot emits, or NULL when the chart fell back to a picture
layers_from <- function(html) {
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

#' One series as "x,y" strings, in the order a reader would walk it
vertices <- function(series) {
  vapply(series, function(point) paste0(point$x, ",", point$y), character(1))
}

#' Whether the element a selector names is in the exported SVG
#'
#' The selectors are ids with their dots escaped for CSS, so the id is
#' recovered by dropping the escapes rather than by parsing the selector.
resolves <- function(selector, html) {
  id <- gsub("\\\\", "", sub("^#", "", selector))
  grepl(paste0('id="', id, '"'), html, fixed = TRUE)
}

#' How many coordinate pairs the element a selector names is drawn from
#'
#' The shape itself, read off the exported SVG. Used where "it resolves" is
#' too weak an assertion -- another layer's polygon resolves too.
drawn_points <- function(selector, html) {
  id <- gsub("\\\\", "", sub("^#", "", selector))
  element <- regmatches(
    html, regexpr(paste0('<polygon id="', id, '"[^>]*>'), html)
  )
  if (length(element) != 1) {
    return(NA_integer_)
  }
  points <- sub('".*$', "", sub('^.*points="', "", element))
  length(strsplit(trimws(points), "\\s+")[[1]])
}


test_that("a polygon layer is claimed rather than left unknown", {
  testthat::skip_if_not_installed("ggplot2")

  # Asked of the classifier directly, upstream of rendering: a regression in
  # the branch shows up here as one failure rather than as a fistful about
  # vertices and selectors.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(square(), ggplot2::aes(x, y)) +
    ggplot2::geom_polygon()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "polygon"
  )
})


test_that("a violin is not swallowed as a ring of vertices", {
  testthat::skip_if_not_installed("ggplot2")

  # The dispatch matches `class(geom)[1]`, and this is the half that keeps
  # that from looking like an oversight. `GeomViolin` and `GeomCrossbar` draw
  # *through* `GeomPolygon` without inheriting it, and `GeomMap` -- measured,
  # `GeomMap < GeomPolygon < Geom` -- does inherit it while being out of
  # scope for #225. An `inherits()` test would claim both.
  adapter <- maidr:::Ggplot2Adapter$new()
  frame <- data.frame(
    g = rep(c("a", "b"), each = 6),
    v = c(1, 2, 3, 4, 5, 6, 2, 3, 4, 5, 6, 7)
  )
  plot <- ggplot2::ggplot(frame, ggplot2::aes(g, v)) + ggplot2::geom_violin()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "violin"
  )
})


test_that("a chart with a polygon on it stays interactive", {
  skip_if_no_render()

  # The regression #225 is about, said the way it was measured: the layer
  # took the whole plot down, so the scatter beside it was unreadable too.
  points <- data.frame(x = c(1, 2, 3, 4), y = c(2, 4, 3, 1))
  plot <- ggplot2::ggplot(points, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::geom_polygon(
      data = square(), ggplot2::aes(x, y), inherit.aes = FALSE, alpha = 0.3
    )

  emitted <- layers_from(rendered(plot))

  testthat::expect_false(is.null(emitted))
  testthat::expect_equal(
    vapply(emitted, function(layer) layer$type, character(1)),
    c("point", "line")
  )
})


test_that("a polygon reads as the closed path it draws", {
  skip_if_no_render()

  # Four rows, four vertices, in the author's order -- and the closing
  # vertex is not repeated, because the closing edge adds no observation.
  # That is ggplot2's own reading as well: under a linear coord
  # `GeomPolygon$draw_panel()` hands grid the munched rows unchanged, so the
  # drawn element holds exactly as many points as the layer has rows.
  emitted <- layers_from(
    rendered(ggplot2::ggplot(square(), ggplot2::aes(x, y)) +
      ggplot2::geom_polygon())
  )

  testthat::expect_length(emitted, 1)
  testthat::expect_equal(emitted[[1]]$type, "line")
  testthat::expect_length(emitted[[1]]$data, 1)
  testthat::expect_equal(
    vertices(emitted[[1]]$data[[1]]), c("1,1", "3,1", "3,3", "1,3")
  )
})


test_that("a polygon reads the same vertices as the path spelling", {
  skip_if_no_render()

  # The point of reading it as a line rather than giving it a shape of its
  # own: two spellings of one mark, one reading. Compared against the path
  # chart rather than against written-down numbers, so a change to how a
  # series is emitted moves both sides together and this keeps asserting
  # what it means to.
  polygon <- layers_from(
    rendered(ggplot2::ggplot(square(), ggplot2::aes(x, y)) +
      ggplot2::geom_polygon())
  )
  path <- layers_from(
    rendered(ggplot2::ggplot(square(), ggplot2::aes(x, y)) +
      ggplot2::geom_path())
  )

  testthat::expect_equal(polygon[[1]]$data, path[[1]]$data)
})


test_that("each shape is addressed by its own drawn element", {
  skip_if_no_render()

  # gridSVG turns one polygon grob into one element per group, which is the
  # granularity the multi-series trace wants -- and the frontend drops the
  # whole layer's highlight unless there is exactly one selector per series.
  html <- rendered(
    ggplot2::ggplot(two_shapes(), ggplot2::aes(x, y, group = g)) +
      ggplot2::geom_polygon()
  )
  layer <- layers_from(html)[[1]]

  testthat::expect_length(layer$data, 2)
  testthat::expect_length(layer$selectors, 2)
  testthat::expect_true(all(vapply(
    layer$selectors, resolves, logical(1), html = html
  )))
  testthat::expect_false(
    identical(layer$selectors[[1]], layer$selectors[[2]])
  )
})


test_that("a shape's series is named by what made it a shape", {
  skip_if_no_render()

  # `aes(group = g)` with nothing else mapped is the plainest way to write
  # two shapes and is how ggplot2's own documentation writes them. A line
  # probes only `colour`, so both series would fall back to "Series 1" and
  # "Series 2" while the chart's data says "a" and "b". ggplot2 records the
  # column under `labels$group` exactly as it records a legend title, so the
  # z label comes out as the column's name.
  layer <- layers_from(rendered(
    ggplot2::ggplot(two_shapes(), ggplot2::aes(x, y, group = g)) +
      ggplot2::geom_polygon()
  ))[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(series) series[[1]]$z, character(1)),
    c("a", "b")
  )
  testthat::expect_equal(layer$axes$z$label, "g")
})


test_that("a fill-split polygon is named the same way", {
  skip_if_no_render()

  # `fill` is the aesthetic a polygon is usually split by, and it is probed
  # first for that reason -- a line has no fill and so probes only colour.
  layer <- layers_from(rendered(
    ggplot2::ggplot(two_shapes(), ggplot2::aes(x, y, fill = g)) +
      ggplot2::geom_polygon()
  ))[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(series) series[[1]]$z, character(1)),
    c("a", "b")
  )
  testthat::expect_equal(layer$axes$z$label, "g")
})


test_that("an outline-split polygon is named the same way", {
  skip_if_no_render()

  # `colour` maps a polygon's outline rather than its face, and it splits
  # the layer into shapes exactly as `fill` does. Probed after `fill` and
  # before `group`, so a chart that maps both is named by its face.
  layer <- layers_from(rendered(
    ggplot2::ggplot(two_shapes(), ggplot2::aes(x, y, colour = g)) +
      ggplot2::geom_polygon(fill = NA)
  ))[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(series) series[[1]]$z, character(1)),
    c("a", "b")
  )
  testthat::expect_equal(layer$axes$z$label, "g")
})


test_that("a shape with a hole is one series holding both its rings", {
  skip_if_no_render()

  # `aes(subgroup =)` is drawn as a `pathgrob` rather than a `polygon`, and
  # its `id` is the subgroup while its `pathId` is the group -- so the group
  # is what has to be counted, and reading `id` would answer two for a chart
  # drawing one shape. gridSVG still emits one `<path>` per `pathId`, both
  # rings in the one `d`, so the addressing is unchanged and the rings are
  # vertices of the same shape.
  html <- rendered(
    ggplot2::ggplot(holed(), ggplot2::aes(x, y, subgroup = sub)) +
      ggplot2::geom_polygon()
  )
  layer <- layers_from(html)[[1]]

  testthat::expect_length(layer$data, 1)
  testthat::expect_equal(
    vertices(layer$data[[1]]),
    c("0,0", "4,0", "4,4", "0,4", "1,1", "3,1", "3,3", "1,3")
  )
  testthat::expect_length(layer$selectors, 1)
  testthat::expect_true(resolves(layer$selectors[[1]], html))
})


test_that("a boxplot's crossbars are not mistaken for a polygon's own", {
  skip_if_no_render()

  # Not defensive: `geom_boxplot()` draws each box's crossbar through
  # `GeomPolygon`, so a boxplot contributes grobs named exactly like a
  # polygon layer's -- and draws them first. Measured on three boxes beside
  # one polygon:
  #
  #     geom_boxplot.gTree.30
  #       ... -> geom_crossbar.gTree.9  -> geom_polygon.polygon.7
  #       ... -> geom_crossbar.gTree.19 -> geom_polygon.polygon.17
  #       ... -> geom_crossbar.gTree.27 -> geom_polygon.polygon.25
  #     geom_polygon.polygon.32                        <- the layer's own
  #
  # Taking the first match would outline a box. Each of those sits inside a
  # tree named after the geom that owns it, so refusing to descend into
  # another layer's tree leaves exactly the layer's own.
  #
  # The polygon layer draws a triangle and a pentagon, so what it is
  # addressing is read off the shapes rather than off the fact that the ids
  # exist: a crossbar is four points, and neither of these is.
  frame <- data.frame(
    g = rep(c("a", "b", "c"), each = 4),
    v = c(1, 2, 3, 4, 2, 3, 4, 5, 3, 4, 5, 6)
  )
  shapes <- data.frame(
    x = c(1, 2, 1.5, 2.2, 2.8, 3, 2.5, 2.4),
    y = c(1, 1, 2, 3, 3, 4, 5, 3.5),
    s = rep(c("t", "p"), times = c(3, 5))
  )
  html <- rendered(
    ggplot2::ggplot(frame, ggplot2::aes(g, v)) +
      ggplot2::geom_boxplot() +
      ggplot2::geom_polygon(
        data = shapes, ggplot2::aes(x, y, group = s),
        inherit.aes = FALSE, alpha = 0.3
      )
  )
  emitted <- layers_from(html)
  polygon <- emitted[[length(emitted)]]

  testthat::expect_equal(polygon$type, "line")
  testthat::expect_length(polygon$selectors, 2)
  testthat::expect_equal(
    vapply(polygon$selectors, drawn_points, integer(1), html = html),
    c(5L, 3L)
  )
})


test_that("a layer whose shapes and series disagree is not addressed", {
  skip_if_no_render()

  # The guard in `curve_selectors()`, asked directly, because nothing a
  # chart can be written as reaches it: the series count and the shape
  # count are the same quantity read two ways, so they agree unless the
  # grob found belongs to something else. That is what it is for -- a
  # mis-resolved grob, which is how the crossbars above would arrive -- and
  # the frontend drops the whole layer's highlight unless there is exactly
  # one selector per series, so a list of the wrong length would outline the
  # wrong shape rather than nothing.
  plot <- ggplot2::ggplot(two_shapes(), ggplot2::aes(x, y, group = g)) +
    ggplot2::geom_polygon()
  table <- ggplot2::ggplotGrob(plot)
  panel <- table$grobs[[which(grepl("^panel", table$layout$name))[1]]]
  processor <- maidr:::Ggplot2PolygonLayerProcessor$new(
    list(index = 1L, type = "polygon", plot = plot)
  )

  testthat::expect_length(processor$curve_selectors(plot, panel, 2L), 2)
  testthat::expect_null(processor$curve_selectors(plot, panel, 3L))
})


test_that("two polygon layers each address their own grob", {
  skip_if_no_render()

  # ggplot2 draws one grob per layer in layer order, so the second layer
  # wants the second match. The two layers' series are emitted together --
  # which is what two `geom_path()` layers do as well -- so what this pins
  # is that the three series carry three distinct selectors, the first two
  # from one grob and the third from the other.
  html <- rendered(
    ggplot2::ggplot(two_shapes(), ggplot2::aes(x, y, group = g)) +
      ggplot2::geom_polygon(alpha = 0.3) +
      ggplot2::geom_polygon(
        data = square(), ggplot2::aes(x, y), inherit.aes = FALSE, fill = "red"
      )
  )
  layer <- layers_from(html)[[1]]

  testthat::expect_length(layer$data, 3)
  testthat::expect_length(unique(unlist(layer$selectors)), 3)
  testthat::expect_true(all(vapply(
    layer$selectors, resolves, logical(1), html = html
  )))
})


test_that("an empty polygon layer is still skipped", {
  skip_if_no_render()

  # Claiming the geom must not undo #227: a layer that drew nothing has no
  # mark for a reader to miss, and emitting it would put an empty series in
  # the payload to land on. That is decided upstream of the dispatch, by
  # rows rather than by kind, so this is the guard that it still is.
  points <- data.frame(x = c(1, 2, 3, 4), y = c(2, 4, 3, 1))
  emitted <- layers_from(rendered(
    ggplot2::ggplot(points, ggplot2::aes(x, y)) +
      ggplot2::geom_point() +
      ggplot2::geom_polygon(
        data = square()[0, ], ggplot2::aes(x, y), inherit.aes = FALSE
      )
  ))

  testthat::expect_equal(
    vapply(emitted, function(layer) layer$type, character(1)), "point"
  )
})
