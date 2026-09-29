# Reading lattice's bwplot(), levelplot() and contourplot() (#333)
#
# All three draw every mark of a kind in one grob per panel, and the reading
# names each mark by its position in that grob, so a reading that is right
# about the values can still point every highlight at the wrong mark. Each
# test therefore checks two things against sources the reading does not
# compute:
#
#   * the values, against R's own statistics -- `boxplot.stats()` over the
#     rows of each level, the data frame's own cells, `contourLines()` over
#     the panel's grid at the levels lattice chose;
#   * the marks, against the exported SVG. Every selector must name exactly
#     one element, and that element must sit where its value says. lattice
#     draws a panel in a viewport whose native scales are the panel's
#     limits, and fills the viewport with the panel border, so a native
#     coordinate lands in the SVG linearly across the border rectangle. The
#     scales are read from the drawn chart's own viewport tree, and the
#     exporter rounds coordinates to 0.01, hence the 0.02 tolerance.
#
# What the frontend then does with the layout decides the orientation
# checks: a horizontal box layer is turned round on the way in
# (src/model/box.ts), and a heat layer's `y` and `points` are too, while its
# selector grid is read bottom row first (src/model/heatmap.ts).

skip_if_no_lattice()
skip_slow_file_on_cran()

# ---------------------------------------------------------------------------
# Reading the drawn chart back
# ---------------------------------------------------------------------------

#' The viewport lattice drew a panel in, from the chart's viewport tree
bh_viewport <- function(tree, name) {
  if (inherits(tree, "vpTree")) {
    found <- bh_viewport(tree$parent, name)
    return(if (is.null(found)) bh_viewport(tree$children, name) else found)
  }
  if (inherits(tree, c("vpList", "vpStack"))) {
    for (child in tree) {
      found <- bh_viewport(child, name)
      if (!is.null(found)) {
        return(found)
      }
    }
    return(NULL)
  }
  if (inherits(tree, "viewport") && identical(tree$name, name)) tree else NULL
}

#' Where a panel's native coordinates land in the exported SVG
bh_frame <- function(rendered, column = 1L, row = 1L) {
  vp <- bh_viewport(
    rendered$orchestrator$get_gtable()$childrenvp,
    sprintf("maidr.panel.%d.%d.vp", column, row)
  )
  testthat::expect_false(is.null(vp))
  border <- lattice_selector_nodes(
    rendered$doc,
    sprintf("g#maidr\\.border\\.panel\\.%d\\.%d\\.1 > rect", column, row)
  )
  testthat::expect_length(border, 1L)
  edge <- function(name) as.numeric(xml2::xml_attr(border[[1]], name))
  list(
    x = function(v) edge("x") + (v - vp$xscale[1]) / diff(vp$xscale) * edge("width"),
    y = function(v) edge("y") + (v - vp$yscale[1]) / diff(vp$yscale) * edge("height")
  )
}

#' The one element a selector names; the test fails if it names more or none
bh_element <- function(doc, selector) {
  nodes <- lattice_selector_nodes(doc, selector)
  testthat::expect_length(nodes, 1L)
  nodes[[1]]
}

#' The vertices of an exported polygon or polyline, one row each
bh_vertices <- function(node) {
  points <- strsplit(trimws(xml2::xml_attr(node, "points")), "\\s+")[[1]]
  vertices <- matrix(
    as.numeric(unlist(strsplit(points, ",", fixed = TRUE))),
    ncol = 2L,
    byrow = TRUE
  )
  colnames(vertices) <- c("x", "y")
  vertices
}

#' The centre of an exported point symbol or rectangle
bh_centre <- function(node) {
  at <- function(name) as.numeric(xml2::xml_attr(node, name))
  if (xml2::xml_name(node) == "rect") {
    c(x = at("x") + at("width") / 2, y = at("y") + at("height") / 2)
  } else {
    c(x = at("x"), y = at("y"))
  }
}

#' Coordinates agree up to the exporter's rounding
bh_expect_at <- function(actual, expected, tolerance = 0.02) {
  testthat::expect_equal(length(actual), length(expected))
  testthat::expect_lt(max(abs(unname(actual) - unname(expected))), tolerance)
}

#' The numbers of a JSON array, a null read as NA
bh_numbers <- function(values) {
  vapply(values, function(v) if (is.null(v)) NA_real_ else as.numeric(v), numeric(1))
}

#' The layers a rendering holds, checking it was read rather than drawn as
#' an image
bh_layers <- function(rendered) {
  testthat::expect_false(rendered$fallback)
  lattice_rendered_layers(rendered)
}

#' Why a chart fell back to an image, failing if it did not
bh_fallback_reasons <- function(rendered) {
  testthat::expect_true(rendered$fallback)
  rendered$orchestrator$unsupported_reasons()
}

# ---------------------------------------------------------------------------
# Box plots: bwplot
# ---------------------------------------------------------------------------

# Three levels of twelve. `low` has an outlier on each side, drawn upper,
# lower, upper in the data (30, -5, 28), so its outliers are not in sorted
# order and not all on one side; `mid` has none at the default `coef` and
# two at `coef = 0.5`; `high` has one below. The outliers are drawn box by
# box in one grob, so `high`'s is numbered after all of `low`'s.
bh_scores <- function() {
  data.frame(
    group = factor(rep(c("low", "mid", "high"), each = 12L), levels = c("low", "mid", "high")),
    score = c(
      12, 30, 11, 10, -5, 13, 9, 11, 28, 12, 10, 11,
      20, 22, 19, 21, 23, 18, 20, 22, 21, 19, 24, 20,
      31, 33, 30, 34, 32, 12, 35, 31, 33, 32, 34, 30
    )
  )
}

#' The five numbers and outliers of each emitted box, as boxplot.stats()
#' gives them for that box's rows
bh_expect_box_stats <- function(layer, scores, coef = 1.5, outliers = TRUE) {
  for (box in layer$data) {
    values <- scores$score[scores$group == box$z & !is.na(scores$score)]
    expected <- grDevices::boxplot.stats(values, coef = coef, do.out = outliers)
    testthat::expect_equal(
      unlist(box[c("min", "q1", "q2", "q3", "max")], use.names = FALSE),
      expected$stats
    )
    out <- expected$out
    testthat::expect_equal(bh_numbers(box$lowerOutliers), out[out < expected$stats[1]])
    testthat::expect_equal(bh_numbers(box$upperOutliers), out[out > expected$stats[5]])
  }
}

