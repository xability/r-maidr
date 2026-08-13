# A `geom_col()` frame need not be a complete grid - pre-aggregated tidy data
# is the reason the geom exists - and the `stat = "identity"` branch of both
# segmented processors used to emit only the rows the caller supplied. That
# made the series RAGGED, which is the one shape the bundled maidr.js cannot
# describe (issue #94).
#
# Its Segmented `mapToSvgElements` rect branch walks `barValues[0].length`
# columns times `barValues.length` series and pulls one node off a single flat
# `querySelectorAll` list per slot, so a 3/2 payload cross-mapped the
# announcement onto a bar in a different category AND a different fill group,
# and left the last bar with no highlight at all. The stacked processor had a
# second failure on top: it read the stacking order off the FIRST column, so a
# fill level absent from that column was dropped from the payload entirely.
#
# These tests replay that regrouping - including the sparse zero-skip the
# bundled build actually has, and the `Number(null) === 0` coercion the absent
# cells rely on - against the rects the pipeline really exports, at each of the
# three places a gap can fall: the start, the middle and the end of the frame.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

incomplete_cache <- new.env(parent = emptyenv())

# Three x categories, two fill levels, one cell removed. Every value is
# distinct so no two bars can be confused by height alone.
gap_frame <- function(where) {
  full <- data.frame(
    x = rep(c("p", "q", "r"), each = 2),
    g = rep(c("A", "B"), times = 3),
    n = c(11, 22, 33, 44, 55, 66),
    stringsAsFactors = FALSE
  )
  drop <- switch(where,
    start = which(full$x == "p" & full$g == "B"),
    middle = which(full$x == "q" & full$g == "B"),
    end = which(full$x == "r" & full$g == "B")
  )
  full[-drop, , drop = FALSE]
}

# The frontend reads `Number(point.y)`, and `Number(null)` is 0 - which is what
# makes an absent cell claim no rect. Mirror that coercion here.
bar_value <- function(point) {
  if (is.null(point$y)) 0 else as.numeric(point$y)
}

