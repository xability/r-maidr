# `monthplot()` drew a seasonal subseries chart that nothing read (#262)
#
# It is recorded -- `save_html()` succeeds rather than reporting "No Base R
# plots detected", which #262 fixed -- but `detect_layer_type()` had no branch
# for it, so it fell through to `unknown` and the chart came out as a static
# image with "Plot contains unsupported elements".
#
# What it draws is not new. `stats::monthplot.default` runs one `lines()` call
# per cycle position over that position's own subseries, which is the shape the
# line processor already reads for `matplot`: one series each, every point
# carrying its series name as `z`. So the reading recovers the times the slot
# offsets were computed from -- the offsets are on the page and the times are
# not -- and reuses that extraction. These tests are about the subseries
# landing where the drawing put them, and about the labels, which are the part
# that is genuinely new.

monthplot_layers <- base_r_layers
monthplot_types <- base_r_layer_types

# Four years of monthly readings, rising by one each month, so a value names
# its own position: month m of year y is 12 * (y - 1) + m.
MONTHLY <- stats::ts(1:48, frequency = 12)

# Three years of quarterly readings, the other frequency `monthplot` names.
QUARTERLY <- stats::ts(1:12, frequency = 4)

series_of <- function(layer, index) {
  vapply(layer$data[[index]], function(point) point$y, numeric(1))
}

labels_of <- function(layer, index) {
  vapply(layer$data[[index]], function(point) point$x, character(1))
}

names_of <- function(layer) {
  vapply(layer$data, function(series) series[[1]]$z, character(1))
}

test_that("a subseries plot is read rather than falling back to a picture", {
  expect_equal(monthplot_types(function() monthplot(MONTHLY)), "line")
})

test_that("the call routes to the processor that recovers the times", {
  # The name the adapter types it as and the name the factory answers to have
  # to be the same string, and the registry has to list it: a type the factory
  # builds but does not claim is refused by `supports_plot_type()` before the
  # processor is ever reached (#200, #214).
  adapter <- BaseRAdapter$new()

  expect_equal(
    adapter$detect_layer_type(
      list(function_name = "monthplot", args = list())
    ),
    "subseries"
  )

  factory <- BaseRProcessorFactory$new()
  expect_true("subseries" %in% factory$get_supported_types())
  expect_s3_class(
    factory$create_processor(
      "subseries",
      list(plot_call = list(args = list()))
    ),
    "BaseRSubseriesLayerProcessor"
  )
})

test_that("each cycle position is its own series over the cycles", {
  layer <- monthplot_layers(function() monthplot(MONTHLY))[[1]]

  # Twelve months, four years each, and January's readings are months
  # 1, 13, 25 and 37 of the series -- the subseries the leftmost line draws.
  expect_length(layer$data, 12)
  expect_equal(series_of(layer, 1), c(1, 13, 25, 37))
  expect_equal(series_of(layer, 12), c(12, 24, 36, 48))
})

test_that("a point is placed at the cycle it falls in, not at the slot offset", {
  layer <- monthplot_layers(function() monthplot(MONTHLY))[[1]]

  # The drawing puts February's four readings at 1.55, 1.85, 2.15 and 2.45 --
  # its own 0.9-wide band, so that twelve subseries fit on one axis. Those
  # numbers say where the band is, not when the reading was taken, and a
  # reader given them would hear four Februaries that all happened in year 2.
  expect_equal(labels_of(layer, 2), c("1", "2", "3", "4"))
})

test_that("every point says which cycle position it belongs to", {
  # Without it the twelve lines are one undifferentiated set of 48 readings,
  # and which month a reading belongs to is the whole point of the chart.
  layer <- monthplot_layers(function() monthplot(MONTHLY))[[1]]

  expect_equal(names_of(layer), month.abb)
  expect_equal(
    vapply(layer$data[[3]], function(point) point$z, character(1)),
    rep("Mar", 4)
  )
})

test_that("a monthly series is named in a spelling that survives being read", {
  # `monthplot.ts` writes `c("J", "F", "M", "A", "M", "J", ...)`, and those
  # letters do not name twelve things: "M" is March and May, "J" is January,
  # June and July. On the axis a sighted reader recovers the month from where
  # the tick sits. A series name has no position to recover it from, so the
  # derived labels are `month.abb` -- base R's own spelling of the same twelve
  # months, and the one it uses wherever a month has room to be named.
  layer <- monthplot_layers(function() monthplot(MONTHLY))[[1]]

  expect_equal(length(unique(names_of(layer))), 12)
  expect_false(any(nchar(names_of(layer)) == 1))
})

