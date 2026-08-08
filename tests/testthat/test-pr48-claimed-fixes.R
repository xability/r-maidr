# Regression tests for fixes the Base R / ggplot2 correctness sweep claimed
# but never pinned. test-pr48-regressions.R covers the defects found while
# reviewing that change; this file covers the cases the change itself said
# used to be broken, so they cannot quietly break again.
#
# Everything here asserts on the payload a user actually receives: the
# maidr-data JSON carried by the exported SVG, and - where the failure mode
# is silent misalignment rather than an error - the drawn SVG geometry it
# has to line up with.

reset_devices <- function() {
  maidr:::clear_all_device_storage()
}

#' Pull the maidr-data payload out of a rendered HTML string
#'
#' The attribute is HTML-escaped inside the SVG tag, so it has to be
#' unescaped before it parses as JSON.
parse_maidr_data <- function(html) {
  attribute <- regmatches(html, regexpr('maidr-data="([^"]*)"', html))
  testthat::expect_length(attribute, 1)

  json <- sub('"$', "", sub('^maidr-data="', "", attribute))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

#' Render a plot the way a user would and return the resulting HTML
#'
#' `plot = NULL` takes the Base R auto-detection path.
render_html <- function(plot = NULL) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)

  save_html(plot, file = file)
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

render_maidr_data <- function(plot = NULL) {
  parse_maidr_data(render_html(plot))
}

#' The layer object for one subplot of a rendered payload
#'
#' subplots is a row-major grid of subplots, each holding a list of layers.
payload_layer <- function(data, column = 1, row = 1, layer = 1) {
  data$subplots[[row]][[column]]$layers[[layer]]
}

field_of <- function(points, name) {
  vapply(points, function(point) point[[name]], numeric(1))
}

# ==============================================================================
# curve(sin(x)) - the non-standard-evaluation recording path
#
# curve() evaluates its first argument lazily with `x` bound inside curve()
# itself. Forcing it at record time either errors or, when the caller
# happens to have its own `x`, silently records that unrelated vector -
# so replay redraws something the user never asked for.
# ==============================================================================

test_that("curve() records its expression, not a same-named caller variable", {
  reset_devices()

  # The trap: forcing `sin(x)` here would resolve `x` to THIS vector.
  x <- c(100, 200, 300)

  curve(sin(x), from = 0, to = 2 * pi, n = 9)

  calls <- maidr:::get_device_calls(grDevices::dev.cur())
  testthat::expect_length(calls, 1)

  recorded <- calls[[1]]$args[[1]]
  testthat::expect_true(is.language(recorded))
  testthat::expect_identical(recorded, quote(sin(x)))
  testthat::expect_true(is.environment(calls[[1]]$call_env))

  reset_devices()
})

test_that("a recorded curve() call replays against its own environment", {
  reset_devices()

  x <- c(100, 200, 300)
  curve(sin(x), from = 0, to = 2 * pi, n = 9)

  call <- maidr:::get_device_calls(grDevices::dev.cur())[[1]]
  replayed <- maidr:::replay_plot_call("curve", call$args, call$call_env)

  # The replayed curve must be the one the user drew: nine points across
  # [0, 2*pi] whose y values are sin() of their own x, not of `x` above.
  testthat::expect_length(replayed$x, 9)
  testthat::expect_equal(range(replayed$x), c(0, 2 * pi))
  testthat::expect_equal(replayed$y, sin(replayed$x))

  reset_devices()
})

# ==============================================================================
# Positional argument resolution - resolve_xy_args()
#
# plot()/lines() match `x` and `y` by name first, then by position among the
# UNNAMED arguments. Reading args[[2]] blindly took the graphical parameter
# instead (plot(v, type = "l") -> y = "l") or ran off the end of a
# single-argument call (plot(v), lines(v)).
# ==============================================================================

test_that("plot(v) plots the vector against its index", {
  reset_devices()

  plot(c(3, 1, 4, 1, 5))
  layer <- payload_layer(render_maidr_data())

  testthat::expect_equal(layer$type, "point")
  testthat::expect_equal(field_of(layer$data, "y"), c(3, 1, 4, 1, 5))
  testthat::expect_equal(field_of(layer$data, "x"), 1:5)

  reset_devices()
})

test_that("plot(v, type = 'l') does not mistake `type` for the y data", {
  reset_devices()

  plot(c(3, 1, 4, 1, 5), type = "l")
  layer <- payload_layer(render_maidr_data())

  testthat::expect_equal(layer$type, "line")
  # a single series of five points, y from the vector, x from its index
  testthat::expect_length(layer$data, 1)
  testthat::expect_equal(field_of(layer$data[[1]], "y"), c(3, 1, 4, 1, 5))
  testthat::expect_equal(
    vapply(layer$data[[1]], function(point) point$x, character(1)),
    as.character(1:5)
  )

  reset_devices()
})

