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

test_that("a facet_wrap() whose last row is short gives each its own bars", {
  skip_if_not_installed("xml2")
  plot <- ggplot2::ggplot(facet_bars(5), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel, ncol = 3)
  html <- rendered(plot)

  titles <- vapply(subplot_bars(html), function(s) s$title, "")
  expect_equal(titles, paste("Panel", 1:5))
  expect_own_bars(html)
})

test_that("a facet_wrap() filled down its columns gives each its own bars", {
  skip_if_not_installed("xml2")
  plot <- ggplot2::ggplot(facet_bars(4), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel, ncol = 2, dir = "v")
  expect_own_bars(rendered(plot))
})

test_that("a facet_wrap() with free scales gives each its own bars", {
  # Each panel draws axes of its own, which the gtable lays out between the
  # panels, so the panels' rows and columns are not the gtable's.
  skip_if_not_installed("xml2")
  plot <- ggplot2::ggplot(facet_bars(6), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel, ncol = 3, scales = "free")
  expect_own_bars(rendered(plot))
})

test_that("a facet_grid() with free scales and space gives each its own bars", {
  skip_if_not_installed("xml2")
  frame <- facet_bars(4)
  frame$top <- rep(c("r1", "r1", "r2", "r2"), each = 3)
  frame$side <- rep(c("c1", "c2", "c1", "c2"), each = 3)
  # One column draws two bars, so the columns take widths of their own.
  frame <- frame[!(frame$side == "c2" & frame$category == "c"), ]
  plot <- ggplot2::ggplot(frame, ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_grid(top ~ side, scales = "free", space = "free")
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
  # A place no panel is drawn at names none, rather than another panel.
  expect_null(at(3, 1))
})

test_that("a facet of one panel is found too", {
  plot <- ggplot2::ggplot(facet_bars(1), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel)
  expect_own_bars(rendered(plot))

  # Named with one number, as the pattern the panel grobs are found by
  # (`find_gtable_panel_grob()`) allows, it is found where it is drawn.
  gtable <- list(layout = data.frame(name = c("panel-1", "strip-t-1"), t = c(8, 7), l = c(5, 5)))
  expect_equal(maidr:::map_visual_to_dom_panel(list(ROW = 1, COL = 1), gtable), "panel-1")
})

test_that("a panel found drawn nowhere is read without marks", {
  # Its processors are handed the guess `panel-<row>-<col>`, which a panel
  # may be named whatever its place: under ggplot2 4.0's names, the guess
  # for row 1, column 2 is the name of the panel in row 2, column 1.
  plot <- ggplot2::ggplot(facet_bars(4), ggplot2::aes(category, value)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~panel, ncol = 2)
  built <- ggplot2::ggplot_build(plot)
  gtable <- ggplot2::ggplot_gtable(built)
  panel_info <- built$layout$layout[built$layout$layout$ROW == 1 &
    built$layout$layout$COL == 2, ]
  panel_data <- built$data[[1]][built$data[[1]]$PANEL == panel_info$PANEL, ]
  read <- function(gtable_panel_name) {
    subplot <- maidr:::process_facet_panel(
      plot, panel_info, panel_data,
      maidr:::get_facet_groups(panel_info, built),
      gtable_panel_name, built, list(title = "", axes = list()), gtable
    )
    subplot$layers[[1]]
  }

  expect_length(read(maidr:::map_visual_to_dom_panel(panel_info, gtable))$selectors, 1)
  layer <- read(NULL)
  expect_length(layer$data, 3)
  expect_length(layer$selectors, 0)
})
