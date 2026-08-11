# A grob lookup that comes up empty must emit NO selector (issue #83).
#
# Histogram, stacked bar, dodged bar and smooth used to invent an id here
# instead of returning `list()` the way bar, point, boxplot, line, heatmap
# and candlestick do. Every id these processors address carries grid's
# session-wide grob counter (`geom_rect.rect.N`, `GRID.polyline.N`), so a
# guessed N is right only by coincidence - and the coincidence is the bad
# case, not the good one: in the composition below the smooth fallback
# produced a selector byte-identical to the FIRST panel's, so the empty
# panel highlighted another panel's fitted line while the payload still
# looked healthy.
#
# `facet_wrap(~g, drop = FALSE)` over a factor with an unused level is the
# reachable input: ggplot2 lays out a third panel and draws nothing in it,
# so the panel grob resolves but holds no marks.

skip_if_no_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

# Two populated facet levels plus an empty third.
drop_false_data <- function() {
  data.frame(
    x = c("A", "B", "A", "B"),
    y = c(10, 20, 30, 40),
    fill = c("u", "v", "u", "v"),
    g = factor(c("p", "p", "q", "q"), levels = c("p", "q", "r"))
  )
}

smooth_drop_false_data <- function() {
  data.frame(
    x = rep(1:20, 2),
    y = c((1:20) * 1.1, (1:20) * 0.7),
    g = factor(rep(c("p", "q"), each = 20), levels = c("p", "q", "r"))
  )
}

# The gtable a processor inspects is the one `create_enhanced_svg()` later
# draws, so build it the same way the orchestrator does.
#
# An empty facet level makes ggplot2 take min()/max() of nothing while it
# lays the panel out, so the build is deliberately noisy here.
panel_selectors <- function(processor, plot) {
  gt <- suppressWarnings(ggplot2::ggplot_gtable(ggplot2::ggplot_build(plot)))
  panel_names <- grep("^panel-", gt$layout$name, value = TRUE)
  testthat::expect_gte(length(panel_names), 3)

  found <- lapply(panel_names, function(name) {
    unlist(
      processor$generate_selectors(
        plot, gt,
        panel_ctx = list(panel_name = name, layer_index = 1)
      ),
      use.names = FALSE
    )
  })
  names(found) <- panel_names
  found
}

# Exactly the panels that drew marks get a selector, the empty one gets
# none, and no two panels are handed the same selector.
expect_empty_panel_unselected <- function(selectors) {
  drawn <- Filter(function(s) length(s) > 0, selectors)
  empty <- Filter(function(s) length(s) == 0, selectors)

  testthat::expect_length(empty, 1)
  testthat::expect_length(drawn, length(selectors) - 1)
  flat <- unlist(drawn, use.names = FALSE)
  testthat::expect_length(unique(flat), length(flat))
}

test_that("histogram emits no selector for a facet level that drew no bins", {
  skip_if_no_ggplot2()

  d <- data.frame(
    x = c(1, 2, 3, 4, 5, 6),
    g = factor(c("p", "p", "p", "q", "q", "q"), levels = c("p", "q", "r"))
  )
  plot <- ggplot2::ggplot(d, ggplot2::aes(x = x)) +
    ggplot2::geom_histogram(bins = 5) +
    ggplot2::facet_wrap(~g, drop = FALSE)

  processor <- maidr:::Ggplot2HistogramLayerProcessor$new(list(index = 1))
  expect_empty_panel_unselected(panel_selectors(processor, plot))
})

test_that("stacked bar emits no selector for a facet level that drew no rects", {
  skip_if_no_ggplot2()

  plot <- ggplot2::ggplot(
    drop_false_data(),
    ggplot2::aes(x = x, y = y, fill = fill)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "stack") +
    ggplot2::facet_wrap(~g, drop = FALSE)

  processor <- maidr:::Ggplot2StackedBarProcessor$new(list(index = 1))
  expect_empty_panel_unselected(panel_selectors(processor, plot))
})

test_that("dodged bar emits no selector for a facet level that drew no rects", {
  skip_if_no_ggplot2()

  plot <- ggplot2::ggplot(
    drop_false_data(),
    ggplot2::aes(x = x, y = y, fill = fill)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "dodge") +
    ggplot2::facet_wrap(~g, drop = FALSE)

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))
  expect_empty_panel_unselected(panel_selectors(processor, plot))
})

