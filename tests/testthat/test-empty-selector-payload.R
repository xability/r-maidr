# A layer that resolved no highlight target must OMIT `selectors`, never send
# an empty list (issue #89).
#
# The frontend hands `layer.selectors` straight to
# `document.querySelectorAll()`. An empty array stringifies to `""`, and an
# empty selector is a SyntaxError -- thrown inside the trace constructor, so
# navigation produces no highlight at all on a chart that still looks fine.
# Measured in headless Chromium against these exact renders:
#
#   render                          e23f860   474d126 (#86)          fixed
#   geom_histogram + empty facet    1 hl      0 hl + PAGEERROR       1 hl
#   geom_bar(stack) + empty facet   1 hl      0 hl + PAGEERROR       1 hl
#   geom_bar(dodge) + empty facet   1 hl      0 hl + PAGEERROR       1 hl
#
# where "hl" counts `[id^=maidr-highlight-]` elements appearing during
# keyboard navigation. An absent key is falsy and takes the frontend's own
# "no selectors" path instead.
#
# The regression came in with PR 86, which replaced four fabricated selectors
# with an empty list. Returning an empty list from a processor is right;
# letting it reach the payload as a JSON empty array is not.

skip_if_no_payload <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

# Two populated facet levels plus an empty third: `drop = FALSE` over a factor
# with an unused level makes ggplot2 lay out a panel and draw nothing in it.
empty_level_frame <- function() {
  data.frame(
    x = c("A", "B", "A", "B"),
    y = c(10, 20, 30, 40),
    fill = c("u", "v", "u", "v"),
    g = factor(c("p", "p", "q", "q"), levels = c("p", "q", "r"))
  )
}

render_payload <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  testthat::expect_length(raw, 1)
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  for (pair in list(
    c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"), c("&amp;", "&")
  )) {
    json <- gsub(pair[1], pair[2], json, fixed = TRUE)
  }
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

# Every node that looks like a layer, wherever it sits in the payload.
collect_layers <- function(node, found = NULL) {
  if (is.null(found)) {
    found <- new.env(parent = emptyenv())
    found$items <- list()
  }
  if (is.list(node)) {
    if (!is.null(names(node)) && all(c("type", "data") %in% names(node))) {
      found$items[[length(found$items) + 1L]] <- node
    }
    for (child in node) collect_layers(child, found)
  }
  found$items
}

expect_no_empty_selector_list <- function(payload) {
  for (layer in collect_layers(payload)) {
    if ("selectors" %in% names(layer)) {
      # Present means non-empty. `list()` would serialise to `[]`.
      testthat::expect_gt(length(layer$selectors), 0)
    }
  }
}

test_that("an empty facet level emits no layer rather than an empty one", {
  skip_if_no_payload()

  plot <- ggplot2::ggplot(
    empty_level_frame(),
    ggplot2::aes(x = x, y = y, fill = fill)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "stack") +
    ggplot2::facet_wrap(~g, drop = FALSE)

  payload <- render_payload(plot)
  panels <- unlist(payload$subplots, recursive = FALSE)
  testthat::expect_length(panels, 3)

  counts <- vapply(panels, function(p) length(p$layers), integer(1))
  # Two panels drew marks; the empty level contributes no layer at all. It
  # used to contribute one whose data was `[[]]` -- a single empty series,
  # which a reader entered and heard announced as "undefined".
  testthat::expect_equal(sort(counts), c(0L, 1L, 1L))
  expect_no_empty_selector_list(payload)
})

test_that("no processor sends an empty selector list through the payload", {
  skip_if_no_payload()

  frame <- empty_level_frame()
  hist_frame <- data.frame(
    x = c(1, 2, 3, 4, 5, 6),
    g = factor(c("p", "p", "p", "q", "q", "q"), levels = c("p", "q", "r"))
  )
  smooth_frame <- data.frame(
    x = rep(1:20, 2),
    y = c((1:20) * 1.1, (1:20) * 0.7),
    g = factor(rep(c("p", "q"), each = 20), levels = c("p", "q", "r"))
  )
  box_frame <- data.frame(
    cat = rep(c("x", "y"), 10),
    v = c(seq_len(10), seq(11, 20)),
    g = factor(rep(c("p", "q"), each = 10), levels = c("p", "q", "r"))
  )

  # The four processors #86 changed, plus box plot -- the one that survived
  # initialisation and announced "undefined" instead.
  plots <- list(
    histogram = ggplot2::ggplot(hist_frame, ggplot2::aes(x = x)) +
      ggplot2::geom_histogram(bins = 5) +
      ggplot2::facet_wrap(~g, drop = FALSE),
    stacked = ggplot2::ggplot(
      frame, ggplot2::aes(x = x, y = y, fill = fill)
    ) +
      ggplot2::geom_bar(stat = "identity", position = "stack") +
      ggplot2::facet_wrap(~g, drop = FALSE),
    dodged = ggplot2::ggplot(
      frame, ggplot2::aes(x = x, y = y, fill = fill)
    ) +
      ggplot2::geom_bar(stat = "identity", position = "dodge") +
      ggplot2::facet_wrap(~g, drop = FALSE),
    smooth = ggplot2::ggplot(smooth_frame, ggplot2::aes(x = x, y = y)) +
      ggplot2::geom_smooth(method = "loess", se = FALSE, formula = y ~ x) +
      ggplot2::facet_wrap(~g, drop = FALSE),
    boxplot = ggplot2::ggplot(box_frame, ggplot2::aes(x = cat, y = v)) +
      ggplot2::geom_boxplot() +
      ggplot2::facet_wrap(~g, drop = FALSE)
  )

  for (name in names(plots)) {
    payload <- render_payload(plots[[name]])
    expect_no_empty_selector_list(payload)
  }
})

test_that("drop_empty_selectors removes only zero-length selector lists", {
  kept <- list(
    layers = list(
      list(type = "bar", selectors = list("#a rect")),
      list(type = "bar", selectors = list()),
      list(type = "bar")
    )
  )
  out <- maidr:::drop_empty_selectors(kept)

  testthat::expect_equal(out$layers[[1]]$selectors, list("#a rect"))
  testthat::expect_false("selectors" %in% names(out$layers[[2]]))
  testthat::expect_false("selectors" %in% names(out$layers[[3]]))

  # A BoxSelector is a named object, not a list of strings; it must survive
  # even though its own fields may be empty.
  box <- list(layers = list(list(
    type = "box",
    selectors = list(list(
      iq = "#a polygon", q2 = "#b polyline",
      lowerOutliers = list(), upperOutliers = list()
    ))
  )))
  out_box <- maidr:::drop_empty_selectors(box)
  testthat::expect_length(out_box$layers[[1]]$selectors, 1)
  testthat::expect_equal(out_box$layers[[1]]$selectors[[1]]$iq, "#a polygon")
})
