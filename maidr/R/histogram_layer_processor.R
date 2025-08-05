#' Histogram Layer Processor
#' 
#' Processes histogram plot layers with complete logic included
#' 
#' @export
HistogramLayerProcessor <- R6::R6Class("HistogramLayerProcessor",
  inherit = LayerProcessor,
  
  public = list(
    process = function(plot, layout, gt = NULL) {
      data <- self$extract_data(plot)
      selectors <- self$generate_selectors(plot, gt)
      
      return(list(
        data = data,
        selectors = selectors
      ))
    },
    
    #' Extract data implementation
    extract_data_impl = function(plot) {
      built <- ggplot_build(plot)
      histogram_data <- list()
      
      for (i in seq_along(built$data)) {
        layer_data <- built$data[[i]]
        
        # Check if this layer has histogram data (rectangular bars with xmin/xmax)
        if (all(c("x", "y", "xmin", "xmax", "ymin", "ymax") %in% names(layer_data))) {
          # This is a histogram layer
          for (j in seq_len(nrow(layer_data))) {
            point <- list(
              x = layer_data$x[j],
              y = layer_data$y[j],
              xMin = layer_data$xmin[j],
              xMax = layer_data$xmax[j],
              yMin = layer_data$ymin[j],
              yMax = layer_data$ymax[j]
            )
            histogram_data[[length(histogram_data) + 1]] <- point
          }
        }
      }
      
      return(histogram_data)
    },
    
    generate_selectors = function(plot, gt = NULL) {
      # Convert to gtable to get grob information if not provided
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }
    
      # Find bar grobs using the same logic as original bar.R
      grobs <- self$find_bar_grobs(gt)
    
      # For histogram plots, we expect only one grob
      if (length(grobs) == 0) {
        return("")
      }
    
      # Use the first (and only) grob
      grob <- grobs[[1]]
      grob_name <- grob$name
      
      # Extract the numeric part from grob name
      # (e.g., "207.1" from "geom_rect.rect.207.1")
      layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
      
      # Create selector for this histogram
      selector <- self$make_bar_selector(layer_id)
      
      return(selector)
    },
    
    #' Make bar selector (same as original bar.R)
    make_bar_selector = function(layer_id) {
      grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
      paste0("#", escaped_grob_id, " rect")
    },
    
    #' Find bar grobs from a gtable (same as original bar.R)
    find_bar_grobs = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        stop("No panel found in gtable")
      }
    
      panel_grob <- gt$grobs[[panel_index]]
    
      if (!inherits(panel_grob, "gTree")) {
        stop("Panel grob is not a gTree")
      }
    
      find_geom_rect_grobs_recursive <- function(grob) {
        rect_grobs <- list()
    
        # Look specifically for geom_rect.rect grobs
        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          rect_grobs[[length(rect_grobs) + 1]] <- grob
        }
    
        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs_recursive(grob[[i]]))
          }
        }
    
        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs_recursive(grob$children[[i]]))
          }
        }
    
        return(rect_grobs)
      }
    
      bar_grobs <- find_geom_rect_grobs_recursive(panel_grob)
      
      # Prioritize the most specific grob (with .1 suffix)
      if (length(bar_grobs) > 0) {
        # Sort by name length (longer names are more specific)
        grob_names <- sapply(bar_grobs, function(g) g$name)
        bar_grobs <- bar_grobs[order(nchar(grob_names), decreasing = TRUE)]
      }
      
      return(bar_grobs)
    }
  )
) 