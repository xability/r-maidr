# Reading a multi-panel lattice chart (#333)
#
# A conditioned trellis chart draws one panel per packet, laid out on a
# grid: bottom row first unless `as.table = TRUE`, cells left empty by
# `skip` or by a layout larger than the packets, and only one page of a
# chart laid out over several. It is read as a MAIDR figure of subplots on
# the same grid, top row first, each holding the layers its panel drew and
# titled with its strip.
#
# Every claim is checked against something the code under test does not
# compute: which panel a subplot is and where it sits against the panels in
# the exported SVG (the border rectangle its selector names, and the strip
# lattice drew over that panel); what a subplot holds against the rows of
# the data its strip names; and the marks each layer's selector matches
# against where those rows are drawn.

skip_slow_file_on_cran()

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

#' Render a chart that must be read interactively rather than as an image
pn_render <- function(plot) {
  rendered <- render_lattice(plot)
  testthat::expect_false(
    rendered$fallback,
    label = paste(
      "fell back:",
      paste(rendered$orchestrator$unsupported_reasons(), collapse = "; ")
    )
  )
  rendered
}

#' Points as a two-column matrix
pn_matrix <- function(points) {
  cbind(
    x = vapply(points, function(p) as.numeric(p$x), numeric(1)),
    y = vapply(points, function(p) as.numeric(p$y), numeric(1))
  )
}

#' The grid of a rendering: one row of cells per subplot row
pn_grid <- function(rendered) {
  rendered$schema$subplots
}

#' Every cell of a rendering, in reading order, with its grid position
pn_cells <- function(rendered) {
  cells <- list()
  for (row in seq_along(pn_grid(rendered))) {
    for (column in seq_along(pn_grid(rendered)[[row]])) {
      cell <- pn_grid(rendered)[[row]][[column]]
      cell$at <- c(row, column)
      cells[[length(cells) + 1L]] <- cell
    }
  }
  cells
}

#' The lattice layout cell a subplot's selector names, from the id of the
#' panel border it selects
pn_panel_of <- function(cell) {
  unescaped <- gsub("\\", "", cell$selector, fixed = TRUE)
  pattern <- "border\\.panel\\.([0-9]+)\\.([0-9]+)\\.1 > rect$"
  m <- regmatches(unescaped, regexec(pattern, unescaped))[[1]]
  testthat::expect_length(m, 3L)
  c(column = as.integer(m[2]), row = as.integer(m[3]))
}

#' The one rectangle a selector matches, as numbers
pn_rect <- function(doc, selector) {
  nodes <- lattice_selector_nodes(doc, selector)
  testthat::expect_length(nodes, 1L)
  vapply(
    c(x = "x", y = "y", width = "width", height = "height"),
    function(attr) as.numeric(xml2::xml_attr(nodes[[1]], attr)),
    numeric(1)
  )
}

#' The strip text lattice drew over one panel, one level per conditioning
#' variable in formula order, joined as the reading joins them
#'
#' A factor's level is drawn right of the strip (`textr`), a shingle's name
#' left of it (`textl`); with several variables each strip is numbered by
#' the variable's place in the formula (`given.<k>`).
pn_strip_text <- function(doc, column, row) {
  nodes <- xml2::xml_find_all(doc, "//*[local-name()='text']")
  ids <- xml2::xml_attr(nodes, "id")
  pattern <- sprintf(
    "^maidr\\.text[lr](?:\\.given\\.([0-9]+))?\\.strip\\.%d\\.%d\\.1\\.1\\.text$",
    column, row
  )
  hit <- grepl(pattern, ids, perl = TRUE)
  given <- suppressWarnings(as.integer(sub(pattern, "\\1", ids[hit], perl = TRUE)))
  paste(xml2::xml_text(nodes[hit])[order(given)], collapse = " & ")
}

