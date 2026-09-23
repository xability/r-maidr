#' @importFrom htmlwidgets createWidget sizingPolicy shinyWidgetOutput shinyRenderWidget
NULL

#' Create MAIDR htmlwidget
#'
#' Internal function that creates an interactive MAIDR widget from a ggplot object.
#' This is called internally by render_maidr() and should not be called directly.
#' Use maidr_output() and render_maidr() for Shiny integration instead.
#'
#' Uses iframe-based isolation to ensure MAIDR.js initializes properly.
#' Each widget gets its own isolated JavaScript context where MAIDR.js
#' can discover and initialize the SVG with maidr-data attribute.
#'
#' @param plot A ggplot object, or NULL to auto-detect recorded Base R plots
#' @param use_cdn Logical. Controls where MAIDR.js is loaded from, matching
#'   \code{show()} and \code{save_html()}:
#'   \itemize{
#'     \item \code{TRUE}: Use CDN (requires internet), loading the latest
#'       published MAIDR.js unless \code{maidr.cdn_version} pins one
#'     \item \code{FALSE}: Use local bundled files (works offline)
#'     \item \code{NULL} (default): Auto-detect based on internet availability
#'   }
#'   This differs from \code{maidr_html_dependencies()}, where \code{NULL}
#'   means bundled. The widget renders through \code{create_maidr_iframe()}
#'   and \code{create_standalone_html()}, which probes for connectivity, so
#'   an unset \code{use_cdn} loads from the CDN on a machine that is online.
#' @param width The width of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param height The height of the widget in pixels or CSS units (default: NULL for auto-sizing)
#' @param element_id A unique identifier for the widget (default: NULL for auto-generated)
#' @param ... Additional arguments passed to create_maidr_html()
#' @return An htmlwidget object that can be displayed in RStudio, Shiny, or saved as HTML
#' @keywords internal
maidr_widget <- function(plot, use_cdn = NULL, width = NULL, height = NULL, element_id = NULL, ...) {
  # NULL means Base R auto-detection (recorded plot calls), mirroring show()
  if (is.null(plot)) {
    if (!is_patching_active() || !has_device_calls(grDevices::dev.cur())) {
      stop(no_base_r_plots_message(), call. = FALSE)
    }
  } else if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object or NULL (Base R auto-detection).")
  }

  svg_content <- create_maidr_html(plot, use_cdn = use_cdn, shiny = TRUE, ...)

  # Create iframe HTML with embedded MAIDR.js

  # This ensures MAIDR.js initializes in its own context and properly
  # discovers the SVG with maidr-data attribute
  # Use explicit pixel height since percentage height requires parent height

  # Resolved here rather than left to `create_standalone_html()`, because it
  # decides the widget's dependencies as well as the frame's script.
  if (is.null(use_cdn)) {
    use_cdn <- maidr_internet_available()
  }

  # A frame that loads from the CDN falls back to a copy of the bundle on the
  # widget's page. That copy is what R Markdown's `self_contained` and
  # Quarto's `embed-resources` embed; the frame's own `<script src>`, inside
  # `srcdoc`, is out of their reach.
  iframe_html <- create_maidr_iframe(
    svg_content = svg_content,
    width = "100%",
    height = "400px",
    plot_id = element_id,
    use_cdn = use_cdn,
    page_fallback = use_cdn
  )

  # The page's copy, only for a frame that can fall back to it. A frame that
  # does not load from the CDN carries the bundle inline and never reads the
  # page, so a copy there would be 1.7 MB nothing uses. Declared per widget
  # rather than in an htmlwidgets yaml, which would put it on every page.
  # Named like the knitr paths' copy, so one serves both.
  page_bundle <- if (use_cdn) list(maidr_page_bundle_dependency())

  htmlwidgets::createWidget(
    name = "maidr",
    x = list(iframe_content = iframe_html),
    width = width,
    height = height,
    elementId = element_id,
    dependencies = page_bundle,
    sizingPolicy = htmlwidgets::sizingPolicy(
      browser.fill = TRUE,
      browser.padding = 0,
      defaultWidth = "100%",
      defaultHeight = "400px",
      viewer.fill = FALSE,
      viewer.padding = 5,
      knitr.figure = FALSE,
      knitr.defaultWidth = "100%",
      knitr.defaultHeight = "400px"
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
