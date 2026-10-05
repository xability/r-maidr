#' Fallback Rendering for Unsupported Plots
#'
#' This module provides fallback rendering functionality for plots that
#' contain unsupported layers or plot types. Instead of failing silently,
#' these plots are rendered as standard PNG images.
#'
#' @noRd
NULL

#' Create Fallback Image for Unsupported Plots
#'
#' Renders a plot as a standard PNG image when MAIDR cannot process it.
#' This is used as a fallback for unsupported plot types or layers.
#'
#' @param plot A ggplot2 object, a lattice (trellis) object, or NULL for Base R
#'   plots
#' @param format Image format: "png" (default), "svg", or "jpeg"
#' @param width Image width in inches (default: 7)
#' @param height Image height in inches (default: 5)
#' @param res Resolution in DPI for PNG/JPEG (default: 150)
#' @return Base64-encoded image data URI string
#' @keywords internal
create_fallback_image <- function(plot = NULL, format = "png",
                                  width = 7, height = 5, res = 150) {
  # Create temporary file

  temp_file <- tempfile(fileext = paste0(".", format))

  # Save current device

  current_dev <- grDevices::dev.cur()

  # Open appropriate graphics device
  if (format == "png") {
    grDevices::png(temp_file,
      width = width * res,
      height = height * res,
      res = res
    )
  } else if (format == "svg") {
    grDevices::svg(temp_file, width = width, height = height)
  } else if (format == "jpeg") {
    grDevices::jpeg(temp_file,
      width = width * res,
      height = height * res,
      res = res,
      quality = 90
    )
  } else {
    stop("Unsupported format: ", format, ". Use 'png', 'svg', or 'jpeg'.")
  }

  # Pages of a lattice chart the picture leaves out; see below.
  pages <- 1

  # Render the plot
  tryCatch(
    {
      if (is.null(plot)) {
        # Base R: replay recorded calls from device storage
        device_id <- current_dev
        replay_base_r_plot(device_id)
      } else if (inherits(plot, "ggplot")) {
        # ggplot2: draw with ggplot2's own print method. A bare `print()`
        # dispatches to `maidr_print_ggplot()`, which builds the interactive
        # chart again, fails again, and lands back here -- once per nested
        # png() device until R runs out of them. The chart that could not be
        # exported is drawn as the picture it is, not re-attempted.
        print_ggplot_natively(plot)
      } else if (inherits(plot, "trellis")) {
        # lattice: drawn by lattice, for the same reason, from its first page.
        pages <- lattice_draw_picture(plot)
      } else {
        stop("Unknown plot type")
      }
    },
    error = function(e) {
      # If rendering fails, create a placeholder
      graphics::plot.new()
      graphics::text(0.5, 0.5,
        "Plot rendering failed",
        cex = 1.5, col = "gray50"
      )
    },
    finally = {
      grDevices::dev.off()
      # Restore previous device if it existed
      if (current_dev > 1) {
        tryCatch(
          grDevices::dev.set(current_dev),
          error = function(e) NULL
        )
      }
    }
  )

  # Nothing in the picture shows that it is one page of several, so the
  # pages left out are named, as the interactive reading names them. Said
  # once the picture is made, so a warning turned into an error cannot turn
  # the picture into the placeholder.
  if (isTRUE(pages > 1) && is_fallback_warning_enabled()) {
    warning(
      "This lattice chart is laid out on ", pages, " pages. ",
      "Only the first page is shown as an image; set `layout =` ",
      "to fit every panel on one page.",
      call. = FALSE
    )
  }

  # Read file and convert to base64
  if (!file.exists(temp_file)) {
    stop("Failed to create fallback image")
  }

  img_data <- base64enc::base64encode(temp_file)

  # Clean up temp file

  unlink(temp_file)

  # Return data URI
  mime_type <- switch(format,
    png = "image/png",
    svg = "image/svg+xml",
    jpeg = "image/jpeg"
  )

  paste0("data:", mime_type, ";base64,", img_data)
}