test_that("plot(x, y, type = 'l') still reads both positional vectors", {
  reset_devices()

  plot(c(2, 4, 6, 8), c(9, 8, 7, 6), type = "l")
  layer <- payload_layer(render_maidr_data())

  testthat::expect_equal(field_of(layer$data[[1]], "y"), c(9, 8, 7, 6))
  testthat::expect_equal(
    vapply(layer$data[[1]], function(point) point$x, character(1)),
    as.character(c(2, 4, 6, 8))
  )

  reset_devices()
})

test_that("lines(v) overlays the vector as its own layer", {
  reset_devices()

  plot(1:5, c(1, 2, 3, 4, 5))
  lines(c(2, 5, 3, 8, 6))

  data <- render_maidr_data()
  point_layer <- payload_layer(data, layer = 1)
  line_layer <- payload_layer(data, layer = 2)

  testthat::expect_equal(point_layer$type, "point")
  testthat::expect_equal(line_layer$type, "line")
  testthat::expect_equal(
    field_of(line_layer$data[[1]], "y"),
    c(2, 5, 3, 8, 6)
  )

  reset_devices()
})

# ==============================================================================
# Faceted layers must reach their per-panel data
#
# Seven faceted layer types used to die with "unused arguments" because
# process() did not accept panel_id/panel_ctx. Box plot, scatter and heat
# map are pinned in test-pr48-regressions.R; these are the rest. Each uses
# panel values far enough apart that a panel reading its neighbour's data
# cannot pass by coincidence.
# ==============================================================================

test_that("each faceted histogram panel reports its own bin counts", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    value = c(rep(1, 3), rep(9, 7), rep(1, 8), rep(9, 2)),
    panel = rep(c("P1", "P2"), each = 10)
  )
  plot_obj <- ggplot2::ggplot(df, ggplot2::aes(value)) +
    ggplot2::geom_histogram(bins = 2) +
    ggplot2::facet_wrap(~panel)

  data <- render_maidr_data(plot_obj)
  panel1 <- payload_layer(data, column = 1)
  panel2 <- payload_layer(data, column = 2)

  testthat::expect_equal(panel1$type, "hist")
  testthat::expect_equal(field_of(panel1$data, "y"), c(3, 7))
  testthat::expect_equal(field_of(panel2$data, "y"), c(8, 2))

  # each panel highlights its own rects, not the first panel's
  testthat::expect_false(
    identical(unlist(panel1$selectors), unlist(panel2$selectors))
  )
})

test_that("each faceted smooth panel reports its own fitted values", {
  testthat::skip_if_not_installed("ggplot2")

  # panel 2's line is an order of magnitude above panel 1's, so reading
  # the wrong panel's data is unmistakable
  df <- data.frame(
    x = rep(1:20, 2),
    y = c(1:20, (1:20) * 10),
    panel = rep(c("P1", "P2"), each = 20)
  )
  plot_obj <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE) +
    ggplot2::facet_wrap(~panel)

  data <- render_maidr_data(plot_obj)
  panel1 <- payload_layer(data, column = 1)
  panel2 <- payload_layer(data, column = 2)

  testthat::expect_equal(panel1$type, "smooth")
  testthat::expect_equal(range(field_of(panel1$data[[1]], "y")), c(1, 20))
  testthat::expect_equal(range(field_of(panel2$data[[1]], "y")), c(10, 200))

  testthat::expect_false(
    identical(unlist(panel1$selectors), unlist(panel2$selectors))
  )
})

test_that("each faceted stacked bar panel reports its own values", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    category = rep(c("a", "b"), 4),
    fill = rep(c("u", "v"), each = 4),
    panel = rep(c("P1", "P1", "P2", "P2"), 2),
    value = c(1, 2, 100, 200, 3, 4, 300, 400)
  )
  plot_obj <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = category, y = value, fill = fill)
  ) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel)

  data <- render_maidr_data(plot_obj)
  panel1 <- payload_layer(data, column = 1)
  panel2 <- payload_layer(data, column = 2)

  testthat::expect_equal(panel1$type, "stacked_bar")
  testthat::expect_equal(
    sort(unlist(lapply(panel1$data, field_of, "y"))),
    c(1, 2, 3, 4)
  )
  testthat::expect_equal(
    sort(unlist(lapply(panel2$data, field_of, "y"))),
    c(100, 200, 300, 400)
  )

  testthat::expect_false(
    identical(unlist(panel1$selectors), unlist(panel2$selectors))
  )
})

# ==============================================================================
# Base R barplot: emitted order must match the drawn bars
#
# The wrapper sorts named bars alphabetically before drawing, so the SVG
# rects come out in that order. Recording the UNSORTED arguments, or
# re-sorting during extraction, leaves every announcement and highlight
# attached to the wrong bar - silently, with no error anywhere.
#
# gridSVG exports the plot under transform="translate(0, height) scale(1, -1)",
# so a bar's rect height grows with its value: rank-matching the rect
# heights against the emitted values is what proves the two agree.
# ==============================================================================