test_that("labels the caller wrote are the ones the series carry", {
  # Theirs, ambiguous or not: the rewriting above is only ever applied to
  # labels this package derived in the first place.
  layer <- monthplot_layers(function() {
    monthplot(MONTHLY, labels = c("J", "F", "M", "A", "M", "J",
                                  "J", "A", "S", "O", "N", "D"))
  })[[1]]

  expect_equal(names_of(layer)[[3]], "M")
  expect_equal(names_of(layer)[[5]], "M")
})

test_that("a quarterly series is named the way the drawing names it", {
  layer <- monthplot_layers(function() monthplot(QUARTERLY))[[1]]

  # `Q1` through `Q4` are already four distinct names, so they are read as
  # written.
  expect_length(layer$data, 4)
  expect_equal(names_of(layer), c("Q1", "Q2", "Q3", "Q4"))
  expect_equal(series_of(layer, 1), c(1, 5, 9))
})

test_that("a series with an uneven number of cycles is not padded out", {
  # Fifty monthly readings give January and February five cycles each and the
  # other ten four. A matrix framing would pad the short ten to five and put
  # ten points on the chart that `monthplot` never drew (#170 is the same
  # claim about `geom_point`).
  layer <- monthplot_layers(function() monthplot(stats::ts(1:50, frequency = 12)))[[1]]

  expect_equal(
    vapply(layer$data, length, integer(1)),
    c(5L, 5L, rep(4L, 10))
  )
})

test_that("a plain vector is cut into cycles by its position", {
  # `monthplot.default`: no `ts` to ask, so `times` is the position in the
  # vector and the phase is that position modulo twelve.
  layer <- monthplot_layers(function() monthplot(1:24))[[1]]

  expect_length(layer$data, 12)
  expect_equal(names_of(layer), as.character(1:12))
  expect_equal(series_of(layer, 1), c(1, 13))
  expect_equal(labels_of(layer, 1), c("1", "13"))
})

test_that("a caller-supplied phase names the series after its own values", {
  # `monthplot.default` again: written `phase` and no `labels` gives the
  # phase's distinct values as the labels, in the order they first appear.
  layer <- monthplot_layers(function() {
    monthplot(1:6, phase = c("b", "a", "b", "a", "b", "a"))
  })[[1]]

  expect_equal(names_of(layer), c("b", "a"))
  expect_equal(series_of(layer, 1), c(1, 3, 5))
  expect_equal(series_of(layer, 2), c(2, 4, 6))
})

test_that("a phase past the last label is not read, because it is not drawn", {
  # `monthplot` loops `1L:f` where `f <- length(labels)`, so a third phase
  # under two labels never reaches `lines()` -- measured: base R draws two
  # lines here, not three. Reading it would announce two values the chart does
  # not contain, and naming the series after the phase's own distinct values
  # would rename the two the caller did label.
  layer <- monthplot_layers(function() {
    suppressWarnings(
      monthplot(1:6, labels = c("a", "b"), phase = c(1, 2, 3, 1, 2, 3))
    )
  })[[1]]

  expect_length(layer$data, 2)
  expect_equal(names_of(layer), c("a", "b"))
  expect_equal(series_of(layer, 1), c(1, 4))
  expect_equal(series_of(layer, 2), c(2, 5))
})

test_that("a cycle position with no observation is not given an empty series", {
  # Five monthly readings fill January through May and leave the other seven
  # months with nothing. `monthplot` calls `lines()` twelve times all the
  # same, seven of them on empty vectors, and an empty series in the payload
  # would be a month a reader could land on and hear nothing from.
  layer <- monthplot_layers(function() {
    suppressWarnings(monthplot(stats::ts(1:5, frequency = 12)))
  })[[1]]

  expect_length(layer$data, 5)
  expect_equal(names_of(layer), month.abb[1:5])
  expect_true(all(vapply(layer$data, length, integer(1)) > 0L))
})

test_that("caller-supplied times are the ones the points are announced at", {
  # `monthplot.default` derives the phase from the times, not from the
  # position: `(times - 1) %% length(labels) + 1`. With two labels that puts
  # the odd years in the first slot and the even ones in the second, which is
  # where the drawing puts them too.
  layer <- monthplot_layers(function() {
    monthplot(1:4, labels = c("odd", "even"), times = c(1990, 1991, 1992, 1993))
  })[[1]]

  expect_equal(labels_of(layer, 1), c("1991", "1993"))
  expect_equal(series_of(layer, 1), c(2, 4))
  expect_equal(labels_of(layer, 2), c("1990", "1992"))
  expect_equal(series_of(layer, 2), c(1, 3))
})