#' Replay Base R Plot from Device Storage
#'
#' Re-executes the recorded Base R plot calls to render the plot.
#'
#' @param device_id The device ID to get calls from
#' @param strict `TRUE` to stop at a call that cannot be drawn again, as
#'   the measure of the size the picture needs does (`picture_size()`);
#'   `FALSE` draws the others, with a warning naming a plot left out
#' @keywords internal
replay_base_r_plot <- function(device_id, strict = FALSE) {
  # Every recorded call on the page R's device shows, with every layout
  # call, in the order it was made (`last_page_calls()`). The grouped view
  # keeps the HIGH and LOW calls and drops the LAYOUT ones, so a
  # multi-panel figure's picture was replayed without its `par(mfrow = )`
  # or `layout()` and came out as one panel drawn over another.
  all_calls <- shown_device_calls(device_id)
  high_calls <- Filter(starts_base_r_plot, all_calls)

  if (length(high_calls) == 0) {
    stop("No Base R plot calls found to replay")
  }

  # A grid no recorded call set up, which R drew the plots in all the same
  # (`grid_of_cells()`), is set up first, as R had it.
  config <- tryCatch(detect_panel_configuration(device_id), error = function(e) NULL)
  if (isTRUE(config$derived) && identical(config$type, "layout")) {
    do.call(graphics::layout, c(list(config$matrix), config$sizes))
  } else if (isTRUE(config$derived)) {
    graphics::par(mfrow = c(config$nrows, config$ncols))
  }

  # Replay through `replay_plot_call()`, which resolves each name to the
  # *original* graphics function and strips maidr's own bookkeeping
  # arguments. Calling the name through `do.call()` reached maidr's recording
  # wrapper instead, so the picture's replay was itself recorded -- against
  # the temporary png() device, whose id R hands out again to the next device
  # opened, where the stale calls surfaced as phantom layers. It also skipped
  # the `call_env` an NSE call needs to evaluate its expressions the way the
  # original did.
  #
  # Each plot is drawn where R started it, as the chart draws it
  # (`place_picture_plot()`): in the cell of the grid, or the region of the
  # page, R put it in, or over the plot before it. The `par()` calls that
  # put R there are not all recorded -- `graphics::par()`,
  # `withr::with_par()`, `screen()` -- so drawn as they come, a plot after
  # `graphics::par(new = TRUE)` started a page of its own, one sent to a
  # cell with `graphics::par(mfg = )` went to the next, and one after a
  # panel `plot.new()` took went to that panel.
  #
  # A low-level call R drew on a plot no recorded call started -- a panel
  # `plot.new()` or `frame()` took, as for a legend of its own, or a plot
  # maidr does not record -- is drawn on a plot started for it where R
  # started that one, in the coordinates it was drawn in, as the chart
  # draws it (`replay_unrecorded_plot_call()`); drawn as it comes, it went
  # over the plot before. `plots` counts the plots started on the page, as
  # R numbered them (`end_base_r_call()`).
  #
  # `split.screen()` is not drawn again: the `screen()` calls that chose
  # each of its screens are not recorded, so the picture drew the last
  # screen's plot alone, in the first screen's region, and R's
  # "calling par(new=TRUE) with no plot" with it. What R drew after
  # `screen(n, new = FALSE)` sent it back to an earlier screen without
  # starting a plot is drawn there, in the coordinates it was drawn in, and
  # clipped as R clipped it; and
  # what it drew after `par(mfg = )` sent it back to an earlier cell of a
  # grid, in that cell (`sent_back_panel()`).
  grid <- if (is_multipanel_config(config)) config
  plots <- 0L
  unrecorded_plot <- FALSE
  window <- NULL
  clipped <- clipped_away_calls(all_calls)
  for (i in seq_along(all_calls)) {
    call_entry <- all_calls[[i]]
    if (identical(call_entry$function_name, "split.screen")) {
      # Where it started the page, the page is started here, before the
      # graphics parameters set for the screens after it: R works out the
      # size of a line of margin text again only for a plot that starts a
      # page, and keeps it for the plots drawn over it, in the screens.
      if (isTRUE(call_entry$new_plot) && isTRUE(call_entry$end_plot > plots)) {
        graphics::par(new = plots > 0L)
        graphics::plot.new()
        plots <- call_entry$end_plot
      }
      next
    }
    on <- call_entry$end_plot
    starts <- starts_base_r_plot(call_entry) && isTRUE(call_entry$new_plot) &&
      is.numeric(call_entry$plot)
    low <- identical(call_entry$class_level, "LOW") && !starts_base_r_plot(call_entry)
    # Drawn in another region than the drawing's, other than the cell of a
    # layout() of one cell, which the layout drawn again puts elsewhere on
    # the picture's page (`layout_cell_region()`).
    sent_back <- low && is.null(grid) && length(call_entry$drawn_fig) == 4L &&
      !same_region(call_entry$drawn_fig, graphics::par("fig")) &&
      !in_layout_cell(call_entry$drawn_fig, config)
    sent_to <- if (low && !is.null(grid)) sent_back_panel(call_entry, grid)
    if (starts) {
      place_picture_plot(call_entry, plots, config)
    } else if (low && length(on) == 1L && isTRUE(on > plots)) {
      place_picture_plot(call_entry, plots, config)
      graphics::plot.new()
      plots <- on
      unrecorded_plot <- TRUE
      window <- NULL
    } else if (sent_back && clipped[[i]]) {
      # Sent there as `screen(n, new = FALSE)` sends R, with the screen's
      # graphics parameters and coordinates and without starting a plot, so
      # R clips what is drawn there as it did (`clipped_away_calls()`): the
      # cell it sets before the region keeps the clip R had.
      graphics::par(mfg = call_entry$drawn_cell)
      graphics::par(fig = call_entry$drawn_fig)
      set_drawing_pars(call_entry$pars)
      unrecorded_plot <- TRUE
      window <- NULL
    } else if (sent_back) {
      # Drawn where R had worked its clip out again, there.
      set_drawing_pars(call_entry$pars)
      graphics::par(fig = call_entry$drawn_fig, new = TRUE)
      graphics::plot.new()
      unrecorded_plot <- TRUE
      window <- NULL
    } else if (!is.null(sent_to)) {
      graphics::par(mfg = mfg_of_panel(sent_to, grid))
    }
    if (low && unrecorded_plot && !identical(call_entry$window, window)) {
      window <- replay_plot_window(call_entry$window) %||% window
    }
    tryCatch(
      replay_plot_call(
        call_entry$function_name,
        call_entry$args,
        call_entry$call_env,
        call_entry$arg_text,
        call_entry$rng_state
      ),
      error = function(e) {
        if (strict) {
          stop(e)
        }
        if (starts_base_r_plot(call_entry)) {
          warning("Failed to replay: ", call_entry$function_name)
        }
      }
    )
    if (starts_base_r_plot(call_entry) && length(on) == 1L) {
      plots <- max(plots, on)
      unrecorded_plot <- FALSE
      window <- NULL
    }
  }
}

