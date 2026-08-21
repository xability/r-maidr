# `geom_curve()` draws schedules too, and gridSVG could not export one (#195)
#
# A curve computes exactly the four columns a segment does -- `x`, `xend`,
# `y`, `yend` -- so it reads as the same gantt: the curvature is a drawing
# instruction that never becomes a position. It was refused anyway, and on
# the export rather than on the reading. `gridSVG::grid.export()` aborts with
# "All SVG style attribute values must have length 1" on the `curve` grob
# ggplot2 draws, so claiming the layer turned a chart that rendered as a
# picture into a `save_html()` that raised.
#
# Measured on ggplot2 3.4.4 with gridSVG 1.7.5: a four-row layer arrives as
# one `curve` grob whose `x1`, `y1`, `x2`, `y2` **and** `gp$col`, `gp$fill`,
# `gp$lwd`, `gp$lty` are all length 4. A `segments` grob is just as vectorised
# and exports fine only because gridSVG has a method that splits it; there is
# none for `curve`. `split_vectorised_curve_grobs()` does that split here.
#
# Slicing the gpar rather than scalarising it is the part worth asserting:
# taking `gp[[1]]` would also satisfy gridSVG and would paint every row the
# first row's colour.

skip_if_no_curve_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

curve_lanes_on_y <- ggplot2::aes(x = start, xend = end, y = task, yend = task)
curve_coloured <- ggplot2::aes(
  x = start, xend = end, y = task, yend = task, colour = owner
)
curve_edges <- ggplot2::aes(x = x, xend = xend, y = y, yend = yend)

#' The same four-interval schedule the segment tests use, plus an owner column
#' so a per-row aesthetic has something to vary on
curve_schedule <- function() {
  data.frame(
    task = factor(
      c("design", "build", "test", "build"),
      levels = c("design", "build", "test")
    ),
    start = c(0, 3, 8, 12),
    end = c(3, 8, 11, 15),
    owner = c("ana", "bo", "cy", "bo")
  )
}

curve_plot <- function(mapping = curve_lanes_on_y, frame = curve_schedule()) {
  ggplot2::ggplot(frame) + ggplot2::geom_curve(mapping)
}

curve_html <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

curve_layer <- function(html) {
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
  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

curve_intervals <- function(layer) {
  lapply(layer$data, function(lane) {
    vapply(
      lane,
      function(one) sprintf("%s %g-%g", one$x, one$start, one$end),
      character(1)
    )
  })
}

curve_ids <- function(layer) {
  sub("^\\*\\[id='", "", sub("'\\]$", "", unlist(layer$selectors)))
}


test_that("a curve layer laying intervals in lanes reaches the gantt processor", {
  testthat::skip_if_not_installed("ggplot2")

  # Asked of the classifier directly, upstream of rendering, for the reason
  # the segment tests give: a regression here would otherwise surface as a
  # fistful of failures about lanes and selectors rather than one about the
  # branch that broke.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- curve_plot()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "gantt"
  )
})

test_that("a curve layer whose ends share nothing is still not a schedule", {
  testthat::skip_if_not_installed("ggplot2")

  # Claiming the geom did not relax the question the layer has to answer.
  # An edge in a node-link diagram has no lane to sit in whether it is drawn
  # straight or bent.
  adapter <- maidr:::Ggplot2Adapter$new()
  frame <- data.frame(x = c(0, 1), xend = c(2, 3), y = c(0, 1), yend = c(2, 3))
  plot <- ggplot2::ggplot(frame) + ggplot2::geom_curve(curve_edges)

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "unknown"
  )
})

test_that("a curve schedule renders instead of raising on export", {
  skip_if_no_curve_render()

  # The regression this issue is about. Before the split, this call died in
  # `gridSVG:::svgStyleAttributes()` with "All SVG style attribute values must
  # have length 1" and took the whole figure with it.
  html <- curve_html(curve_plot())

  testthat::expect_true(nchar(html) > 0)
  testthat::expect_false(is.null(curve_layer(html)))
})

test_that("a curve schedule reads the same lanes a segment one does", {
  skip_if_no_curve_render()

  layer <- curve_layer(curve_html(curve_plot()))

  testthat::expect_equal(layer$type, "gantt")
  testthat::expect_equal(
    curve_intervals(layer),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )
})

test_that("each curved interval addresses its own drawn element", {
  skip_if_no_curve_render()

  html <- curve_html(curve_plot())
  layer <- curve_layer(html)
  ids <- curve_ids(layer)

  # One selector per interval, and the emission order is the lane grouping's:
  # built rows 1, 2, 4, 3 read as design, build, build, test.
  testthat::expect_equal(length(ids), 4L)
  testthat::expect_equal(length(unique(ids)), 4L)

  # A `curve` grob puts the row number before gridSVG's own `.1`, where a
  # `segments` grob puts it after -- the split names each child
  # `<grob>.<row>` and gridSVG appends `.1` to that. Pinned because a
  # selector built to the segment shape would match nothing at all.
  testthat::expect_true(all(grepl("\\.[0-9]+\\.1$", ids)))

  # The pairing, not just the shape. Highlighting is the one modality an
  # accessibility suite cannot hear go wrong: audio, text and braille all read
  # correctly while the wrong element lights up (xability/maidr#814). The
  # built rows are 1, 2, 4, 3 once the lanes are grouped, and the selectors
  # have to follow that regrouping rather than the document order.
  testthat::expect_equal(
    as.integer(sub("^.*\\.([0-9]+)\\.1$", "\\1", ids)),
    c(1L, 2L, 4L, 3L)
  )

  # And every one of them is an element the document actually has.
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0("id=\"", id, "\""), html, fixed = TRUE),
      info = paste("no element in the exported SVG for", id)
    )
  }
})

