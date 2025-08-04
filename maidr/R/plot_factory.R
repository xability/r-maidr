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
    # Check aes_params for fill
    if (!is.null(layer$aes_params) && "fill" %in% names(layer$aes_params)) {
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

#' Check if plot is a histogram
#' @param plot A ggplot2 object
#' @return Logical indicating if plot is a histogram
#' @keywords internal
is_histogram_plot <- function(plot) {
  if (length(plot$layers) == 0) {
    return(FALSE)
  }
  
  # Check if any layer has GeomBar with StatBin
  for (layer in plot$layers) {
    if (inherits(layer$geom, "GeomBar") && inherits(layer$stat, "StatBin")) {
      return(TRUE)
    }
  }
  
  FALSE
}

#' Determine if plot is stacked bar
#' @param plot A ggplot2 object
#' @return Logical indicating if plot is stacked bar
#' @keywords internal
is_stacked_bar <- function(plot) {
  position_class <- get_position_class(plot)
  has_fill <- has_fill_aesthetic(plot)
  
  # A stacked bar must have PositionStack AND fill aesthetic
  if (position_class == "PositionStack" && has_fill) {
    layer <- plot$layers[[1]]
    
    if (!is.null(layer$mapping) && "fill" %in% names(layer$mapping)) {
      return(TRUE)
    }
    
    if (!is.null(plot$mapping) && "fill" %in% names(plot$mapping)) {
      return(TRUE)
    }
    
    if (!is.null(layer$aes_params) && "fill" %in% names(layer$aes_params)) {
      return(FALSE)
    }
  }
  
  FALSE
}

#' Determine if plot is dodged bar
#' @param plot A ggplot2 object
#' @return Logical indicating if plot is dodged bar
#' @keywords internal
is_dodged_bar <- function(plot) {
  position_class <- get_position_class(plot)
  has_fill <- has_fill_aesthetic(plot)
  position_class == "PositionDodge" && has_fill
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
  # Check for histogram first
  if (is_histogram_plot(plot)) {
    return("hist")
  }
  if (is_stacked_bar(plot)) {
    return("stacked_bar")
  } else if (is_dodged_bar(plot)) {
    return("dodged_bar")
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
  # Check for smooth plots first (GeomDensity or GeomLine with StatDensity)
  if (any(geom_types %in% c("GeomDensity")) || 
      (any(geom_types %in% c("GeomLine")) && has_density_stat(plot))) {
    return("smooth")
  }
  
  # Check for bar types
  if (is_bar_geom(geom_types)) {
    return(detect_bar_type(plot, geom_types))
  }
  
  # If no specific type is detected, return NA
  NA_character_
}

#' Check if plot has density stat
#' @param plot A ggplot2 object
#' @return Logical indicating if plot has density stat
#' @keywords internal
has_density_stat <- function(plot) {
  if (length(plot$layers) == 0) {
    return(FALSE)
  }
  
  # Check if any layer has StatDensity
  for (layer in plot$layers) {
    if (inherits(layer$stat, "StatDensity")) {
      return(TRUE)
    }
  }
  
  FALSE
}

#' Get list of supported plot types
#' @return Character vector of supported plot types
#' @export
get_supported_plot_types <- function() {
  c("bar", "stacked_bar", "dodged_bar", "hist", "smooth")
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
#' @param ... Additional arguments
#' @return A plot_data object
#' @export
create_plot_processor <- function(plot, ...) {
  plot_type <- detect_plot_type(plot)

  if (!is_supported_plot_type(plot_type)) {
    stop("Unsupported plot type: ", plot_type)
  }

  switch(plot_type,
    "bar" = process_bar_plot(plot, ...),
    "stacked_bar" = process_stacked_bar_plot(plot, ...),
    "dodged_bar" = process_dodged_bar_plot(plot, ...),
    "hist" = process_histogram_plot(plot, ...),
    "smooth" = process_smooth_plot(plot, ...),
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

#' Process dodged bar plot using factory pattern
#' @param plot A ggplot2 object
#' @param ... Additional arguments
#' @return A dodged_bar_plot_data object
#' @keywords internal
process_dodged_bar_plot <- function(plot, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  # Apply reordering for dodged bar plots to ensure correct DOM element order
  reordered_plot <- apply_dodged_bar_reordering(plot)

  layout <- extract_layout(reordered_plot)
  data <- extract_dodged_bar_data(reordered_plot)
  # Note: selectors are generated later in make_selector() with proper layer_id
  # No need to generate them here as they'll be regenerated with correct layer_id

  dodged_bar_plot_data(data = data, layout = layout, selectors = list(), reordered_plot = reordered_plot)
}

#' Process histogram plot using factory pattern
#' @param plot A ggplot2 object
#' @param ... Additional arguments
#' @return A histogram_plot_data object
#' @keywords internal
process_histogram_plot <- function(plot, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  layout <- extract_layout(plot)
  data <- extract_histogram_data(plot)
  selectors <- make_histogram_selectors(plot)

  histogram_plot_data(data = data, layout = layout, selectors = selectors)
}

#' Process smooth plot using factory pattern
#' @param plot A ggplot2 object
#' @param ... Additional arguments
#' @return A smooth_plot_data object
#' @keywords internal
process_smooth_plot <- function(plot, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  layout <- extract_layout(plot)
  data <- extract_smooth_data(plot)
  selectors <- make_smooth_selectors(plot)

  smooth_plot_data(data = data, layout = layout, selectors = selectors)
}