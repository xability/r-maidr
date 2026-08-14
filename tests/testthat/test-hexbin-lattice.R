# `geom_hex()` is a lattice of counted cells, not a heatmap (issue #136)
#
# Hexagons tessellate because alternate rows are offset by half a cell, and
# that one fact is why this is a layer type of its own rather than a heatmap
# with different cells: a bin's column index is not its position, so bin 3 of
# one row and bin 3 of the next sit at different x. Read as `heat` the chart
# would navigate perfectly well and put every bin past the first row on the
# wrong coordinate.
#
# Two things then have to hold together, and neither is visible from the
# announcement alone:
#
#   * the rows are ragged -- `stat_binhex()` emits only the bins that hold
#     something, so the lattice is genuinely uneven and padding it would put
#     cells on the chart that were never drawn;
#   * the selectors have to follow the regrouping. `stat_binhex()` does emit
#     its rows bottom-first today, so a selector list left in document order
#     would pass -- and would be undetectable the moment that stopped, since
#     a hexbin announces centres and has no index to contradict.
#
# So the regrouping is tested directly, on a deliberately shuffled frame,
# rather than through a chart that happens to arrive already sorted.

skip_if_no_hex <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("hexbin")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

hex_aes <- ggplot2::aes(x = x, y = y)

#' A reproducible cloud, dense enough to leave the lattice uneven
hex_frame <- function(n = 200) {
  set.seed(1)
  data.frame(x = stats::rnorm(n), y = stats::rnorm(n))
}

hex_plot <- function(bins = 4, n = 200) {
  ggplot2::ggplot(hex_frame(n), hex_aes) + ggplot2::geom_hex(bins = bins)
}

#' Render a plot and return its whole schema, plus the drawn SVG
hex_render_all <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  testthat::expect_length(raw, 1)
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  schema <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  opening <- regexpr("<svg", html, fixed = TRUE)
  closing <- regexpr("</svg>", html, fixed = TRUE)
  doc <- xml2::read_xml(substr(html, opening, closing + 5L))
  xml2::xml_ns_strip(doc)

  list(subplots = schema$subplots, svg = doc)
}

#' Render a single-panel plot and return the one layer it emits
hex_render <- function(plot) {
  rendered <- hex_render_all(plot)
  list(layer = rendered$subplots[[1]][[1]]$layers[[1]], svg = rendered$svg)
}

#' The bins in the order the frontend flattens them
hex_bins <- function(layer) {
  unlist(layer$data, recursive = FALSE)
}

test_that("a hexbin is its own layer type, not a heatmap", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("hexbin")

  # Before, GeomHex matched no branch and the layer fell through to the
  # unknown processor -- the chart rendered as a static image with nothing
  # to read. Reading it as `heat` would have been worse than that.
  plot <- hex_plot()
  adapter <- maidr:::Ggplot2Adapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "hexbin"
  )

  # The neighbouring rectangular binning keeps its own answer.
  binned <- ggplot2::ggplot(hex_frame(), hex_aes) + ggplot2::geom_bin_2d(bins = 4)
  testthat::expect_equal(
    adapter$detect_layer_type(binned$layers[[1]], binned), "heat"
  )
})

test_that("the lattice is read as rows, bottom first", {
  skip_if_no_hex()

  # Bottom-first because the frontend's UPWARD steps to the *next* row index,
  # the same convention the heatmap follows. Inverted, the chart would flip
  # under the cursor while every announcement stayed true.
  layer <- hex_render(hex_plot())$layer

  testthat::expect_equal(layer$type, "hexbin")

  rows <- layer$data
  testthat::expect_gt(length(rows), 1)

  row_y <- vapply(rows, function(row) row[[1]]$y, numeric(1))
  testthat::expect_false(is.unsorted(row_y))

  for (row in rows) {
    ys <- vapply(row, function(bin) bin$y, numeric(1))
    xs <- vapply(row, function(bin) bin$x, numeric(1))
    testthat::expect_equal(ys, rep(ys[1], length(ys)))
    testthat::expect_false(is.unsorted(xs))
  }
})

test_that("the rows are ragged and stay that way", {
  skip_if_no_hex()

  # `stat_binhex()` emits only the bins that hold something, so the lattice
  # is uneven by construction. Padding it to a rectangle would announce
  # cells that were never drawn.
  layer <- hex_render(hex_plot())$layer

  testthat::expect_gt(length(unique(lengths(layer$data))), 1)
})

test_that("every drawn hexagon is announced with its own count", {
  skip_if_no_hex()

  # Read against what ggplot2 drew rather than against a shape chosen here,
  # so this keeps meaning if the stat changes where it puts the bins.
  plot <- hex_plot()
  drawn <- ggplot2::ggplot_build(plot)$data[[1]]
  layer <- hex_render(plot)$layer

  bins <- hex_bins(layer)
  testthat::expect_equal(length(bins), nrow(drawn))
  testthat::expect_equal(
    sort(vapply(bins, function(bin) bin$count, numeric(1))),
    sort(as.numeric(drawn$count))
  )
  testthat::expect_equal(layer$axes$z$label, "count")
})