#' Where every `<use>` a selector matches is drawn
pn_use_positions <- function(doc, selector) {
  nodes <- lattice_selector_nodes(doc, selector)
  cbind(
    x = as.numeric(xml2::xml_attr(nodes, "x")),
    y = as.numeric(xml2::xml_attr(nodes, "y"))
  )
}

#' Expect device coordinates to be one increasing linear function of values
pn_expect_drawn_at <- function(px, values) {
  testthat::expect_identical(length(px), length(values))
  fit <- stats::lm(px ~ values)
  testthat::expect_gt(unname(stats::coef(fit)[2]), 0)
  testthat::expect_lt(max(abs(stats::residuals(fit))), 0.02)
}

#' Expect a subplot to be the panel of its strip, holding that packet's rows
#'
#' `rows_of(title)` gives the rows of the data a strip title names, as a
#' data frame of the x and y drawn. The subplot's selector must name
#' exactly one panel border; its layers' titles must be the strip lattice
#' drew over that panel -- or, for a shingle, whose strip shows its name
#' and draws its interval as a bar, start with it; its points must be those
#' rows, in their order, each drawn at its value and all inside that panel.
pn_expect_panel <- function(rendered, cell, rows_of, shingle = FALSE) {
  doc <- rendered$doc
  testthat::expect_identical(lattice_selector_counts(doc, cell$selector), 1L)
  panel <- pn_panel_of(cell)
  strip <- pn_strip_text(doc, panel[["column"]], panel[["row"]])
  border <- pn_rect(doc, cell$selector)

  testthat::expect_length(cell$layers, 1L)
  layer <- cell$layers[[1]]
  if (shingle) {
    testthat::expect_true(startsWith(layer$title, paste0(strip, " [ ")))
  } else {
    testthat::expect_identical(layer$title, strip)
  }
  rows <- rows_of(layer$title)
  testthat::expect_equal(unname(pn_matrix(layer$data)), unname(as.matrix(rows)))

  drawn <- pn_use_positions(doc, layer$selectors)
  testthat::expect_identical(nrow(drawn), nrow(rows))
  if (nrow(rows) > 1L && length(unique(rows[[1]])) > 1L) {
    pn_expect_drawn_at(drawn[, "x"], rows[[1]])
  }
  testthat::expect_true(all(
    drawn[, "x"] >= border[["x"]] & drawn[, "x"] <= border[["x"]] + border[["width"]] &
      drawn[, "y"] >= border[["y"]] & drawn[, "y"] <= border[["y"]] + border[["height"]]
  ))
  invisible(border)
}

#' Expect the grid's rows to run top to bottom and its cells left to right
#' on the page, as the panels their selectors name
pn_expect_reading_order <- function(rendered) {
  borders <- lapply(pn_grid(rendered), function(row) {
    lapply(Filter(function(cell) !is.null(cell$selector), row), function(cell) {
      pn_rect(rendered$doc, cell$selector)
    })
  })
  for (row in borders) {
    x <- vapply(row, function(b) b[["x"]], numeric(1))
    testthat::expect_false(is.unsorted(x, strictly = TRUE))
  }
  # The page is exported with y growing upward: a lower row sits lower.
  tops <- vapply(borders, function(row) row[[1]][["y"]], numeric(1))
  testthat::expect_false(is.unsorted(rev(tops), strictly = TRUE))
}

pn_mt <- within(mtcars, {
  cyl <- factor(cyl)
  am <- factor(am, labels = c("auto", "manual"))
  gear <- factor(gear)
})

#' The rows of `pn_mt` a strip title of `cyl`, or of `cyl & am`, names
pn_cyl_am_rows <- function(title) {
  levels <- strsplit(title, " & ", fixed = TRUE)[[1]]
  keep <- pn_mt$cyl == levels[1]
  if (length(levels) > 1L) {
    keep <- keep & pn_mt$am == levels[2]
  }
  pn_mt[keep, c("wt", "mpg")]
}

# ------------------------------------------------------------------------------
# One and two conditioning variables
# ------------------------------------------------------------------------------