#' Check that every part of each emitted box is drawn where its value says
#'
#' The caps must sit at `min` and `max`, the body span `q1` to `q3` -- or the
#' notch, which can reach past the hinges -- the median sit at `q2`, and each
#' outlier at its value, all across the position of the box's own level.
#' A selector pointing at another box, or at another part, lands elsewhere.
bh_expect_boxes_drawn <- function(rendered, layer, levels, frame = bh_frame(rendered),
                                  body = function(box) c(box$q1, box$q3)) {
  horizontal <- identical(layer$orientation, "horz")
  value_at <- if (horizontal) frame$x else frame$y
  level_at <- if (horizontal) frame$y else frame$x
  along <- if (horizontal) "x" else "y"
  across <- if (horizontal) "y" else "x"
  testthat::expect_length(layer$selectors, length(layer$data))

  for (k in seq_along(layer$data)) {
    box <- layer$data[[k]]
    selector <- layer$selectors[[k]]
    position <- level_at(match(box$z, levels))

    for (end in c("min", "max")) {
      cap <- bh_vertices(bh_element(rendered$doc, selector[[end]]))
      bh_expect_at(cap[, along], rep(value_at(box[[end]]), nrow(cap)))
      bh_expect_at(mean(range(cap[, across])), position)
    }

    shape <- bh_vertices(bh_element(rendered$doc, selector$iq))
    bh_expect_at(range(shape[, along]), value_at(range(body(box))))
    bh_expect_at(mean(range(shape[, across])), position)

    median <- bh_element(rendered$doc, selector$q2)
    if (xml2::xml_name(median) == "use") {
      bh_expect_at(bh_centre(median)[[along]], value_at(box$q2))
      bh_expect_at(bh_centre(median)[[across]], position)
    } else {
      stroke <- bh_vertices(median)
      bh_expect_at(stroke[, along], rep(value_at(box$q2), nrow(stroke)))
      bh_expect_at(mean(range(stroke[, across])), position)
    }

    for (side in c("lowerOutliers", "upperOutliers")) {
      testthat::expect_length(selector[[side]], length(box[[side]]))
      for (j in seq_along(box[[side]])) {
        symbol <- bh_element(rendered$doc, selector[[side]][[j]])
        testthat::expect_equal(xml2::xml_name(symbol), "use")
        bh_expect_at(bh_centre(symbol)[[along]], value_at(box[[side]][[j]]))
        bh_expect_at(bh_centre(symbol)[[across]], position)
      }
    }
  }
}

#' Every selector string of a layer names exactly one element
bh_expect_one_each <- function(rendered, layer) {
  counts <- lattice_selector_counts(rendered$doc, layer$selectors)
  testthat::expect_gt(length(counts), 0L)
  testthat::expect_true(all(counts == 1L))
}

#' The z names of a box layer, in the order it emits them
bh_box_names <- function(layer) {
  vapply(layer$data, function(box) box$z, character(1))
}

test_that("a horizontal bwplot is emitted top first, its selectors turned with it", {
  scores <- bh_scores()
  rendered <- render_lattice(lattice::bwplot(group ~ score, data = scores))
  layers <- bh_layers(rendered)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_equal(layer$type, "box")
  testthat::expect_equal(layer$orientation, "horz")
  # Q1 is the left edge of a horizontal box, which is what "forward" says.
  testthat::expect_equal(layer$domMapping$iqrDirection, "forward")
  testthat::expect_equal(layer$axes$x$label, "score")
  testthat::expect_equal(layer$axes$y$label, "group")

  # `low` is the bottom box. The frontend reverses a horizontal layer, so it
  # is emitted last for a reader to start at it.
  testthat::expect_equal(bh_box_names(layer), c("high", "mid", "low"))
  bh_expect_box_stats(layer, scores)
  bh_expect_one_each(rendered, layer)
  # Each box's parts are drawn at its own level, so the selectors were
  # reversed along with the data rather than left in drawing order.
  bh_expect_boxes_drawn(rendered, layer, levels(scores$group))
})

test_that("a vertical bwplot is emitted left to right with its Q1 edge reversed", {
  scores <- bh_scores()
  rendered <- render_lattice(lattice::bwplot(score ~ group, data = scores))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_equal(layer$orientation, "vert")
  testthat::expect_equal(layer$domMapping$iqrDirection, "reverse")
  testthat::expect_equal(bh_box_names(layer), c("low", "mid", "high"))
  bh_expect_box_stats(layer, scores)
  bh_expect_one_each(rendered, layer)
  bh_expect_boxes_drawn(rendered, layer, levels(scores$group))

  # The export turns the page so y runs upwards, so the edge of a box's
  # bounding box the frontend calls its top -- the smallest y -- is the
  # lower hinge. That is what "reverse" tells it.
  frame <- bh_frame(rendered)
  for (k in seq_along(layer$data)) {
    shape <- bh_vertices(bh_element(rendered$doc, layer$selectors[[k]]$iq))
    bh_expect_at(min(shape[, "y"]), frame$y(layer$data[[k]]$q1))
  }
})

test_that("outliers are split by side in the order they were drawn", {
  scores <- bh_scores()
  rendered <- render_lattice(lattice::bwplot(score ~ group, data = scores))
  layer <- bh_layers(rendered)[[1]]
  boxes <- stats::setNames(layer$data, bh_box_names(layer))
  selectors <- stats::setNames(layer$selectors, bh_box_names(layer))

  testthat::expect_equal(bh_numbers(boxes$low$lowerOutliers), -5)
  testthat::expect_equal(bh_numbers(boxes$low$upperOutliers), c(30, 28))
  testthat::expect_length(boxes$mid$lowerOutliers, 0L)
  testthat::expect_length(boxes$mid$upperOutliers, 0L)
  testthat::expect_equal(bh_numbers(boxes$high$lowerOutliers), 12)

  # One grob holds every outlier, box by box, each box's in data order: 30,
  # -5, 28, then 12. Each selector names exactly its own symbol.
  drawn <- xml2::xml_find_all(
    rendered$doc,
    "//*[@id='maidr.bwplot.outlier.points.panel.1.1.1']/*"
  )
  testthat::expect_length(drawn, 4L)
  own <- function(selector) xml2::xml_attr(bh_element(rendered$doc, selector), "id")
  ids <- xml2::xml_attr(drawn, "id")
  testthat::expect_equal(own(selectors$low$upperOutliers[[1]]), ids[1])
  testthat::expect_equal(own(selectors$low$lowerOutliers[[1]]), ids[2])
  testthat::expect_equal(own(selectors$low$upperOutliers[[2]]), ids[3])
  testthat::expect_equal(own(selectors$high$lowerOutliers[[1]]), ids[4])
  bh_expect_one_each(rendered, layer)
})

