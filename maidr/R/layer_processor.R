#' Base Layer Processor Class
#' 
#' This is the base class for all layer processors. Each layer type
#' will have its own processor that inherits from this class.
#' 
#' @field layer_info Information about the layer
#' @export
LayerProcessor <- R6::R6Class("LayerProcessor",
  private = list(
    reordered_plot = NULL,
    last_result = NULL
  ),
  
  public = list(
    layer_info = NULL,
    
    initialize = function(layer_info) {
      self$layer_info <- layer_info
    },
    
    #' Process the layer (to be implemented by subclasses)
    process = function(plot, layout, gt = NULL) {
      stop("process() method must be implemented by subclasses")
    },
    
    #' Extract data from the layer (with optional reordering)
    extract_data = function(plot) {
      # Apply reordering if needed
      if (self$needs_reordering()) {
        plot <- self$apply_reordering(plot)
        # Store the reordered plot for later use
        private$reordered_plot <- plot
      }
      
      # Extract data using implementation method
      data <- self$extract_data_impl(plot)
      
      # Add layer information to each data point only for multi-layer plots
      # This is handled by the orchestrator when combining results
      return(data)
    },
    
    #' Extract data implementation (to be implemented by subclasses)
    extract_data_impl = function(plot) {
      stop("extract_data_impl() method must be implemented by subclasses")
    },
    
    #' Check if this layer needs reordering
    needs_reordering = function() {
      return(FALSE)  # Default: no reordering needed
    },
    
    #' Apply reordering to plot (to be implemented by subclasses if needed)
    apply_reordering = function(plot) {
      return(plot)  # Default: no reordering
    },
    
    #' Generate selectors for the layer
    generate_selectors = function(plot, gt = NULL) {
      stop("generate_selectors() method must be implemented by subclasses")
    },
    
    #' Get layer type
    get_layer_type = function() {
      return(self$layer_info$type)
    },
    
    #' Get layer index
    get_layer_index = function() {
      return(self$layer_info$index)
    },
    
    #' Get reordered plot (if available)
    get_reordered_plot = function() {
      return(private$reordered_plot)
    },
    
    #' Store the last processed result
    set_last_result = function(result) {
      private$last_result <- result
    },
    
    #' Get the last processed result
    get_last_result = function() {
      return(private$last_result)
    }
  )
) 