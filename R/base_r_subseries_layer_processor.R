#' Base R Seasonal Subseries Layer Processor
#'
#' @description
#' Reads `monthplot()` as the set of lines it draws: one series per cycle
#' position -- month, quarter, whatever the frequency makes it -- running over
#' that position's own subseries.
#'
#' `stats::monthplot.default` draws exactly that, one `lines()` call per
#' position:
#'
#' ```r
#' for (i in 1L:f) {
#'   sub <- phase == i
#'   lines((y[sub] - min(y)) * scale - 0.45 + i, x[sub], type = type, ...)
#' }
#' ```
#'
#' The x coordinate there is a slot offset, not a reading: every subseries is
#' squeezed into its own 0.9-wide band so twelve of them fit side by side on
#' one axis. What the offset is computed *from* is `times`, and that is the
#' reading -- the cycle each observation falls in. So each series comes out as
#' its own subseries over `times`, carrying its position's label as `z`, which
#' is the shape [BaseRLineLayerProcessor] already reads for `matplot`.
#'
#' Recomputed from the recorded arguments rather than read back off the
#' drawing, for the reason the correlograms recompute theirs (#276): the slot
#' offsets are on the page and the times are not, and the offsets are the half
#' that carries no meaning.
#'
#' # What is not read
#'
#' `base` draws one horizontal segment per position at `base(x[phase == i])`
#' -- the position's mean, by default -- and those segments are not emitted.
#' There is no shape in the grammar for a per-series reference level, and a
#' series of its own would be wrong: the twelve means run across the *cycle
#' positions*, while every series here runs across the *cycles*, so putting
#' them in one layer would put two x domains in it. Left to a maintainer with
#' the grammar to change.
#'
#' `type` does not change the reading, for the reason `interaction.plot`'s does
#' not change its own (#278): `"l"` and `"h"` draw the same subseries with
#' different marks, and reading the spikes as loose values would lose the
#' grouping that makes the chart a subseries plot.
#'
#' It does change where the marks *are*, though. `"h"` is not handed to
#' `lines()` the way a `type` usually is -- `monthplot` branches and calls
#' `segments()` instead -- so the grobs land under `-segments-` and the
#' inherited search for `-lines-` finds nothing. A layer with no selectors is
#' dropped by the frontend's `selectors.length === series count` precondition,
#' so the chart would read correctly and highlight nothing at all. See
#' `selector_grob_type()` and `generate_selectors()` below.
#'
#' A monthly series whose labels this reads rather than the caller writes is
#' named with [month.abb] rather than with `monthplot`'s own initials -- see
#' the note beside `ts_labels()` for why the initials do not survive being
#' announced.
#'
#' @keywords internal
BaseRSubseriesLayerProcessor <- R6::R6Class(
  "BaseRSubseriesLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description
    #' One series per cycle position, over that position's own subseries.
    #'
    #' Built point by point rather than through
    #' `extract_multiline_data()`, which takes a matrix and so would need the
    #' short positions padded. A series of 48 monthly observations gives every
    #' month four cycles and pads nothing; 50 gives January and February five
    #' and the other ten four, and the padding would put two points on the
    #' chart that `monthplot` never drew.
    #'
    #' @param layer_info Layer information for the recorded call
    #' @return A list of series, each a list of `x`/`y`/`z` points
    extract_data = function(layer_info) {
      drawn <- private$subseries(layer_info)
      if (is.null(drawn)) {
        return(list())
      }

      series <- list()
      # `1L:f` where `f <- length(labels)`, the bound `monthplot` itself
      # loops to. A phase value past the last label is not drawn at all, so
      # walking the phase's own distinct values instead would emit a series
      # for observations that are not on the page.
      for (i in seq_along(drawn$labels)) {
        at <- which(drawn$phase == i)
        if (!length(at)) {
          next
        }
        label <- as.character(drawn$labels[[i]])
        series[[length(series) + 1L]] <- lapply(at, function(j) {
          list(
            # `as.character()` on a whole double already writes "2" rather
            # than "2.0", so nothing has to round it into an integer first --
            # and an integer cast would answer `NA` for a time beyond
            # .Machine$integer.max, which a year never is but a caller's own
            # `times` could be.
            x = as.character(drawn$times[[j]]),
            y = as.numeric(drawn$values[[j]]),
            z = label
          )
        })
      }
      series
    },
    #' @description
    #' The labels the drawing writes.
    #'
    #' `monthplot`'s own `ylab` default is `deparse1(substitute(x))`, so it
    #' names the *expression* the caller wrote. The wrapper records evaluated
    #' values, by which point `substitute()` is gone, so the expression comes
    #' off the recorded call text instead, the way the correlograms recover
    #' their series names (#276).
    #'
    #' There is no default for `xlab`: `monthplot` blanks it unless the caller
    #' passes one, because the axis it writes carries the cycle labels and not
    #' a quantity. An unset label is left unset rather than invented.
    #'
    #' @param layer_info Layer information for the recorded call
    #' @return An `axes` list from [build_axes()]
    extract_axis_titles = function(layer_info) {
      args <- private$recorded_args(layer_info)
      written <- private$written_args(layer_info)

      build_axes(
        x = private$label(args$xlab, NULL),
        y = private$label(args$ylab, written$x)
      )
    },
    #' @description
    #' The selectors, with the base line's grob left out of them.
    #'
    #' `monthplot` draws the `base` reference segments in one `segments()`
    #' call *before* the loop, so on a `type = "h"` chart the first
    #' `-segments-` grob is the twelve means and the rest are the twelve
    #' subseries. Handed over as they are, every series would be outlined on
    #' the position before it.
    #'
    #' A count that is not exactly one more than the series drops the
    #' selectors rather than guessing which grob is which: outlining the wrong
    #' spikes is worse than outlining none.
    #'
    #' `base = NULL` would remove the extra grob, and cannot arrive here:
    #' `monthplot(x, type = "h", base = NULL)` raises `object 'means' not
    #' found` inside `stats` -- measured -- because the `"h"` branch reads a
    #' `means` the `base` guard never computed. A call that raised is never
    #' recorded.
    #'
    #' @param layer_info Layer information for the recorded call
    #' @param gt The gtable the drawing was exported to
    #' @return A list of CSS selectors, one per series
    generate_selectors = function(layer_info, gt = NULL) {
      selectors <- super$generate_selectors(layer_info, gt)
      if (!private$spikes(layer_info)) {
        return(selectors)
      }

      drawn <- private$subseries(layer_info)
      expected <- if (is.null(drawn)) {
        0L
      } else {
        sum(vapply(
          seq_along(drawn$labels),
          function(i) any(drawn$phase == i),
          logical(1)
        ))
      }
      if (!expected || length(selectors) != expected + 1L) {
        return(list())
      }
      selectors[-1L]
    },
    #' @description
    #' Which family of grob names this layer's selectors come from.
    #'
    #' `-segments-` when the spikes were drawn, `-lines-` otherwise. Public
    #' because the parent's is: `generate_selectors_from_grob()` reaches it
    #' through `self$`, which finds nothing private.
    #'
    #' @param layer_info Layer information for the recorded call
    #' @return `"segments"` or `"lines"`
    selector_grob_type = function(layer_info) {
      if (private$spikes(layer_info)) "segments" else "lines"
    }
  ),
  private = list(
    # Whether this call drew spikes rather than lines. `type` reaches the
    # recorded arguments only when the caller wrote it, and `match.arg` admits
    # nothing but `"l"` and `"h"`, so anything else is the default.
    spikes = function(layer_info) {
      type <- as.character(private$recorded_args(layer_info)$type)
      length(type) && identical(type[[1L]], "h")
    },
    recorded_args = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(list())
      }
      layer_info$plot_call$args %||% list()
    },
    # The series, its cycle positions and their labels, resolved the way
    # `monthplot` resolves them.
    #
    # `x` is read positionally because `match_recorded_args()` deliberately
    # leaves the dispatch slot named as the caller wrote it, so a positional
    # first argument arrives unnamed.
    subseries = function(layer_info) {
      args <- private$recorded_args(layer_info)
      x <- args$x %||% (if (length(args)) args[[1]] else NULL)
      if (is.null(x) || is.language(x) || !is.numeric(x)) {
        return(NULL)
      }

      labels <- private$given(args$labels)
      times <- private$given(args$times)
      phase <- private$given(args$phase)

      # `monthplot.ts` derives all three from the series when the caller
      # supplied none; `monthplot.default` derives them from the position in
      # the vector. Either way an argument the caller did write wins.
      if (stats::is.ts(x)) {
        # `time()` on a `ts` encodes the cycle position in its fraction --
        # February of cycle 2 is 2.083333 -- and that fraction is the phase,
        # which is already announced as the series name. Announcing it twice,
        # as six decimal places, is noise, so the derived times are the cycle
        # numbers: `frequency` is defined so that one unit is one cycle, which
        # makes the floor exactly the cycle and not a rounding.
        times <- times %||% floor(as.numeric(stats::time(x)))
        phase <- phase %||% as.numeric(stats::cycle(x))
        labels <- labels %||% private$ts_labels(stats::frequency(x), args)
      } else {
        labels <- labels %||% 1L:12L
        times <- times %||% seq_along(x)
        phase <- phase %||% ((as.numeric(times) - 1L) %% length(labels) + 1L)
      }

      # `monthplot.default` again: a caller who wrote `phase` but no `labels`
      # gets the phase's own distinct values as the labels, and the phase
      # renumbered against them.
      if (is.null(private$given(args$labels)) &&
            !is.null(private$given(args$phase))) {
        labels <- unique(phase)
        phase <- match(phase, labels)
      }

      if (!length(labels) || length(phase) != length(x) ||
            length(times) != length(x)) {
        return(NULL)
      }

      list(
        values = as.numeric(x),
        times = as.numeric(times),
        phase = as.numeric(phase),
        labels = labels
      )
    },
    # `monthplot.ts`'s own table: quarters and months are named, and any other
    # frequency is numbered.
    ts_labels = function(frequency, args) {
      if (!is.null(private$given(args$phase))) {
        # The method hands a caller-supplied `phase` to `monthplot.default`
        # without labels, and the renumbering above is what names it.
        return(seq_len(max(1L, as.integer(frequency))))
      }
      if (isTRUE(frequency == 4)) {
        return(paste0("Q", 1L:4L))
      }
      if (isTRUE(frequency == 12)) {
        # `monthplot.ts` writes `c("J", "F", "M", ...)`, and those letters do
        # not name twelve things: March and May are both "M", and January,
        # June and July are all "J". On the axis that is a space-saving
        # device and costs a sighted reader nothing, because the third tick
        # is March by where it sits. A series name has no position to be read
        # from, so a reader who hears "M" cannot tell which "M" it is.
        #
        # So the derived monthly labels are `month.abb` -- base R's own
        # spelling of the same twelve months, and the one it uses everywhere
        # a month has room to be named. This applies only to the labels we
        # derive: labels the caller wrote are theirs and are passed through
        # exactly as written, ambiguous or not.
        return(month.abb)
      }
      seq_len(max(1L, as.integer(frequency)))
    },
    # An argument the caller actually supplied. A recorded `NULL` is how
    # `monthplot(x, labels = NULL)` arrives, and the function treats that as
    # "derive them", not as "no labels".
    given = function(value) {
      if (is.null(value) || is.language(value) || !length(value)) {
        return(NULL)
      }
      value
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
          definition = stats::monthplot,
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
      paste(deparse(fallback), collapse = " ")
    }
  )
)
