# A curve layer outlined whatever was drawn after it (#204)
#
# `Ggplot2SmoothLayerProcessor$generate_selectors()` picked its curve by
# taking the largest `GRID.polyline.N` in the panel. The reasoning behind it
# is sound but local: within one smooth layer, the confidence band is drawn
# before the fitted line, so the later grob is the line. Applied panel-wide
# the largest counter is simply whatever was drawn last, so any other
# polyline-drawing layer takes it.
#
# Measured before the fix, with both orders of the same two layers:
#
#   geom_smooth() then geom_line()   smooth -> .234   line -> .234
#   geom_line() then geom_smooth()   line   -> .324   smooth -> .325
#
# One order is correct and the other hands the curve the line's polyline, so
# a test written in only one order passes while the defect is live. Every
# pairing below is therefore asserted in both orders.
#
# `geom_function()` adds the same failure from the other side. Its grob is a
# *bare* polyline -- `GeomFunction` inherits `GeomPath$draw_panel()` and gets
# no geom-named tree -- so it joins the population `layer_polyline_grobs()`
# hands to a line layer, while `polyline_layer_position()` counted only the
# line-ish types. A function drawn first therefore took the line's slot and
# the line took the function's: the two charts outlined each other.
#
# Nothing about either announcement changes in any of these cases. The audio,
# the text and the braille are all correct while the wrong curve lights up,
# which is the highlight-only shape xability/maidr#814 names -- so each test
# resolves the selector against the rendered document and counts the points
# of the element it lands on, rather than comparing selector strings.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

#' Render a plot once, returning both its layers and the document
#'
#' Rendered once and read twice on purpose. `GRID.polyline.N` carries grid's
#' *session-wide* grob counter, so two renders of the same plot produce
#' different ids -- a test that took the layers from one render and the
#' document from another would compare a selector against a document that
#' never contained it.
curve_render <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(list(html = html, layers = NULL))
  }
  json <- gsub("^maidr-data=\"|\"$", "", raw)
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&#39;", "'", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  list(html = html, layers = parsed$subplots[[1]][[1]]$layers)
}

#' The id in a selector, in either of the two formats processors emit
selector_id <- function(selector) {
  if (grepl("^\\*\\[id=", selector)) {
    sub("^\\*\\[id='(.*)'\\]$", "\\1", selector)
  } else {
    gsub("\\\\", "", sub("^#", "", selector))
  }
}

#' How many points the polyline this layer's selector names holds
#'
#' The count is what tells the two curves apart: a `geom_line()` over twelve
#' rows draws twelve points, a curve sampled at `n` draws `n`. Comparing ids
#' would only show that they differ, not which is whose.
outlined_points <- function(rendered, index) {
  selectors <- rendered$layers[[index]]$selectors
  if (!length(selectors)) {
    return(NA_integer_)
  }
  id <- selector_id(selectors[[1]])
  found <- regmatches(
    rendered$html,
    regexpr(paste0('id="', id, '"[^>]*points="[^"]*"'), rendered$html)
  )
  if (!length(found)) {
    return(NA_integer_)
  }
  points <- sub('.*points="([^"]*)".*', "\\1", found)
  length(strsplit(trimws(points), "\\s+")[[1]])
}

#' Every polyline in the document holding exactly `n` points, by id
#'
#' A confidence band is drawn as its two edges, each sampled at the same `n`
#' as the fitted line it surrounds, so counting points cannot tell an edge
#' from the curve. Their *positions* can: the fitted line runs between them.
#'
#' Ordered by x, because a ribbon's outline is traced up one edge and back
#' down the other -- the second edge arrives reversed, and comparing it to
#' the curve by index would line each sample up against the wrong one.
sampled_curves <- function(html, n) {
  found <- regmatches(
    html,
    gregexpr('id="[^"]*"[^>]*points="[^"]*"', html)
  )[[1]]
  out <- list()
  for (element in found) {
    id <- sub('id="([^"]*)".*', "\\1", element)
    pairs <- strsplit(
      trimws(sub('.*points="([^"]*)".*', "\\1", element)), "\\s+"
    )[[1]]
    if (length(pairs) != n) {
      next
    }
    xs <- as.numeric(sub(",.*", "", pairs))
    ys <- as.numeric(sub(".*,", "", pairs))
    out[[id]] <- ys[order(xs)]
  }
  out
}

