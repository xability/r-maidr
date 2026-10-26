# Each facet panel's selectors name the marks drawn in that panel
#
# The facet path finds a panel's marks in the gtable panel named for it, and
# `map_visual_to_dom_panel()` chose the name by reading `panel-<a>-<b>` as the
# panel's column-major position. ggplot2 does not name its panels that way:
# under 3.4.4 a 2 x 2 `facet_wrap()` or `facet_grid()` is `panel-<row>-<col>`,
# so the two off-diagonal panels took each other's marks, and a wrap that is
# not square is named in an order matching no grid at all. The reader heard
# Region C's values while the highlight lit Region B's bars, and maidr.js,
# which places each subplot where its first mark is drawn, put the subplots
# out of order (Region C first).
#
# Each panel below draws the three bars a, b, c in its own order of heights,
# so the heights a selector finds say which panel's bars it names.

skip_slow_file_on_cran()

# Every ordering of three heights, one per panel.
facet_orders <- list(
  c(1, 2, 3), c(3, 2, 1), c(2, 3, 1), c(1, 3, 2), c(3, 1, 2), c(2, 1, 3)
)

facet_bars <- function(panels) {
  data.frame(
    panel = rep(paste("Panel", seq_len(panels)), each = 3),
    category = rep(c("a", "b", "c"), panels),
    value = unlist(facet_orders[seq_len(panels)])
  )
}

# For every subplot of a rendering: its data values and the heights of the
# rects its selector names, in document order.
subplot_bars <- function(html) {
  schema <- schema_from(html)
  doc <- xml2::read_html(html)
  out <- list()
  for (row in seq_along(schema$subplots)) {
    for (col in seq_along(schema$subplots[[row]])) {
      layer <- schema$subplots[[row]][[col]]$layers[[1]]
      selector <- unlist(layer$selectors)
      id <- sub(" rect$", "", sub("^#", "", gsub("\\", "", selector, fixed = TRUE)))
      rects <- xml2::xml_find_all(doc, sprintf("//*[@id='%s']/rect", id))
      out[[length(out) + 1L]] <- list(
        at = c(row, col),
        title = layer$title,
        values = vapply(layer$data, function(p) as.numeric(p$y), numeric(1)),
        heights = as.numeric(xml2::xml_attr(rects, "height"))
      )
    }
  }
  out
}

expect_own_bars <- function(html) {
  for (subplot in subplot_bars(html)) {
    expect_length(subplot$heights, length(subplot$values))
    expect_equal(
      order(subplot$heights), order(subplot$values),
      info = sprintf("subplot %s (%s)", paste(subplot$at, collapse = ","), subplot$title)
    )
  }
}

test_that("a 2 x 2 facet_wrap() gives each subplot its own panel's bars", {
  skip_if_not_installed("xml2")
  plot <- ggplot2::ggplot(facet_bars(4), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel, ncol = 2)
  html <- rendered(plot)

  titles <- vapply(subplot_bars(html), function(s) s$title, "")
  expect_equal(titles, paste("Panel", 1:4))
  expect_own_bars(html)
})

test_that("a facet_wrap() of two rows and three columns gives each its own bars", {
  skip_if_not_installed("xml2")
  plot <- ggplot2::ggplot(facet_bars(6), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel, ncol = 3)
  expect_own_bars(rendered(plot))
})

test_that("a facet_wrap() of three rows and two columns gives each its own bars", {
  skip_if_not_installed("xml2")
  plot <- ggplot2::ggplot(facet_bars(6), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel, ncol = 2)
  expect_own_bars(rendered(plot))
})

test_that("a 2 x 2 facet_grid() gives each subplot its own panel's bars", {
  skip_if_not_installed("xml2")
  frame <- facet_bars(4)
  frame$top <- rep(c("r1", "r1", "r2", "r2"), each = 3)
  frame$side <- rep(c("c1", "c2", "c1", "c2"), each = 3)
  plot <- ggplot2::ggplot(frame, ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_grid(top ~ side)
  expect_own_bars(rendered(plot))
})

test_that("the panel is found by where it is drawn, whatever it is named", {
  # ggplot2 4.0 names a wrap's panels `panel-<col>-<row>`: the same grid,
  # drawn in the same places, under the transposed names.
  gtable <- list(layout = data.frame(
    name = c("panel-1-1", "panel-1-2", "panel-2-1", "panel-2-2", "strip-t-1"),
    t = c(8, 13, 8, 13, 7),
    l = c(5, 5, 9, 9, 5)
  ))
  at <- function(row, col) {
    maidr:::map_visual_to_dom_panel(list(ROW = row, COL = col), gtable)
  }
  expect_equal(at(1, 1), "panel-1-1")
  expect_equal(at(1, 2), "panel-2-1")
  expect_equal(at(2, 1), "panel-1-2")
  expect_equal(at(2, 2), "panel-2-2")
})