test_that("a panel per level is one subplot each, titled by its strip and holding its rows", {
  skip_if_no_lattice()
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl, pn_mt))

  # Three panels side by side on a landscape page.
  testthat::expect_length(pn_grid(r), 1L)
  testthat::expect_length(pn_grid(r)[[1]], 3L)
  for (cell in pn_cells(r)) {
    pn_expect_panel(r, cell, pn_cyl_am_rows)
  }
  titles <- vapply(pn_cells(r), function(cell) cell$layers[[1]]$title, "")
  testthat::expect_setequal(titles, levels(pn_mt$cyl))
  pn_expect_reading_order(r)
})

test_that("two conditioning variables are read top row first, as.table or not", {
  skip_if_no_lattice()
  for (as_table in c(FALSE, TRUE)) {
    r <- pn_render(lattice::xyplot(mpg ~ wt | cyl * am, pn_mt, as.table = as_table))

    testthat::expect_identical(lengths(pn_grid(r)), c(3L, 3L))
    for (cell in pn_cells(r)) {
      pn_expect_panel(r, cell, pn_cyl_am_rows)
    }
    pn_expect_reading_order(r)

    # lattice fills the bottom row first unless as.table: the first
    # variable runs along a row, the second from row to row.
    top <- vapply(pn_grid(r)[[1]], function(cell) cell$layers[[1]]$title, "")
    expected_am <- if (as_table) "auto" else "manual"
    testthat::expect_identical(top, paste(levels(pn_mt$cyl), expected_am, sep = " & "))
  }
})

test_that("each subplot names exactly one panel border, and the panels are all named", {
  skip_if_no_lattice()
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl * am, pn_mt))

  selectors <- vapply(pn_cells(r), function(cell) cell$selector, "")
  testthat::expect_false(anyDuplicated(selectors) > 0L)
  testthat::expect_identical(lattice_selector_counts(r$doc, selectors), rep(1L, 6))
  borders <- xml2::xml_find_all(
    r$doc,
    "//*[local-name()='g' and starts-with(@id, 'maidr.border.panel.')]/*[local-name()='rect']"
  )
  testthat::expect_length(borders, length(selectors))
})

test_that("layer ids are unique across the figure and run in reading order", {
  skip_if_no_lattice()
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl * am, pn_mt, groups = gear, type = c("p", "l")))

  ids <- unlist(lapply(pn_cells(r), function(cell) vapply(cell$layers, `[[`, "", "id")))
  testthat::expect_gt(length(ids), 6L)
  testthat::expect_false(anyDuplicated(ids) > 0L)
  numbers <- as.integer(sub("^maidr-layer-", "", ids))
  testthat::expect_false(is.unsorted(numbers, strictly = TRUE))
})

# ------------------------------------------------------------------------------
# Layouts with empty cells
# ------------------------------------------------------------------------------

test_that("a layout with a cell to spare drops the empty cell at the end of its row", {
  skip_if_no_lattice()
  for (as_table in c(FALSE, TRUE)) {
    r <- pn_render(lattice::xyplot(mpg ~ wt | cyl, pn_mt, layout = c(2, 2), as.table = as_table))

    # Without as.table the bottom row fills first, so the short row is the top one.
    lengths_expected <- if (as_table) c(2L, 1L) else c(1L, 2L)
    testthat::expect_identical(lengths(pn_grid(r)), lengths_expected)
    for (cell in pn_cells(r)) {
      pn_expect_panel(r, cell, pn_cyl_am_rows)
    }
    pn_expect_reading_order(r)
    # The cells run in packet order from wherever lattice starts.
    order <- if (as_table) c(1L, 2L, 3L) else c(3L, 1L, 2L)
    titles <- vapply(pn_cells(r), function(cell) cell$layers[[1]]$title, "")
    testthat::expect_identical(titles, levels(pn_mt$cyl)[order])
  }
})

