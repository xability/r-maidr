#' Common SVG and HTML utilities
#'
#' This file contains common utilities for SVG manipulation, maidr data
#' injection, and HTML generation that work for all plot types.

#' Create enhanced SVG with maidr data
#' @param gt A gtable object
#' @param maidr_data The maidr-data structure
#' @param ... Additional arguments
#' @return Character vector of SVG content
#' @keywords internal
create_enhanced_svg <- function(gt, maidr_data, ...) {
  svg_file <- tempfile(fileext = ".svg")
  library(grid)
  library(gridSVG)

  # Use default rendering (no viewport changes)
  grid.newpage()
  grid.draw(gt)

  # Export to SVG
  grid.export(svg_file, exportCoords = "inline", exportMappings = "inline")

  svg_content <- readLines(svg_file, warn = FALSE)
  svg_content <- add_maidr_data_to_svg(svg_content, maidr_data)

  svg_content
}

#' Add maidr-data to SVG using proper XML manipulation
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure
#' @return Modified SVG content
#' @keywords internal
add_maidr_data_to_svg <- function(svg_content, maidr_data) {
  maidr_json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)

  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop(
      "The 'xml2' package is required for SVG manipulation. ",
      "Please install it with: install.packages('xml2')"
    )
  }

  svg_text <- paste(svg_content, collapse = "\n")
  svg_doc <- xml2::read_xml(svg_text)

  xml2::xml_attr(svg_doc, "maidr-data") <- maidr_json

  svg_content <- strsplit(as.character(svg_doc), "\n")[[1]]

  svg_content
}

#' Create HTML document with dependencies
#' @param svg_content Character vector of SVG content
#' @return An htmltools HTML document object
#' @keywords internal
create_html_document <- function(svg_content) {
  html_doc <- htmltools::tags$html(
    htmltools::tags$head(),
    htmltools::tags$body(
      htmltools::HTML(paste(svg_content, collapse = "\n"))
    )
  )

  html_doc <- htmltools::attachDependencies(
    html_doc,
    maidr_html_dependencies()
  )

  html_doc
}

#' Save HTML document to file
#' @param html_doc An htmltools HTML document object
#' @param file Output file path
#' @keywords internal
save_html_document <- function(html_doc, file) {
  htmltools::save_html(html_doc, file = file)
}

#' Display HTML document directly
#' @param html_doc An htmltools HTML document object
#' @keywords internal
display_html <- function(html_doc) {
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(html_doc)
  } else {
    # Create temporary HTML file and open it
    temp_file <- tempfile(fileext = ".html")
    htmltools::save_html(html_doc, file = temp_file)
    utils::browseURL(temp_file)
  }
}

#' Display HTML file in browser
#' @param file HTML file path
#' @keywords internal
display_html_file <- function(file) {
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(htmltools::includeHTML(file))
  } else {
    utils::browseURL(file)
  }
}
