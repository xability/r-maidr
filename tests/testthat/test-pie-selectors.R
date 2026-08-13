# Pie selectors against the SVG they are meant to address (issue #151).
#
# The processor's own tests assert the selector string. This renders the whole
# pipeline and asks the exported document whether that string finds the
# wedges, which is the question the string exists to answer.
#
# It is the test that was missing. `generate_selectors()` returned an empty
# list on ggplot2 3.4.4 -- a polar bar layer draws one `geom_polygon.polygon`
# grob per wedge inside a `geom_rect.gTree`, where the lookup wanted a single
# `geom_rect.polygon` -- so a pie highlighted nothing at all, while every
# assertion about what a reader *hears* passed. Nine tests failed and were
# recorded as "pre-existing" through two pull requests, because nothing said
# which defect they were.

skip_if_no_export <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("gridSVG")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

#: Three wedges of visibly different size, so a selector that resolved to the
#: wrong container could not coincide with the right one.
FRUIT <- data.frame(
  fruit = c("Apples", "Bananas", "Cherries"),
  units = c(3, 5, 2)
)

pie_cache <- new.env(parent = emptyenv())

pie_render <- function(plot, key) {
  if (!is.null(pie_cache[[key]])) {
    return(pie_cache[[key]])
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
  assign(key, out, envir = pie_cache)
  out
}

# Resolve `#id descendant` the way a browser would. `selectr` is not a
# dependency, and the pie emits only this one selector shape.
pie_resolve <- function(payload, selector) {
  testthat::expect_true(is.character(selector) && length(selector) == 1L)

  parts <- strsplit(trimws(selector), " +")[[1]]
  testthat::expect_length(parts, 2L)

  id <- gsub("\\\\", "", sub("^#", "", parts[1]))
  xml2::xml_find_all(
    payload$doc,
    sprintf("//*[@id='%s']//*[local-name()='%s']", id, parts[2])
  )
}

pie_plot <- function() {
  ggplot2::ggplot(FRUIT, ggplot2::aes(x = "", y = units, fill = fruit)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")
}

test_that("a pie's selector finds one element per wedge", {
  skip_if_no_export()

  payload <- pie_render(pie_plot(), "fruit")
  layer <- payload$data$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_equal(layer$type, "pie")
  testthat::expect_length(layer$selectors, 1)
  testthat::expect_length(pie_resolve(payload, layer$selectors[[1]]), nrow(FRUIT))
})

test_that("the wedges arrive in the order the data was emitted", {
  skip_if_no_export()

  # The trace pairs element i with slice i, so an element list in another
  # order highlights the wrong wedge -- silently, since every element it
  # names is a real wedge. The areas are 3, 5 and 2 of ten, so the drawn
  # extents pin the pairing.
  payload <- pie_render(pie_plot(), "fruit")
  layer <- payload$data$subplots[[1]][[1]]$layers[[1]]
  nodes <- pie_resolve(payload, layer$selectors[[1]])

  drawn <- vapply(nodes, function(node) {
    points <- strsplit(trimws(xml2::xml_attr(node, "points")), "\\s+")[[1]]
    length(points)
  }, numeric(1))
  magnitudes <- vapply(layer$data, function(point) as.numeric(point$y), numeric(1))

  # A wider wedge is drawn with more points along its arc.
  testthat::expect_equal(order(drawn), order(magnitudes))
  testthat::expect_equal(which.max(drawn), which.max(magnitudes))
})

test_that("a faceted pie scopes each panel to its own wedges", {
  skip_if_no_export()

  # The failure this guards is not an empty selector but a shared one: every
  # panel pointing at the first panel's wedges resolves, and looks healthy.
  faceted <- rbind(
    cbind(FRUIT, season = "Summer"),
    cbind(FRUIT, season = "Winter")
  )
  payload <- pie_render(
    ggplot2::ggplot(faceted, ggplot2::aes(x = "", y = units, fill = fruit)) +
      ggplot2::geom_col() +
      ggplot2::coord_polar("y") +
      ggplot2::facet_wrap(~season),
    "faceted"
  )

  layers <- lapply(payload$data$subplots[[1]], function(cell) cell$layers[[1]])
  testthat::expect_length(layers, 2)

  selectors <- vapply(layers, function(layer) {
    testthat::expect_length(layer$selectors, 1)
    layer$selectors[[1]]
  }, character(1))

  testthat::expect_false(identical(selectors[1], selectors[2]))
  for (selector in selectors) {
    testthat::expect_length(pie_resolve(payload, selector), nrow(FRUIT))
  }
})