test_that("coef moves the whiskers and the outliers with them", {
  scores <- bh_scores()
  rendered <- render_lattice(lattice::bwplot(score ~ group, data = scores, coef = 0.5))
  layer <- bh_layers(rendered)[[1]]

  bh_expect_box_stats(layer, scores, coef = 0.5)
  mid <- layer$data[[match("mid", bh_box_names(layer))]]
  testthat::expect_equal(bh_numbers(mid$lowerOutliers), 18)
  testthat::expect_equal(bh_numbers(mid$upperOutliers), 24)
  bh_expect_one_each(rendered, layer)
  bh_expect_boxes_drawn(rendered, layer, levels(scores$group))
})

test_that("do.out = FALSE reads no outliers where none are drawn", {
  scores <- bh_scores()
  rendered <- render_lattice(lattice::bwplot(group ~ score, data = scores, do.out = FALSE))
  layer <- bh_layers(rendered)[[1]]

  bh_expect_box_stats(layer, scores, outliers = FALSE)
  for (k in seq_along(layer$data)) {
    testthat::expect_length(layer$data[[k]]$lowerOutliers, 0L)
    testthat::expect_length(layer$data[[k]]$upperOutliers, 0L)
    testthat::expect_length(layer$selectors[[k]]$lowerOutliers, 0L)
    testthat::expect_length(layer$selectors[[k]]$upperOutliers, 0L)
  }
  # Nothing is drawn for them, so no selector can name a symbol that is not
  # there.
  testthat::expect_length(
    xml2::xml_find_all(rendered$doc, "//*[starts-with(@id, 'maidr.bwplot.outlier.points')]"),
    0L
  )
  bh_expect_one_each(rendered, layer)
  bh_expect_boxes_drawn(rendered, layer, levels(scores$group))
})

test_that("pch = '|' draws the median as a segment, and q2 names it", {
  scores <- bh_scores()
  rendered <- render_lattice(lattice::bwplot(group ~ score, data = scores, pch = "|"))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_length(
    xml2::xml_find_all(rendered$doc, "//*[starts-with(@id, 'maidr.bwplot.dot.points')]"),
    0L
  )
  for (selector in layer$selectors) {
    testthat::expect_equal(xml2::xml_name(bh_element(rendered$doc, selector$q2)), "polyline")
  }
  bh_expect_box_stats(layer, scores)
  bh_expect_boxes_drawn(rendered, layer, levels(scores$group))
})

test_that("notch and varwidth change the shapes, not what is read or named", {
  scores <- bh_scores()
  plain <- bh_layers(render_lattice(lattice::bwplot(group ~ score, data = scores)))[[1]]

  notched <- render_lattice(lattice::bwplot(group ~ score, data = scores, notch = TRUE))
  layer <- bh_layers(notched)[[1]]
  bh_expect_box_stats(layer, scores)
  testthat::expect_equal(layer$data, plain$data)
  testthat::expect_equal(layer$selectors, plain$selectors)
  # The notch reaches to the median's confidence interval, which for `low`
  # runs below the lower hinge; the body is drawn over both.
  confidence <- lapply(split(scores$score, scores$group), function(values) {
    grDevices::boxplot.stats(values)$conf
  })
  bh_expect_boxes_drawn(notched, layer, levels(scores$group), body = function(box) {
    c(box$q1, box$q3, confidence[[box$z]])
  })

  wide <- render_lattice(lattice::bwplot(group ~ score, data = scores, varwidth = TRUE))
  layer <- bh_layers(wide)[[1]]
  bh_expect_box_stats(layer, scores)
  testthat::expect_equal(layer$data, plain$data)
  testthat::expect_equal(layer$selectors, plain$selectors)
  bh_expect_boxes_drawn(wide, layer, levels(scores$group))
})

test_that("a level whose values are all missing leaves the other boxes named right", {
  # lattice gives such a level a box of missing statistics, which is drawn
  # as no polygon and would shift every later polygon's number; the level
  # is left out of the ones the panel draws, so the boxes drawn are the
  # boxes counted.
  scores <- bh_scores()
  scores$score[scores$group == "mid"] <- NA
  rendered <- render_lattice(lattice::bwplot(group ~ score, data = scores))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_equal(bh_box_names(layer), c("high", "low"))
  bh_expect_box_stats(layer, scores)
  bh_expect_one_each(rendered, layer)
  # `high` keeps its place on the axis, the third level, with the gap where
  # `mid` would be.
  bh_expect_boxes_drawn(rendered, layer, levels(scores$group))
})

test_that("a level absent from a packet has no box in that panel", {
  scores <- bh_scores()
  first <- scores
  first$batch <- "first"
  second <- scores[scores$group != "mid", ]
  second$score <- second$score + 2
  second$batch <- "second"
  both <- rbind(first, second)
  rendered <- render_lattice(
    lattice::bwplot(score ~ group | batch, data = both, layout = c(2, 1))
  )
  layers <- bh_layers(rendered)

  testthat::expect_length(layers, 2L)
  titles <- vapply(layers, function(layer) layer$title, character(1))
  testthat::expect_setequal(titles, c("first", "second"))
  for (layer in layers) {
    batch <- both[both$batch == layer$title, ]
    testthat::expect_equal(
      bh_box_names(layer),
      intersect(levels(scores$group), unique(as.character(batch$group)))
    )
    bh_expect_box_stats(layer, batch)
    bh_expect_one_each(rendered, layer)
    # Every part is named in the panel the packet was drawn in.
    column <- layer$cell[2]
    testthat::expect_true(all(grepl(
      sprintf("panel\\.%d\\.1\\.1", column),
      unlist(layer$selectors),
      fixed = TRUE
    )))
    bh_expect_boxes_drawn(
      rendered, layer, levels(scores$group),
      frame = bh_frame(rendered, column = column)
    )
  }
})

