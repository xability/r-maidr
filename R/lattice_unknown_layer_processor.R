#' lattice Unknown Layer Processor
#'
#' @description
#' The factory's answer for a layer type it has no processor for. It reads
#' nothing: a lattice layer that cannot be read makes the chart fall back to
#' an image, rather than be emitted as a layer the frontend has no reading
#' for.
#'
#' @keywords internal
LatticeUnknownLayerProcessor <- R6::R6Class(
  "LatticeUnknownLayerProcessor",
  inherit = LatticeLayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The trellis object
    #' @param layout The figure's layout: title and axis labels
    #' @param built Unused for lattice
    #' @param gt The drawn chart
    #' @param grob_id Unused for lattice
    #' @param panel_id Unused for lattice
    #' @param panel_ctx The panel the layer was drawn in
    #' @param layer_info The layer: its type, role and grobs
    #' @return NULL: the layer cannot be read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      NULL
    }
  )
)