test_that("a layout of more rows than the panels fill leaves no empty row", {
  skip_if_no_lattice()
  # Four rows for three panels: lattice leaves the top one empty.
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl, pn_mt, layout = c(1, 4)))

  testthat::expect_identical(lengths(pn_grid(r)), c(1L, 1L, 1L))
  for (cell in pn_cells(r)) {
    testthat::expect_length(cell$layers, 1L)
    pn_expect_panel(r, cell, pn_cyl_am_rows)
  }
  pn_expect_reading_order(r)
  testthat::expect_identical(pn_grid(r)[[1]][[1]]$layers[[1]]$title, "8")
  testthat::expect_identical(
    vapply(pn_cells(r), function(cell) cell$id, ""),
    sprintf("maidr-subplot-%d-1", 1:3)
  )
})

test_that("a skipped cell is left out of its row, so every subplot can be measured", {
  skip_if_no_lattice()
  # Three columns, the second position skipped: 4, <skip>, 6 along the
  # bottom row, and 8 above. maidr.js lays a figure out -- which subplot is
  # first, which way Up goes -- by measuring every subplot's panel on the
  # page; a skipped cell has no panel, and one it cannot measure sends it
  # back to array order, where Up moves down.
  for (skip in list(c(FALSE, TRUE, FALSE), c(TRUE, FALSE, FALSE))) {
    r <- pn_render(lattice::xyplot(
      mpg ~ wt | cyl, pn_mt,
      layout = c(3, 2), skip = skip
    ))

    testthat::expect_identical(lengths(pn_grid(r)), c(1L, 2L))
    for (cell in pn_cells(r)) {
      pn_expect_panel(r, cell, pn_cyl_am_rows)
    }
    pn_expect_reading_order(r)
    bottom <- pn_grid(r)[[2]]
    titles <- vapply(bottom, function(cell) cell$layers[[1]]$title, "")
    testthat::expect_identical(titles, c("4", "6"))
    # The cells are still the panels lattice drew, in their own columns.
    columns <- vapply(bottom, function(cell) pn_panel_of(cell)[["column"]], 1L)
    testthat::expect_identical(columns, if (skip[1]) 2:3 else c(1L, 3L))
  }
})

# A cell skipped before a panel in its row. Ground truth is where lattice
# drew each panel: the x of the border rectangle its subplot's selector
# names. The frontend keeps a reader's place in the row when Up or Down
# changes row, so two panels at the same place in adjacent rows must be
# drawn one above the other -- the same x.

gap_mt <- within(mtcars, {
  cyl <- factor(cyl)
  gear <- factor(gear)
})

gap_x <- function(doc, selector) {
  nodes <- lattice_selector_nodes(doc, selector)
  testthat::expect_length(nodes, 1L)
  as.numeric(xml2::xml_attr(nodes[[1]], "x"))
}

gap_expect_columns_kept <- function(plot) {
  r <- render_lattice(plot)
  testthat::expect_false(r$fallback)
  grid <- r$schema$subplots
  pairs <- 0L
  for (i in seq_len(length(grid) - 1L)) {
    for (k in seq_len(min(length(grid[[i]]), length(grid[[i + 1L]])))) {
      above <- grid[[i]][[k]]
      below <- grid[[i + 1L]][[k]]
      # Only panels lattice drew are compared: their borders are its drawing.
      if (length(above$layers) && length(below$layers)) {
        pairs <- pairs + 1L
        testthat::expect_equal(
          gap_x(r$doc, above$selector), gap_x(r$doc, below$selector),
          label = sprintf("x of %s (above %s)", above$layers[[1]]$title, below$layers[[1]]$title)
        )
      }
    }
  }
  testthat::expect_gt(pairs, 0L)
  invisible(r)
}

