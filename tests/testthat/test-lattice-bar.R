# lattice `barchart()`, `histogram()` and `dotplot()` readings (#333)
#
# All three draw one mark per value on a category or bin axis, and the
# frontend pairs a bar-shaped layer's marks with its values by position:
# one selector string, resolved in document order, against the values in
# payload order. So every reading here is checked twice over:
#
#   * the values against where they come from outside the reader -- the
#     rows the chart was given, `hist()` over lattice's own breaks, the
#     `Titanic` and `VADeaths` tables;
#   * every selector against the SVG the chart was exported as, resolved to
#     the elements it names, which are then measured: a bar has to end at
#     its own value and sit at its own level, not merely exist.
#
# The measuring reads a shape's coordinates back into the units lattice
# drew it in. The exporter draws each panel's frame
# (`maidr.border.panel.<column>.<row>`) exactly around the panel's limits,
# which the trellis object keeps: a number range, or the names of a
# factor's levels, which lattice lays out at positions 1..n padded by its
# `axis.padding` option. The export flips the page (`scale(1, -1)`), so a
# shape's `y` grows upward as native units do.
#
# lattice draws the bars and dots of a panel in the order of its rows, so
# the rows are sorted by level before drawing (`lattice_prepare()`); the
# fixtures are shuffled so a reading that kept the rows' order cannot pass,
# and the last tests check that the sort changes nothing a reader sees.

skip_slow_file_on_cran()

# Four levels whose rows arrive out of order: banana first, apple third.
FRUIT <- data.frame(
  fruit = factor(
    c("banana", "date", "apple", "cherry"),
    levels = c("apple", "banana", "cherry", "date")
  ),
  sold = c(7, 5, 3, 2)
)

# Three shops by three seasons, shuffled, with one combination missing:
# the cherry shop has no spring row.
SALES <- data.frame(
  shop = factor(c("b", "a", "c", "a", "b", "c", "a", "b")),
  season = factor(
    c("summer", "winter", "summer", "summer", "winter", "winter", "spring", "spring"),
    levels = c("spring", "summer", "winter")
  ),
  sold = c(5, 3, 2, 4, 6, 1, 7, 8)
)

# The same grid with losses and nothing at all: stacked bars split by sign
# and draw no bar for a zero.
PROFIT <- transform(SALES, profit = c(5, -3, 0, 4, -6, 1, 7, 0))

# Two values on an exact break, so which side a break closes on matters.
BINNED <- c(0.5, 1, 2, 2, 2.5, 3, 4, 4, 5.5, 6)

#' The frame of a panel as exported: the rectangle its limits span, in px
drawn_frame <- function(doc, column = 1L, row = 1L) {
  node <- xml2::xml_find_first(
    doc,
    sprintf("//*[@id='maidr.border.panel.%d.%d.1.1']", column, row)
  )
  testthat::expect_false(inherits(node, "xml_missing"))
  number <- function(name) as.numeric(xml2::xml_attr(node, name))
  list(x = number("x"), y = number("y"), width = number("width"), height = number("height"))
}

#' An axis' limits as the numeric range lattice draws them over
native_range <- function(limits) {
  if (is.character(limits)) {
    pad <- lattice::lattice.getOption("axis.padding")$factor
    c(1 - pad, length(limits) + pad)
  } else {
    as.numeric(limits)
  }
}

#' px along one side of a panel's frame, in the panel's native units
native_along <- function(px, start, size, limits) {
  range <- native_range(limits)
  range[1] + (px - start) / size * diff(range)
}

#' How much of an axis one px of a panel spans, in native units
native_per_px <- function(size, limits) {
  diff(native_range(limits)) / size
}

#' The native extents of exported `<rect>`s, one row per element
#'
#' Carries how much one px spans on each axis, as `x_unit` and `y_unit`:
#' the exporter writes coordinates to a hundredth of a px, so that is as
#' closely as a drawn shape can be measured.
rect_extents <- function(nodes, frame, x_limits, y_limits) {
  number <- function(name) as.numeric(xml2::xml_attr(nodes, name))
  x <- number("x")
  y <- number("y")
  structure(
    data.frame(
      left = native_along(x, frame$x, frame$width, x_limits),
      right = native_along(x + number("width"), frame$x, frame$width, x_limits),
      bottom = native_along(y, frame$y, frame$height, y_limits),
      top = native_along(y + number("height"), frame$y, frame$height, y_limits)
    ),
    x_unit = native_per_px(frame$width, x_limits),
    y_unit = native_per_px(frame$height, y_limits)
  )
}

#' The native centres of exported points (`<use>`), one row per element
dot_centres <- function(nodes, frame, x_limits, y_limits) {
  number <- function(name) as.numeric(xml2::xml_attr(nodes, name))
  structure(
    data.frame(
      x = native_along(number("x"), frame$x, frame$width, x_limits),
      y = native_along(number("y"), frame$y, frame$height, y_limits)
    ),
    x_unit = native_per_px(frame$width, x_limits),
    y_unit = native_per_px(frame$height, y_limits)
  )
}

#' The layout cell of the panel a layer's selectors point into
#'
#' Read off the ids of the elements they resolve to, which lattice names
#' `...panel.<column>.<row>`; every element has to be in the same panel.
panel_named <- function(doc, selectors) {
  cells <- unique(unlist(lapply(unlist(selectors), function(selector) {
    id <- xml2::xml_attr(lattice_selector_nodes(doc, selector), "id")
    sub("^.*\\.panel\\.([0-9]+)\\.([0-9]+)\\.[0-9]+(\\.[0-9]+)?$", "\\1 \\2", id)
  })))
  testthat::expect_length(cells, 1L)
  as.integer(strsplit(cells[1], " ", fixed = TRUE)[[1]])
}

