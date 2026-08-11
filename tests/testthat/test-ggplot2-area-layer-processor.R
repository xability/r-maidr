# Tests for Ggplot2AreaLayerProcessor
#
# Two things about ggplot2's built data make an area layer easy to read wrong,
# and both are plausible-looking failures rather than crashes:
#
#   1. `y` is the band's cumulative top edge, not the series' own value.
#   2. `geom_area()` defaults to `stat = "align"`, whose interpolation and
#      baseline-closing vertices outnumber the data three to one.
#
# These tests are written against both, so an implementation that reads the
# built frame naively fails rather than emitting numbers that look like data.

skip_if_not_installed("ggplot2")

library(ggplot2)

#: Four years, two series. The two series' values differ at every year and no
#: value equals another's cumulative total, so a reading that took the band's
#: top edge instead of its height cannot coincide with the right answer.
area_data <- function() {
  data.frame(
    year = rep(2000:2003, 2),
    grp = rep(c("a", "b"), each = 4),
    val = c(3, 5, 4, 7, 2, 3, 6, 5)
  )
}

# Build a layer's MAIDR payload.
area_process <- function(plot) {
  processor <- maidr:::Ggplot2AreaLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  processor$process(plot, NULL, ggplot2::ggplot_build(plot))
}

# Classify a layer the way the adapter does.
area_detect <- function(plot) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[1]], plot)
}

# Pull one series' y values out of an emitted payload.
series_values <- function(result, index) {
  vapply(result$data[[index]], function(point) point$y, numeric(1))
}

# ==============================================================================
# Detection
# ==============================================================================

test_that("an area layer is detected as an area, not as a line", {
  df <- area_data()

  testthat::expect_equal(
    area_detect(ggplot(df, aes(year, val)) + geom_area()),
    "area"
  )
  testthat::expect_equal(
    area_detect(ggplot(df, aes(year, val, fill = grp)) + geom_area()),
    "area"
  )
})

test_that("a filled area is detected as normalized", {
  # `position = "fill"` rescales every column to a common height, so a band's
  # height is its share. Reading it as a plain stacked area would announce the
  # shares as values and imply the columns have equal totals -- the one thing
  # a filled chart is drawn to deny.
  df <- area_data()

  testthat::expect_equal(
    area_detect(ggplot(df, aes(year, val, fill = grp)) + geom_area(position = "fill")),
    "stacked_normalized_area"
  )
})

test_that("detection does not swallow the neighbouring geoms", {
  # GeomArea inherits GeomRibbon, which inherits GeomPath, so the branch has
  # to sit before the line branch and stay a class(...)[1] comparison. This is
  # what says that ordering did not take the other geoms with it.
  df <- area_data()

  testthat::expect_equal(area_detect(ggplot(df, aes(year, val)) + geom_line()), "line")
  testthat::expect_equal(area_detect(ggplot(df, aes(year, val)) + geom_path()), "line")
  testthat::expect_equal(area_detect(ggplot(df, aes(year, val)) + geom_step()), "step")
})

# ==============================================================================
# The alignment vertices
# ==============================================================================

test_that("the interpolation vertices stat_align inserts are not data", {
  # The trap. A four-year, two-series chart builds twenty-four rows: the eight
  # real ones, interpolation vertices at x +- 0.003, and a closing vertex on
  # the baseline at each end. Read whole, the chart announces twelve points
  # per series including a value at "year 2000.003".
  df <- area_data()
  result <- area_process(ggplot(df, aes(year, val, fill = grp)) + geom_area())

  testthat::expect_length(result$data, 2)
  for (series in result$data) {
    testthat::expect_length(series, 4)
    testthat::expect_equal(
      vapply(series, function(point) point$x, numeric(1)),
      c(2000, 2001, 2002, 2003)
    )
  }
})

test_that("filtering matches what stat = 'identity' produces", {
  # The filter is a claim about StatAlign's behaviour, so it is checked
  # against the version of the same chart that has no stat to align.
  df <- area_data()
  aligned <- area_process(ggplot(df, aes(year, val, fill = grp)) + geom_area())
  identity <- area_process(
    ggplot(df, aes(year, val, fill = grp)) + geom_area(stat = "identity")
  )

  testthat::expect_equal(aligned$data, identity$data)
})

# ==============================================================================
# The value versus the total
# ==============================================================================

test_that("a series carries its own value, not the cumulative band top", {
  # The consumer sums the series to reach the running total, so handing it a
  # cumulative number would make the totals grow with the number of series
  # rather than with the data.
  df <- area_data()
  result <- area_process(ggplot(df, aes(year, val, fill = grp)) + geom_area())

  values <- sort(c(series_values(result, 1), series_values(result, 2)))

  testthat::expect_equal(values, sort(df$val))
})

