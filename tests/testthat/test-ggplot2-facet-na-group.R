# Faceting on a column that contains NA (issue #92)
#
# `original_data[original_data[[facet_var]] == group, ]` answers NA for every
# row whose facet value is missing, and `[` turns an NA index into a
# fabricated all-NA row. One missing facet value therefore contaminated EVERY
# panel's subset, and `save_html()` aborted in `order(NULL)` with "argument 1
# is not a vector" - no file, and an error naming nothing the user wrote.
#
# ggplot2 does not treat the missing value as an absence: it lays out a real
# third panel and draws the two glyphs "NA" on its strip. So the panel has to
# carry its own rows and announce the same string a sighted reader sees, which
# is what these tests pin - the title is checked against the text ggplot2
# actually exported, not against a literal chosen here.

# Held at file scope rather than built inside the helpers below: the
# processor resolves column names with `rlang::as_label()`, so the mapping has
# to stay written as bare `cat` / `val` / `fill`.
na_facet_aes <- ggplot2::aes(x = cat, y = val, fill = fill)

na_facet_frame <- function(na_rows_first = FALSE) {
  frame <- data.frame(
    g = c(rep("a", 4), rep("b", 4), NA, NA),
    cat = c("x", "x", "y", "y", "x", "x", "y", "y", "x", "y"),
    fill = c("u", "v", "u", "v", "u", "v", "u", "v", "u", "v"),
    val = c(10, 30, 20, 40, 11, 31, 21, 41, 99, 98),
    stringsAsFactors = FALSE
  )

  # The NA rows sorting last used to hide the damage in the two real panels,
  # because split() quietly discarded the injected rows. Sorting them first
  # skewed the colour-to-fill zip and killed all three panels.
  if (na_rows_first) frame[c(9, 10, seq_len(8)), ] else frame
}

na_facet_stacked_plot <- function(na_rows_first = FALSE) {
  ggplot2::ggplot(
    na_facet_frame(na_rows_first),
    na_facet_aes
  ) +
    ggplot2::geom_bar(stat = "identity", position = "stack") +
    ggplot2::facet_wrap(~g)
}

#' Render a plot to HTML and return both the payload and the drawn SVG text
na_facet_render <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)

  save_html(plot, file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  attribute <- regmatches(html, regexpr('maidr-data="([^"]*)"', html))
  testthat::expect_length(attribute, 1)
  json <- sub('"$', "", sub('^maidr-data="', "", attribute))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  document <- xml2::read_html(file)
  glyphs <- xml2::xml_text(
    xml2::xml_find_all(document, "//*[local-name()='text']")
  )

  list(
    payload = jsonlite::fromJSON(json, simplifyVector = FALSE),
    glyphs = trimws(glyphs)
  )
}

na_facet_panel <- function(rendered, column) {
  rendered$payload$subplots[[1]][[column]]$layers[[1]]
}

na_facet_values <- function(panel) {
  sort(unlist(lapply(panel$data, function(series) {
    vapply(series, function(point) point$y, numeric(1))
  })))
}

test_that("a faceted stacked bar with an NA facet level still exports", {
  testthat::skip_if_not_installed("ggplot2")

  testthat::expect_no_error(na_facet_render(na_facet_stacked_plot()))
  testthat::expect_no_error(
    na_facet_render(na_facet_stacked_plot(na_rows_first = TRUE))
  )
})

test_that("an NA facet level does not leak rows into the other panels", {
  testthat::skip_if_not_installed("ggplot2")

  for (na_rows_first in c(FALSE, TRUE)) {
    rendered <- na_facet_render(na_facet_stacked_plot(na_rows_first))

    testthat::expect_equal(
      na_facet_values(na_facet_panel(rendered, 1)),
      c(10, 20, 30, 40)
    )
    testthat::expect_equal(
      na_facet_values(na_facet_panel(rendered, 2)),
      c(11, 21, 31, 41)
    )

    # Every announced value comes from a row the user supplied. The old
    # subset injected all-NA rows, so a leaked value shows up as NA here.
    for (column in 1:3) {
      values <- na_facet_values(na_facet_panel(rendered, column))
      testthat::expect_false(anyNA(values))
      testthat::expect_true(all(values %in% na_facet_frame()$val))
    }
  }
})

test_that("the NA panel carries its own rows and its own selector", {
  testthat::skip_if_not_installed("ggplot2")

  rendered <- na_facet_render(na_facet_stacked_plot())
  na_panel <- na_facet_panel(rendered, 3)

  testthat::expect_true(99 %in% na_facet_values(na_panel))

  selectors <- unlist(na_panel$selectors)
  testthat::expect_true(length(selectors) > 0)
  testthat::expect_false(any(nchar(selectors) == 0))
  testthat::expect_false(identical(
    selectors,
    unlist(na_facet_panel(rendered, 1)$selectors)
  ))
})

test_that("the NA panel announces the string ggplot2 draws on its strip", {
  testthat::skip_if_not_installed("ggplot2")

  rendered <- na_facet_render(na_facet_stacked_plot())

  # ggplot2 gives the panel a strip whose label is NA_character_, and grid
  # draws that as the literal glyphs "NA" - it is in the exported SVG next to
  # "a" and "b". Announcing anything else ("Missing", "(none)") would read out
  # a word that is not on the chart.
  testthat::expect_true(all(c("a", "b", "NA") %in% rendered$glyphs))

  testthat::expect_equal(na_facet_panel(rendered, 1)$title, "a")
  testthat::expect_equal(na_facet_panel(rendered, 2)$title, "b")
  testthat::expect_equal(na_facet_panel(rendered, 3)$title, "NA")
})

