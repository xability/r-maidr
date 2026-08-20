#' ggplot2 Processor Factory
#'
#' @description
#' Factory for creating ggplot2-specific processors. This factory uses the existing
#' ggplot2 layer processors and wraps them in the new unified interface.
#'
#' @format An R6 class inheriting from ProcessorFactory
#' @keywords internal

Ggplot2ProcessorFactory <- R6::R6Class(
  "Ggplot2ProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    #' @description Initialize the ggplot2 processor factory
    initialize = function() {
      # No additional initialization needed
    },

    #' @description Create a processor for a specific plot type
    #' @param plot_type The type of plot (e.g., "bar", "line", "point")
    #' @param layer_info Information about the layer (contains plot object and metadata)
    #' @return Processor instance for the specified plot type
    create_processor = function(plot_type, layer_info) {
      if (is.null(layer_info)) {
        stop("Layer info must be provided")
      }

      # Map plot types to existing processor classes
      # Only support the plot types that the adapter can detect
      switch(plot_type,
        "bar" = Ggplot2BarLayerProcessor$new(layer_info),
        "dodged_bar" = Ggplot2DodgedBarLayerProcessor$new(layer_info),
        "stacked_bar" = Ggplot2StackedBarProcessor$new(layer_info),
        # A filled bar is a stacked bar whose segments have been rescaled to
        # shares, so it is extracted by the same processor; only the emitted
        # type and the value it reads off the built data differ.
        "stacked_normalized_bar" = Ggplot2StackedBarProcessor$new(layer_info),
        "pie" = Ggplot2PieLayerProcessor$new(layer_info),
        "hist" = Ggplot2HistogramLayerProcessor$new(layer_info),
        # A stack of dots is a bar and the layer emits `hist`, but it reads
        # from different columns and has no per-bin element to highlight.
        "dotplot" = Ggplot2DotplotLayerProcessor$new(layer_info),
        "line" = Ggplot2LineLayerProcessor$new(layer_info),
        "area" = Ggplot2AreaLayerProcessor$new(layer_info),
        # The three area variants differ in how their bands relate, not in
        # where the numbers are read from, so one processor emits all three
        # and decides the type from the layer's position.
        "stacked_area" = Ggplot2AreaLayerProcessor$new(layer_info),
        "stacked_normalized_area" = Ggplot2AreaLayerProcessor$new(layer_info),
        "step" = Ggplot2StepLayerProcessor$new(layer_info),
        "smooth" = Ggplot2SmoothLayerProcessor$new(layer_info),
        # A field drawn as curves of constant value, the level being a
        # number on every row rather than a fill colour.
        "contour" = Ggplot2ContourLayerProcessor$new(layer_info),
        # A segment whose ends share a coordinate is an interval in a lane,
        # which is a schedule rather than a shape of its own.
        "gantt" = Ggplot2GanttLayerProcessor$new(layer_info),
        "heat" = Ggplot2HeatmapLayerProcessor$new(layer_info),
        # A hexbin is a lattice of counted cells like a heatmap, but its
        # rows are staggered, so it reads through a processor of its own.
        "hexbin" = Ggplot2HexbinLayerProcessor$new(layer_info),
        "point" = Ggplot2PointLayerProcessor$new(layer_info),
        "box" = Ggplot2BoxplotLayerProcessor$new(layer_info),
        "error_bar" = Ggplot2ErrorbarLayerProcessor$new(layer_info),
        "violin" = Ggplot2ViolinLayerProcessor$new(layer_info),
        "candlestick" = Ggplot2CandlestickProcessor$new(layer_info),
        # For unknown types, use the generic processor
        Ggplot2UnknownLayerProcessor$new(layer_info)
      )
    },

    #' @description Get list of supported plot types
    #' @return Character vector of supported plot types
    get_supported_types = function() {
      c(
        # Plot types supported by PlotOrchestrator
        "bar",
        "dodged_bar",
        "stacked_bar",
        "stacked_normalized_bar",
        "pie",
        "hist",
        "line",
        "area",
        "stacked_area",
        "stacked_normalized_area",
        "step",
        "smooth",
        "contour",
        "gantt",
        "heat",
        "hexbin",
        "point",
        "box",
        "error_bar",
        "violin",
        "candlestick",
        "unknown"
      )
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "ggplot2"
    },

    #' @description Check if a specific processor class is available
    #' @param processor_class_name Name of the processor class
    #' @return TRUE if available, FALSE otherwise
    is_processor_available = function(processor_class_name) {
      exists(processor_class_name, mode = "function")
    },

    #' @description Get available processor classes
    #' @return Character vector of available processor class names
    get_available_processors = function() {
      processor_classes <- c(
        "Ggplot2BarLayerProcessor",
        "Ggplot2DodgedBarLayerProcessor",
        "Ggplot2StackedBarProcessor",
        "Ggplot2PieLayerProcessor",
        "Ggplot2LineLayerProcessor",
        "Ggplot2AreaLayerProcessor",
        "Ggplot2StepLayerProcessor",
        "Ggplot2PointLayerProcessor",
        "Ggplot2HistogramLayerProcessor",
        "Ggplot2SmoothLayerProcessor",
        "Ggplot2BoxplotLayerProcessor",
        "Ggplot2ErrorbarLayerProcessor",
        "Ggplot2ViolinLayerProcessor",
        "Ggplot2CandlestickProcessor",
        "Ggplot2HeatmapLayerProcessor",
        "Ggplot2UnknownLayerProcessor"
      )

      available <- sapply(processor_classes, self$is_processor_available)
      names(available)[available]
    },

    #' @description Create a processor with error handling
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
