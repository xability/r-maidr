#' Create MAIDR htmlwidget
#'
#' Creates an interactive MAIDR widget from a ggplot object using htmlwidgets.
#' This provides automatic dependency injection and robust JavaScript initialization.
#'
#' @param plot A ggplot object to render as an interactive MAIDR widget
#' @param width The width of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param height The height of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param element_id A unique identifier for the widget (default: NULL for auto-generated)
#' @param ... Additional arguments passed to create_maidr_html()
#' @returns An htmlwidget object that can be displayed in RStudio, Shiny, or saved as HTML
#' @examples
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) + geom_bar(stat = "identity")
#' \dontrun{
#'   widget <- maidr::maidr_widget(p)
#'   widget
#' }
#' @export
maidr_widget <- function(plot, width = NULL, height = NULL, element_id = NULL, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  svg_content <- create_maidr_html(plot, shiny = TRUE, ...)

  # Define dependencies
  maidr_deps <- list(
    htmltools::htmlDependency(
      name = "maidr-js",
      version = "1.0.0",
      src = c(href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist"),
      script = "maidr.js",
      stylesheet = "maidr_style.css"
    )
  )

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

#' MAIDR Widget Output for Shiny UI
#'
#' Creates a Shiny output function for MAIDR widgets.
#' This function should be used in the UI part of a Shiny application.
#'
#' @param output_id The output variable to read the widget from
#' @param width The width of the widget (default: "100%")
#' @param height The height of the widget (default: "400px")
#' @returns A Shiny widget output function for use in UI
#' @examples
#' \dontrun{
#'   # In Shiny UI
#'   library(shiny)
#'   ui <- fluidPage(maidr_widget_output("plot"))
#' }
#' @export
maidr_widget_output <- function(output_id, width = "100%", height = "400px") {
  htmlwidgets::shinyWidgetOutput(output_id, "maidr", width, height)
}

#' Render MAIDR Widget in Shiny Server
#'
#' Creates a Shiny render function for MAIDR widgets.
#' This function should be used in the server part of a Shiny application.
#'
#' @param expr An expression that returns a ggplot object
#' @param env The environment in which to evaluate expr
#' @param quoted Is expr a quoted expression
#' @returns A Shiny render function for use in server
#' @examples
#' \dontrun{
#'   # In Shiny server
#'   library(shiny)
#'   library(ggplot2)
#'   server <- function(input, output) {
#'     output$plot <- render_maidr_widget({
#'       ggplot(mtcars, aes(x = factor(cyl), y = mpg)) + geom_bar(stat = "identity")
#'     })
#'   }
#' }
#' @export
render_maidr_widget <- function(expr, env = parent.frame(), quoted = FALSE) {
  htmlwidgets::shinyRenderWidget(expr, maidr_widget_output, env, quoted)
}
