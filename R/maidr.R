#' Display Interactive MAIDR Plot
#'
#' Display a ggplot2 or Base R plot as an interactive, accessible visualization
#' using the MAIDR (Multimodal Access and Interactive Data Representation) system.
#'
#' @param plot A ggplot2 object or NULL for Base R auto-detection
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param as_widget If TRUE, returns an htmlwidget object instead of opening in browser
#' @param ... Additional arguments passed to internal functions
#' @returns Invisible NULL. The plot is displayed in RStudio Viewer or browser as a side effect.
#' @examples
#' # ggplot2 example
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_bar(stat = "identity")
#' \dontrun{
#'   maidr::show(p)
#' }
#'
#' # Base R example
#' \dontrun{
#'   barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
#'   maidr::show()
#' }
#' @export
show <- function(plot = NULL, shiny = FALSE, as_widget = FALSE, ...) {
  device_id <- grDevices::dev.cur()

  if (is.null(plot)) {
    if (!is_patching_active() || !has_device_calls(device_id)) {
      stop(
        "No Base R plots detected. Please create a plot first ",
        "(e.g., barplot(), plot())."
      )
    }
    plot <- NULL
  }

  if (as_widget) {
    return(maidr_widget(plot, ...))
  }

  if (shiny) {
    return(create_maidr_html(plot, shiny = TRUE, ...))
  }

  html_doc <- create_maidr_html(plot, ...)

  if (is.null(plot)) {
    clear_device_storage(device_id)
  }

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

  # All plot types now use the unified orchestrator data generation
  maidr_data <- orchestrator$generate_maidr_data()

  svg_content <- create_enhanced_svg(gt, maidr_data, ...)

  if (shiny) {
    return(htmltools::HTML(paste(svg_content, collapse = "\n")))
  }

  html_doc <- create_html_document(svg_content)
  html_doc
}

#' Save Interactive Plot as HTML File
#'
#' Save a ggplot2 or Base R plot as a standalone HTML file with interactive
#' MAIDR accessibility features.
#'
#' @param plot A ggplot2 object or NULL for Base R auto-detection
#' @param file File path where to save the HTML file (e.g., "plot.html")
#' @param ... Additional arguments passed to internal functions
#' @returns The file path where the HTML was saved (invisibly)
#' @examples
#' # ggplot2 example
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_bar(stat = "identity")
#' \dontrun{
#'   maidr::save_html(p, "myplot.html")
#' }
#'
#' # Base R example
#' \dontrun{
#'   barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
#'   maidr::save_html(file = "barplot.html")
#' }
#' @export
save_html <- function(plot = NULL, file = "plot.html", ...) {
  device_id <- grDevices::dev.cur()

  if (is.null(plot)) {
    if (!is_patching_active() || !has_device_calls(device_id)) {
      stop(
        "No Base R plots detected. Please create a plot first ",
        "(e.g., barplot(), plot())."
      )
    }
    plot <- NULL
  }

  html_doc <- create_maidr_html(plot, ...)

  if (is.null(plot)) {
    clear_device_storage(device_id)
  }

  save_html_document(html_doc, file)

  invisible(file)
}