test_that("a curve layer keeps each row's own colour through the split", {
  skip_if_no_curve_render()

  # The falsification of the cheap fix. Scalarising the vectorised gpar --
  # keeping `gp[[1]]` -- also satisfies gridSVG, and would paint all four
  # rows the first one's colour. Three owners over four rows means three
  # distinct strokes, with the repeated owner repeating its colour.
  html <- curve_html(curve_plot(curve_coloured))
  ids <- curve_ids(curve_layer(html))
  testthat::expect_equal(length(ids), 4L)

  strokes <- vapply(ids, function(id) {
    element <- regmatches(
      html,
      regexpr(paste0("<[a-z]+ id=\"", id, "\"[^>]*>"), html)
    )
    if (length(element) != 1) {
      return(NA_character_)
    }
    found <- regmatches(element, regexpr('stroke="[^"]*"', element))
    if (length(found) == 1) found else NA_character_
  }, character(1))

  testthat::expect_false(anyNA(strokes))
  testthat::expect_equal(length(unique(strokes)), 3L)
})

test_that("a curve after a segment finds its own grob, not the second segments one", {
  skip_if_no_curve_render()

  # Both layers are gantts, and each is the *first* grob of its own kind in
  # the panel. Counting them together would send the curve looking for a
  # second `segments` grob, which does not exist -- and a layer that resolves
  # to no grob announces every interval and highlights none of them.
  plot <- ggplot2::ggplot(curve_schedule()) +
    ggplot2::geom_segment(curve_lanes_on_y) +
    ggplot2::geom_curve(curve_lanes_on_y)

  html <- curve_html(plot)
  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  for (pair in list(
    c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"),
    c("&amp;", "&"), c("&#39;", "'")
  )) {
    json <- gsub(pair[1], pair[2], json, fixed = TRUE)
  }
  layers <- jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers

  testthat::expect_equal(length(layers), 2L)
  curve <- layers[[2]]
  testthat::expect_equal(curve$type, "gantt")

  ids <- sub("^\\*\\[id='", "", sub("'\\]$", "", unlist(curve$selectors)))
  testthat::expect_equal(length(ids), 4L)
  testthat::expect_true(all(grepl("^GRID\\.curve\\.", ids)))
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0("id=\"", id, "\""), html, fixed = TRUE),
      info = paste("no element in the exported SVG for", id)
    )
  }
})

test_that("splitting a curve pushes its viewport once, not once per row", {
  testthat::skip_if_not_installed("ggplot2")

  # Asserted directly because ggplot2's own curve grobs carry no viewport, so
  # no rendered chart reaches this. Leaving the vp on the children as well as
  # the wrapper would push it twice -- nesting a relative viewport inside
  # itself and shrinking every curve into a corner of its own panel.
  vp <- grid::viewport(width = 0.5, height = 0.5, name = "half")
  curve <- grid::curveGrob(
    x1 = grid::unit(c(0, 0.2), "npc"), y1 = grid::unit(c(0, 0.2), "npc"),
    x2 = grid::unit(c(1, 0.8), "npc"), y2 = grid::unit(c(1, 0.8), "npc"),
    gp = grid::gpar(col = c("red", "blue")), name = "two", vp = vp
  )

  split <- maidr:::split_one_curve(curve)

  testthat::expect_true(inherits(split, "gTree"))
  testthat::expect_equal(split$name, "two")
  testthat::expect_identical(split$vp, vp)
  testthat::expect_equal(length(split$children), 2L)
  for (child in split$children) {
    testthat::expect_null(child$vp)
    # And each row kept its own colour rather than the first row's.
    testthat::expect_equal(length(child$gp$col), 1L)
  }
  testthat::expect_equal(
    vapply(split$children, function(ch) ch$gp$col, character(1)),
    c("red", "blue"),
    ignore_attr = TRUE
  )
})

test_that("a single-row curve is left exactly as it was", {
  testthat::skip_if_not_installed("ggplot2")

  # It already satisfies gridSVG, and wrapping it would change the element id
  # its selector is built from.
  curve <- grid::curveGrob(
    x1 = grid::unit(0, "npc"), y1 = grid::unit(0, "npc"),
    x2 = grid::unit(1, "npc"), y2 = grid::unit(1, "npc"), name = "one"
  )

  testthat::expect_identical(maidr:::split_one_curve(curve), curve)
})
