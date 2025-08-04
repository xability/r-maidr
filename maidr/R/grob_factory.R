#' Extract layer IDs from gtable using factory pattern
#' @param gt A gtable object
#' @param plot_type The type of plot
#' @return Character vector of layer IDs
#' @keywords internal
extract_layer_ids <- function(gt, plot_type) {
  layer_ids <- switch(plot_type,
    "bar" = extract_bar_layer_ids_from_gtable(gt),
    "stacked_bar" = extract_bar_layer_ids_from_gtable(gt),  # Use same logic as regular bars
    "dodged_bar" = extract_bar_layer_ids_from_gtable(gt),  # Use same logic as regular bars
    "hist" = extract_bar_layer_ids_from_gtable(gt),  # Histogram bars are rectangles
    "histogram" = extract_bar_layer_ids_from_gtable(gt),  # Backward compatibility
    "smooth" = extract_polyline_layer_ids_from_gtable(gt),  # Use polyline logic for smooth curves
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
    "dodged_bar" = make_dodged_bar_selectors(plot, layer_id),
    "hist" = make_hist_selector(layer_id), # Histogram type
    "smooth" = make_smooth_selector(layer_id), # Added smooth type
    stop("Unsupported plot type: ", plot_type)
  )
  
  result
}

#' Make histogram bar selector
#' @param layer_id The layer ID
#' @return CSS selector string
#' @keywords internal
make_hist_selector <- function(layer_id) {
  # Use the same selector logic as bar plots since histogram bars are rendered as rectangles
  make_bar_selector(layer_id)
}

#' Make smooth curve selector
#' @param layer_id The layer ID
#' @return CSS selector array
#' @keywords internal
make_smooth_selector <- function(layer_id) {
  # For smooth plots, the layer_id should be the actual numeric ID from the grob name
  # The pattern is "GRID.polyline.{layer_id}.1.1"
  grob_id <- paste0("GRID.polyline.", layer_id, ".1.1")
  
  escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
  
  selector <- paste0("#", escaped_grob_id)
  
  # Return as character vector to ensure proper JSON serialization as array
  c(selector)
}
