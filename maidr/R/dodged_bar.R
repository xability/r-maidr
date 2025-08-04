# Dodged Bar Plot Support for maidr Package
# This file contains functions for handling dodged bar plots

#' Reorder data for visual order in dodged bar plots
#' 
#' For dodged bars, we want each x-value to be grouped together.
#' The order should be: all bars for x1, then all bars for x2, etc.
#' Within each x-value group: left bar (Type1) first, then right bar (Type2).
#' 
#' @param data The input data.frame
#' @param x_col The x column name
#' @param y_col The y column name  
#' @param fill_col The fill column name
#' @return Reordered data.frame
#' @keywords internal
reorder_data_for_visual_order <- function(data, x_col, y_col, fill_col) {
  # Get unique values and sort them consistently
  x_values <- sort(unique(data[[x_col]]))
  fill_values <- sort(unique(data[[fill_col]]))
  
  reordered_data <- data.frame()
  
  for (x_val in x_values) {
    # For each x-value, we want Type2 first, then Type1
    # This will result in DOM elements that map correctly to the 2D data structure
    for (fill_val in rev(fill_values)) {
      # Find the row for this x-fill combination
      matching_rows <- which(data[[x_col]] == x_val & data[[fill_col]] == fill_val)
      if (length(matching_rows) > 0) {
        reordered_data <- rbind(reordered_data, data[matching_rows[1], ])
      }
    }
  }
  
  # Reset row names
  rownames(reordered_data) <- NULL
  
  return(reordered_data)
}

#' Apply reordering to dodged bar plot to ensure correct DOM element order
#' 
#' @param plot A ggplot2 object representing a dodged bar plot
#' @return A reordered ggplot2 object
#' @keywords internal
apply_dodged_bar_reordering <- function(plot) {
  # Get the original data
  original_data <- plot$data
  
  # Get the aesthetics from the plot
  aesthetics <- plot$mapping
  if (length(plot$layers) > 0) {
    layer_aesthetics <- plot$layers[[1]]$mapping
    if (!is.null(layer_aesthetics)) {
      aesthetics <- c(aesthetics, layer_aesthetics)
    }
  }
  
  # Extract column names from aesthetics using rlang functions
  x_col <- rlang::as_name(aesthetics$x)
  fill_col <- rlang::as_name(aesthetics$fill)
  y_col <- rlang::as_name(aesthetics$y)
  
  # Reorder the data
  reordered_data <- reorder_data_for_visual_order(original_data, x_col, y_col, fill_col)
  
  # Create new plot with reordered data
  new_plot <- plot
  new_plot$data <- reordered_data
  
  return(new_plot)
}

#' Extract dodged bar data from ggplot object
#' @param plot A ggplot2 object
#' @return List of dodged bar data points
#' @keywords internal
extract_dodged_bar_data <- function(plot) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  # Get the built data from the plot
  built <- ggplot_build(plot)
  
  # Extract data from the first layer (dodged bar layer)
  layer_data <- built$data[[1]]
  
  # Get the original data to retain text values
  original_data <- plot$data
  
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
  if (is.null(fill_col)) {
    stop("Could not determine fill aesthetic mapping")
  }
  
  # Get unique values
  x_values <- unique(original_data[[x_col]])
  fill_values <- unique(original_data[[fill_col]])
  
  # Sort values consistently
  x_values <- sort(x_values)
  fill_values <- sort(fill_values)
  
  # Get fill values in the order they appear in the reordered data
  # But we need to reverse the order to match DOM element order
  # DOM order should be: Above (right bars) first, then Below (left bars)
  fill_order <- rev(unique(original_data[[fill_col]]))
  
  # Create nested structure for maidr with text values
  # Order groups to match visual order (left to right)
  # Each group represents one fill value (e.g., one color in the dodged bars)
  maidr_data <- list()
  for (fill_value in fill_order) {
    group_points <- list()
    for (x_val in x_values) {
      # Find the y value for this x-fill combination
      matching_rows <- which(original_data[[x_col]] == x_val & original_data[[fill_col]] == fill_value)
      if (length(matching_rows) > 0) {
        y_val <- original_data[[y_col]][matching_rows[1]]
        # Create point with original text values
        point <- list(
          x = as.character(x_val),           # Keep as text
          y = y_val,                         # Keep as number
          fill = as.character(fill_value)    # Keep as text
        )
        group_points[[length(group_points) + 1]] <- point
      }
    }
    maidr_data[[length(maidr_data) + 1]] <- group_points
  }
  
  maidr_data
}

#' Extract dodged bar layer data from plot processor
#' @param plot_processor The plot processor object
#' @param layer_id The layer ID
#' @return Dodged bar layer data structure (nested array format)
#' @keywords internal
extract_dodged_bar_layer_data <- function(plot_processor, layer_id) {
  if (is.null(plot_processor$data)) {
    return(list())
  }
  
  # For dodged bar plots, return the entire nested array structure
  # plot_processor$data is already the nested array of dodged bar data points
  if (length(plot_processor$data) > 0) {
    return(plot_processor$data)
  }
  
  return(list())
}

#' Make dodged bar selectors using parent element with path selector
#' @param plot The ggplot2 object
#' @param layer_id The layer ID to use
#' @return Single CSS selector string for all path elements
#' @keywords internal
make_dodged_bar_selectors <- function(plot, layer_id) {
  # Convert layer_id to integer if it's a character
  layer_id <- as.integer(layer_id)
  
  # For dodged bars, we need to target path elements within g elements that have maidr attributes
  # This matches the Python binder pattern: g[maidr='uuid'] > path
  # However, gridSVG generates rect elements, so we use the rect selector pattern
  selector_string <- sprintf("#geom_rect\\.rect\\.%d\\.1 rect", layer_id)
  
  return(selector_string)
}

#' Create dodged bar plot data object
#' 
#' @param data The extracted data
#' @param layout The layout information
#' @param selectors The CSS selectors
#' @param reordered_plot The reordered plot object
#' @return A dodged_bar_plot_data object
#' @keywords internal
dodged_bar_plot_data <- function(data, layout, selectors, reordered_plot = NULL, ...) {
  # Create base plot_data object
  base_obj <- plot_data(
    type = "dodged_bar",
    data = data,
    layout = layout,
    selectors = selectors,
    reordered_plot = reordered_plot,
    ...
  )

  # Add dodged bar-specific class
  class(base_obj) <- c("dodged_bar_plot_data", class(base_obj))

  base_obj
} 