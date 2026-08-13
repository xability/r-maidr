# A bar whose x or fill is missing (issue #112)
#
# ggplot2 does not treat a missing value as an absence. Its discrete scale lays
# out a category for it after the ordinary levels, draws a grey bar there, puts
# a tick under it and a key in the legend -- exactly as it lays out a facet
# panel for a missing facet value and draws "NA" on the strip.
#
# maidr gave two different wrong answers. A missing `x` kept its value and lost
# its category, so a reader heard the number 30 attached to nothing. A missing
# `fill` lost its whole series: three bars drawn, two announced, and the third
# unreachable by any keystroke -- with the payload internally consistent, so
# nothing looked wrong from the inside.
#
# These run the bundled frontend's own rect walk against the rects the pipeline
# really exports, because the question is not whether the payload looks
# plausible. It is whether the highlight lands on the bar the reader is on: a
# grid that gained a column but drew it in the wrong place would announce every
# category correctly and outline the wrong bar, and no assertion on the payload
# alone can see that.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

# Built at top level: inside a closure the bare column names in `aes()` read as
# undefined globals to static analysis.
na_bar_aes <- ggplot2::aes(x = cat, y = val, fill = fl)

#' Three rows, each with a distinct value, one aesthetic set to NA
na_bar_frame <- function(where) {
  frame <- data.frame(
    cat = c("p", "q", "r"),
    fl = c("A", "B", "A"),
    val = c(10, 20, 30),
    stringsAsFactors = FALSE
  )
  frame[[where]][3] <- NA
  frame
}

#' Render a plot and return its layer alongside the rects its selector claims
#'
#' The rects are scoped through the layer's own selector rather than by
#' hunting the SVG, so this reads the same nodes the frontend would.
na_bar_render <- function(plot) {
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

  layer <- jsonlite::fromJSON(json, simplifyVector = FALSE)$
    subplots[[1]][[1]]$layers[[1]]

  selector <- unlist(layer$selectors, use.names = FALSE)
  testthat::expect_length(selector, 1)
  id <- gsub("\\\\", "", sub(" rect$", "", sub("^#", "", selector)))
  rects <- xml2::xml_find_all(
    xml2::read_html(html),
    sprintf("//*[@id='%s']//rect", id)
  )

  list(
    layer = layer,
    rect_x = as.numeric(xml2::xml_attr(rects, "x")),
    rect_fill = xml2::xml_attr(rects, "fill")
  )
}

#' The bundled maidr.js Segmented rect walk, in R
#'
#' `Number(null)` is 0, which is what lets an absent cell claim no rect. The
#' walk is x-major over a series-major payload, and reverse within a column
#' unless the layer says `groupDirection: "forward"`.
#'
#' @return One row per non-null cell: its point, and the index of the rect it
#'   was handed
na_bar_walk <- function(rendered) {
  bar_values <- lapply(rendered$layer$data, function(series) {
    vapply(
      series,
      function(point) if (is.null(point$y)) 0 else as.numeric(point$y),
      numeric(1)
    )
  })

  slots <- sum(vapply(bar_values, length, integer(1)))
  sparse <- length(rendered$rect_x) < slots
  forward <- identical(rendered$layer$domMapping$groupDirection, "forward")
  series_order <- if (forward) {
    seq_along(bar_values)
  } else {
    rev(seq_along(bar_values))
  }

  claimed <- list()
  k <- 0L
  for (col in seq_along(bar_values[[1]])) {
    for (s in series_order) {
      if ((sparse && bar_values[[s]][col] == 0) || k >= length(rendered$rect_x)) {
        next
      }
      k <- k + 1L
      claimed[[length(claimed) + 1L]] <- list(
        point = rendered$layer$data[[s]][[col]],
        rect = k
      )
    }
  }

  list(claimed = claimed, rect_count = length(rendered$rect_x))
}

