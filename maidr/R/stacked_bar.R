#' Stacked bar plot data S3 class
#'
#' This class inherits from plot_data and provides stacked bar-specific functionality.
#'
#' @param data Stacked bar plot data
#' @param layout Layout information
#' @param selectors CSS selectors for stacked bar elements
#' @param reordered_plot The reordered plot object (for stacked bars)
#' @param ... Additional arguments
#' @return A stacked_bar_plot_data object
#' @export
stacked_bar_plot_data <- function(data, layout, selectors, reordered_plot = NULL, ...) {
  # Create base plot_data object
  base_obj <- plot_data(
    type = "stacked_bar",
    data = data,
    layout = layout,
    selectors = selectors,
    reordered_plot = reordered_plot,
    ...
  )

  # Add stacked bar-specific class
  class(base_obj) <- c("stacked_bar_plot_data", class(base_obj))

  base_obj
}

#' Convert stacked_bar_plot_data to JSON
#' @param x A stacked_bar_plot_data object
#' @param ... Additional arguments passed to jsonlite::toJSON
#' @return JSON string
#' @export
as.json.stacked_bar_plot_data <- function(x, ...) {
  jsonlite::toJSON(unclass(x), auto_unbox = TRUE, ...)
}

#' Extract stacked bar plot data
#' 
#' This function extracts data from stacked bar plots and ensures the order
#' matches the visual stacking order (bottom to top).
#' 
#' Key Logic:
#' 1. ggplot2 assigns colors to fill values in order of appearance in data
#' 2. Visual stacking order is determined by ymin values in ggplot_build output
#' 3. Lowest ymin = bottom of stack, highest ymin = top of stack
#' 4. We map colors back to fill values and sort by ymin to get correct order
#' 
#' @param plot A ggplot2 object
#' @return List of stacked bar plot data points in visual order
#' @export
extract_stacked_bar_data <- function(plot) {
  # Get original data to retain text values
  original_data <- plot$data
  
  # Build the plot to get built data for segment calculations
  built <- ggplot2::ggplot_build(plot)

  # Find bar layers
  bar_layers <- which(sapply(plot$layers, function(layer) {
    inherits(layer$geom, "GeomBar") || inherits(layer$geom, "GeomCol")
  }))

  if (length(bar_layers) == 0) {
    stop("No bar layers found in plot")
  }

  # Extract built data from first bar layer for segment heights
  built_data <- built$data[[bar_layers[1]]]
  
  # For stacked bars, we need to calculate segment heights
  # y values in built_data are cumulative, so we need ymax - ymin
  if ("ymax" %in% names(built_data) && "ymin" %in% names(built_data)) {
    built_data$segment_height <- built_data$ymax - built_data$ymin
  } else {
    built_data$segment_height <- built_data$y
  }

  # Get the actual column names from the plot aesthetics
  plot_mapping <- plot$mapping
  layer_mapping <- plot$layers[[1]]$mapping
  
  # Determine x, y, and fill column names
  x_col <- NULL
  y_col <- NULL
  fill_col <- NULL
  
  # Check layer mapping first, then plot mapping
  if (!is.null(layer_mapping)) {
    if (!is.null(layer_mapping$x)) x_col <- rlang::as_name(layer_mapping$x)
    if (!is.null(layer_mapping$y)) y_col <- rlang::as_name(layer_mapping$y)
    if (!is.null(layer_mapping$fill)) fill_col <- rlang::as_name(layer_mapping$fill)
  }
  if (!is.null(plot_mapping)) {
    if (is.null(x_col) && !is.null(plot_mapping$x)) x_col <- rlang::as_name(plot_mapping$x)
    if (is.null(y_col) && !is.null(plot_mapping$y)) y_col <- rlang::as_name(plot_mapping$y)
    if (is.null(fill_col) && !is.null(plot_mapping$fill)) fill_col <- rlang::as_name(plot_mapping$fill)
  }
  

  
  # Ensure required columns are found
  if (is.null(x_col)) {
    stop("Could not determine x aesthetic mapping")
  }
  if (is.null(y_col)) {
    stop("Could not determine y aesthetic mapping")
  }
  if (!x_col %in% names(original_data)) {
    stop("x aesthetic column '", x_col, "' not found in data")
  }
  if (!y_col %in% names(original_data)) {
    stop("y aesthetic column '", y_col, "' not found in data")
  }
  
  # Group by fill values - this is a stacked bar plot with fill aesthetic
  fill_groups <- split(original_data, original_data[[fill_col]])
  
  # Extract the stacking order from the built data
  built_data <- ggplot2::ggplot_build(plot)
  if (length(built_data$data) > 0) {
    built_data_layer <- built_data$data[[1]]
    
    # Get the stacking order by looking at the first bar's layers
    first_bar_data <- built_data_layer[built_data_layer$x == 1, ]
    first_bar_data <- first_bar_data[order(first_bar_data$ymin), ]  # Order by ymin (bottom to top)
    
    # Map colors back to fill values
    color_to_fill <- setNames(original_data[[fill_col]], built_data_layer$fill)
    stacking_order <- unique(color_to_fill[first_bar_data$fill])
    
    # Use the stacking order (bottom to top)
    fill_order <- stacking_order
  } else {
    # Fallback to alphabetical order if we can't determine stacking order
    fill_order <- unique(original_data[[fill_col]])
  }

  maidr_data <- list()
  for (fill_value in fill_order) {
    if (fill_value %in% names(fill_groups)) {
      group_data <- fill_groups[[fill_value]]
      # Sort by x position to match visual order
      if (!is.null(x_col)) {
        group_data <- group_data[order(group_data[[x_col]]), ]
      }
      
      group_points <- list()
      for (i in 1:nrow(group_data)) {
        # Create point with original text values (not ggplot2's internal representations)
        point <- list(
          x = as.character(group_data[[x_col]][i]),
          y = group_data[[y_col]][i],
          fill = as.character(fill_value)
        )
        group_points[[i]] <- point
      }
      maidr_data[[length(maidr_data) + 1]] <- group_points
    }
  }
  
  maidr_data
}

#' Extract stacked bar layer data from plot processor
#' @param plot_processor The plot processor object
#' @param layer_id The layer ID
#' @return Stacked bar layer data structure (nested array format)
#' @keywords internal
extract_stacked_bar_layer_data <- function(plot_processor, layer_id) {
  if (is.null(plot_processor$data)) {
    return(list())
  }
  
  # For stacked bar plots, return the entire nested array structure
  # plot_processor$data is already the nested array of stacked bar data points
  if (length(plot_processor$data) > 0) {
    return(plot_processor$data)
  }
  
  return(list())
}

#' Make stacked bar selectors using parent element with rect selector
#' @param plot The ggplot2 object
#' @param layer_id The layer ID to use
#' @return Single CSS selector string for all rect elements
#' @keywords internal
make_stacked_bar_selectors <- function(plot, layer_id) {
  # Convert layer_id to integer if it's a character
  layer_id <- as.integer(layer_id)
  
  # Create single selector using parent element with rect selector
  selector_string <- sprintf("#geom_rect\\.rect\\.%d\\.1 rect", layer_id)
  
  return(selector_string)
} 