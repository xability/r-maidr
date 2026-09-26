# The svglite export writes the document shape every selector in the package
# is built against (R/svg_export.R): grob groups and element ids numbered as
# gridSVG numbered them, the page drawn under a Y-flip, points as `<use>`
# references, paint as presentation attributes. Each test here draws a small
# grid scene and reads that contract back.

export_scene <- function(draw, width = 3, height = 2) {
  svg_string <- maidr:::open_svg_device(width, height)
  grid::grid.newpage()
  draw()
  svg <- maidr:::export_svg_scene(svg_string, width, height)
  xml2::read_xml(paste(svg, collapse = "\n"))
}

svg_ns <- c(s = "http://www.w3.org/2000/svg")

by_id <- function(doc, id) {
  xml2::xml_find_first(doc, sprintf("//*[@id='%s']", id))
}

child_ids <- function(doc, id) {
  xml2::xml_attr(xml2::xml_children(by_id(doc, id)), "id")
}

test_that("the page is sized in px and drawn under a Y-flip", {
  doc <- export_scene(function() grid::grid.rect(name = "r"))
  root <- xml2::xml_root(doc)

  testthat::expect_equal(xml2::xml_attr(root, "width"), "216px")
  testthat::expect_equal(xml2::xml_attr(root, "height"), "144px")
  testthat::expect_equal(xml2::xml_attr(root, "viewBox"), "0 0 216 144")
  flip <- xml2::xml_find_first(doc, "/s:svg/s:g", svg_ns)
  testthat::expect_equal(
    xml2::xml_attr(flip, "transform"), "translate(0, 144) scale(1, -1)"
  )
  testthat::expect_equal(
    xml2::xml_attr(xml2::xml_child(flip, 1), "id"), "gridSVG"
  )
})

test_that("grobs are groups named <name>.<k> and shapes <name>.<k>.<i>", {
  # Two grobs of one name, as a redrawn grob gives: grid.grab() warns that
  # it cannot tell them apart by name, which the numbering does instead.
  doc <- suppressWarnings(export_scene(function() {
    grid::grid.rect(x = c(0.25, 0.75), width = 0.1, name = "bars")
    grid::grid.rect(x = 0.5, width = 0.1, name = "bars")
  }))

  testthat::expect_equal(child_ids(doc, "bars.1"), c("bars.1.1", "bars.1.2"))
  testthat::expect_equal(child_ids(doc, "bars.2"), "bars.2.1")
  testthat::expect_equal(xml2::xml_name(by_id(doc, "bars.1.2")), "rect")
})

test_that("a rect's y is its bottom edge, measured up from the page bottom", {
  doc <- export_scene(function() {
    grid::grid.rect(
      x = 0, y = 0, width = 0.5, height = 0.25,
      just = c("left", "bottom"), name = "corner"
    )
  })
  rect <- by_id(doc, "corner.1.1")

  testthat::expect_equal(as.numeric(xml2::xml_attr(rect, "y")), 0)
  testthat::expect_equal(as.numeric(xml2::xml_attr(rect, "height")), 36)
  testthat::expect_equal(as.numeric(xml2::xml_attr(rect, "width")), 108)
})

test_that("an element that is not drawn keeps the numbering of the rest", {
  doc <- export_scene(function() {
    grid::grid.rect(x = c(0.2, NA, 0.8), width = 0.1, name = "gappy")
  })

  testthat::expect_equal(child_ids(doc, "gappy.1"), c("gappy.1.1", "gappy.1.3"))
})

test_that("a line broken by a missing value is lettered piece by piece", {
  doc <- export_scene(function() {
    grid::grid.polyline(
      x = c(0.1, 0.2, NA, 0.4, 0.5), y = c(0.1, 0.2, 0.3, 0.4, 0.5),
      name = "broken"
    )
  })

  testthat::expect_equal(
    child_ids(doc, "broken.1"), c("broken.1.1a", "broken.1.1b")
  )
  testthat::expect_true(all(
    xml2::xml_name(xml2::xml_children(by_id(doc, "broken.1"))) == "polyline"
  ))
})