#' Give a drawing the graphics parameters R had as a recorded call started
#'
#' Those `screen()` puts back for each screen of `split.screen()`, and the
#' outer margins (`base_r_drawing_pars`), as R had them whatever set them
#' (`begin_base_r_call()`), and the margins R gave the plot it started, in
#' inches (`note_base_r_plot_started()`). Replayed as they come, the
#' recorded `par()` calls gave a screen's plot the margins and size of text
#' set for another, under outer margins `split.screen()` had taken away,
#' and those `graphics::par()` set were not given at all. Only those that
#' differ from the drawing's are set, in their order.
#'
#' @param pars Graphics parameters, as a named list for `par()`; NULL or
#'   empty where they were not read
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
set_drawing_pars <- function(pars) {
  if (!is.list(pars) || length(pars) == 0L) {
    return(invisible(NULL))
  }
  changed <- differing_pars(pars)
  if (length(changed) > 0L) {
    graphics::par(changed)
  }
  invisible(NULL)
}

#' The graphics parameters that differ from those the drawing has
#'
#' A number is taken to be the same to within a millionth, as one read in
#' inches where it was set in lines is: setting the outer margins again
#' starts a new page in a grid, in R as here. The margins, `mar` or `mai`,
#' are always set: R keeps them in the unit they were last set in, and
#' works them out again in it as it starts a page or a panel, so the same
#' margins set in the other unit come out another size.
#'
#' @param pars Graphics parameters, as a named list for `par()`
#' @return Those of `pars` that differ, in their order
#' @keywords internal
#' @noRd
differing_pars <- function(pars) {
  now <- graphics::par(names(pars))
  same <- mapply(
    function(name, want, have) {
      if (name %in% c("mar", "mai")) {
        FALSE
      } else if (is.numeric(want) && is.numeric(have) && length(want) == length(have)) {
        missing <- is.na(want)
        identical(missing, is.na(have)) && all(abs(want[!missing] - have[!missing]) < 1e-6)
      } else {
        identical(want, have)
      }
    },
    names(pars),
    pars,
    now[names(pars)]
  )
  pars[!same]
}

