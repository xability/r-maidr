#' Factory function to create data extractors for different plot types
#' @param plot_type The type of plot
#' @return A function that can extract data for the specified plot type
#' @keywords internal
make_data_extractor <- function(plot_type) {
  switch(plot_type,
    "bar" = extract_layer_data_bar,
    stop("No data extractor implemented for plot type: ", plot_type)
  )
}

#' Bar plot data extractor (internal function)
#' @param layer A ggplot2 layer
#' @param built_data The built data for this layer
#' @param layout Layout information
#' @return List of data points
#' @keywords internal
extract_layer_data_bar <- function(layer, built_data, layout) {
  # For bar plots, extract x and y values
  if (inherits(layer$geom, "GeomBar") || inherits(layer$geom, "GeomCol")) {
    # Get the data that was actually used for plotting
    data_points <- list()
    
    # Extract x and y values
    if (nrow(built_data) > 0) {
      for (j in 1:nrow(built_data)) {
        point <- list()
        
        # Add x value
        if ("x" %in% names(built_data)) {
          point$x <- built_data$x[j]
        }
        
        # Add y value (count for bar plots)
        if ("y" %in% names(built_data)) {
          point$y <- built_data$y[j]
        } else if ("count" %in% names(built_data)) {
          point$y <- built_data$count[j]
        }
        
        # Add any other relevant data
        if ("fill" %in% names(built_data)) {
          point$fill <- built_data$fill[j]
        }
        
        data_points[[j]] <- point
      }
    }
    
    return(data_points)
  }
  
  # For other plot types, return empty list for now
  return(list())
}

#' Extract data from a specific layer using factory pattern
#' @param layer A ggplot2 layer
#' @param built_data The built data for this layer
#' @param layout Layout information
#' @param plot_type The type of plot
#' @return List of data points
#' @keywords internal
extract_layer_data <- function(layer, built_data, layout, plot_type) {
  # Use factory pattern to get plot-type-specific data extractor
  data_extractor <- make_data_extractor(plot_type)
  return(data_extractor(layer, built_data, layout))
} 