#' Read the rects a layer's selector points at, in document order
#'
#' The selector is a CSS id selector with the dots escaped
#' ("#graphics-plot-1-rect-1\\.1 rect"); the id itself is what xml2 needs.
selector_rects <- function(html, selector) {
  svg <- regmatches(html, regexpr("<svg.*</svg>", html))
  testthat::expect_length(svg, 1)

  group_id <- gsub("\\\\", "", sub("^#([^ ]+) rect$", "\\1", selector))
  group <- xml2::xml_find_first(
    xml2::read_html(svg),
    sprintf("//*[@id='%s']", group_id)
  )
  testthat::expect_false(is.na(group))

  xml2::xml_find_all(group, ".//rect")
}

test_that("named barplot bars are emitted in the order they are drawn", {
  reset_devices()

  # deliberately unsorted names with distinct values, so each bar is
  # identifiable from its geometry alone
  barplot(c(delta = 7, alpha = 3, charlie = 11))

  html <- render_html()
  layer <- payload_layer(parse_maidr_data(html))

  # the wrapper draws the bars alphabetically, so that is the order the
  # data has to be announced in
  testthat::expect_equal(
    vapply(layer$data, function(point) point$x, character(1)),
    c("alpha", "charlie", "delta")
  )
  testthat::expect_equal(field_of(layer$data, "y"), c(3, 11, 7))

  rects <- selector_rects(html, unlist(layer$selectors)[1])
  testthat::expect_length(rects, length(layer$data))

  heights <- as.numeric(xml2::xml_attr(rects, "height"))
  lefts <- as.numeric(xml2::xml_attr(rects, "x"))

  # rects arrive left to right, and the i-th one is as tall as the i-th
  # emitted value is large
  testthat::expect_true(all(diff(lefts) > 0))
  testthat::expect_equal(rank(heights), rank(field_of(layer$data, "y")))

  reset_devices()
})

test_that("an unnamed barplot keeps call order in both data and geometry", {
  reset_devices()

  # nothing to sort by, so the drawn order is the call order and the
  # emitted labels are the bar indices
  barplot(c(9, 2, 7, 4))

  html <- render_html()
  layer <- payload_layer(parse_maidr_data(html))

  testthat::expect_equal(field_of(layer$data, "y"), c(9, 2, 7, 4))

  rects <- selector_rects(html, unlist(layer$selectors)[1])
  heights <- as.numeric(xml2::xml_attr(rects, "height"))

  testthat::expect_length(rects, 4)
  testthat::expect_equal(rank(heights), rank(c(9, 2, 7, 4)))

  reset_devices()
})

# ==============================================================================
# Widget and Shiny paths reach Base R auto-detection
#
# maidr_widget() rejected anything that was not a ggplot, so
# show(as_widget = TRUE) after a Base R call died with "Input must be a
# ggplot object" - the one show() mode Base R could not use.
# ==============================================================================

#' Decode the maidr-data of a widget's base64 data-URI iframe
widget_maidr_data <- function(widget) {
  encoded <- sub(
    '^.*src="data:text/html;base64,([^"]*)".*$', "\\1",
    widget$x$iframe_content
  )
  html <- rawToChar(base64enc::base64decode(encoded))
  Encoding(html) <- "UTF-8"
  parse_maidr_data(html)
}

test_that("show(as_widget = TRUE) renders a recorded Base R plot", {
  reset_devices()

  barplot(c(delta = 7, alpha = 3, charlie = 11))
  widget <- show(as_widget = TRUE)

  testthat::expect_s3_class(widget, "htmlwidget")
  testthat::expect_s3_class(widget, "maidr")

  layer <- payload_layer(widget_maidr_data(widget))
  testthat::expect_equal(layer$type, "bar")
  testthat::expect_equal(field_of(layer$data, "y"), c(3, 11, 7))

  reset_devices()
})

test_that("show(as_widget = TRUE) clears the recorded Base R calls", {
  reset_devices()

  barplot(c(a = 1, b = 2))
  invisible(show(as_widget = TRUE))

  # leaving the calls behind would fold this plot into the next render
  testthat::expect_false(maidr:::has_device_calls(grDevices::dev.cur()))

  reset_devices()
})

test_that("render_maidr() hands a Base R plot's own values to the widget", {
  testthat::skip_if_not_installed("shiny")
  reset_devices()

  # test-shiny-render.R pins WHICH branch each reactive shape takes; this
  # pins that the Base R branch carries the recorded plot's data through.
  server <- function(input, output, session) {
    output$p <- render_maidr({
      barplot(c(delta = 7, alpha = 3, charlie = 11))
    })
  }

  shiny::testServer(server, {
    payload <- jsonlite::fromJSON(as.character(output$p), simplifyVector = FALSE)
    layer <- payload_layer(widget_maidr_data(list(x = payload$x)))

    testthat::expect_equal(field_of(layer$data, "y"), c(3, 11, 7))
  })

  reset_devices()
})
