#' Generic utility to replace grobs in a gtable
#' @param gt A gtable object (from ggplotGrob)
#' @param original_grobs List of original grobs to replace
#' @param new_grobs List of new grobs to replace with
#' @return Modified gtable with replaced grobs
#' @export
replace_grobs_in_gtable <- function(gt, original_grobs, new_grobs) {
  if (length(original_grobs) != length(new_grobs)) {
    stop("Number of original grobs must match number of new grobs")
  }
  
  # Recursive function to replace grobs in a gTree
  replace_grobs_recursive <- function(grob, original_grobs, new_grobs) {
    if (inherits(grob, "gTree")) {
      # Check if any of the children match our original grobs
      for (i in seq_along(grob$children)) {
        child <- grob$children[[i]]
        
        # Check if this child is one of our original grobs
        for (j in seq_along(original_grobs)) {
          if (identical(child, original_grobs[[j]])) {
            # Replace with the new grob
            grob$children[[i]] <- new_grobs[[j]]
            break
          }
        }
        
        # Recursively check children
        if (inherits(child, "gTree")) {
          grob$children[[i]] <- replace_grobs_recursive(child, original_grobs, new_grobs)
        }
      }
    }
    
    return(grob)
  }
  
  # Find the panel grob (where most geom grobs are located)
  panel_index <- which(gt$layout$name == "panel")
  if (length(panel_index) == 0) {
    stop("No panel found in gtable")
  }
  
  # Replace grobs in the panel
  gt$grobs[[panel_index]] <- replace_grobs_recursive(
    gt$grobs[[panel_index]], 
    original_grobs, 
    new_grobs
  )
  
  return(gt)
}

#' Extract bar grobs from a gtable
#' @param gt A gtable object (from ggplotGrob)
#' @return List of bar grobs
#' @export
extract_bar_grobs <- function(gt) {
  # Find the panel grob
  panel_index <- which(gt$layout$name == "panel")
  if (length(panel_index) == 0) {
    stop("No panel found in gtable")
  }
  
  panel_grob <- gt$grobs[[panel_index]]
  
  if (!inherits(panel_grob, "gTree")) {
    stop("Panel grob is not a gTree")
  }
  
  # Recursive function to find all rect grobs
  find_rect_grobs_recursive <- function(grob) {
    rect_grobs <- list()
    
    # Check for rectGrob OR rect class (bars can be either)
    if (inherits(grob, "rectGrob") || (inherits(grob, "rect") && !inherits(grob, "zeroGrob"))) {
      rect_grobs[[length(rect_grobs) + 1]] <- grob
    }
    
    # Check for gList
    if (inherits(grob, "gList")) {
      for (i in seq_along(grob)) {
        rect_grobs <- c(rect_grobs, find_rect_grobs_recursive(grob[[i]]))
      }
    }
    
    # Check for gTree
    if (inherits(grob, "gTree")) {
      for (i in seq_along(grob$children)) {
        rect_grobs <- c(rect_grobs, find_rect_grobs_recursive(grob$children[[i]]))
      }
    }
    
    return(rect_grobs)
  }
  
  # Find all rect grobs in the panel
  all_rects <- find_rect_grobs_recursive(panel_grob)
  
  # Filter for bar grobs (those created by GeomBar/GeomRect)
  # Bar grobs are typically rect or rectGrob objects with specific properties
  bar_grobs <- list()
  for (i in seq_along(all_rects)) {
    grob <- all_rects[[i]]
    # Check if this is a bar grob (not background, border, etc.)
    if (inherits(grob, "rectGrob") || inherits(grob, "rect")) {
      # Filter out background and border rects
      if (!grepl("background|border", grob$name, ignore.case = TRUE)) {
        bar_grobs[[length(bar_grobs) + 1]] <- grob
      }
    }
  }
  
  return(bar_grobs)
}

#' Add layer IDs to bar grobs
#' @param bar_grobs List of bar grobs
#' @param layer_ids Character vector of layer IDs to assign
#' @return List of modified bar grobs with layer IDs
#' @export
add_layer_id_to_bar_grobs <- function(bar_grobs, layer_ids = NULL) {
  if (is.null(layer_ids)) {
    layer_ids <- paste0("layer-", as.integer(Sys.time()), "-", seq_along(bar_grobs))
  }
  
  if (length(bar_grobs) != length(layer_ids)) {
    stop("Number of bar grobs must match number of layer IDs")
  }
  
  modified_grobs <- list()
  
  for (i in seq_along(bar_grobs)) {
    grob <- bar_grobs[[i]]
    
    # Add layer ID as a custom attribute
    grob[["maidr"]] <- layer_ids[i]
    
    # Add a special attribute to mark this as a custom grob
    grob[["data-custom"]] <- "true"
    
    modified_grobs[[i]] <- grob
  }
  
  return(modified_grobs)
}

#' Generic function to extract grobs based on plot type
#' @param gt A gtable object (from ggplotGrob)
#' @param plot_type The type of plot (e.g., "bar", "scatter", "line")
#' @param ... Additional arguments passed to plot-type-specific functions
#' @return List of grobs for the specified plot type
#' @export
extract_grobs <- function(gt, plot_type, ...) {
  switch(plot_type,
    "bar" = extract_bar_grobs(gt),
    stop("No extractor found for plot type: ", plot_type)
  )
}

#' Generic function to add layer IDs to grobs based on plot type
#' @param grobs List of grobs
#' @param plot_type The type of plot (e.g., "bar", "scatter", "line")
#' @param layer_ids Character vector of layer IDs to assign
#' @param ... Additional arguments passed to plot-type-specific functions
#' @return List of modified grobs with layer IDs
#' @export
add_layer_id_to_grobs <- function(grobs, plot_type, layer_ids = NULL, ...) {
  switch(plot_type,
    "bar" = add_layer_id_to_bar_grobs(grobs, layer_ids),
    stop("No layer ID adder found for plot type: ", plot_type)
  )
}

#' Generic function to process grobs for a plot
#' @param gt A gtable object (from ggplotGrob)
#' @param plot_type The type of plot (e.g., "bar", "scatter", "line")
#' @param layer_ids Character vector of layer IDs to assign
#' @param ... Additional arguments passed to plot-type-specific functions
#' @return List with original grobs and modified grobs
#' @export
process_grobs_for_plot <- function(gt, plot_type, layer_ids = NULL, ...) {
  # Extract grobs based on plot type
  grobs <- extract_grobs(gt, plot_type, ...)
  
  # Add layer IDs to grobs
  modified_grobs <- add_layer_id_to_grobs(grobs, plot_type, layer_ids, ...)
  
  list(
    original_grobs = grobs,
    modified_grobs = modified_grobs,
    plot_type = plot_type
  )
}
