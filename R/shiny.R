#' MAIDR Shiny Connector
#'
#' This file contains the Shiny integration functions for MAIDR plots.
#' It provides the interface between MAIDR and Shiny applications.
#'
#' @importFrom shiny installExprFunction
NULL

#' MAIDR Output Container for Shiny UI
#'
#' Creates a Shiny output container for MAIDR widgets using htmlwidgets.
#' This provides automatic dependency injection and robust JavaScript initialization.
#'
#' @param output_id The output variable to read the plot from
#' @param width The width of the plot container (default: "100percent")
#' @param height The height of the plot container (default: "400px")
#' @return A Shiny widget output function for use in UI
#' @examples
#' \dontrun{
#'   library(shiny)
#'   ui <- fluidPage(maidr_output("myplot"))
#' }
#' @export
maidr_output <- function(output_id, width = "100%", height = "400px") {
  htmlwidgets::shinyWidgetOutput(output_id, "maidr", width, height)
}

#' Render MAIDR Plot in Shiny Server
#'
#' Creates a Shiny render function for MAIDR widgets using htmlwidgets.
#' This provides automatic dependency injection and robust JavaScript initialization.
#'
#' @param expr An expression that returns a ggplot object
#' @param env The environment in which to evaluate expr
#' @param quoted Is expr a quoted expression
#' @return A Shiny render function for use in server
#' @examples
#' \dontrun{
#'   library(shiny)
#'   library(ggplot2)
#'   server <- function(input, output) {
#'     output$myplot <- render_maidr({
#'       ggplot(mtcars, aes(x = factor(cyl), y = mpg)) + geom_bar(stat = "identity")
#'     })
#'   }
#' }
#' @export
render_maidr <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) {
    quoted <- TRUE
    expr <- substitute(expr)
  }

  shiny::installExprFunction(expr, "func", env, quoted)

  expr2 <- quote(maidr_widget(func()))

  htmlwidgets::shinyRenderWidget(expr2, maidr_widget_output, environment(), quoted)
}
