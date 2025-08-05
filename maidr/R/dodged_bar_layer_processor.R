#' Dodged Bar Layer Processor
#' 
#' Processes dodged bar plot layers with complete logic included
#' 
#' @export
DodgedBarLayerProcessor <- R6::R6Class("DodgedBarLayerProcessor",
  inherit = LayerProcessor,
  
  public = list(
    process = function(plot, layout, gt = NULL) {
      # Apply reordering if needed
      if (self$needs_reordering()) {
        plot <- self$apply_reordering(plot)
        # Store the reordered plot for later use
        private$reordered_plot <- plot
      }
      
      # Extract data from the reordered plot
      data <- self$extract_data_impl(plot)
      
      # Generate selectors using the reordered plot
      selectors <- self$generate_selectors(plot, gt)
      
      return(list(
        data = data,
        selectors = selectors
      ))
    },
    
    #' Check if this layer needs reordering
    needs_reordering = function() {
      return(TRUE)  # Dodged bars need reordering
    },
    
    #' Apply reordering to the plot data
    apply_reordering = function(plot) {
      # Get the original data
      original_data <- plot$data
      
      # Get the actual column names from the plot aesthetics
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[1]]$mapping
      
      x_col <- NULL
      y_col <- NULL
      fill_col <- NULL
      
      if (!is.null(layer_mapping)) {
        if (!is.null(layer_mapping$x)) x_col <- rlang::as_name(layer_mapping$x)
        if (!is.null(layer_mapping$y)) y_col <- rlang::as_name(layer_mapping$y)
        if (!is.null(layer_mapping$fill)) fill_col <- rlang::as_name(layer_mapping$fill)
      }
      if (!is.null(plot_mapping)) {
        if (is.null(x_col) && !is.null(plot_mapping$x)) x_col <- rlang::as_name(plot_mapping$x)
        if (is.null(y_col) && !is.null(plot_mapping$y)) y_col <- rlang::as_name(plot_mapping$y)
        if (is.null(fill_col) && !is.null(plot_mapping$fill)) fill_col <- rlang::as_name(plot_mapping$fill)
      }
      
      # Reorder the data
      reordered_data <- self$reorder_data_for_visual_order(original_data, x_col, y_col, fill_col)
      
      # Create a new plot with reordered data
      new_plot <- plot
      new_plot$data <- reordered_data
      
      return(new_plot)
    },
    
    #' Reorder data for visual order in dodged bar plots
    reorder_data_for_visual_order = function(data, x_col, y_col, fill_col) {
      # Get unique values and sort them consistently
      x_values <- sort(unique(data[[x_col]]))
      fill_values <- sort(unique(data[[fill_col]]))
      
      reordered_data <- data.frame()
      
      # For each x value, process fill values in reverse order
      # This will create: A-Type2, A-Type1, B-Type2, B-Type1, C-Type2, C-Type1
      for (x_val in x_values) {
        for (fill_val in rev(fill_values)) {  # Type2 first, then Type1 for each x
          # Find the row for this x-fill combination
          matching_rows <- which(data[[x_col]] == x_val & data[[fill_col]] == fill_val)
          if (length(matching_rows) > 0) {
            reordered_data <- rbind(reordered_data, data[matching_rows, ])
          }
        }
      }
      
      return(reordered_data)
    },
    
    #' Extract data implementation
    extract_data_impl = function(plot) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      # Get the built data from the plot
      built <- ggplot_build(plot)
      
      # Extract data from the first layer (dodged bar layer)
      layer_data <- built$data[[1]]
      
      # Get the original data to retain text values
      original_data <- plot$data
      
      # Get the actual column names from the plot aesthetics
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[1]]$mapping
      
      # Determine x, y, and fill column names
      x_col <- NULL
      y_col <- NULL
      fill_col <- NULL
      
      # Check layer mapping first, then plot mapping
      if (!is.null(layer_mapping)) {
        if (!is.null(layer_mapping$x)) x_col <- rlang::as_name(layer_mapping$x)
        if (!is.null(layer_mapping$y)) y_col <- rlang::as_name(layer_mapping$y)
        if (!is.null(layer_mapping$fill)) fill_col <- rlang::as_name(layer_mapping$fill)
      }
      if (!is.null(plot_mapping)) {
        if (is.null(x_col) && !is.null(plot_mapping$x)) x_col <- rlang::as_name(plot_mapping$x)
        if (is.null(y_col) && !is.null(plot_mapping$y)) y_col <- rlang::as_name(plot_mapping$y)
        if (is.null(fill_col) && !is.null(plot_mapping$fill)) fill_col <- rlang::as_name(plot_mapping$fill)
      }
      
      # Ensure required columns are found
      if (is.null(x_col)) {
        stop("Could not determine x aesthetic mapping")
      }
      if (is.null(y_col)) {
        stop("Could not determine y aesthetic mapping")
      }
      if (is.null(fill_col)) {
        stop("Could not determine fill aesthetic mapping")
      }
      
      # Get unique values
      x_values <- unique(original_data[[x_col]])
      fill_values <- unique(original_data[[fill_col]])
      
      # Sort values consistently
      x_values <- sort(x_values)
      fill_values <- sort(fill_values)
      
      # Get fill values in the order they appear in the reordered data
      # DOM order is: right bar first, then left bar (due to rev(fill_values) in reordering)
      # But data structure should be: Type1 first, then Type2 (sorted order)
      fill_order <- sort(unique(original_data[[fill_col]]))
      
      # Create nested structure for maidr with text values
      # Order groups to match original data order (Type1 first, then Type2)
      # Each group represents one fill value (e.g., one color in the dodged bars)
      maidr_data <- list()
      for (fill_value in fill_order) {
        group_points <- list()
        for (x_val in x_values) {
          # Find the y value for this x-fill combination
          matching_rows <- which(original_data[[x_col]] == x_val & original_data[[fill_col]] == fill_value)
          if (length(matching_rows) > 0) {
            y_val <- original_data[[y_col]][matching_rows[1]]
            group_points[[length(group_points) + 1]] <- list(
              x = as.character(x_val),
              y = y_val,
              fill = as.character(fill_value)
            )
          }
        }
        maidr_data[[length(maidr_data) + 1]] <- group_points
      }
      
      return(maidr_data)
    },
    
    generate_selectors = function(plot, gt = NULL) {
      # Helper function to recursively search for geom_rect grobs
      find_geom_rect_grobs <- function(grob) {
        rect_grobs <- character(0)
        
        # Check if this grob is a geom_rect
        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          rect_grobs <- c(rect_grobs, grob$name)
        }
        
        # Recursively search children
        if ("children" %in% names(grob) && length(grob$children) > 0) {
          for (child in grob$children) {
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs(child))
          }
        }
        
        return(rect_grobs)
      }
      
      # Find the actual grob ID from the gtable
      if (!is.null(gt)) {
        # Try to find rect grobs by recursively searching the grob tree
        rect_grobs <- character(0)
        
        # Search through all top-level grobs
        if ("grobs" %in% names(gt) && length(gt$grobs) > 0) {
          for (i in 1:length(gt$grobs)) {
            grob <- gt$grobs[[i]]
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs(grob))
          }
        }
        
        # If not found, look in layout
        if (length(rect_grobs) == 0 && "layout" %in% names(gt)) {
          if ("grobs" %in% names(gt$layout) && length(gt$layout$grobs) > 0) {
            for (i in 1:length(gt$layout$grobs)) {
              grob <- gt$layout$grobs[[i]]
              rect_grobs <- c(rect_grobs, find_geom_rect_grobs(grob))
            }
          }
        }
        
        if (length(rect_grobs) > 0) {
          # Use the first rect grob found
          grob_name <- rect_grobs[1]
          # Extract the numeric part from grob name (e.g., "58" from "geom_rect.rect.58")
          layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
          # Create selector with .1 suffix as per original logic
          grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id, " rect")
        } else {
          # Fallback to layer index if no rect grobs found
          layer_id <- self$get_layer_index()
          grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id, " rect")
        }
      } else {
        # No gtable provided, use layer index
        layer_id <- self$get_layer_index()
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        selector_string <- paste0("#", escaped_grob_id, " rect")
      }
      
      return(selector_string)
    },
    
    #' Get the last processed result
    get_last_result = function() {
      return(private$last_result)
    },
    
    #' Get the reordered plot if it exists
    get_reordered_plot = function() {
      return(private$reordered_plot)
    }
  )
) 