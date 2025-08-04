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
  
  # Get the plot type and appropriate plot for SVG generation
  plot_type <- get_plot_type(plot_processor)
  svg_plot <- get_svg_plot(plot_processor, plot, plot_type)
  
  # Generate SVG content
  layout <- extract_layout(svg_plot)
  gt <- ggplot2::ggplotGrob(svg_plot)
  layer_ids <- extract_layer_ids(gt, plot_type)
  
  # Create layers structure
  layers <- create_layers(layer_ids, plot_type, svg_plot, plot_processor, layout)
  
  # Generate final HTML
  maidr_data <- create_maidr_data(layers)
  svg_content <- create_enhanced_svg(gt, maidr_data, ...)
  html_doc <- create_html_document(svg_content)

  html_doc
}

#' Get the appropriate plot for SVG generation
#' @param plot_processor The plot processor object
#' @param original_plot The original plot
#' @param plot_type The plot type
#' @return The plot to use for SVG generation
#' @keywords internal
get_svg_plot <- function(plot_processor, original_plot, plot_type) {
  if (!is.null(plot_processor$reordered_plot)) {
    plot_processor$reordered_plot
  } else {
    original_plot
  }
}

#' Extract layer-specific data using the appropriate function
#' @param plot_processor The plot processor object
#' @param layer_id The layer ID
#' @param plot_type The plot type
#' @return Layer-specific data structure
#' @keywords internal
extract_layer_data <- function(plot_processor, layer_id, plot_type) {
  switch(plot_type,
    "bar" = extract_bar_layer_data(plot_processor, layer_id),
    "stacked_bar" = extract_stacked_bar_layer_data(plot_processor, layer_id),
    "dodged_bar" = extract_dodged_bar_layer_data(plot_processor, layer_id),
    "hist" = extract_histogram_layer_data(plot_processor, layer_id),
    "smooth" = extract_smooth_layer_data(plot_processor, layer_id),
    extract_default_layer_data(plot_processor, layer_id)  # fallback
  )
}

#' Create layers structure for HTML generation
#' @param layer_ids Vector of layer IDs
#' @param plot_type The plot type
#' @param svg_plot The plot used for SVG generation
#' @param plot_processor The plot processor object
#' @param layout Layout information
#' @return List of layer structures
#' @keywords internal
create_layers <- function(layer_ids, plot_type, svg_plot, plot_processor, layout) {
  layers <- list()
  
  for (i in seq_along(layer_ids)) {
    layer_id <- layer_ids[i]
    
    # Get selectors and ensure they're always an array
    selectors <- make_selector(plot_type, layer_id, svg_plot)
    
    # Ensure selectors is always a list/array, even for single elements
    if (!is.list(selectors) && length(selectors) == 1) {
      selectors <- list(selectors)
    }
    
    # Extract layer-specific data using the appropriate function
    layer_data <- extract_layer_data(plot_processor, layer_id, plot_type)
    
    layers[[i]] <- list(
      id = layer_id,
      selectors = selectors,
      type = plot_type,
      data = layer_data,
      title = if (!is.null(layout$title)) layout$title else "",
      axes = if (!is.null(layout$axes)) layout$axes else list(x = "", y = "")
    )
  }
  
  layers
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
