#' Base R Processor Factory
#'
#' Factory for creating Base R-specific processors. This factory creates
#' processors for Base R plot types based on recorded plot calls.
#'
#' @format An R6 class inheriting from ProcessorFactory
#' @keywords internal

BaseRProcessorFactory <- R6::R6Class("BaseRProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    #' Initialize the Base R processor factory
    initialize = function() {
      # No additional initialization needed
    },

    #' Create a processor for a specific plot type
    #' @param plot_type The type of plot (e.g., "bar", "line", "point")
    #' @param layer_info Information about the layer (contains plot call and metadata)
    #' @return Processor instance for the specified plot type
    create_processor = function(plot_type, layer_info) {
      # Validate that layer_info is provided
      if (is.null(layer_info)) {
        stop("Layer info must be provided")
      }

      # Map plot types to Base R processor classes
      switch(plot_type,
        "bar" = BaseRBarplotLayerProcessor$new(layer_info),
        "dodged_bar" = BaseRDodgedBarLayerProcessor$new(layer_info),
        "stacked_bar" = BaseRStackedBarLayerProcessor$new(layer_info),
        "line" = BaseRUnknownLayerProcessor$new(layer_info), # TODO: Implement line processor
        "hist" = BaseRUnknownLayerProcessor$new(layer_info), # TODO: Implement hist processor
        "box" = BaseRUnknownLayerProcessor$new(layer_info), # TODO: Implement box processor
        "heat" = BaseRUnknownLayerProcessor$new(layer_info), # TODO: Implement heat processor
        "contour" = BaseRUnknownLayerProcessor$new(layer_info), # TODO: Implement contour processor
        # For unknown types, use the generic processor
        BaseRUnknownLayerProcessor$new(layer_info)
      )
    },

    #' Get list of supported plot types
    #' @return Character vector of supported plot types
    get_supported_types = function() {
      c(
        # Plot types supported by Base R system
        "bar",
        "dodged_bar",
        "stacked_bar",
        "line",
        "hist",
        "box",
        "heat",
        "contour",
        "unknown"
      )
    },

    #' Get the system name
    #' @return System name string
    get_system_name = function() {
      "base_r"
    },

    #' Check if a specific processor class is available
    #' @param processor_class_name Name of the processor class
    #' @return TRUE if available, FALSE otherwise
    is_processor_available = function(processor_class_name) {
      exists(processor_class_name, mode = "function")
    },

    #' Get available processor classes
    #' @return Character vector of available processor class names
    get_available_processors = function() {
      processor_classes <- c(
        "BaseRBarplotLayerProcessor",
        "BaseRDodgedBarLayerProcessor",
        "BaseRStackedBarLayerProcessor",
        "BaseRUnknownLayerProcessor"
        # TODO: Add other processor classes as they are implemented
      )

      available <- sapply(processor_classes, self$is_processor_available)
      names(available)[available]
    },

    #' Create a processor with error handling
    #' @param plot_type The type of plot
    #' @param layer_info The layer information
    #' @return Processor instance or NULL if creation fails
    try_create_processor = function(plot_type, layer_info) {
      tryCatch(
        {
          self$create_processor(plot_type, layer_info)
        },
        error = function(e) {
          warning("Failed to create processor for plot type '", plot_type, "': ", e$message)
          # Fall back to unknown processor
          tryCatch(
            {
              BaseRUnknownLayerProcessor$new(layer_info)
            },
            error = function(e2) {
              warning("Failed to create unknown processor: ", e2$message)
              NULL
            }
          )
        }
      )
    }
  )
)