for (where in c("cat", "fl")) {
  for (position in c("dodge", "stack")) {
    label <- paste0("a missing ", where, " on a ", position, "d bar")

    test_that(paste(label, "is announced and highlighted on its own bar"), {
      skip_if_no_render()

      rendered <- na_bar_render(
        ggplot2::ggplot(na_bar_frame(where), na_bar_aes) +
          ggplot2::geom_col(position = position)
      )
      walked <- na_bar_walk(rendered)

      # Three rows in, three bars drawn, three cells carrying a value out --
      # and every rect claimed, so nothing was left without an announcement
      # to reach it.
      testthat::expect_equal(walked$rect_count, 3)
      testthat::expect_length(walked$claimed, 3)

      values <- vapply(
        walked$claimed, function(one) as.numeric(one$point$y), numeric(1)
      )
      testthat::expect_setequal(values, c(10, 20, 30))

      # The walk is x-major, so the rects it hands out advance across the
      # panel. A category inserted in the wrong place shows up here and
      # nowhere else in the payload.
      claimed_x <- rendered$rect_x[vapply(
        walked$claimed, function(one) one$rect, integer(1)
      )]
      testthat::expect_false(is.unsorted(claimed_x))

      # One colour per series, and no two series sharing one. The missing
      # category is drawn grey rather than from the hue palette, so a cell
      # handed another series' rect is visible here as a colour clash.
      by_series <- split(
        rendered$rect_fill[vapply(
          walked$claimed, function(one) one$rect, integer(1)
        )],
        vapply(walked$claimed, function(one) one$point$z, character(1))
      )
      for (colours in by_series) {
        testthat::expect_length(unique(colours), 1)
      }
      testthat::expect_length(
        unique(unlist(by_series)), length(by_series)
      )
    })

    test_that(paste(label, "names the category ggplot2 drew"), {
      skip_if_no_render()

      # The two characters on the tick and in the legend key, not a `null`
      # that serialises the category away, and not a word the axis does not
      # print. This is the answer `test-ggplot2-facet-na-group.R` already
      # pins for a facet strip; the same missing value has to read the same
      # way whichever of the two it lands on.
      rendered <- na_bar_render(
        ggplot2::ggplot(na_bar_frame(where), na_bar_aes) +
          ggplot2::geom_col(position = position)
      )

      carrying <- Filter(
        function(one) identical(as.numeric(one$point$y), 30),
        na_bar_walk(rendered)$claimed
      )
      testthat::expect_length(carrying, 1)

      named <- if (where == "cat") carrying[[1]]$point$x else carrying[[1]]$point$z
      testthat::expect_identical(named, "NA")
    })
  }
}

test_that("the scale draws NA where the payload announces it", {
  skip_if_no_render()

  # The level order is not chosen here, it is read off ggplot2. If a future
  # version stops putting the missing category last, this fails rather than
  # the announcement quietly drifting a column away from the tick.
  for (where in c("cat", "fl")) {
    frame <- na_bar_frame(where)
    plot <- ggplot2::ggplot(frame, na_bar_aes) + ggplot2::geom_col()
    drawn <- ggplot2::ggplot_build(plot)$layout$panel_params[[1]]$x$get_labels()

    announced <- vapply(
      na_bar_render(plot)$layer$data[[1]],
      function(point) as.character(point$x),
      character(1)
    )

    testthat::expect_identical(
      announced,
      vapply(drawn, level_label, character(1), USE.NAMES = FALSE),
      info = where
    )
  }
})

test_that("a level spelled NA and a missing one are two categories", {
  skip_if_no_render()

  # By identity, not by string -- the rule `facet_group_rows()` follows. Both
  # print as "NA", because both ticks say "NA", and they are still two
  # columns carrying two different values.
  frame <- data.frame(
    cat = c("p", "NA", NA),
    fl = c("A", "A", "A"),
    val = c(10, 20, 30),
    stringsAsFactors = FALSE
  )

  rendered <- na_bar_render(
    ggplot2::ggplot(frame, na_bar_aes) + ggplot2::geom_col()
  )
  walked <- na_bar_walk(rendered)

  testthat::expect_equal(walked$rect_count, 3)
  testthat::expect_length(walked$claimed, 3)

  named <- vapply(
    walked$claimed, function(one) as.character(one$point$x), character(1)
  )
  testthat::expect_equal(sum(named == "NA"), 2)
  testthat::expect_setequal(
    vapply(walked$claimed, function(one) as.numeric(one$point$y), numeric(1)),
    c(10, 20, 30)
  )
})

test_that("an ordinary bar chart is untouched", {
  skip_if_no_render()

  # The control. Everything above changes how a level order is built, and the
  # overwhelming majority of charts have no missing value at all -- so the
  # chart that does not is worth asserting explicitly rather than trusting to
  # the rest of the suite.
  frame <- data.frame(
    cat = c("p", "q", "r"),
    fl = c("A", "B", "A"),
    val = c(10, 20, 30),
    stringsAsFactors = FALSE
  )

  for (position in c("dodge", "stack")) {
    rendered <- na_bar_render(
      ggplot2::ggplot(frame, na_bar_aes) + ggplot2::geom_col(position = position)
    )
    walked <- na_bar_walk(rendered)

    testthat::expect_equal(walked$rect_count, 3)
    testthat::expect_length(walked$claimed, 3)
    testthat::expect_setequal(
      vapply(walked$claimed, function(one) as.character(one$point$x), character(1)),
      c("p", "q", "r")
    )
    testthat::expect_false(any(vapply(
      walked$claimed,
      function(one) identical(as.character(one$point$x), "NA"),
      logical(1)
    )))
  }
})