#' Expect shapes to be drawn where lattice draws the expected values
#'
#' To within the exporter's rounding: each coordinate is written to a
#' hundredth of a px, and an edge is a sum of two of them.
expect_drawn <- function(drawn, expected, unit) {
  testthat::expect_length(drawn, length(expected))
  off <- max(abs(drawn - expected)) / unit
  testthat::expect(
    isTRUE(off <= 0.025),
    sprintf(
      "drawn at %s, expected %s (%.3g px off)",
      toString(signif(drawn, 6)), toString(signif(expected, 6)), off
    )
  )
}

#' One field of every point of a layer, a JSON null read as NA
field_of <- function(points, field) {
  values <- lapply(points, function(point) point[[field]])
  text <- any(vapply(values, is.character, logical(1)))
  vapply(values, function(value) {
    if (is.null(value)) {
      if (text) NA_character_ else NA_real_
    } else if (text) {
      as.character(value)
    } else {
      as.numeric(value)
    }
  }, if (text) "" else 0)
}

#' The only layer of a rendering, after checking it is the only one
only_layer <- function(rendered) {
  testthat::expect_false(rendered$fallback)
  layers <- lattice_rendered_layers(rendered)
  testthat::expect_length(layers, 1L)
  layers[[1]]
}

#' Every mark a chart draws in the SVG it is exported as, without ids
#'
#' The ids of a panel's marks number them in drawing order, which is the
#' one thing sorting the rows is meant to change; everything else about a
#' mark -- where it is, how big, its colour and stroke -- is what the chart
#' looks like.
drawn_marks <- function(scene) {
  svg <- maidr:::create_enhanced_svg(
    scene$grob,
    list(id = "maidr-plot-prepare", subplots = list())
  )
  doc <- xml2::read_xml(paste(svg, collapse = "\n"))
  nodes <- xml2::xml_find_all(
    doc,
    paste(
      "//*[local-name()='rect' or local-name()='polyline' or",
      "local-name()='polygon' or local-name()='use' or local-name()='text']"
    )
  )
  vapply(nodes, function(node) {
    attrs <- xml2::xml_attrs(node)
    attrs <- attrs[names(attrs) != "id"]
    paste(
      xml2::xml_name(node),
      paste(names(attrs), attrs, sep = "=", collapse = " "),
      xml2::xml_text(node)
    )
  }, character(1))
}

# barchart(): one value per level ------------------------------------------

test_that("a horizontal barchart reads each level's value in level order", {
  skip_if_no_lattice()
  layer <- only_layer(render_lattice(lattice::barchart(fruit ~ sold, data = FRUIT)))

  testthat::expect_identical(layer$type, "bar")
  testthat::expect_identical(layer$orientation, "horz")
  # `horz` puts the magnitude in x and the category in y. The rows came in
  # banana-first; the levels run apple first, and so must the reading.
  in_order <- FRUIT[order(FRUIT$fruit), ]
  testthat::expect_identical(field_of(layer$data, "y"), as.character(in_order$fruit))
  testthat::expect_equal(field_of(layer$data, "x"), in_order$sold)
})

test_that("a horizontal barchart's i-th bar in the SVG is level i, ending at value i", {
  skip_if_no_lattice()
  plot <- lattice::barchart(fruit ~ sold, data = FRUIT)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, nrow(FRUIT))
  testthat::expect_true(all(xml2::xml_name(nodes) == "rect"))

  bars <- rect_extents(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  levels_at <- (bars$bottom + bars$top) / 2
  labels <- field_of(layer$data, "y")
  expect_drawn(levels_at, match(labels, levels(FRUIT$fruit)), attr(bars, "y_unit"))
  expect_drawn(bars$right, FRUIT$sold[match(labels, FRUIT$fruit)], attr(bars, "x_unit"))
  # With no origin lattice starts every bar at the panel's edge, so a bar's
  # length is not its value -- which is why the value is read, not measured.
  expect_drawn(bars$left, rep(plot$x.limits[1], nrow(FRUIT)), attr(bars, "x_unit"))
})

test_that("a vertical barchart reads the level as x and the value as y", {
  skip_if_no_lattice()
  plot <- lattice::barchart(sold ~ fruit, data = FRUIT)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_false(isTRUE(plot$panel.args.common$horizontal))
  testthat::expect_identical(layer$orientation, "vert")
  in_order <- FRUIT[order(FRUIT$fruit), ]
  testthat::expect_identical(field_of(layer$data, "x"), as.character(in_order$fruit))
  testthat::expect_equal(field_of(layer$data, "y"), in_order$sold)

  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, nrow(FRUIT))
  bars <- rect_extents(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn((bars$left + bars$right) / 2, seq_len(nrow(FRUIT)), attr(bars, "x_unit"))
  expect_drawn(bars$top, in_order$sold, attr(bars, "y_unit"))
})

test_that("a missing value or category draws no bar and is left out", {
  skip_if_no_lattice()
  gappy <- rbind(FRUIT, data.frame(fruit = NA, sold = 9))
  gappy$sold[gappy$fruit %in% "cherry"] <- NA
  plot <- lattice::barchart(fruit ~ sold, data = gappy)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(field_of(layer$data, "y"), c("apple", "banana", "date"))
  testthat::expect_equal(field_of(layer$data, "x"), c(3, 7, 5))

  # Three bars, at the positions of apple, banana and date: the gap is where
  # cherry would be, not at the end.
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, 3L)
  bars <- rect_extents(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn((bars$bottom + bars$top) / 2, c(1, 2, 4), attr(bars, "y_unit"))
  expect_drawn(bars$right, c(3, 7, 5), attr(bars, "x_unit"))
})

