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
#' Automatically falls back to image rendering for unsupported plot types or
#' non-HTML output formats (PDF, EPUB).
#'
#' @param x A ggplot object
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return A knit_asis object containing the iframe HTML or inline image
#' @keywords internal
knit_print.ggplot <- function(x, options = list(), ...) {
  # Check output format - only use iframes for HTML output
  if (!is_html_output()) {
    # For PDF/EPUB/LaTeX: let knitr handle the plot natively
    # Print the plot and use default knit_print behavior
    print(x)
    return(invisible(NULL))
  }

  # Create orchestrator ONCE and reuse it
  registry <- get_global_registry()
  adapter <- registry$get_adapter("ggplot2")
  orchestrator <- adapter$create_orchestrator(x)

  if (orchestrator$should_fallback()) {
    # For fallback/unsupported plots in HTML: use inline image (no iframe needed)
    img_html <- create_inline_image(x)
    return(knitr::asis_output(img_html))
  }

  # Get content using the SAME orchestrator (avoid creating another)
  content <- create_maidr_html(x, shiny = TRUE, orchestrator = orchestrator)

  # For supported MAIDR plots in HTML: use full iframe with MAIDR.js
  iframe_html <- create_maidr_iframe(
    svg_content = content,
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
#' Automatically falls back to image rendering for unsupported plot types or
#' non-HTML output formats (PDF, EPUB).
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
    # Check output format - only use iframes for HTML output
    if (!is_html_output()) {
      # For PDF/EPUB/LaTeX: use default knitr handling
      # Clear storage but use standard image output
      clear_device_storage(device_id)
      return(knitr::hook_plot_md(x, options))
    }

    # Create orchestrator ONCE and reuse it
    registry <- get_global_registry()
    adapter <- registry$get_adapter("base_r")
    orchestrator <- adapter$create_orchestrator(NULL)

    if (orchestrator$should_fallback()) {
      # For fallback/unsupported plots in HTML: use inline image (no iframe needed)
      img_html <- create_inline_image(plot = NULL)
      clear_device_storage(device_id)
      return(img_html)
    }

    # Get content using the SAME orchestrator (avoid creating another)
    content <- create_maidr_html(plot = NULL, shiny = TRUE, orchestrator = orchestrator)

    # Clear the device storage
    clear_device_storage(device_id)

    # For supported MAIDR plots in HTML: use full iframe with MAIDR.js
    iframe_html <- create_maidr_iframe(
      svg_content = content,
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

#' Check if current knitr output format is HTML
#'
#' Detects whether the current RMarkdown document is being rendered to HTML
#' format (html_document, bookdown, etc.) vs non-HTML formats (pdf, epub, etc.)
#'
#' @return TRUE if rendering to HTML, FALSE otherwise
#' @keywords internal
is_html_output <- function() {
  # Use knitr's built-in detection if available

  if (requireNamespace("knitr", quietly = TRUE)) {
    # knitr::is_html_output() checks the current output format
    if (exists("is_html_output", where = asNamespace("knitr"))) {
      return(knitr::is_html_output())
    }

    # Fallback: check pandoc output format
    pandoc_to <- knitr::opts_knit$get("rmarkdown.pandoc.to")
    if (!is.null(pandoc_to)) {
      html_formats <- c("html", "html4", "html5", "revealjs", "s5", "slideous", "slidy")
      return(pandoc_to %in% html_formats || grepl("^html", pandoc_to))
    }
  }

  # Default to TRUE (assume HTML) if we can't detect

  TRUE
}

#' Create inline image HTML for non-iframe rendering
#'
#' Creates a simple img tag for fallback/non-HTML output.
#' Used when we don't need iframe isolation (unsupported plots in HTML,
#' or any plot in PDF/EPUB output).
#'
#' @param plot A ggplot object or NULL for Base R
#' @param width Width for the image container
#' @param height Height for the image container
#' @return Character string of HTML with img tag
#' @keywords internal
create_inline_image <- function(plot = NULL, width = "100%", height = "auto") {
  # Generate PNG image
  img_data <- create_fallback_image(plot, format = "png")

  # Create simple inline image HTML
  img_html <- sprintf(
    '<div style="text-align: center; width: %s;"><img src="%s" alt="Plot" style="max-width: 100%%; height: %s;" /></div>',
    width,
    img_data,
    height
  )

  img_html
}
