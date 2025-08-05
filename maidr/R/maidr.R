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

#' Create HTML document with maidr enhancements using the orchestrator
#' @param plot A ggplot2 object
#' @param ... Additional arguments passed to internal functions
#' @return An htmltools HTML document object
#' @keywords internal
create_maidr_html <- function(plot, ...) {
  # Use the orchestrator to process the plot
  orchestrator <- PlotOrchestrator$new(plot)
  
  # Get the gtable for SVG generation
  gt <- orchestrator$get_gtable()
  
  # Get combined data and selectors from orchestrator
  combined_data <- orchestrator$get_combined_data()
  combined_selectors <- orchestrator$get_selectors()
  layout <- orchestrator$get_layout()
  
  # Create layers structure for HTML generation
  layers <- create_layers_from_orchestrator(orchestrator, layout)
  
  # Generate final HTML
  maidr_data <- create_maidr_data(layers)
  svg_content <- create_enhanced_svg(gt, maidr_data, ...)
  html_doc <- create_html_document(svg_content)

  html_doc
}

#' Create layers structure from orchestrator data
#' @param orchestrator The PlotOrchestrator instance
#' @param layout Layout information
#' @return List of layer structures
#' @keywords internal
create_layers_from_orchestrator <- function(orchestrator, layout) {
  layers <- list()
  layer_processors <- orchestrator$get_layer_processors()
  
  for (i in seq_along(layer_processors)) {
    processor <- layer_processors[[i]]
    layer_info <- processor$layer_info
    
    # Get the already processed data from the orchestrator
    # The orchestrator has already called process() on each layer processor
    # so we can get the results directly
    processed_result <- processor$get_last_result()
    
    if (!is.null(processed_result)) {
      # Use the selectors and data from the processed result
      selectors <- processed_result$selectors
      data <- processed_result$data
    } else {
      # Fallback: get selectors and data directly from processor
      selectors <- processor$generate_selectors(orchestrator$get_plot(), orchestrator$get_gtable())
      data <- processor$extract_data(orchestrator$get_plot())
    }
    
    # Filter out layer information from final JSON
    data <- filter_layer_info_from_data(data)
    
    # Keep selectors as a list format
    # If selectors is already a list, use it directly
    # If it's a single string, wrap it in a list
    # If it's empty, use empty list
    if (is.character(selectors) && length(selectors) == 1) {
      selectors_list <- list(selectors)
    } else if (is.list(selectors)) {
      selectors_list <- selectors
    } else {
      selectors_list <- list()
    }
    
    layers[[i]] <- list(
      id = layer_info$index,
      selectors = selectors_list,
      type = layer_info$type,
      data = data,
      title = if (!is.null(layout$title)) layout$title else "",
      axes = if (!is.null(layout$axes)) layout$axes else list(x = "", y = "")
    )
  }
  
  layers
}

#' Filter out layer information from data for final JSON
#' @param data The data to filter
#' @return Filtered data without layer information
#' @keywords internal
filter_layer_info_from_data <- function(data) {
  # Recursively remove layer_index and layer_type from data points
  filter_recursive <- function(data) {
    if (is.list(data)) {
      # Remove layer info if this is a data point (has x, y, etc.)
      if (any(c("x", "y", "fill") %in% names(data))) {
        data$layer_index <- NULL
        data$layer_type <- NULL
      }
      
      # Recursively filter nested structures
      for (i in seq_along(data)) {
        if (is.list(data[[i]])) {
          data[[i]] <- filter_recursive(data[[i]])
        }
      }
    }
    return(data)
  }
  
  return(filter_recursive(data))
}

#' Filter out layer information from selectors for final JSON
#' @param selectors The selectors to filter
#' @return Filtered selectors without layer information
#' @keywords internal
filter_layer_info_from_selectors <- function(selectors) {
  # Remove layer_index and layer_type from selector objects
  for (i in seq_along(selectors)) {
    if (is.list(selectors[[i]]) && "selector" %in% names(selectors[[i]])) {
      selectors[[i]]$layer_index <- NULL
      selectors[[i]]$layer_type <- NULL
    }
  }
  
  return(selectors)
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