test_that("the y axis is named after the expression the caller wrote", {
  # `monthplot`'s own `ylab` default is `deparse1(substitute(x))`, so it names
  # the expression rather than the value -- recovered from the recorded call
  # text, since the wrapper stores evaluated values and a series is not its
  # name.
  layer <- monthplot_layers(function() monthplot(MONTHLY))[[1]]

  expect_equal(layer$axes$y$label, "MONTHLY")
})

test_that("an unwritten x label is left unset rather than invented", {
  # `monthplot` blanks `xlab` unless the caller passes one: the axis it writes
  # carries the cycle labels, not a quantity, so there is no name to give.
  layer <- monthplot_layers(function() monthplot(MONTHLY))[[1]]

  expect_null(layer$axes$x)
})

test_that("an explicit label wins over the deparsed default", {
  layer <- monthplot_layers(function() {
    monthplot(MONTHLY, xlab = "Month", ylab = "Readings")
  })[[1]]

  expect_equal(layer$axes$x$label, "Month")
  expect_equal(layer$axes$y$label, "Readings")
})

test_that("naming the x axis does not empty the series (#292)", {
  # `xlab` is not a formal of `monthplot.default`, so it arrives through
  # `...` and the series is left unnamed in the recorded arguments. `args$x`
  # then partial-matched `xlab`, took the label for the series, and dropped
  # every point as non-numeric -- while the chart drew normally.
  unnamed <- monthplot_layers(function() monthplot(MONTHLY))[[1]]
  named <- monthplot_layers(function() {
    monthplot(MONTHLY, xlab = "Month")
  })[[1]]

  expect_length(named$data, 12L)
  expect_equal(named$data, unnamed$data)
  expect_equal(named$axes$x$label, "Month")
})

test_that("one selector per subseries, in the order the lines were drawn", {
  # The drawing runs `for (i in 1L:f)`, so the i-th `lines` grob is the i-th
  # cycle position. Series and selectors are built in that same order, and a
  # reader on the third line is outlined on the third line.
  layer <- monthplot_layers(function() monthplot(MONTHLY))[[1]]

  expect_length(layer$selectors, length(layer$data))
  expect_true(all(grepl("lines-", layer$selectors, fixed = TRUE)))
})

test_that("the spike variant is read as the same subseries", {
  # `type = "h"` swaps the lines for verticals from each cycle position's
  # base. The marks change; the readings do not, and reading them as loose
  # values would lose the grouping that makes the chart a subseries plot.
  layer <- monthplot_layers(function() monthplot(MONTHLY, type = "h"))[[1]]

  expect_equal(series_of(layer, 1), c(1, 13, 25, 37))
  expect_equal(names_of(layer), month.abb)
})

test_that("the spike variant is outlined too, not only read", {
  # `"h"` is not handed to `lines()` the way a `type` usually is:
  # `monthplot` branches and calls `segments()`, so the grobs land under
  # `-segments-` and the inherited search for `-lines-` finds none. A layer
  # with no selectors is dropped by the frontend's
  # `selectors.length === series count` precondition, so the chart read
  # correctly and highlighted nothing at all.
  layer <- monthplot_layers(function() monthplot(MONTHLY, type = "h"))[[1]]

  expect_length(layer$selectors, length(layer$data))
  expect_true(all(grepl("segments-", unlist(layer$selectors), fixed = TRUE)))
})

test_that("the base line's own grob is not mistaken for a subseries", {
  # `monthplot` draws the `base` segments in one call *before* the loop, so
  # the first `-segments-` grob is the twelve means and the twelve after it
  # are the subseries. Counted from the first, every series would be outlined
  # on the position before it -- and January on the means.
  layer <- monthplot_layers(function() monthplot(MONTHLY, type = "h"))[[1]]

  expect_match(layer$selectors[[1]], "segments-2", fixed = TRUE)
  expect_match(layer$selectors[[12]], "segments-13", fixed = TRUE)
})

test_that("a ts with a written phase is named after the phase, not the months", {
  # The same renaming the plain-vector case gets. `monthplot.ts` hands a
  # caller-supplied `phase` straight to `monthplot.default` without labels,
  # so the month names never enter it.
  layer <- monthplot_layers(function() {
    monthplot(MONTHLY, phase = rep(c("odd", "even"), 24))
  })[[1]]

  expect_equal(names_of(layer), c("odd", "even"))
  expect_equal(series_of(layer, 1)[1:3], c(1, 3, 5))
})
