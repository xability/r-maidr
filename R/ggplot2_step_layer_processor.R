#' ggplot2 Step Layer Processor
#'
#' Processes `geom_step()` layers. A step chart is piecewise constant: the
#' value is held across an interval and then jumps, rather than being
#' interpolated between samples the way a line implies. The canonical case is
#' a hypnogram -- an ordinal sleep stage (Awake / REM / N1 / N2 / N3) against
#' time.
#'
#' Everything about extracting x/y and locating the rendered polyline is the
#' same as for a line, so this class inherits `Ggplot2LineLayerProcessor` and
#' adds only what a step layer has that a line layer does not:
#'
#' \itemize{
#'   \item `stepDirection` -- the `hv` / `vh` / `mid` convention the layer was
#'     drawn with, emitted as a sibling of `axes` and `data` on the layer.
#'   \item a per-point `label` -- the *name* of the ordinal level, so the
#'     frontend announces "REM" rather than the numeric level code that
#'     encodes it. `y` stays numeric because it drives sonification, braille
#'     and the min/max range.
#' }
#'
#' One data point is emitted per data *sample*, never one per stairstep
#' vertex. `ggplot2` expands the stairsteps inside `GeomStep$draw_panel()`, so
#' the rendered polyline carries `2n - 1` vertices (`hv` / `vh`) or `2n`
#' (`mid`) for `n` samples; the MAIDR frontend's `StepTrace` maps those
#' vertices back onto the samples. Emitting vertex-level data to "match" the
#' polyline would double every level and misreport transitions and run
#' lengths.
#'
#' @keywords internal
Ggplot2StepLayerProcessor <- R6::R6Class(
  "Ggplot2StepLayerProcessor",
  inherit = Ggplot2LineLayerProcessor,
  public = list(
    #' @description Process the step layer.
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes, type and stepDirection
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      result <- super$process(
        plot, layout, built, gt, scale_mapping, grob_id, panel_id, panel_ctx
      )
      result$type <- "step"

      direction <- self$extract_step_direction(plot)
      if (!is.null(direction)) {
        result$stepDirection <- direction
      }

      result
    },

    #' @description Read the step convention this layer was drawn with.
    #'
    #' `geom_step(direction = )` is a formal of `GeomStep$draw_panel()`, so
    #' ggplot2 files it under `layer$geom_params$direction` rather than
    #' `layer$aes_params` or the layer's mapping. The three accepted values
    #' (`"hv"`, `"vh"`, `"mid"`) are exactly MAIDR's, so they pass through
    #' unchanged. `"hv"` is both ggplot2's and MAIDR's default.
    #'
    #' @param plot The ggplot2 object
    #' @return One of "hv", "vh", "mid" (defaulting to "hv"), or NULL when the
    #'   layer cannot be located at all.
    extract_step_direction = function(plot) {
      layer <- self$get_layer(plot)
      if (is.null(layer)) {
        return(NULL)
      }

      direction <- layer$geom_params$direction
      if (is.null(direction) || length(direction) == 0) {
        return("hv")
      }

      direction <- as.character(direction)[1]
      if (!direction %in% c("hv", "vh", "mid")) {
        return("hv")
      }
      direction
    }
  )
)
