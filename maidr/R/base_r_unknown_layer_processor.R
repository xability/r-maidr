#' Base R Unknown Layer Processor
#'
#' Processes unknown Base R layer types as a fallback
#'
#' @keywords internal
BaseRUnknownLayerProcessor <- R6::R6Class("BaseRUnknownLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, scale_mapping = NULL, grob_id = NULL, panel_id = NULL, panel_ctx = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info)
      list(
        data = data,
        selectors = selectors,
        type = "unknown",
        title = "Unknown Plot Type",
        axes = list(x = "X", y = "Y")
      )
    },

    needs_reordering = function() {
      FALSE
    },

    extract_data = function(layer_info) {
      # For unknown plot types, return minimal data
      list()
    },

    generate_selectors = function(layer_info) {
      # For unknown plot types, return minimal selectors
      list()
    }
  )
)
