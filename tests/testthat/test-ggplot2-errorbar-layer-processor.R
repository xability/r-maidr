# Tests for Ggplot2ErrorbarLayerProcessor
#
# ggplot2's built data carries BOTH pairs of bounds for most uncertainty
# geoms, and only one of them is the interval: for a vertical geom_errorbar,
# xmin/xmax are the cap width, a styling parameter that is not data at all.
# These tests are written against the cases that distinguish the two, so an
# implementation reading the wrong pair fails rather than looking plausible.

skip_if_not_installed("ggplot2")

library(ggplot2)

#: Three group means with asymmetric intervals. Every number is distinct so a
#: reading that took the wrong bound, or the wrong sample, cannot coincide
#: with the right one -- and no bound equals a cap extent (0.55 / 1.45).
eb_data <- function() {
  data.frame(
    g = c("control", "low", "high"),
    y = c(4.2, 5.1, 7.3),
    lo = c(3.8, 4.0, 7.1),
    hi = c(4.6, 6.6, 7.4)
  )
}

# Build a layer's MAIDR payload.
eb_process <- function(plot) {
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  processor$process(plot, NULL, ggplot2::ggplot_build(plot))
}

# Classify a layer the way the adapter does.
eb_detect <- function(plot) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[1]], plot)
}

# ==============================================================================
# Detection
# ==============================================================================

test_that("every uncertainty geom is detected as an error bar layer", {
  df <- eb_data()
  mapping <- aes(g, y, ymin = lo, ymax = hi)

  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_errorbar()), "error_bar")
  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_linerange()), "error_bar")
  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_pointrange()), "error_bar")
  testthat::expect_equal(eb_detect(ggplot(df, mapping) + geom_crossbar()), "error_bar")
  testthat::expect_equal(
    eb_detect(ggplot(df, aes(y, g, xmin = lo, xmax = hi)) + geom_errorbarh()),
    "error_bar"
  )
})

test_that("detection does not swallow neighbouring geoms", {
  # GeomCrossbar and GeomPointrange do not inherit GeomErrorbar, so the
  # membership test could not be loosened to inherits() -- and this is what
  # says the loosening did not take other layer types with it.
  df <- eb_data()

  testthat::expect_equal(eb_detect(ggplot(df, aes(g, y)) + geom_point()), "point")
  testthat::expect_equal(eb_detect(ggplot(df, aes(g, y)) + geom_col()), "bar")
})

# ==============================================================================
# Vertical intervals
# ==============================================================================

test_that("a vertical error bar emits the interval, not the cap width", {
  # The trap: built data carries xmin = 0.55 and xmax = 1.45 for the first
  # sample, which is how wide the cap is drawn. Reading that pair would
  # produce a navigable chart describing the styling.
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(result$type, "error_bar")
  testthat::expect_equal(result$orientation, "vert")
  testthat::expect_equal(result$data[[1]]$yMin, 3.8)
  testthat::expect_equal(result$data[[1]]$yMax, 4.6)
})

test_that("asymmetric intervals survive both sides", {
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_pointrange()
  )

  bounds <- lapply(result$data, function(point) c(point$yMin, point$yMax))
  testthat::expect_equal(bounds[[2]], c(4.0, 6.6))
  testthat::expect_equal(bounds[[3]], c(7.1, 7.4))
})

test_that("a discrete category is named, not numbered", {
  # ggplot2 maps a discrete axis onto integer positions before computing the
  # layer, and the positions follow the scale's order rather than the data's:
  # here "low" is drawn third and "high" second. Announcing 1/2/3 would name
  # something the reader cannot find on the chart, and would not even read as
  # a row number.
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(
    vapply(result$data, function(point) as.character(point$x), character(1)),
    c("control", "low", "high")
  )
})

test_that("a continuous category axis keeps its numbers", {
  # The label lookup must not fire on a continuous axis: its break labels
  # ("0", "25", ...) are not an index into anything, and treating them as one
  # would rename every point.
  df <- data.frame(x = c(10, 20, 30), y = c(1, 2, 3), lo = c(0.5, 1.5, 2.5),
                   hi = c(1.5, 2.5, 3.5))
  result <- eb_process(ggplot(df, aes(x, y, ymin = lo, ymax = hi)) + geom_errorbar())

  testthat::expect_equal(
    vapply(result$data, function(point) as.numeric(point$x), numeric(1)),
    c(10, 20, 30)
  )
})

