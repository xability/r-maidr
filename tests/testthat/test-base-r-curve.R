# Regression tests for issue #82: curve() fell back to a static image.
#
# curve() was recorded as a HIGH-level call, but the adapter had no layer
# type for it, so it typed as "unknown" and the whole figure rendered as a
# picture -- no sonification, no braille, no keyboard navigation.
#
# Everything here asserts on the payload a user receives: the maidr-data
# JSON carried by the exported SVG. A curve is only described correctly if
# its y values actually track the expression the user wrote, so the data
# assertions recompute the function rather than checking that points exist.

# Read every maidr-data payload back out of a rendered HTML file.
read_curve_payloads <- function(file) {
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  matches <- regmatches(html, gregexpr('maidr-data="[^"]*"', html))[[1]]
  lapply(matches, function(match) {
    raw <- sub('"$', "", sub('^maidr-data="', "", match))
    raw <- gsub("&quot;", '"', raw, fixed = TRUE)
    raw <- gsub("&lt;", "<", raw, fixed = TRUE)
    raw <- gsub("&gt;", ">", raw, fixed = TRUE)
    raw <- gsub("&amp;", "&", raw, fixed = TRUE)
    jsonlite::fromJSON(raw, simplifyVector = FALSE)
  })
}

# Draw `plot_fun` on an off-screen device, render it the way a user would,
# and hand back the payloads, the raw HTML and every warning raised.
render_curve_figure <- function(plot_fun) {
  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )

  warnings_seen <- character(0)
  withCallingHandlers(
    {
      plot_fun()
      maidr::save_html(plot = NULL, file = file)
    },
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  list(
    payloads = read_curve_payloads(file),
    html = paste(readLines(file, warn = FALSE), collapse = "\n"),
    warnings = warnings_seen
  )
}

curve_layer <- function(payload, row = 1, column = 1, layer = 1) {
  payload$subplots[[row]][[column]]$layers[[layer]]
}

# A line layer serializes as one series of {x, y} objects; x is a string.
layer_xy <- function(layer) {
  points <- layer$data[[1]]
  list(
    x = vapply(points, function(p) as.numeric(p$x), numeric(1)),
    y = vapply(points, function(p) as.numeric(p$y), numeric(1))
  )
}

# The selector is a CSS id with the dot escaped; the SVG has to carry an
# element with the unescaped id for it to resolve in a browser.
selector_target_id <- function(selector) {
  sub("^#", "", sub(" .*$", "", gsub("\\\\.", ".", selector)))
}

# ==============================================================================
# The reported case
# ==============================================================================

test_that("curve() renders as an interactive line layer, not a static image", {
  result <- render_curve_figure(function() {
    curve(sin(x), from = 0, to = 2 * pi)
  })

  testthat::expect_length(result$payloads, 1)
  testthat::expect_false(any(grepl(
    "Rendering as static image", result$warnings,
    fixed = TRUE
  )))

  layer <- curve_layer(result$payloads[[1]])
  testthat::expect_identical(layer$type, "line")

  # curve()'s default resolution, spanning exactly the requested interval.
  xy <- layer_xy(layer)
  testthat::expect_length(xy$x, 101)
  testthat::expect_equal(range(xy$x), c(0, 2 * pi))

  # The point of the layer: the announced y values ARE sin() of their x.
  testthat::expect_equal(xy$y, sin(xy$x))
})

test_that("curve() honours from/to/n and keeps the expression's own values", {
  result <- render_curve_figure(function() {
    curve(x^2 - 1, from = -2, to = 2, n = 9)
  })

  testthat::expect_length(result$payloads, 1)

  xy <- layer_xy(curve_layer(result$payloads[[1]]))
  testthat::expect_equal(xy$x, seq(-2, 2, length.out = 9))
  testthat::expect_equal(xy$y, seq(-2, 2, length.out = 9)^2 - 1)
})

test_that("curve() does not read a same-named variable from the caller", {
  # The trap from #48: forcing `sin(x)` at record time, or re-deriving the
  # points at emit time from a frame where `x` is bound, would announce
  # sin(c(100, 200, 300)) instead of the curve that was drawn.
  x <- c(100, 200, 300)

  result <- render_curve_figure(function() {
    curve(sin(x), from = 0, to = 2 * pi, n = 9)
  })

  xy <- layer_xy(curve_layer(result$payloads[[1]]))
  testthat::expect_equal(xy$x, seq(0, 2 * pi, length.out = 9))
  testthat::expect_equal(xy$y, sin(xy$x))
})

