#' Base R Recorded-Argument Utilities
#'
#' Helpers for resolving data arguments out of recorded Base R plot calls.
#'
#' @keywords internal
NULL

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

#' Is a set of resolved coordinates usable for an axis grid?
#'
#' `grDevices::xy.coords()` coerces whatever it is given, so categorical
#' coordinates come back as all-`NA` numerics rather than as an error. Those
#' are worse than the raw input: `range()` on them yields infinities and a
#' warning, where the raw character vector is simply rejected as non-numeric.
#'
#' @param coords Value returned by `grDevices::xy.coords()`, or NULL
#' @return TRUE when both axes carry at least one finite value
#' @keywords internal
usable_xy_coords <- function(coords) {
  if (is.null(coords) || !is.numeric(coords$x) || !is.numeric(coords$y)) {
    return(FALSE)
  }
  any(is.finite(coords$x)) && any(is.finite(coords$y))
}

#' Name a recorded call's arguments the way R matched them
#'
#' A wrapper declared `function(...)` sees only the names the user typed, so
#' `hist(x, 20)` records an unnamed `20` and every processor asking for
#' `args[["breaks"]]` comes up empty. Running the recorded arguments through
#' `match.call()` against the definition R actually dispatched to restores
#' the names R itself assigned, once, for every processor.
#'
#' Two properties are preserved deliberately:
#'
#' * **Order.** `match.call()` reorders arguments into formal order; the
#'   recorded list keeps the user's order and only gains names. Replay does
#'   `do.call()`, which honours names regardless of position, while
#'   `apply_barplot_sorting()` and friends still find the height in slot 1.
#' * **The dispatch argument stays exactly as written.** S3 dispatch happens
#'   on the first argument of the *generic*, and methods are free to rename
#'   it: `plot.formula()` calls it `formula`, not `x`. Naming a positional
#'   first argument would therefore break replay in one direction or the
#'   other (`plot(x = mpg ~ wt)` never reaches `plot.formula()`, and
#'   `plot(formula = ...)` never satisfies the generic). Leaving it untouched
#'   makes the replayed call dispatch byte-identically to the user's.
#'
#' @param function_name Name of the recorded function
#' @param definition The original (unwrapped) function that was called
#' @param args Recorded argument list of evaluated values
#' @return `args` with the names R matched, in the recorded order
#' @keywords internal
match_recorded_args <- function(function_name, definition, args) {
  if (is.null(args) || length(args) == 0 || !is.function(definition)) {
    return(args)
  }

  target <- dispatched_definition(function_name, definition, args)
  if (is.null(target) || is.null(formals(target))) {
    return(args)
  }

  arg_names <- names(args)
  if (is.null(arg_names)) {
    arg_names <- rep("", length(args))
  }

  # Placeholder symbols rather than the recorded call: they are unique, so
  # the matched call maps back to a slot even when the user passed the same
  # expression twice, and no data value is deparsed.
  slots <- paste0("..maidr_slot_", seq_along(args))
  placeholders <- lapply(slots, as.name)
  names(placeholders) <- arg_names
  synthetic <- as.call(c(list(as.name(function_name)), placeholders))

  matched <- tryCatch(
    match.call(definition = target, call = synthetic, expand.dots = TRUE),
    error = function(e) NULL
  )
  if (is.null(matched)) {
    return(args)
  }

  matched_args <- as.list(matched)[-1L]
  matched_names <- names(matched_args)
  if (is.null(matched_names)) {
    return(args)
  }

  dispatch_formal <- names(formals(target))[1L]

  for (i in seq_along(matched_args)) {
    entry <- matched_args[[i]]
    if (!is.name(entry) || !nzchar(matched_names[i])) {
      next
    }
    if (identical(matched_names[i], dispatch_formal)) {
      next
    }
    slot <- match(as.character(entry), slots)
    if (is.na(slot)) {
      next
    }
    arg_names[slot] <- matched_names[i]
  }

  names(args) <- arg_names
  args
}

#' Resolve the definition R dispatched a recorded call to
#'
#' `hist` is the motivating case from #98: the generic is `hist(x, ...)`, so
#' matching against it leaves a positional `breaks` inside the dots. The
#' method carries the formals that matter, and picking it by the first
#' argument's class is the same choice `UseMethod()` made when the call ran.
#'
#' @param function_name Name of the recorded function
#' @param definition The original (unwrapped) function that was called
#' @param args Recorded argument list of evaluated values
#' @return A function to match against, or NULL when none can be resolved
#' @keywords internal
dispatched_definition <- function(function_name, definition, args) {
  if (is.primitive(definition)) {
    return(NULL)
  }
  body_names <- tryCatch(all.names(body(definition)), error = function(e) character(0))
  if (!"UseMethod" %in% body_names) {
    return(definition)
  }

  # Resolve methods from the generic's OWN namespace. getS3method() defaults
  # to parent.frame(), which from inside this package finds maidr's exported
  # wrapper of the same name and then searches maidr's (empty) S3 table.
  env <- environment(definition)
  if (!is.environment(env)) {
    env <- globalenv()
  }

  first <- tryCatch(args[[1L]], error = function(e) NULL)
  candidates <- c(class(first), "default")
  for (cls in candidates) {
    method <- tryCatch(
      utils::getS3method(function_name, cls, optional = TRUE, envir = env),
      error = function(e) NULL
    )
    if (is.function(method)) {
      return(method)
    }
  }

  definition
}

#' The two-way contingency table a recorded call was handed, when it is one
#'
#' `mosaicplot()` is given the table itself, so the recorded call carries
#' every number a `mosaic` layer wants -- the counts, the margins they imply,
#' and the level names from `dimnames()`. Nothing is inferred from the
#' drawing.
#'
#' Only a two-dimensional table is returned. `mosaicplot()` accepts three and
#' more, splitting recursively, and a `mosaic` layer has one category axis and
#' one fill -- so a deeper table has nowhere to put its later dimensions and
#' is declined rather than flattened into a cross-classification the chart
#' does not claim. A table with unnamed margins is declined too: the levels
#' are what a reader navigates by, and positions are not levels.
#'
#' Shared by the adapter's dispatch and the processor's extraction so the two
#' cannot disagree about which calls are readable.
#'
#' @param args Recorded argument list, or NULL
#' @return A 2-D table with named margins, or NULL
#' @keywords internal
recorded_two_way_table <- function(args) {
  table <- resolve_xy_args(args)$x
  if (is.null(table) || is.language(table)) {
    return(NULL)
  }
  table <- tryCatch(as.table(table), error = function(e) NULL)
  if (is.null(table) || length(dim(table)) != 2) {
    return(NULL)
  }
  if (is.null(rownames(table)) || is.null(colnames(table))) {
    return(NULL)
  }
  table
}