test_that("a zero is read as zero, and its bar of no length is still exported", {
  skip_if_no_lattice()
  zero <- transform(FRUIT, sold = c(7, 0, 3, 2))
  plot <- lattice::barchart(fruit ~ sold, data = zero, origin = 0)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_equal(field_of(layer$data, "x"), c(3, 7, 2, 0))
  # The frontend pairs by count: a zero bar missing from the SVG would hand
  # every later value the wrong element, so it has to be there, flat.
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, 4L)
  testthat::expect_equal(as.numeric(xml2::xml_attr(nodes[[4]], "width")), 0)
  bars <- rect_extents(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn((bars$bottom + bars$top)[4] / 2, 4, attr(bars, "y_unit"))
  expect_drawn(bars$left[4], 0, attr(bars, "x_unit"))
})

test_that("negative values are read as given, their bars running back from the origin", {
  skip_if_no_lattice()
  losses <- transform(FRUIT, sold = c(7, -5, 3, -2))
  plot <- lattice::barchart(fruit ~ sold, data = losses, origin = 0)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_equal(field_of(layer$data, "x"), c(3, 7, -2, -5))
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, 4L)
  bars <- rect_extents(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  value <- c(3, 7, -2, -5)
  expect_drawn(bars$left, pmin(value, 0), attr(bars, "x_unit"))
  expect_drawn(bars$right, pmax(value, 0), attr(bars, "x_unit"))
})

test_that("an origin draws a reference line, which is not read as a layer", {
  skip_if_no_lattice()
  plot <- lattice::barchart(fruit ~ sold, data = FRUIT, origin = 0)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  line <- xml2::xml_find_all(
    rendered$doc,
    "//*[@id='maidr.barchart.abline.v.panel.1.1.1']/*[local-name()='polyline']"
  )
  testthat::expect_length(line, 1L)
  testthat::expect_equal(field_of(layer$data, "x"), c(3, 7, 2, 5))
})

test_that("a level given two values overlaps its bars and falls back", {
  skip_if_no_lattice()
  twice <- rbind(FRUIT, data.frame(fruit = "apple", sold = 1))
  rendered <- render_lattice(lattice::barchart(fruit ~ sold, data = twice))

  testthat::expect_true(rendered$fallback)
  testthat::expect_match(
    paste(rendered$orchestrator$unsupported_reasons(), collapse = "; "),
    "bar"
  )
})

test_that("a numeric category is cut into a shingle and falls back", {
  skip_if_no_lattice()
  plot <- lattice::barchart(cyl ~ mpg, data = mtcars)

  # lattice's own record of the conversion: the levels are intervals.
  testthat::expect_false(is.null(plot$panel.args.common$nlevels))
  testthat::expect_true(render_lattice(plot)$fallback)
})

test_that("a log value axis is read on the data's own scale", {
  skip_if_no_lattice()
  plot <- lattice::barchart(fruit ~ sold, data = FRUIT, scales = list(x = list(log = 10)))
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  # lattice keeps and draws a log axis in log units: its limits are logs,
  # and so is where each bar ends.
  in_order <- FRUIT[order(FRUIT$fruit), ]
  testthat::expect_equal(field_of(layer$data, "x"), in_order$sold)
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, nrow(FRUIT))
  bars <- rect_extents(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn(bars$right, log10(in_order$sold), attr(bars, "x_unit"))
})

test_that("a named vector's bars read their names in the order lattice lays them out", {
  skip_if_no_lattice()
  plot <- lattice::barchart(c(pear = 2, fig = 5, kiwi = 1))
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  laid_out <- levels(plot$panel.args[[1]]$y)
  testthat::expect_setequal(laid_out, c("pear", "fig", "kiwi"))
  testthat::expect_identical(field_of(layer$data, "y"), laid_out)
  testthat::expect_equal(
    field_of(layer$data, "x"),
    unname(c(pear = 2, fig = 5, kiwi = 1)[laid_out])
  )
  testthat::expect_identical(lattice_selector_counts(rendered$doc, layer$selectors), 3L)
})

# barchart(): groups ------------------------------------------------------

