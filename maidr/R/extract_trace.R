#' Extract trace from a ggplot2 layer (S3 generic)
#' @export
extract_trace <- function(layer, built_data, layout = NULL, layer_id = NULL) {
  geom_class <- class(layer$geom)[1]
  if (geom_class %in% c("GeomBar", "GeomCol")) {
    return(extract_trace_bar(layer, built_data, layout, layer_id))
  }
  return(list(type = NA_character_))
}

#' Extract trace for bar plot layers
#' @keywords internal
extract_trace_bar <- function(layer, built_data, layout, layer_id) {
  # Use layout info if provided
  title <- if (!is.null(layout)) layout$title else ""
  axes <- if (!is.null(layout)) layout$axes else list(x = "", y = "")
  id <- if (!is.null(layer_id)) layer_id else "maidr-layer-1"
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

#' Default method for extract_trace
#' @export
extract_trace.default <- function(layer, built_data, ...) {
  stop("No extract_trace method for this layer type.")
} 