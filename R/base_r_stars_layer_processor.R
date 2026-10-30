#' Base R Star Plot Processor
#'
#' Reads `stars()` as the radar it draws: one closed outline per observation,
#' with a spoke for each variable.
#'
#' **It is a multi-line layer.** MAIDR's `radar` trace is navigated as one --
#' "each spoke a column and each series a row" -- so the whole reading is
#' handing over the matrix with its axes the other way round from the way
#' `stars()` takes it. `stars(m)` draws a glyph per **row**, so the rows are
#' the series and the columns are the spokes, and
#' [BaseRLineLayerProcessor]'s `extract_multiline_data()` wants series in
#' *columns*. Hence the transpose, which is the only rearranging here.
#'
#' **The values are the caller's, not the drawing's.** `stars()` scales every
#' column to `[0, 1]` before drawing, so the radii on the page are shares of
#' each column's range rather than the readings themselves. Announcing those
#' would tell a reader that observation 1 scores 0 on a variable it merely
#' has the smallest value of. The recorded matrix carries what the caller
#' measured, and that is what a reader is told.
#'
#' **Each star is outlined through the polygon it is drawn as.** Measured by
#' giving each observation its own `col.stars` and reading every polygon's
#' fill, observation `k` owns polygons `2k - 1` and `2k`, both filled its
#' colour, plus a `segments-k` carrying one segment per variable:
#'
#'     polygon-1  #111199   polygon-2  #111199   segments-1   observation 1
#'     polygon-3  #229922   polygon-4  #229922   segments-2   observation 2
#'     ...
#'
#' `stars()` draws each star twice, the second time with its `col.lines`
#' border, and the export writes each as a `<polygon>` whose vertices are
#' the spoke tips in the order of the variables, which is how a radar series
#' is paired with its marks; each star's selector names the second. The
#' reading had no outline at all until a real export could be measured. A
#' call drawn with `draw.segments = TRUE` draws sectors instead, and one
#' whose polygons are not two per star, and a key's, is not paired: those
#' are still read without an outline.
#'
#' @keywords internal
BaseRStarsLayerProcessor <- R6::R6Class(
  "BaseRStarsLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Emit one radar series per observation
    #' @param plot Unused; present for the processor interface.
    #' @param layout Unused; present for the processor interface.
    #' @param built Unused; present for the processor interface.
    #' @param gt The grob tree, for the selectors.
    #' @param grob_id Unused; present for the processor interface.
    #' @param panel_id Unused; present for the processor interface.
    #' @param panel_ctx Unused; present for the processor interface.
    #' @param layer_info Layer information with the recorded call.
    #' @return A radar layer, or NULL when nothing was read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      readings <- private$readings(info)
      if (is.null(readings)) {
        return(NULL)
      }

      list(
        data = self$extract_multiline_data(
          seq_len(ncol(readings)),
          t(readings),
          colnames(readings)
        ),
        # NULL, not `list()`, where the stars cannot be paired with their
        # polygons: the orchestrator drops a NULL field, while `list()`
        # would claim marks that resolve to nothing.
        selectors = self$star_selectors(info, gt, nrow(readings)),
        type = "radar",
        title = self$extract_main_title(info),
        axes = build_axes(
          x = private$label(info, "xlab"),
          y = private$label(info, "ylab")
        )
      )
    },

    #' @description One selector per star: the polygon it is drawn as
    #' @param layer_info Layer information with the recorded call.
    #' @param gt The grob tree the chart was drawn to.
    #' @param count How many stars, one per row of the matrix.
    #' @return A list of selectors, or NULL when the polygons cannot be
    #'   paired with the stars
    star_selectors = function(layer_info, gt, count) {
      if (is.null(gt) || count < 1L ||
            recorded_flag(layer_info$plot_call$args, "draw.segments")) {
        return(NULL)
      }
      group_index <- layer_info$group_index %||% layer_info$index
      polygons <- find_graphics_plot_grobs(gt, "polygon", group_index)
      # Two per star, and one more where a key is drawn after them.
      if (!length(polygons) %in% c(2L * count, 2L * count + 1L)) {
        return(NULL)
      }
      drawn <- as.integer(sub("^.*-polygon-([0-9]+)$", "\\1", polygons))
      polygons <- polygons[order(drawn)]
      lapply(seq_len(count), function(k) polygon_cell_selector(polygons[[2L * k]]))
    }
  ),
  private = list(
    # The matrix the caller handed over, named down both sides.
    #
    # `stars()` takes `x` as its first formal with nothing ahead of it, and
    # coerces a data frame with `as.matrix`. A matrix of one row is still a
    # star -- one glyph -- so only an empty one is declined.
    readings = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      handed <- resolve_xy_args(layer_info$plot_call$args)$x
      if (is.null(handed) || is.language(handed) || !length(handed)) {
        return(NULL)
      }

      readings <- tryCatch(as.matrix(handed), error = function(e) NULL)
      if (is.null(readings) || !is.numeric(readings)) {
        return(NULL)
      }
      if (!nrow(readings) || !ncol(readings)) {
        return(NULL)
      }

      dimnames(readings) <- list(
        private$row_names(readings),
        private$column_names(readings)
      )
      readings
    },
    # What the drawing writes under each glyph.
    #
    # `stars()` labels a glyph with `dimnames(x)[[1L]]` and falls back to the
    # row number, which is what the reading does rather than leaving a series
    # unnamed -- a radar's series name is how a reader tells the outlines
    # apart, so there is nothing else it could be.
    row_names = function(readings) {
      declared <- rownames(readings)
      if (!is.null(declared) && length(declared) == nrow(readings) &&
            all(nzchar(declared))) {
        return(as.character(declared))
      }
      as.character(seq_len(nrow(readings)))
    },
    # What the drawing writes around the spokes.
    column_names = function(readings) {
      declared <- colnames(readings)
      if (!is.null(declared) && length(declared) == ncol(readings) &&
            all(nzchar(declared))) {
        return(as.character(declared))
      }
      paste("var", seq_len(ncol(readings)))
    },
    label = function(layer_info, name) {
      args <- if (is.null(layer_info)) NULL else layer_info$plot_call$args
      recorded_axis_label(args, name)
    }
  )
)
