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
  
  # Group by fill values if fill aesthetic exists
  if (!is.null(fill_col) && fill_col %in% names(original_data)) {
    fill_groups <- split(original_data, original_data[[fill_col]])
    
    # STACKING ORDER LOGIC: Determine visual stacking order from ggplot_build output
    # 
    # ggplot2 assigns colors to fill values in order of appearance in data.
    # The visual stacking order is determined by the ymin values in the built data:
    # - Lowest ymin = bottom of stack
    # - Highest ymin = top of stack
    # 
    # We map colors back to fill values and sort by ymin to get the correct order.
    
    unique_fill_values <- unique(original_data[[fill_col]])
    unique_colors <- unique(built_data$fill)

    # Step 1: Map colors to fill values (simple 1:1 mapping based on order of appearance)
    color_to_fill <- list()
    for (i in 1:length(unique_colors)) {
      color_to_fill[[unique_colors[i]]] <- unique_fill_values[i]
    }

    # Step 2: Calculate average ymin for each color to determine visual position
    color_ymin <- sapply(unique_colors, function(color) {
      mean(built_data$ymin[built_data$fill == color])
    })

    # Step 3: Sort colors by ymin (lowest first = bottom of stack)
    sorted_indices <- order(color_ymin)
    sorted_colors <- unique_colors[sorted_indices]

    # Step 4: Get final stacking order by mapping sorted colors back to fill values
    fill_order <- sapply(sorted_colors, function(color) color_to_fill[[color]])

    # Create nested structure for maidr with text values
    # Order groups to match visual stacking (bottom to top)
    # Each group represents one fill value (e.g., one color in the stack)
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
            x = as.character(group_data[[x_col]][i]),  # Keep as text
            y = group_data[[y_col]][i],                # Keep as number
            fill = as.character(fill_value)            # Keep as text
          )
          group_points[[i]] <- point
        }
        maidr_data[[length(maidr_data) + 1]] <- group_points
      }
    }
  } else {
    # If no fill aesthetic, treat as regular bar plot
    maidr_data <- list()
    group_points <- list()
    for (i in 1:nrow(original_data)) {
      point <- list(
        x = as.character(original_data[[x_col]][i]),  # Keep as text
        y = original_data[[y_col]][i]                 # Keep as number
      )
      group_points[[i]] <- point
    }
    maidr_data[[1]] <- group_points
  }
  
  maidr_data
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
  # This targets all rect elements within the parent grob
  selector_string <- sprintf("#geom_rect\\.rect\\.%d\\.1 rect", layer_id)
  
  return(selector_string)
} 