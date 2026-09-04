#' Base R Interaction Plot Layer Processor
#'
#' @description
#' Reads `interaction.plot()` as the set of lines it draws: one series per
#' level of the trace factor, running across the levels of the x factor at
#' `fun(response)` for each cell.
#'
#' `stats::interaction.plot` computes that grid itself and hands it straight
#' to `matplot`:
#'
#' ```r
#' cells <- tapply(response, list(x.factor, trace.factor), fun)
#' matplot(xvals, cells, ..., type = type, ...)
#' ```
#'
#' which is the shape [BaseRLineLayerProcessor] already reads for `matplot` --
#' one series per column, each point carrying its column name as `z`. So the
#' whole reading is recomputing `cells` and handing it over; nothing about
#' extracting a multi-series line is new here.
#'
#' Recomputed rather than read back off the drawing, for the reason the
#' correlograms recompute theirs (#276): a cell mean is not on the page in any
#' form a grob carries, and the recorded arguments hold everything needed to
#' get it exactly as the function did.
#'
#' `type` is not consulted. It varies the marks -- `"l"` draws lines, `"p"`
#' points, `"b"`/`"o"`/`"c"` both -- but every variant draws the same cell
#' means in the same series, and reading a `type = "p"` chart as loose points
#' would lose the trace grouping that makes it an interaction plot.
#'
#' @keywords internal
BaseRInteractionLayerProcessor <- R6::R6Class(
  "BaseRInteractionLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description One series per trace level, read from the grid of cell means
    #' @param layer_info Layer information with the recorded call
    #' @return List of series
    extract_data = function(layer_info) {
      cells <- private$cell_grid(layer_info)
      if (is.null(cells)) {
        return(list())
      }

      # Positions and labels both come from the grid's rows. The positions
      # are indices rather than `interaction.plot`'s own `xvals`, which
      # spaces an ordered factor whose levels are all numbers by their
      # values: a line point carries the label it is announced under and no
      # coordinate beside it, so uneven spacing has nowhere to go and
      # computing it would only look like it did.
      self$extract_multiline_data(
        seq_len(nrow(cells)),
        cells,
        rownames(cells)
      )
    },
    #' @description
    #' The three labels the drawing writes, each explicit argument first.
    #'
    #' All three of `interaction.plot`'s own defaults are
    #' `deparse1(substitute(...))` of an argument, so they name the
    #' *expression* the caller wrote. The wrapper records evaluated values, by
    #' which point `substitute()` is long gone -- a factor's levels are not its
    #' name -- so the expressions come off the recorded call text instead, the
    #' way the correlograms recover their series names (#276).
    #'
    #' @param layer_info Layer information for the recorded call
    #' @return An `axes` list from [build_axes()]
    extract_axis_titles = function(layer_info) {
      args <- private$recorded_args(layer_info)
      written <- private$written_args(layer_info)

      build_axes(
        x = private$label(args$xlab, written$x.factor),
        y = private$label(args$ylab, private$default_ylab(written)),
        # What the lines are grouped by, which is what the trace label names.
        z = private$label(args$trace.label, written$trace.factor)
      )
    }
  ),
  private = list(
    recorded_args = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(list())
      }
      layer_info$plot_call$args %||% list()
    },
    # `tapply(response, list(x.factor, trace.factor), fun)`, the grid the
    # function draws.
    #
    # `x.factor` is read positionally because `match_recorded_args()`
    # deliberately leaves the dispatch slot named as the caller wrote it, so
    # a positional first argument arrives unnamed.
    cell_grid = function(layer_info) {
      args <- private$recorded_args(layer_info)
      x_factor <- args$x.factor %||% args[[1]]
      trace_factor <- args$trace.factor
      response <- args$response
      if (is.null(x_factor) || is.null(trace_factor) || is.null(response)) {
        return(NULL)
      }
      if (is.language(x_factor) || is.language(trace_factor) ||
            is.language(response)) {
        return(NULL)
      }

      fun <- args$fun %||% mean
      # Unreachable by contract, and kept anyway. The wrapper logs nothing
      # when the original call raised -- measured: `interaction.plot` with
      # mismatched lengths, and with a `fun` returning a vector, both error
      # inside `stats` and neither is recorded -- so a recorded call is one
      # whose own `tapply` already succeeded on these very arguments and
      # produced a grid `matplot` could draw. The guard is here so that a
      # future path this reasoning does not cover costs the figure one layer
      # rather than the whole save.
      cells <- tryCatch(
        tapply(response, list(x_factor, trace_factor), fun),
        error = function(e) NULL
      )
      if (!is.matrix(cells) || !nrow(cells) || !ncol(cells)) {
        return(NULL)
      }
      cells
    },
    # The arguments as the caller *wrote* them, matched to their formals.
    #
    # `layer_info$call_expr` is the recorded source text; matching it against
    # the real definition puts each expression under the formal R matched it
    # to, so a caller who named their arguments out of order is read the same
    # way the function read them.
    written_args = function(layer_info) {
      text <- if (is.null(layer_info)) NULL else layer_info$call_expr
      if (!is.character(text) || !length(text) || !nzchar(text[[1]])) {
        return(list())
      }
      parsed <- tryCatch(str2lang(text[[1]]), error = function(e) NULL)
      if (is.null(parsed) || !is.call(parsed)) {
        return(list())
      }
      matched <- tryCatch(
        match.call(
          definition = stats::interaction.plot,
          call = parsed,
          expand.dots = TRUE
        ),
        error = function(e) NULL
      )
      if (is.null(matched)) {
        return(list())
      }
      as.list(matched)[-1L]
    },
    # `paste(deparse1(substitute(fun)), "of ", deparse1(substitute(response)))`
    # -- spelled the way the function spells it, double space and all, so the
    # announcement matches the axis a sighted reader sees.
    default_ylab = function(written) {
      response <- written$response
      if (is.null(response)) {
        return(NULL)
      }
      fun <- written$fun %||% quote(mean)
      paste(private$deparsed(fun), "of ", private$deparsed(response))
    },
    label = function(explicit, fallback) {
      if (is.character(explicit) && length(explicit) && nzchar(explicit[[1]])) {
        return(explicit[[1]])
      }
      if (is.null(fallback)) {
        return(NULL)
      }
      if (is.character(fallback)) {
        return(fallback)
      }
      private$deparsed(fallback)
    },
    deparsed = function(expr) {
      paste(deparse(expr), collapse = " ")
    }
  )
)
