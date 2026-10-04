#' Display Interactive MAIDR Plot
#'
#' Display a ggplot2, lattice or Base R plot as an interactive, accessible
#' visualization using the MAIDR (Multimodal Access and Interactive Data Representation) system.
#'
#' Attaching maidr masks \code{methods::show()}. An object that is not a
#' plot maidr renders -- an S4 object, a vector, a data frame -- is handed to
#' \code{methods::show()}, so it prints as it did before maidr was attached.
#' In a script or a package, call \code{maidr::show()} and
#' \code{methods::show()} by name; \code{?"base-r-wrappers"} lists
#' everything else attaching maidr masks.
#'
#' Under webR there is no browser to open, so the chart is added to the page
#' the session runs in: as an iframe in the element with id
#' \code{maidr-output}, or at the end of \code{<body>} when there is none. A
#' page that defines \code{globalThis.maidrWebRShow(html)}, or R code that sets
#' \code{options(maidr.webr_display = function(html) ...)}, receives the
#' document instead. A plotly, highcharter or echarts4r widget is shown the
#' same way, made accessible with \code{\link{maidr_htmlwidget}()} first; its
#' document carries the chart library, a few megabytes. Any other htmlwidget is
#' refused, with the message \code{maidr_htmlwidget()} gives.
#'
#' @param plot A ggplot2 object, a lattice (trellis) object, or NULL for Base R
#'   auto-detection
#' @param use_cdn Logical. Controls where MAIDR.js is loaded from:
#'   \itemize{
#'     \item \code{TRUE}: Use the jsDelivr CDN (requires internet), which
#'       loads the latest published MAIDR.js rather than the bundled copy.
#'       The version is looked up once per R session; pin one with
#'       \code{options(maidr.cdn_version = ...)}, see
#'       \code{?"maidr-options"}.
#'     \item \code{FALSE}: Use local bundled files (works offline, and makes
#'       no network request)
#'     \item \code{NULL} (default): Use the bundled files, so the viewer
#'       works offline. With \code{as_widget = TRUE} the widget instead
#'       auto-detects internet availability and uses the CDN when online,
#'       as the Shiny path does.
#'   }
#' @section Chart size:
#' A chart is drawn at a size in inches, as [ggplot2::ggsave()] and knitr's
#' `fig.width` and `fig.height` size a figure, and its SVG is 72 pixels to
#' the inch: a 10 x 4 in chart is 720 pixels wide and 288 high. The size is
#' the room the chart is laid out in -- how far apart its ticks and labels
#' are, how lattice arranges its panels, where Base R puts its titles -- and
#' not what maidr reads out: the data, titles and axis labels a reader
#' hears are the same at every size. Only how a reader moves between panels
#' can change: lattice arranges the panels of a chart conditioned on one
#' variable with no `layout =` for the shape of the page, 1 x 2 at 7 x 5 in
#' and 2 x 1 at 5 x 8 in for two panels, and the subplot grid a reader
#' moves through follows; give `layout =` to keep it. The size is set by
#' `width` and `height` in [show()] and [save_html()], by `fig_width` and
#' `fig_height` in
#' [render_maidr()], and by the chunk's `fig.width` and `fig.height` in an
#' R Markdown or Quarto document (see [maidr_on()]). Nothing else sets it:
#' not the size of the device a chart was drawn on, nor the size of the
#' window, viewer or Shiny output it is shown in, which shrinks a chart
#' wider than itself to fit.
#'
#' Unset, a chart is 7 x 5 in. A candlestick chart is 12 x 6 in, and is
#' never drawn smaller than that: quantmod's `chartSeries()` needs the room
#' for its title, date range and date labels. A smaller size asked for is
#' enlarged, with a message naming the size the chart is drawn at. A side
#' larger than 50 in is refused, as [ggplot2::ggsave()] refuses one: the
#' size is in inches, not the pixels [maidr_output()] takes.
#'
#' A Base R chart's margins and text take the same room at every size, so
#' a chart can be too small for them -- R itself stops with "figure margins
#' too large" at such a size. maidr draws the chart with the margins and
#' text size its `par()` calls set, so it fits where R draws it with them.
#' Asked for a size too small, maidr stops too, with an error naming the
#' size, rather than show an empty chart: draw it larger. With no size
#' asked for, a chart too small for 7 x 5 in, such as a `par(mfrow)` grid
#' of five rows or more, is drawn on the 7 x 7 in page maidr laid every
#' Base R chart out on before it drew one at its size. Where that is too
#' small too, it is drawn on the smallest larger page that leaves each of
#' its plots a sixth of an inch, 12 px, each way, each side grown in whole
#' inches only as far as it needs: 7 x 9 in for six rows, 12 x 5 in for
#' twelve columns. A message names the size it is drawn at. The picture of a
#' Base R chart maidr cannot read is held to its size in the same way.
#'
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param as_widget If TRUE, returns an htmlwidget object instead of opening in browser
#' @param width,height The size to draw the chart at, in inches: each a
#'   single positive number no larger than 50, or `NULL` (the default) for
#'   7 x 5 in, 12 x 6 in for a candlestick chart. A side not given takes
#'   its default. With `as_widget = TRUE` they size the chart in the widget,
#'   not the widget, whose own CSS size is set on the widget returned:
#'   `widget$width <- "300px"`. See \strong{Chart size}.
#' @param ... Additional arguments passed to internal functions
#' @return Invisible NULL. The plot is displayed in RStudio Viewer or browser as a side effect.
#' @examples
#' # ggplot2 bar chart
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_bar(stat = "identity")
#' \donttest{
#' maidr::show(p)
#'
#' # The same chart, 10 inches wide and 4 high
#' maidr::show(p, width = 10, height = 4)
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
#' # lattice chart [experimental]
#' \donttest{
#' if (requireNamespace("lattice", quietly = TRUE)) {
#'   maidr::show(lattice::xyplot(mpg ~ wt, data = mtcars))
#' }
#' }
#'
#' # Base R example (requires interactive session for function patching)
#' if (interactive()) {
#'   barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
#'   maidr::show(width = 6, height = 4)
#' }
#' @importFrom R6 R6Class
#' @importFrom ggplotify as.grob
#' @export
show <- function(plot = NULL, use_cdn = NULL, shiny = FALSE, as_widget = FALSE,
                 width = NULL, height = NULL, ...) {
  # Attaching maidr masks methods::show(). An object that is not a ggplot2
  # plot -- an S4 object, a vector -- is that generic's to print, so it is
  # handed over rather than failed on (#320). Decided on the object rather
  # than through the registry: the Base R adapter claims by device state,
  # not by what it was given, so with a recorded chart on the device an S4
  # object would otherwise be "handled" as Base R and never printed.
  if (!is.null(plot) && !is_maidr_plot_object(plot)) {
    # An htmlwidget has no viewer to print into under webR, where methods::show()
    # prints nothing. Those maidr reads are made accessible and put on the page
    # like any other chart; maidr_htmlwidget() says plainly which it cannot read.
    if (is_webr() && inherits(plot, "htmlwidget")) {
      # NULL is the bundled copy here, as everywhere; anything else goes on to
      # maidr_htmlwidget(), which checks it.
      display_html_webr(
        maidr_htmlwidget(plot, use_cdn = if (is.null(use_cdn)) FALSE else use_cdn)
      )
      return(invisible(NULL))
    }
    return(methods::show(plot))
  }

  # `width` and `height` are the chart's size. With `as_widget = TRUE` they
  # used to reach the widget through `...` as its CSS size, and `fig_width`
  # and `fig_height` there would reach it twice: each mistake is told what
  # to do instead.
  if (is.character(width) || is.character(height)) {
    stop(
      "`width` and `height` are the size to draw the chart at, in inches, not ",
      "a CSS size. Size the widget that `show(as_widget = TRUE)` returns with ",
      "its own: `widget$width <- \"300px\"`.",
      call. = FALSE
    )
  }
  if (any(c("fig_width", "fig_height") %in% names(match.call(expand.dots = FALSE)$...))) {
    stop("show() takes the size to draw the chart at as `width` and `height`.", call. = FALSE)
  }
  check_chart_size(width, "width")
  check_chart_size(height, "height")

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
    orchestrator <- adapter$create_orchestrator(plot, width = width, height = height)

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
      } else if (inherits(plot, "trellis")) {
        # lattice: draw with lattice itself, not through the print hook
        # maidr set, which would run the support check a second time. As
        # the hook draws a chart it cannot read, on a screen of its own and
        # with MAIDR's hidden device made current again for the Base R
        # chart it holds, which is then still show()'s to open.
        recording <- if (maidr_hidden_device_is_current()) grDevices::dev.cur()
        if (!is.null(recording)) {
          plot <- lattice_carry_reader_settings(plot)
        }
        open_default_device()
        if (!is.null(recording)) {
          on.exit(
            if (recording %in% grDevices::dev.list()) grDevices::dev.set(recording),
            add = TRUE
          )
        }
        print_trellis_natively(plot)
      } else {
        # ggplot2: Print to native graphics device with ggplot2's own
        # method, not the one maidr registered, which would run the support
        # check a second time.
        open_default_device()
        print_ggplot_natively(plot)
      }

      return(invisible(NULL))
    }
  }

  if (as_widget) {
    result <- maidr_widget(
      plot,
      use_cdn = use_cdn,
      fig_width = width,
      fig_height = height,
      ...
    )
    if (is_base_r) {
      clear_device_storage(device_id)
      close_maidr_temp_device()
    }
    return(result)
  }

  if (shiny) {
    result <- create_maidr_html(
      plot,
      use_cdn = use_cdn,
      shiny = TRUE,
      width = width,
      height = height,
      ...
    )
    if (is_base_r) {
      clear_device_storage(device_id)
      close_maidr_temp_device()
    }
    return(result)
  }

  # Reuse the orchestrator from the fallback check above: creating a new
  # one would re-run the entire layer-processing pipeline. It was made at
  # the size asked for.
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