#' Check a grouped bar layer against the rows it was drawn from
#'
#' `rows` holds the panel's rows (`shop`, `season`, and the value in
#' `value`). Every cell must hold its row's value -- or NA, with a null
#' selector, where there is no row -- and every selector must resolve to the
#' one bar drawn for that cell in the panel at `column`, `row`: dodged, at
#' the group's slot beside its level and running from the origin to the
#' value; stacked, on top of the groups before it, or below them for a loss.
expect_grouped_bars <- function(rendered, layer, plot, rows, stacked, horizontal,
                                column = 1L, row = 1L) {
  groups <- levels(rows$season)[levels(rows$season) %in% rows$season[!is.na(rows$value)]]
  shops <- levels(rows$shop)[levels(rows$shop) %in% rows$shop[!is.na(rows$value)]]
  testthat::expect_length(layer$data, length(groups))
  testthat::expect_length(layer$selectors, length(groups))

  frame <- drawn_frame(rendered$doc, column, row)
  # `panel.barchart()` dodges over every level of the groups, as a factor.
  every_group <- plot$panel.args.common$groups
  nvals <- nlevels(if (is.factor(every_group)) every_group else factor(every_group))
  box_width <- plot$panel.args.common$box.ratio / (1 + plot$panel.args.common$box.ratio)

  for (s in seq_along(groups)) {
    series <- layer$data[[s]]
    testthat::expect_identical(field_of(series, "z"), rep(groups[s], length(shops)))
    testthat::expect_identical(
      field_of(series, if (horizontal) "y" else "x"),
      shops
    )
    for (k in seq_along(shops)) {
      cell <- rows[rows$season == groups[s] & rows$shop == shops[k], ]
      value <- if (nrow(cell)) cell$value else NA_real_
      read <- series[[k]][[if (horizontal) "x" else "y"]]
      selector <- layer$selectors[[s]][[k]]

      if (is.na(value)) {
        testthat::expect_null(read)
        testthat::expect_null(selector)
        next
      }
      testthat::expect_equal(read, value)
      if (stacked && value == 0) {
        testthat::expect_null(selector)
        next
      }

      nodes <- lattice_selector_nodes(rendered$doc, selector)
      testthat::expect_length(nodes, 1L)
      bar <- rect_extents(nodes, frame, plot$x.limits, plot$y.limits)
      across <- if (horizontal) c(bar$bottom, bar$top) else c(bar$left, bar$right)
      along <- if (horizontal) c(bar$left, bar$right) else c(bar$bottom, bar$top)
      across_unit <- attr(bar, if (horizontal) "y_unit" else "x_unit")
      along_unit <- attr(bar, if (horizontal) "x_unit" else "y_unit")
      level <- match(shops[k], levels(rows$shop))
      group <- match(groups[s], levels(rows$season))

      if (!stacked) {
        slot <- level + box_width / nvals * (group - (nvals + 1) / 2)
        expect_drawn(mean(across), slot, across_unit)
        expect_drawn(along, sort(c(0, value)), along_unit)
      } else {
        expect_drawn(mean(across), level, across_unit)
        # lattice draws a level's gains and its losses as two grobs.
        testthat::expect_match(
          xml2::xml_attr(nodes, "id"),
          if (value > 0) ".pos." else ".neg.",
          fixed = TRUE
        )
        # Stacked in the order of the groups, gains up from zero and losses
        # down from it.
        same_sign <- rows[rows$shop == shops[k] & sign(rows$value) == sign(value), ]
        before <- same_sign$value[as.integer(same_sign$season) < group]
        start <- sum(before)
        expect_drawn(along, sort(c(start, start + value)), along_unit)
      }
    }
  }
}

test_that("a dodged barchart reads a series per group, null where a bar is missing", {
  skip_if_no_lattice()
  plot <- lattice::barchart(shop ~ sold, groups = season, data = SALES, origin = 0)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(layer$type, "dodged_bar")
  testthat::expect_identical(layer$orientation, "horz")
  rows <- data.frame(shop = SALES$shop, season = SALES$season, value = SALES$sold)
  expect_grouped_bars(rendered, layer, plot, rows, stacked = FALSE, horizontal = TRUE)
})

test_that("a vertical dodged barchart is read the same way round as it is drawn", {
  skip_if_no_lattice()
  plot <- lattice::barchart(sold ~ shop, groups = season, data = SALES, origin = 0)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(layer$type, "dodged_bar")
  testthat::expect_identical(layer$orientation, "vert")
  rows <- data.frame(shop = SALES$shop, season = SALES$season, value = SALES$sold)
  expect_grouped_bars(rendered, layer, plot, rows, stacked = FALSE, horizontal = FALSE)
})

test_that("a group or level a panel does not hold is not read in that panel", {
  skip_if_no_lattice()
  # The second town has no winter row and no cherry shop at all.
  towns <- rbind(
    transform(SALES, town = "north"),
    data.frame(
      shop = c("a", "b", "a", "b"),
      season = c("spring", "spring", "summer", "summer"),
      sold = c(2, 3, 4, 1),
      town = "south"
    )
  )
  plot <- lattice::barchart(shop ~ sold | town, groups = season, data = towns, origin = 0)
  rendered <- render_lattice(plot)
  layers <- lattice_rendered_layers(rendered)
  testthat::expect_false(rendered$fallback)
  testthat::expect_length(layers, 2L)

  south <- Filter(function(layer) identical(layer$title, "south"), layers)[[1]]
  testthat::expect_identical(
    vapply(south$data, function(series) series[[1]]$z, ""),
    c("spring", "summer")
  )
  testthat::expect_identical(field_of(south$data[[1]], "y"), c("a", "b"))
  testthat::expect_equal(field_of(south$data[[1]], "x"), c(2, 3))
  testthat::expect_equal(field_of(south$data[[2]], "x"), c(4, 1))
  testthat::expect_true(all(lattice_selector_counts(rendered$doc, south$selectors) == 1L))
})

test_that("a stacked barchart reads losses and zeros, stacking bars as lattice does", {
  skip_if_no_lattice()
  plot <- lattice::barchart(shop ~ profit, groups = season, data = PROFIT, stack = TRUE)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(layer$type, "stacked_bar")
  testthat::expect_identical(layer$orientation, "horz")
  rows <- data.frame(shop = PROFIT$shop, season = PROFIT$season, value = PROFIT$profit)
  expect_grouped_bars(rendered, layer, plot, rows, stacked = TRUE, horizontal = TRUE)
})

