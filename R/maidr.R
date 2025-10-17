#' Display a plot in RStudio Viewer or browser
#' @param plot A ggplot2 object or NULL for Base R auto-detection
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param as_widget If TRUE, returns an htmlwidget object instead of opening in browser
#' @param ... Additional arguments passed to internal functions
#' @export
show <- function(plot = NULL, shiny = FALSE, as_widget = FALSE, ...) {
  # If no plot provided, try Base R auto-detection
  if (is.null(plot)) {
    if (!is_patching_active() || length(get_plot_calls()) == 0) {
      stop("No Base R plots detected. Please create a plot first (e.g., barplot(), plot()).")
    }
    plot <- NULL
  }

  # Use existing logic for both ggplot2 and Base R
  if (as_widget) {
    return(maidr_widget(plot, ...))
  }

  # Shiny mode - return just the SVG content
  if (shiny) {
    return(create_maidr_html(plot, shiny = TRUE, ...))
  }

  # Default behavior - create full HTML document and display it
  html_doc <- create_maidr_html(plot, ...)

  if (is.null(plot)) {
    clear_plot_calls()
  }

  # Always display the HTML document
  display_html(html_doc)

  invisible(NULL)
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

#' Save a plot as an HTML file
#' @param plot A ggplot2 object or NULL for Base R auto-detection
#' @param file File path where to save the HTML file (e.g., "plot.html")
#' @param ... Additional arguments passed to internal functions
#' @return The file path where the HTML was saved
#' @export
save_html <- function(plot = NULL, file = "plot.html", ...) {
  # If no plot provided, try Base R auto-detection
  if (is.null(plot)) {
    if (!is_patching_active() || length(get_plot_calls()) == 0) {
      stop("No Base R plots detected. Please create a plot first (e.g., barplot(), plot()).")
    }
    plot <- NULL
  }

  # Create the HTML document
  html_doc <- create_maidr_html(plot, ...)

  if (is.null(plot)) {
    clear_plot_calls()
  }

  # Save the HTML document to file
  save_html_document(html_doc, file)

  invisible(file)
}