test_that("a log scale is read back on the data's own scale", {
  scores <- bh_scores()
  scores <- scores[scores$score > 0, ]
  rendered <- render_lattice(
    lattice::bwplot(group ~ score, data = scores, scales = list(x = list(log = 10)))
  )
  layer <- bh_layers(rendered)[[1]]

  # lattice computes the statistics over the logarithms and draws them
  # there; each is announced at the value the axis labels that position.
  for (box in layer$data) {
    logged <- grDevices::boxplot.stats(log10(scores$score[scores$group == box$z]))
    testthat::expect_equal(
      unlist(box[c("min", "q1", "q2", "q3", "max")], use.names = FALSE),
      10^logged$stats
    )
    out <- logged$out
    testthat::expect_equal(bh_numbers(box$upperOutliers), 10^out[out > logged$stats[5]])
    testthat::expect_equal(bh_numbers(box$lowerOutliers), 10^out[out < logged$stats[1]])
  }
  bh_expect_one_each(rendered, layer)
  frame <- bh_frame(rendered)
  bh_expect_boxes_drawn(rendered, layer, levels(scores$group), frame = list(
    x = function(v) frame$x(log10(v)),
    y = frame$y
  ))
})

test_that("an outlier a log scale cannot place is neither drawn nor read", {
  # A zero is drawn at log10(0) = -Inf, which is no position: lattice draws
  # no outlier there, and the exporter skips its mark without renumbering
  # the outliers after it.
  d <- data.frame(
    v = c(0, 1, 2, 5, 10, 20, 50, 100, 3, 4, 6, 8, 0.001, 900),
    g = factor(c(rep("A", 6), rep("B", 8)))
  )
  rendered <- render_lattice(lattice::bwplot(g ~ v, d, scales = list(x = list(log = 10))))
  layer <- bh_layers(rendered)[[1]]
  boxes <- stats::setNames(layer$data, bh_box_names(layer))

  testthat::expect_length(boxes$A$lowerOutliers, 0L)
  logged <- grDevices::boxplot.stats(log10(d$v[d$g == "B"]))
  out <- logged$out
  testthat::expect_equal(bh_numbers(boxes$B$lowerOutliers), 10^out[out < logged$stats[1]])
  testthat::expect_equal(bh_numbers(boxes$B$upperOutliers), 10^out[out > logged$stats[5]])
  bh_expect_one_each(rendered, layer)
})

test_that("a date axis is read as the dates it stands for", {
  # lattice draws a date axis in days since 1970 and labels it with dates;
  # the frontend reads a time as milliseconds since 1970, announced through
  # the axis' date format.
  visits <- data.frame(
    clinic = factor(rep(c("north", "south"), each = 5L)),
    seen = as.Date("2024-01-01") + c(0, 10, 20, 30, 40, 5, 15, 25, 35, 45)
  )
  rendered <- render_lattice(lattice::bwplot(clinic ~ seen, data = visits))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_equal(layer$axes$x$format$type, "date")
  day <- 86400000
  for (box in layer$data) {
    days <- as.numeric(visits$seen[visits$clinic == box$z])
    testthat::expect_equal(
      unlist(box[c("min", "q1", "q2", "q3", "max")], use.names = FALSE),
      grDevices::boxplot.stats(days)$stats * day
    )
  }
  bh_expect_one_each(rendered, layer)
  frame <- bh_frame(rendered)
  bh_expect_boxes_drawn(rendered, layer, levels(visits$clinic), frame = list(
    x = function(v) frame$x(v / day),
    y = frame$y
  ))
})

test_that("a single box, drawn on no level, is named by what it summarises", {
  # `bwplot(~x)` draws its one box on a level named "", and the frontend
  # names a box "<axis> is <name>".
  scores <- bh_scores()
  rendered <- render_lattice(lattice::bwplot(~score, data = scores))
  layer <- bh_layers(rendered)[[1]]
  testthat::expect_equal(bh_box_names(layer), "score")
  expected <- grDevices::boxplot.stats(scores$score)$stats
  box <- layer$data[[1]]
  testthat::expect_equal(c(box$min, box$q1, box$q2, box$q3, box$max), expected)
  bh_expect_one_each(rendered, layer)

  # Named as the axis is: by the title the chart gives it.
  rendered <- render_lattice(lattice::bwplot(~score, data = scores, xlab = "Test score"))
  testthat::expect_equal(bh_box_names(bh_layers(rendered)[[1]]), "Test score")
})

test_that("a blank level of the chart's own factor keeps its name", {
  # lattice draws a "" level's tick blank; the box over it is one category
  # among the others, not a summary of the whole measure.
  scores <- bh_scores()
  scores$group <- factor(
    rep(c("", "mid", "high"), each = 12L),
    levels = c("", "mid", "high")
  )
  vertical <- render_lattice(lattice::bwplot(score ~ group, data = scores))
  testthat::expect_equal(bh_box_names(bh_layers(vertical)[[1]]), c("", "mid", "high"))
  horizontal <- render_lattice(lattice::bwplot(group ~ score, data = scores))
  testthat::expect_equal(bh_box_names(bh_layers(horizontal)[[1]]), c("high", "mid", ""))

  # A factor whose only level is blank is still the chart's own factor.
  scores$group <- factor(rep("", nrow(scores)))
  rendered <- render_lattice(lattice::bwplot(score ~ group, data = scores))
  testthat::expect_equal(bh_box_names(bh_layers(rendered)[[1]]), "")
})

test_that("a violin panel falls back to an image", {
  rendered <- render_lattice(
    lattice::bwplot(group ~ score, data = bh_scores(), panel = lattice::panel.violin)
  )
  testthat::expect_true(length(bh_fallback_reasons(rendered)) > 0L)
})

# ---------------------------------------------------------------------------
# Heat maps: levelplot
# ---------------------------------------------------------------------------

