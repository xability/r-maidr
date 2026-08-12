# Error bar selectors against the SVG they are meant to address (issue #145).
#
# The processor's own tests assert the selector strings. These render the
# whole pipeline and ask the exported document whether those strings find
# anything -- which is the question the strings exist to answer, and the one
# no assertion on the emitted payload can reach.
#
# `ErrorBarTrace.mapToSvgElements` requires the flattened match to be exactly
# as long as the layer's data and discards it otherwise, so a count that is
# merely non-zero is not enough: it has to be right.

skip_if_no_export <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("gridSVG")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

#: Three intervals of visibly different width -- 0.8, 2.6, 0.3 -- so the
#: drawn lengths are in an order no other assignment of elements to samples
#: reproduces. A fixture with equal intervals would pass with the elements
#: shuffled.
ebs_data <- function() {
  data.frame(
    g = c("control", "low", "high"),
    y = c(4.2, 5.1, 7.3),
    lo = c(3.8, 4.0, 7.1),
    hi = c(4.6, 6.6, 7.4)
  )
}

# Render through the real pipeline and return the emitted payload beside the
# exported SVG. A full render is a few seconds, so results are cached per
# named plot for the duration of the file.
ebs_cache <- new.env(parent = emptyenv())

ebs_render <- function(plot, key) {
  if (!is.null(ebs_cache[[key]])) {
    return(ebs_cache[[key]])
  }

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(
    html, gregexpr('maidr-data="([^"]*)"', html, perl = TRUE)
  )[[1]]
  testthat::expect_gt(length(raw), 0)

  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  out <- list(data = jsonlite::fromJSON(json, simplifyVector = FALSE),
              doc = xml2::read_html(html))
  assign(key, out, envir = ebs_cache)
  out
}

# The first layer of the first subplot.
ebs_layer <- function(payload) {
  payload$data$subplots[[1]][[1]]$layers[[1]]
}

# Resolve a selector the way a browser would.
#
# `selectr` is not a dependency, so the two shapes the processor emits are
# translated by hand: `g#ID > *` addresses every child, and
# `g#ID > *:nth-child(3n+2)` every third starting at the second. The
# translation is checked by the geometry assertions below rather than taken
# on trust -- a wrong stride finds a cap instead of a whisker.
ebs_resolve <- function(payload, selector) {
  # A layer with no selectors is the regression itself, and reporting it as a
  # missing selector rather than as an XPath error is what makes the failure
  # readable the day it comes back.
  testthat::expect_true(is.character(selector) && length(selector) == 1L)

  id <- gsub("\\\\", "", sub("^[a-zA-Z]*#", "", sub(" .*$", "", selector)))
  stride <- regmatches(selector, regexpr("nth-child\\((\\d+)n\\+(\\d+)\\)", selector))

  path <- if (length(stride) == 0) {
    sprintf("//*[@id='%s']/*", id)
  } else {
    parts <- as.integer(regmatches(stride, gregexpr("\\d+", stride))[[1]])
    sprintf(
      "//*[@id='%s']/*[position() mod %d = %d]", id, parts[1], parts[2]
    )
  }
  xml2::xml_find_all(payload$doc, path)
}

# Endpoints of a two-point polyline, as drawn.
ebs_ends <- function(node) {
  pts <- strsplit(trimws(xml2::xml_attr(node, "points")), "\\s+")[[1]]
  vapply(strsplit(pts, ","), as.numeric, numeric(2))
}

ebs_plot <- function(geom, horizontal = FALSE) {
  df <- ebs_data()
  if (horizontal) {
    ggplot2::ggplot(df, ggplot2::aes(y, g, xmin = lo, xmax = hi)) + geom
  } else {
    ggplot2::ggplot(df, ggplot2::aes(g, y, ymin = lo, ymax = hi)) + geom
  }
}