test_that("segments are one polyline each", {
  doc <- export_scene(function() {
    grid::grid.segments(
      x0 = c(0.1, 0.2), y0 = 0.1, x1 = 0.9, y1 = 0.9, name = "segs"
    )
  })
  kids <- xml2::xml_children(by_id(doc, "segs.1"))

  testthat::expect_equal(xml2::xml_attr(kids, "id"), c("segs.1.1", "segs.1.2"))
  testthat::expect_equal(xml2::xml_name(kids), c("polyline", "polyline"))
})

test_that("an arrowed line keeps its position among its siblings", {
  # gridSVG wrote each arrowed line after a <defs> holding its heads, so the
  # lines sit at even child positions; the heads take the <defs> slot here.
  doc <- export_scene(function() {
    grid::grid.segments(
      x0 = c(0.1, 0.2), y0 = 0.5, x1 = 0.9, y1 = 0.5,
      arrow = grid::arrow(type = "closed"), name = "arrows"
    )
  })
  kids <- xml2::xml_children(by_id(doc, "arrows.1"))

  testthat::expect_equal(xml2::xml_name(kids), c("g", "polyline", "g", "polyline"))
  testthat::expect_equal(xml2::xml_attr(kids, "id")[c(2, 4)], c("arrows.1.1", "arrows.1.2"))
})

test_that("points are <use> references to one symbol per plotting character", {
  doc <- export_scene(function() {
    grid::grid.points(
      x = grid::unit(c(0.2, 0.5, 0.8), "npc"),
      y = grid::unit(c(0.2, 0.5, 0.8), "npc"),
      pch = c(19, 19, 3), name = "pts"
    )
  })
  uses <- xml2::xml_children(by_id(doc, "pts.1"))

  testthat::expect_equal(xml2::xml_name(uses), rep("use", 3))
  testthat::expect_equal(xml2::xml_attr(uses, "id"), paste0("pts.1.", 1:3))
  testthat::expect_equal(
    xml2::xml_attr(uses, "href"),
    c("#gridSVG.pch19", "#gridSVG.pch19", "#gridSVG.pch3")
  )
  symbols <- xml2::xml_find_all(doc, "//s:symbol", svg_ns)
  testthat::expect_setequal(
    xml2::xml_attr(symbols, "id"), c("gridSVG.pch19", "gridSVG.pch3")
  )
  # x/y are the point's centre in the flipped page: 20% of 216 x 144.
  testthat::expect_equal(as.numeric(xml2::xml_attr(uses[[1]], "x")), 43.2)
  testthat::expect_equal(as.numeric(xml2::xml_attr(uses[[1]], "y")), 28.8)
})

test_that("a label is a translated group holding an unflipped text", {
  doc <- export_scene(function() {
    grid::grid.text(c("left", "right"), x = c(0.25, 0.75), name = "lab")
  })
  group <- by_id(doc, "lab.1.2")
  text <- by_id(doc, "lab.1.2.text")

  testthat::expect_match(xml2::xml_attr(group, "transform"), "^translate\\(")
  testthat::expect_equal(
    xml2::xml_attr(by_id(doc, "lab.1.2.scale"), "transform"), "scale(1, -1)"
  )
  testthat::expect_equal(xml2::xml_text(text), "right")
  testthat::expect_equal(
    xml2::xml_attr(xml2::xml_parent(xml2::xml_parent(text)), "id"), "lab.1.2"
  )
})

test_that("an empty label and a blank line still have their element", {
  # The device draws neither, but later siblings' positions count them.
  doc <- export_scene(function() {
    grid::grid.text(c("", "b"), x = c(0.25, 0.75), name = "sparse")
    grid::grid.segments(
      x0 = c(0.1, 0.2), y0 = 0.5, x1 = 0.9, y1 = 0.5,
      gp = grid::gpar(lty = c("blank", "solid")), name = "hidden"
    )
  })

  testthat::expect_equal(
    child_ids(doc, "sparse.1"), c("sparse.1.1", "sparse.1.2")
  )
  testthat::expect_equal(
    child_ids(doc, "hidden.1"), c("hidden.1.1", "hidden.1.2")
  )
})

