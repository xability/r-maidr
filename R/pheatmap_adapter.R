#' pheatmap System Adapter
#'
#' @description
#' Adapter for clustered heat maps drawn by the 'pheatmap' package. It claims
#' the object `pheatmap::pheatmap()` returns -- a list of class `"pheatmap"`
#' holding the row and column trees and the drawn `gtable` -- and reads it
#' with [PheatmapPlotOrchestrator]. 'pheatmap' itself is only suggested:
#' nothing here calls it, the object carries everything that is read.
#'
#' @format An R6 class inheriting from SystemAdapter
#' @keywords internal
PheatmapAdapter <- R6::R6Class(
  "PheatmapAdapter",
  inherit = SystemAdapter,
  public = list(
    #' @description Initialize the pheatmap adapter
    initialize = function() {
      super$initialize("pheatmap")
    },

    #' @description Check if this adapter can handle a plot object
    #' @param plot_object The plot object to check
    #' @return TRUE for the object `pheatmap::pheatmap()` returns
    can_handle = function(plot_object) {
      inherits(plot_object, "pheatmap") && inherits(plot_object$gtable, "gtable")
    },

    #' @description Create an orchestrator for a pheatmap object
    #' @param plot_object The pheatmap object
    #' @param width,height The size to draw the chart at, in inches, or `NULL`
    #'   for maidr's own; see [chart_canvas_size()]
    #' @param asked Whether that size was asked for, by default when either
    #'   side is given; see [chart_canvas_size()]
    #' @return PheatmapPlotOrchestrator instance
    create_orchestrator = function(plot_object, width = NULL, height = NULL,
                                   asked = !is.null(width) || !is.null(height)) {
      if (!self$can_handle(plot_object)) {
        stop("Plot object is not the result of pheatmap::pheatmap()")
      }
      PheatmapPlotOrchestrator$new(plot_object, width = width, height = height, asked = asked)
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "pheatmap"
    }
  )
)

#' pheatmap Processor Factory
#'
#' @description
#' A pheatmap draws one matrix, read as one `heat` layer, a dendrogram on
#' each clustered side, each read as a `tree` layer, and its annotation
#' tracks, each read as a `heat` or `step` layer beside the matrix's.
#'
#' @format An R6 class inheriting from ProcessorFactory
#' @keywords internal
PheatmapProcessorFactory <- R6::R6Class(
  "PheatmapProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    #' @description Create the processor for a layer type
    #' @param plot_type The layer type, `"heat"` or `"tree"`, or
    #'   `"annotation"` for an annotation track, read as a `heat` or `step`
    #'   layer
    #' @param plot_object The layer information; a tree's names its `side`
    #' @return A PheatmapHeatmapLayerProcessor, PheatmapTreeLayerProcessor or
    #'   PheatmapAnnotationLayerProcessor
    create_processor = function(plot_type, plot_object) {
      switch(plot_type,
        heat = PheatmapHeatmapLayerProcessor$new(plot_object),
        tree = PheatmapTreeLayerProcessor$new(plot_object),
        annotation = PheatmapAnnotationLayerProcessor$new(plot_object),
        stop("pheatmap charts are read as heat and tree layers, not '", plot_type, "'")
      )
    },

    #' @description The layer types this factory creates processors for
    #' @return Character vector
    get_supported_types = function() {
      c("heat", "tree")
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "pheatmap"
    }
  )
)

#' pheatmap System Initialization
#'
#' Register the pheatmap system with the global registry. The adapter claims
#' objects by their class alone, so where it is registered among the others
#' does not matter, except that it must come before Base R, whose adapter
#' claims by device state.
#'
#' @keywords internal
#' @return NULL (invisible)
initialize_pheatmap_system <- function() {
  registry <- get_global_registry()
  if (registry$is_system_registered("pheatmap")) {
    return(invisible(NULL))
  }
  registry$register_system("pheatmap", PheatmapAdapter$new(), PheatmapProcessorFactory$new())
  invisible(NULL)
}
