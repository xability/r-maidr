#' Extract trace from a ggplot2 layer (S3 generic)
#' @param layer A ggplot2 layer object
#' @param built_data The built data for this layer
#' @param layout Layout information from the plot
#' @param layer_id The layer ID to assign
#' @param ... Additional arguments
#' @export
extract_trace <- function(layer, built_data, layout = NULL, layer_id = NULL, ...) {
  geom_class <- class(layer$geom)[1]
  
  # Use factory pattern to determine trace type
  trace_type <- get_trace_type(geom_class)
  
  if (is.na(trace_type)) {
    return(list(type = NA_character_))
  }
  
  # Use switch instead of S3 dispatch since trace_type is a character
  switch(trace_type,
    "bar" = extract_trace_bar(layer, built_data, layout, layer_id, ...),
    stop("No extract_trace method for this layer type.")
  )
}

#' Get trace type from geom class
#' @param geom_class Character string of geom class
#' @return Trace type or NA_character_
#' @keywords internal
get_trace_type <- function(geom_class) {
  trace_mapping <- list(
    "GeomBar" = "bar",
    "GeomCol" = "bar"
  )
  
  return(trace_mapping[[geom_class]] %||% NA_character_)
}

#' Extract trace for bar plot layers (internal function)
#' @keywords internal
extract_trace_bar <- function(layer, built_data, layout, layer_id, ...) {
  # Use layout info if provided
  title <- if (!is.null(layout)) layout$title else ""
  axes <- if (!is.null(layout)) layout$axes else list(x = "", y = "")
  
  # Use the provided layer_id (which should be the actual grob number)
  id <- if (!is.null(layer_id)) layer_id else "1"
  
  # Extract x/y data
  data <- built_data[, c("x", "y"), drop = FALSE]
  
  list(
    type = "bar",
    title = title,
    axes = axes,
    id = id,
    data = data
  )
} 