test_that("a panel after a skipped cell stays under the panel lattice drew above it", {
  skip_if_no_lattice()
  # Top 6, 8; bottom <skip>, 4 -- and with as.table, top <skip>, 4; bottom 6, 8.
  for (as_table in c(FALSE, TRUE)) {
    gap_expect_columns_kept(lattice::xyplot(
      mpg ~ wt | cyl, gap_mt,
      layout = c(2, 2), skip = c(TRUE, FALSE, FALSE, FALSE), as.table = as_table
    ))
  }
  # Top <skip>, 5; bottom 3, 4.
  gap_expect_columns_kept(lattice::xyplot(
    mpg ~ wt | gear, gap_mt,
    layout = c(2, 2), skip = c(FALSE, FALSE, TRUE, FALSE)
  ))
  # A gap in the middle of a row: top 4, <skip>, 6; bottom 1, 2, 3.
  gap_expect_columns_kept(lattice::xyplot(
    mpg ~ wt | factor(carb), mtcars, subset = carb != 8,
    layout = c(3, 2), skip = c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)
  ))
})

test_that("a trailing empty cell is still left out, and a skipped cell kept is empty", {
  skip_if_no_lattice()
  r <- render_lattice(lattice::xyplot(mpg ~ wt | cyl, gap_mt, layout = c(2, 2)))
  testthat::expect_identical(lengths(r$schema$subplots), c(1L, 2L))

  r <- gap_expect_columns_kept(lattice::xyplot(
    mpg ~ wt | cyl, gap_mt, layout = c(2, 2), skip = c(TRUE, FALSE, FALSE, FALSE)
  ))
  testthat::expect_identical(lengths(r$schema$subplots), c(2L, 2L))
  kept <- r$schema$subplots[[2]][[1]]
  testthat::expect_length(kept$layers, 0L)
  # Its selector names one shape the frontend can measure.
  testthat::expect_identical(lattice_selector_counts(r$doc, kept$selector), 1L)
})

test_that("an empty packet is a subplot with no layers whose panel is still drawn", {
  skip_if_no_lattice()
  # No car has three gears and a manual gearbox, or five gears and an automatic one.
  r <- pn_render(lattice::xyplot(mpg ~ wt | gear * am, pn_mt))
  empty <- 0L
  for (cell in pn_cells(r)) {
    panel <- pn_panel_of(cell)
    strip <- pn_strip_text(r$doc, panel[["column"]], panel[["row"]])
    levels <- strsplit(strip, " & ", fixed = TRUE)[[1]]
    rows <- pn_mt[pn_mt$gear == levels[1] & pn_mt$am == levels[2], c("wt", "mpg")]
    if (nrow(rows) == 0L) {
      empty <- empty + 1L
      testthat::expect_length(cell$layers, 0L)
      testthat::expect_identical(lattice_selector_counts(r$doc, cell$selector), 1L)
    } else {
      pn_expect_panel(r, cell, function(title) rows)
    }
  }
  testthat::expect_identical(empty, 2L)
})

# ------------------------------------------------------------------------------
# Reordered and permuted packets, shingles
# ------------------------------------------------------------------------------

test_that("index.cond reorders the panels, each still read with its own packet", {
  skip_if_no_lattice()
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl, pn_mt, index.cond = list(c(3, 1, 2))))

  titles <- vapply(pn_cells(r), function(cell) cell$layers[[1]]$title, "")
  testthat::expect_identical(titles, levels(pn_mt$cyl)[c(3, 1, 2)])
  for (cell in pn_cells(r)) {
    pn_expect_panel(r, cell, pn_cyl_am_rows)
  }
  pn_expect_reading_order(r)
})

test_that("perm.cond swaps which variable runs along a row, titles kept in formula order", {
  skip_if_no_lattice()
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl * am, pn_mt, perm.cond = c(2, 1)))

  # am now runs along a row and cyl from row to row: three rows of two.
  testthat::expect_identical(lengths(pn_grid(r)), c(2L, 2L, 2L))
  for (cell in pn_cells(r)) {
    pn_expect_panel(r, cell, pn_cyl_am_rows)
  }
  pn_expect_reading_order(r)
  top <- vapply(pn_grid(r)[[1]], function(cell) cell$layers[[1]]$title, "")
  testthat::expect_identical(top, c("8 & auto", "8 & manual"))
})

