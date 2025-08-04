#' Extract histogram data from ggplot object
#' @param plot A ggplot2 object
#' @return List of histogram data points
#' @keywords internal
extract_histogram_data <- function(plot) {
  built <- ggplot_build(plot)
  histogram_data <- list()
  
  for (i in seq_along(built$data)) {
    layer_data <- built$data[[i]]
    
    # Check if this layer has histogram data (rectangular bars with xmin/xmax)
    if (all(c("x", "y", "xmin", "xmax", "ymin", "ymax") %in% names(layer_data))) {
      # This is a histogram layer
      for (j in seq_len(nrow(layer_data))) {
        point <- list(
          x = layer_data$x[j],
          y = layer_data$y[j],
          xMin = layer_data$xmin[j],
          xMax = layer_data$xmax[j],
          yMin = layer_data$ymin[j],
          yMax = layer_data$ymax[j]
        )
        histogram_data[[length(histogram_data) + 1]] <- point
      }
    }
  }
  
  histogram_data
}

#' Extract histogram layer data from plot processor
#' @param plot_processor The plot processor object
#' @param layer_id The layer ID
#' @return Histogram layer data structure (array format)
#' @keywords internal
extract_histogram_layer_data <- function(plot_processor, layer_id) {
  if (is.null(plot_processor$data)) {
    return(list())
  }
  
  # For histogram plots, return the entire data array
  # plot_processor$data is already the array of histogram data points
  if (length(plot_processor$data) > 0) {
    return(plot_processor$data)
  }
  
  return(list())
}

#' Get histogram layer type
#' @return Character string indicating histogram layer type
#' @keywords internal
get_histogram_layer_type <- function() {
  "hist"
}

#' Make histogram selectors
#' @param plot A ggplot2 object
#' @return List of CSS selectors
#' @keywords internal
make_histogram_selectors <- function(plot) {
  # For now, return empty list - selectors will be generated later with proper layer_id
  list()
}

#' Make histogram bar selector
#' @param layer_id The layer ID
#' @return CSS selector string
#' @keywords internal
make_hist_selector <- function(layer_id) {
  # Use the same selector logic as bar plots since histogram bars are rendered as rectangles
  make_bar_selector(layer_id)
}

#' Create histogram plot data object
#' @param data The extracted data
#' @param layout The layout information
#' @param selectors The selectors for the plot
#' @return A histogram_plot_data object
#' @export
histogram_plot_data <- function(data, layout, selectors) {
  base_obj <- plot_data(data = data, layout = layout, selectors = selectors, type = "hist")
  class(base_obj) <- c("histogram_plot_data", class(base_obj))
  base_obj
} 