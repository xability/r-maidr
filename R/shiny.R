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
#' if (interactive()) {
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
#' @param expr An expression that draws a plot. Either a ggplot object, or
#'   Base R plotting calls -- their return values differ
#'   (\code{plot()} returns NULL, \code{barplot()} returns bar midpoints)
#'   and are ignored; what counts is whether the expression drew. An
#'   expression that draws nothing and returns NULL renders nothing, per
#'   Shiny convention.
#' @param env The environment in which to evaluate expr
#' @param quoted Is expr a quoted expression
#' @return A Shiny render function for use in server
#' @examples
#' if (interactive()) {
#'   library(shiny)
#'   library(ggplot2)
#'   server <- function(input, output) {
#'     output$myplot <- render_maidr({
#'       ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'         geom_bar(stat = "identity")
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

  # A Base R plotting call's RETURN VALUE says nothing useful about whether
  # it drew. `plot()` returns NULL invisibly, `barplot()` returns the bar
  # midpoints, `hist()` returns the histogram object. Branching on that
  # value broke both shapes in Shiny: `render_maidr({ plot(x, y) })` was
  # treated as an empty reactive and rendered a silent blank, while
  # `render_maidr({ barplot(...) })` passed a numeric matrix to
  # maidr_widget() and errored the output slot. Only ggplot happened to work.
  #
  # Ask the recorder instead: did THIS evaluation draw anything? A count
  # taken before and after is what distinguishes "drew, then returned
  # something unhelpful" from "returned without drawing". Checking merely
  # that the device is non-empty would re-render the previous plot every
  # time a reactive later returns NULL.
  expr2 <- quote({
    device_before <- grDevices::dev.cur()
    calls_before <- length(get_device_calls(device_before))

    plot_result <- func()

    device_after <- grDevices::dev.cur()
    drew_something <- if (identical(device_after, device_before)) {
      length(get_device_calls(device_after)) > calls_before
    } else {
      # The evaluation opened its own device -- the usual case, since the
      # first Base R call in a session opens maidr's temp device
      has_device_calls(device_after)
    }

    if (inherits(plot_result, "ggplot")) {
      maidr_widget(plot_result)
    } else if (drew_something && is_patching_active()) {
      # A Base R call that drew to the recorded device; its return value is
      # irrelevant, so hand over to Base R auto-detection
      maidr_widget(NULL)
    } else if (is.null(plot_result)) {
      # Shiny's convention: an empty reactive renders nothing
      NULL
    } else {
      # Not a plot and nothing was drawn -- let maidr_widget() raise its
      # own "Input must be a ggplot object" error rather than fail silently
      maidr_widget(plot_result)
    }
  })

  htmlwidgets::shinyRenderWidget(expr2, maidr_widget_output, environment(), quoted)
}
