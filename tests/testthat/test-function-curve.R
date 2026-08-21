# `geom_function()` draws a sampled curve, and it rendered as a picture (#202)
#
# Same failure shape as the dot plot in #201: not a mis-typed layer but no
# layer, because `should_fallback()` fired on the unclassified geom and the
# whole figure went out as an `<img>`.
#
#   geom_function    svg=FALSE  maidr-data=FALSE  img=TRUE
#
# Unlike `GeomRaster` (#193) and `GeomDotplot` (#201), this one *is* a
# relative of something already handled -- `GeomFunction` inherits `GeomPath`
# -- and it is the first-element class match that misses it:
#
#   class(GeomFunction)   "GeomFunction" "GeomPath" "Geom" "ggproto" "gg"
#
# It reads as `smooth` rather than `line` for the reason `StatDensity` does.
# The curve is sampled from a function at `n` renderer-chosen points, so there
# are no observations to announce and the sample count is a drawing parameter,
# not data. That is the distinction `smooth` already carries in this package.

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
#' never contained it, and fail for a reason that has nothing to do with the
#' reading.
function_render <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  list(html = html, layers = layers_in(html))
}

#' The layers a rendered document carries, or NULL when it carries none
layers_in <- function(html) {
  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(NULL)
  }
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers
}

#' Just the layers, for the assertions that do not look at the document
function_layers <- function(plot) {
  function_render(plot)$layers
}

#' The id a selector names, in either of the two spellings this package emits
#'
#' The line processor writes `#GRID\.polyline\.1\.1\.1` and the newer ones
#' write `*[id='...']`; both are valid CSS and both appear in one plot.
selector_id <- function(selector) {
  if (grepl("^\\*\\[id=", selector)) {
    sub("^\\*\\[id='(.*)'\\]$", "\\1", selector)
  } else {
    gsub("\\\\", "", sub("^#", "", selector))
  }
}

#' A sine over [0, 6], as `geom_function` samples it
function_plot <- function(n = 9) {
  ggplot2::ggplot(data.frame(x = c(0, 6)), ggplot2::aes(x)) +
    ggplot2::geom_function(fun = sin, n = n)
}

test_that("a computed curve reaches the smooth processor at all", {
  testthat::skip_if_not_installed("ggplot2")

  # Upstream of everything else and asked without rendering, so a regression
  # in the branch surfaces as one failure about classification rather than
  # several about curves.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- function_plot()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "smooth"
  )
})

test_that("a computed curve is a chart rather than a picture", {
  skip_if_no_render()

  layers <- function_layers(function_plot())

  testthat::expect_false(is.null(layers))
  testthat::expect_length(layers, 1)
  testthat::expect_equal(layers[[1]]$type, "smooth")
})

test_that("the curve carries the points the function was sampled at", {
  skip_if_no_render()

  # Checked against `sin` in closed form rather than against a recorded
  # shape: `n = 9` over [0, 6] samples at 0, 0.75, 1.5 and so on, and the
  # announced y has to be the function's value there. A reading that emitted
  # the drawing's coordinates, or the wrong layer's data, fails this while
  # passing any assertion about the count.
  layers <- function_layers(function_plot(n = 9))
  points <- layers[[1]]$data[[1]]

  xs <- vapply(points, function(point) as.numeric(point$x), numeric(1))
  ys <- vapply(points, function(point) as.numeric(point$y), numeric(1))

  testthat::expect_length(points, 9)
  testthat::expect_equal(xs, seq(0, 6, length.out = 9))
  testthat::expect_equal(ys, sin(xs), tolerance = 1e-6)
})

test_that("a lone computed curve is addressed by the polyline it drew", {
  skip_if_no_render()

  # `GeomFunction` draws a bare auto-named polyline rather than a tree named
  # after its geom, so it is addressed the way a line is. Asserted against the
  # document, because a selector that resolves to nothing reads correctly
  # through every modality and lights nothing up (xability/maidr#814).
  rendered <- function_render(function_plot())
  selectors <- rendered$layers[[1]]$selectors

  testthat::expect_length(selectors, 1)
  testthat::expect_true(
    grepl(
      paste0('id="', selector_id(selectors[[1]]), '"'),
      rendered$html,
      fixed = TRUE
    )
  )
})

