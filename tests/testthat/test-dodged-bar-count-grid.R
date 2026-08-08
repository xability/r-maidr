# A dodged `stat = "count"` layer used to emit one entry per bar it actually
# drew, so a cross-tabulation with structurally empty cells came out RAGGED
# (issue #80): `mpg` class x drv gave series of 5, 4 and 3 entries.
#
# The bundled maidr.js cannot describe a ragged payload. Its Segmented
# `mapToSvgElements` walks `barValues[0].length` columns times
# `barValues.length` series and pulls one node off a single flat
# `querySelectorAll` list per slot, so 5x3 = 15 slots consumed a 12-rect list
# and every bar after the first gap highlighted its neighbour.
#
# These tests re-run that regrouping in R - including the sparse zero-skip the
# bundled build actually has - against the rects the pipeline really exports,
# so a change to the emitted shape, the column order or the per-column walk
# direction fails here instead of silently highlighting the wrong bar.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

count_grid_cache <- new.env(parent = emptyenv())

# Render through the real pipeline and return the layer payload alongside the
# geometry of every rect the layer's selector matches, in SVG document order.
render_count_grid <- function(key, plot) {
  if (!is.null(count_grid_cache[[key]])) {
    return(count_grid_cache[[key]])
  }

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

  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  layer <- payload$subplots[[1]][[1]]$layers[[1]]

  selector <- unlist(layer$selectors, use.names = FALSE)[1]
  id <- gsub("\\\\", "", sub(" rect$", "", sub("^#", "", selector)))

  doc <- xml2::read_html(html)
  rects <- xml2::xml_find_all(doc, sprintf("//*[@id='%s']//rect", id))

  out <- list(
    layer = layer,
    bar_values = lapply(layer$data, function(series) {
      vapply(series, function(point) as.numeric(point$y), numeric(1))
    }),
    x_labels = lapply(layer$data, function(series) {
      vapply(series, function(point) as.character(point$x), character(1))
    }),
    fills = vapply(layer$data, function(series) {
      as.character(series[[1]]$z)
    }, character(1)),
    rect_x = as.numeric(xml2::xml_attr(rects, "x")),
    rect_height = as.numeric(xml2::xml_attr(rects, "height"))
  )
  assign(key, out, envir = count_grid_cache)
  out
}

# The `mapToSvgElements` rect branch of the bundled maidr.js, in R. Unlike the
# copy in test-segmented-bar-selector-contract.R this one carries the sparse
# zero-skip, which is the mechanism a zero-filled grid relies on: when the
# layer holds fewer rects than slots, a barValue of exactly 0 consumes no node
# and the cell is handed an empty highlight element (NA here).
regroup_with_zero_skip <- function(bar_values, nodes, dom_mapping = NULL) {
  slots <- sum(vapply(bar_values, length, integer(1)))
  sparse <- length(nodes) < slots
  forward <- identical(dom_mapping$groupDirection, "forward")

  grouped <- replicate(length(bar_values), integer(0), simplify = FALSE)
  k <- 1L
  for (col in seq_along(bar_values[[1]])) {
    series_order <- if (forward) {
      seq_along(bar_values)
    } else {
      rev(seq_along(bar_values))
    }
    for (s in series_order) {
      if ((sparse && bar_values[[s]][col] == 0) || k > length(nodes)) {
        grouped[[s]] <- c(grouped[[s]], NA_integer_)
      } else {
        grouped[[s]] <- c(grouped[[s]], nodes[k])
        k <- k + 1L
      }
    }
  }
  grouped
}

mpg_dodged_count <- function() {
  render_count_grid(
    "mpg_dodge",
    ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, fill = drv)) +
      ggplot2::geom_bar(position = "dodge")
  )
}

test_that("a dodged count layer emits a rectangular grid, zeros included", {
  skip_if_no_render()
  rendered <- mpg_dodged_count()

  truth <- table(ggplot2::mpg$drv, ggplot2::mpg$class)
  classes <- sort(unique(as.character(ggplot2::mpg$class)))
  drvs <- sort(unique(as.character(ggplot2::mpg$drv)))

  # Before the fix these were 5, 4 and 3.
  testthat::expect_equal(lengths(rendered$bar_values), rep(length(classes), 3))
  testthat::expect_equal(rendered$fills, drvs)

  for (i in seq_along(drvs)) {
    testthat::expect_equal(rendered$x_labels[[i]], classes)
    testthat::expect_equal(
      rendered$bar_values[[i]],
      as.numeric(truth[drvs[i], classes])
    )
  }

  # The zero cells are the point: 21 slots for 12 drawn bars.
  testthat::expect_equal(sum(unlist(rendered$bar_values) == 0), 9)
})

test_that("the dodged count grid covers every slot the frontend walks", {
  skip_if_no_render()
  rendered <- mpg_dodged_count()

  slots <- length(rendered$bar_values[[1]]) * length(rendered$bar_values)
  testthat::expect_equal(slots, 21)
  testthat::expect_equal(length(rendered$rect_height), 12)

  # The walk is bounded by the payload, so the payload has to cover it. A
  # ragged 5/4/3 payload declared 15 slots for these same 12 rects and ran
  # the node cursor off the end.
  testthat::expect_equal(
    sum(unlist(rendered$bar_values) > 0),
    length(rendered$rect_height)
  )
})