# Four columns by three rows of distinct values, so a grid read transposed
# or upside down cannot come out right.
bh_field <- function() {
  field <- expand.grid(
    x = factor(c("west", "inland", "coast", "east"), levels = c("west", "inland", "coast", "east")),
    y = factor(c("south", "middle", "north"), levels = c("south", "middle", "north"))
  )
  field$z <- c(3, 8, 1, 6, 2, 9, 12, 4, 7, 5, 11, 10)
  field
}

#' The value each cell holds, rows running up y, as a plain matrix
bh_cells <- function(x, y, z) {
  unname(tapply(z, list(factor(y), factor(x)), function(value) value))
}

#' The value grid a heat layer carries, top row first as it is emitted
bh_heat_grid <- function(layer) {
  do.call(rbind, lapply(layer$data$points, bh_numbers))
}

#' Check that each cell's selector names the rectangle drawn at that cell
#'
#' The grid runs bottom row first, so row `r` is the `r`-th position up y.
#' A null selector is a cell with nothing drawn.
bh_expect_cells_drawn <- function(rendered, layer, x_at, y_at, frame = bh_frame(rendered)) {
  grid <- layer$selectors
  testthat::expect_length(grid, length(y_at))
  centre_x <- matrix(NA_real_, length(y_at), length(x_at))
  centre_y <- centre_x
  for (r in seq_along(grid)) {
    testthat::expect_length(grid[[r]], length(x_at))
    for (column in seq_along(grid[[r]])) {
      selector <- grid[[r]][[column]]
      if (is.null(selector)) {
        next
      }
      rect <- bh_element(rendered$doc, selector)
      testthat::expect_equal(xml2::xml_name(rect), "rect")
      centre_x[r, column] <- bh_centre(rect)[["x"]]
      centre_y[r, column] <- bh_centre(rect)[["y"]]
    }
  }
  drawn <- !is.na(centre_x)
  bh_expect_at(centre_x[drawn], frame$x(x_at)[col(drawn)][drawn])
  bh_expect_at(centre_y[drawn], frame$y(y_at)[row(drawn)][drawn])
  invisible(drawn)
}

test_that("a matrix is read with its rows along x and its columns up y", {
  values <- matrix(c(3, 8, 1, 6, 2, 9, 12, 4, 7, 5, 11, 10), nrow = 4L)
  rendered <- render_lattice(lattice::levelplot(values))
  layers <- bh_layers(rendered)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_equal(layer$type, "heat")
  # A matrix has no names here, so its cells are named by position.
  testthat::expect_equal(unlist(layer$data$x), c("1", "2", "3", "4"))
  testthat::expect_equal(unlist(layer$data$y), c("3", "2", "1"))
  # Column j of the matrix is row j up the chart, emitted top first.
  testthat::expect_equal(bh_heat_grid(layer), t(values)[3:1, ])
  # The axis titles lattice draws for a matrix, and the formula it reads it
  # through, `z ~ row * column`.
  drawn_title <- function(id) {
    xml2::xml_text(xml2::xml_find_first(
      rendered$doc,
      sprintf("//*[@id='%s']//*[local-name()='text']", id)
    ))
  }
  testthat::expect_equal(layer$axes$x$label, drawn_title("maidr.xlab.1"))
  testthat::expect_equal(layer$axes$y$label, drawn_title("maidr.ylab.1"))
  testthat::expect_equal(layer$axes$z$label, "z")

  bh_expect_one_each(rendered, layer)
  bh_expect_cells_drawn(rendered, layer, x_at = 1:4, y_at = 1:3)
})

test_that("a matrix with dimnames is read with them", {
  values <- matrix(
    c(3, 8, 1, 6, 2, 9, 12, 4, 7, 5, 11, 10),
    nrow = 4L,
    dimnames = list(c("a", "b", "c", "d"), c("p", "q", "r"))
  )
  rendered <- render_lattice(lattice::levelplot(values))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_equal(unlist(layer$data$x), c("a", "b", "c", "d"))
  testthat::expect_equal(unlist(layer$data$y), c("r", "q", "p"))
  testthat::expect_equal(bh_heat_grid(layer), unname(t(values)[3:1, ]))
  bh_expect_cells_drawn(rendered, layer, x_at = 1:4, y_at = 1:3)
})

test_that("a one-row matrix keeps its grid shape in the payload", {
  # A list of one is not unboxed, so the frontend still gets a grid.
  rendered <- render_lattice(lattice::levelplot(matrix(c(3, 1, 2), nrow = 3L)))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_equal(unlist(layer$data$y), "1")
  testthat::expect_equal(bh_heat_grid(layer), matrix(c(3, 1, 2), nrow = 1L))
  testthat::expect_length(layer$selectors, 1L)
  bh_expect_cells_drawn(rendered, layer, x_at = 1:3, y_at = 1)
})

test_that("z ~ x * y with factor axes reads the levels, top row first", {
  field <- bh_field()
  rendered <- render_lattice(lattice::levelplot(z ~ x * y, data = field))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_equal(unlist(layer$data$x), levels(field$x))
  # `y` and `points` run top first -- the frontend turns both round so its
  # row 0 is the bottom one -- while the selector grid runs bottom first.
  testthat::expect_equal(unlist(layer$data$y), rev(levels(field$y)))
  expected <- bh_cells(field$x, field$y, field$z)
  testthat::expect_equal(bh_heat_grid(layer), expected[3:1, ])
  testthat::expect_equal(layer$axes$x$label, "x")
  testthat::expect_equal(layer$axes$y$label, "y")
  testthat::expect_equal(layer$axes$z$label, "z")

  bh_expect_one_each(rendered, layer)
  bh_expect_cells_drawn(rendered, layer, x_at = 1:4, y_at = 1:3)
  # Read the way the frontend reads it: selector row r, bottom first, holds
  # the cells of `points` row (3 - r + 1), which sit at y level r.
  frame <- bh_frame(rendered)
  for (r in 1:3) {
    for (column in 1:4) {
      centre <- bh_centre(bh_element(rendered$doc, layer$selectors[[r]][[column]]))
      bh_expect_at(centre[["y"]], frame$y(match(rev(unlist(layer$data$y))[r], levels(field$y))))
      testthat::expect_equal(
        bh_numbers(layer$data$points[[3 - r + 1]])[column],
        field$z[field$x == levels(field$x)[column] & field$y == levels(field$y)[r]]
      )
    }
  }
})