#' Whether an object is a plot maidr renders from the object itself
#'
#' A ggplot2 object or a lattice (trellis) object. Base R charts are not
#' objects: they are recorded as they are drawn, and \code{show()} and
#' \code{save_html()} take them with no argument.
#'
#' @param x Any object
#' @return TRUE for a ggplot2 or trellis object
#' @keywords internal
is_maidr_plot_object <- function(x) {
  inherits(x, c("ggplot", "trellis"))
}

#' Create HTML document with maidr enhancements using the orchestrator
#' @param plot A ggplot2 object
#' @param use_cdn Logical. If `TRUE`, use CDN. If `FALSE` or `NULL`
#'   (default), use bundled files; see [maidr_html_dependencies()].
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param orchestrator Optional pre-created orchestrator to reuse (avoids double
#'   creation). The chart is drawn at the size it was created with, and
#'   `width` and `height` are not read.
#' @param width,height The size to draw the chart at, in inches, or `NULL`
#'   for maidr's own; see [chart_canvas_size()]. Checked by the caller.
#' @param ... Additional arguments passed to [create_fallback_html()]
#' @return An htmltools HTML document object or SVG content
#' @keywords internal
create_maidr_html <- function(plot, use_cdn = NULL, shiny = FALSE, orchestrator = NULL,
                              width = NULL, height = NULL, ...) {
  # Use provided orchestrator or create a new one
  if (is.null(orchestrator)) {
    registry <- get_global_registry()
    system_name <- registry$detect_system(plot)
    adapter <- registry$get_adapter(system_name)
    orchestrator <- adapter$create_orchestrator(plot, width = width, height = height)
  }
  # A picture in place of the chart is drawn at the chart's size. A Base R
  # chart's is held to it as the chart is, which can enlarge it or stop
  # (`picture_size()`); only the Base R orchestrator has that member.
  picture_size <- function() {
    if (is.function(orchestrator$picture_size)) {
      return(orchestrator$picture_size())
    }
    orchestrator$canvas_size()
  }
  fallback_html <- function(size = picture_size()) {
    create_fallback_html(
      plot,
      shiny = shiny,
      width = size[["width"]],
      height = size[["height"]],
      ...
    )
  }

  # Check if we should fall back to image rendering
  if (orchestrator$should_fallback()) {
    # Settled before the warning that a picture is drawn: a size too small
    # to draw the picture at stops instead.
    size <- picture_size()
    if (is_fallback_warning_enabled()) {
      warning(
        "Plot contains unsupported elements. ",
        "Rendering as static image instead of interactive MAIDR plot.",
        call. = FALSE
      )
    }
    return(fallback_html(size))
  }

  warn_panel_fallback(orchestrator)

  svg_content <- build_interactive_svg(orchestrator)

  # `build_interactive_svg()` answers NULL for a plot that could not be built,
  # which is the same outcome as the gate above reaching a chart it cannot
  # read: a picture rather than nothing.
  if (is.null(svg_content)) {
    return(fallback_html())
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
#' the exporter's question and the exporter is not consulted until the export
#' runs. When maidr exported through gridSVG, two base R charts failed there
#' on plots that pass the gate -- `matplot()` with "non-numeric argument to
#' binary operator" and `symbols()` with gridSVG's own "We shouldn't be here!"
#' assertion, both raised inside `grid.export()` rather than by anything this
#' package computes. The svglite export draws both, but an export can still
#' throw.
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
#' A chart too small to draw at its size (a `maidr_chart_draw_error`
#' from [base_r_drawing_grob()]) is re-raised too: its picture is drawn at
#' the same size and would fail the same way.
#'
#' @param orchestrator The orchestrator for the plot being rendered.
#' @return The SVG content, drawn at the orchestrator's `canvas_size()`, or
#'   `NULL` when the build failed and fallback is enabled.
#' @keywords internal
build_interactive_svg <- function(orchestrator) {
  build <- function() {
    gt <- orchestrator$get_gtable()

    # All plot types now use the unified orchestrator data generation
    maidr_data <- orchestrator$generate_maidr_data()

    size <- orchestrator$canvas_size()
    create_enhanced_svg(gt, maidr_data, width = size[["width"]], height = size[["height"]])
  }

  if (!is_fallback_enabled()) {
    return(build())
  }

  tryCatch(build(), error = function(e) {
    if (inherits(e, "maidr_chart_draw_error")) {
      stop(e)
    }
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
#' Save a ggplot2, lattice or Base R plot as an HTML file with interactive MAIDR
#' accessibility features.
#'
#' By default the MAIDR.js library is written to a \code{lib/} folder beside
#' \code{file}, and the two have to be shared together: zip the folder that
#' holds both, or copy both. An \code{.html} sent on its own loads no
#' MAIDR.js and shows a plain, inaccessible chart. \code{use_cdn = TRUE}
#' writes one self-contained file instead, which needs internet access
#' whenever it is viewed and loads the latest published MAIDR.js from
#' jsDelivr rather than the copy bundled with this package.
#'
#' @param plot A ggplot2 object, a lattice (trellis) object, or NULL for Base R
#'   auto-detection
#' @param file File path where to save the HTML file (e.g., "plot.html")
#' @param use_cdn Logical. Controls where MAIDR.js is loaded from:
#'   \itemize{
#'     \item \code{TRUE}: Use CDN. The file is self-contained but needs
#'       internet access when it is viewed. It names the latest published
#'       MAIDR.js by version (looked up once per R session, or the bundled
#'       version when the lookup cannot be made); pin a version with
#'       \code{options(maidr.cdn_version = ...)}, see
#'       \code{?"maidr-options"}.
#'     \item \code{FALSE} or \code{NULL} (default): Use the bundled files.
#'       The MAIDR.js library is written to a \code{lib/} folder beside
#'       \code{file}, which has to travel with it.
#'   }
#' @param width,height The size to draw the chart at, in inches: each a
#'   single positive number no larger than 50, or `NULL` (the default) for
#'   7 x 5 in, 12 x 6 in for a candlestick chart. A side not given takes
#'   its default. See \strong{Chart size}.
#' @inheritSection show Chart size
#' @param ... Additional arguments passed to internal functions
#' @return The file path where the HTML was saved (invisibly)
#' @examples
#' # ggplot2 bar chart
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_bar(stat = "identity")
#' \donttest{
#' maidr::save_html(p, tempfile(fileext = ".html"))
#'
#' # The same chart, 10 inches wide and 4 high
#' maidr::save_html(p, tempfile(fileext = ".html"), width = 10, height = 4)
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
#' # lattice chart [experimental]
#' \donttest{
#' if (requireNamespace("lattice", quietly = TRUE)) {
#'   p_lattice <- lattice::bwplot(factor(cyl) ~ mpg, data = mtcars)
#'   maidr::save_html(p_lattice, tempfile(fileext = ".html"))
#' }
#' }
#'
#' # Base R example (requires interactive session for function patching)
#' if (interactive()) {
#'   barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
#'   maidr::save_html(file = tempfile(fileext = ".html"))
#' }
#' @export
save_html <- function(plot = NULL, file = "plot.html", use_cdn = NULL,
                      width = NULL, height = NULL, ...) {
  check_chart_size(width, "width")
  check_chart_size(height, "height")

  device_id <- grDevices::dev.cur()
  is_base_r <- is.null(plot)

  if (is_base_r) {
    if (!is_patching_active() || !has_device_calls(device_id)) {
      stop(no_base_r_plots_message(), call. = FALSE)
    }
  }

  html_doc <- create_maidr_html(
    plot,
    use_cdn = use_cdn,
    width = width,
    height = height,
    ...
  )

  if (is_base_r) {
    clear_device_storage(device_id)
    # Close the temp device created by wrappers to suppress default graphics window
    close_maidr_temp_device()
  }

  save_html_document(html_doc, file)

  invisible(file)
}