test_that("an unstacked single series is its own value too", {
  df <- subset(area_data(), grp == "a")
  result <- area_process(ggplot(df, aes(year, val)) + geom_area())

  testthat::expect_equal(series_values(result, 1), c(3, 5, 4, 7))
})

test_that("a filled area carries shares that total one per column", {
  df <- area_data()
  result <- area_process(
    ggplot(df, aes(year, val, fill = grp)) + geom_area(position = "fill")
  )

  totals <- series_values(result, 1) + series_values(result, 2)

  testthat::expect_equal(totals, rep(1, 4))
  # 3 of 5 at year 2000, which is the share the chart draws.
  testthat::expect_equal(series_values(result, 1)[1], 0.6)
})

# ==============================================================================
# Types and labels
# ==============================================================================

test_that("one series is an area and several are stacked", {
  # A single series has nothing stacked on it whatever its position, so
  # announcing a running total equal to its own value would be noise.
  df <- area_data()

  testthat::expect_equal(
    area_process(ggplot(subset(df, grp == "a"), aes(year, val)) + geom_area())$type,
    "area"
  )
  testthat::expect_equal(
    area_process(ggplot(df, aes(year, val, fill = grp)) + geom_area())$type,
    "stacked_area"
  )
})

test_that("each series is named after its fill level", {
  # Without the name a reader hears two sets of numbers with nothing to say
  # which series either belongs to.
  df <- area_data()
  result <- area_process(ggplot(df, aes(year, val, fill = grp)) + geom_area())

  testthat::expect_equal(result$data[[1]][[1]]$z, "a")
  testthat::expect_equal(result$data[[2]][[1]]$z, "b")
})

test_that("the legend title travels as the z axis", {
  df <- area_data()
  result <- area_process(ggplot(df, aes(year, val, fill = grp)) + geom_area())

  testthat::expect_equal(result$axes$z$label, "grp")
})

test_that("a chart with no fill emits no series label", {
  df <- subset(area_data(), grp == "a")
  result <- area_process(ggplot(df, aes(year, val)) + geom_area())

  testthat::expect_null(result$data[[1]][[1]]$z)
})

# ==============================================================================
# Registration
# ==============================================================================

test_that("the factory builds the area processor for all three types", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  info <- list(layer_index = 1, index = 1)

  for (type in c("area", "stacked_area", "stacked_normalized_area")) {
    testthat::expect_s3_class(
      factory$create_processor(type, info),
      "Ggplot2AreaLayerProcessor"
    )
    testthat::expect_true(type %in% factory$get_supported_types())
  }
})

test_that("a filled density curve stays a smooth, not an area", {
  # `geom_area()` is also how a filled density curve is drawn, and its rows
  # are a computed curve rather than the observations an area chart carries.
  # The stat is what tells them apart -- the same rule GeomStep follows.
  set.seed(1)
  df <- data.frame(
    y = c(stats::rnorm(30), stats::rnorm(30, 3)),
    g = rep(c("a", "b"), each = 30)
  )

  testthat::expect_equal(
    area_detect(ggplot(df, aes(y, fill = g)) + geom_area(stat = "density")),
    "smooth"
  )
})

test_that("a discrete x keeps its categories and drops the padding", {
  # A discrete axis is drawn at positions the *scale* assigns, so they cannot
  # be reconstructed from the data column -- a factor level present in one and
  # absent from the other would shift every position. What holds regardless is
  # that those positions are whole numbers and StatAlign's inserted vertices
  # are not.
  df <- data.frame(
    q = factor(rep(c("Q1", "Q2", "Q3"), 2), levels = c("Q1", "Q2", "Q3", "Q4")),
    grp = rep(c("a", "b"), each = 3),
    val = c(3, 5, 4, 2, 3, 6)
  )

  result <- area_process(ggplot(df, aes(q, val, fill = grp, group = grp)) + geom_area())

  testthat::expect_length(result$data, 2)
  for (series in result$data) {
    testthat::expect_length(series, 3)
  }
  # The unused 'Q4' level does not become a phantom column.
  testthat::expect_equal(series_values(result, 1), c(3, 5, 4))
})