test_that("each selector addresses the hexagon its bin describes", {
  skip_if_no_hex()

  # The one that catches an off-by-a-row highlight. Resolved against the
  # exported SVG rather than reasoned about: the claim is that selector *k*
  # matches the polygon whose centre and count bin *k* announces, and only
  # walking the document can say whether it does.
  plot <- hex_plot()
  drawn <- ggplot2::ggplot_build(plot)$data[[1]]
  rendered <- hex_render(plot)
  layer <- rendered$layer

  bins <- hex_bins(layer)
  testthat::expect_length(layer$selectors, length(bins))

  polygons <- xml2::xml_find_all(rendered$svg, "//polygon[contains(@id, 'geom_hex')]")
  testthat::expect_equal(length(polygons), nrow(drawn))

  ids <- vapply(layer$selectors, function(selector) {
    sub("^polygon#", "", gsub("\\\\", "", selector))
  }, character(1))
  testthat::expect_equal(length(unique(ids)), length(ids))

  for (i in seq_along(bins)) {
    matched <- xml2::xml_find_all(
      rendered$svg, sprintf("//polygon[@id='%s']", ids[i])
    )
    testthat::expect_length(matched, 1)

    # The id's trailing number is the built row gridSVG drew that polygon
    # from, which is what makes this a check of the mapping rather than of
    # the string.
    row <- as.integer(sub(".*\\.", "", ids[i]))
    testthat::expect_equal(drawn$x[row], bins[[i]]$x, tolerance = 1e-6)
    testthat::expect_equal(drawn$y[row], bins[[i]]$y, tolerance = 1e-6)
    testthat::expect_equal(as.numeric(drawn$count[row]), bins[[i]]$count)
  }
})

test_that("the regrouping carries the built rows with it", {
  skip_if_no_hex()

  # The test above passes on a frame that arrives already sorted, which
  # `stat_binhex()` does emit today -- so on its own it cannot tell a real
  # regrouping from a list left in document order. This one shuffles the
  # frame so the two answers differ, and asserts the order the selectors are
  # built from.
  built <- data.frame(
    x = c(3, 1, 2, 1, 2, 1),
    y = c(0, 10, 0, 0, 10, 20),
    count = c(7, 5, 8, 9, 6, 4)
  )

  lattice <- maidr:::hexbin_lattice(built)

  testthat::expect_equal(lengths(lattice$data), c(3L, 2L, 1L))
  testthat::expect_equal(lattice$order, c(4L, 3L, 1L, 2L, 5L, 6L))

  bins <- unlist(lattice$data, recursive = FALSE)
  testthat::expect_equal(
    vapply(bins, function(bin) bin$count, numeric(1)),
    built$count[lattice$order]
  )
  testthat::expect_false(identical(lattice$order, seq_len(nrow(built))))
})

test_that("the axes are named for what was mapped, however it was named", {
  skip_if_no_hex()

  # Resolved through `resolve_legend_label()` -- the package's own
  # "`labs()` override, then the layer's mapping, then the plot's" chain --
  # rather than a second implementation of it here.
  named <- hex_plot() + ggplot2::labs(x = "First", y = "Second")
  layer <- hex_render(named)$layer
  testthat::expect_equal(layer$axes$x$label, "First")
  testthat::expect_equal(layer$axes$y$label, "Second")

  # No `labs()`: the mapped expressions, which is what ggplot2 prints.
  plain <- hex_render(hex_plot())$layer
  testthat::expect_equal(plain$axes$x$label, "x")
  testthat::expect_equal(plain$axes$y$label, "y")

  # Mapped on the layer rather than on the plot. This passes through the
  # *first* step rather than the second: ggplot2 records every layer's
  # mapping in `built$plot$labels` while building, so the override path
  # already answers. Asserted for the outcome, not as evidence about which
  # branch ran.
  frame <- hex_frame()
  names(frame) <- c("width", "height")
  on_layer <- ggplot2::ggplot(frame) +
    ggplot2::geom_hex(ggplot2::aes(x = width, y = height), bins = 4)
  processor <- maidr:::Ggplot2HexbinLayerProcessor$new(list(index = 1))
  testthat::expect_equal(
    processor$extract_axes(on_layer, ggplot2::ggplot_build(on_layer))$x$label,
    "width"
  )

  # The one place the shared chain differs from reading the label directly:
  # a blank override falls through to the mapped name. An axis announced as
  # the empty string is worse than one announced as its column.
  blanked <- hex_plot() + ggplot2::labs(x = "")
  testthat::expect_equal(
    processor$extract_axes(blanked, ggplot2::ggplot_build(blanked))$x$label,
    "x"
  )
})