#' Twelve rows, so a twelve-point line cannot be mistaken for a sampled curve
noisy_frame <- function() {
  set.seed(3)
  frame <- data.frame(x = seq(0, 6, length.out = 12))
  frame$y <- sin(frame$x) + stats::rnorm(12, 0, 0.15)
  frame
}


test_that("a smooth drawn before a line outlines its own curve (#204)", {
  skip_if_no_render()

  rendered <- curve_render(
    ggplot2::ggplot(noisy_frame(), ggplot2::aes(x, y)) +
      ggplot2::geom_smooth(
        se = FALSE, method = "loess", formula = y ~ x, n = 25
      ) +
      ggplot2::geom_line()
  )

  testthat::expect_equal(
    vapply(rendered$layers, function(l) l$type, character(1)),
    c("smooth", "line")
  )
  # 25 sampled points for the fitted curve, 12 rows for the line. Before the
  # fix both selectors resolved to the same twelve-point element.
  testthat::expect_equal(outlined_points(rendered, 1), 25)
  testthat::expect_equal(outlined_points(rendered, 2), 12)
})


test_that("a smooth drawn after a line still outlines its own curve", {
  skip_if_no_render()

  # The order that was already correct. Kept so a fix that merely moves the
  # mix-up to the other order cannot pass.
  rendered <- curve_render(
    ggplot2::ggplot(noisy_frame(), ggplot2::aes(x, y)) +
      ggplot2::geom_line() +
      ggplot2::geom_smooth(
        se = FALSE, method = "loess", formula = y ~ x, n = 25
      )
  )

  testthat::expect_equal(outlined_points(rendered, 1), 12)
  testthat::expect_equal(outlined_points(rendered, 2), 25)
})


test_that("a smooth with a band outlines the fitted line, not the band", {
  skip_if_no_render()

  # `se = TRUE` puts a ribbon in the layer's own tree, drawn before the
  # curve, so the layer's polylines are the band's two edges and then the
  # fitted line. Taking the LAST of them is what keeps the original "band
  # first, line second" reasoning working -- it was only ever wrong when
  # applied across layers rather than within one.
  #
  # Point counts cannot check this: ggplot2 draws each band edge as its own
  # sub-polyline sampled at the same `n` as the curve, so all three hold 25
  # points. Measured -- `GRID.polyline.12.1.1`, `.12.1.2` and `.15.1.1`, 25
  # points each. What separates them is where they sit: the fitted line runs
  # between its own band's edges at every sample, and neither edge does.
  rendered <- curve_render(
    ggplot2::ggplot(noisy_frame(), ggplot2::aes(x, y)) +
      ggplot2::geom_smooth(
        se = TRUE, method = "loess", formula = y ~ x, n = 25
      ) +
      ggplot2::geom_line()
  )

  curves <- sampled_curves(rendered$html, 25)
  testthat::expect_length(curves, 3)

  outlined <- selector_id(rendered$layers[[1]]$selectors[[1]])
  testthat::expect_true(outlined %in% names(curves))

  edges <- curves[names(curves) != outlined]
  testthat::expect_length(edges, 2)

  # Strictly between the other two at every sample, in SVG coordinates --
  # whose y axis points down, which `pmin`/`pmax` makes irrelevant.
  fitted <- curves[[outlined]]
  testthat::expect_true(
    all(fitted > pmin(edges[[1]], edges[[2]])) &&
      all(fitted < pmax(edges[[1]], edges[[2]]))
  )

  # And the line beside it still outlines its own twelve rows.
  testthat::expect_equal(outlined_points(rendered, 2), 12)
})
