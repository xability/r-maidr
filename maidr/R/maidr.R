#' Display a plot in the appropriate environment (browser, Viewer, etc.)
#' @param plot A ggplot2 object
#' @param file Optional file path to save HTML. If NULL, creates temporary file
#' @param open Whether to open the HTML file in browser/RStudio Viewer
#' @param ... Additional arguments passed to internal functions
#' @export
maidr <- function(plot, file = NULL, open = TRUE, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  html_doc <- create_maidr_html(plot, ...)

  if (is.null(file)) {
    if (open) {
      display_html(html_doc)
    }
    invisible(NULL)
  } else {
    save_html_document(html_doc, file)
    if (open) {
      display_html_file(file)
    }
    invisible(file)
  }
}

#' Save ggplot2 plot as interactive HTML with maidr enhancements
#' @param plot A ggplot2 object
#' @param file Output HTML file path
#' @param ... Additional arguments passed to internal functions
#' @export
save_html <- function(plot, file, ...) {
  stopifnot(inherits(plot, "ggplot"))

  html_doc <- create_maidr_html(plot, ...)
  save_html_document(html_doc, file)

  invisible(file)
}

#' Create HTML document with maidr enhancements
#' @param plot A ggplot2 object
#' @param ... Additional arguments passed to internal functions
#' @return An htmltools HTML document object
#' @keywords internal
create_maidr_html <- function(plot, ...) {
  # Use the factory pattern to process the plot
  plot_processor <- create_plot_processor(plot, ...)
  
  # Extract layout information
  layout <- extract_layout(plot)
  
  # Convert to gtable for SVG generation
  gt <- ggplot2::ggplotGrob(plot)
  
  # Get plot type from processor
  plot_type <- get_plot_type(plot_processor)
  layer_ids <- extract_layer_ids(gt, plot_type)
  
  # Create layers structure from the processed plot data
  layers <- list()
  
  for (i in seq_along(layer_ids)) {
    layer_id <- layer_ids[i]
    
    layers[[i]] <- list(
      id = layer_id,
      selectors = make_selector(plot_type, layer_id),
      type = plot_type,
      data = plot_processor$data,
      title = if (!is.null(layout$title)) layout$title else "",
      axes = if (!is.null(layout$axes)) layout$axes else list(x = "", y = "")
    )
  }

  maidr_data <- create_maidr_data(layers)
  svg_content <- create_enhanced_svg(gt, maidr_data, ...)
  html_doc <- create_html_document(svg_content)

  html_doc
}

#' Create maidr-data structure
#' @param layers List of plot layers
#' @return List containing maidr-data structure
#' @keywords internal
create_maidr_data <- function(layers) {
  valid_layers <- list()
  for (i in seq_along(layers)) {
    layer <- layers[[i]]

    if (is.null(layer$type)) {
      next
    }

    if (is.null(layer$data)) {
      layer$data <- list()
    }

    if (!is.list(layer$data) || length(layer$data) == 0) {
      layer$data <- list()
    }

    if (is.null(layer$title)) {
      layer$title <- ""
    }
    if (is.null(layer$axes)) {
      layer$axes <- list(x = "", y = "")
    }

    valid_layers[[length(valid_layers) + 1]] <- layer
  }

  list(
    id = paste0("maidr-plot-", as.integer(Sys.time())),
    subplots = list(
      list(
        list(
          id = paste0("maidr-subplot-", as.integer(Sys.time())),
          layers = valid_layers
        )
      )
    )
  )
}
