#' Base R Step Plot Layer Processor
#'
#' Processes Base R stairstep layers -- `plot(x, y, type = "s")`,
#' `plot(x, y, type = "S")` and the `lines()` equivalents. A step chart is
#' piecewise constant: the value is held across an interval and then jumps,
#' rather than being interpolated between samples the way a line implies.
#'
#' Data extraction, axis titles, the main title and polyline selector
#' generation are identical to a line layer, so this class inherits
#' `BaseRLineLayerProcessor` and adds only the step-specific reporting: the
#' layer `type` and the `stepDirection` convention the call requested.
#'
#' One data point is emitted per data *sample*, never one per stairstep
#' vertex -- the MAIDR frontend maps the rendered polyline's corner vertices
#' back onto the samples itself.
#'
#' @keywords internal
BaseRStepLayerProcessor <- R6::R6Class(
  "BaseRStepLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Process the step layer.
    #' @param plot Unused for Base R (kept for interface compatibility)
    #' @param layout Unused for Base R (kept for interface compatibility)
    #' @param built Unused for Base R (kept for interface compatibility)
    #' @param gt Gtable object used for selector generation (optional)
    #' @param grob_id Unused for Base R
    #' @param panel_id Unused for Base R
    #' @param panel_ctx Unused for Base R
    #' @param layer_info Information about the recorded plot call
    #' @return List with data, selectors, type, title, axes and stepDirection
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      result <- list(
        data = self$extract_data(layer_info),
        selectors = self$generate_selectors(layer_info, gt),
        type = "step",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info)
      )

      direction <- self$extract_step_direction(layer_info)
      if (!is.null(direction)) {
        result$stepDirection <- direction
      }

      result
    },

    #' @description Read the step convention the recorded call requested.
    #'
    #' `type = "s"` draws the horizontal segment first (MAIDR's `"hv"`) and
    #' `type = "S"` draws the vertical segment first (`"vh"`). The two are not
    #' interchangeable, so an unrecognised or absent `type` yields NULL and
    #' the caller omits `stepDirection` rather than guessing.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return "hv", "vh", or NULL
    extract_step_direction = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      base_r_step_direction(layer_info$plot_call$args$type)
    },

    #' @description Draw a step layer's selectors from the stairstep grobs.
    #'
    #' gridGraphics names a grob after the `type` letter that drew it, so a
    #' stairstep lands under `graphics-plot-N-step-M` (`type = "s"`) or
    #' `graphics-plot-N-Step-M` (`type = "S"`) -- never under the `-lines-`
    #' name the inherited line search looks for. Without this override a Base
    #' R step layer emits zero selectors, and the frontend's
    #' `selectors.length === series count` precondition then drops the
    #' layer's highlighting entirely.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return "step"
    selector_grob_type = function(layer_info) {
      "step"
    }
  )
)