#' The panel of a grid R was sent back to draw a low-level call in
#'
#' `par(mfg = )` sends R to another cell of the grid without starting a
#' plot, and what is drawn then is drawn there, in the coordinates of the
#' plot R was on (`base_r_drawing_region()`).
#'
#' @param call The recorded low-level call
#' @param grid The page's grid
#' @return The panel's number in the grid, where it is not the one the
#'   drawing is in; else NULL
#' @keywords internal
#' @noRd
sent_back_panel <- function(call, grid) {
  drawn <- as.integer(call$drawn_cell)
  here <- as.integer(graphics::par("mfg"))
  if (length(drawn) != 4L || anyNA(drawn) || identical(drawn, here) ||
        !identical(drawn[3:4], here[3:4])) {
    return(NULL)
  }
  panel_of_cell(drawn, grid)
}

#' Send a picture's drawing to where R started a plot
#'
#' The plot a recorded call starts, or the one no recorded call started that
#' a low-level call was drawn on, is drawn where R started it on the page R
#' shows (`end_base_r_call()`): in the region of the page `par(fig = )` or
#' `screen()` gave it (`is_figure_region()`); in the cell of the grid R put
#' it in, which `par(mfg = )` can send it to out of turn, or over the plot
#' drawn there, after `par(new = TRUE)`; or, on a page of one panel, over
#' the plots started on it before, as R starts a page for any other. Where
#' R put it is read from where it was, not from the `par()` calls before
#' it, which are not all recorded. A plot of a call that draws several,
#' started on a page before the last, is started in the panel R started it
#' in, so those before fill that page, as in the chart (`replay_page()`).
#' A plot in a grid of another shape than the drawing's -- one a call lays
#' out itself, as `heatmap()` does -- is left where the drawing puts it.
#' It is drawn with the graphics parameters R had as the call started, and
#' the margins R gave the plot (`set_drawing_pars()`).
#'
#' @param call The recorded call, with the `cell` and `fig` R put the plot
#'   in
#' @param plots The plots the drawing has started on its page, as R
#'   numbered them
#' @param config The page's configuration, from
#'   [detect_panel_configuration()], or NULL
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
place_picture_plot <- function(call, plots, config) {
  grid <- if (is_multipanel_config(config)) config
  pars <- call$pars
  margins <- call$margins
  csi <- margins$csi
  if (isTRUE(margins$region_set)) {
    # A region `par(plt = )` gave the plot in place of the margins, which
    # the `par()` call drawn again as it was gives it: margins set again
    # would take it back.
    pars <- pars[setdiff(names(pars), c("mar", "oma"))]
    margins <- NULL
  }
  if (is.numeric(margins$mai) && is.numeric(margins$omi) && is.numeric(csi) &&
        is.numeric(pars$cex)) {
    # In inches, as R drew the plot with them; set in lines again with the
    # size of text R had set since, they came out another size. R works out
    # the height of a line of margin text as margins, a region or a cell are
    # set, from the size of text it has then, which a `par(cex = )` set
    # after `screen()` does not change: they are set with the size of text
    # that gives the height R had, and the size R had is set after them.
    cex <- pars$cex
    graphics::par(cex = csi / graphics::par("cin")[[2L]])
    on.exit(graphics::par(cex = cex), add = TRUE)
    keep <- setdiff(names(pars), c("mar", "oma", "cex"))
    pars <- c(pars[keep], margins[c("mai", "omi")])
  }
  set_drawing_pars(pars)
  if (isTRUE(call$spans_pages)) {
    graphics::par(new = FALSE)
    for (k in seq_len(max(call$start_figure - 1L, 0L))) {
      graphics::plot.new()
    }
    graphics::par(new = FALSE)
    return(invisible(NULL))
  }
  cell <- as.integer(call$cell)
  in_drawing_grid <- length(cell) == 4L && !anyNA(cell) &&
    identical(as.integer(graphics::par("mfg")[3:4]), cell[3:4])
  if (is_figure_region(call, config, graphics::par("fig"))) {
    graphics::par(fig = call$fig, new = plots > 0L)
  } else if (!in_drawing_grid) {
    return(invisible(NULL))
  } else if (is.null(grid)) {
    graphics::par(new = plots > 0L)
  } else {
    slot <- panel_of_cell(cell, grid)
    if (is.null(slot)) {
      return(invisible(NULL))
    }
    graphics::par(new = FALSE)
    if (plots > 0L || slot != 1L) {
      # R does not move to a cell before the page's first plot is started.
      if (plots == 0L) {
        graphics::plot.new()
      }
      graphics::par(mfg = mfg_of_panel(slot, grid))
    }
  }
  invisible(NULL)
}