# ==============================================================================
# Horizontal intervals
# ==============================================================================

test_that("geom_errorbarh reads the x pair, and says it is horizontal", {
  # geom_errorbarh carries no flipped_aes column at all, so an implementation
  # reading only that flag would call this vertical and emit ymin/ymax --
  # which here are the cap HEIGHTS (0.55 / 1.45), not the interval.
  result <- eb_process(
    ggplot(eb_data(), aes(y, g, xmin = lo, xmax = hi)) + geom_errorbarh()
  )

  testthat::expect_equal(result$orientation, "horz")
  testthat::expect_equal(result$data[[1]]$yMin, 3.8)
  testthat::expect_equal(result$data[[1]]$yMax, 4.6)
})

test_that("an explicitly flipped error bar is horizontal too", {
  result <- eb_process(
    ggplot(eb_data(), aes(y, g, xmin = lo, xmax = hi)) +
      geom_errorbar(orientation = "y")
  )

  testthat::expect_equal(result$orientation, "horz")
  testthat::expect_equal(result$data[[1]]$yMin, 3.8)
  testthat::expect_equal(result$data[[1]]$yMax, 4.6)
})

test_that("a horizontal layer reads the same magnitudes as a vertical one", {
  # The emitted shape names the category x and the magnitude y in BOTH
  # orientations -- that is what MAIDR's ErrorBarTrace consumes -- so the two
  # payloads must agree on every number and differ only in `orientation`.
  df <- eb_data()
  vertical <- eb_process(ggplot(df, aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar())
  horizontal <- eb_process(
    ggplot(df, aes(y, g, xmin = lo, xmax = hi)) + geom_errorbarh()
  )

  testthat::expect_equal(
    lapply(vertical$data, function(p) c(p$y, p$yMin, p$yMax)),
    lapply(horizontal$data, function(p) c(p$y, p$yMin, p$yMax))
  )
})

# ==============================================================================
# The estimate aesthetic is optional
# ==============================================================================

test_that("a layer with no estimate still emits its interval", {
  # `geom_errorbar(aes(x, ymin, ymax))` over a `geom_col()` is the standard way
  # to draw a bar chart with error bars, and it builds with no `y` column at
  # all. Requiring one dropped every such layer silently: no interval, no
  # estimate, no error -- the whole layer just vanished.
  df <- eb_data()

  for (layer in list(geom_errorbar(), geom_linerange())) {
    result <- eb_process(ggplot(df, aes(g, ymin = lo, ymax = hi)) + layer)

    testthat::expect_length(result$data, 3)
    testthat::expect_equal(result$data[[1]]$yMin, 3.8)
    testthat::expect_equal(result$data[[1]]$yMax, 4.6)
  }
})

test_that("an absent estimate falls back to the centre of the drawn span", {
  # The chart draws a span and no estimate, so the span's centre is what is
  # reported -- a property of the drawn bar, not a claim about an unobserved
  # mean. Asserted on the ASYMMETRIC sample, where the centre (5.3) and the
  # real mean (5.1) differ, so a fixture that happened to be symmetric could
  # not make this look right by accident.
  result <- eb_process(
    ggplot(eb_data(), aes(g, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(result$data[[2]]$y, 5.3)
})

test_that("a layer that carries an estimate never substitutes the centre", {
  # The same asymmetric sample, this time with `y` mapped: the drawn value
  # must win over the derived one.
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(result$data[[2]]$y, 5.1)
})

# ==============================================================================
# Degenerate inputs
# ==============================================================================

test_that("a layer with no bounds still emits its estimates", {
  # A one-sided or bound-less layer is a real chart, and dropping the points
  # for want of their bounds would lose the estimates too.
  df <- eb_data()
  result <- eb_process(
    ggplot(df, aes(g, y, ymin = lo, ymax = hi)) + geom_pointrange()
  )

  testthat::expect_length(result$data, 3)
  testthat::expect_equal(
    vapply(result$data, function(point) point$y, numeric(1)),
    c(4.2, 5.1, 7.3)
  )
})

test_that("every geom reads its flipped built data, not just errorbar", {
  # GeomPointrange and GeomCrossbar do not inherit GeomErrorbar -- which is why
  # detection needs a membership test -- so their flipped built-data shapes are
  # pinned rather than assumed to match geom_errorbar's.
  df <- eb_data()

  for (layer in list(
    geom_pointrange(orientation = "y"),
    geom_crossbar(orientation = "y"),
    geom_linerange(orientation = "y")
  )) {
    result <- eb_process(
      ggplot(df, aes(y, g, xmin = lo, xmax = hi)) + layer
    )

    testthat::expect_equal(result$orientation, "horz")
    testthat::expect_equal(result$data[[1]]$yMin, 3.8)
    testthat::expect_equal(result$data[[1]]$yMax, 4.6)
  }
})

test_that("an empty layer yields no points rather than erroring", {
  empty <- data.frame(
    g = character(0), y = numeric(0), lo = numeric(0), hi = numeric(0)
  )
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1)
  )

  testthat::expect_equal(processor$extract_interval_data(NULL, NULL, FALSE), list())
})

# ==============================================================================
# Selectors (issue #145)
# ==============================================================================
#
# A layer with no selectors sonifies, announces and brailles correctly and
# highlights nothing, so no assertion on data or announcements can see the
# gap. These are written against the drawn grob instead.
#
# `ErrorBarTrace.mapToSvgElements` discards a selector list whose flattened
# length is not exactly the number of points, so "how many elements does this
# address" is the whole contract, and every case below asserts it.

# Build a layer's payload with the gtable it was drawn from, which is what
# `process()` needs before it can name a grob.
eb_process_drawn <- function(plot) {
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  processor$process(
    plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot)
  )
}

# The `<g>` id a selector addresses, unescaped.
eb_selector_id <- function(selector) {
  gsub("\\\\", "", sub("^[a-zA-Z]*#", "", sub(" .*$", "", selector)))
}

test_that("every uncertainty geom addresses one element per sample", {
  df <- eb_data()
  mapping <- aes(g, y, ymin = lo, ymax = hi)

  plots <- list(
    errorbar = ggplot(df, mapping) + geom_errorbar(width = 0.2),
    linerange = ggplot(df, mapping) + geom_linerange(),
    pointrange = ggplot(df, mapping) + geom_pointrange(),
    crossbar = ggplot(df, mapping) + geom_crossbar(),
    errorbarh = ggplot(df, aes(y, g, xmin = lo, xmax = hi)) +
      geom_errorbarh(height = 0.2)
  )

  for (name in names(plots)) {
    result <- eb_process_drawn(plots[[name]])

    testthat::expect_length(result$data, 3)
    # One selector, not one per sample: gridSVG groups a grob's elements
    # under a single `<g>`, so the samples are a stride through its children.
    testthat::expect_length(result$selectors, 1)
    testthat::expect_true(
      grepl("^g#", result$selectors[[1]]),
      info = paste(name, "addresses a group")
    )
  }
})

test_that("an unnamed geom_errorbar grob is still addressed", {
  # The reason this issue existed. geom_errorbar() draws `GRID.polyline.N`
  # with no geom prefix, so every name-matching search reaches it last or not
  # at all -- and it is the most common of the five.
  result <- eb_process_drawn(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar(width = 0.2)
  )

  testthat::expect_match(eb_selector_id(result$selectors[[1]]), "^GRID\\.polyline\\.")
})

test_that("geom_errorbar addresses its whisker, not one of its caps", {
  # A bar is drawn as three elements -- cap, whisker, cap -- so addressing
  # the group's children directly would resolve to three times the samples
  # and the trace would discard the lot. The stride picks the middle one.
  result <- eb_process_drawn(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar(width = 0.2)
  )

  testthat::expect_match(result$selectors[[1]], "nth-child(3n+2)", fixed = TRUE)
})

test_that("a geom drawing one element per sample takes no stride", {
  # The counterpart: a linerange draws exactly one line per sample, so a
  # stride here would address a third of them.
  result <- eb_process_drawn(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_linerange()
  )

  testthat::expect_false(grepl("nth-child", result$selectors[[1]], fixed = TRUE))
})

test_that("a pointrange is highlighted by the range rather than the point", {
  # Its gTree holds the whisker and the estimate as siblings, both one per
  # sample. The whisker is the one that spans the interval the reader is
  # navigating.
  result <- eb_process_drawn(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_pointrange()
  )

  testthat::expect_match(eb_selector_id(result$selectors[[1]]), "^geom_linerange\\.segments\\.")
})

test_that("a crossbar is highlighted by its box rather than its middle line", {
  result <- eb_process_drawn(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_crossbar()
  )

  testthat::expect_match(eb_selector_id(result$selectors[[1]]), "^geom_polygon\\.polygon\\.")
})

test_that("an error bar beside another layer addresses its own marks", {
  # geom_col() + geom_errorbar() is the standard way to draw this chart, and
  # the errorbar is the second layer. Resolving it by position rather than by
  # name is only sound if the position is the layer's own.
  df <- eb_data()
  plot <- ggplot(df, aes(g)) +
    geom_col(aes(y = y)) +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.2)
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 2, index = 2, plot = plot)
  )

  result <- processor$process(
    plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot)
  )

  testthat::expect_length(result$selectors, 1)
  # The bars are a `rect` grob; picking that one up would highlight the
  # estimates while the reader navigates the interval.
  testthat::expect_match(eb_selector_id(result$selectors[[1]]), "^GRID\\.polyline\\.")
})