test_that("shuffled rows are read into the same grid, each cell naming its own rect", {
  field <- bh_field()
  shuffled <- field[c(7, 2, 11, 4, 12, 1, 9, 5, 3, 10, 8, 6), ]
  plain <- bh_layers(render_lattice(lattice::levelplot(z ~ x * y, data = field)))[[1]]
  rendered <- render_lattice(lattice::levelplot(z ~ x * y, data = shuffled))
  layer <- bh_layers(rendered)[[1]]

  testthat::expect_equal(bh_heat_grid(layer), bh_cells(field$x, field$y, field$z)[3:1, ])
  testthat::expect_equal(layer$data, plain$data)
  # The rects are drawn in the order of the rows, so the ids differ...
  testthat::expect_false(identical(layer$selectors, plain$selectors))
  # ...and each still names the rect drawn at its cell.
  bh_expect_one_each(rendered, layer)
  bh_expect_cells_drawn(rendered, layer, x_at = 1:4, y_at = 1:3)
})

test_that("a missing value is a hole with no selector, where nothing is drawn", {
  field <- bh_field()
  # The sixth row: `inland`, `middle`.
  field$z[6] <- NA
  rendered <- render_lattice(lattice::levelplot(z ~ x * y, data = field))
  layer <- bh_layers(rendered)[[1]]

  grid <- bh_heat_grid(layer)
  testthat::expect_equal(grid, bh_cells(field$x, field$y, field$z)[3:1, ])
  testthat::expect_true(is.na(grid[2, 2]))
  testthat::expect_null(layer$selectors[[2]][[2]])
  counts <- lattice_selector_counts(rendered$doc, layer$selectors)
  testthat::expect_equal(sum(is.na(counts)), 1L)
  testthat::expect_true(all(counts[!is.na(counts)] == 1L))
  # lattice draws no rect for it, and the others keep their numbers.
  testthat::expect_length(
    xml2::xml_find_all(rendered$doc, "//*[@id='maidr.levelplot.rect.panel.1.1.1.6']"),
    0L
  )
  testthat::expect_length(
    xml2::xml_find_all(rendered$doc, "//*[@id='maidr.levelplot.rect.panel.1.1.1']/*"),
    11L
  )
  bh_expect_cells_drawn(rendered, layer, x_at = 1:4, y_at = 1:3)
})

test_that("a value outside `at`, which lattice leaves unfilled, is a hole with no selector", {
  cells <- expand.grid(x = 1:3, y = 1:2)
  # Below, on and above the ends of `at`: lattice colours a value on either
  # end (level.colors() cuts with include.lowest) and none beyond them.
  cells$z <- c(-1, 0, 3, 6, 5, 9)
  rendered <- render_lattice(lattice::levelplot(z ~ x * y, data = cells, at = 0:6))
  testthat::expect_false(rendered$fallback)
  layer <- lattice_rendered_layers(rendered)[[1]]
  testthat::expect_equal(layer$type, "heat")

  value <- function(cell) if (is.null(cell)) NA_real_ else as.numeric(cell)
  grid <- do.call(rbind, lapply(layer$data$points, function(row) vapply(row, value, 0)))
  # Top row first: y = 2 holds 6, 5, 9 and y = 1 holds -1, 0, 3.
  testthat::expect_equal(grid, rbind(c(6, 5, NA), c(NA, 0, 3)))
  # The selector grid runs bottom first; the unfilled cells name nothing.
  testthat::expect_null(layer$selectors[[1]][[1]])
  testthat::expect_null(layer$selectors[[2]][[3]])
  counts <- lattice_selector_counts(rendered$doc, layer$selectors)
  testthat::expect_equal(sum(is.na(counts)), 2L)
  testthat::expect_true(all(counts[!is.na(counts)] == 1L))
  # Every cell still named is one lattice filled.
  fills <- vapply(
    unlist(layer$selectors),
    function(selector) {
      xml2::xml_attr(lattice_selector_nodes(rendered$doc, selector)[[1]], "fill")
    },
    character(1)
  )
  testthat::expect_false(any(fills == "none"))
})

test_that("a cell with no row is a hole", {
  field <- bh_field()[-10, ]
  rendered <- render_lattice(lattice::levelplot(z ~ x * y, data = field))
  layer <- bh_layers(rendered)[[1]]

  grid <- bh_heat_grid(layer)
  testthat::expect_equal(grid, bh_cells(field$x, field$y, field$z)[3:1, ])
  # The tenth row was `inland`, `north`: the top row, second column.
  testthat::expect_true(is.na(grid[1, 2]))
  testthat::expect_null(layer$selectors[[3]][[2]])
  bh_expect_cells_drawn(rendered, layer, x_at = 1:4, y_at = 1:3)
})

test_that("two rows for one cell fall back to an image", {
  field <- bh_field()
  rendered <- render_lattice(lattice::levelplot(z ~ x * y, data = rbind(field, field[5, ])))
  testthat::expect_true(length(bh_fallback_reasons(rendered)) > 0L)
  # It is the cells that cannot be read: two rects drawn over one another,
  # of which a grid cell could name only one.
  heat <- Filter(
    function(processor) inherits(processor, "LatticeHeatmapLayerProcessor"),
    rendered$orchestrator$get_layer_processors()
  )
  testthat::expect_length(heat, 1L)
  testthat::expect_null(heat[[1]]$get_last_result())
})

test_that("each packet of a conditioned levelplot is read from its own panel", {
  field <- bh_field()
  wet <- field
  wet$z <- wet$z * 10
  both <- rbind(transform(field, season = "dry"), transform(wet, season = "wet"))
  rendered <- render_lattice(
    lattice::levelplot(z ~ x * y | season, data = both, layout = c(2, 1))
  )
  layers <- bh_layers(rendered)

  testthat::expect_length(layers, 2L)
  for (layer in layers) {
    season <- both[both$season == layer$title, ]
    testthat::expect_equal(bh_heat_grid(layer), bh_cells(season$x, season$y, season$z)[3:1, ])
    bh_expect_one_each(rendered, layer)
    bh_expect_cells_drawn(
      rendered, layer, x_at = 1:4, y_at = 1:3,
      frame = bh_frame(rendered, column = layer$cell[2])
    )
  }
  testthat::expect_setequal(
    vapply(layers, function(layer) layer$title, character(1)),
    c("dry", "wet")
  )
})