test_that("a shingle's panels are titled by its name and interval and hold the rows in it", {
  skip_if_no_lattice()
  displacement <- lattice::equal.count(mtcars$disp, 3)
  r <- pn_render(lattice::xyplot(mpg ~ wt | displacement, mtcars))
  intervals <- levels(displacement)

  cells <- pn_cells(r)
  testthat::expect_length(cells, length(intervals))
  for (i in seq_along(cells)) {
    cell <- cells[[i]]
    layer <- cell$layers[[1]]
    bounds <- intervals[[i]]
    testthat::expect_identical(
      layer$title,
      sprintf("displacement [ %s, %s ]", format(bounds[1]), format(bounds[2]))
    )
    # The intervals overlap: a car can be in two panels.
    inside <- mtcars$disp >= bounds[1] & mtcars$disp <= bounds[2]
    pn_expect_panel(r, cell, function(title) mtcars[inside, c("wt", "mpg")], shingle = TRUE)
  }
})

# ------------------------------------------------------------------------------
# Axes per panel
# ------------------------------------------------------------------------------

test_that("with relation = 'free' each panel's axes span its own drawn extent", {
  skip_if_no_lattice()
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl, pn_mt, scales = list(relation = "free")))

  mins <- numeric(0)
  for (cell in pn_cells(r)) {
    layer <- cell$layers[[1]]
    rows <- pn_cyl_am_rows(layer$title)
    drawn <- pn_use_positions(r$doc, layer$selectors)
    fit_x <- stats::coef(stats::lm(drawn[, "x"] ~ rows$wt))
    fit_y <- stats::coef(stats::lm(drawn[, "y"] ~ rows$mpg))
    border <- pn_rect(r$doc, cell$selector)
    to_x <- function(px) (px - fit_x[[1]]) / fit_x[[2]]
    to_y <- function(px) (px - fit_y[[1]]) / fit_y[[2]]

    right <- border[["x"]] + border[["width"]]
    top <- border[["y"]] + border[["height"]]
    testthat::expect_equal(layer$axes$x$min, to_x(border[["x"]]), tolerance = 1e-3)
    testthat::expect_equal(layer$axes$x$max, to_x(right), tolerance = 1e-3)
    testthat::expect_equal(layer$axes$y$min, to_y(border[["y"]]), tolerance = 1e-3)
    testthat::expect_equal(layer$axes$y$max, to_y(top), tolerance = 1e-3)

    # And steps as the ticks this panel draws.
    panel <- pn_panel_of(cell)
    ticks <- lattice_selector_nodes(
      r$doc,
      maidr:::lattice_grob_selector(
        sprintf("maidr.ticks.bottom.panel.%d.%d", panel[["column"]], panel[["row"]]),
        "polyline"
      )
    )
    at <- vapply(xml2::xml_attr(ticks, "points"), function(p) {
      as.numeric(strsplit(strsplit(p, " ")[[1]][1], ",")[[1]][1])
    }, numeric(1))
    steps <- diff(to_x(unname(at)))
    testthat::expect_equal(rep(layer$axes$x$tickStep, length(steps)), steps, tolerance = 1e-3)
    mins <- c(mins, layer$axes$x$min)
  }
  # Free scales: no two panels share their range.
  testthat::expect_false(anyDuplicated(round(mins, 6)) > 0L)
})

# ------------------------------------------------------------------------------
# Groups across panels
# ------------------------------------------------------------------------------

