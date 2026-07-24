#' Base R Recorded-Argument Utilities
#'
#' Helpers for resolving data arguments out of recorded Base R plot calls.
#'
#' @keywords internal

#' Resolve x/y data arguments from a recorded call's argument list
#'
#' Mirrors how plot()/points()/lines() match their arguments: named `x`/`y`
#' win, then the first two UNNAMED arguments in order. Blind positional
#' access (`args[[2]]`) would grab graphical parameters instead
#' (plot(x, type = "l") -> y = "l") or error for single-argument calls
#' (plot(v), lines(v)).
#'
#' @param args Recorded argument list
#' @return List with `x` and `y` (either may be NULL)
#' @keywords internal
resolve_xy_args <- function(args) {
  if (is.null(args) || length(args) == 0) {
    return(list(x = NULL, y = NULL))
  }

  arg_names <- names(args)
  unnamed <- if (is.null(arg_names)) {
    seq_along(args)
  } else {
    which(!nzchar(arg_names))
  }

  x <- args[["x"]]
  if (is.null(x) && length(unnamed) >= 1) {
    x <- args[[unnamed[1]]]
    unnamed <- unnamed[-1]
  }

  y <- args[["y"]]
  if (is.null(y) && length(unnamed) >= 1) {
    y <- args[[unnamed[1]]]
  }

  list(x = x, y = y)
}