test_that("a packet whose values are all missing has no cells to read", {
  field <- bh_field()
  empty <- transform(field, z = NA_real_)
  both <- rbind(transform(field, season = "dry"), transform(empty, season = "wet"))
  rendered <- render_lattice(
    lattice::levelplot(z ~ x * y | season, data = both, layout = c(2, 1))
  )
  layers <- bh_layers(rendered)

  # lattice draws no rect in the second panel, and a grid of nothing but
  # holes would be a layer that announces nothing.
  testthat::expect_length(
    xml2::xml_find_all(rendered$doc, "//*[@id='maidr.levelplot.rect.panel.2.1.1']/*"),
    0L
  )
  testthat::expect_length(layers, 1L)
  testthat::expect_equal(layers[[1]]$title, "dry")
  testthat::expect_length(rendered$schema$subplots[[1]][[2]]$layers, 0L)
  bh_expect_cells_drawn(rendered, layers[[1]], x_at = 1:4, y_at = 1:3)
})

test_that("the colour key's title names the values, wherever the key is", {
  field <- bh_field()
  for (space in c("right", "left", "bottom")) {
    rendered <- render_lattice(lattice::levelplot(
      z ~ x * y,
      data = field,
      colorkey = list(space = space, title = "Rainfall (mm)")
    ))
    layer <- bh_layers(rendered)[[1]]
    testthat::expect_equal(layer$axes$z$label, "Rainfall (mm)")
    bh_expect_cells_drawn(rendered, layer, x_at = 1:4, y_at = 1:3)
  }
})

test_that("numeric positions are read on the data's scale, each on its own", {
  field <- expand.grid(x = c(1, 10, 100), y = c(-1, -0.5, 0, 0.5, 1))
  field$z <- seq_len(nrow(field))
  rendered <- render_lattice(
    lattice::levelplot(z ~ x * y, data = field, scales = list(x = list(log = 10)))
  )
  layer <- bh_layers(rendered)[[1]]

  # lattice hands the panel log10(x); the columns are named by x itself.
  testthat::expect_equal(unlist(layer$data$x), c("1", "10", "100"))
  # And -1 among halves reads "-1", not "-1.0".
  testthat::expect_equal(unlist(layer$data$y), c("1", "0.5", "0", "-0.5", "-1"))
  testthat::expect_equal(bh_heat_grid(layer), bh_cells(field$x, field$y, field$z)[5:1, ])
  bh_expect_cells_drawn(rendered, layer, x_at = log10(c(1, 10, 100)), y_at = c(-1, -0.5, 0, 0.5, 1))
})

