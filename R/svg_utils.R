#' Common SVG and HTML utilities
#'
#' This file contains common utilities for SVG manipulation, maidr data
#' injection, and HTML generation that work for all plot types.
#'
#' @importFrom grid grid.newpage grid.draw
#' @importFrom gridSVG grid.export
#' @importFrom stats setNames
NULL

# Counter for unique ID generation
.maidr_id_counter <- new.env(parent = emptyenv())
.maidr_id_counter$value <- 0L

#' Generate a unique ID for MAIDR plots
#'
#' Creates a unique identifier combining timestamp and counter to ensure
#' uniqueness even when multiple plots are created within the same second.
#'
#' @return Character string with unique ID
#' @keywords internal
generate_unique_id <- function() {
  .maidr_id_counter$value <- .maidr_id_counter$value + 1L
  paste0(
    as.integer(Sys.time()) * 1000 + .maidr_id_counter$value,
    "-",
    sample.int(9999, 1)
  )
}

#' Create enhanced SVG with maidr data
#' @param gt A gtable object
#' @param maidr_data The maidr-data structure
#' @param ... Additional arguments
#' @return Character vector of SVG content
#' @keywords internal
create_enhanced_svg <- function(gt, maidr_data, ...) {
  svg_file <- tempfile(fileext = ".svg")


  # Save current device

  current_dev <- grDevices::dev.cur()

  # Use a null/invisible PDF device for rendering to avoid side effects
  pdf_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(pdf_file, width = 7, height = 5)
  on.exit(
    {
      grDevices::dev.off()
      if (current_dev > 1) grDevices::dev.set(current_dev)
      unlink(pdf_file)
    },
    add = TRUE
  )

  # Render to the invisible device
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

#' Create self-contained HTML for iframe embedding
#'
#' Generates a complete standalone HTML document with MAIDR.js that can be
#' embedded in an iframe for isolation. Each iframe gets its own JavaScript
#' context, avoiding MAIDR.js singleton pattern issues with multiple plots.
#' Auto-detects internet availability: uses CDN if online, inline local if offline.
#'
#' @param svg_content Character vector of SVG content with maidr-data attribute
#' @return Character string of complete HTML document
#' @keywords internal
create_standalone_html <- function(svg_content) {
  svg_html <- paste(svg_content, collapse = "\n")

  # Auto-detect: use CDN if internet available, otherwise inline local content
  use_cdn <- curl::has_internet()

  if (use_cdn) {
    # CDN links - smaller HTML, relies on internet at view time
    css_tag <- sprintf(
      '<link rel="stylesheet" href="%s/maidr.css">',
      maidr_cdn_url()
    )
    js_tag <- sprintf(
      '<script src="%s/maidr.js"></script>',
      maidr_cdn_url()
    )
  } else {
    # Inline local content - works offline, larger HTML
    assets <- maidr_local_assets()
    css_content <- paste(readLines(assets$css, warn = FALSE), collapse = "\n")
    js_content <- paste(readLines(assets$js, warn = FALSE), collapse = "\n")
    css_tag <- sprintf("<style>\n%s\n</style>", css_content)
    js_tag <- sprintf("<script>\n%s\n</script>", js_content)
  }

  # Create a complete standalone HTML document
  # CSS prevents layout shifts from focus outlines and MAIDR UI elements
  html <- sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MAIDR Plot</title>
  %s
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%%;
      height: 100%%;
      overflow: hidden;
      box-sizing: border-box;
    }
    body {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
    }
    svg {
      max-width: 100%%;
      height: auto;
      display: block;
    }
    /* Prevent focus outlines from causing layout shifts */
    *:focus {
      outline-offset: -2px !important;
    }
    svg:focus, svg:focus-visible {
      outline: 2px solid #0066cc !important;
      outline-offset: -2px !important;
    }
    /* Ensure MAIDR containers do not shift layout */
    figure, article {
      margin: 0 !important;
      padding: 0 !important;
      box-sizing: border-box;
    }
  </style>
</head>
<body>
  %s
  %s
</body>
</html>', css_tag, svg_html, js_tag)

  html
}

#' Create iframe HTML tag for isolated MAIDR plot
#'
#' Creates an iframe element with base64-encoded src containing the complete MAIDR plot.
#' Uses data URI with base64 encoding to avoid quote escaping issues with JSON.
#' This isolates each plot in its own document/JavaScript context.
#'
#' @param svg_content Character vector of SVG content with maidr-data attribute
#' @param width Width of the iframe (default: "100\%")
#' @param height Height of the iframe (default: "450px")
#' @param plot_id Unique identifier for the plot
#' @return Character string of iframe HTML
#' @keywords internal
create_maidr_iframe <- function(svg_content, width = "100%", height = "450px", plot_id = NULL) {
  if (is.null(plot_id)) {
    plot_id <- generate_unique_id()
  }

  standalone_html <- create_standalone_html(svg_content)

  # Use base64 encoding to avoid quote escaping issues with JSON in maidr-data
  html_base64 <- base64enc::base64encode(charToRaw(standalone_html))
  data_uri <- paste0("data:text/html;base64,", html_base64)

  iframe_html <- sprintf(
    '<iframe id="maidr-iframe-%s" src="%s" style="width: %s; height: %s; border: none; display: block; margin: 0 auto; outline: none;" title="Accessible MAIDR Plot" aria-label="Interactive accessible chart"></iframe>',
    plot_id,
    data_uri,
    width,
    height
  )

  iframe_html
}
