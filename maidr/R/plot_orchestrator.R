#' Plot Orchestrator Class
#' 
#' This class orchestrates the detection and processing of multiple layers
#' in a ggplot2 object. It analyzes each layer individually and combines
#' the results into a comprehensive interactive plot.
#' 
#' @field plot The ggplot2 object being processed
#' @field layers List of detected layer information
#' @field layer_processors List of layer-specific processors
#' @field combined_data Combined data from all layers
#' @field combined_selectors Combined selectors from all layers
#' @field layout Layout information from the plot
#' 
#' @export
PlotOrchestrator <- R6::R6Class("PlotOrchestrator",
  private = list(
    # Private fields
    .plot = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .combined_selectors = list(),
    .layout = NULL,
    .gtable = NULL
  ),
  
  public = list(
    # Constructor
    initialize = function(plot) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object")
      }
      private$.plot <- plot
      self$detect_layers()
      self$create_layer_processors()
      self$process_layers()
    },
    
    # =======================================================================
    # LAYER DETECTION METHODS
    # =======================================================================
    
    #' Detect all layers in the plot
    detect_layers = function() {
      cat("Detecting layers...\n")
      
      layers <- private$.plot$layers
      private$.layers <- list()
      
      for (i in seq_along(layers)) {
        layer_info <- self$analyze_single_layer(layers[[i]], i)
        private$.layers[[i]] <- layer_info
        cat("Layer", i, "detected as:", layer_info$type, "\n")
      }
      
      cat("Total layers detected:", length(private$.layers), "\n")
    },
    
    #' Analyze a single layer
    analyze_single_layer = function(layer, layer_index) {
      # Extract layer components
      geom <- layer$geom
      stat <- layer$stat
      position <- layer$position
      mapping <- layer$mapping
      params <- layer$params
      
      # Get class information
      geom_class <- class(geom)[1]
      stat_class <- class(stat)[1]
      position_class <- class(position)[1]
      
      # Detect initial layer type
      layer_type <- self$detect_layer_type(geom_class, stat_class, position_class)
      
      # Refine layer type based on actual characteristics
      layer_type <- self$refine_layer_type(layer_type, layer, mapping)
      
      # Create layer information
      layer_info <- list(
        index = layer_index,
        type = layer_type,
        geom_class = geom_class,
        stat_class = stat_class,
        position_class = position_class,
        aesthetics = if (!is.null(mapping)) names(mapping) else character(0),
        parameters = names(params),
        layer_object = layer
      )
      
      return(layer_info)
    },
    
    #' Detect individual layer type (simplified for existing plot types)
    detect_layer_type = function(geom_class, stat_class, position_class) {
      # Bar-related layers
      if (geom_class %in% c("GeomBar", "GeomCol")) {
        if (stat_class == "StatBin") {
          return("hist")
        } else if (position_class == "PositionDodge") {
          return("dodged_bar")
        } else if (position_class == "PositionStack") {
          return("stacked_bar")
        } else {
          return("bar")
        }
      }
      
      # Smooth-related layers
      if (geom_class == "GeomSmooth" || stat_class == "StatDensity") {
        return("smooth")
      }
      
      # Default - unknown layer type
      return("unknown")
    },
    
    #' Refine layer type based on actual layer characteristics
    refine_layer_type = function(layer_type, layer, mapping) {
      # For stacked bars, check if it's actually a simple bar
      if (layer_type == "stacked_bar") {
        # Check if this is a simple bar (no fill aesthetic or single fill value)
        # Check both layer mapping and plot's global mapping
        has_fill_layer <- !is.null(mapping$fill)
        has_fill_plot <- !is.null(private$.plot$mapping$fill)
        
        if (!has_fill_layer && !has_fill_plot) {
          # No fill aesthetic - this is a simple bar
          return("bar")
        }
        
        # Has fill aesthetic - this is a true stacked bar
        return("stacked_bar")
      }
      
      return(layer_type)
    },
    
    # =======================================================================
    # LAYER PROCESSOR CREATION
    # =======================================================================
    
    #' Create layer-specific processors
    create_layer_processors = function() {
      cat("Creating layer processors...\n")
      
      private$.layer_processors <- list()
      
      for (i in seq_along(private$.layers)) {
        layer_info <- private$.layers[[i]]
        processor <- self$create_layer_processor(layer_info)
        private$.layer_processors[[i]] <- processor
        cat("Created processor for layer", i, "(", layer_info$type, ")\n")
      }
    },
    
    #' Create a layer-specific processor
    create_layer_processor = function(layer_info) {
      layer_type <- layer_info$type
      
      # Create processor based on layer type (only existing types)
      processor <- switch(layer_type,
        "bar" = BarLayerProcessor$new(layer_info),
        "stacked_bar" = StackedBarLayerProcessor$new(layer_info),
        "dodged_bar" = DodgedBarLayerProcessor$new(layer_info),
        "hist" = HistogramLayerProcessor$new(layer_info),
        "smooth" = SmoothLayerProcessor$new(layer_info),
        UnknownLayerProcessor$new(layer_info)  # Default for unknown types
      )
      
      return(processor)
    },
    
    # =======================================================================
    # LAYER PROCESSING
    # =======================================================================
    
    #' Process all layers
    process_layers = function() {
      cat("Processing layers...\n")
      
      # Extract layout information
      private$.layout <- self$extract_layout()
      
      # Build the plot once to get consistent data
      built_plot <- ggplot2::ggplot_build(private$.plot)
      
      # Process each layer first to get any reordered plots
      layer_results <- list()
      reordered_plots <- list()
      
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        layer_info <- private$.layers[[i]]
        
        cat("Processing layer", i, "(", layer_info$type, ")\n")
        
        # Process the layer with built data
        result <- processor$process(private$.plot, private$.layout, NULL)
        
        # Store the result in the processor for later retrieval
        processor$set_last_result(result)
        
        layer_results[[i]] <- result
        
        # Check if this processor has a reordered plot
        if (!is.null(processor$get_reordered_plot())) {
          reordered_plots[[i]] <- processor$get_reordered_plot()
        }
      }
      
      # Use reordered plot for gtable if any layer has reordering
      plot_for_gtable <- private$.plot
      if (length(reordered_plots) > 0) {
        # Use the first reordered plot (assuming single layer for now)
        plot_for_gtable <- reordered_plots[[1]]
      }
      
      gt_plot <- ggplot2::ggplotGrob(plot_for_gtable)
      
      # Store the gtable for later use
      private$.gtable <- gt_plot
      
      # Re-process layers with the correct gtable
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        
        # Re-generate selectors with the correct gtable
        if (!is.null(processor$get_last_result())) {
          result <- processor$get_last_result()
          result$selectors <- processor$generate_selectors(plot_for_gtable, gt_plot)
          processor$set_last_result(result)
        }
      }
      
      # Combine results
      self$combine_layer_results(layer_results)
    },
    
    #' Extract layout information
    extract_layout = function() {
      # Build the plot to get actual axis labels
      built <- ggplot2::ggplot_build(private$.plot)
      
      # Extract title, axes labels, etc.
      layout <- list(
        title = if (!is.null(private$.plot$labels$title)) private$.plot$labels$title else "",
        axes = list(
          x = if (!is.null(private$.plot$labels$x)) private$.plot$labels$x else "",
          y = if (!is.null(private$.plot$labels$y)) private$.plot$labels$y else ""
        )
      )
      
      return(layout)
    },
    
    #' Combine results from all layers
    combine_layer_results = function(layer_results) {
      cat("Combining layer results...\n")
      
      # Combine data
      combined_data <- list()
      for (i in seq_along(layer_results)) {
        result <- layer_results[[i]]
        
        # Add layer information to data points for consistent grouping
        # Each layer processor is responsible for its own data structure
        if (length(result$data) > 0) {
          result$data <- self$add_layer_info_to_data(result$data, i, private$.layers[[i]]$type)
        }
        
        combined_data <- c(combined_data, result$data)
      }
      
      # Combine selectors
      combined_selectors <- list()
      for (result in layer_results) {
        combined_selectors <- c(combined_selectors, result$selectors)
      }
      
      # Store combined results
      private$.combined_data <- combined_data
      private$.combined_selectors <- combined_selectors
      
      cat("Combined", length(combined_data), "data points and", 
          length(combined_selectors), "selectors\n")
    },
    
    # =======================================================================
    # OUTPUT GENERATION
    # =======================================================================
    
    #' Generate final maidr data structure
    generate_maidr_data = function() {
      # Create the final data structure
      maidr_data <- list(
        id = paste0("maidr-plot-", as.integer(Sys.time())),
        subplots = list(
          list(
            list(
              id = paste0("maidr-subplot-", as.integer(Sys.time())),
              layers = private$.combined_data
            )
          )
        )
      )
      
      return(maidr_data)
    },
    
    #' Get reordered plots from layer processors
    get_reordered_plots = function() {
      reordered_plots <- list()
      
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        reordered_plot <- processor$get_reordered_plot()
        
        if (!is.null(reordered_plot)) {
          reordered_plots[[i]] <- reordered_plot
        }
      }
      
      return(reordered_plots)
    },
    
    #' Get the gtable (for consistent layer IDs)
    get_gtable = function() {
      return(private$.gtable)
    },
    
    #' Get combined selectors
    get_selectors = function() {
      return(private$.combined_selectors)
    },
    
    #' Get layout information
    get_layout = function() {
      return(private$.layout)
    },
    
    #' Get layer information
    get_layers = function() {
      return(private$.layers)
    },
    
    #' Get combined data
    get_combined_data = function() {
      return(private$.combined_data)
    },
    
    #' Get the original plot
    get_plot = function() {
      return(private$.plot)
    },
    
    #' Get layer processors
    get_layer_processors = function() {
      return(private$.layer_processors)
    },
    
    #' Add layer information to data points
    add_layer_info_to_data = function(data, layer_index, layer_type) {
      # Recursively add layer info to all data points
      add_layer_info_recursive <- function(data) {
        if (is.list(data)) {
          # Only add layer info if this is a data point (has x, y, etc.)
          if (any(c("x", "y", "fill") %in% names(data))) {
            data$layer_index <- layer_index
            data$layer_type <- layer_type
          }
          
          # Recursively add layer info to nested structures
          for (i in seq_along(data)) {
            if (is.list(data[[i]])) {
              data[[i]] <- add_layer_info_recursive(data[[i]])
            }
          }
        }
        return(data)
      }
      
      return(add_layer_info_recursive(data))
    }
  )
) 