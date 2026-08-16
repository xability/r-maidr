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
      # Put the layer's rows into the order the polyline is drawn in, and
      # drop the ends that are not points, *before* anything reads the frame.
      # Doing it here rather than on the emitted payload is what keeps it
      # correct: by the time `super$process()` returns, x may have been
      # rewritten into axis labels, and sorting those would be a
      # lexicographic sort of numbers.
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      built <- self$in_drawn_order(built)

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

    #' @description Put this layer's built rows into the order they are drawn
    #' in, dropping any row that is not a point.
    #'
    #' Both halves come from one fact: \code{GeomStep} does not draw the rows
    #' it is handed. \code{GeomStep$draw_panel()} calls
    #' \code{ggplot2:::stairstep()}, whose first act is
    #' \code{data[order(data$x), ]} -- so the drawn staircase is the
    #' \emph{sorted} rows, whatever order the stat returned them in. Sorting
    #' here recovers what is on screen rather than imposing a new order, and
    #' an already-sorted layer -- which is every \code{geom_step()} written by
    #' hand -- is unchanged.
    #'
    #' \code{StatEcdf} is why this is needed at all. It returns its rows in
    #' input order and pads them with \code{-Inf} / \code{Inf} for the two
    #' ends of the staircase. Measured on \code{n = 20}: 22 rows, two of them
    #' infinite, unsorted. Those two rows are not observations -- there is no
    #' x to announce for them -- and an infinity in the payload is worse than
    #' a dropped point in both bindings: \code{jsonlite} writes it as the
    #' \emph{string} \code{"-Inf"}, and \code{json.dumps} on the Python side
    #' writes a bare \code{-Infinity} that \code{JSON.parse} rejects outright
    #' (xability/py-maidr#427).
    #'
    #' Ordered within \code{PANEL} and \code{group}, not globally, because
    #' \code{draw_panel()} is called once per panel per group -- a grouped
    #' ECDF is several staircases, and a global sort would interleave them
    #' into one series that walks backwards at every seam.
    #'
    #' Left alone when x is not numeric: the finiteness test is meaningless
    #' there and \code{is.finite()} on a character vector is \code{FALSE}
    #' throughout, which would delete every row.
    #'
    #' @param built Built plot data
    #' @return \code{built}, with this layer's frame reordered and filtered
    in_drawn_order = function(built) {
      index <- self$layer_info$index
      if (is.null(built) || is.null(built$data) || is.null(index) ||
        index < 1L || index > length(built$data)) {
        return(built)
      }

      frame <- built$data[[index]]
      if (!is.data.frame(frame) || nrow(frame) == 0L ||
        !("x" %in% names(frame)) || !is.numeric(frame$x)) {
        return(built)
      }

      keep <- is.finite(frame$x)
      if ("y" %in% names(frame) && is.numeric(frame$y)) {
        keep <- keep & is.finite(frame$y)
      }
      frame <- frame[keep, , drop = FALSE]
      if (nrow(frame) == 0L) {
        built$data[[index]] <- frame
        return(built)
      }

      panel <- if ("PANEL" %in% names(frame)) as.integer(frame$PANEL) else 1L
      group <- if ("group" %in% names(frame)) frame$group else 1L
      built$data[[index]] <- frame[order(panel, group, frame$x), , drop = FALSE]
      built
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