test_that("a vertical stacked barchart stacks up the value axis", {
  skip_if_no_lattice()
  plot <- lattice::barchart(profit ~ shop, groups = season, data = PROFIT, stack = TRUE)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(layer$type, "stacked_bar")
  testthat::expect_identical(layer$orientation, "vert")
  rows <- data.frame(shop = PROFIT$shop, season = PROFIT$season, value = PROFIT$profit)
  expect_grouped_bars(rendered, layer, plot, rows, stacked = TRUE, horizontal = FALSE)
})

test_that("barchart(Titanic) reads each panel of the table as a stacked layer", {
  skip_if_no_lattice()
  plot <- lattice::barchart(Titanic)
  rendered <- render_lattice(plot)
  layers <- lattice_rendered_layers(rendered)

  testthat::expect_false(rendered$fallback)
  # One panel per sex and age, the survivors stacked on the dead by class.
  testthat::expect_length(layers, 4L)
  titles <- vapply(layers, function(layer) layer$title, "")
  testthat::expect_setequal(
    titles,
    c("Male & Child", "Female & Child", "Male & Adult", "Female & Adult")
  )

  table <- as.data.frame(Titanic)
  for (layer in layers) {
    testthat::expect_identical(layer$type, "stacked_bar")
    testthat::expect_identical(layer$orientation, "horz")
    packet <- strsplit(layer$title, " & ", fixed = TRUE)[[1]]
    here <- table[table$Sex == packet[1] & table$Age == packet[2], ]
    rows <- data.frame(shop = here$Class, season = here$Survived, value = here$Freq)

    # The bars are measured in the panel the layer's selectors name. A layer
    # pointing at another panel's bars would still find bars there, but not
    # ones the size of this panel's counts.
    cell <- panel_named(rendered$doc, layer$selectors)
    expect_grouped_bars(
      rendered, layer, plot, rows,
      stacked = TRUE, horizontal = TRUE, column = cell[1], row = cell[2]
    )
  }
})

test_that("a key drawn for the groups adds no layer and names the series' axis", {
  skip_if_no_lattice()
  plot <- lattice::barchart(
    shop ~ sold,
    groups = season, data = SALES,
    auto.key = list(title = "Season")
  )
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  # The key is drawn -- a swatch per season, under its title -- and none of
  # it is read: every element the layer names is a bar inside the panel.
  swatches <- xml2::xml_find_all(
    rendered$doc,
    "//*[local-name()='rect'][starts-with(@id, 'maidr.key.rect.')]"
  )
  testthat::expect_length(swatches, nlevels(SALES$season))
  texts <- xml2::xml_text(xml2::xml_find_all(rendered$doc, "//*[local-name()='text']"))
  testthat::expect_true("Season" %in% texts)
  named <- unlist(lapply(unlist(layer$selectors), function(selector) {
    xml2::xml_attr(lattice_selector_nodes(rendered$doc, selector), "id")
  }))
  testthat::expect_true(all(startsWith(named, "maidr.barchart.")))

  testthat::expect_identical(layer$axes$z$label, "Season")
})

test_that("without a key the series' axis is named by the grouping expression", {
  skip_if_no_lattice()
  layer <- only_layer(render_lattice(
    lattice::barchart(shop ~ sold, groups = season, data = SALES)
  ))

  testthat::expect_identical(layer$axes$z$label, "season")
  testthat::expect_identical(layer$axes$x$label, "sold")
  testthat::expect_identical(layer$axes$y$label, "shop")
})

test_that("numeric groups are series named by their values, smallest first", {
  skip_if_no_lattice()
  # Years out of order and not in text order: 9 before 10.
  yearly <- data.frame(
    shop = factor(c("a", "b", "a", "b")),
    year = c(10, 9, 9, 10),
    sold = c(4, 3, 2, 5)
  )
  plot <- lattice::barchart(shop ~ sold, groups = year, data = yearly, origin = 0)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(
    vapply(layer$data, function(series) series[[1]]$z, ""),
    c("9", "10")
  )
  testthat::expect_identical(layer$axes$z$label, "year")
  rows <- data.frame(
    shop = yearly$shop,
    season = factor(yearly$year),
    value = yearly$sold
  )
  expect_grouped_bars(rendered, layer, plot, rows, stacked = FALSE, horizontal = TRUE)
})

# histogram() ---------------------------------------------------------------

#' The bins `hist()` makes of `x` over lattice's breaks, as lattice reads them
#'
#' What `panel.histogram()` draws, recomputed without it: counts from
#' `hist()` on the breaks, and the height in the units `type` asks for --
#' percent of every row the panel was given, missing ones included.
lattice_bins <- function(x, breaks, type, right = TRUE) {
  bins <- graphics::hist(x, breaks = breaks, right = right, plot = FALSE)
  list(
    breaks = bins$breaks,
    height = switch(type,
      count = bins$counts,
      percent = 100 * bins$counts / length(x),
      density = bins$density
    )
  )
}

