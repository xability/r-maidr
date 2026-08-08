# Stacked and dodged bars emit ONE flat CSS selector for the whole layer while
# `data` stays series-major (issue #54).
#
# Flattened side by side the two look mismatched, because SVG document order is
# x-major. They are not: the bundled maidr.js builds stacked, dodged and
# normalized traces from a single class whose `mapToSvgElements` re-groups the
# flat `querySelectorAll` node list one column at a time, walking each column's
# series in REVERSE when the layer carries no `domMapping`:
#
#   for (let col = 0, k = 0; col < barValues[0].length; col++)
#     if (domMapping?.groupDirection === "forward")
#       for (let s = 0; s < barValues.length; s++)      out[s][col] = nodes[k++];
#     else
#       for (let s = barValues.length - 1; s >= 0; s--) out[s][col] = nodes[k++];
#
# These tests re-run that regrouping in R against the rects actually exported,
# so a change to either the emitted series order or the rect draw order fails
# here instead of silently announcing the wrong bars.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

# x = a,b,c crossed with fills u = 10,20,30 and v = 55,65,75. Every value is
# distinct, so a rect's pixel height identifies which datum drew it.
segmented_bar_frame <- function() {
  data.frame(
    cat = rep(c("a", "b", "c"), times = 2),
    grp = rep(c("u", "v"), each = 3),
    val = c(10, 20, 30, 55, 65, 75),
    stringsAsFactors = FALSE
  )
}

segmented_bar_cache <- new.env(parent = emptyenv())

# Render through the real pipeline and return the layer payload alongside the
# value each matched rect represents, in SVG document order.
render_segmented_bar <- function(position, key) {
  if (!is.null(segmented_bar_cache[[key]])) {
    return(segmented_bar_cache[[key]])
  }

  plot <- ggplot2::ggplot(
    segmented_bar_frame(),
    ggplot2::aes(x = cat, y = val, fill = grp)
  ) + ggplot2::geom_col(position = position)

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
  heights <- as.numeric(xml2::xml_attr(rects, "height"))

  # Rect heights are proportional to the values that drew them; the tallest
  # rect is the largest value, which pins the pixels-per-unit scale.
  values <- unlist(lapply(layer$data, function(series) {
    vapply(series, function(point) as.numeric(point$y), numeric(1))
  }))
  dom_values <- heights / (max(heights) / max(values))

  out <- list(layer = layer, selector = selector, dom_values = dom_values)
  assign(key, out, envir = segmented_bar_cache)
  out
}

# The `mapToSvgElements` rect branch of the bundled maidr.js, in R.
regroup_like_maidr_js <- function(layer, dom_values) {
  bar_values <- lapply(layer$data, function(series) {
    vapply(series, function(point) as.numeric(point$y), numeric(1))
  })
  forward <- identical(layer$domMapping$groupDirection, "forward")

  grouped <- vector("list", length(bar_values))
  k <- 1L
  for (col in seq_along(bar_values[[1]])) {
    series_order <- if (forward) {
      seq_along(bar_values)
    } else {
      rev(seq_along(bar_values))
    }
    for (s in series_order) {
      grouped[[s]] <- c(grouped[[s]], dom_values[k])
      k <- k + 1L
    }
  }
  grouped
}

series_values <- function(layer, index) {
  vapply(layer$data[[index]], function(point) as.numeric(point$y), numeric(1))
}

series_fill <- function(layer, index) {
  as.character(layer$data[[index]][[1]]$z)
}

test_that("a stacked bar layer emits one flat selector for every rect", {
  skip_if_no_render()
  rendered <- render_segmented_bar("stack", "stack")

  testthat::expect_length(rendered$layer$selectors, 1)
  testthat::expect_match(rendered$selector, "^#geom_rect\\\\\\..* rect$")
  testthat::expect_null(rendered$layer$domMapping)
  testthat::expect_equal(rendered$layer$type, "stacked_bar")
})