test_that("a dodged count layer asks for the forward per-column walk", {
  skip_if_no_render()
  rendered <- mpg_dodged_count()

  # stat_count() rebuilds its own rows, so reorder_layer_data() cannot make
  # ggplot2 draw each column right-to-left the way it does for geom_col().
  testthat::expect_equal(rendered$layer$domMapping$groupDirection, "forward")
})

test_that("geom_col dodging keeps the default reverse walk", {
  skip_if_no_render()

  # Guards against applying the forward walk to the stat = "identity" branch,
  # where reorder_layer_data() already arranges for the reverse one.
  rendered <- render_count_grid(
    "col_dodge",
    ggplot2::ggplot(
      data.frame(
        cat = rep(c("a", "b", "c"), times = 2),
        grp = rep(c("u", "v"), each = 3),
        val = c(10, 20, 30, 55, 65, 75),
        stringsAsFactors = FALSE
      ),
      ggplot2::aes(x = cat, y = val, fill = grp)
    ) + ggplot2::geom_col(position = "dodge")
  )

  testthat::expect_null(rendered$layer$domMapping)
})

# The end-to-end check: replay the frontend regrouping over the real rects and
# confirm every series is handed exactly the bars it describes.
expect_series_own_their_rects <- function(rendered) {
  bar_values <- rendered$bar_values
  scale <- max(rendered$rect_height) / max(unlist(bar_values))

  grouped <- regroup_with_zero_skip(
    bar_values,
    seq_along(rendered$rect_height),
    rendered$layer$domMapping
  )

  column_x <- vector("list", length(bar_values[[1]]))
  for (s in seq_along(bar_values)) {
    for (col in seq_along(bar_values[[s]])) {
      node <- grouped[[s]][col]
      if (bar_values[[s]][col] == 0) {
        # A cell with no bar must be handed no rect, or it would steal the
        # next series' node and shift everything after it.
        testthat::expect_true(is.na(node))
        next
      }
      testthat::expect_false(is.na(node))
      # The rect this cell was handed is as tall as the value it announces.
      testthat::expect_equal(
        rendered$rect_height[node] / scale,
        bar_values[[s]][col],
        tolerance = 1e-3
      )
      column_x[[col]] <- c(column_x[[col]], rendered$rect_x[node])
    }
  }

  # Heights alone cannot tell two equal bars apart, so also pin the columns:
  # every rect handed to column j must sit to the left of every rect handed
  # to column j + 1.
  occupied <- Filter(length, column_x)
  for (col in seq_len(length(occupied) - 1)) {
    testthat::expect_lt(max(occupied[[col]]), min(occupied[[col + 1]]))
  }
}

test_that("maidr.js regrouping reunites ragged-source dodged counts with their rects", {
  skip_if_no_render()
  expect_series_own_their_rects(mpg_dodged_count())
})

test_that("maidr.js regrouping holds for a fully populated dodged count", {
  skip_if_no_render()

  # No empty cells at all, so this isolates the per-column walk direction from
  # the zero-filling: it fails whenever the layer takes the reverse walk.
  rendered <- render_count_grid(
    "complete_count",
    ggplot2::ggplot(
      data.frame(
        cat = c(rep("a", 5), rep("b", 7), rep("c", 9)),
        grp = c(
          rep("u", 1), rep("v", 4), rep("u", 2),
          rep("v", 5), rep("u", 3), rep("v", 6)
        ),
        stringsAsFactors = FALSE
      ),
      ggplot2::aes(cat, fill = grp)
    ) + ggplot2::geom_bar(position = "dodge")
  )

  testthat::expect_equal(rendered$bar_values, list(c(1, 2, 3), c(4, 5, 6)))
  expect_series_own_their_rects(rendered)
})

test_that("a dodged count grid follows factor level order, not alphabetical order", {
  skip_if_no_render()

  # A discrete scale lays categories out in level order. Ordering the emitted
  # grid with sort() instead put column 1 of the payload against column 3 of
  # the chart whenever the levels were not alphabetical.
  frame <- data.frame(
    cat = factor(
      c(rep("a", 5), rep("b", 7), rep("c", 9)),
      levels = c("c", "b", "a")
    ),
    grp = factor(
      c(
        rep("u", 1), rep("v", 4), rep("u", 2),
        rep("v", 5), rep("u", 3), rep("v", 6)
      ),
      levels = c("v", "u")
    )
  )
  rendered <- render_count_grid(
    "factor_levels",
    ggplot2::ggplot(frame, ggplot2::aes(cat, fill = grp)) +
      ggplot2::geom_bar(position = "dodge")
  )

  testthat::expect_equal(rendered$fills, c("v", "u"))
  testthat::expect_equal(rendered$x_labels[[1]], c("c", "b", "a"))
  testthat::expect_equal(rendered$bar_values, list(c(6, 5, 4), c(3, 2, 1)))
  expect_series_own_their_rects(rendered)
})
