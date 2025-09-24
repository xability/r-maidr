#' Abstract Layer Processor Interface
#'
#' This is the abstract base class for all layer processors. It defines the
#' interface that all layer processors must implement.
#'
#' @field layer_info Information about the layer
#' @keywords internal
LayerProcessor <- R6::R6Class("LayerProcessor",
  private = list(
    .last_result = NULL
  ),
  public = list(
    #' @field layer_info Information about the layer
    layer_info = NULL,

    #' @description Initialize the layer processor
    #' @param layer_info Information about the layer
    initialize = function(layer_info) {
      self$layer_info <- layer_info
    },

    #' @description Process the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @return List with data and selectors
    process = function(plot, layout, built = NULL, gt = NULL) {
      stop("process() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Extract data from the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @return Extracted data
    extract_data = function(plot, built = NULL) {
      stop("extract_data() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Generate selectors for the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL) {
      stop("generate_selectors() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Check if this layer needs reordering (OPTIONAL - default: FALSE)
    #' @return Logical indicating if reordering is needed
    needs_reordering = function() {
      FALSE
    },

    #' @description Reorder layer data (OPTIONAL - default: no-op)
    #' @param data data.frame effective for this layer
    #' @param plot full ggplot object (for mappings)
    #' @return Reordered data
    reorder_layer_data = function(data, plot) {
      data
    },

    #' @description Get layer index
    #' @return Layer index
    get_layer_index = function() {
      self$layer_info$index
    },

    #' @description Store the last processed result (used by orchestrator)
    #' @param result The result to store
    set_last_result = function(result) {
      private$.last_result <- result
      invisible(result)
    },

    #' @description Get the last processed result
    #' @return The last result
    get_last_result = function() {
      private$.last_result
    }
  )
)
