#' Base plot data S3 class
#'
#' This is the base class for all plot data objects. It provides a common
#' interface for different plot types while allowing specific implementations
#' for each type.
#'
#' @param type Character string indicating plot type
#' @param data Plot-specific data
#' @param layout Layout information
#' @param selectors CSS selectors for plot elements
#' @param ... Additional arguments
#' @return A plot_data object
#' @export
plot_data <- function(type, data, layout, selectors, ...) {
  structure(
    list(
      type = type,
      data = data,
      layout = layout,
      selectors = selectors,
      ...
    ),
    class = c("plot_data", "list")
  )
}

#' Print method for plot_data objects
#' @param x A plot_data object
#' @param ... Additional arguments
#' @export
print.plot_data <- function(x, ...) {
  cat("Plot Data Object\n")
  cat("Type:", x$type, "\n")
  cat("Data points:", length(x$data), "\n")
  cat("Selectors:", length(x$selectors), "\n")
  invisible(x)
}

#' Generic function for converting to JSON
#' @param x Object to convert
#' @param ... Additional arguments
#' @export
as.json <- function(x, ...) {
  UseMethod("as.json")
}

#' Default JSON conversion for plot_data objects
#' @param x A plot_data object
#' @param ... Additional arguments passed to jsonlite::toJSON
#' @return JSON string
#' @export
as.json.plot_data <- function(x, ...) {
  jsonlite::toJSON(unclass(x), auto_unbox = TRUE, ...)
}

#' Check if object is a plot_data
#' @param x Object to check
#' @return Logical indicating if object is plot_data
#' @export
is.plot_data <- function(x) {
  inherits(x, "plot_data")
}

#' Get plot type from plot_data object
#' @param x A plot_data object
#' @return Character string indicating plot type
#' @export
get_plot_type.plot_data <- function(x) {
  x$type
}

#' Generic function for getting plot type
#' @param x Object to get plot type from
#' @param ... Additional arguments
#' @export
get_plot_type <- function(x, ...) {
  UseMethod("get_plot_type")
}

#' Extract standardized layer data from plot processor
#' @param plot_processor The plot processor object
#' @param plot_type The plot type
#' @param layer_id The layer ID
#' @return Standardized layer data structure
#' @keywords internal
extract_layer_data <- function(plot_processor, plot_type, layer_id) {
  if (is.null(plot_processor$data)) {
    return(list())
  }
  
  # Delegate to plot-specific extraction functions
  switch(plot_type,
    "histogram" = extract_histogram_layer_data(plot_processor, layer_id),
    "smooth" = extract_smooth_layer_data(plot_processor, layer_id),
    "bar" = extract_bar_layer_data(plot_processor, layer_id),
    "stacked_bar" = extract_stacked_bar_layer_data(plot_processor, layer_id),
    "dodged_bar" = extract_dodged_bar_layer_data(plot_processor, layer_id),
    extract_default_layer_data(plot_processor, layer_id)  # fallback for other plot types
  )
}

#' Extract default layer data from plot processor
#' @param plot_processor The plot processor object
#' @param layer_id The layer ID
#' @return Default layer data structure
#' @keywords internal
extract_default_layer_data <- function(plot_processor, layer_id) {
  if (is.null(plot_processor$data)) {
    return(list())
  }
  
  # For default case, return the data as is
  plot_processor$data
}
