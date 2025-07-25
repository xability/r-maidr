# Internal helper functions for maidr 

#' Get the plot type from a ggplot object
#'
#' Inspects the layers of a ggplot object and returns the plot type.
#' Currently supports detection of bar plots (geom_bar, geom_col).
#' @param gg A ggplot2 object
#' @return A character string indicating the plot type (e.g., 'bar'), or NA if not recognized
#' @export
get_plot_type <- function(gg) {
    
  geoms <- vapply(gg$layers, function(layer) class(layer$geom)[1], character(1))
  if (any(geoms %in% c("GeomBar", "GeomCol"))) {
    return("bar")
  }
  NA_character_
} 