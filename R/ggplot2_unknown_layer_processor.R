#' Unknown Layer Processor
#'
#' Handles unsupported layer types gracefully by returning empty data
#'
#' @keywords internal
Ggplot2UnknownLayerProcessor <- R6::R6Class(
  "Ggplot2UnknownLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Describe a layer nothing is known about
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List with no data and no selectors
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      list(
        data = list(),
        selectors = list(),
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout)
      )
    },
    #' @description Nothing: an unknown layer has no data to announce
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @return Empty list
    extract_data = function(plot, built = NULL) {
      list()
    },
    #' @description Nothing: an unknown layer has no elements to address
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return Empty list
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      list()
    }
  )
)