test_that("two hexbin layers each address their own hexagons", {
  skip_if_no_hex()

  # A first match for `geom_hex.polygon` anywhere in the panel is the wrong
  # grob for every layer but the first: the second layer would highlight the
  # first one's hexagons while announcing its own counts. Silent, because
  # both lists are the right length and every count is real.
  #
  # `find_layer_grob_tree()` on the base class disambiguates by position
  # among the layers sharing a geom, which is what it is for.
  plot <- ggplot2::ggplot(hex_frame(), hex_aes) +
    ggplot2::geom_hex(bins = 3) +
    ggplot2::geom_hex(bins = 6)
  gt <- ggplot2::ggplotGrob(plot)
  built <- ggplot2::ggplot_build(plot)

  grobs <- character(0)
  sizes <- integer(0)
  for (index in 1:2) {
    processor <- maidr:::Ggplot2HexbinLayerProcessor$new(list(index = index))
    lattice <- processor$extract_data(plot, built)
    selectors <- processor$generate_selectors(gt, plot, NULL, lattice$order)

    testthat::expect_length(selectors, length(lattice$order))
    grobs <- c(grobs, sub("\\.1\\.[0-9]+$", "", selectors[[1]]))
    sizes <- c(sizes, length(lattice$order))
  }

  # Different grobs, and different lattices -- the second is the finer one,
  # so a shared grob would also be the wrong length for it.
  testthat::expect_equal(length(unique(grobs)), 2L)
  testthat::expect_lt(sizes[1], sizes[2])
})

test_that("each facet reads its own lattice and highlights its own hexagons", {
  skip_if_no_hex()

  # The selectors are indexed by built-data row, and a facetted plot filters
  # those rows per panel -- so the index has to be within the panel's frame,
  # because each panel draws its own grob and gridSVG numbers the polygons
  # inside it from one. That claim was a comment in the processor before it
  # was a test; this is the test.
  #
  # The panels are deliberately unequal, so an index carried across from the
  # wrong frame lands on a real hexagon rather than running off the end.
  set.seed(1)
  frame <- data.frame(
    x = stats::rnorm(300), y = stats::rnorm(300),
    g = rep(c("a", "b"), each = 150)
  )
  plot <- ggplot2::ggplot(frame, hex_aes) +
    ggplot2::geom_hex(bins = 3) +
    ggplot2::facet_wrap(~g)

  rendered <- hex_render_all(plot)
  panels <- rendered$subplots[[1]]
  testthat::expect_length(panels, 2)

  drawn <- ggplot2::ggplot_build(plot)$data[[1]]
  ids <- character(0)

  for (index in seq_along(panels)) {
    layer <- panels[[index]]$layers[[1]]
    own <- drawn[drawn$PANEL == index, , drop = FALSE]
    bins <- hex_bins(layer)

    testthat::expect_equal(layer$type, "hexbin")
    testthat::expect_equal(length(bins), nrow(own))
    testthat::expect_length(layer$selectors, length(bins))

    for (i in seq_along(bins)) {
      id <- sub("^polygon#", "", gsub("\\\\", "", layer$selectors[[i]]))
      ids <- c(ids, id)
      testthat::expect_length(
        xml2::xml_find_all(rendered$svg, sprintf("//polygon[@id='%s']", id)), 1
      )
      row <- as.integer(sub(".*\\.", "", id))
      testthat::expect_equal(own$x[row], bins[[i]]$x, tolerance = 1e-6)
      testthat::expect_equal(as.numeric(own$count[row]), bins[[i]]$count)
    }
  }

  # No panel borrows another's elements.
  testthat::expect_equal(length(unique(ids)), length(ids))
})

test_that("a lattice with nothing in it emits nothing rather than a shape", {
  testthat::skip_if_not_installed("ggplot2")

  # An empty answer is the honest one, and the frontend withdraws
  # highlighting outright when the element count disagrees with the bin
  # count -- so a partial list is worse than none.
  empty <- data.frame(x = numeric(0), y = numeric(0), count = numeric(0))
  testthat::expect_equal(maidr:::hexbin_lattice(empty)$data, list())
  testthat::expect_length(maidr:::hexbin_lattice(empty)$order, 0)

  # A frame missing `count` is not a hexbin lattice, whatever else it is.
  testthat::expect_equal(
    maidr:::hexbin_lattice(data.frame(x = 1, y = 1))$data, list()
  )

  processor <- maidr:::Ggplot2HexbinLayerProcessor$new(list(index = 1))
  testthat::expect_equal(processor$generate_selectors(order = integer(0)), list())
})
