#' Whether an object is a ComplexHeatmap heat map maidr reads
#'
#' A `Heatmap` or a `HeatmapList`, the S4 classes of the 'ComplexHeatmap'
#' package, told apart from any other package's class of the same name by
#' the package the class belongs to. Neither 'ComplexHeatmap' nor its
#' namespace is needed to ask.
#'
#' @param x Any object
#' @return TRUE for a `ComplexHeatmap::Heatmap` or `HeatmapList`
#' @keywords internal
is_complexheatmap <- function(x) {
  isS4(x) && inherits(x, c("Heatmap", "HeatmapList")) &&
    identical(attr(class(x), "package"), "ComplexHeatmap")
}

#' ComplexHeatmap System Adapter
#'
#' @description
#' Adapter for heat maps drawn by the Bioconductor package 'ComplexHeatmap'.
#' It claims a `Heatmap` -- what `ComplexHeatmap::Heatmap()` returns -- and
#' a `HeatmapList`, what `draw()` returns or `+` builds, and reads it with
#' [ComplexHeatmapPlotOrchestrator]. 'ComplexHeatmap' is only suggested; it
#' is loaded when such an object is read, which it must have been for the
#' object to exist.
#'
#' @format An R6 class inheriting from SystemAdapter
#' @keywords internal
ComplexHeatmapAdapter <- R6::R6Class(
  "ComplexHeatmapAdapter",
  inherit = SystemAdapter,
  public = list(
    #' @description Initialize the ComplexHeatmap adapter
    initialize = function() {
      super$initialize("complexheatmap")
    },

    #' @description Check if this adapter can handle a plot object
    #' @param plot_object The plot object to check
    #' @return TRUE for a ComplexHeatmap `Heatmap` or `HeatmapList`
    can_handle = function(plot_object) {
      is_complexheatmap(plot_object)
    },

    #' @description Create an orchestrator for a ComplexHeatmap object
    #' @param plot_object The `Heatmap` or `HeatmapList`
    #' @param width,height The size to draw the chart at, in inches, or `NULL`
    #'   for maidr's own; see [chart_canvas_size()]
    #' @param asked Whether that size was asked for, by default when either
    #'   side is given; see [chart_canvas_size()]
    #' @return ComplexHeatmapPlotOrchestrator instance
    create_orchestrator = function(plot_object, width = NULL, height = NULL,
                                   asked = !is.null(width) || !is.null(height)) {
      if (!self$can_handle(plot_object)) {
        stop("Plot object is not a ComplexHeatmap Heatmap or HeatmapList")
      }
      ComplexHeatmapPlotOrchestrator$new(plot_object, width = width, height = height, asked = asked)
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "complexheatmap"
    }
  )
)

#' ComplexHeatmap Processor Factory
#'
#' @description
#' Each heat map of a ComplexHeatmap chart draws one matrix, read as one
#' `heat` layer.
#'
#' @format An R6 class inheriting from ProcessorFactory
#' @keywords internal
ComplexHeatmapProcessorFactory <- R6::R6Class(
  "ComplexHeatmapProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    #' @description Create the processor for a layer type
    #' @param plot_type The layer type; only `"heat"` is read
    #' @param plot_object The layer information
    #' @return A ComplexHeatmapLayerProcessor
    create_processor = function(plot_type, plot_object) {
      if (!identical(plot_type, "heat")) {
        stop("ComplexHeatmap charts are read as one heat layer, not '", plot_type, "'")
      }
      ComplexHeatmapLayerProcessor$new(plot_object)
    },

    #' @description The layer types this factory creates processors for
    #' @return Character vector
    get_supported_types = function() {
      "heat"
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "complexheatmap"
    }
  )
)

#' ComplexHeatmap System Initialization
#'
#' Register the ComplexHeatmap system with the global registry. The adapter
#' claims objects by their class alone, so it must come before Base R, whose
#' adapter claims by device state.
#'
#' @keywords internal
#' @return NULL (invisible)
initialize_complexheatmap_system <- function() {
  registry <- get_global_registry()
  if (registry$is_system_registered("complexheatmap")) {
    return(invisible(NULL))
  }
  registry$register_system(
    "complexheatmap", ComplexHeatmapAdapter$new(), ComplexHeatmapProcessorFactory$new()
  )
  invisible(NULL)
}
