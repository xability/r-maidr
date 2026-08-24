# A base R filled contour fell back to a picture (#251).
#
# `filled.contour()` was one of the eight #216 put in HIGH so that a recorded
# call would stop failing the save, but it had no branch in
# `detect_layer_type()` and no processor, so the figure took the static-image
# path.
#
# **It is read as the contour it is.** `filled.contour` draws the same level
# curves `contour()` draws and fills the bands between them, so both spellings
# of one chart get one reading, and the curves come from
# `grDevices::contourLines()` -- the computation the drawing itself runs --
# rather than from anything inferred about the fill.
#
# Two things differ from `contour()`, and only two.
#
# **The level default is twice as large.** `contour.default` takes
# `nlevels = 10` and `filled.contour` takes `nlevels = 20`, and that number
# decides the whole announced set through `pretty(zlim, nlevels)`. Everything
# else about resolving the call is identical in the two functions -- the
# `(x, y, z, ...)` slots, the `if (missing(z)) z <- x` fallback, the
# `list(x =, y =, z =)` unpacking, the `zlim` default -- so the number is the
# only thing this class overrides.
#
# **The chart cannot be highlighted.** `contour()` writes one `lines` grob per
# curve, which is what the selectors pair against. `filled.contour` writes one
# `polygon` grob for the whole field. Measured on the 6x5 grid below at the 17
# default levels:
#
#     grobs written    graphics-plot-2-filled-contour-1     (one)
#     SVG polygons     graphics-plot-2-filled-contour-1.1.1 .. .1.160
#     curves announced 40
#
# 160 pieces against 40 curves and against 17 levels: the polygons are the
# grid's cells cut by the level crossings, not the bands and not the curves.
# Nothing pairs, so nothing is emitted -- and the inherited
# `generate_selectors()` reaches that answer on its own, because it finds no
# `-contour-N-N` grob and its count check fails. A layer with no selectors is
# announced, sonified and navigated; only the visual highlight is missing, and
# that is the established degradation here (#89) rather than a reason to ship
# a picture.
#
# The field is also drawn in the **second** plot region -- the call lays out a
# colour key as `graphics-plot-1` -- which nothing here depends on, because
# nothing here addresses a grob, but a later attempt to highlight this chart
# will.
#
# py-maidr declines the equivalent call, and its recorded reason does not
# apply: it is that `contourf` hands back the filled paths and "an outline of
# one runs along two different level curves", which is about deriving curves
# from what was drawn. R hands over `contourLines()`, so the curves announced
# here are the level curves themselves, each of them on the page as the
# boundary between two bands.

# `base_r_layers` lives in `helper.R` (#241).
filled_layers <- base_r_layers

#' A radially symmetric field: every level curve is a closed ring.
FIELD <- outer(
  seq(-2, 2, length.out = 6),
  seq(-2, 2, length.out = 5),
  function(a, b) a^2 + b^2
)

#' The layers a recorded `filled.contour()` argument list produces
processed <- function(args) {
  info <- list(plot_call = list(args = args), group_index = 1)
  BaseRFilledContourLayerProcessor$new(info)$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, info
  )
}

#' Every level a layer announced, in order and without repeats
announced_levels <- function(layer) {
  unique(vapply(layer$data, function(curve) curve[[1]]$level, 0))
}

test_that("a filled contour is read rather than pictured", {
  layers <- filled_layers(function() filled.contour(FIELD))

  expect_equal(length(layers), 1)
  expect_equal(layers[[1]]$type, "contour")
})

test_that("the curves are the ones contourLines draws at those levels", {
  # Not a resemblance: the same call, so a change in either moves both.
  layer <- processed(list(FIELD))
  expected <- grDevices::contourLines(
    seq(0, 1, length.out = 6),
    seq(0, 1, length.out = 5),
    FIELD,
    levels = pretty(range(FIELD, finite = TRUE), 20)
  )

  expect_equal(length(layer$data), length(expected))
  expect_equal(layer$data[[1]][[1]]$x, expected[[1]]$x[1])
  expect_equal(layer$data[[1]][[1]]$y, expected[[1]]$y[1])
})

test_that("it defaults to twice as many levels as contour does", {
  # The single number that separates the two readings. `contour()` on the
  # same field announces the 10-level set and this the 20-level one.
  filled <- announced_levels(processed(list(FIELD)))
  plain <- BaseRContourLayerProcessor$new(
    list(plot_call = list(args = list(FIELD)), group_index = 1)
  )$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            list(plot_call = list(args = list(FIELD)), group_index = 1))

  expect_gt(length(filled), length(announced_levels(plain)))
  expect_equal(filled, pretty(range(FIELD, finite = TRUE), 20)[-1])
})

test_that("an explicit nlevels wins over the default", {
  levels <- announced_levels(processed(list(FIELD, nlevels = 4)))

  expect_equal(levels, setdiff(pretty(range(FIELD, finite = TRUE), 4), 0))
})

test_that("explicit levels are announced as given", {
  layer <- processed(list(FIELD, levels = c(0, 2, 4, 8)))

  # 0 is the field's minimum, so no curve crosses it.
  expect_equal(announced_levels(layer), c(2, 4, 8))
})

test_that("the caller's own grid is used, not the 0-1 default", {
  layer <- processed(list(1:6 * 10, 1:5 * 100, FIELD))

  expect_gt(layer$data[[1]][[1]]$x, 1)
  expect_gt(layer$data[[1]][[1]]$y, 1)
})

test_that("a matrix handed positionally is the field, not the x axis", {
  # `filled.contour`'s own `if (missing(z)) { z <- x; x <- NULL }`, which is
  # what makes `filled.contour(m)` a contour *of* m.
  expect_equal(
    length(processed(list(FIELD))$data),
    length(processed(list(z = FIELD))$data)
  )
})

test_that("no selector is emitted, because nothing pairs with a curve", {
  # Measured: one polygon grob holding 160 pieces, against 40 curves. The
  # inherited selector code reaches this on its own -- there is no
  # `-contour-N-N` grob for it to find -- so a filled contour is read and
  # navigated without a highlight rather than fabricating one.
  layers <- filled_layers(function() filled.contour(FIELD))

  expect_equal(length(layers[[1]]$selectors), 0)
})

test_that("the title and axis names reach the layer", {
  # `filled.contour` forwards its `...` to `title()`, so a caller writing
  # `main`/`xlab`/`ylab` is writing them where the inherited helpers already
  # look.
  layers <- filled_layers(function() {
    filled.contour(FIELD, xlab = "Easting", ylab = "Northing", main = "Field")
  })

  expect_equal(layers[[1]]$title, "Field")
  expect_equal(layers[[1]]$axes$x$label, "Easting")
  expect_equal(layers[[1]]$axes$y$label, "Northing")
})

test_that("a field with nothing to contour is declined rather than emptied", {
  # One row cannot be interpolated between, and `filled.contour` errors on it
  # too, so the layer would be an empty one in a chart that never drew.
  expect_equal(length(processed(list(matrix(1:3, nrow = 1)))$data), 0)
})

test_that("a call carrying no field at all is declined", {
  expect_equal(length(processed(list())$data), 0)
  expect_equal(length(processed(list(c(1, 2, 3)))$data), 0)
})

test_that("the factory knows the type and the adapter routes to it", {
  factory <- BaseRProcessorFactory$new()

  expect_true("filled_contour" %in% factory$get_supported_types())
  expect_s3_class(
    factory$create_processor("filled_contour", list(plot_call = list(args = list()))),
    "BaseRFilledContourLayerProcessor"
  )
})