#' Check a hist layer's bins, and the rects its selector names, against bins
expect_bins <- function(rendered, layer, plot, bins, column = 1L, row = 1L) {
  testthat::expect_identical(layer$type, "hist")
  testthat::expect_identical(layer$orientation, "vert")
  n <- length(bins$breaks) - 1L
  lower <- bins$breaks[-(n + 1L)]
  upper <- bins$breaks[-1L]

  testthat::expect_equal(field_of(layer$data, "xMin"), lower)
  testthat::expect_equal(field_of(layer$data, "xMax"), upper)
  testthat::expect_equal(field_of(layer$data, "x"), (lower + upper) / 2)
  testthat::expect_equal(field_of(layer$data, "y"), bins$height)
  testthat::expect_equal(field_of(layer$data, "yMin"), rep(0, n))
  testthat::expect_equal(field_of(layer$data, "yMax"), bins$height)

  # One rect per bin, left to right in the document as on the axis, each as
  # tall as the bin reads -- an empty bin as a rect with no height.
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, n)
  testthat::expect_true(all(xml2::xml_name(nodes) == "rect"))
  drawn <- rect_extents(
    nodes, drawn_frame(rendered$doc, column, row), plot$x.limits, plot$y.limits
  )
  expect_drawn(drawn$left, lower, attr(drawn, "x_unit"))
  expect_drawn(drawn$right, upper, attr(drawn, "x_unit"))
  expect_drawn(drawn$bottom, rep(0, n), attr(drawn, "y_unit"))
  expect_drawn(drawn$top, bins$height, attr(drawn, "y_unit"))
}

test_that("a histogram reads the percent of the rows in each bin by default", {
  skip_if_no_lattice()
  plot <- lattice::histogram(~BINNED)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  common <- plot$panel.args.common
  testthat::expect_identical(common$type, "percent")
  expect_bins(rendered, layer, plot, lattice_bins(BINNED, common$breaks, "percent"))
  # The axis is named as lattice draws it.
  texts <- xml2::xml_text(xml2::xml_find_all(rendered$doc, "//*[local-name()='text']"))
  testthat::expect_identical(layer$axes$y$label, "Percent of Total")
  testthat::expect_true("Percent of Total" %in% texts)
})

test_that("a histogram reads counts in as many bins as nint asks for", {
  skip_if_no_lattice()
  plot <- lattice::histogram(~BINNED, type = "count", nint = 5)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  breaks <- plot$panel.args.common$breaks
  testthat::expect_length(breaks, 6L)
  expect_bins(rendered, layer, plot, lattice_bins(BINNED, breaks, "count"))
  testthat::expect_identical(layer$axes$y$label, "Count")
})

test_that("a density histogram reads hist()'s densities over lattice's breaks", {
  skip_if_no_lattice()
  plot <- lattice::histogram(~BINNED, type = "density")
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  bins <- lattice_bins(BINNED, plot$panel.args.common$breaks, "density")
  expect_bins(rendered, layer, plot, bins)
  # A density is what makes the bins' areas add up to one.
  testthat::expect_equal(sum(bins$height * diff(bins$breaks)), 1)
})

test_that("breaks given as a vector are the bins, unequal ones read as densities", {
  skip_if_no_lattice()
  breaks <- c(0, 1, 2.5, 4, 6)
  plot <- lattice::histogram(~BINNED, breaks = breaks)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  # lattice's own choice for unequal bins, which percent would misdraw.
  testthat::expect_identical(plot$panel.args.common$type, "density")
  expect_bins(rendered, layer, plot, lattice_bins(BINNED, breaks, "density"))
  testthat::expect_identical(layer$axes$y$label, "Density")
})

test_that("a bin with nothing in it is drawn flat and read as zero", {
  skip_if_no_lattice()
  plot <- lattice::histogram(~BINNED, breaks = 0:6, type = "count")
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  bins <- lattice_bins(BINNED, 0:6, "count")
  testthat::expect_true(any(bins$height == 0))
  expect_bins(rendered, layer, plot, bins)
})

test_that("right = FALSE closes the bins on their left, as hist() does", {
  skip_if_no_lattice()
  plot <- lattice::histogram(~BINNED, breaks = 0:6, type = "count", right = FALSE)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  left_closed <- lattice_bins(BINNED, 0:6, "count", right = FALSE)
  # Values on the breaks move bins, so the two readings differ.
  testthat::expect_false(identical(left_closed$height, lattice_bins(BINNED, 0:6, "count")$height))
  expect_bins(rendered, layer, plot, left_closed)
})

test_that("conditioned histograms share their breaks, each panel its own counts", {
  skip_if_no_lattice()
  batches <- data.frame(
    value = c(BINNED, BINNED[-(1:4)] + 1),
    batch = rep(c("first", "second"), c(length(BINNED), length(BINNED) - 4L))
  )
  plot <- lattice::histogram(~ value | batch, data = batches)
  rendered <- render_lattice(plot)
  layers <- lattice_rendered_layers(rendered)

  testthat::expect_false(rendered$fallback)
  testthat::expect_length(layers, 2L)
  breaks <- plot$panel.args.common$breaks
  for (layer in layers) {
    rows <- batches$value[batches$batch == layer$title]
    testthat::expect_gt(length(rows), 0L)
    cell <- panel_named(rendered$doc, layer$selectors)
    expect_bins(
      rendered, layer, plot, lattice_bins(rows, breaks, "percent"),
      column = cell[1], row = cell[2]
    )
  }
})

test_that("breaks named by a rule are worked out per panel", {
  skip_if_no_lattice()
  spread <- data.frame(
    value = c(seq(0, 1, length.out = 20), seq(0, 50, length.out = 20)),
    batch = rep(c("narrow", "wide"), each = 20)
  )
  plot <- lattice::histogram(~ value | batch, data = spread, breaks = "Sturges")
  rendered <- render_lattice(plot)
  layers <- lattice_rendered_layers(rendered)

  testthat::expect_length(layers, 2L)
  widths <- list()
  for (layer in layers) {
    rows <- spread$value[spread$batch == layer$title]
    bins <- lattice_bins(rows, "Sturges", plot$panel.args.common$type)
    widths[[layer$title]] <- diff(bins$breaks)[1]
    cell <- panel_named(rendered$doc, layer$selectors)
    expect_bins(rendered, layer, plot, bins, column = cell[1], row = cell[2])
  }
  # The rule gives each panel bins of its own scale.
  testthat::expect_false(isTRUE(all.equal(widths$narrow, widths$wide)))
})

