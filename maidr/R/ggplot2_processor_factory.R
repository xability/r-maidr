#' ggplot2 Processor Factory
#'
#' Factory for creating ggplot2-specific processors. This factory uses the existing
#' ggplot2 layer processors and wraps them in the new unified interface.
#'
#' @format An R6 class inheriting from ProcessorFactory
#' @keywords internal

Ggplot2ProcessorFactory <- R6::R6Class("Ggplot2ProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    #' Initialize the ggplot2 processor factory
    initialize = function() {
      # No additional initialization needed
    },

    #' Create a processor for a specific plot type
    #' @param plot_type The type of plot (e.g., "bar", "line", "point")
    #' @param layer_info Information about the layer (contains plot object and metadata)
    #' @return Processor instance for the specified plot type
    create_processor = function(plot_type, layer_info) {
      # Validate that layer_info is provided
      if (is.null(layer_info)) {
        stop("Layer info must be provided")
      }

      # Map plot types to existing processor classes
      # Only support the plot types that the adapter can detect
      switch(plot_type,
        "bar" = Ggplot2BarLayerProcessor$new(layer_info),
        "dodged_bar" = Ggplot2DodgedBarLayerProcessor$new(layer_info),
        "stacked_bar" = Ggplot2StackedBarLayerProcessor$new(layer_info),
        "hist" = Ggplot2HistogramLayerProcessor$new(layer_info),
        "line" = Ggplot2LineLayerProcessor$new(layer_info),
        "smooth" = Ggplot2SmoothLayerProcessor$new(layer_info),
        "heat" = Ggplot2HeatmapLayerProcessor$new(layer_info),
        "point" = Ggplot2PointLayerProcessor$new(layer_info),
        "box" = Ggplot2BoxplotLayerProcessor$new(layer_info),
        # For unknown types, use the generic processor
        Ggplot2UnknownLayerProcessor$new(layer_info)
      )
    },

    #' Get list of supported plot types
    #' @return Character vector of supported plot types
    get_supported_types = function() {
      c(
        # Plot types supported by PlotOrchestrator
        "bar",
        "dodged_bar",
        "stacked_bar",
        "hist",
        "line",
        "smooth",
        "heat",
        "point",
        "box",
        "unknown"
      )
    },

    #' Get the system name
    #' @return System name string
    get_system_name = function() {
      "ggplot2"
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
        "Ggplot2BarLayerProcessor",
        "Ggplot2DodgedBarLayerProcessor",
        "Ggplot2StackedBarLayerProcessor",
        "Ggplot2LineLayerProcessor",
        "Ggplot2PointLayerProcessor",
        "Ggplot2HistogramLayerProcessor",
        "Ggplot2SmoothLayerProcessor",
        "Ggplot2BoxplotLayerProcessor",
        "Ggplot2HeatmapLayerProcessor",
        "Ggplot2UnknownLayerProcessor"
      )

      available <- sapply(processor_classes, self$is_processor_available)
      names(available)[available]
    },

    #' Create a processor with error handling
    #' @param plot_type The type of plot
    #' @param plot_object The plot object
    #' @return Processor instance or NULL if creation fails
    try_create_processor = function(plot_type, plot_object) {
      tryCatch(
        {
          self$create_processor(plot_type, plot_object)
        },
        error = function(e) {
          warning("Failed to create processor for plot type '", plot_type, "': ", e$message)
          # Fall back to unknown processor
          tryCatch(
            {
              Ggplot2UnknownLayerProcessor$new(plot_object)
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