# The two orders below run opposite ways, which is the whole point of this
# file: `data` starts at the BOTTOM of the stack while each column's rects
# are drawn TOP first. ggplot2 puts v at the bottom here (ymin 0 to 55) and
# u above it (55 to 65), and the processor sorts series by ascending stack
# height, so data[[1]] is v. The reverse regrouping is what reunites the two.
test_that("stacked bar data stays series-major, bottom fill level first", {
  skip_if_no_render()
  rendered <- render_segmented_bar("stack", "stack")
  layer <- rendered$layer

  testthat::expect_length(layer$data, 2)
  testthat::expect_equal(series_fill(layer, 1), "v")
  testthat::expect_equal(series_values(layer, 1), c(55, 65, 75))
  testthat::expect_equal(series_fill(layer, 2), "u")
  testthat::expect_equal(series_values(layer, 2), c(10, 20, 30))
})

test_that("stacked rects are exported x-major, top segment first per column", {
  skip_if_no_render()
  rendered <- render_segmented_bar("stack", "stack")

  # Deliberately NOT the emitted flattening (55,65,75,10,20,30).
  testthat::expect_equal(rendered$dom_values, c(10, 55, 20, 65, 30, 75),
                         tolerance = 1e-3)
})

test_that("maidr.js regrouping reunites stacked series with their own rects", {
  skip_if_no_render()
  rendered <- render_segmented_bar("stack", "stack")
  grouped <- regroup_like_maidr_js(rendered$layer, rendered$dom_values)

  testthat::expect_equal(grouped[[1]], series_values(rendered$layer, 1),
                         tolerance = 1e-3)
  testthat::expect_equal(grouped[[2]], series_values(rendered$layer, 2),
                         tolerance = 1e-3)
})

test_that("a dodged bar layer emits one flat selector for every rect", {
  skip_if_no_render()
  rendered <- render_segmented_bar("dodge", "dodge")

  testthat::expect_length(rendered$layer$selectors, 1)
  testthat::expect_match(rendered$selector, "^#geom_rect\\\\\\..* rect$")
  testthat::expect_null(rendered$layer$domMapping)
  testthat::expect_equal(rendered$layer$type, "dodged_bar")
})

test_that("dodged bar data stays series-major, fills ascending", {
  skip_if_no_render()
  rendered <- render_segmented_bar("dodge", "dodge")
  layer <- rendered$layer

  testthat::expect_length(layer$data, 2)
  testthat::expect_equal(series_fill(layer, 1), "u")
  testthat::expect_equal(series_values(layer, 1), c(10, 20, 30))
  testthat::expect_equal(series_fill(layer, 2), "v")
  testthat::expect_equal(series_values(layer, 2), c(55, 65, 75))
})

test_that("dodged rects are exported x-major, fills descending per column", {
  skip_if_no_render()
  rendered <- render_segmented_bar("dodge", "dodge")

  # reorder_layer_data() sorts fill descending so ggplot2 draws each column
  # right-to-left, which is what the reverse regrouping expects.
  testthat::expect_equal(rendered$dom_values, c(55, 10, 65, 20, 75, 30),
                         tolerance = 1e-3)
})

test_that("maidr.js regrouping reunites dodged series with their own rects", {
  skip_if_no_render()
  rendered <- render_segmented_bar("dodge", "dodge")
  grouped <- regroup_like_maidr_js(rendered$layer, rendered$dom_values)

  testthat::expect_equal(grouped[[1]], series_values(rendered$layer, 1),
                         tolerance = 1e-3)
  testthat::expect_equal(grouped[[2]], series_values(rendered$layer, 2),
                         tolerance = 1e-3)
})

test_that("a naive flatten-and-zip would disagree with the regrouping", {
  skip_if_no_render()

  # Guards the premise of the tests above: if emitted order and document
  # order ever coincided, the regrouping assertions would pass vacuously and
  # stop protecting anything.
  for (key in c("stack", "dodge")) {
    rendered <- render_segmented_bar(key, key)
    flattened <- unlist(lapply(rendered$layer$data, function(series) {
      vapply(series, function(point) as.numeric(point$y), numeric(1))
    }))
    testthat::expect_false(isTRUE(all.equal(flattened, rendered$dom_values)))
  }
})
