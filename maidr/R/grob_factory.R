#' Extract layer IDs from gtable using factory pattern
#' @param gt A gtable object
#' @param plot_type The type of plot
#' @return Character vector of layer IDs
#' @keywords internal
extract_layer_ids <- function(gt, plot_type) {
  layer_ids <- switch(plot_type,
    "bar" = extract_bar_layer_ids_from_gtable(gt),
    "stacked_bar" = extract_bar_layer_ids_from_gtable(gt),  # Use same logic as regular bars
    character(0) # Return empty vector for unsupported types
  )

  layer_ids
}

#' Extract bar layer IDs from gtable
#' @param gt A gtable object
#' @return Character vector of layer IDs
#' @keywords internal
extract_bar_layer_ids_from_gtable <- function(gt) {
  # Find bar grobs
  grobs <- find_bar_grobs(gt)

  # Extract layer IDs from grob names
  layer_ids <- character(0)
  for (grob in grobs) {
    grob_name <- grob$name
    # Extract the numeric part from grob name
    # (e.g., "2" from "geom_rect.rect.2")
    layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
    layer_ids <- c(layer_ids, layer_id)
  }

  layer_ids
}

#' Make selector for plot type and layer ID using factory pattern
#' @param plot_type The type of plot
#' @param layer_id The layer ID
#' @param plot The ggplot2 object (required for stacked bars)
#' @return CSS selector string or list of selectors
#' @keywords internal
make_selector <- function(plot_type, layer_id, plot = NULL) {
  result <- switch(plot_type,
    "bar" = make_bar_selector(layer_id),
    "stacked_bar" = make_stacked_bar_selectors(plot, layer_id),
    stop("Unsupported plot type: ", plot_type)
  )
  
  result
}
