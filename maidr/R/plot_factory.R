#' Factory for plot type detection and processing
#'
#' This file implements the Factory Pattern for plot type detection and
#' processing. It provides a centralized way to handle different plot types
#' in a extensible manner.

#' Detect plot type from ggplot object using factory pattern
#' @param plot A ggplot2 object
#' @return Character string indicating plot type
#' @export
detect_plot_type <- function(plot) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  layers <- plot$layers
  geom_types <- sapply(layers, function(layer) {
    class(layer$geom)[1]
  })

  plot_type <- determine_plot_type_from_geoms(geom_types)

  if (is.na(plot_type)) {
    stop(
      "Unable to detect plot type from geom layers: ",
      paste(geom_types, collapse = ", ")
    )
  }

  plot_type
}

#' Determine plot type based on geom classes using factory pattern
#' @param geom_types Character vector of geom classes
#' @return Plot type or NA_character_
#' @keywords internal
determine_plot_type_from_geoms <- function(geom_types) {
  if (any(geom_types %in% c("GeomBar", "GeomCol"))) {
    return("bar")
  }

  NA_character_
}

#' Get list of supported plot types
#' @return Character vector of supported plot types
#' @export
get_supported_plot_types <- function() {
  c("bar")
}

#' Check if plot type is supported
#' @param plot_type Character string indicating plot type
#' @return Logical indicating if plot type is supported
#' @export
is_supported_plot_type <- function(plot_type) {
  plot_type %in% get_supported_plot_types()
}

#' Create plot processor based on plot type using factory pattern
#' @param plot A ggplot2 object
#' @param plot_type The type of plot (if NULL, will be detected)
#' @param ... Additional arguments
#' @return A plot_data object
#' @export
create_plot_processor <- function(plot, plot_type = NULL, ...) {
  if (is.null(plot_type)) {
    plot_type <- detect_plot_type(plot)
  }

  if (!is_supported_plot_type(plot_type)) {
    stop("Unsupported plot type: ", plot_type)
  }

  switch(plot_type,
    "bar" = process_bar_plot(plot, ...),
    stop("Unsupported plot type: ", plot_type)
  )
}

#' Process bar plot using factory pattern
#' @param plot A ggplot2 object
#' @param ... Additional arguments
#' @return A bar_plot_data object
#' @keywords internal
process_bar_plot <- function(plot, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  layout <- extract_layout(plot)
  data <- extract_bar_data(plot)
  selectors <- make_bar_selectors(plot)

  bar_plot_data(data = data, layout = layout, selectors = selectors)
}

#' Extract plot data using factory pattern
#' @param plot A ggplot2 object
#' @param built The built plot data
#' @param layout Layout information
#' @param plot_type The type of plot
#' @return List of data for each layer
#' @keywords internal
extract_plot_data <- function(plot, built, layout, plot_type) {
  switch(plot_type,
    "bar" = extract_bar_data(plot),
    list() # Return empty list for unsupported types
  )
}