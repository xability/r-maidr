#' Fallback Rendering for Unsupported Plots
#'
#' This module provides fallback rendering functionality for plots that
#' contain unsupported layers or plot types. Instead of failing silently,
#' these plots are rendered as standard PNG images.
#'
#' @keywords internal
NULL

#' Create Fallback Image for Unsupported Plots
#'
#' Renders a plot as a standard PNG image when MAIDR cannot process it.
#' This is used as a fallback for unsupported plot types or layers.
#'
#' @param plot A ggplot2 object or NULL for Base R plots
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

  # Render the plot
  tryCatch(
    {
      if (is.null(plot)) {
        # Base R: replay recorded calls from device storage
        device_id <- current_dev
        replay_base_r_plot(device_id)
      } else if (inherits(plot, "ggplot")) {
        # ggplot2: print the plot
        print(plot)
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
#' @keywords internal
replay_base_r_plot <- function(device_id) {
  # Get plot calls from device storage
  grouped <- group_device_calls(device_id)
  plot_groups <- grouped$groups

  if (length(plot_groups) == 0) {
    stop("No Base R plot calls found to replay")
  }

  # Replay each group of calls

  for (group in plot_groups) {
    # Execute high-level call first
    high_call <- group$high_call
    if (!is.null(high_call)) {
      tryCatch(
        {
          do.call(high_call$function_name, high_call$args)
        },
        error = function(e) {
          warning("Failed to replay: ", high_call$function_name)
        }
      )
    }

    # Execute low-level calls
    for (low_call in group$low_calls) {
      tryCatch(
        {
          do.call(low_call$function_name, low_call$args)
        },
        error = function(e) NULL
      )
    }
  }
}

#' Create Fallback HTML Content
#'
#' Creates HTML content with the fallback image, styled to fit in iframes.
#'
#' @param plot A ggplot2 object or NULL for Base R plots
#' @param shiny If TRUE, returns just the image tag for Shiny/knitr use
#' @param format Image format (default: "png")
#' @param width Image width in inches
#' @param height Image height in inches
#' @return HTML content string or htmltools object
#' @keywords internal
create_fallback_html <- function(plot = NULL, shiny = FALSE,
                                  format = "png", width = 7, height = 5) {
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

  img_tag <- sprintf(
    '<img src="%s" alt="Plot (rendered as image - contains unsupported elements)" style="%s">',
    img_data_uri,
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
          "This plot contains unsupported elements and is rendered as a static image."
        )
      )
    )
  )

  html_doc
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
