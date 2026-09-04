#' Base R Unknown Layer Processor
#'
#' Processes unknown Base R layer types as a fallback
#'
#' @keywords internal
BaseRUnknownLayerProcessor <- R6::R6Class(
  "BaseRUnknownLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Describe a layer nothing is known about
    #' @param plot Unused; present for the processor interface
    #' @param layout Unused; present for the processor interface
    #' @param built Unused; present for the processor interface
    #' @param gt Gtable of the replayed drawing, searched for selectors (optional)
    #' @param grob_id Unused; present for the processor interface
    #' @param panel_id Unused; present for the processor interface
    #' @param panel_ctx Unused; present for the processor interface
    #' @param layer_info Layer information with the recorded call
    #' @return List with no data and no selectors
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
    #' @description Whether the plot data must be reordered before drawing; a Base R layer is read
    #'   from the recorded call and never is
    #' @return FALSE
    needs_reordering = function() {
      FALSE
    },
    #' @description Nothing: an unknown layer has no data to announce
    #' @param layer_info Layer information with the recorded call
    #' @return Empty list
    extract_data = function(layer_info) {
      # For unknown plot types, return minimal data
      list()
    },
    #' @description Nothing: an unknown layer has no elements to address
    #' @param layer_info Layer information with the recorded call
    #' @return Empty list
    generate_selectors = function(layer_info) {
      # For unknown plot types, return minimal selectors
      list()
    }
  )
)