test_that("a facet level literally spelled \"NA\" is not the missing panel", {
  testthat::skip_if_not_installed("ggplot2")

  frame <- data.frame(
    g = c("NA", "NA", NA, NA),
    cat = c("x", "y", "x", "y"),
    fill = c("u", "u", "u", "u"),
    val = c(1, 2, 30, 40),
    stringsAsFactors = FALSE
  )
  plot <- ggplot2::ggplot(
    frame,
    na_facet_aes
  ) +
    ggplot2::geom_bar(stat = "identity", position = "stack") +
    ggplot2::facet_wrap(~g)

  rendered <- na_facet_render(plot)

  testthat::expect_equal(na_facet_values(na_facet_panel(rendered, 1)), c(1, 2))
  testthat::expect_equal(
    na_facet_values(na_facet_panel(rendered, 2)),
    c(30, 40)
  )
})

test_that("facet_group_rows never answers NA", {
  values <- c("a", NA, "b", "NA")

  testthat::expect_equal(
    maidr:::facet_group_rows(values, "a"),
    c(TRUE, FALSE, FALSE, FALSE)
  )
  testthat::expect_equal(
    maidr:::facet_group_rows(values, NA),
    c(FALSE, TRUE, FALSE, FALSE)
  )
  testthat::expect_equal(
    maidr:::facet_group_rows(values, "NA"),
    c(FALSE, FALSE, FALSE, TRUE)
  )
  testthat::expect_equal(
    maidr:::facet_group_rows(factor(values), NA),
    c(FALSE, TRUE, FALSE, FALSE)
  )
})

# The two fixes below are in the same `extract_data()` change but are reachable
# with NO facet at all, so they need their own coverage (raised in review of
# the PR for issue #92).

test_that("a layer whose own data is shorter than the plot's is not zipped against it", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")

  # Naming the caller's fill values after the built layer's fill column is
  # only meaningful while the two frames still line up row for row. A layer
  # carrying its own `data =` breaks that, and the mismatch used to pad the
  # names with NA -- which announced a category the layer never drew.
  big <- data.frame(
    cat = c("x", "y", "z"), fill = c("u", "v", "u"), val = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
  small <- data.frame(
    cat = c("x", "x", "y", "y"), fill = c("u", "v", "u", "v"),
    val = c(10, 30, 20, 40), stringsAsFactors = FALSE
  )
  plot <- ggplot2::ggplot(big, ggplot2::aes(x = cat, y = val, fill = fill)) +
    ggplot2::geom_col(data = small)

  drawn <- ggplot2::ggplot_build(plot)$data[[1]]
  processor <- maidr:::Ggplot2StackedBarProcessor$new(list(index = 1))
  data <- processor$extract_data(plot)

  points <- unlist(data, recursive = FALSE)
  testthat::expect_length(points, nrow(drawn))

  # Every announced category is one the layer actually drew. "z" is in the
  # plot's data but not the layer's, so it must not appear.
  announced <- vapply(points, function(p) as.character(p$x), character(1))
  testthat::expect_setequal(unique(announced), unique(as.character(small$cat)))
  testthat::expect_false("z" %in% announced)
})

test_that("rows ggplot2 could not position do not poison the stacking order", {
  testthat::skip_if_not_installed("ggplot2")

  # ggplot2 4.x keeps an unpositionable row in the built data with x/ymin/ymax
  # NA rather than deleting it. `min(x)` then returned NA, `x == min(x)`
  # answered NA for every row, and the stacking order came back empty --
  # `order(NULL)`, which is the same crash issue #92 reports, reachable with
  # no facet in sight.
  frame <- data.frame(
    cat = c("x", "x", "y", "y"),
    fill = c("u", "v", "u", "v"),
    val = c(10, 30, NA, 40),
    stringsAsFactors = FALSE
  )
  plot <- ggplot2::ggplot(frame, ggplot2::aes(x = cat, y = val, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "stack")

  processor <- maidr:::Ggplot2StackedBarProcessor$new(list(index = 1))
  testthat::expect_no_error(data <- suppressWarnings(processor$extract_data(plot)))

  # Both fill levels survive. Before the fix the stacking order came back
  # empty and there was nothing to order by, which is the crash.
  testthat::expect_length(data, 2)
  levels_seen <- vapply(data, function(s) as.character(s[[1]]$z), character(1))
  testthat::expect_setequal(levels_seen, c("u", "v"))

  values <- vapply(
    unlist(data, recursive = FALSE), function(p) as.numeric(p$y), numeric(1)
  )
  testthat::expect_false(any(is.na(values)))

  # What is NOT claimed here: the unpositionable cell is still announced,
  # as (y, 0, u). ggplot2 gives that row `x = NA` and draws no rect for it,
  # so a value of 0 is announced for a bar that is not on screen. This fix
  # only stops the row poisoning `min(x)`; deciding whether an unpositioned
  # cell should be announced as 0 or omitted is the same open question the
  # dodged processor's comment raises for `stat = "identity"`, and it wants
  # its own change. Pinned so the current behaviour is at least visible.
  emitted <- vapply(
    unlist(data, recursive = FALSE),
    function(p) sprintf("%s/%s/%s", p$x, p$y, p$z), character(1)
  )
  testthat::expect_true("y/0/u" %in% emitted)
})
