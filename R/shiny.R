#' MAIDR Shiny Connector
#'
#' This file contains the Shiny integration functions for MAIDR plots.
#' It provides the interface between MAIDR and Shiny applications.

#' Create a MAIDR output container for Shiny UI
#'
#' Creates a Shiny output container for MAIDR widgets using htmlwidgets.
#' This provides automatic dependency injection and robust JavaScript initialization.
#'
#' @param outputId The output variable to read the plot from
#' @param width The width of the plot container (default: "100%")
#' @param height The height of the plot container (default: "400px")
#' @return A Shiny widget output function
#' @export
maidrOutput <- function(outputId, width = "100%", height = "400px") {
  htmlwidgets::shinyWidgetOutput(outputId, "maidr", width, height)
}

#' Render MAIDR plot in Shiny server
#'
#' Creates a Shiny render function for MAIDR widgets using htmlwidgets.
#' This provides automatic dependency injection and robust JavaScript initialization.
#'
#' @param expr An expression that returns a ggplot object
#' @param env The environment in which to evaluate expr
#' @param quoted Is expr a quoted expression
#' @return A Shiny render function
#' @export
renderMaidr <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) {
    quoted <- TRUE
    expr <- substitute(expr)
  }

  shiny::installExprFunction(expr, "func", env, quoted)

  expr2 <- quote(maidr_widget(func()))

  htmlwidgets::shinyRenderWidget(expr2, maidr_widgetOutput, environment(), quoted)
}