# ==============================================================================
# Axis labels -- curve() derives them internally, they are not in the call
# ==============================================================================

test_that("curve() announces the axis labels it draws", {
  result <- render_curve_figure(function() {
    curve(sin(x), from = 0, to = 2 * pi)
  })

  layer <- curve_layer(result$payloads[[1]])
  testthat::expect_identical(layer$axes$x$label, "x")
  testthat::expect_identical(layer$axes$y$label, "sin(x)")
})

test_that("an explicit xlab/ylab/main wins over curve()'s own defaults", {
  result <- render_curve_figure(function() {
    curve(x^2,
      from = -2, to = 2, n = 5,
      main = "Parabola", xlab = "input", ylab = "output"
    )
  })

  payload <- result$payloads[[1]]
  layer <- curve_layer(payload)
  testthat::expect_identical(layer$axes$x$label, "input")
  testthat::expect_identical(layer$axes$y$label, "output")
  testthat::expect_identical(payload$title, "Parabola")
})

test_that("a bare function name is labelled and sampled the way curve() draws it", {
  # curve(sin, 0, 1) rewrites the expression to sin(x) for the y label, and
  # every argument here is positional, so nothing can be matched by name.
  result <- render_curve_figure(function() {
    curve(sin, 0, 2 * pi)
  })

  layer <- curve_layer(result$payloads[[1]])
  testthat::expect_identical(layer$axes$y$label, "sin(x)")

  xy <- layer_xy(layer)
  testthat::expect_equal(xy$y, sin(xy$x))
})

test_that("curve() respects a renamed variable via xname", {
  result <- render_curve_figure(function() {
    curve(cos(t), from = 0, to = pi, n = 7, xname = "t")
  })

  layer <- curve_layer(result$payloads[[1]])
  testthat::expect_identical(layer$axes$x$label, "t")
  testthat::expect_identical(layer$axes$y$label, "cos(t)")

  xy <- layer_xy(layer)
  testthat::expect_equal(xy$x, seq(0, pi, length.out = 7))
  testthat::expect_equal(xy$y, cos(xy$x))
})

# ==============================================================================
# Highlighting -- the emitted selector must address a real SVG element
# ==============================================================================

test_that("the emitted selector addresses the polyline curve() drew", {
  result <- render_curve_figure(function() {
    curve(sin(x), from = 0, to = 2 * pi)
  })

  layer <- curve_layer(result$payloads[[1]])
  testthat::expect_length(layer$selectors, 1)

  selector <- layer$selectors[[1]]
  testthat::expect_identical(selector, "#graphics-plot-1-lines-1\\.1 polyline")

  # The escaped id has to exist in the exported SVG, or the selector
  # resolves to nothing and highlighting silently does nothing.
  testthat::expect_true(grepl(
    paste0("id=\"", selector_target_id(selector), "\""),
    result$html,
    fixed = TRUE
  ))
})

# ==============================================================================
# Multi-panel figures, including the loop case #59 fixed
# ==============================================================================

test_that("each mfrow panel carries its own curve and its own selector", {
  result <- render_curve_figure(function() {
    par(mfrow = c(1, 2))
    curve(sin(x), from = 0, to = pi, n = 11)
    curve(sin(3 * x), from = 0, to = pi, n = 11)
    par(mfrow = c(1, 1))
  })

  testthat::expect_length(result$payloads, 1)
  payload <- result$payloads[[1]]
  testthat::expect_length(payload$subplots, 1)
  testthat::expect_length(payload$subplots[[1]], 2)

  left <- curve_layer(payload, 1, 1)
  right <- curve_layer(payload, 1, 2)

  left_xy <- layer_xy(left)
  right_xy <- layer_xy(right)
  testthat::expect_equal(left_xy$y, sin(left_xy$x))
  testthat::expect_equal(right_xy$y, sin(3 * right_xy$x))

  testthat::expect_identical(
    left$selectors[[1]], "#graphics-plot-1-lines-1\\.1 polyline"
  )
  testthat::expect_identical(
    right$selectors[[1]], "#graphics-plot-2-lines-1\\.1 polyline"
  )
})

