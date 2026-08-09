# The last two facet subsets that picked their rows with `==` (issue #102).
#
# Issue 92 fixed the stacked processor and put `facet_group_rows()` in the
# shared facet file precisely so the remaining call sites could reuse it. Two
# were left: the dodged bar processor and the heatmap. `==` answers NA for
# every row whose facet value is missing, and `[` turns an NA index into a
# fabricated all-NA row, so the panel ggplot2 draws for the missing value came
# back holding nothing usable.
#
# The symptom differs from #92's crash, which is why it went unnoticed:
#
#   dodged   the panel's layer was dropped from the payload entirely
#   heatmap  the layer survived with its labels but scored no cells
#
# Either way a reader arrowing into that panel is told there is nothing there,
# while ggplot2 has drawn bars or tiles in it and written "NA" on its strip.

# Held at file scope: the processors resolve column names with
# `rlang::as_label()`, so the mappings have to stay written as bare columns.
na_dodged_aes <- ggplot2::aes(x = cat, y = val, fill = fill)
na_dodged_count_aes <- ggplot2::aes(x = cat, fill = fill)
na_heat_aes <- ggplot2::aes(x = cl, y = rw, fill = z)

na_dodged_frame <- function() {
  data.frame(
    g = c(rep("a", 4), rep("b", 4), NA, NA),
    cat = c("x", "x", "y", "y", "x", "x", "y", "y", "x", "y"),
    fill = c("u", "v", "u", "v", "u", "v", "u", "v", "u", "v"),
    val = c(10, 30, 20, 40, 11, 31, 21, 41, 99, 98),
    stringsAsFactors = FALSE
  )
}

# Render and return both the payload and the text ggplot2 exported, so the
# announced title can be checked against the glyphs actually drawn rather than
# against a literal chosen here.
na_dodged_render <- function(plot) {
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

  list(
    panels = jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]],
    glyphs = trimws(
      xml2::xml_text(xml2::xml_find_all(document, "//*[local-name()='text']"))
    )
  )
}

skip_if_no_na_facet_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

dodged_plot <- function(stat) {
  frame <- na_dodged_frame()
  if (stat == "identity") {
    ggplot2::ggplot(frame, na_dodged_aes) +
      ggplot2::geom_bar(stat = "identity", position = "dodge") +
      ggplot2::facet_wrap(~g)
  } else {
    ggplot2::ggplot(frame, na_dodged_count_aes) +
      ggplot2::geom_bar(position = "dodge") +
      ggplot2::facet_wrap(~g)
  }
}

panel_values <- function(panel) {
  points <- unlist(panel$layers[[1]]$data, recursive = FALSE)
  vapply(points, function(point) {
    if (is.null(point$y)) NA_real_ else as.numeric(point$y)
  }, numeric(1))
}

test_that("the NA facet panel of a dodged bar carries a layer at all", {
  skip_if_no_na_facet_render()

  for (stat in c("identity", "count")) {
    rendered <- na_dodged_render(dodged_plot(stat))
    testthat::expect_length(rendered$panels, 3)

    # The defect: this panel came back with `layers` empty, so there was
    # nothing to announce, nothing to sonify and nothing to highlight.
    na_panel <- rendered$panels[[3]]
    testthat::expect_gte(length(na_panel$layers), 1, label = stat)
    testthat::expect_gt(length(na_panel$layers[[1]]$data), 0)
  }
})

test_that("the NA facet panel announces its own rows and nobody else's", {
  skip_if_no_na_facet_render()

  rendered <- na_dodged_render(dodged_plot("identity"))

  # 99 and 98 are the two rows whose facet value is NA. They are the only
  # values that may appear here, and they must not appear anywhere else.
  testthat::expect_setequal(panel_values(rendered$panels[[3]]), c(99, 98))
  for (panel in 1:2) {
    values <- panel_values(rendered$panels[[panel]])
    testthat::expect_false(anyNA(values))
    testthat::expect_false(any(c(99, 98) %in% values))
  }
})

