#' Enable MAIDR Rendering in RMarkdown
#'
#' Enables automatic accessible rendering of ggplot2 and Base R plots
#' in RMarkdown documents. When enabled, plots are automatically converted
#' to interactive MAIDR widgets with keyboard navigation and screen reader support.
#'
#' @return Invisible TRUE on success
#' @examples
#' \dontrun{
#' # In RMarkdown setup chunk:
#' library(maidr)
#' maidr_on()
#'
#' # Now all plots render as accessible MAIDR widgets
#' library(ggplot2)
#' ggplot(mtcars, aes(x = factor(cyl))) +
#'   geom_bar()
#'
#' barplot(table(mtcars$cyl))
#' }
#' @seealso [maidr_off()] to disable MAIDR rendering
#' @export
maidr_on <- function() {
  # Check if knitr is available
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("knitr package is required for RMarkdown integration")
  }

  # Enable Base R function patching
  initialize_base_r_patching()

  # Register knit_print method for ggplot
  registerS3method(
    "knit_print",
    "ggplot",
    knit_print.ggplot,
    envir = asNamespace("knitr")
  )

  # Register knit_print methods to suppress return value printing
  # for plotting functions that return visible objects
  registerS3method(
    "knit_print",
    "histogram",
    knit_print.histogram,
    envir = asNamespace("knitr")
  )

  registerS3method(
    "knit_print",
    "density",
    knit_print.density,
    envir = asNamespace("knitr")
  )

  # Store original plot hook
  .maidr_knitr_state$original_plot_hook <- knitr::knit_hooks$get("plot")

  # Override the plot hook to intercept Base R plots
  knitr::knit_hooks$set(plot = maidr_plot_hook)

  # Store state
  .maidr_knitr_state$enabled <- TRUE

  invisible(TRUE)
}

#' Disable MAIDR Rendering in RMarkdown
#'
#' Disables automatic MAIDR rendering and restores normal plot behavior.
#'
#' @return Invisible TRUE on success
#' @seealso [maidr_on()] to enable MAIDR rendering
#' @export
maidr_off <- function() {
  # Restore original Base R functions
  restore_original_functions()

  # Reset knitr hooks
  if (requireNamespace("knitr", quietly = TRUE)) {
    # Restore original plot hook
    if (!is.null(.maidr_knitr_state$original_plot_hook)) {
      knitr::knit_hooks$set(plot = .maidr_knitr_state$original_plot_hook)
    }
  }

  # Update state
  .maidr_knitr_state$enabled <- FALSE

  invisible(TRUE)
}

#' Check if MAIDR RMarkdown Mode is Enabled
#'
#' @return Logical indicating if MAIDR mode is active
#' @keywords internal
is_maidr_on <- function() {
  isTRUE(.maidr_knitr_state$enabled)
}

#' Custom knit_print Method for ggplot Objects
#'
#' Converts ggplot objects to MAIDR widgets for accessible rendering in RMarkdown.
#' Uses iframe-based isolation to ensure each plot has its own MAIDR.js context.
#'
#' @param x A ggplot object
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return A knit_asis object containing the iframe HTML
#' @keywords internal
knit_print.ggplot <- function(x, options = list(), ...) {
  # Get SVG content using existing infrastructure
  svg_content <- create_maidr_html(x, shiny = TRUE)

  # Create iframe with isolated MAIDR context
  iframe_html <- create_maidr_iframe(
    svg_content = svg_content,
    width = "100%",
    height = "450px"
  )

  # Return as raw HTML
  knitr::asis_output(iframe_html)
}

#' Custom knit_print Method for histogram Objects
#'
#' Suppresses the default printing of histogram return values in RMarkdown.
#' The plot is already rendered via the plot hook; this prevents the
#' histogram object structure from being printed as text output.
#'
#' @param x A histogram object (from hist())
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return An invisible empty string
#' @keywords internal
knit_print.histogram <- function(x, options = list(), ...) {
  # Return invisible empty output to suppress printing
  invisible(knitr::asis_output(""))
}

#' Custom knit_print Method for density Objects
#'
#' Suppresses the default printing of density return values in RMarkdown.
#' The density() function is not patched (it's in stats, not graphics),
#' so we need this method to suppress its output.
#'
#' @param x A density object (from density())
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return An invisible empty string
#' @keywords internal
knit_print.density <- function(x, options = list(), ...) {
  invisible(knitr::asis_output(""))
}

#' Create MAIDR Widget for knitr (Internal)
#'
#' Internal function to create a MAIDR widget from either ggplot or Base R plots.
#'
#' @param plot A ggplot object or NULL for Base R
#' @return An htmlwidget object
#' @keywords internal
create_maidr_widget_internal <- function(plot = NULL) {
  # Get SVG content using existing infrastructure
  svg_content <- create_maidr_html(plot, shiny = TRUE)

  # Use centralized MAIDR dependencies (local files with CDN fallback)
  maidr_deps <- maidr_html_dependencies()

  htmlwidgets::createWidget(
    name = "maidr",
    x = list(svg_content = as.character(svg_content)),
    width = NULL,
    height = NULL,
    elementId = NULL,
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
      knitr.defaultHeight = "400px"
    )
  )
}

#' knitr Plot Hook for Base R Plots
#'
#' Intercepts Base R plot output and converts to MAIDR iframe.
#' Uses iframe-based isolation to ensure each plot has its own MAIDR.js context.
#' This replaces knitr's default plot hook when maidr_on() is called.
#'
#' @param x The plot file path from knitr
#' @param options Chunk options
#' @return HTML string for the plot
#' @keywords internal
maidr_plot_hook <- function(x, options) {
  device_id <- grDevices::dev.cur()

  # Check if we have captured Base R calls
  if (has_device_calls(device_id)) {
    # Get SVG content from captured Base R plot
    svg_content <- create_maidr_html(plot = NULL, shiny = TRUE)

    # Clear the device storage
    clear_device_storage(device_id)

    # Create iframe with isolated MAIDR context
    iframe_html <- create_maidr_iframe(
      svg_content = svg_content,
      width = "100%",
      height = "450px"
    )

    # Return as raw HTML
    return(iframe_html)
  }

  # Fall back to original plot hook if no Base R calls captured
  original_hook <- .maidr_knitr_state$original_plot_hook
  if (!is.null(original_hook) && is.function(original_hook)) {
    return(original_hook(x, options))
  }

  # Default: return standard image tag
  knitr::hook_plot_md(x, options)
}

# Internal state for knitr integration
.maidr_knitr_state <- new.env(parent = emptyenv())
.maidr_knitr_state$enabled <- FALSE
.maidr_knitr_state$original_plot_hook <- NULL
