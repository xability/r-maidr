# Rendering a plot and reading the layers back out of its HTML.
#
# Shared because three test files had grown their own copies of it -- #227's,
# #230's and #232's -- and testthat sources every file in this directory into
# one environment, so the later definitions silently shadowed the earlier
# ones. Two HTML parsers that are supposed to agree and cannot be seen
# together is the drift this removes.

#' Skip unless a plot can actually be rendered and read back
skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

#' Render a plot and return its HTML
rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

#' Whether a rendering is the static-image fallback rather than a chart
fell_back <- function(html) {
  grepl("base64", html, fixed = TRUE)
}

#' The MAIDR schema carried in a rendering, or NULL when it fell back
schema_from <- function(html) {
  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(NULL)
  }
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  for (pair in list(
    c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"),
    c("&amp;", "&"), c("&#39;", "'")
  )) {
    json <- gsub(pair[1], pair[2], json, fixed = TRUE)
  }
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

#' Every layer of a rendering's first cell, or NULL when it fell back
layers_from <- function(html) {
  schema <- schema_from(html)
  if (is.null(schema)) {
    return(NULL)
  }
  schema$subplots[[1]][[1]]$layers
}

#' One "type(n)" string per layer, for every cell of a rendering
#'
#' A series layer reports "type(SxN)" -- S series of N points -- because a
#' smooth's `data` is a list of series, so its length alone cannot tell an
#' empty layer from a full one: a real smooth is `smooth(1x80)` and an empty
#' one was `smooth(1x0)`.
#'
#' One string per cell, so a facet grid or a patchwork composition reports
#' each panel separately. "image" when the chart fell back.
emitted_layers <- function(plot) {
  html <- rendered(plot)
  if (fell_back(html)) {
    return("image")
  }
  schema <- schema_from(html)
  if (is.null(schema)) {
    return(character(0))
  }

  size <- function(layer) {
    rows <- layer$data
    series <- length(rows) > 0 &&
      is.list(rows[[1]]) &&
      is.null(names(rows[[1]]))
    if (series) {
      paste0(length(rows), "x", paste(vapply(rows, length, 0L), collapse = "/"))
    } else {
      as.character(length(rows))
    }
  }

  out <- character(0)
  for (row in schema$subplots) {
    for (cell in row) {
      out <- c(out, paste(
        vapply(cell$layers, function(l) sprintf("%s(%s)", l$type, size(l)), ""),
        collapse = " "
      ))
    }
  }
  out
}
