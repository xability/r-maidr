# Tests for grouped uncertainty layers (#183)
#
# A dodged interval chart puts one whip per group at every category. Without
# the split every category is announced twice with nothing saying which
# reading belongs to which group, so the comparison the figure exists to
# support -- whether two groups' intervals overlap -- is the one thing a
# reader cannot make. Every value is correct throughout, which is what makes
# the reading sound complete.
#
# Both halves have to move together. The payload runs series by series while
# the chart draws row by row, so a grouped layer names each mark by the id
# gridSVG gave it instead of striding over all of them in drawn order.
#
# Measured on ggplot2 3.4.4 with gridSVG. The drawn marks for the frame
# below, read off the exported SVG:
#
#   GRID.polyline.1.1.1b  stroke rgb(248,118,109)   <- group p, category a
#   GRID.polyline.1.1.2b  stroke rgb(0,191,196)     <- group q, category a
#   GRID.polyline.1.1.3b  stroke rgb(248,118,109)   <- group p, category b
#   ...
#
# so the drawn order interleaves the groups and the series order does not:
# 1, 3, 5 then 2, 4, 6.

skip_if_not_installed("ggplot2")

library(ggplot2)

#: Three categories over two groups, dodged. Every number is distinct, so a
#: reading that took the wrong group's interval cannot coincide with the
#: right one.
eg_data <- function() {
  data.frame(
    g = rep(c("a", "b", "c"), each = 2),
    grp = rep(c("p", "q"), 3),
    y = c(2, 3, 4, 5, 3, 6),
    lo = c(1.5, 2.4, 3.2, 4.1, 2.7, 5.2),
    hi = c(2.9, 3.6, 5.5, 6.0, 3.2, 6.9)
  )
}

eg_plot <- function(df = eg_data(), geom = geom_errorbar, mapping = NULL) {
  base <- mapping %||% aes(g, y, colour = grp)
  ggplot(df, base) +
    geom(aes(ymin = lo, ymax = hi), position = position_dodge(width = 0.5))
}

# Build a layer's payload, with the drawn gtable so selectors resolve.
eg_process <- function(plot) {
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  processor$process(
    plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot)
  )
}

# Every point of the payload, series by series.
eg_flat <- function(data) {
  if (length(data) == 0 || !is.null(data[[1]]$x)) {
    return(data)
  }
  unlist(data, recursive = FALSE)
}

# The trailing sample id of each emitted selector, in the order emitted.
eg_sample_ids <- function(selectors) {
  vapply(selectors, function(s) sub(".*\\\\\\.1\\\\\\.", "", s), character(1),
         USE.NAMES = FALSE)
}

# ==============================================================================
# The split
# ==============================================================================

test_that("a dodged error bar emits one series per group", {
  out <- eg_process(eg_plot())

  testthat::expect_length(out$data, 2)
  testthat::expect_length(out$data[[1]], 3)
  testthat::expect_length(out$data[[2]], 3)
})

test_that("every point says which group it belongs to", {
  out <- eg_process(eg_plot())

  testthat::expect_equal(
    vapply(eg_flat(out$data), function(p) p$z, character(1)),
    c("p", "p", "p", "q", "q", "q")
  )
})

test_that("every value stays with its own category and group", {
  out <- eg_process(eg_plot())

  testthat::expect_equal(out$data[[1]], list(
    list(x = "a", y = 2, yMin = 1.5, yMax = 2.9, z = "p"),
    list(x = "b", y = 4, yMin = 3.2, yMax = 5.5, z = "p"),
    list(x = "c", y = 3, yMin = 2.7, yMax = 3.2, z = "p")
  ))
  testthat::expect_equal(out$data[[2]], list(
    list(x = "a", y = 3, yMin = 2.4, yMax = 3.6, z = "q"),
    list(x = "b", y = 5, yMin = 4.1, yMax = 6.0, z = "q"),
    list(x = "c", y = 6, yMin = 5.2, yMax = 6.9, z = "q")
  ))
})

test_that("the series axis is named after the legend", {
  out <- eg_process(eg_plot())

  testthat::expect_equal(out$axes$z$label, "grp")
})

test_that("geom_pointrange splits the same way", {
  out <- eg_process(eg_plot(geom = geom_pointrange))

  testthat::expect_length(out$data, 2)
  testthat::expect_equal(
    vapply(eg_flat(out$data), function(p) p$z, character(1)),
    c("p", "p", "p", "q", "q", "q")
  )
})

test_that("a horizontal grouped layer splits on the same aesthetic", {
  df <- eg_data()
  out <- eg_process(
    ggplot(df, aes(y, g, colour = grp)) +
      geom_errorbarh(aes(xmin = lo, xmax = hi),
                     position = position_dodge(width = 0.5))
  )

  testthat::expect_length(out$data, 2)
  testthat::expect_equal(out$orientation, "horz")
  # The interval is still emitted in yMin/yMax; `orientation` says where it
  # is drawn. Reading the y pair here would emit the cap extents.
  testthat::expect_equal(out$data[[1]][[1]]$yMin, 1.5)
  testthat::expect_equal(out$data[[1]][[1]]$yMax, 2.9)
})

# ==============================================================================
# What is not a grouping
# ==============================================================================

test_that("an ungrouped chart keeps the flat shape", {
  df <- data.frame(g = c("a", "b", "c"), y = c(2, 4, 3),
                   lo = c(1.5, 3.2, 2.7), hi = c(2.9, 5.5, 3.2))
  out <- eg_process(ggplot(df, aes(g, y)) + geom_errorbar(aes(ymin = lo, ymax = hi)))

  testthat::expect_length(out$data, 3)
  testthat::expect_equal(out$data[[1]]$x, "a")
  testthat::expect_null(out$data[[1]]$z)
  testthat::expect_null(out$axes$z)
})

