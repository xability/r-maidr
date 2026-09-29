# Rendering a lattice chart and resolving its selectors against its own SVG.
#
# The lattice processors address marks with a handful of selector shapes --
# `g#<id> > use`, `g#<id> > rect`, `g#<id> > polyline` and the single shape
# `#<id>\.<k>` -- where `<id>` is an exported grob id with every character
# outside `[A-Za-z0-9_-]` escaped. They are translated to XPath here rather
# than resolved by a CSS engine, which no package in Suggests provides; a
# shape outside this set is an error, so a processor that starts emitting a
# new one has to be taught here first.

#' Skip unless lattice charts can be drawn and read back
skip_if_no_lattice <- function() {
  testthat::skip_if_not_installed("lattice")
  testthat::skip_if_not_installed("jsonlite")
  testthat::skip_if_not_installed("xml2")
}

#' Render a trellis object the way `save_html()` does, keeping the SVG
#'
#' @return A list: `fallback` (TRUE when the chart falls back to an image),
#'   `orchestrator`, and, when it does not, `schema` (the parsed maidr-data)
#'   and `doc` (the exported SVG as an xml2 document).
render_lattice <- function(plot) {
  orchestrator <- maidr:::get_global_registry()$
    get_adapter("lattice")$
    create_orchestrator(plot)
  if (orchestrator$should_fallback()) {
    return(list(fallback = TRUE, orchestrator = orchestrator))
  }
  svg <- maidr:::create_enhanced_svg(
    orchestrator$get_gtable(),
    orchestrator$generate_maidr_data()
  )
  doc <- xml2::read_xml(paste(svg, collapse = "\n"))
  schema <- jsonlite::fromJSON(
    xml2::xml_attr(doc, "maidr-data"),
    simplifyVector = FALSE
  )
  list(fallback = FALSE, orchestrator = orchestrator, schema = schema, doc = doc)
}

#' Every layer of a rendering, with the grid cell it sits in
lattice_rendered_layers <- function(rendered) {
  out <- list()
  for (row in seq_along(rendered$schema$subplots)) {
    for (column in seq_along(rendered$schema$subplots[[row]])) {
      for (layer in rendered$schema$subplots[[row]][[column]]$layers) {
        layer$cell <- c(row, column)
        out[[length(out) + 1L]] <- layer
      }
    }
  }
  out
}

#' XPath for one selector of the shapes the lattice processors emit
lattice_selector_xpath <- function(selector) {
  parts <- trimws(strsplit(selector, ", ", fixed = TRUE)[[1]])
  paths <- vapply(parts, function(part) {
    match <- regmatches(
      part,
      regexec("^(g)?#((?:[^ \\\\]|\\\\.)+)(?: > ([a-z]+))?$", part, perl = TRUE)
    )[[1]]
    if (length(match) == 0L) {
      stop("Unsupported selector shape: ", part, call. = FALSE)
    }
    id <- gsub("\\\\(.)", "\\1", match[3])
    element <- if (nzchar(match[2])) "*[local-name()='g']" else "*"
    base <- sprintf("//%s[@id='%s']", element, id)
    if (nzchar(match[4])) {
      sprintf("%s/*[local-name()='%s']", base, match[4])
    } else {
      base
    }
  }, character(1))
  paste(paths, collapse = " | ")
}

#' The elements one selector matches in an exported SVG
lattice_selector_nodes <- function(doc, selector) {
  xml2::xml_find_all(doc, lattice_selector_xpath(selector))
}

#' How many elements each selector string of a layer matches
#'
#' A layer's selectors are a string, a list of strings, a grid of strings
#' and nulls, or a list of box selectors; every string in them is counted,
#' in the order they appear, and a null as NA.
lattice_selector_counts <- function(doc, selectors) {
  # `rapply()` would drop the nulls, which are the cells the counts are for.
  flatten <- function(x) {
    if (is.null(x)) {
      return(NA_character_)
    }
    if (is.character(x)) {
      return(x)
    }
    unlist(lapply(x, flatten), use.names = FALSE)
  }
  strings <- flatten(selectors)
  vapply(strings, function(s) {
    if (is.na(s)) NA_integer_ else length(lattice_selector_nodes(doc, s))
  }, integer(1), USE.NAMES = FALSE)
}