test_that("a curve drawn inside a function sees that function's variables", {
  # curve() resolves free variables against parent.frame(). Called through
  # the wrapper that is the wrapper's frame, not the user's, so a local
  # variable used to be invisible and the call died with "object 'k' not
  # found" -- a call that works in plain R.
  draw_scaled_sine <- function(k) {
    curve(sin(k * x), from = 0, to = pi, n = 11)
  }

  result <- render_curve_figure(function() draw_scaled_sine(4))

  testthat::expect_length(result$payloads, 1)
  xy <- layer_xy(curve_layer(result$payloads[[1]]))
  testthat::expect_equal(xy$y, sin(4 * xy$x))
})

test_that("curves drawn in a loop keep their own loop-variable value", {
  # R reuses one frame for a whole `for` loop (issue #59), so a curve whose
  # points were re-derived later would replay every panel with k = 3.
  result <- render_curve_figure(function() {
    par(mfrow = c(1, 2))
    for (k in c(1, 3)) curve(sin(k * x), from = 0, to = pi, n = 11)
    par(mfrow = c(1, 1))
  })

  payload <- result$payloads[[1]]
  left_xy <- layer_xy(curve_layer(payload, 1, 1))
  right_xy <- layer_xy(curve_layer(payload, 1, 2))

  testthat::expect_equal(left_xy$y, sin(1 * left_xy$x))
  testthat::expect_equal(right_xy$y, sin(3 * right_xy$x))
})

# ==============================================================================
# Deliberately out of scope: draw types and overlays keep the old fallback
# ==============================================================================

test_that("curve(type = 'p') keeps falling back to a static image", {
  # It draws a points grob, not the polyline the line selector addresses,
  # so emitting a line layer would ship a selector that highlights nothing.
  result <- render_curve_figure(function() {
    curve(sin(x), from = 0, to = 2 * pi, type = "p")
  })

  testthat::expect_length(result$payloads, 0)
  testthat::expect_true(any(grepl(
    "Rendering as static image", result$warnings,
    fixed = TRUE
  )))
})

test_that("curve(add = TRUE) falls back cleanly, without leaking maidr args", {
  # An overlay opens its own plot group, and a single-panel figure exports
  # only the first group's grob, so the overlay stays on the static path.
  # The fallback still has to replay the recorded call without passing
  # maidr's own bookkeeping into the plotting function's `...`.
  result <- render_curve_figure(function() {
    plot(1:10, sqrt(1:10), type = "l")
    curve(sqrt(x), from = 1, to = 10, add = TRUE)
  })

  testthat::expect_length(result$payloads, 0)
  testthat::expect_true(any(grepl(
    "Rendering as static image", result$warnings,
    fixed = TRUE
  )))
  testthat::expect_false(any(grepl(
    "is not a graphical parameter", result$warnings,
    fixed = TRUE
  )))
  testthat::expect_false(any(grepl(
    "Failed to replay", result$warnings,
    fixed = TRUE
  )))
})

# ==============================================================================
# Layer typing, directly
# ==============================================================================

test_that("the adapter types curve() the way it types plot(type = 'l')", {
  adapter <- maidr:::BaseRAdapter$new()

  line_plot <- list(
    function_name = "plot",
    args = list(1:3, 1:3, type = "l")
  )
  testthat::expect_identical(
    adapter$detect_layer_type(line_plot), "line"
  )

  plain <- list(
    function_name = "curve",
    args = list(quote(sin(x)), from = 0, to = quote(2 * pi))
  )
  testthat::expect_identical(adapter$detect_layer_type(plain), "line")

  overplotted <- list(
    function_name = "curve",
    args = list(quote(sin(x)), type = "o")
  )
  testthat::expect_identical(adapter$detect_layer_type(overplotted), "line")

  for (drawn_as in c("p", "b", "c", "s", "S", "h", "n")) {
    typed <- adapter$detect_layer_type(list(
      function_name = "curve",
      args = list(quote(sin(x)), type = drawn_as)
    ))
    testthat::expect_identical(typed, "unknown")
  }

  overlay <- list(
    function_name = "curve",
    args = list(quote(sin(x)), add = TRUE)
  )
  testthat::expect_identical(adapter$detect_layer_type(overlay), "unknown")

  not_an_overlay <- list(
    function_name = "curve",
    args = list(quote(sin(x)), add = FALSE)
  )
  testthat::expect_identical(adapter$detect_layer_type(not_an_overlay), "line")
})