test_that("every uncertainty geom's selector finds one element per sample", {
  skip_if_no_export()

  cases <- list(
    errorbar = list(ggplot2::geom_errorbar(width = 0.2), FALSE),
    linerange = list(ggplot2::geom_linerange(), FALSE),
    pointrange = list(ggplot2::geom_pointrange(), FALSE),
    crossbar = list(ggplot2::geom_crossbar(), FALSE),
    errorbarh = list(ggplot2::geom_errorbarh(height = 0.2), TRUE)
  )

  for (name in names(cases)) {
    payload <- ebs_render(
      ebs_plot(cases[[name]][[1]], cases[[name]][[2]]), name
    )
    layer <- ebs_layer(payload)

    testthat::expect_equal(layer$type, "error_bar", info = name)
    testthat::expect_length(layer$selectors, 1)
    testthat::expect_length(ebs_resolve(payload, layer$selectors[[1]]), 3)
  }
})

test_that("an error bar's selector finds its whiskers, not its caps", {
  skip_if_no_export()

  payload <- ebs_render(ebs_plot(ggplot2::geom_errorbar(width = 0.2)), "errorbar")
  nodes <- ebs_resolve(payload, ebs_layer(payload)$selectors[[1]])

  # A whisker is vertical and a cap horizontal, so this separates them
  # without depending on which of the three the export happens to write
  # first. Highlighting a cap would put the outline on a tick the width of
  # the styling parameter rather than on the interval.
  for (node in nodes) {
    ends <- ebs_ends(node)
    testthat::expect_equal(ends[1, 1], ends[1, 2])
    testthat::expect_false(isTRUE(all.equal(ends[2, 1], ends[2, 2])))
  }
})

test_that("a horizontal error bar's selector finds its horizontal whiskers", {
  skip_if_no_export()

  payload <- ebs_render(
    ebs_plot(ggplot2::geom_errorbarh(height = 0.2), horizontal = TRUE),
    "errorbarh"
  )
  nodes <- ebs_resolve(payload, ebs_layer(payload)$selectors[[1]])

  for (node in nodes) {
    ends <- ebs_ends(node)
    testthat::expect_equal(ends[2, 1], ends[2, 2])
    testthat::expect_false(isTRUE(all.equal(ends[1, 1], ends[1, 2])))
  }
})

test_that("the elements arrive in the order the data was emitted", {
  skip_if_no_export()

  # The trace pairs element i with point i, so an element list in any other
  # order highlights the wrong sample -- silently, since every element it
  # names is a real error bar. The fixture's intervals are 0.8, 2.6 and 0.3
  # wide, so the drawn lengths pin the pairing.
  payload <- ebs_render(ebs_plot(ggplot2::geom_errorbar(width = 0.2)), "errorbar")
  layer <- ebs_layer(payload)
  nodes <- ebs_resolve(payload, layer$selectors[[1]])

  drawn <- vapply(nodes, function(node) {
    ends <- ebs_ends(node)
    abs(ends[2, 1] - ends[2, 2])
  }, numeric(1))
  spans <- vapply(layer$data, function(point) {
    point$yMax - point$yMin
  }, numeric(1))

  testthat::expect_equal(order(drawn), order(spans))
  testthat::expect_equal(which.max(drawn), which.max(spans))
})

test_that("an error bar drawn beside a bar chart addresses only itself", {
  skip_if_no_export()

  # geom_col() + geom_errorbar() is the chart this geom is usually part of,
  # and the bars are drawn first. Addressing them would highlight the
  # estimates while the reader navigates the bounds.
  df <- ebs_data()
  payload <- ebs_render(
    ggplot2::ggplot(df, ggplot2::aes(g)) +
      ggplot2::geom_col(ggplot2::aes(y = y)) +
      ggplot2::geom_errorbar(
        ggplot2::aes(ymin = lo, ymax = hi), width = 0.2
      ),
    "col_errorbar"
  )

  layers <- payload$data$subplots[[1]][[1]]$layers
  interval <- Filter(function(l) identical(l$type, "error_bar"), layers)
  testthat::expect_length(interval, 1)

  nodes <- ebs_resolve(payload, interval[[1]]$selectors[[1]])
  testthat::expect_length(nodes, 3)
  for (node in nodes) {
    testthat::expect_equal(xml2::xml_name(node), "polyline")
  }
})
