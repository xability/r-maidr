#' Base R bxp() Layer Processor
#'
#' @description
#' Reads a `graphics::bxp()` call as the box plot it draws.
#'
#' `bxp()` is the drawing half of `boxplot()`: `boxplot.default()` computes the
#' five-number summaries and then hands them to `bxp()`, which puts the boxes,
#' whiskers, medians and outliers on the page. Calling it directly is how a
#' caller draws boxes from summaries they already have -- from
#' `boxplot(plot = FALSE)`, from `boxplot.stats()`, or computed elsewhere
#' entirely -- and it is one of the twelve calls #262 found drawing while the
#' save reported no plot at all.
#'
#' ## What is the same, and what is not
#'
#' The marks are identical. Drawn off-screen and echoed through
#' `gridGraphics`, `bxp(z)` and the `boxplot()` call that produced `z` emit
#' the same grob names in the same order -- `polygon-1`, `segments-1`,
#' `points-1`, ... -- because the same code drew them. Every selector
#' `BaseRBoxplotLayerProcessor` builds, including the index shift each box
#' with no outliers puts on the boxes after it, therefore addresses a `bxp()`
#' chart unchanged, and this class inherits all of it.
#'
#' The one difference is where the summaries come from. `boxplot()` is handed
#' observations, so its processor replays `boxplot(plot = FALSE)` to recover
#' them; `bxp()` is handed the summaries themselves, in its first argument.
#' Replaying `boxplot()` on *that* would read the six-element list as six
#' groups of numbers and summarise them -- so the only thing this class
#' overrides is `read_stats()`.
#'
#' Two things `bxp()` shares with `boxplot()` are shared including their
#' limits: `horizontal = TRUE` means the same thing to both, and `at =`
#' repositions boxes without reordering the drawing in either, so a
#' non-monotonic `at` reads in drawing order here exactly as it already does
#' for `boxplot()`.
#'
#' @keywords internal
BaseRBxpLayerProcessor <- R6::R6Class(
  "BaseRBxpLayerProcessor",
  inherit = BaseRBoxplotLayerProcessor,
  public = list(
    # The summaries `bxp()` was handed
    #
    # `bxp()`'s first formal is `z`, and it draws nothing without a numeric
    # `z$stats` with five rows -- so a recorded call that reached this
    # package has one. It is still checked rather than assumed: a shape that
    # does not answer leaves the layer empty and the figure falls back to the
    # picture it already was, where reaching past it would raise out of
    # `process()` with nothing to catch it.
    #
    # The positional half looks for the first *unnamed* argument rather than
    # for slot 1. `match_recorded_args()` keeps the author's order and leaves
    # only the dispatch argument unnamed, wherever it was written, so
    # `bxp(horizontal = TRUE, z)` records `z` in slot 2 -- a call R itself
    # accepts and draws. Reading slot 1 there hands `TRUE` to the check below
    # and leaves the layer empty. `resolve_xy_args()` resolves a positional
    # argument the same way, for the same reason. Raised in review of #265.
    #
    # @param args Recorded argument list
    # @return The `boxplot.stats`-shaped list, or NULL when it is not one
    read_stats = function(args) {
      z <- args[["z"]]
      if (is.null(z)) {
        arg_names <- names(args)
        unnamed <- if (is.null(arg_names)) {
          seq_along(args)
        } else {
          which(!nzchar(arg_names))
        }
        if (length(unnamed) > 0) {
          z <- args[[unnamed[1L]]]
        }
      }
      if (!is.list(z)) {
        return(NULL)
      }
      stats <- z[["stats"]]
      if (!is.numeric(stats) || !is.matrix(stats) || nrow(stats) != 5L) {
        return(NULL)
      }
      z
    }
  )
)