test_that("each panel reads the groups it drew, with the marks of that panel and group", {
  skip_if_no_lattice()
  # Automatic cars have three and four gears, manual ones four and five: no
  # panel draws every group.
  d <- within(mtcars, am <- factor(am, labels = c("auto", "manual")))
  r <- pn_render(lattice::xyplot(mpg ~ wt | am, d, groups = gear))

  names <- list()
  for (cell in pn_cells(r)) {
    panel <- pn_panel_of(cell)
    strip <- pn_strip_text(r$doc, panel[["column"]], panel[["row"]])
    border <- pn_rect(r$doc, cell$selector)
    for (layer in cell$layers) {
      testthat::expect_identical(layer$title, strip)
      rows <- d$am == strip & d$gear == as.numeric(layer$name)
      testthat::expect_equal(
        unname(pn_matrix(layer$data)),
        unname(as.matrix(d[rows, c("wt", "mpg")]))
      )
      drawn <- pn_use_positions(r$doc, layer$selectors)
      testthat::expect_identical(nrow(drawn), sum(rows))
      pn_expect_drawn_at(drawn[, "y"], d$mpg[rows])
      testthat::expect_true(all(
        drawn[, "x"] >= border[["x"]] & drawn[, "x"] <= border[["x"]] + border[["width"]]
      ))
    }
    names[[strip]] <- vapply(cell$layers, `[[`, "", "name")
  }
  testthat::expect_identical(names[["auto"]], c("3", "4"))
  testthat::expect_identical(names[["manual"]], c("4", "5"))
})

# ------------------------------------------------------------------------------
# Pages
# ------------------------------------------------------------------------------

test_that("a chart laid out over several pages is read from its first, with a warning", {
  skip_if_no_lattice()
  old <- options(maidr.fallback_warning = TRUE)
  on.exit(options(old), add = TRUE)
  d <- within(mtcars, band <- cut(disp, 5))
  chart <- lattice::xyplot(mpg ~ wt | band, d, layout = c(2, 2))

  testthat::expect_warning(
    r <- render_lattice(chart),
    "laid out on 2 pages. Only the first page is rendered interactively",
    fixed = TRUE
  )
  testthat::expect_false(r$fallback)
  testthat::expect_identical(lengths(pn_grid(r)), c(2L, 2L))
  titles <- vapply(pn_cells(r), function(cell) cell$layers[[1]]$title, "")
  testthat::expect_setequal(titles, levels(d$band)[1:4])
  for (cell in pn_cells(r)) {
    pn_expect_panel(r, cell, function(title) d[d$band == title, c("wt", "mpg")])
  }
  # The SVG holds the first page only.
  strips <- xml2::xml_text(xml2::xml_find_all(
    r$doc,
    "//*[local-name()='text' and starts-with(@id, 'maidr.textr.strip.')]"
  ))
  testthat::expect_setequal(strips, levels(d$band)[1:4])

  # One panel to a page: the first page's panel is still titled by its strip.
  testthat::expect_warning(
    r <- render_lattice(lattice::xyplot(mpg ~ wt | cyl, pn_mt, layout = c(1, 1))),
    "laid out on 3 pages",
    fixed = TRUE
  )
  cells <- pn_cells(r)
  testthat::expect_length(cells, 1L)
  testthat::expect_null(cells[[1]]$selector)
  testthat::expect_identical(cells[[1]]$layers[[1]]$title, "4")
  testthat::expect_equal(
    unname(pn_matrix(cells[[1]]$layers[[1]]$data)),
    unname(as.matrix(pn_cyl_am_rows("4")))
  )
})

test_that("the multi-page warning is not raised when fallback warnings are off", {
  skip_if_no_lattice()
  old <- options(maidr.fallback_warning = FALSE)
  on.exit(options(old), add = TRUE)
  testthat::expect_no_warning(
    r <- render_lattice(lattice::xyplot(mpg ~ wt | cyl, pn_mt, layout = c(1, 1)))
  )
  testthat::expect_false(r$fallback)
})