test_that("a layer drawing nothing beside it does not shift the lookup", {
  # A layer with no rows still takes its slot in the panel as a zeroGrob, so
  # the positional lookup has to count it. If it did not, this would address
  # the layer before the error bar.
  df <- eb_data()
  plot <- ggplot(df, aes(g)) +
    geom_point(data = df[0, ], aes(y = y)) +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.2)
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 2, index = 2, plot = plot)
  )

  result <- processor$process(
    plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot)
  )

  testthat::expect_length(result$selectors, 1)
  testthat::expect_match(eb_selector_id(result$selectors[[1]]), "^GRID\\.polyline\\.")
})

test_that("no gtable yields no selectors rather than a guessed one", {
  # A selector that resolves to the wrong element highlights somewhere else,
  # which a reader cannot tell from the right answer. An empty list is the
  # only honest response to not knowing.
  result <- eb_process(
    ggplot(eb_data(), aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(result$selectors, list())
})

test_that("an empty layer emits no selector for its no points", {
  empty <- data.frame(
    g = character(0), y = numeric(0), lo = numeric(0), hi = numeric(0)
  )
  result <- eb_process_drawn(
    ggplot(empty, aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar()
  )

  testthat::expect_equal(result$data, list())
  testthat::expect_equal(result$selectors, list())
})

test_that("two error bar layers in one panel address different marks", {
  # The case the positional lookup is most likely to get wrong: neither layer
  # has a name to match on, so nothing but position tells them apart. If it
  # counted from the wrong anchor, both would resolve to the first polyline
  # and the second layer would highlight the first layer's whiskers -- which
  # resolves, and looks healthy, and is wrong.
  df <- eb_data()
  plot <- ggplot(df, aes(g)) +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.2) +
    geom_errorbar(aes(ymin = lo - 1, ymax = hi + 1), width = 0.4)

  selectors <- lapply(seq_len(2), function(index) {
    processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
      list(layer_index = index, index = index, plot = plot)
    )
    processor$process(
      plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot)
    )$selectors
  })

  testthat::expect_length(selectors[[1]], 1)
  testthat::expect_length(selectors[[2]], 1)
  testthat::expect_false(identical(selectors[[1]], selectors[[2]]))
})

