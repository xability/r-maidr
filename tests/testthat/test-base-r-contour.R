# Base R `contour()` is read as the contour it draws (#218)
#
# #214 stopped `contour()` shipping a layer typed "contour" with no processor
# behind it -- which made the figure bind interactively and then fail to
# construct -- by typing the call "unknown" so it degraded to a static image.
# That was the smaller half; this is the reading.
#
# The curves come from `grDevices::contourLines()`, which is the same
# computation `contour()` does and takes the same defaults, so nothing here
# guesses at what was drawn:
#
#   contour.default(x = seq(0, 1, length.out = nrow(z)),
#                   y = seq(0, 1, length.out = ncol(z)),
#                   z, nlevels = 10, levels = pretty(zlim, nlevels),
#                   zlim = range(z, finite = TRUE))
#
# The selector half was the part recorded as unresolved when #214 shipped.
# It is resolved: gridGraphics writes one `lines` grob per curve, named
# `graphics-plot-<group>-contour-<i>-<i>`, in the order `contourLines()`
# returns them -- measured vertex count by vertex count against the curves,
# not assumed.

skip_unless_jsonlite <- function() {
  testthat::skip_if_not_installed("jsonlite")
}

# A field with a simple, exactly-known set of contours.
FIELD <- matrix(c(1, 2, 3, 2, 4, 6, 3, 6, 9), nrow = 3)

decode_payloads <- function(file) {
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

# Draw on an off-screen device, render as a user would, hand back the layer
# and the page it came in.
render_base_figure <- function(plot_fun) {
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
      clear_all_device_storage()
    },
    add = TRUE
  )

  suppressWarnings({
    plot_fun()
    maidr::save_html(plot = NULL, file = file)
  })

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  payloads <- decode_payloads(file)
  layers <- if (length(payloads) == 0) {
    list()
  } else {
    payloads[[1]]$subplots[[1]][[1]]$layers
  }

  list(
    layers = layers,
    html = html,
    fell_back = grepl("base64", html, fixed = TRUE)
  )
}


test_that("a contour is read rather than turned into a picture", {
  skip_unless_jsonlite()

  result <- render_base_figure(function() contour(FIELD))

  expect_length(result$layers, 1L)
  expect_equal(result$layers[[1]]$type, "contour")
  expect_false(result$fell_back)
})

test_that("it announces the curves contourLines says were drawn", {
  skip_unless_jsonlite()

  # The reference, computed the way `contour()` computes it. Asserted against
  # rather than against numbers typed here, because the point is that the two
  # agree -- a hand-written expectation would pass even if the processor
  # invented its own levels.
  levels <- pretty(range(FIELD, finite = TRUE), 10)
  expected <- grDevices::contourLines(
    x = seq(0, 1, length.out = nrow(FIELD)),
    y = seq(0, 1, length.out = ncol(FIELD)),
    z = FIELD,
    levels = levels
  )
  expected <- Filter(function(curve) length(curve$x) >= 2L, expected)

  layer <- render_base_figure(function() contour(FIELD))$layers[[1]]

  expect_length(layer$data, length(expected))
  for (i in seq_along(expected)) {
    curve <- layer$data[[i]]
    expect_length(curve, length(expected[[i]]$x))
    expect_equal(curve[[1]]$x, expected[[i]]$x[1])
    expect_equal(curve[[1]]$y, expected[[i]]$y[1])
    expect_equal(curve[[1]]$level, expected[[i]]$level)
  }
})

test_that("every point of a curve carries its level", {
  skip_unless_jsonlite()

  # The level is not an axis: it travels on each point, which is where the
  # frontend's contour trace reads it from. Same shape the ggplot2 processor
  # emits, so the two adapters describe one chart alike.
  layer <- render_base_figure(function() contour(FIELD))$layers[[1]]

  for (curve in layer$data) {
    levels <- vapply(curve, function(point) point$level, numeric(1))
    expect_length(unique(levels), 1L)
  }
})

test_that("each curve is addressable by the element that drew it", {
  skip_unless_jsonlite()

  result <- render_base_figure(function() contour(FIELD))
  layer <- result$layers[[1]]

  # One selector per curve, or the frontend drops the layer's highlighting
  # entirely -- the precondition #145 and #204 are both about.
  expect_length(layer$selectors, length(layer$data))

  # And each one resolves: gridGraphics writes the grob into the SVG under
  # the same name, holding the polyline the curve was drawn as.
  ids <- regmatches(
    result$html,
    gregexpr('id="graphics-plot-1-contour-[0-9]+-[0-9]+\\.1"', result$html)
  )[[1]]
  expect_length(ids, length(layer$data))
})

test_that("the selectors are ordered by the curve, not lexicographically", {
  skip_unless_jsonlite()

  # A field with more than nine curves, so `-contour-10-10` exists. Sorted as
  # text it would come before `-contour-2-2` and every curve from the tenth
  # onward would highlight its neighbour's polyline. `volcano` is R's own
  # dataset and draws dozens.
  layer <- render_base_figure(
    function() contour(datasets::volcano)
  )$layers[[1]]
  expect_gt(length(layer$selectors), 10L)

  numbers <- as.integer(sub(
    "^#graphics-plot-1-contour-([0-9]+)-.*$", "\\1",
    unlist(layer$selectors)
  ))
  expect_false(is.unsorted(numbers))
})

