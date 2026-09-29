#' lattice Processor Factory
#'
#' @description
#' Factory for the processors that read the layers of a lattice panel. The
#' layer types are the ones the lattice adapter detects from the grobs a
#' panel function draws (`LatticeAdapter$detect_panel_layers()`).
#'
#' @format An R6 class inheriting from ProcessorFactory
#' @keywords internal
LatticeProcessorFactory <- R6::R6Class(
  "LatticeProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    #' @description Initialize the lattice processor factory
    initialize = function() {
      # No additional initialization needed
    },

    #' @description Create a processor for a specific layer type
    #' @param plot_type The layer type (e.g., "bar", "line", "point")
    #' @param layer_info Information about the layer: its type, role and the
    #'   grobs it is read from
    #' @return Processor instance for the specified layer type
    create_processor = function(plot_type, layer_info) {
      if (is.null(layer_info)) {
        stop("Layer info must be provided")
      }

      switch(plot_type,
        "point" = LatticePointLayerProcessor$new(layer_info),
        # A Cleveland dot plot reads as bars with a different mark.
        "dot" = LatticeDotLayerProcessor$new(layer_info),
        # `type = "h"` spikes stand side by side rather than in a series.
        "lollipop" = LatticeLollipopLayerProcessor$new(layer_info),
        # A staircase is drawn by the same grob as a line, as a line is read.
        "line" = LatticeLineLayerProcessor$new(layer_info),
        "step" = LatticeLineLayerProcessor$new(layer_info),
        "smooth" = LatticeSmoothLayerProcessor$new(layer_info),
        # Grouped bars are the same marks read as a grid; one processor
        # decides the type from the panel's `groups` and `stack`.
        "bar" = LatticeBarLayerProcessor$new(layer_info),
        "dodged_bar" = LatticeBarLayerProcessor$new(layer_info),
        "stacked_bar" = LatticeBarLayerProcessor$new(layer_info),
        "hist" = LatticeHistogramLayerProcessor$new(layer_info),
        "box" = LatticeBoxLayerProcessor$new(layer_info),
        "heat" = LatticeHeatmapLayerProcessor$new(layer_info),
        "contour" = LatticeContourLayerProcessor$new(layer_info),
        LatticeUnknownLayerProcessor$new(layer_info)
      )
    },

    #' @description Get list of supported layer types
    #' @return Character vector of supported layer types
    get_supported_types = function() {
      c(
        "point",
        "dot",
        "lollipop",
        "line",
        "step",
        "smooth",
        "bar",
        "dodged_bar",
        "stacked_bar",
        "hist",
        "box",
        "heat",
        "contour",
        "unknown"
      )
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "lattice"
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
      classes <- dispatched_processor_classes(LatticeProcessorFactory, "Lattice")
      Filter(self$is_processor_available, classes)
    }
  )
)