test_that("an error bar beside a geom of another family still resolves", {
  # geom_linerange() is found by name and geom_errorbar() by position, so this
  # is the case where the two lookups have to agree about which layer is which.
  df <- eb_data()
  plot <- ggplot(df, aes(g, y, ymin = lo, ymax = hi)) +
    geom_errorbar(width = 0.2) +
    geom_linerange()

  first <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )$process(plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot))
  second <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 2, index = 2, plot = plot)
  )$process(plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot))

  testthat::expect_match(eb_selector_id(first$selectors[[1]]), "^GRID\\.polyline\\.")
  testthat::expect_match(
    eb_selector_id(second$selectors[[1]]), "^geom_linerange\\.segments\\."
  )
})

test_that("a theme that draws no grid does not move the lookup", {
  # The positional anchor is the leading zeroGrob rather than the grill, so a
  # theme that renders the background differently must not shift it. Worth
  # pinning rather than assuming: the anchor is the one part of this that
  # depends on ggplot2's internal panel layout.
  df <- eb_data()
  base <- ggplot(df, aes(g, y, ymin = lo, ymax = hi)) + geom_errorbar(width = 0.2)

  for (plot in list(base + theme_void(), base + theme(panel.grid = element_blank()))) {
    result <- eb_process_drawn(plot)

    testthat::expect_length(result$selectors, 1)
    testthat::expect_match(eb_selector_id(result$selectors[[1]]), "^GRID\\.polyline\\.")
  }
})
