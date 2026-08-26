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
#' **It is read without an outline, deliberately.** The marks are there and
#' the pairing is known -- measured by giving each observation its own
#' `col.stars` and reading every polygon's fill, observation `k` owns
#' polygons `2k - 1` and `2k`, both filled its colour, plus a `segments-k`
#' carrying one segment per variable:
#'
#'     polygon-1  #111199   polygon-2  #111199   segments-1   observation 1
#'     polygon-3  #229922   polygon-4  #229922   segments-2   observation 2
#'     ...
#'
#' What is *not* established is the selector those grobs export to. A
#' selector is only worth emitting once it has been resolved against a real
#' export, and a real export cannot be had until the chart stops falling back
#' to a picture -- which is what this reading is for. So the outline is left
#' for a follow-up that can measure it, rather than guessed from the grob
#' names. Reading without one is what `gauge` already does upstream when the
#' marks and the cursor cannot be paired with confidence.
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
    #' @param gt Unused; this reading emits no selectors.
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
        # Not `list()`: see the note at the head of this file.
        selectors = NULL,
        type = "radar",
        title = self$extract_main_title(info),
        axes = build_axes(
          x = private$label(info, "xlab"),
          y = private$label(info, "ylab")
        )
      )
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
