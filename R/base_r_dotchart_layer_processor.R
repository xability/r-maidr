#' Base R Dot Chart Layer Processor
#'
#' Processes Base R `dotchart()` layers -- a Cleveland dot plot: one value
#' per category, marked with a dot on a horizontal guide line, with the
#' categories running down the page.
#'
#' Read as a `dot` layer, which the core builds on `BarTrace`: a bar chart's
#' reading with a different mark. The guide lines and the category labels are
#' frame rather than data -- gridGraphics draws them as `-abline-h-` and
#' `-mtext-left-`, and only the dots carry a value.
#'
#' `orientation` is `"horz"`, which is not a detail: `dotchart()` puts the
#' categories on the vertical axis and the value along the horizontal one,
#' and the core reads a `horz` layer's magnitude from `x` and its category
#' from `y`. Without the key the layer defaults to vertical and reads the
#' category name where the magnitude belongs -- no number to pitch, and the
#' announcement inverted (#184, #480).
#'
#' The dots are emitted in the order `dotchart()` was handed them, which is
#' bottom-up on the drawn chart -- base R puts the first element at the
#' bottom. That is the arrangement `barplot(horiz = TRUE)` already ships for
#' the same reason, so the two horizontal base R charts read from the same
#' end.
#'
#' Selectors come from the points grob, which is the one thing a dotchart
#' shares with a scatter: `graphics-plot-N-points-1` holds one `<use>` per
#' dot. So this inherits `BaseRPointLayerProcessor` and replaces what is
#' read out of the call rather than how the marks are addressed.
#'
#' @keywords internal
BaseRDotchartLayerProcessor <- R6::R6Class(
  "BaseRDotchartLayerProcessor",
  inherit = BaseRPointLayerProcessor,
  public = list(
    #' @description Process the dot chart layer.
    #' @param plot Unused for Base R (kept for interface compatibility)
    #' @param layout Unused for Base R (kept for interface compatibility)
    #' @param built Unused for Base R (kept for interface compatibility)
    #' @param gt Gtable object used for selector generation (optional)
    #' @param grob_id Unused for Base R
    #' @param panel_id Unused for Base R
    #' @param panel_ctx Unused for Base R
    #' @param layer_info Information about the recorded plot call
    #' @return List with data, selectors, type, title, axes and orientation
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      list(
        data = self$extract_data(layer_info),
        selectors = self$generate_selectors(layer_info, gt),
        type = "dot",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info),
        orientation = "horz"
      )
    },

    #' @description Read the dots out of the recorded `dotchart()` call.
    #'
    #' `dotchart(x, labels = NULL, ...)` names its dots from `labels` when
    #' the caller gives them and from `names(x)` otherwise, which is what the
    #' chart draws down its left margin. A vector with neither is drawn
    #' against blank labels, and is emitted here against its positions so a
    #' reader still has something to navigate by.
    #'
    #' `x` and `y` carry the magnitude and the category respectively, which
    #' is the arrangement a `horz` layer means -- see the class note.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return List of `x`/`y` points, empty when there is nothing to read
    extract_data = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(list())
      }
      args <- layer_info$plot_call$args

      values <- args$x
      if (is.null(values)) {
        values <- if (length(args) >= 1) args[[1]] else NULL
      }
      if (is.null(values) || is.language(values) || !is.numeric(values)) {
        return(list())
      }

      labels <- args$labels
      if (is.null(labels)) {
        labels <- names(values)
      }
      if (is.null(labels) || length(labels) != length(values)) {
        labels <- as.character(seq_along(values))
      }

      lapply(seq_along(values), function(i) {
        list(x = as.numeric(values[i]), y = as.character(labels[i]))
      })
    }
  )
)