test_that("one group is not a grouping", {
  # A mapped aesthetic with a single level draws one undivided series, and
  # wrapping it in a series of series would announce a group name that tells
  # a reader nothing.
  df <- data.frame(g = c("a", "b", "c"), grp = "only", y = c(2, 4, 3),
                   lo = c(1.5, 3.2, 2.7), hi = c(2.9, 5.5, 3.2))
  out <- eg_process(
    ggplot(df, aes(g, y, colour = grp)) + geom_errorbar(aes(ymin = lo, ymax = hi))
  )

  testthat::expect_length(out$data, 3)
  testthat::expect_null(out$data[[1]]$z)
})

test_that("a stat that aggregates rows declines the split", {
  # `stat_summary()` computes one interval per (category, group) cell, so a
  # frame with several observations per cell stops being a row-per-row
  # lookup. Pairing them anyway would put somebody else's name on a reading;
  # the flat shape is the honest fallback.
  df <- do.call(rbind, replicate(3, eg_data(), simplify = FALSE))
  df$y <- df$y + seq_len(nrow(df)) / 10
  out <- suppressWarnings(eg_process(
    ggplot(df, aes(g, y, colour = grp)) +
      stat_summary(fun.data = mean_se, geom = "errorbar")
  ))

  testthat::expect_null(eg_flat(out$data)[[1]]$z)
})

test_that("a stat that reorders rows declines the split", {
  # `stat_summary()` emits one row per (category, group) cell in ggplot2's
  # own group order, which is not the frame's when the frame is written
  # group by group. The counts still agree -- six rows either way -- so only
  # the pairing itself can say the rows do not correspond.
  df <- eg_data()
  df <- df[order(df$grp), ]
  out <- suppressWarnings(eg_process(
    ggplot(df, aes(g, y, colour = grp)) +
      stat_summary(fun.data = mean_se, geom = "errorbar")
  ))

  testthat::expect_null(eg_flat(out$data)[[1]]$z)
})

test_that("a frame whose names contradict the drawn groups declines", {
  # The count test can be satisfied by coincidence. What cannot is a drawn
  # colour carrying two different names: that says the rows do not
  # correspond, whatever their counts say.
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = eg_plot())
  )
  layer_data <- data.frame(colour = c("#A", "#A", "#B", "#B"))

  testthat::expect_true(
    processor$group_values_agree(layer_data, c("colour", "color"),
                                 c("p", "p", "q", "q"))
  )
  testthat::expect_false(
    processor$group_values_agree(layer_data, c("colour", "color"),
                                 c("p", "q", "p", "q"))
  )
})

test_that("a faceted layer takes the frame's matching slice", {
  # The frame lines up with the WHOLE layer, not with one panel's rows, so a
  # facet would decline the split if the slice were not taken with it.
  df <- eg_data()
  plot <- eg_plot(df) + facet_wrap(~g)
  processor <- maidr:::Ggplot2ErrorbarLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  out <- processor$process(
    plot, NULL, ggplot2::ggplot_build(plot), ggplot2::ggplotGrob(plot),
    panel_id = 1
  )

  testthat::expect_length(out$data, 2)
  testthat::expect_equal(out$data[[1]][[1]]$z, "p")
  testthat::expect_equal(out$data[[2]][[1]]$z, "q")
})

# ==============================================================================
# The highlight half
# ==============================================================================

test_that("a grouped layer names one mark per sample, in series order", {
  out <- eg_process(eg_plot())

  testthat::expect_length(out$selectors, 6)
  # The drawn order interleaves the groups; the payload does not. 1,3,5 are
  # group p's whips and 2,4,6 are group q's, measured off the exported SVG.
  testthat::expect_equal(
    eg_sample_ids(unlist(out$selectors)),
    c("1b", "3b", "5b", "2b", "4b", "6b")
  )
})

test_that("every grouped selector addresses a mark by id", {
  out <- eg_process(eg_plot())

  # An id cannot be disturbed by resolving another selector. A positional
  # list would be: resolving one inserts a hidden clone beside the match and
  # shifts every later nth-child (xability/maidr#1004).
  testthat::expect_true(all(startsWith(unlist(out$selectors), "#")))
  testthat::expect_false(any(grepl("nth-child", unlist(out$selectors), fixed = TRUE)))
})

test_that("a grouped pointrange names its whisker without a sub-element suffix", {
  # geom_pointrange draws one segment per sample, so the id carries no
  # a/b/c suffix -- that only appears where geom_errorbar draws a cap, the
  # whisker and the other cap as three sub-polylines.
  out <- eg_process(eg_plot(geom = geom_pointrange))

  testthat::expect_equal(
    eg_sample_ids(unlist(out$selectors)),
    c("1", "3", "5", "2", "4", "6")
  )
})

test_that("an ungrouped layer keeps the stride selector", {
  df <- data.frame(g = c("a", "b", "c"), y = c(2, 4, 3),
                   lo = c(1.5, 3.2, 2.7), hi = c(2.9, 5.5, 3.2))
  out <- eg_process(ggplot(df, aes(g, y)) + geom_errorbar(aes(ymin = lo, ymax = hi)))

  testthat::expect_length(out$selectors, 1)
  testthat::expect_true(grepl("nth-child(3n+2)", out$selectors[[1]], fixed = TRUE))
})