test_that("paint is presentation attributes, never a stylesheet or style", {
  doc <- export_scene(function() {
    grid::grid.rect(gp = grid::gpar(fill = "#FF0000", col = NA), name = "red")
  })
  svg <- as.character(doc)
  rect <- by_id(doc, "red.1.1")

  testthat::expect_false(grepl(" style=", svg, fixed = TRUE))
  testthat::expect_false(grepl("svglite", svg, fixed = TRUE))
  testthat::expect_equal(xml2::xml_attr(rect, "fill"), "rgb(255,0,0)")
  testthat::expect_equal(xml2::xml_attr(rect, "stroke"), "none")
})

test_that("a shape inherits what its own gpar does not set", {
  # A highlight clone of a group repaints its shapes only where they inherit,
  # so a gTree's gpar is written on its group and not on every shape.
  doc <- export_scene(function() {
    grid::grid.draw(grid::gTree(
      children = grid::gList(grid::linesGrob(name = "inner")),
      gp = grid::gpar(col = "#0000FF"), name = "outer"
    ))
  })

  testthat::expect_equal(
    xml2::xml_attr(by_id(doc, "outer.1"), "stroke"), "rgb(0,0,255)"
  )
  testthat::expect_true(is.na(xml2::xml_attr(by_id(doc, "inner.1.1"), "stroke")))
})

test_that("text is written with a generic font stack", {
  doc <- export_scene(function() grid::grid.text("x", name = "t"))
  family <- xml2::xml_attr(by_id(doc, "t.1.1.text"), "font-family")

  testthat::expect_match(family, "sans-serif$")
})

test_that("the export leaves the caller's device current", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  before <- grDevices::dev.cur()

  maidr:::create_enhanced_svg(
    ggplot2::ggplotGrob(ggplot2::ggplot()), list(id = "empty")
  )

  testthat::expect_equal(grDevices::dev.cur(), before)
})

test_that("drawing rects one at a time gives the same document", {
  # The fallback taken if a vectorised rect ever draws other than one shape
  # per element: it must number and paint every shape as the fast path does.
  walk_doc <- function(one_at_a_time) {
    svg_string <- maidr:::open_svg_device(3, 2)
    dev <- grDevices::dev.cur()
    grid::grid.newpage()
    grid::grid.rect(
      x = c(0.2, 0.5, 0.8), width = 0.1,
      gp = grid::gpar(fill = c("red", "green", "blue")), name = "trio"
    )
    grid::grid.force()
    grid::upViewport(0, recording = FALSE)
    scene <- grid::grid.grab(name = "gridSVG", wrap = TRUE, gp = grid::get.gpar())
    walk <- maidr:::walk_svg_scene(scene, one_at_a_time = one_at_a_time)
    grDevices::dev.off(dev)
    doc <- maidr:::build_svg_document(
      walk, utils::tail(svg_string(), 1L), 216, 144
    )
    testthat::expect_false(isTRUE(attr(doc, "run_mismatch")))
    as.character(doc)
  }

  testthat::expect_identical(walk_doc(FALSE), walk_doc(TRUE))
})

# svglite's output as the walk read it, for tampering with below.
walk_and_svg <- function(draw) {
  svg_string <- maidr:::open_svg_device(3, 2)
  dev <- grDevices::dev.cur()
  grid::grid.newpage()
  draw()
  grid::grid.force()
  grid::upViewport(0, recording = FALSE)
  scene <- grid::grid.grab(name = "gridSVG", wrap = TRUE, gp = grid::get.gpar())
  walk <- maidr:::walk_svg_scene(scene)
  grDevices::dev.off(dev)
  list(walk = walk, lines = strsplit(utils::tail(svg_string(), 1L), "\n")[[1]])
}

rebuild <- function(w, lines) {
  maidr:::build_svg_document(w$walk, paste(lines, collapse = "\n"), 216, 144)
}

test_that("svglite output the rewrite does not know stops the export", {
  # A later svglite writing differently must fail loudly (the chart then
  # falls back to a picture) rather than number shapes onto the wrong grobs.
  w <- walk_and_svg(function() grid::grid.rect(name = "r"))
  at <- grep("^<rect x=", w$lines)[1]

  testthat::expect_no_error(rebuild(w, w$lines))
  testthat::expect_error(
    rebuild(w, append(w$lines, "<ellipse cx='1' cy='1'/>", after = at)),
    "could not read the SVG"
  )
  marks <- grep("@@maidr-svg-mark@@", w$lines)
  testthat::expect_error(
    rebuild(w, w$lines[-marks[1]]),
    "markers read back"
  )
})

