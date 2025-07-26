# Internal helper functions for maidr 

#' Get the plot type from a ggplot object
#'
#' Inspects the layers of a ggplot object and returns the plot type.
#' Currently supports detection of bar plots (geom_bar, geom_col).
#' Uses a factory pattern to make it extensible for new plot types.
#' 
#' @param gg A ggplot2 object
#' @return A character string indicating the plot type (e.g., 'bar'), or NA if not recognized
#' @export
get_plot_type <- function(gg) {
  if (!inherits(gg, "ggplot")) {
    stop("Input must be a ggplot object.")
  }
  
  geoms <- vapply(gg$layers, function(layer) class(layer$geom)[1], character(1))
  
  # Use factory pattern to determine plot type
  plot_type <- determine_plot_type(geoms)
  
  return(plot_type)
}

#' Determine plot type based on geom classes
#' @param geoms Character vector of geom classes
#' @return Plot type or NA_character_
#' @keywords internal
determine_plot_type <- function(geoms) {
  # Bar plots
  if (any(geoms %in% c("GeomBar", "GeomCol"))) {
    return("bar")
  }
  
  # Add more plot types here as needed
  # if (any(geoms %in% c("GeomPoint"))) {
  #   return("scatter")
  # }
  
  return(NA_character_)
}

#' Check if a plot type is supported
#' @param plot_type Character string indicating plot type
#' @return Logical indicating if the plot type is supported
#' @export
is_supported_plot_type <- function(plot_type) {
  supported_types <- c("bar")
  return(plot_type %in% supported_types)
}

#' Get supported plot types
#' @return Character vector of supported plot types
#' @export
get_supported_plot_types <- function() {
  return(c("bar"))
}

#' Get default element type for a plot type
#' @param plot_type Character string indicating plot type
#' @return Character string indicating default element type
#' @export
get_default_element_type <- function(plot_type) {
  element_types <- list(
    bar = "rect"
  )
  
  return(element_types[[plot_type]] %||% "rect")
} 