test_that("a curve and a line drawn together are told apart by their data", {
  skip_if_no_render()

  # Both layers read, and each reads its own numbers: twelve observations for
  # the line, nine samples for the curve. What they announce is right in
  # either drawing order.
  #
  # What is *not* right in one of the two orders is which curve lights up --
  # see the test below, which pins that separately because it is a defect of
  # the selector path rather than of this reading.
  set.seed(3)
  frame <- data.frame(x = seq(0, 6, length.out = 12))
  frame$y <- sin(frame$x) + rnorm(12, 0, 0.15)

  first <- function_layers(
    ggplot2::ggplot(frame, ggplot2::aes(x, y)) +
      ggplot2::geom_line() +
      ggplot2::geom_function(fun = sin, n = 9)
  )
  second <- function_layers(
    ggplot2::ggplot(frame, ggplot2::aes(x, y)) +
      ggplot2::geom_function(fun = sin, n = 9) +
      ggplot2::geom_line()
  )

  testthat::expect_equal(
    vapply(first, function(layer) layer$type, character(1)),
    c("line", "smooth")
  )
  testthat::expect_equal(
    vapply(second, function(layer) layer$type, character(1)),
    c("smooth", "line")
  )

  sizes <- function(layers) {
    vapply(layers, function(layer) length(layer$data[[1]]), numeric(1))
  }
  testthat::expect_equal(sizes(first), c(12, 9))
  testthat::expect_equal(sizes(second), c(9, 12))
})


test_that("a curve drawn before a line keeps its own curve (#204)", {
  skip_if_no_render()

  # `geom_function()` draws a *bare* polyline: `GeomFunction` inherits
  # `GeomPath$draw_panel()` and gets no geom-named tree, so its grob is
  # indistinguishable by name from a `geom_line()`'s and only draw order
  # tells them apart. Both halves of that ordering were wrong when the
  # function was drawn first. Measured before the fix:
  #
  #   function  n=9   selector GRID.polyline.42.1.1  svg points=12
  #   line      n=12  selector GRID.polyline.41.1.1  svg points=9
  #
  # -- each outlining the other's curve, with every announcement correct
  # throughout, which is the highlight-only shape xability/maidr#814 names.
  # The curve took the largest counter in the panel, and the line indexed a
  # population `polyline_layer_position()` counted without it.
  set.seed(3)
  frame <- data.frame(x = seq(0, 6, length.out = 12))
  frame$y <- sin(frame$x) + rnorm(12, 0, 0.15)

  rendered <- function_render(
    ggplot2::ggplot(frame, ggplot2::aes(x, y)) +
      ggplot2::geom_function(fun = sin, n = 9) +
      ggplot2::geom_line()
  )

  #' How many points the polyline with this id holds in the document
  drawn_points <- function(html, id) {
    found <- regmatches(
      html, regexpr(paste0('id="', id, '"[^>]*points="[^"]*"'), html)
    )
    if (!length(found)) {
      return(NA_integer_)
    }
    length(strsplit(trimws(sub('.*points="([^"]*)".*', "\\1", found)), "\\s+")[[1]])
  }

  curve <- rendered$layers[[1]]
  line <- rendered$layers[[2]]
  testthat::expect_equal(curve$type, "smooth")
  testthat::expect_equal(line$type, "line")
  testthat::expect_length(curve$data[[1]], 9)

  # Nine sampled points for the curve, twelve rows for the line, each
  # outlining the element it announces.
  testthat::expect_equal(
    drawn_points(rendered$html, selector_id(curve$selectors[[1]])), 9
  )
  testthat::expect_equal(
    drawn_points(rendered$html, selector_id(line$selectors[[1]])), 12
  )
})