test_that("the NA facet panel of a dodged bar is announced as NA", {
  skip_if_no_na_facet_render()

  rendered <- na_dodged_render(dodged_plot("identity"))

  # Checked against the text ggplot2 exported, not against a literal chosen
  # here: grid draws the NA_character_ strip label as the glyphs "NA", next to
  # "a" and "b". Announcing "Missing" or "(none)" would read out a word that
  # is not on the chart. This matches what #92 settled for the stacked path.
  testthat::expect_true(all(c("a", "b", "NA") %in% rendered$glyphs))

  titles <- vapply(rendered$panels, function(panel) {
    as.character(panel$layers[[1]]$title)
  }, character(1))
  testthat::expect_equal(titles, c("a", "b", "NA"))
})

test_that("a dodged stat = 'count' NA panel is still a rectangular grid", {
  skip_if_no_na_facet_render()

  # #87 made this branch emit the full cross-tabulation so the frontend can
  # size its column walk. Restoring the panel's rows must not hand it a
  # ragged one: the NA panel holds (x, u) and (y, v) only, so the two absent
  # cells have to come back as a real 0 - the count of a combination that
  # genuinely occurred zero times.
  rendered <- na_dodged_render(dodged_plot("count"))
  na_panel <- rendered$panels[[3]]

  series <- na_panel$layers[[1]]$data
  testthat::expect_length(series, 2)
  testthat::expect_equal(unique(lengths(series)), 2L)
  testthat::expect_setequal(panel_values(na_panel), c(0, 1))
})

test_that("a facet level literally spelled NA is not the missing panel", {
  skip_if_no_na_facet_render()

  frame <- data.frame(
    g = c("NA", "NA", NA, NA),
    cat = c("x", "y", "x", "y"),
    fill = c("u", "u", "u", "u"),
    val = c(1, 2, 30, 40),
    stringsAsFactors = FALSE
  )
  rendered <- na_dodged_render(
    ggplot2::ggplot(frame, na_dodged_aes) +
      ggplot2::geom_bar(stat = "identity", position = "dodge") +
      ggplot2::facet_wrap(~g)
  )

  # `facet_group_rows()` separates the two by identity rather than by string,
  # which is the property that stops `%in%` collapsing them.
  testthat::expect_setequal(panel_values(rendered$panels[[1]]), c(1, 2))
  testthat::expect_setequal(panel_values(rendered$panels[[2]]), c(30, 40))
})

test_that("the NA facet panel of a heatmap scores its own cells", {
  skip_if_no_na_facet_render()

  frame <- data.frame(
    g = c(rep("a", 4), rep("b", 4), NA, NA),
    rw = c("r1", "r1", "r2", "r2", "r1", "r1", "r2", "r2", "r1", "r2"),
    cl = c("c1", "c2", "c1", "c2", "c1", "c2", "c1", "c2", "c1", "c2"),
    z = c(1, 2, 3, 4, 5, 6, 7, 8, 99, 98),
    stringsAsFactors = FALSE
  )
  rendered <- na_dodged_render(
    ggplot2::ggplot(frame, na_heat_aes) +
      ggplot2::geom_tile() +
      ggplot2::facet_wrap(~g)
  )

  # Here the layer survived - it kept its row and column labels - but every
  # cell scored NA, so the panel read as an empty grid rather than as absent.
  # That is the same root cause wearing a different symptom.
  na_layer <- rendered$panels[[3]]$layers[[1]]
  scores <- suppressWarnings(as.numeric(unlist(na_layer$data)))
  testthat::expect_true(all(c(99, 98) %in% scores))

  for (panel in 1:2) {
    other <- suppressWarnings(
      as.numeric(unlist(rendered$panels[[panel]]$layers[[1]]$data))
    )
    testthat::expect_false(any(c(99, 98) %in% other))
  }
})
