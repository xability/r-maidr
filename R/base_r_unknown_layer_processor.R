#' Base R Unknown Layer Processor
#'
#' Processes unknown Base R layer types as a fallback
#'
#' @keywords internal
BaseRUnknownLayerProcessor <- R6::R6Class(
  "BaseRUnknownLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info)
      list(
        data = data,
        selectors = selectors,
        type = "unknown",
        title = "Unknown Plot Type",
        # Nothing is known about this layer, its axes included. Emitting the
        # generic "X"/"Y" here would only duplicate the renderer's own
        # fallback, and would do it from the side that cannot tell whether
        # something better exists.
        axes = build_axes()
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
