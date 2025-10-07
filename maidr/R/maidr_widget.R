#' Create a MAIDR htmlwidget
#'
#' Creates an interactive MAIDR widget from a ggplot object using htmlwidgets.
#' This provides automatic dependency injection and robust JavaScript initialization.
#'
#' @param plot A ggplot object to render as an interactive MAIDR widget
#' @param width The width of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param height The height of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param elementId A unique identifier for the widget (default: NULL for auto-generated)
#' @param ... Additional arguments passed to create_maidr_html()
#' @return An htmlwidget object that can be displayed in RStudio, Shiny, or saved as HTML
#' @export
maidr_widget <- function(plot, width = NULL, height = NULL, elementId = NULL, ...) {
  cat("=== MAIDR_WIDGET CALLED ===\n")
  
  # Validate input
  cat("Validating plot input...\n")
  cat("Plot class:", class(plot), "\n")
  cat("Plot inherits ggplot:", inherits(plot, "ggplot"), "\n")
  
  if (!inherits(plot, "ggplot")) {
    cat("ERROR: Input is not a ggplot object\n")
    stop("Input must be a ggplot object.")
  }
  
  cat("Plot validation passed\n")
  
  # Generate SVG using existing MAIDR pipeline
  cat("Calling create_maidr_html...\n")
  tryCatch({
    svg_content <- create_maidr_html(plot, shiny = TRUE, ...)
    cat("create_maidr_html completed successfully\n")
    cat("SVG content type:", class(svg_content), "\n")
    cat("SVG content length:", length(svg_content), "\n")
  }, error = function(e) {
    cat("ERROR in create_maidr_html:", e$message, "\n")
    traceback()
    stop(e)
  })
  
  # Define dependencies manually since YAML CDN approach has issues
  cat("Creating dependencies...\n")
  maidr_deps <- list(
    htmltools::htmlDependency(
      name = "maidr-js",
      version = "1.0.0",
      src = c(href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist"),
      script = "maidr.js",
      stylesheet = "maidr_style.css"
    )
  )
  cat("Dependencies created\n")
  
  # Create htmlwidget with manual dependencies
  cat("Creating htmlwidget...\n")
  tryCatch({
    widget <- htmlwidgets::createWidget(
      name = "maidr",
      x = list(svg_content = as.character(svg_content)),
      width = width,
      height = height,
      elementId = elementId,
      dependencies = maidr_deps,
      sizingPolicy = htmlwidgets::sizingPolicy(
        browser.fill = TRUE,
        browser.padding = 0,
        defaultWidth = '100%',
        defaultHeight = 'auto',
        viewer.fill = FALSE,
        viewer.padding = 5,
        knitr.figure = FALSE,
        knitr.defaultWidth = '100%',
        knitr.defaultHeight = 'auto'
      )
    )
    cat("htmlwidget created successfully\n")
    cat("Widget class:", class(widget), "\n")
    return(widget)
  }, error = function(e) {
    cat("ERROR in htmlwidget creation:", e$message, "\n")
    traceback()
    stop(e)
  })
}

#' Create a MAIDR widget output for Shiny
#'
#' Creates a Shiny output function for MAIDR widgets.
#' This function should be used in the UI part of a Shiny application.
#'
#' @param outputId The output variable to read the widget from
#' @param width The width of the widget (default: "100%")
#' @param height The height of the widget (default: "400px")
#' @return A Shiny widget output function
#' @export
maidr_widgetOutput <- function(outputId, width = "100%", height = "400px") {
  htmlwidgets::shinyWidgetOutput(outputId, "maidr", width, height)
}

#' Render a MAIDR widget in Shiny
#'
#' Creates a Shiny render function for MAIDR widgets.
#' This function should be used in the server part of a Shiny application.
#'
#' @param expr An expression that returns a ggplot object
#' @param env The environment in which to evaluate expr
#' @param quoted Is expr a quoted expression
#' @return A Shiny render function
#' @export
renderMaidrWidget <- function(expr, env = parent.frame(), quoted = FALSE) {
  htmlwidgets::shinyRenderWidget(expr, maidr_widgetOutput, env, quoted)
}