test_that("smooth emits no selector for a facet level that drew no line", {
  skip_if_no_ggplot2()

  plot <- ggplot2::ggplot(
    smooth_drop_false_data(),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_smooth(method = "loess", se = FALSE, formula = y ~ x) +
    ggplot2::facet_wrap(~g, drop = FALSE)

  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(list(index = 1))
  expect_empty_panel_unselected(panel_selectors(processor, plot))
})

test_that("pie emits no selector for a facet level that drew no wedges", {
  skip_if_no_ggplot2()

  # A pie addresses `geom_rect.polygon.N` rather than `geom_rect.rect.N`, but
  # the id carries the same session-wide grob counter, so the same guess would
  # be just as wrong.
  plot <- ggplot2::ggplot(
    drop_false_data(),
    ggplot2::aes(x = "", y = y, fill = fill)
  ) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y") +
    ggplot2::facet_wrap(~g, drop = FALSE)

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  expect_empty_panel_unselected(panel_selectors(processor, plot))
})

test_that("dodged bar emits no selector when the panel cannot be resolved", {
  skip_if_no_ggplot2()

  # A flat gtable names its single cell "panel", so no `panel-<n>` cell
  # matches and `find_gtable_panel_grob()` returns NULL. Pointing the layer
  # at the layer INDEX instead would emit a plausible-looking id for a grob
  # that was never drawn.
  plot <- ggplot2::ggplot(
    drop_false_data(),
    ggplot2::aes(x = x, y = y, fill = fill)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "dodge")
  gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(plot))
  testthat::expect_length(grep("^panel-", gt$layout$name), 0)

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))
  selectors <- processor$generate_selectors(
    plot, gt,
    panel_ctx = list(panel_name = "panel-9-9", panel_index = 99, layer_index = 1)
  )

  testthat::expect_type(selectors, "list")
  testthat::expect_length(selectors, 0)
})

test_that("histogram and stacked bar emit no selector for a zero-row layer", {
  skip_if_no_ggplot2()

  empty <- drop_false_data()[0, , drop = FALSE]

  hist_plot <- ggplot2::ggplot(empty, ggplot2::aes(x = y)) +
    ggplot2::geom_histogram(bins = 5)
  hist_gt <- suppressWarnings(
    ggplot2::ggplot_gtable(ggplot2::ggplot_build(hist_plot))
  )
  hist_processor <- maidr:::Ggplot2HistogramLayerProcessor$new(list(index = 1))
  testthat::expect_length(
    hist_processor$generate_selectors(hist_plot, hist_gt), 0
  )

  stacked_plot <- ggplot2::ggplot(
    empty, ggplot2::aes(x = x, y = y, fill = fill)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "stack")
  stacked_gt <- suppressWarnings(
    ggplot2::ggplot_gtable(ggplot2::ggplot_build(stacked_plot))
  )
  stacked_processor <- maidr:::Ggplot2StackedBarProcessor$new(list(index = 1))
  testthat::expect_length(
    stacked_processor$generate_selectors(stacked_plot, stacked_gt), 0
  )
})

test_that("an empty facet level never inherits another panel's selector", {
  skip_if_no_ggplot2()
  testthat::skip_if_not_installed("jsonlite")

  # End to end through save_html(): this is the shape where the smooth
  # fallback used to hand the empty panel the FIRST panel's selector.
  plot <- ggplot2::ggplot(
    smooth_drop_false_data(),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_smooth(method = "loess", se = FALSE, formula = y ~ x) +
    ggplot2::facet_wrap(~g, drop = FALSE)

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  raw <- regmatches(html, gregexpr('maidr-data="[^"]*"', html))[[1]]
  testthat::expect_gt(length(raw), 0)
  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  emitted <- list()
  collect <- function(node) {
    if (!is.list(node)) {
      return(invisible(NULL))
    }
    if ("selectors" %in% names(node)) {
      flat <- unlist(node$selectors, use.names = FALSE)
      emitted[[length(emitted) + 1]] <<- if (is.null(flat)) character(0) else flat
    }
    for (child in node) collect(child)
  }
  collect(payload)

  # This used to assert THREE selector entries, one of them empty -- pinning
  # the very shape that turned out to be broken (issue #89). An empty
  # selector list serialises to `[]`, the frontend hands it to
  # `document.querySelectorAll()`, and an empty selector raises a
  # `SyntaxError` that kills highlighting for the whole figure. Measured in
  # Chromium on this exact render: navigation produced 0 highlight elements
  # against 1 before the change, plus a page error.
  #
  # The empty panel now contributes no layer at all, so only the two panels
  # that drew a curve carry a selector -- which is what this test was
  # really about: neither of them may be the other's.
  testthat::expect_length(emitted, 2)
  drawn <- unlist(emitted, use.names = FALSE)
  testthat::expect_length(drawn, 2)
  testthat::expect_length(unique(drawn), 2)

  # And no layer anywhere may carry an empty selector list.
  for (entry in emitted) {
    testthat::expect_gt(length(entry), 0)
  }
})
