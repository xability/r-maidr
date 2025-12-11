#' @importFrom htmlwidgets createWidget sizingPolicy shinyWidgetOutput shinyRenderWidget
NULL

#' Create MAIDR htmlwidget
#'
#' Internal function that creates an interactive MAIDR widget from a ggplot object.
#' This is called internally by render_maidr() and should not be called directly.
#' Use maidr_output() and render_maidr() for Shiny integration instead.
#'
#' @param plot A ggplot object to render as an interactive MAIDR widget
#' @param width The width of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param height The height of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param element_id A unique identifier for the widget (default: NULL for auto-generated)
#' @param ... Additional arguments passed to create_maidr_html()
#' @return An htmlwidget object that can be displayed in RStudio, Shiny, or saved as HTML
#' @keywords internal
maidr_widget <- function(plot, width = NULL, height = NULL, element_id = NULL, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  svg_content <- create_maidr_html(plot, shiny = TRUE, ...)

  # Use centralized MAIDR dependencies (local files with CDN fallback)
  maidr_deps <- maidr_html_dependencies()

  htmlwidgets::createWidget(
    name = "maidr",
    x = list(svg_content = as.character(svg_content)),
    width = width,
    height = height,
    elementId = element_id,
    dependencies = maidr_deps,
    sizingPolicy = htmlwidgets::sizingPolicy(
      browser.fill = TRUE,
      browser.padding = 0,
      defaultWidth = "100%",
      defaultHeight = "auto",
      viewer.fill = FALSE,
      viewer.padding = 5,
      knitr.figure = FALSE,
      knitr.defaultWidth = "100%",
      knitr.defaultHeight = "auto"
    )
  )
}

#' MAIDR Widget Output for Shiny UI (Internal Alternative)
#'
#' Internal alternative Shiny UI function. This provides the same functionality
#' as maidr_output() but is no longer recommended for direct use.
#' Use maidr_output() and render_maidr() instead for better consistency.
#'
#' @param output_id The output variable to read the widget from
#' @param width The width of the widget (default: "100percent")
#' @param height The height of the widget (default: "400px")
#' @return A Shiny widget output function for use in UI
#' @keywords internal
maidr_widget_output <- function(output_id, width = "100%", height = "400px") {
  htmlwidgets::shinyWidgetOutput(output_id, "maidr", width, height)
}

#' Render MAIDR Widget in Shiny Server (Internal Alternative)
#'
#' Internal alternative Shiny server function. This provides the same functionality
#' as render_maidr() but is no longer recommended for direct use.
#' Use maidr_output() and render_maidr() instead for better consistency.
#'
#' @param expr An expression that returns a ggplot object
#' @param env The environment in which to evaluate expr
#' @param quoted Is expr a quoted expression
#' @return A Shiny render function for use in server
#' @keywords internal
render_maidr_widget <- function(expr, env = parent.frame(), quoted = FALSE) {
  htmlwidgets::shinyRenderWidget(expr, maidr_widget_output, env, quoted)
}
