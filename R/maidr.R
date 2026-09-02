#' Display Interactive MAIDR Plot
#'
#' Display a ggplot2 or Base R plot as an interactive, accessible visualization
#' using the MAIDR (Multimodal Access and Interactive Data Representation) system.
#'
#' @param plot A ggplot2 object or NULL for Base R auto-detection
#' @param use_cdn Logical. Controls where MAIDR.js is loaded from:
#'   \itemize{
#'     \item \code{TRUE}: Use CDN (requires internet)
#'     \item \code{FALSE}: Use local bundled files (works offline)
#'     \item \code{NULL} (default): Use the bundled files, so the viewer
#'       works offline. With \code{as_widget = TRUE} the widget instead
#'       auto-detects internet availability and uses the CDN when online,
#'       as the knitr and Shiny paths do.
#'   }
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param as_widget If TRUE, returns an htmlwidget object instead of opening in browser
#' @param ... Additional arguments passed to internal functions
#' @return Invisible NULL. The plot is displayed in RStudio Viewer or browser as a side effect.
#' @examples
#' # ggplot2 bar chart
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_bar(stat = "identity")
#' \donttest{
#' maidr::show(p)
#' }
#'
#' # ggplot2 violin plot
#' p_violin <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_violin(fill = "lightblue", alpha = 0.7) +
#'   labs(title = "MPG by Cylinders", x = "Cylinders", y = "MPG")
#' \donttest{
#' maidr::show(p_violin)
#' }
#'
#' # Base R example (requires interactive session for function patching)
#' if (interactive()) {
#'   barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
#'   maidr::show()
#' }
#' @importFrom R6 R6Class
#' @importFrom ggplotify as.grob
#' @export
show <- function(plot = NULL, use_cdn = NULL, shiny = FALSE, as_widget = FALSE, ...) {
  device_id <- grDevices::dev.cur()
  is_base_r <- is.null(plot)

  if (is_base_r) {
    if (!is_patching_active() || !has_device_calls(device_id)) {
      stop(no_base_r_plots_message(), call. = FALSE)
    }
  }

  orchestrator <- NULL

  # Check for unsupported plots early - use native graphics fallback
  if (!shiny && !as_widget) {
    registry <- get_global_registry()
    system_name <- registry$detect_system(plot)
    adapter <- registry$get_adapter(system_name)
    orchestrator <- adapter$create_orchestrator(plot)

    if (orchestrator$should_fallback()) {
      if (is_fallback_warning_enabled()) {
        warning(
          "Plot contains unsupported elements. ",
          "Displaying in native graphics device instead of interactive MAIDR plot.",
          call. = FALSE
        )
      }

      if (is_base_r) {
        # Base R: Plot is already drawn - replay to native device
        replay_to_native_device(device_id)
        clear_device_storage(device_id)
      } else {
        # ggplot2: Print to native graphics device with ggplot2's own
        # method, not the one maidr registered, which would run the support
        # check a second time.
        grDevices::dev.new()
        print_ggplot_natively(plot)
      }

      return(invisible(NULL))
    }
  }

  if (as_widget) {
    result <- maidr_widget(plot, use_cdn = use_cdn, ...)
    if (is_base_r) {
      clear_device_storage(device_id)
      close_maidr_temp_device()
    }
    return(result)
  }

  if (shiny) {
    result <- create_maidr_html(plot, use_cdn = use_cdn, shiny = TRUE, ...)
    if (is_base_r) {
      clear_device_storage(device_id)
      close_maidr_temp_device()
    }
    return(result)
  }

  # Reuse the orchestrator from the fallback check above: creating a new
  # one would re-run the entire layer-processing pipeline.
  html_doc <- create_maidr_html(
    plot,
    use_cdn = use_cdn,
    orchestrator = orchestrator,
    ...
  )

  if (is_base_r) {
    clear_device_storage(device_id)
    # Close the temp device created by wrappers to suppress default graphics window
    close_maidr_temp_device()
  }

  display_html(html_doc)

  invisible(NULL)
}

#' Create HTML document with maidr enhancements using the orchestrator
#' @param plot A ggplot2 object
#' @param use_cdn Logical. If `TRUE`, use CDN. If `FALSE` or `NULL`
#'   (default), use bundled files; see [maidr_html_dependencies()].
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param orchestrator Optional pre-created orchestrator to reuse (avoids double creation)
#' @param ... Additional arguments passed to internal functions
#' @return An htmltools HTML document object or SVG content
#' @keywords internal
create_maidr_html <- function(plot, use_cdn = NULL, shiny = FALSE, orchestrator = NULL, ...) {
  # Use provided orchestrator or create a new one
  if (is.null(orchestrator)) {
    registry <- get_global_registry()
    system_name <- registry$detect_system(plot)
    adapter <- registry$get_adapter(system_name)
    orchestrator <- adapter$create_orchestrator(plot)
  }

  # Check if we should fall back to image rendering
  if (orchestrator$should_fallback()) {
    if (is_fallback_warning_enabled()) {
      warning(
        "Plot contains unsupported elements. ",
        "Rendering as static image instead of interactive MAIDR plot.",
        call. = FALSE
      )
    }
    return(create_fallback_html(plot, shiny = shiny, ...))
  }

  warn_panel_fallback(orchestrator)

  svg_content <- build_interactive_svg(orchestrator, ...)

  # `build_interactive_svg()` answers NULL for a plot that could not be built,
  # which is the same outcome as the gate above reaching a chart it cannot
  # read: a picture rather than nothing.
  if (is.null(svg_content)) {
    return(create_fallback_html(plot, shiny = shiny, ...))
  }

  if (shiny) {
    return(htmltools::HTML(paste(svg_content, collapse = "\n")))
  }

  html_doc <- create_html_document(svg_content, use_cdn = use_cdn)
  html_doc
}