test_that("a conditioned chart drawing one panel is titled by its strip", {
  skip_if_no_lattice()
  chart <- lattice::xyplot(mpg ~ wt | cyl, pn_mt, subset = cyl == "6", main = "Six cylinders")
  r <- pn_render(chart)

  cells <- pn_cells(r)
  testthat::expect_length(cells, 1L)
  layer <- cells[[1]]$layers[[1]]
  testthat::expect_identical(layer$title, pn_strip_text(r$doc, 1, 1))
  testthat::expect_identical(layer$title, "6")
  testthat::expect_identical(r$schema$title, "Six cylinders")
})

test_that("the panels of an extended formula drawn outer are titled by their variable", {
  skip_if_no_lattice()
  # `outer = TRUE` conditions on the formula's variables through a variable
  # lattice leaves unnamed, as it leaves an unconditioned chart's; its
  # strips still name each panel's variable.
  d <- data.frame(x = 1:5, a = c(2, 4, 3, 5, 1), b = c(9, 7, 8, 6, 10))
  r <- pn_render(lattice::xyplot(a + b ~ x, d, outer = TRUE))

  cells <- pn_cells(r)
  testthat::expect_length(cells, 2L)
  for (cell in cells) {
    layer <- cell$layers[[1]]
    column <- pn_panel_of(cell)[["column"]]
    row <- pn_panel_of(cell)[["row"]]
    testthat::expect_identical(layer$title, pn_strip_text(r$doc, column, row))
    testthat::expect_true(layer$title %in% c("a", "b"))
    testthat::expect_equal(unname(pn_matrix(layer$data)), unname(cbind(d$x, d[[layer$title]])))
  }

  # Superposed rather than outer, the one panel stays untitled.
  r <- pn_render(lattice::xyplot(a + b ~ x, d))
  titles <- vapply(lattice_rendered_layers(r), `[[`, "", "title")
  testthat::expect_true(all(titles == ""))
})

# ------------------------------------------------------------------------------
# Titles
# ------------------------------------------------------------------------------

test_that("the figure's title and subtitle are main and sub as lattice draws them", {
  skip_if_no_lattice()
  drawn_text <- function(doc, which) {
    xml2::xml_text(xml2::xml_find_all(
      doc,
      sprintf("//*[local-name()='text' and @id='maidr.%s.1.1.text']", which)
    ))
  }

  r <- pn_render(lattice::xyplot(
    mpg ~ wt, mtcars,
    main = list(label = "Fuel economy", cex = 2),
    sub = list("by weight", col = "grey")
  ))
  testthat::expect_identical(r$schema$title, drawn_text(r$doc, "main"))
  testthat::expect_identical(r$schema$subtitle, drawn_text(r$doc, "sub"))
  testthat::expect_identical(r$schema$title, "Fuel economy")
  # An unconditioned chart's one layer carries the chart's title.
  testthat::expect_identical(lattice_rendered_layers(r)[[1]]$title, "Fuel economy")

  # An expression is drawn as mathematics; it is read as it was written.
  title <- expression(sqrt(x) ~ "against" ~ beta[1])
  r <- pn_render(lattice::xyplot(mpg ~ wt, mtcars, main = title, sub = quote(alpha^2)))
  testthat::expect_identical(r$schema$title, paste(deparse(title[[1]]), collapse = " "))
  testthat::expect_identical(r$schema$subtitle, "alpha^2")

  # Without main or sub, the figure has neither.
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl, pn_mt))
  testthat::expect_null(r$schema$title)
  testthat::expect_null(r$schema$subtitle)
  testthat::expect_length(xml2::xml_find_all(r$doc, "//*[@id='maidr.main.1']"), 0L)

  # A conditioned chart's figure keeps its main, and each panel its strip.
  r <- pn_render(lattice::xyplot(mpg ~ wt | cyl, pn_mt, main = "By cylinders"))
  testthat::expect_identical(r$schema$title, "By cylinders")
  titles <- vapply(pn_cells(r), function(cell) cell$layers[[1]]$title, "")
  testthat::expect_identical(titles, levels(pn_mt$cyl))
})