test_that("a histogram of a factor is read as a bar per level, named by it", {
  skip_if_no_lattice()
  answers <- factor(
    c("no", "yes", "yes", "maybe", "yes", "no"),
    levels = c("no", "maybe", "yes")
  )
  plot <- lattice::histogram(~answers)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  # lattice bins a factor one level to a bin, at the positions where the
  # axis names the levels. As bins they would be announced as "0.5 through
  # 1.5"; as bars they are announced by the names the chart shows.
  testthat::expect_identical(plot$x.limits, levels(answers))
  testthat::expect_equal(plot$panel.args.common$breaks, seq_len(4) - 0.5)
  testthat::expect_identical(layer$type, "bar")
  testthat::expect_identical(layer$orientation, "vert")
  testthat::expect_identical(field_of(layer$data, "x"), levels(answers))
  share <- as.numeric(100 * table(answers) / length(answers))
  testthat::expect_equal(field_of(layer$data, "y"), share)

  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, 3L)
  drawn <- rect_extents(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn((drawn$left + drawn$right) / 2, seq_len(3), attr(drawn, "x_unit"))
  expect_drawn(drawn$top, share, attr(drawn, "y_unit"))
})

test_that("breaks that put several levels in a bin keep a factor's bins as bins", {
  skip_if_no_lattice()
  answers <- factor(
    c("no", "yes", "yes", "maybe", "yes", "no"),
    levels = c("no", "maybe", "yes")
  )
  breaks <- c(0.5, 2.5, 3.5)
  plot <- lattice::histogram(~answers, breaks = breaks)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  # The first bin counts "no" and "maybe" together: no one name says what
  # it holds, so it is read by the positions it spans.
  testthat::expect_identical(plot$panel.args.common$type, "density")
  expect_bins(rendered, layer, plot, lattice_bins(as.numeric(answers), breaks, "density"))
})

test_that("a missing value counts towards the total a percent is taken of", {
  skip_if_no_lattice()
  gappy <- c(BINNED, NA, NA)
  plot <- lattice::histogram(~gappy)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  bins <- lattice_bins(gappy, plot$panel.args.common$breaks, "percent")
  expect_bins(rendered, layer, plot, bins)
  # lattice divides by every row, so the bins add up to the share present.
  testthat::expect_equal(sum(field_of(layer$data, "y")), 100 * 10 / 12)
})

# dotplot() -------------------------------------------------------------------

test_that("a dot plot with one value per level is read as dots, in level order", {
  skip_if_no_lattice()
  plot <- lattice::dotplot(fruit ~ sold, data = FRUIT)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(layer$type, "dot")
  testthat::expect_identical(layer$orientation, "horz")
  in_order <- FRUIT[order(FRUIT$fruit), ]
  testthat::expect_identical(field_of(layer$data, "y"), as.character(in_order$fruit))
  testthat::expect_equal(field_of(layer$data, "x"), in_order$sold)

  # The i-th dot in the document sits on level i, at value i.
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, nrow(FRUIT))
  testthat::expect_true(all(xml2::xml_name(nodes) == "use"))
  dots <- dot_centres(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn(dots$y, seq_len(nrow(FRUIT)), attr(dots, "y_unit"))
  expect_drawn(dots$x, in_order$sold, attr(dots, "x_unit"))
})

test_that("a vertical dot plot reads the level as x and the value as y", {
  skip_if_no_lattice()
  plot <- lattice::dotplot(sold ~ fruit, data = FRUIT)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_false(isTRUE(plot$panel.args.common$horizontal))
  testthat::expect_identical(layer$type, "dot")
  testthat::expect_identical(layer$orientation, "vert")
  in_order <- FRUIT[order(FRUIT$fruit), ]
  testthat::expect_identical(field_of(layer$data, "x"), as.character(in_order$fruit))
  testthat::expect_equal(field_of(layer$data, "y"), in_order$sold)

  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, nrow(FRUIT))
  dots <- dot_centres(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn(dots$x, seq_len(nrow(FRUIT)), attr(dots, "x_unit"))
  expect_drawn(dots$y, in_order$sold, attr(dots, "y_unit"))
})

test_that("a missing dot is left out and the others keep their levels", {
  skip_if_no_lattice()
  gappy <- FRUIT
  gappy$sold[gappy$fruit == "banana"] <- NA
  plot <- lattice::dotplot(fruit ~ sold, data = gappy)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(field_of(layer$data, "y"), c("apple", "cherry", "date"))
  testthat::expect_equal(field_of(layer$data, "x"), c(3, 2, 5))
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, 3L)
  dots <- dot_centres(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn(dots$y, c(1, 3, 4), attr(dots, "y_unit"))
  expect_drawn(dots$x, c(3, 2, 5), attr(dots, "x_unit"))
})

