#' Base R Processor Factory
#'
#' @description
#' Factory for creating Base R-specific processors. This factory creates
#' processors for Base R plot types based on recorded plot calls.
#'
#' @format An R6 class inheriting from ProcessorFactory
#' @keywords internal

BaseRProcessorFactory <- R6::R6Class(
  "BaseRProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    #' @description Initialize the Base R processor factory
    initialize = function() {
      # No additional initialization needed
    },

    #' @description Create a processor for a specific plot type
    #' @param plot_type The type of plot (e.g., "bar", "line", "point")
    #' @param layer_info Information about the layer (contains plot call and metadata)
    #' @return Processor instance for the specified plot type
    create_processor = function(plot_type, layer_info) {
      if (is.null(layer_info)) {
        stop("Layer info must be provided")
      }

      # Map plot types to Base R processor classes
      switch(plot_type,
        "bar" = BaseRBarplotLayerProcessor$new(layer_info),
        "dodged_bar" = BaseRDodgedBarLayerProcessor$new(layer_info),
        "stacked_bar" = BaseRStackedBarLayerProcessor$new(layer_info),
        # Same extraction as a plain stack: base R has no normalisation
        # argument, so the values already are the drawn shares.
        "stacked_normalized_bar" = BaseRStackedBarLayerProcessor$new(layer_info),
        "smooth" = BaseRSmoothLayerProcessor$new(layer_info),
        "line" = BaseRLineLayerProcessor$new(layer_info),
        "step" = BaseRStepLayerProcessor$new(layer_info),
        "point" = BaseRPointLayerProcessor$new(layer_info),
        "hist" = BaseRHistogramLayerProcessor$new(layer_info),
        "box" = BaseRBoxplotLayerProcessor$new(layer_info),
        "violin" = BaseRViolinLayerProcessor$new(layer_info),
        "pie" = BaseRPieLayerProcessor$new(layer_info),
        "heat" = BaseRHeatmapLayerProcessor$new(layer_info),
        "candlestick" = BaseRCandlestickLayerProcessor$new(layer_info),
        # For unknown types, use the generic processor
        BaseRUnknownLayerProcessor$new(layer_info)
      )
    },

    #' @description Get list of supported plot types
    #' @return Character vector of supported plot types
    get_supported_types = function() {
      c(
        # Plot types supported by Base R system
        "bar",
        "dodged_bar",
        "stacked_bar",
        "stacked_normalized_bar",
        "smooth",
        "line",
        "step",
        "point",
        "hist",
        "box",
        "pie",
        "heat",
        # `contour` is deliberately absent. `base_r_adapter` maps the call to
        # that type and the factory had no processor for it, so the layer was
        # emitted typed "unknown" -- and because the type was listed here, the
        # unsupported-elements fallback that saves `dotchart` never ran. The
        # core's factory ends its dispatch with
        # `throw new Error("Invalid trace type: " + layer.type)`, so the figure
        # never bound: an interactive shell answering no key, and no picture
        # either. A static image with a warning is worse than reading the
        # chart and better than both of those (#214).
        #
        # Reading it properly is still open. `contour` *is* a trace type --
        # the ggplot2 side emits it for `geom_contour` (#198) -- and base R's
        # `contour()` hands over the same `x`, `y`, `z` and `levels`. Adding
        # the processor is what puts the type back on this list.
        "candlestick",
        "unknown"
      )
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "base_r"
    },

    #' @description Check if a specific processor class is available
    #' @param processor_class_name Name of the processor class
    #' @return TRUE if available, FALSE otherwise
    is_processor_available = function(processor_class_name) {
      processor_class_exists(processor_class_name)
    },

    #' @description Get available processor classes
    #'
    #' Enumerated from `create_processor()` rather than listed here, so the
    #' answer cannot drift away from what the factory actually dispatches to
    #' (#200).
    #'
    #' @return Character vector of available processor class names
    get_available_processors = function() {
      classes <- dispatched_processor_classes(BaseRProcessorFactory, "BaseR")
      Filter(self$is_processor_available, classes)
    },

    #' @description Create a processor with error handling
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
