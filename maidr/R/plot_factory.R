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

  plot_type <- determine_plot_type_from_geoms_and_position(plot, geom_types)

  if (is.na(plot_type)) {
    stop(
      "Unable to detect plot type from geom layers: ",
      paste(geom_types, collapse = ", ")
    )
  }

  plot_type
}

#' Check if plot has fill aesthetic
#' @param plot A ggplot2 object
#' @return Logical indicating if fill aesthetic is present
#' @keywords internal
has_fill_aesthetic <- function(plot) {
  has_fill <- FALSE
  if (length(plot$layers) > 0) {
    layer <- plot$layers[[1]]
    # Check layer mapping for fill
    if (!is.null(layer$mapping) && "fill" %in% names(layer$mapping)) {
      has_fill <- TRUE
    }
    # Check plot mapping for fill
    if (!is.null(plot$mapping) && "fill" %in% names(plot$mapping)) {
      has_fill <- TRUE
    }
  }
  has_fill
}

#' Get position class from plot
#' @param plot A ggplot2 object
#' @return Character string of position class
#' @keywords internal
get_position_class <- function(plot) {
  if (length(plot$layers) == 0) {
    return(NA_character_)
  }
  position <- plot$layers[[1]]$position
  class(position)[1]
}

#' Check if geoms are bar types
#' @param geom_types Character vector of geom classes
#' @return Logical indicating if geoms are bar types
#' @keywords internal
is_bar_geom <- function(geom_types) {
  any(geom_types %in% c("GeomBar", "GeomCol"))
}

#' Determine if plot is stacked bar
#' @param plot A ggplot2 object
#' @return Logical indicating if plot is stacked bar
#' @keywords internal
is_stacked_bar <- function(plot) {
  position_class <- get_position_class(plot)
  has_fill <- has_fill_aesthetic(plot)
  position_class == "PositionStack" && has_fill
}

#' Detect bar plot type
#' @param plot A ggplot2 object
#' @param geom_types Character vector of geom classes
#' @return Character string indicating plot type
#' @keywords internal
detect_bar_type <- function(plot, geom_types) {
  if (!is_bar_geom(geom_types)) {
    return(NA_character_)
  }
  if (is_stacked_bar(plot)) {
    return("stacked_bar")
  } else {
    return("bar")
  }
}

#' Determine plot type based on geom classes and position using factory pattern
#' @param plot A ggplot2 object
#' @param geom_types Character vector of geom classes
#' @return Plot type or NA_character_
#' @keywords internal
determine_plot_type_from_geoms_and_position <- function(plot, geom_types) {
  detect_bar_type(plot, geom_types)
}

#' Determine plot type based on geom classes using factory pattern (legacy)
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
  c("bar", "stacked_bar")
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
    "stacked_bar" = process_stacked_bar_plot(plot, ...),
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

#' Process stacked bar plot using factory pattern
#' @param plot A ggplot2 object
#' @param ... Additional arguments
#' @return A stacked_bar_plot_data object
#' @keywords internal
process_stacked_bar_plot <- function(plot, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  # Apply reordering for stacked bar plots to ensure correct DOM element order
  reordered_plot <- apply_stacked_bar_reordering(plot)

  layout <- extract_layout(reordered_plot)
  data <- extract_stacked_bar_data(reordered_plot)
  # Note: selectors are generated later in make_selector() with proper layer_id
  # No need to generate them here as they'll be regenerated with correct layer_id

  stacked_bar_plot_data(data = data, layout = layout, selectors = list(), reordered_plot = reordered_plot)
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
    "stacked_bar" = extract_stacked_bar_data(plot),
    list() # Return empty list for unsupported types
  )
}