test_that("dotplot(VADeaths) reads a dot layer per column, named after it", {
  skip_if_no_lattice()
  plot <- lattice::dotplot(VADeaths)
  rendered <- render_lattice(plot)
  layers <- lattice_rendered_layers(rendered)

  testthat::expect_false(rendered$fallback)
  testthat::expect_length(layers, ncol(VADeaths))
  testthat::expect_identical(
    vapply(layers, function(layer) layer$name, ""),
    colnames(VADeaths)
  )
  frame <- drawn_frame(rendered$doc)
  for (j in seq_along(layers)) {
    layer <- layers[[j]]
    testthat::expect_identical(layer$type, "dot")
    testthat::expect_identical(layer$orientation, "horz")
    testthat::expect_identical(field_of(layer$data, "y"), rownames(VADeaths))
    testthat::expect_equal(field_of(layer$data, "x"), unname(VADeaths[, j]))

    # Each group's dots are its own: at the age groups, at its own rates.
    nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
    testthat::expect_length(nodes, nrow(VADeaths))
    dots <- dot_centres(nodes, frame, plot$x.limits, plot$y.limits)
    expect_drawn(dots$y, seq_len(nrow(VADeaths)), attr(dots, "y_unit"))
    expect_drawn(dots$x, unname(VADeaths[, j]), attr(dots, "x_unit"))
  }
})

test_that("a dot plot with several values on a level is read as points named by level", {
  skip_if_no_lattice()
  repeats <- data.frame(
    fruit = factor(c("cherry", "apple", "cherry", "banana", "apple")),
    sold = c(4, 2, 6, 3, 5)
  )
  plot <- lattice::dotplot(fruit ~ sold, data = repeats)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  testthat::expect_identical(layer$type, "point")
  labels <- field_of(layer$data, "yLabel")
  # Every row once, each point on its own level's position.
  testthat::expect_setequal(
    paste(labels, field_of(layer$data, "x")),
    paste(repeats$fruit, repeats$sold)
  )
  testthat::expect_equal(field_of(layer$data, "y"), match(labels, levels(repeats$fruit)))

  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  testthat::expect_length(nodes, nrow(repeats))
  dots <- dot_centres(nodes, drawn_frame(rendered$doc), plot$x.limits, plot$y.limits)
  expect_drawn(dots$y, field_of(layer$data, "y"), attr(dots, "y_unit"))
  expect_drawn(dots$x, field_of(layer$data, "x"), attr(dots, "x_unit"))
})

# lattice_prepare(): the order changes, the drawing does not -----------------

test_that("sorting the rows changes nothing a reader sees", {
  skip_if_no_lattice()
  # Boxes sized by their rows, some of them missing; and a level with
  # nothing but missing values, which draws no box.
  varied <- data.frame(
    shop = factor(rep(c("a", "b", "c"), c(6, 5, 4))),
    sold = c(3, NA, 5, 9, 4, NA, 2, 8, 6, 7, 1, 4, NA, 5, 12)
  )
  emptied <- transform(varied, sold = ifelse(shop == "b", NA, sold))
  charts <- list(
    bars = lattice::barchart(
      fruit ~ sold,
      data = FRUIT,
      col = c("gold", "red", "brown", "purple"),
      border = c("black", "grey")
    ),
    missing = lattice::barchart(
      sold ~ fruit,
      data = rbind(FRUIT, data.frame(fruit = "apple", sold = NA)),
      col = c("gold", "red", "brown", "purple", "green")
    ),
    panels = lattice::barchart(
      shop ~ sold | season,
      data = SALES,
      col = c("gold", "red", "brown")
    ),
    dodged = lattice::barchart(shop ~ sold, groups = season, data = SALES),
    stacked = lattice::barchart(shop ~ profit, groups = season, data = PROFIT, stack = TRUE),
    dots = lattice::dotplot(
      fruit ~ sold,
      data = FRUIT,
      col = c("gold", "red", "brown", "purple"),
      pch = 1:4,
      lty = 1:4
    ),
    grouped = lattice::dotplot(VADeaths),
    # Joined by lines, which run through the rows in their order.
    joined = lattice::dotplot(
      fruit ~ sold,
      data = rbind(FRUIT, transform(FRUIT, sold = sold + 1)),
      groups = rep(c("first", "second"), each = nrow(FRUIT)),
      type = "o"
    ),
    spikes = lattice::xyplot(
      sold ~ as.numeric(fruit),
      data = FRUIT,
      type = c("p", "h"),
      col = c("gold", "red", "brown", "purple")
    ),
    boxes = lattice::bwplot(sold ~ shop, data = varied, varwidth = TRUE),
    empty_box = lattice::bwplot(shop ~ sold, data = emptied)
  )

  for (name in names(charts)) {
    plot <- charts[[name]]
    native <- drawn_marks(maidr:::lattice_draw_scene(plot))
    sorted <- drawn_marks(maidr:::lattice_draw_scene(maidr:::lattice_prepare(plot)))
    testthat::expect_identical(sort(sorted), sort(native), label = name)
  }
})

test_that("sorting the rows reorders the bars, each keeping its own colour", {
  skip_if_no_lattice()
  colours <- c("gold", "red", "brown", "purple")
  plot <- lattice::barchart(fruit ~ sold, data = FRUIT, col = colours)
  rendered <- render_lattice(plot)
  layer <- only_layer(rendered)

  # lattice colours the rows in the order they come, banana first; the
  # document now holds the bars apple first, and each still in its row's
  # colour.
  nodes <- lattice_selector_nodes(rendered$doc, layer$selectors)
  rgb <- grDevices::col2rgb(colours[match(field_of(layer$data, "y"), FRUIT$fruit)])
  testthat::expect_identical(
    xml2::xml_attr(nodes, "fill"),
    sprintf("rgb(%d,%d,%d)", rgb[1, ], rgb[2, ], rgb[3, ])
  )
  testthat::expect_false(identical(
    drawn_marks(maidr:::lattice_draw_scene(plot)),
    drawn_marks(maidr:::lattice_draw_scene(maidr:::lattice_prepare(plot)))
  ))
})