test_that("a continuous x whose values cannot be read keeps every row", {
  # `source_x_values()` cannot answer for an x mapped through an expression:
  # `mapped_column()` unwraps `factor(...)` and a bare column name, and this
  # is neither. The axis is still continuous, so the whole-number rule that
  # is exact for a discrete axis would drop the fractional halves and keep
  # the integral ones -- half the chart, silently, and no way to tell from
  # the output that anything went missing.
  #
  # The documented behaviour for an unreadable axis is to keep the layer
  # whole. Noisy beats wrong: the padding vertices read as extra points, but
  # every observation is still there.
  df <- data.frame(
    year = rep(c(2000, 2001, 2002, 2003), 2),
    grp = rep(c("a", "b"), each = 4),
    val = c(3, 5, 4, 7, 2, 3, 6, 5)
  )
  plot <- ggplot(df, aes(year / 2, val, fill = grp, group = grp)) + geom_area()

  built <- ggplot2::ggplot_build(plot)
  processor <- Ggplot2AreaLayerProcessor$new(
    # `index` is the key every production site sets; a processor built with
    # anything else resolves no layer, and the assertions below would then
    # pass because nothing was found rather than because the axis is
    # unreadable.
    list(index = 1L, geom_class = "GeomArea", stat_class = "StatAlign")
  )

  testthat::expect_null(processor$source_x_values(built))

  # 2000/2 = 1000 is whole; 2001/2 = 1000.5 is not. Filtering on whole
  # numbers would keep the first and lose the second.
  layer_data <- built$data[[1]]
  kept <- processor$drop_alignment_vertices(built, layer_data)

  testthat::expect_identical(nrow(kept), nrow(layer_data))
  testthat::expect_true(any(layer_data$x != round(layer_data$x)))
})

test_that("each band gets its own selector, in series order", {
  # `geom_area` draws one `geom_ribbon.gTree` per series, each holding a
  # filled polygon -- the granularity `AreaTrace` needs, since it extends the
  # line trace and that discards a selector list whose length disagrees with
  # the data.
  df <- area_data()
  plot <- ggplot(df, aes(year, val, fill = grp, group = grp)) + geom_area()
  built <- ggplot2::ggplot_build(plot)
  gt <- ggplot2::ggplot_gtable(built)
  processor <- Ggplot2AreaLayerProcessor$new(list(index = 1L))

  selectors <- processor$generate_selectors(plot, gt, NULL, 2L)

  testthat::expect_length(selectors, 2)
  for (selector in selectors) {
    # The polygon, not the outline polyline each ribbon also draws.
    testthat::expect_match(selector, "polygon$")
    # gridSVG escapes the dots in an id, and the id is the grob's name with a
    # `.1` suffix. Read from the drawn grobs rather than guessed: the counter
    # in `GRID.polygon.N` is session-wide, so a guessed name lands on another
    # panel's marks when it lands at all.
    testthat::expect_match(selector, "^#GRID\\\\\\.polygon\\\\\\.[0-9]+\\\\\\.1 polygon$")
  }
  testthat::expect_false(identical(selectors[[1]], selectors[[2]]))
})

test_that("a mismatched band count withdraws the selectors entirely", {
  # A short or mispaired list is worse than none: the consumer cannot tell
  # one from a correct one, and a highlight on the neighbouring band tells
  # the reader the wrong thing about every value it announces.
  df <- area_data()
  plot <- ggplot(df, aes(year, val, fill = grp, group = grp)) + geom_area()
  gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(plot))
  processor <- Ggplot2AreaLayerProcessor$new(list(index = 1L))

  testthat::expect_length(processor$generate_selectors(plot, gt, NULL, 3L), 0)
  testthat::expect_length(processor$generate_selectors(plot, NULL, NULL, 2L), 0)
  testthat::expect_length(processor$generate_selectors(plot, gt, NULL, 0L), 0)
})

test_that("a sibling layer's marks are not counted as bands", {
  # The layer's own grob tree is what is walked, so a `geom_line()` drawn
  # beside the area contributes no polygon and shifts no pairing.
  df <- area_data()
  plot <- ggplot(df, aes(year, val, fill = grp, group = grp)) +
    geom_area() +
    geom_line()
  gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(plot))
  processor <- Ggplot2AreaLayerProcessor$new(list(index = 1L))

  testthat::expect_length(processor$generate_selectors(plot, gt, NULL, 2L), 2)
})

test_that("a single-series area still gets its one selector", {
  df <- data.frame(year = 2000:2003, val = c(3, 5, 4, 7))
  plot <- ggplot(df, aes(year, val)) + geom_area()
  gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(plot))
  processor <- Ggplot2AreaLayerProcessor$new(list(index = 1L))

  testthat::expect_length(processor$generate_selectors(plot, gt, NULL, 1L), 1)
})