#' Create Fallback HTML Content
#'
#' Creates HTML content with the fallback image, styled to fit in iframes.
#' The image's alt text, which is what a screen reader says of it, names the
#' chart by its title when it is given one, and says why it is an image.
#'
#' @param plot A ggplot2 or trellis object, or NULL for Base R plots
#' @param shiny If TRUE, returns just the image tag for Shiny/knitr use
#' @param format Image format. Defaults to the `maidr.fallback_format`
#'   option, which [maidr_set_fallback()] sets.
#' @param width Image width in inches
#' @param height Image height in inches
#' @param title The chart's title, or NULL; the alt text then calls it "Plot"
#' @param reason Why the chart is an image: `"unsupported"`, it holds
#'   elements maidr cannot read, or `"failed"`, it could not be made
#'   interactive ([build_interactive_svg()])
#' @return HTML content string or htmltools object
#' @keywords internal
create_fallback_html <- function(plot = NULL, shiny = FALSE,
                                 format = get_fallback_format(),
                                 width = 7, height = 5, title = NULL,
                                 reason = c("unsupported", "failed")) {
  reason <- match.arg(reason)
  # Generate the fallback image
  img_data_uri <- create_fallback_image(
    plot = plot,
    format = format,
    width = width,
    height = height
  )

  # Create image tag with proper styling for iframe fit

  img_style <- paste(
    "width: 100%",
    "height: auto",
    "max-height: 100%",
    "display: block",
    "margin: auto",
    sep = "; "
  )

  why <- switch(reason,
    unsupported = "contains unsupported elements",
    failed = "could not be made interactive"
  )
  alt <- sprintf("%s (rendered as image - %s)", title %||% "Plot", why)
  img_tag <- sprintf(
    '<img src="%s" alt="%s" style="%s">',
    img_data_uri,
    htmltools::htmlEscape(alt, attribute = TRUE),
    img_style
  )

  if (shiny) {
    # For Shiny/knitr: return just the image tag wrapped in a div
    div_style <- paste(
      "width: 100%",
      "height: 100%",
      "display: flex",
      "align-items: center",
      "justify-content: center",
      "background-color: white",
      sep = "; "
    )

    html_content <- sprintf(
      '<div style="%s">%s</div>',
      div_style,
      img_tag
    )

    return(htmltools::HTML(html_content))
  }

  # For standalone display: create full HTML document
  html_doc <- htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$style(htmltools::HTML("
        body {
          margin: 0;
          padding: 20px;
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 100vh;
          background-color: #f5f5f5;
        }
        .fallback-container {
          background-color: white;
          padding: 20px;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          max-width: 100%;
        }
        .fallback-notice {
          text-align: center;
          color: #666;
          font-family: sans-serif;
          font-size: 12px;
          margin-top: 10px;
        }
      "))
    ),
    htmltools::tags$body(
      htmltools::tags$div(
        class = "fallback-container",
        htmltools::HTML(img_tag),
        htmltools::tags$p(
          class = "fallback-notice",
          paste(
            switch(reason,
              unsupported = "This plot contains unsupported elements",
              failed = "This plot could not be made interactive"
            ),
            "and is rendered as a static image."
          )
        )
      )
    )
  )

  html_doc
}

#' Describe a Panel-scoped Fallback
#'
#' Builds the warning text used when only some panels of a multi-panel
#' figure lose their accessible data. Naming the panels matters: the rest
#' of the figure still sonifies and navigates, so the user needs to know
#' which panel went quiet rather than assuming the whole figure did.
#'
#' @param panels Integer vector of 1-based panel numbers, in drawing order
#' @return A single warning string
#' @keywords internal
format_panel_fallback_warning <- function(panels) {
  panels <- sort(unique(as.integer(panels)))
  listed <- paste(panels, collapse = ", ")

  if (length(panels) == 1) {
    return(paste0(
      "Panel ", listed, " contains unsupported elements. ",
      "It is drawn but has no accessible data; ",
      "the other panels remain interactive."
    ))
  }

  paste0(
    "Panels ", listed, " contain unsupported elements. ",
    "They are drawn but have no accessible data; ",
    "the other panels remain interactive."
  )
}

#' Check if Fallback is Enabled
#'
#' @return Logical indicating if fallback rendering is enabled
#' @keywords internal
is_fallback_enabled <- function() {
  getOption("maidr.fallback_enabled", TRUE)
}

#' Check if Fallback Warning is Enabled
#'
#' @return Logical indicating if warnings should be shown
#' @keywords internal
is_fallback_warning_enabled <- function() {
  getOption("maidr.fallback_warning", TRUE)
}

#' Get Fallback Image Format
#'
#' @return Character string of the format to use
#' @keywords internal
get_fallback_format <- function() {
  getOption("maidr.fallback_format", "png")
}
