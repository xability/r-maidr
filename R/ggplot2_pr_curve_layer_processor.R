#' Precision-Recall Curve Layer Processor
#'
#' @description
#' Reads a precision-recall curve -- a classifier's precision against its
#' recall, one point per decision threshold, one curve per classifier -- as
#' the `pr_curve` trace.
#'
#' A ROC curve's reading with a different baseline, so the ROC processor does
#' the work it shares: the series split, the rates handed back as numbers,
#' the thresholds a `maidr_pr_curve()` layer's `threshold` aesthetic carries
#' through the build. A PR curve's `x` is never inverted -- recall is not
#' drawn on a reversed axis by any producer -- and its layer declares no
#' `auc`, so the ROC-only steps leave it unchanged. What this adds is what
#' the trace reads that a ROC curve does not: the share of positives each
#' curve was scored on, which is the height of its baseline, and the
#' average precision, both on the curve's first point.
#'
#' Emitted with `type = "pr_curve"`, which the core has read since maidr
#' 4.14.0.
#'
#' @keywords internal
Ggplot2PrCurveLayerProcessor <- R6::R6Class(
  "Ggplot2PrCurveLayerProcessor",
  inherit = Ggplot2RocLayerProcessor,
  public = list(
    #' @description Process the precision-recall layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes and type
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      result <- super$process(
        plot, layout, built, gt, grob_id, panel_id, panel_ctx
      )
      result$type <- "pr_curve"

      layer <- self$get_layer(plot)
      result$data <- self$attach_per_curve(
        result$data, tryCatch(layer$maidr_prevalence, error = function(e) NULL),
        "prevalence"
      )
      result$data <- self$attach_per_curve(
        result$data, tryCatch(layer$maidr_ap, error = function(e) NULL), "ap"
      )
      result
    },

    #' @description Attach a declared per-curve number to each curve's first
    #' point
    #'
    #' `maidr_pr_curve(prevalence = , ap = )` takes one number for every
    #' curve, a vector named by the groups' names, or an unnamed vector with
    #' one entry per curve in series order. Anything else is left out rather
    #' than guessed.
    #'
    #' @param data The series list
    #' @param values The declared numbers, or NULL
    #' @param key The name the core reads the number under
    #' @return The series list, with `key` on each curve's first point
    attach_per_curve = function(data, values, key) {
      if (!is.numeric(values) || length(values) == 0L || length(data) == 0L) {
        return(data)
      }

      names_of <- vapply(data, function(series) {
        z <- if (length(series) > 0L) series[[1]]$z else NULL
        if (is.null(z)) "" else as.character(z)
      }, character(1))

      matched <- if (!is.null(names(values)) && all(nzchar(names(values)))) {
        values[match(names_of, names(values))]
      } else if (length(values) == 1L) {
        rep(values, length(data))
      } else if (length(values) == length(data)) {
        unname(values)
      } else {
        rep(NA_real_, length(data))
      }

      for (i in seq_along(data)) {
        if (length(data[[i]]) > 0L && is.finite(matched[[i]])) {
          data[[i]][[1]][[key]] <- unname(matched[[i]])
        }
      }
      data
    }
  )
)

#' Whether a line layer maps the precision-recall vocabulary
#'
#' A precision-recall curve drawn as `geom_line()` or `geom_path()` carries
#' no evidence of what it means except its column names, and
#' `ggplot2::autoplot()` of a [yardstick::pr_curve()] names them after the
#' rates themselves: `recall` against `precision`. Those names are the
#' claim, as `specificity` and `sensitivity` are for a ROC curve
#' ([layer_maps_roc_rates()]).
#'
#' @param layer A ggplot2 layer
#' @param plot_object The plot the layer belongs to
#' @return TRUE when the layer's x is recall and its y precision
#' @keywords internal
layer_maps_pr_rates <- function(layer, plot_object) {
  rates <- roc_layer_rates(layer, plot_object)
  identical(rates$x, "recall") && identical(rates$y, "precision")
}
