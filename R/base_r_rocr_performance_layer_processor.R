#' Base R ROCR Performance Layer Processor
#'
#' @description
#' Reads `plot()` of a ROCR `performance` object -- most often
#' `plot(performance(pred, "prec", "rec"))`, a precision-recall curve -- from
#' the object itself.
#'
#' Why the object and not the drawing
#' ----------------------------------
#' ROCR's `plot` method draws with calls made from inside its own namespace:
#' `.performance.plot.canvas()` calls `plot()` with `type = "n"`, `axis()`
#' and `box()`, and `.performance.plot.no.avg()` draws each curve with
#' `plot.xy()` (ROCR 1.0.11). Those resolve through ROCR's imports of
#' graphics, never through the search path, so maidr's wrappers see none of
#' them; what is recorded is the one `plot(perf)` call the reader wrote. Its
#' `x.values` and `y.values` are the points the method draws, after it drops
#' the pairs that are not finite (`ROCR:::.plot.performance`), as this does
#' too; its `x.name` and `y.name` are the axis titles it draws unless
#' `xlab` and `ylab` are given.
#'
#' The reading
#' -----------
#' ROCR names the axes of `performance(pred, "prec", "rec")` "Recall" and
#' "Precision", so the curve is a precision-recall curve by its own titles
#' ([titled_pr_curve()]), as `plot(recall, precision, type = "l")` is, and is
#' emitted as a `pr_curve` layer whose points carry the cutoff each was
#' scored at, from `alpha.values`. ROCR scores its first point at an infinite
#' cutoff, which has no JSON number and is left out. Every other measure ROCR
#' plots against another -- a ROC curve's rates, accuracy against cutoff --
#' is a line, which is what it draws.
#'
#' One series per run: a `performance` object of several runs (from
#' cross-validation) draws one curve each, with `plot.xy()`, and gridGraphics
#' names each `graphics-plot-N-lines-M`, the polylines the line processor
#' finds -- so highlighting needs nothing new.
#'
#' Only the plain drawing is read; see [rocr_performance_layer_type()] for
#' what is declined.
#'
#' @keywords internal
BaseRRocrPerformanceLayerProcessor <- R6::R6Class(
  "BaseRRocrPerformanceLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Process the layer: read its curves, selectors and titles
    #'   from the recorded `performance` object
    #' @param plot Unused; present for the processor interface
    #' @param layout Unused; present for the processor interface
    #' @param built Unused; present for the processor interface
    #' @param gt Gtable of the replayed drawing, searched for selectors (optional)
    #' @param grob_id Unused; present for the processor interface
    #' @param panel_id Unused; present for the processor interface
    #' @param panel_ctx Unused; present for the processor interface
    #' @param layer_info Layer information with the recorded call
    #' @return List describing the layer for the MAIDR payload
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      axes <- self$extract_axis_titles(layer_info)
      data <- self$extract_data(layer_info)
      pr_curve <- titled_pr_curve(axes, data)
      if (!pr_curve) {
        # A threshold is a pr_curve's to announce; a line has no slot for it.
        data <- lapply(data, function(series) {
          lapply(series, function(point) {
            point$threshold <- NULL
            point
          })
        })
      }

      list(
        data = data,
        selectors = self$generate_selectors(layer_info, gt),
        type = if (pr_curve) "pr_curve" else "line",
        title = self$extract_main_title(layer_info),
        axes = axes
      )
    },

    #' @description One series per run of the `performance` object, each
    #'   point its x and y and, where it is finite, the cutoff it was scored at
    #' @param layer_info Layer information with the recorded call
    #' @return List of series
    extract_data = function(layer_info) {
      perf <- self$performance(layer_info)
      if (is.null(perf)) {
        return(list())
      }
      runs <- length(perf@x.values)
      lapply(seq_len(runs), function(i) {
        x <- as.numeric(perf@x.values[[i]])
        y <- as.numeric(perf@y.values[[i]])
        cutoff <- if (length(perf@alpha.values) >= i) {
          as.numeric(perf@alpha.values[[i]])
        } else {
          NULL
        }
        # The pairs ROCR's own plot method draws.
        drawn <- is.finite(x) & is.finite(y)
        idx <- which(drawn)
        lapply(idx, function(j) {
          point <- list(x = x[[j]], y = y[[j]])
          if (length(cutoff) == length(x) && is.finite(cutoff[[j]])) {
            point$threshold <- cutoff[[j]]
          }
          if (runs > 1L) {
            point$z <- paste("Run", i)
          }
          point
        })
      })
    },

    #' @description The axis titles ROCR draws: `xlab` and `ylab` when given,
    #'   else the measures' names
    #' @param layer_info Layer information with the recorded call
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      perf <- self$performance(layer_info)
      args <- layer_info$plot_call$args
      build_axes(
        x = recorded_axis_label(args, "xlab", if (!is.null(perf)) perf@x.name),
        y = recorded_axis_label(args, "ylab", if (!is.null(perf)) perf@y.name)
      )
    },

    #' @description The recorded `performance` object
    #' @param layer_info Layer information with the recorded call
    #' @return The object, or NULL when the call does not carry one
    performance = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      perf <- resolve_xy_args(layer_info$plot_call$args)$x
      if (is_rocr_performance(perf)) perf else NULL
    }
  )
)

#' Whether a value is a ROCR `performance` object
#'
#' Checked by class name, so ROCR is not needed to ask: a `performance`
#' object only exists where ROCR is installed.
#'
#' @param x Anything
#' @return TRUE for an S4 object of class `performance` from ROCR
#' @keywords internal
is_rocr_performance <- function(x) {
  isS4(x) && methods::is(x, "performance") &&
    identical(attr(class(x), "package"), "ROCR")
}

#' The layer type of `plot()` of a ROCR `performance` object
#'
#' Read (`"rocr_performance"`) only when ROCR draws one polyline per run
#' from the object's own values, which is what its plot method does unless
#' told otherwise. Declined (`"unknown"`, so the chart is shown as a
#' picture) when the drawing is something else:
#'
#' * `avg` other than `"none"` draws averaged curves and, with
#'   `spread.estimate`, error bars or boxes -- values the object does not
#'   hold;
#' * `colorize = TRUE` draws each curve as one segment per pair of points,
#'   so there is no polyline per run to outline;
#' * `downsampling` draws a subset of the points;
#' * `add = TRUE` draws over an earlier plot, as `curve(add = TRUE)` does,
#'   and starts no plot of its own;
#' * a `type` other than `"l"` draws points or steps the line reading does
#'   not outline;
#' * a measure with no x values, such as `"auc"`, ROCR does not plot.
#'
#' @param args The recorded arguments of the `plot()` call
#' @return `"rocr_performance"` or `"unknown"`
#' @keywords internal
rocr_performance_layer_type <- function(args) {
  perf <- resolve_xy_args(args)$x
  flag <- function(name) isTRUE(as.logical(args[[name]])[1])
  avg <- args[["avg"]]
  type <- args[["type"]]
  downsampling <- args[["downsampling"]]

  plain <- (is.null(avg) || identical(as.character(avg)[1], "none")) &&
    !flag("colorize") && !flag("add") &&
    (is.null(downsampling) || isTRUE(downsampling[1] == 0)) &&
    (is.null(type) || identical(as.character(type)[1], "l"))
  readable <- length(perf@x.values) > 0L &&
    length(perf@x.values) == length(perf@y.values) &&
    all(vapply(perf@x.values, is.numeric, logical(1))) &&
    all(vapply(perf@y.values, is.numeric, logical(1)))

  if (plain && readable) "rocr_performance" else "unknown"
}