test_that("more shapes than a grob can draw stops the export", {
  w <- walk_and_svg(function() {
    grid::grid.path(c(0.1, 0.9, 0.5), c(0.1, 0.1, 0.9), name = "tri")
  })
  at <- grep("^<(path|polygon) ", w$lines)[1]

  testthat::expect_error(
    rebuild(w, append(w$lines, w$lines[at], after = at)),
    "at most 1"
  )
})

test_that("more than 26 pieces are lettered as gridSVG lettered them", {
  # gridSVG's genAlpha(): a..z, then aa, bb, cc -- not aa, ab, ac. The ids
  # a line has always had are the contract, so they are kept exactly.
  suffix <- maidr:::svg_alpha_suffix(30)

  testthat::expect_equal(suffix[1:3], c("a", "b", "c"))
  testthat::expect_equal(suffix[26:30], c("z", "aa", "bb", "cc", "dd"))
  testthat::expect_equal(anyDuplicated(maidr:::svg_alpha_suffix(200)), 0L)

  doc <- export_scene(function() {
    x <- seq(0.02, 0.98, length.out = 90)
    y <- rep(c(0.2, 0.8, NA), 30)
    grid::grid.polyline(x = x, y = y, name = "sparse")
  })
  testthat::expect_equal(
    child_ids(doc, "sparse.1"), paste0("sparse.1.1", suffix)
  )
})

test_that("a grob's shared clip is written once, on its group, in the flipped page", {
  doc <- export_scene(function() {
    grid::pushViewport(grid::viewport(
      x = 0.25, y = 0.25, width = 0.5, height = 0.5,
      just = c("left", "bottom"), clip = "on"
    ))
    grid::grid.rect(x = c(0.25, 0.75), width = 0.2, name = "boxed")
    grid::grid.text("clipped", name = "said")
    grid::popViewport()
  })

  group <- by_id(doc, "boxed.1")
  ref <- sub("^url\\(#(.*)\\)$", "\\1", xml2::xml_attr(group, "clip-path"))
  testthat::expect_false(is.na(ref))
  testthat::expect_true(all(is.na(xml2::xml_attr(
    xml2::xml_children(group), "clip-path"
  ))))
  # The viewport's lower-left quarter-inset box, in px from the bottom edge.
  rect <- xml2::xml_find_first(
    doc, sprintf("//s:clipPath[@id='%s']/s:rect", ref), svg_ns
  )
  testthat::expect_equal(
    as.numeric(vapply(
      c("x", "y", "width", "height"),
      function(a) xml2::xml_attr(rect, a), character(1)
    )),
    c(54, 36, 108, 72)
  )
  # The label in the same viewport shares the same region, on its grob group.
  testthat::expect_equal(
    xml2::xml_attr(by_id(doc, "said.1"), "clip-path"),
    xml2::xml_attr(group, "clip-path")
  )
})

test_that("a clip covering the whole page is left off", {
  doc <- export_scene(function() grid::grid.rect(name = "whole"))

  testthat::expect_true(is.na(xml2::xml_attr(by_id(doc, "whole.1"), "clip-path")))
  testthat::expect_length(xml2::xml_find_all(doc, "//s:clipPath", svg_ns), 0L)
})

test_that("a zero-size point keeps its element with a valid stroke width", {
  doc <- export_scene(function() {
    grid::grid.points(
      x = grid::unit(c(0.3, 0.6), "npc"), y = grid::unit(c(0.5, 0.5), "npc"),
      size = grid::unit(c(0, 2), "mm"), pch = 19, name = "dots"
    )
  })
  uses <- xml2::xml_children(by_id(doc, "dots.1"))

  testthat::expect_equal(xml2::xml_attr(uses, "id"), c("dots.1.1", "dots.1.2"))
  testthat::expect_false(any(grepl("Inf|NaN", as.character(doc))))
})
