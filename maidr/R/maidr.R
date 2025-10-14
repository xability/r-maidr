#' Display a plot in the appropriate environment (browser, Viewer, etc.)
#' @param plot A ggplot2 object
#' @param file Optional file path to save HTML. If NULL, creates temporary file
#' @param open Whether to open the HTML file in browser/RStudio Viewer
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param as_widget If TRUE, returns an htmlwidget object instead of opening in browser
#' @param ... Additional arguments passed to internal functions
#' @export
show <- function(plot, file = NULL, open = TRUE, shiny = FALSE, as_widget = FALSE, ...) {
  if (as_widget) {
    return(maidr_widget(plot, ...))
  }

  # Shiny mode - return just the SVG content
  if (shiny) {
    return(create_maidr_html(plot, shiny = TRUE, ...))
  }

  # Default behavior - create full HTML document
  html_doc <- create_maidr_html(plot, ...)

  if (is.null(file)) {
    if (open) display_html(html_doc)
    result <- NULL
  } else {
    save_html_document(html_doc, file)
    if (open) display_html_file(file)
    result <- file
  }

  invisible(result)
}

#' Create HTML document with maidr enhancements using the orchestrator
#' @param plot A ggplot2 object
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param ... Additional arguments passed to internal functions
#' @return An htmltools HTML document object or SVG content
#' @keywords internal
create_maidr_html <- function(plot, shiny = FALSE, ...) {
  registry <- get_global_registry()

  system_name <- registry$detect_system(plot)

  adapter <- registry$get_adapter(system_name)

  orchestrator <- adapter$create_orchestrator(plot)

  gt <- orchestrator$get_gtable()

  layout <- orchestrator$get_layout()

  # All plot types now use the unified orchestrator data generation
  maidr_data <- orchestrator$generate_maidr_data()

  svg_content <- create_enhanced_svg(gt, maidr_data, ...)

  if (shiny) {
    return(htmltools::HTML(paste(svg_content, collapse = "\n")))
  }

  html_doc <- create_html_document(svg_content)
  html_doc
}
