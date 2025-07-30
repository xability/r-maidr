#' Reorder data for stacked bar plots to ensure correct DOM element order
#' 
#' This function applies the optimal ordering strategy for stacked bar plots:
#' 1. Determine the stacking order dynamically from the plot
#' 2. Reorder data so fill values appear in the correct stacking order
#' 3. Sort by category values alphabetically within each fill group
#' 
#' @param data Data frame with stacked bar plot data
#' @param fill_col Name of the fill column (e.g., "weight_status")
#' @param category_col Name of the category column (e.g., "species")
#' @return Reordered data frame
#' @keywords internal
reorder_for_stacked_bar <- function(data, fill_col, category_col) {
  # Find the y column (the numeric column that's not fill_col or category_col)
  y_col <- setdiff(names(data), c(fill_col, category_col))[1]
  if (is.na(y_col)) {
    stop("Could not find y column in data")
  }
  
  # Create a temporary plot to determine the actual stacking order
  temp_plot <- ggplot2::ggplot(data, ggplot2::aes_string(x = category_col, y = y_col, fill = fill_col)) +
    ggplot2::geom_bar(stat = "identity", position = "stack")
  
  # Extract computed data to see the actual stacking order
  computed_data <- ggplot2::ggplot_build(temp_plot)$data[[1]]
  
  # Get the stacking order by looking at the first bar's layers
  first_bar_data <- computed_data[computed_data$x == 1, ]
  first_bar_data <- first_bar_data[order(first_bar_data$ymin), ]  # Order by ymin (bottom to top)
  
  # Map colors back to fill values
  color_to_fill <- setNames(data[[fill_col]], computed_data$fill)
  stacking_order <- unique(color_to_fill[first_bar_data$fill])
  
  # Create a factor with the REVERSE stacking order for JavaScript
  # Visual stacking: Normal (bottom) → Below (middle) → Above (top)
  # JavaScript expects: Above (top) → Below (middle) → Normal (bottom)
  # So we reverse the stacking order
  data[[fill_col]] <- factor(data[[fill_col]], levels = rev(stacking_order))
  
  # Apply category-first ordering: category first, then fill in reverse stacking order
  reordered_data <- data[order(data[[category_col]], data[[fill_col]]), ]
  
  # Convert back to character to avoid factor issues
  reordered_data[[fill_col]] <- as.character(reordered_data[[fill_col]])
  
  return(reordered_data)
}

#' Detect if a plot is a stacked bar plot
#' 
#' @param plot ggplot2 object
#' @return Logical indicating if the plot is a stacked bar plot
#' @keywords internal
is_stacked_bar_plot <- function(plot) {
  # Get built data
  built_data <- ggplot2::ggplot_build(plot)
  
  # Check if this is a stacked bar plot
  if (length(built_data$data) > 0) {
    built_data_layer <- built_data$data[[1]]
    if ("ymin" %in% names(built_data_layer) && "ymax" %in% names(built_data_layer)) {
      # Check if there are multiple ymin values (indicating stacking)
      unique_ymins <- unique(built_data_layer$ymin)
      return(length(unique_ymins) > 1)
    }
  }
  
  return(FALSE)
}

#' Extract fill and category column names from plot aesthetics
#' 
#' @param plot ggplot2 object
#' @return List with fill_col and category_col names
#' @keywords internal
extract_plot_columns <- function(plot) {
  # Get plot mappings
  plot_mapping <- plot$mapping
  
  # Extract fill column
  fill_col <- NULL
  if (!is.null(plot_mapping$fill)) {
    fill_col <- rlang::as_name(plot_mapping$fill)
  }
  
  # Extract x column (category)
  category_col <- NULL
  if (!is.null(plot_mapping$x)) {
    category_col <- rlang::as_name(plot_mapping$x)
  }
  
  return(list(
    fill_col = fill_col,
    category_col = category_col
  ))
}

#' Apply optimal reordering to stacked bar plot data
#' 
#' This function automatically detects if a plot is a stacked bar plot and
#' applies the optimal reordering strategy to ensure correct DOM element order.
#' 
#' @param plot ggplot2 object
#' @return ggplot2 object with reordered data (if applicable)
#' @keywords internal
apply_stacked_bar_reordering <- function(plot) {
  # Check if this is a stacked bar plot
  if (!is_stacked_bar_plot(plot)) {
    return(plot)  # No reordering needed for non-stacked plots
  }

  # Extract column names
  columns <- extract_plot_columns(plot)
  fill_col <- columns$fill_col
  category_col <- columns$category_col
  
  # Check if we have the required columns
  if (is.null(fill_col) || is.null(category_col)) {
    return(plot)  # Cannot reorder without proper column names
  }
  
  # Check if columns exist in the data
  if (!fill_col %in% names(plot$data) || !category_col %in% names(plot$data)) {
    return(plot)  # Columns not found in data
  }
  
  # Apply reordering
  reordered_data <- reorder_for_stacked_bar(plot$data, fill_col, category_col)
  
  # Update the plot data
  plot$data <- reordered_data
  
  # Rebuild the plot to ensure the new data is used
  plot <- ggplot2::ggplot_build(plot)$plot
  
  return(plot)
}

 