#' Build the Interactive SVG, or Answer NULL When It Cannot Be Built
#'
#' `should_fallback()` answers whether the recorded layers are ones maidr can
#' read. It cannot answer whether the plot can be *exported*, because that is
#' gridSVG's question and gridSVG is not consulted until the export runs. Two
#' base R charts fail there on plots that pass the gate -- `matplot()` with
#' "non-numeric argument to binary operator" and `symbols()` with gridSVG's
#' own "We shouldn't be here!" assertion, both raised inside `grid.export()`
#' rather than by anything this package computes.
#'
#' Left to propagate, those kill the save outright: the caller gets neither
#' the interactive chart nor the static image, and an error naming a package
#' they never called. The lower claim the package makes about a recorded plot
#' is that it is *at worst a picture* (#216), and an export that throws is no
#' more a reason to break that than a layer it cannot classify.
#'
#' The whole build is guarded rather than the export alone. From the caller's
#' side the gtable, the data and the SVG are one step -- producing the
#' interactive chart -- and which of the three threw does not change what they
#' should be given instead.
#'
#' `maidr_set_fallback(enabled = FALSE)` is the caller asking for the failure
#' rather than the picture, so the error is re-raised untouched there.
#'
#' @param orchestrator The orchestrator for the plot being rendered.
#' @param ... Passed through to `create_enhanced_svg()`.
#' @return The SVG content, or `NULL` when the build failed and fallback is
#'   enabled.
#' @keywords internal
build_interactive_svg <- function(orchestrator, ...) {
  build <- function() {
    gt <- orchestrator$get_gtable()

    # All plot types now use the unified orchestrator data generation
    maidr_data <- orchestrator$generate_maidr_data()

    create_enhanced_svg(gt, maidr_data, ...)
  }

  if (!is_fallback_enabled()) {
    return(build())
  }

  tryCatch(build(), error = function(e) {
    if (is_fallback_warning_enabled()) {
      warning(
        "Plot could not be rendered interactively (",
        conditionMessage(e),
        "). Rendering as static image instead.",
        call. = FALSE
      )
    }
    NULL
  })
}

#' Warn About Panels That Lost Their Accessible Data
#'
#' Emitted from the single place every render path funnels through, so a
#' figure is described once no matter which entry point produced it.
#'
#' @param orchestrator The orchestrator about to render the figure
#' @return Invisibly NULL
#' @keywords internal
warn_panel_fallback <- function(orchestrator) {
  if (!is_fallback_warning_enabled()) {
    return(invisible(NULL))
  }
  # Only the Base R orchestrator scopes a fallback to panels; on any other
  # orchestrator this member is simply absent.
  if (!is.function(orchestrator$fallback_panels)) {
    return(invisible(NULL))
  }

  panels <- orchestrator$fallback_panels()
  if (length(panels) == 0) {
    return(invisible(NULL))
  }

  warning(format_panel_fallback_warning(panels), call. = FALSE)

  invisible(NULL)
}

#' Save Interactive Plot as HTML File
#'
#' Save a ggplot2 or Base R plot as a standalone HTML file with interactive
#' MAIDR accessibility features.
#'
#' @param plot A ggplot2 object or NULL for Base R auto-detection
#' @param file File path where to save the HTML file (e.g., "plot.html")
#' @param use_cdn Logical. Controls where MAIDR.js is loaded from:
#'   \itemize{
#'     \item \code{TRUE}: Use CDN. The file is self-contained but needs
#'       internet access when it is viewed.
#'     \item \code{FALSE} or \code{NULL} (default): Use the bundled files.
#'       The MAIDR.js library is written to a \code{lib/} folder beside
#'       \code{file}, which has to travel with it.
#'   }
#' @param ... Additional arguments passed to internal functions
#' @return The file path where the HTML was saved (invisibly)
#' @examples
#' # ggplot2 bar chart
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_bar(stat = "identity")
#' \donttest{
#' maidr::save_html(p, tempfile(fileext = ".html"))
#' }
#'
#' # ggplot2 violin plot
#' p_violin <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_violin(fill = "lightblue", alpha = 0.7) +
#'   labs(title = "MPG by Cylinders", x = "Cylinders", y = "MPG")
#' \donttest{
#' maidr::save_html(p_violin, tempfile(fileext = ".html"))
#' }
#'
#' # Base R example (requires interactive session for function patching)
#' if (interactive()) {
#'   barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
#'   maidr::save_html(file = tempfile(fileext = ".html"))
#' }
#' @export
save_html <- function(plot = NULL, file = "plot.html", use_cdn = NULL, ...) {
  device_id <- grDevices::dev.cur()
  is_base_r <- is.null(plot)

  if (is_base_r) {
    if (!is_patching_active() || !has_device_calls(device_id)) {
      stop(no_base_r_plots_message(), call. = FALSE)
    }
  }

  html_doc <- create_maidr_html(plot, use_cdn = use_cdn, ...)

  if (is_base_r) {
    clear_device_storage(device_id)
    # Close the temp device created by wrappers to suppress default graphics window
    close_maidr_temp_device()
  }

  save_html_document(html_doc, file)

  invisible(file)
}
