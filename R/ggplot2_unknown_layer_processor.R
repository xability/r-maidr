#' Unknown Layer Processor
#'
#' Handles unsupported layer types gracefully by returning empty data
#'
#' @keywords internal
Ggplot2UnknownLayerProcessor <- R6::R6Class(
  "Ggplot2UnknownLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, gt = NULL) {
      list(
        data = list(),
        selectors = list()
      )
    },
    extract_data = function(plot, built = NULL) {
      list()
    },
    generate_selectors = function(plot, gt = NULL) {
      list()
    }
  )
)