test_that("positions on a time axis are named by the instant they stand for", {
  shifts <- expand.grid(day = as.Date("2024-03-01") + 0:4, hour = c(8, 12, 16))
  shifts$load <- seq_len(nrow(shifts))
  rendered <- render_lattice(lattice::levelplot(load ~ day * hour, data = shifts))
  layer <- bh_layers(rendered)[[1]]

  # An ISO 8601 date, which the axis' date format reads out as the date.
  testthat::expect_equal(unlist(layer$data$x), format(sort(unique(shifts$day))))
  testthat::expect_equal(layer$axes$x$format$type, "date")
  testthat::expect_null(layer$axes$y$format)
  testthat::expect_equal(
    bh_heat_grid(layer),
    bh_cells(shifts$day, shifts$hour, shifts$load)[3:1, ]
  )
  bh_expect_cells_drawn(
    rendered, layer,
    x_at = as.numeric(sort(unique(shifts$day))),
    y_at = c(8, 12, 16)
  )

  readings <- expand.grid(
    at = as.POSIXct("2024-03-01 06:00:00", tz = "UTC") + 3600 * 0:3,
    probe = factor(c("a", "b"))
  )
  readings$value <- seq_len(nrow(readings))
  rendered <- render_lattice(lattice::levelplot(value ~ at * probe, data = readings))
  layer <- bh_layers(rendered)[[1]]
  testthat::expect_equal(
    unlist(layer$data$x),
    format(sort(unique(readings$at)), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  testthat::expect_equal(layer$axes$x$format$type, "date")
  bh_expect_cells_drawn(
    rendered, layer,
    x_at = as.numeric(sort(unique(readings$at))),
    y_at = 1:2
  )
})

test_that("a raster or filled-contour levelplot falls back to an image", {
  # One image, or bands of polygons, rather than a rect per cell.
  # `useRaster = TRUE` asks the current device whether it can draw a raster,
  # which opens one when none is; it is asked a null device, closed after.
  grDevices::pdf(NULL)
  raster <- tryCatch(
    lattice::levelplot(volcano, useRaster = TRUE),
    finally = grDevices::dev.off()
  )
  testthat::expect_true(length(bh_fallback_reasons(render_lattice(raster))) > 0L)
  testthat::expect_true(length(bh_fallback_reasons(
    render_lattice(lattice::levelplot(volcano, region.type = "contour"))
  )) > 0L)
})

# ---------------------------------------------------------------------------
# Contours: contourplot, and levelplot with contour = TRUE
# ---------------------------------------------------------------------------

# A bump on a grid of 21 by 16, so the grid's two sides differ, off centre,
# so a grid or a curve read upside down or mirrored differs from it.
bh_bump <- function() {
  bump <- expand.grid(x = seq(-2, 2, length.out = 21L), y = seq(-1.5, 1.5, length.out = 16L))
  bump$z <- exp(-((bump$x - 0.4)^2 + (bump$y - 0.3)^2))
  bump
}

#' The curves contourLines() draws for a data frame's grid
bh_contour_lines <- function(frame, at) {
  xs <- sort(unique(frame$x))
  ys <- sort(unique(frame$y))
  # expand.grid() runs x fastest, so the values fill a matrix by x rows.
  grDevices::contourLines(x = xs, y = ys, z = matrix(frame$z, nrow = length(xs)), levels = at)
}

#' Check a contour layer holds exactly the given curves, in their order
bh_expect_curves <- function(layer, curves) {
  testthat::expect_equal(layer$type, "contour")
  testthat::expect_length(layer$data, length(curves))
  for (k in seq_along(curves)) {
    points <- layer$data[[k]]
    testthat::expect_equal(bh_field_of(points, "x"), curves[[k]]$x)
    testthat::expect_equal(bh_field_of(points, "y"), curves[[k]]$y)
    testthat::expect_equal(unique(bh_field_of(points, "level")), curves[[k]]$level)
  }
}

#' One numeric field of every point of a curve
bh_field_of <- function(points, field) {
  vapply(points, function(point) as.numeric(point[[field]]), numeric(1))
}

#' Check each curve's selector names one polyline drawn through its vertices
bh_expect_curves_drawn <- function(rendered, layer, frame = bh_frame(rendered),
                                   native = function(v) v) {
  testthat::expect_length(layer$selectors, length(layer$data))
  for (k in seq_along(layer$data)) {
    line <- bh_element(rendered$doc, layer$selectors[[k]])
    testthat::expect_equal(xml2::xml_name(line), "polyline")
    vertices <- bh_vertices(line)
    points <- layer$data[[k]]
    testthat::expect_equal(nrow(vertices), length(points))
    bh_expect_at(vertices[, "x"], frame$x(native(bh_field_of(points, "x"))))
    bh_expect_at(vertices[, "y"], frame$y(bh_field_of(points, "y")))
  }
}

test_that("contourplot(volcano) reads the curves contourLines() draws", {
  plot <- lattice::contourplot(volcano)
  rendered <- render_lattice(plot)
  layers <- bh_layers(rendered)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  curves <- grDevices::contourLines(
    x = seq_len(nrow(volcano)),
    y = seq_len(ncol(volcano)),
    z = volcano,
    levels = plot$panel.args.common$at
  )
  bh_expect_curves(layer, curves)
  testthat::expect_equal(layer$axes$x$label, "row")
  testthat::expect_equal(layer$axes$y$label, "column")
  bh_expect_one_each(rendered, layer)
  bh_expect_curves_drawn(rendered, layer)
})

test_that("contourplot(z ~ x * y) reads the curves of the data frame's grid", {
  bump <- bh_bump()
  plot <- lattice::contourplot(z ~ x * y, data = bump)
  rendered <- render_lattice(plot)
  layer <- bh_layers(rendered)[[1]]

  curves <- bh_contour_lines(bump, plot$panel.args.common$at)
  testthat::expect_gt(length(curves), 1L)
  bh_expect_curves(layer, curves)
  testthat::expect_equal(layer$axes$z$label, "z")
  bh_expect_curves_drawn(rendered, layer)
})

test_that("a contour on a log scale is read on the data's scale", {
  bump <- bh_bump()
  bump$x <- 10^(bump$x)
  plot <- lattice::contourplot(z ~ x * y, data = bump, scales = list(x = list(log = 10)))
  rendered <- render_lattice(plot)
  layer <- bh_layers(rendered)[[1]]

  logged <- bump
  logged$x <- log10(logged$x)
  curves <- lapply(bh_contour_lines(logged, plot$panel.args.common$at), function(curve) {
    curve$x <- 10^curve$x
    curve
  })
  bh_expect_curves(layer, curves)
  bh_expect_curves_drawn(rendered, layer, native = log10)
})

test_that("a contour over dates runs through the instants they stand for", {
  bump <- bh_bump()
  # Twenty-one days, one a column.
  bump$x <- as.Date("2024-01-01") + round((bump$x + 2) * 5)
  plot <- lattice::contourplot(z ~ x * y, data = bump)
  rendered <- render_lattice(plot)
  layer <- bh_layers(rendered)[[1]]

  day <- 86400000
  in_days <- transform(bump, x = as.numeric(x))
  curves <- lapply(bh_contour_lines(in_days, plot$panel.args.common$at), function(curve) {
    curve$x <- curve$x * day
    curve
  })
  bh_expect_curves(layer, curves)
  testthat::expect_equal(layer$axes$x$format$type, "date")
  bh_expect_curves_drawn(rendered, layer, native = function(v) v / day)
})

test_that("levelplot(contour = TRUE) reads the cells, then the curves", {
  bump <- bh_bump()
  plot <- lattice::levelplot(z ~ x * y, data = bump, contour = TRUE)
  rendered <- render_lattice(plot)
  layers <- bh_layers(rendered)

  testthat::expect_equal(
    vapply(layers, function(layer) layer$type, character(1)),
    c("heat", "contour")
  )
  testthat::expect_equal(layers[[1]]$cell, layers[[2]]$cell)
  testthat::expect_equal(bh_heat_grid(layers[[1]]), bh_cells(bump$x, bump$y, bump$z)[16:1, ])
  bh_expect_one_each(rendered, layers[[1]])
  bh_expect_cells_drawn(
    rendered, layers[[1]],
    x_at = sort(unique(bump$x)),
    y_at = sort(unique(bump$y))
  )
  bh_expect_curves(layers[[2]], bh_contour_lines(bump, plot$panel.args.common$at))
  bh_expect_curves_drawn(rendered, layers[[2]])
})

test_that("a panel no level crosses has no curves to read", {
  bump <- bh_bump()
  # Between two levels everywhere, and not flat -- a flat field makes
  # contourLines() warn.
  still <- transform(bump, z = 0.25 + 0.01 * x / 2)
  both <- rbind(transform(bump, part = "bump"), transform(still, part = "still"))
  plot <- lattice::contourplot(z ~ x * y | part, data = both, layout = c(2, 1))
  testthat::expect_length(bh_contour_lines(still, plot$panel.args.common$at), 0L)
  rendered <- render_lattice(plot)
  layers <- bh_layers(rendered)

  testthat::expect_length(layers, 1L)
  testthat::expect_equal(layers[[1]]$title, "bump")
  bh_expect_curves(layers[[1]], bh_contour_lines(bump, plot$panel.args.common$at))
  bh_expect_curves_drawn(
    rendered, layers[[1]],
    frame = bh_frame(rendered, column = layers[[1]]$cell[2])
  )
  # The still panel keeps its place in the grid, with nothing in it.
  cells <- rendered$schema$subplots[[1]]
  testthat::expect_length(cells, 2L)
  testthat::expect_length(cells[[3L - layers[[1]]$cell[2]]]$layers, 0L)
})
