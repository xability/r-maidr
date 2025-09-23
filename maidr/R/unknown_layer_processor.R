#' Unknown Layer Processor
#'
#' Handles unsupported layer types gracefully by returning empty data
#'
#' @export
UnknownLayerProcessor <- R6::R6Class("UnknownLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, gt = NULL) {
      # Return empty data for unknown layer types
      list(
        data = list(),
        selectors = list()
      )
    },
    extract_data_impl = function(plot) {
      # Return empty data for unknown layer types
      list()
    },
    generate_selectors = function(plot, gt = NULL) {
      # Return empty selectors for unknown layer types
      list()
    }
  )
)
