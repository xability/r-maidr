#' Extract layer IDs from gtable using factory pattern
#' @param gt A gtable object
#' @param plot_type The type of plot
#' @return Character vector of layer IDs
#' @keywords internal
extract_layer_ids <- function(gt, plot_type) {
  layer_ids <- switch(plot_type,
    "bar" = extract_bar_layer_ids_from_gtable(gt),
    "stacked_bar" = extract_bar_layer_ids_from_gtable(gt),
    "dodged_bar" = extract_bar_layer_ids_from_gtable(gt),
    "hist" = extract_bar_layer_ids_from_gtable(gt), 
    "smooth" = extract_polyline_layer_ids_from_gtable(gt), 
    character(0)
  )

  layer_ids
}

#' Find rectangular grobs from a gtable (generic)
#' @param gt A gtable object (from ggplotGrob)
#' @return List of rectangular grobs
#' @keywords internal
find_rect_grobs <- function(gt) {
  panel_index <- which(gt$layout$name == "panel")
  if (length(panel_index) == 0) {
    stop("No panel found in gtable")
  }

  panel_grob <- gt$grobs[[panel_index]]

  if (!inherits(panel_grob, "gTree")) {
    stop("Panel grob is not a gTree")
  }

  find_rect_grobs_recursive <- function(grob) {
    rect_grobs <- list()

    if (inherits(grob, "rectGrob") ||
      (inherits(grob, "rect") && !inherits(grob, "zeroGrob"))) {
      rect_grobs[[length(rect_grobs) + 1]] <- grob
    }

    if (inherits(grob, "gList")) {
      for (i in seq_along(grob)) {
        rect_grobs <- c(rect_grobs, find_rect_grobs_recursive(grob[[i]]))
      }
    }

    if (inherits(grob, "gTree")) {
      for (i in seq_along(grob$children)) {
        rect_grobs <- c(
          rect_grobs,
          find_rect_grobs_recursive(grob$children[[i]])
        )
      }
    }

    rect_grobs
  }

  all_rects <- find_rect_grobs_recursive(panel_grob)

  # Filter out background/border grobs
  rect_grobs <- list()
  for (i in seq_along(all_rects)) {
    grob <- all_rects[[i]]
    if (inherits(grob, "rectGrob") || inherits(grob, "rect")) {
      if (!grepl("background|border", grob$name, ignore.case = TRUE)) {
        rect_grobs[[length(rect_grobs) + 1]] <- grob
      }
    }
  }

  rect_grobs
}

#' Extract bar layer IDs from gtable
#' @param gt A gtable object
#' @return Character vector of layer IDs
#' @keywords internal
extract_bar_layer_ids_from_gtable <- function(gt) {
  # Find rectangular grobs (generic)
  grobs <- find_rect_grobs(gt)

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
    "hist" = make_hist_selector(layer_id),
    "smooth" = make_smooth_selector(layer_id),
    stop("Unsupported plot type: ", plot_type)
  )
  
  result
}