test_that("an explicit levels argument is the one announced", {
  skip_unless_jsonlite()

  layer <- render_base_figure(
    function() contour(FIELD, levels = c(3, 6))
  )$layers[[1]]

  drawn <- sort(unique(vapply(
    layer$data, function(curve) curve[[1]]$level, numeric(1)
  )))
  expect_equal(drawn, c(3, 6))
})

test_that("the caller's own x and y are used where given", {
  skip_unless_jsonlite()

  # `contour(x, y, z)`, the three-argument form. Without reading them the
  # curves would be announced on the 0-1 default grid and every coordinate
  # would be wrong.
  layer <- render_base_figure(
    function() contour(c(10, 20, 30), c(100, 200, 300), FIELD)
  )$layers[[1]]

  xs <- unlist(lapply(layer$data, function(curve) {
    vapply(curve, function(point) point$x, numeric(1))
  }))
  expect_gte(min(xs), 10)
  expect_lte(max(xs), 30)
})

test_that("a chart drawn beside it still reads", {
  skip_unless_jsonlite()

  # The adapter's type map changed, so this pins that the change did not
  # reach the neighbouring entries -- `image` and `matplot` sit either side.
  expect_equal(
    render_base_figure(function() image(FIELD))$layers[[1]]$type,
    "heat"
  )
})

test_that("the factory claims contour again, and can dispatch it", {
  # The two have to move together: a type listed here but not dispatched is
  # what #214 was about -- the layer ships "unknown" *and* the fallback that
  # would have saved it never runs, because the type was claimed.
  factory <- BaseRProcessorFactory$new()

  expect_true("contour" %in% factory$get_supported_types())
  processor <- factory$create_processor("contour", list(index = 1))
  expect_s3_class(processor, "BaseRContourLayerProcessor")
})

test_that("a call that draws no contour is declined rather than guessed at", {
  # Not reachable through `contour()` itself, which errors on these -- this
  # is the processor's own guard, so a producer handing it something else
  # gets an empty layer rather than a fabricated curve.
  processor <- BaseRContourLayerProcessor$new(list(index = 1))

  expect_null(processor$contour_grid(list()))
  expect_null(processor$contour_grid(list(z = "not a matrix")))
  expect_null(processor$contour_grid(list(z = matrix(1, nrow = 1, ncol = 1))))
  expect_null(processor$contour_grid(list(z = matrix(NA_real_, 2, 2))))
  # An x that does not match the grid names coordinates the chart never drew.
  expect_null(processor$contour_grid(list(x = c(1, 2, 3), z = matrix(1:4, 2))))
})

test_that("a curve dropped from the payload does not cost the layer its highlighting", {
  skip_unless_jsonlite()

  # Review asked what happens if `contourLines()` ever returns a one-vertex
  # curve: the payload drops it, but gridGraphics draws from the same output
  # and would still write its grob -- so a count comparison would disagree
  # and withhold *every* selector, not just that one's.
  #
  # Measured first: it does not arise. A level the surface merely touches
  # yields no curve at all rather than a one-vertex one, and none appeared
  # across four hundred random fields. So this exercises the pairing
  # directly instead, which is what makes the mismatch impossible rather
  # than merely unobserved.
  processor <- BaseRContourLayerProcessor$new(list(index = 1))

  # Three grobs drawn, the middle curve dropped: the selectors must be the
  # first and third, not the first two.
  gt <- list(
    name = NULL,
    children = list(
      list(name = "graphics-plot-1-contour-1-1", children = NULL),
      list(name = "graphics-plot-1-contour-2-2", children = NULL),
      list(name = "graphics-plot-1-contour-3-3", children = NULL)
    )
  )

  selectors <- processor$generate_selectors(
    list(index = 1), gt, kept = c(1L, 3L), total = 3L
  )

  expect_length(selectors, 2L)
  expect_match(selectors[[1]], "contour-1-1", fixed = TRUE)
  expect_match(selectors[[2]], "contour-3-3", fixed = TRUE)
})

test_that("a tangent level yields no curve and no grob, so the counts agree", {
  # The case that would have produced a one-vertex curve if anything did.
  # Both sides answer the same way, which is why the pairing above is
  # belt-and-braces rather than a live path.
  grid <- seq(-1, 1, length.out = 5)
  bowl <- outer(grid, grid, function(a, b) a^2 + b^2)

  expect_length(
    grDevices::contourLines(x = grid, y = grid, z = bowl, levels = 0),
    0L
  )
})

test_that("the list form contour(list(x =, y =, z =)) is read", {
  skip_unless_jsonlite()

  # `contour.default` unpacks a list into its three parts, which is the shape
  # interpolation helpers hand back. Without it the call resolved to nothing
  # and the chart silently announced no data.
  processor <- BaseRContourLayerProcessor$new(list(index = 1))

  grid <- processor$contour_grid(list(list(
    x = c(1, 2, 3), y = c(10, 20, 30), z = FIELD
  )))

  expect_false(is.null(grid))
  expect_equal(grid$x, c(1, 2, 3))
  expect_equal(grid$y, c(10, 20, 30))
  expect_equal(grid$z, FIELD)
})