render_layer <- function(key, plot, panel = 1) {
  if (!is.null(incomplete_cache[[key]])) {
    return(incomplete_cache[[key]])
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
  layer <- payload$subplots[[1]][[panel]]$layers[[1]]

  # An empty selector list serialises to `[]`, which throws inside
  # `document.querySelectorAll` and kills the whole figure's highlighting
  # (issue #89), so the key is omitted instead. These plots draw rects, so a
  # selector has to be here.
  selector <- unlist(layer$selectors, use.names = FALSE)
  testthat::expect_length(selector, 1)
  testthat::expect_match(selector, "^#(\\\\.|[^ \\\\])+ rect$")

  id <- gsub("\\\\", "", sub(" rect$", "", sub("^#", "", selector)))
  rects <- xml2::xml_find_all(
    xml2::read_html(html),
    sprintf("//*[@id='%s']//rect", id)
  )

  out <- list(
    layer = layer,
    bar_values = lapply(layer$data, function(series) {
      vapply(series, bar_value, numeric(1))
    }),
    missing = lapply(layer$data, function(series) {
      vapply(series, function(p) is.null(p$y), logical(1))
    }),
    x_labels = lapply(layer$data, function(series) {
      vapply(series, function(p) as.character(p$x), character(1))
    }),
    fills = vapply(layer$data, function(series) {
      as.character(series[[1]]$z)
    }, character(1)),
    rect_x = as.numeric(xml2::xml_attr(rects, "x")),
    rect_height = as.numeric(xml2::xml_attr(rects, "height"))
  )
  assign(key, out, envir = incomplete_cache)
  out
}

# Built at top level: inside a closure the bare column names in `aes()` read
# as undefined globals to static analysis.
col_aes <- ggplot2::aes(x = x, y = n, fill = g)
count_aes <- ggplot2::aes(x = x, fill = g)

col_layer <- function(where, position) {
  key <- paste0(position, "_", where)
  render_layer(key, {
    base <- ggplot2::ggplot(gap_frame(where), col_aes)
    if (identical(position, "dodged")) {
      base + ggplot2::geom_col(position = "dodge")
    } else {
      base + ggplot2::geom_col()
    }
  })
}

# The `mapToSvgElements` rect branch of the bundled maidr.js, in R, carrying
# the sparse zero-skip that lets a rectangular payload describe a chart with
# structurally missing bars.
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

for (gap in c("start", "middle", "end")) {
  for (position in c("dodged", "stacked")) {
    local({
      where <- gap
      pos <- position
      label <- sprintf("geom_col %s, gap at the %s", pos, where)

      test_that(paste(label, "- emits a rectangular grid"), {
        skip_if_no_render()
        rendered <- col_layer(where, pos)

        # Before the fix: 3/2 for dodged and 2/3 for stacked, except the
        # stacked start case, which emitted a single series of 3.
        testthat::expect_equal(lengths(rendered$bar_values), c(3L, 3L))
        testthat::expect_setequal(rendered$fills, c("A", "B"))

        # Every series covers every x category, in the same order.
        for (labels in rendered$x_labels) {
          testthat::expect_equal(labels, c("p", "q", "r"))
        }
      })

      test_that(paste(label, "- the omitted row reads as missing, not zero"), {
        skip_if_no_render()
        rendered <- col_layer(where, pos)

        # Exactly one cell is absent, and it is the one the frame omitted.
        absent <- which(unlist(rendered$missing))
        testthat::expect_length(absent, 1)

        series <- which(rendered$fills == "B")
        col <- match(where, c("start", "middle", "end"))
        testthat::expect_true(rendered$missing[[series]][col])

        # `NA` -> JSON `null`, NOT 0. The frontend coerces it to 0 for the
        # highlight sentinel but announces the raw value through its missing
        # branch, so the reader hears "missing" rather than the value zero.
        # A literal 0 here would be a claim the caller never made.
        point <- rendered$layer$data[[series]][[col]]
        testthat::expect_true("y" %in% names(point))
        testthat::expect_null(point$y)

        # The values that ARE present survive untouched.
        present <- unlist(rendered$bar_values)[!unlist(rendered$missing)]
        testthat::expect_setequal(present, setdiff(c(11, 22, 33, 44, 55, 66),
                                                   c(22, 44, 66)[col]))
      })

      test_that(paste(label, "- every announced cell owns its own bar"), {
        skip_if_no_render()
        rendered <- col_layer(where, pos)

        bar_values <- rendered$bar_values
        testthat::expect_length(rendered$rect_height, 5)

        # Rectangular payload, 6 slots, 5 rects - so `sparse` is true and the
        # absent cell is skipped rather than eating its neighbour's node.
        slots <- sum(lengths(bar_values))
        testthat::expect_equal(slots, 6)
        testthat::expect_lt(length(rendered$rect_height), slots)

        grouped <- regroup_with_zero_skip(
          bar_values,
          seq_along(rendered$rect_height),
          rendered$layer$domMapping
        )
        scale <- max(rendered$rect_height) / max(unlist(bar_values))

        for (s in seq_along(bar_values)) {
          xs <- numeric(0)
          for (col in seq_along(bar_values[[s]])) {
            node <- grouped[[s]][col]

            if (rendered$missing[[s]][col]) {
              # A cell with no bar must be handed no rect, or it would steal
              # the next series' node and shift everything after it.
              testthat::expect_true(is.na(node))
              next
            }

            testthat::expect_false(is.na(node))
            # The rect this cell was handed is as tall as the value it
            # announces. Before the fix these landed on other categories.
            testthat::expect_equal(
              rendered$rect_height[node],
              bar_values[[s]][col] * scale,
              tolerance = 0.02
            )
            xs <- c(xs, rendered$rect_x[node])
          }
          # ... and the bars walk left to right across the columns.
          testthat::expect_false(is.unsorted(xs, strictly = TRUE))
        }
      })
    })
  }
}

test_that("a stacked geom_col keeps a fill level the first column lacks", {
  skip_if_no_render()

  # The stacking order used to come off the first column alone, so fill B -
  # which the `start` frame omits at x = p - never reached the payload: an
  # entire series that could not be announced or highlighted at all.
  rendered <- col_layer("start", "stacked")
  testthat::expect_length(rendered$bar_values, 2)
  testthat::expect_setequal(rendered$fills, c("A", "B"))
})

test_that("a dodged geom_col still asks for the default reverse walk", {
  skip_if_no_render()

  # reorder_layer_data() draws each column's fills descending, which is what
  # the frontend's default reverse per-column walk expects. Zero-/NA-filling
  # the grid must not quietly turn this into the "forward" walk that the
  # stat = "count" branch needs.
  testthat::expect_null(col_layer("middle", "dodged")$layer$domMapping)
})

# A real NA in the x or fill aesthetic is NOT an absent cell. ggplot2 draws it
# as its own grey "NA" category, so it is a row the caller did supply, and it
# gets a column and a series of its own like any other level (#112). It used
# to be held back to the row-by-row path, because `sort()` left it out of the
# level order and `paste()` hid it from the duplicate check by stringifying it
# to "NA"; `discrete_level_order()` and `level_keys()` are what changed.

na_aes_frame <- function(where) {
  frame <- data.frame(
    x = c("p", "q", "r"), g = c("A", "B", "A"), n = c(10, 20, 30),
    stringsAsFactors = FALSE
  )
  frame[[where]][3] <- NA
  frame
}

na_aes_points <- function(frame, position) {
  processor <- if (position == "dodge") {
    maidr:::Ggplot2DodgedBarLayerProcessor
  } else {
    maidr:::Ggplot2StackedBarProcessor
  }
  plot <- ggplot2::ggplot(frame, col_aes) +
    ggplot2::geom_col(position = position)
  unlist(processor$new(list(index = 1))$extract_data(plot), recursive = FALSE)
}

test_that("a real NA in x or fill takes the grid path like any other level", {
  testthat::skip_if_not_installed("ggplot2")

  for (where in c("x", "g")) {
    for (position in c("dodge", "stack")) {
      points <- na_aes_points(na_aes_frame(where), position)

      # The grid path is what introduces `NA` y values, so their presence is
      # the evidence this frame took it -- and the three the caller supplied
      # are all still there, none traded away for the grid.
      values <- vapply(points, function(p) as.numeric(p$y), numeric(1))
      testthat::expect_true(anyNA(values), info = paste(where, position))
      testthat::expect_setequal(values[!is.na(values)], c(10, 20, 30))
    }
  }
})

test_that("the missing category is announced as the NA ggplot2 draws", {
  testthat::skip_if_not_installed("ggplot2")

  # The row carrying the missing value reaches the reader under the same two
  # characters that are printed on its axis tick or legend key. Announcing it
  # as nothing -- which is what a `NULL` x or z serializes to -- describes a
  # value against a category that has no name.
  for (position in c("dodge", "stack")) {
    on_x <- na_aes_points(na_aes_frame("x"), position)
    thirty <- Filter(function(p) identical(as.numeric(p$y), 30), on_x)
    testthat::expect_length(thirty, 1)
    testthat::expect_identical(thirty[[1]]$x, "NA", info = position)

    on_fill <- na_aes_points(na_aes_frame("g"), position)
    thirty <- Filter(function(p) identical(as.numeric(p$y), 30), on_fill)
    testthat::expect_length(thirty, 1)
    testthat::expect_identical(thirty[[1]]$z, "NA", info = position)
  }
})

test_that("a missing fill still gets a series of its own", {
  testthat::skip_if_not_installed("ggplot2")

  # The sharper half of #112: the row did not merely lose its name, it left
  # the payload entirely. Three bars drawn, two announced, and the third
  # unreachable by any keystroke -- with the payload internally consistent,
  # so nothing looked wrong from the inside.
  for (position in c("dodge", "stack")) {
    plot <- ggplot2::ggplot(na_aes_frame("g"), col_aes) +
      ggplot2::geom_col(position = position)
    processor <- if (position == "dodge") {
      maidr:::Ggplot2DodgedBarLayerProcessor
    } else {
      maidr:::Ggplot2StackedBarProcessor
    }

    series <- processor$new(list(index = 1))$extract_data(plot)

    testthat::expect_length(series, 3)
    groups <- vapply(series, function(one) one[[1]]$z, character(1))
    testthat::expect_setequal(groups, c("A", "B", "NA"))
  }
})

test_that("a level spelled NA stays distinct from a missing one", {
  testthat::skip_if_not_installed("ggplot2")

  # The rule `facet_group_rows()` already follows for a facet strip, applied
  # to an axis tick: the two are told apart by identity, not by the string
  # they print as. ggplot2 lays out two categories here and draws "NA" on
  # both ticks, so two columns both reading "NA" is the picture, not a bug.
  frame <- data.frame(
    x = c("p", "NA", NA), g = c("A", "A", "A"), n = c(10, 20, 30),
    stringsAsFactors = FALSE
  )

  for (position in c("dodge", "stack")) {
    points <- na_aes_points(frame, position)

    testthat::expect_length(points, 3)
    testthat::expect_equal(
      sum(vapply(points, function(p) identical(p$x, "NA"), logical(1))),
      2,
      info = position
    )
    testthat::expect_setequal(
      vapply(points, function(p) as.numeric(p$y), numeric(1)),
      c(10, 20, 30)
    )
  }
})

test_that("a duplicated cell still falls back to the row-by-row reading", {
  testthat::skip_if_not_installed("ggplot2")

  # The guard that remains. Two rows in one (x, fill) cell draw two rects and
  # a grid has nowhere to put the second value, so that frame keeps the
  # row-by-row path -- and now that a missing value is a level rather than a
  # disqualification, the missing row has to survive that path too. `split()`
  # drops it on its own.
  frame <- data.frame(
    x = c("p", "p", "q", NA), g = c("A", "A", "B", NA), n = c(10, 11, 20, 30),
    stringsAsFactors = FALSE
  )

  for (position in c("dodge", "stack")) {
    values <- vapply(
      na_aes_points(frame, position),
      function(p) as.numeric(p$y), numeric(1)
    )

    testthat::expect_false(anyNA(values), info = position)
    testthat::expect_setequal(values, c(10, 11, 20, 30))
  }
})

faceted_gap_plot <- function() {
  ggplot2::ggplot(
    data.frame(
      f = c("f1", "f1", "f1", "f2", "f2", "f2"),
      x = c("p", "p", "q", "p", "q", "q"),
      g = c("A", "B", "A", "A", "A", "B"),
      n = c(11, 22, 33, 44, 55, 66),
      stringsAsFactors = FALSE
    ),
    col_aes
  ) + ggplot2::geom_col() + ggplot2::facet_wrap(~f)
}

test_that("each facet panel completes its own frame", {
  skip_if_no_render()

  # The gap sits in a different cell in each panel, and a panel reads only its
  # own rows, so the grid has to be completed per panel rather than once for
  # the whole layer. Panel 1 omits (q, B); panel 2 omits (p, B).
  for (panel in 1:2) {
    rendered <- render_layer(
      paste0("faceted_gap_", panel), faceted_gap_plot(),
      panel = panel
    )
    testthat::expect_equal(lengths(rendered$bar_values), c(2L, 2L))
    testthat::expect_equal(sum(unlist(rendered$missing)), 1)
    for (labels in rendered$x_labels) {
      testthat::expect_equal(labels, c("p", "q"))
    }
  }
})

test_that("an absent stat = 'count' cell still announces a real zero", {
  skip_if_no_render()

  # #87's zero-fill is a DATUM, not a placeholder: a cross-tabulation cell
  # that drew nothing genuinely counted nothing. Only the stat = "identity"
  # path, where a missing row means the caller supplied no value, uses `null`.
  rendered <- render_layer(
    "count_dodged",
    ggplot2::ggplot(
      data.frame(
        x = c("p", "p", "q", "r", "r", "r"),
        g = c("A", "B", "A", "A", "B", "B"),
        stringsAsFactors = FALSE
      ),
      count_aes
    ) + ggplot2::geom_bar(position = "dodge")
  )

  testthat::expect_equal(lengths(rendered$bar_values), c(3L, 3L))
  testthat::expect_false(any(unlist(rendered$missing)))

  series <- which(rendered$fills == "B")
  point <- rendered$layer$data[[series]][[2]]
  testthat::expect_false(is.null(point$y))
  testthat::expect_equal(as.numeric(point$y), 0)
  testthat::expect_equal(rendered$layer$domMapping$groupDirection, "forward")
})
