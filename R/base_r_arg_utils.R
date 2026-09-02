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
#' `mosaicplot()`'s other calling style hands it a formula and a `data`
#' argument instead, and `mosaicplot.formula()` builds the table from the two.
#' That is recovered by `formula_two_way_table()` rather than declined, for
#' the reason the direct call is read at all: the table is the one the chart
#' draws, arrived at by the same code, not a plausible reconstruction (#248).
#'
#' Shared by the adapter's dispatch and the processor's extraction so the two
#' cannot disagree about which calls are readable.
#'
#' @param args Recorded argument list, or NULL
#' @return A 2-D table with named margins, or NULL
#' @keywords internal
recorded_two_way_table <- function(args) {
  handed <- resolve_xy_args(args)$x
  table <- if (is.null(handed) || is.language(handed)) {
    formula_two_way_table(args)
  } else {
    tryCatch(as.table(handed), error = function(e) NULL)
  }
  if (is.null(table) || length(dim(table)) != 2) {
    return(NULL)
  }
  if (is.null(rownames(table)) || is.null(colnames(table))) {
    return(NULL)
  }
  table
}

#' The table `mosaicplot.formula()` would build from a recorded formula call
#'
#' `mosaicplot(~ Hair + Eye, data = df)` is a common calling style, and the
#' table it draws is recoverable rather than invented -- so it is built the
#' way `mosaicplot.formula()` builds it, by the same two branches, rather
#' than by a rule of our own that would agree with it only sometimes.
#'
#' ## Which branch, and why it matters
#'
#' Read from `graphics:::mosaicplot.formula` rather than assumed. A `data`
#' that is a table (or has more than two dimensions) is summed over the
#' formula's terms; anything else goes through `model.frame()` and is
#' **counted by row**:
#'
#' \preformatted{
#' if (inherits(edata, "ftable") || inherits(edata, "table") ||
#'     length(dim(edata)) > 2) {
#'   data <- marginSums(as.table(data), varnames)
#'   mosaicplot(data, ...)
#' } else {
#'   mf <- eval(model.frame(formula, data, subset, na.action))
#'   mosaicplot(table(mf), ...)
#' }
#' }
#'
#' The distinction is not cosmetic, and #248 proposed the other reading. A
#' data frame of *pre-counted* cells -- `as.data.frame(HairEyeColor[, , 1])`,
#' sixteen rows and a `Freq` column -- is counted by row like any other, so
#' the chart draws sixteen equal cells:
#'
#' \preformatted{
#' table(model.frame(~ Hair + Eye, df))    xtabs(Freq ~ Hair + Eye, df)
#'         Brown Blue Hazel Green                  Brown Blue Hazel Green
#'   Black     1    1     1     1            Black    32   11    10     3
#'   Brown     1    1     1     1            Brown    53   50    25    15
#'   Red       1    1     1     1            Red      10   10     7     7
#'   Blond     1    1     1     1            Blond     3   30     5     8
#' }
#'
#' The left table is what `mosaicplot()` draws; the right is the one it would
#' draw if handed `HairEyeColor[, , 1]` directly. Reading the right one would
#' announce numbers the chart does not show, which is the one thing this
#' processor exists not to do. There is no `Freq` convention to match:
#' `mosaicplot.formula()` has none.
#'
#' ## What is declined
#'
#' A recorded `subset`. `mosaicplot.formula()` passes it into
#' `model.frame()`, so honouring it means reproducing an argument whose
#' recorded form is not the expression `model.frame()` is given -- and
#' ignoring it would read rows the chart left out. Declined rather than
#' guessed, which leaves the figure exactly the picture it is today.
#'
#' A recorded `na.action` is *not* passed through, and does not need to be:
#' `table()` drops a missing level whatever reached it, so the three actions
#' a caller can name all draw the same chart. Measured on a frame with an NA
#' in each column, `na.omit`, `na.pass` and `na.exclude` gave one table:
#'
#' \preformatted{
#'      b
#' a     p q
#'   x   2 1
#'   y   1 0
#' }
#'
#' `stats::na.omit` is named here anyway, because that is what
#' `mosaicplot.formula()` defaults to and matching it costs nothing.
#'
#' @param args Recorded argument list, or NULL
#' @return A table, or NULL when the call is not a readable formula call
#' @keywords internal
formula_two_way_table <- function(args) {
  formula <- tryCatch(args[[1L]], error = function(e) NULL)
  if (!inherits(formula, "formula")) {
    return(NULL)
  }
  data <- args$data
  if (is.null(data) || "subset" %in% names(args)) {
    return(NULL)
  }

  if (inherits(data, "ftable") || inherits(data, "table") ||
    length(dim(data)) > 2) {
    return(formula_margin_table(formula, data))
  }

  frame <- tryCatch(
    stats::model.frame(formula, data = data, na.action = stats::na.omit),
    error = function(e) NULL
  )
  if (is.null(frame)) {
    return(NULL)
  }
  tryCatch(as.table(table(frame)), error = function(e) NULL)
}

#' Sum a table over the variables a formula names
#'
#' The branch `mosaicplot.formula()` takes when `data` is already a table:
#' the formula selects which margins to keep, and `~ .` keeps all of them.
#'
#' @param formula The recorded formula
#' @param data The recorded table
#' @return A table, or NULL
#' @keywords internal
formula_margin_table <- function(formula, data) {
  table <- tryCatch(as.table(data), error = function(e) NULL)
  if (is.null(table)) {
    return(NULL)
  }
  names <- tryCatch(
    attr(stats::terms(formula), "term.labels"),
    error = function(e) NULL
  )
  if (is.null(names) || !all(names != ".")) {
    return(table)
  }
  tryCatch(marginSums(table, names), error = function(e) NULL)
}

#' Read a recorded logical argument the way its drawing function does
#'
#' Every base R reader asked `isTRUE()` of a recorded flag, and the base R
#' drawing functions ask `if (x)`. The two agree on `TRUE`, on `FALSE` and on
#' absent, and disagree on every other truthy value R accepts in an `if` --
#' so a chart written `stripchart(x, vertical = 1)` was drawn vertically and
#' announced horizontally, with the values on the group axis and the group
#' positions on the value axis, silently, on a chart that renders as an
#' interactive one rather than as a fallback (#256).
#'
#' Measured, by reading each drawing function's own body:
#'
#' | function | asks |
#' | --- | --- |
#' | `barplot.default` | `if (beside)`, `(logx && horiz)` |
#' | `bxp` | `if (horizontal)` |
#' | `hist.default` | `if (freq1)` |
#' | `stripchart.default` | `if (vertical)` |
#' | `qqnorm.default`, `qqline` | `if (datax)` |
#' | `vioplot.default` | `if (horizontal | ...)` |
#'
#' All seven ask R's own truthiness, so all seven are read through this.
#'
#' `NA` and an uncoercible value give the caller's default rather than an
#' error: `if (NA)` stops in R, but a reader that stops takes the whole
#' figure with it, and a chart read under its default is better than no chart
#' at all. A value of any length but one does the same, since `if` on one of
#' those errors too.
#'
#' @param args Recorded argument list
#' @param name The formal's name
#' @param default What an absent, `NA` or unreadable argument means
#' @return TRUE or FALSE
#' @keywords internal
recorded_flag <- function(args, name, default = FALSE) {
  if (is.null(args)) {
    return(default)
  }
  value <- args[[name]]
  if (is.null(value) || length(value) != 1) {
    return(default)
  }
  if (is.logical(value)) {
    return(if (is.na(value)) default else as.logical(value))
  }
  if (is.numeric(value)) {
    return(if (is.na(value)) default else value != 0)
  }
  if (is.character(value)) {
    coerced <- suppressWarnings(as.logical(value))
    return(if (is.na(coerced)) default else coerced)
  }
  default
}

#' The `main` title a recorded call wrote, as text
#'
#' `main = expression(alpha^2)` is an ordinary way to put a Greek letter on a
#' chart, and a dozen readers passed the recorded value straight into the
#' layer's `title`. `jsonlite::toJSON()` has no method for an expression, so
#' the whole save failed on a title. A title that is not text is announced
#' as empty rather than failing the chart it sits on; the drawing keeps it.
#'
#' Exact-name lookup, since `args$main` would partial-match nothing today but
#' is the same shape as the `args$x` / `xlab` collision that emptied
#' `monthplot()` (#292).
#'
#' @param args Recorded argument list
#' @return Character scalar, empty when there is no usable title
#' @keywords internal
recorded_main_title <- function(args) {
  title <- if (is.list(args)) args[["main"]] else NULL
  if (is.null(title) || is.language(title)) {
    return("")
  }
  title <- tryCatch(as.character(title)[1], error = function(e) NULL)
  if (is.null(title) || is.na(title)) "" else title
}

#' Resolve a recorded formula into the frame the chart was drawn from
#'
#' Base R calls are recorded and read later, at `show()`/`save_html()` time,
#' and for every argument but one that is harmless: the wrapper records
#' *evaluated values*, so a vector recorded is a vector and rebinding the
#' name it came from afterwards changes nothing.
#'
#' A formula is the exception. It is a reference rather than a value -- it
#' carries the environment it was written in -- and a processor that calls
#' `stats::model.frame()` on it at render time resolves the variables
#' **then**. Measured (#254):
#'
#'     len  <- c(1, 2, 3, 10, 11, 12); supp <- rep(c("OJ", "VC"), each = 3)
#'     stripchart(len ~ supp)              # draws 1,2,3 under OJ
#'     len  <- c(99, 98, 97, 96, 95, 94)   # the user carries on working
#'     supp <- rep(c("XX", "YY"), each = 3)
#'     save_html(file = f)                 # announced 99,98,97 under XX
#'
#' Every value and both group names belonged to bindings made after the
#' drawing, and it was silent: the figure rendered as an interactive chart
#' rather than as a fallback, so nothing said the numbers had moved.
#'
#' So the frame is built **here**, while the call is being recorded and the
#' bindings are still the ones the chart was drawn from. `stripchart.formula`
#' and `boxplot.formula` build the same `stats::model.frame(formula, data)`
#' as they draw, so this is the frame they used rather than a reconstruction
#' of it.
#'
#' Fixed at the recording layer rather than per processor because anything
#' that reads a formula later inherits the same defect.
#'
#' @param args Recorded argument list
#' @param call_env The environment snapshot a deferred call was recorded
#'   with, or NULL when every argument is a plain value.
#' @return The model frame, or NULL when the call carries no formula or the
#'   frame cannot be built -- in which case the reader falls back to
#'   resolving it itself, exactly as before.
#' @keywords internal
recorded_formula_frame <- function(args, call_env = NULL) {
  if (!is.list(args) || length(args) == 0) {
    return(NULL)
  }

  formula <- args[["formula"]]
  if (!is_formula_argument(formula)) {
    formula <- NULL
    for (value in args) {
      if (is_formula_argument(value)) {
        formula <- value
        break
      }
    }
  }
  # Nearly every recorded call carries no formula at all, and this runs on
  # all of them. The `tryCatch` below would cover the case on its own --
  # measured, `stats::model.frame(NULL)` stops with "argument is not a valid
  # model" -- so this changes no reading, only whether the common path raises
  # and catches a condition to reach the same NULL.
  if (!is_formula_argument(formula)) {
    return(NULL)
  }

  # On the NSE path every argument arrives as the expression the caller
  # wrote, with a snapshot of the bindings those expressions name. The
  # formula and the data are resolved in that snapshot, which is where the
  # drawing resolved them.
  formula <- resolve_recorded_value(formula, call_env)
  data <- resolve_recorded_value(args[["data"]], call_env)
  if (!inherits(formula, "formula")) {
    return(NULL)
  }

  # `subset` is part of what was drawn: `pairs.formula` and
  # `stripchart.formula` hand it to `model.frame()`, so a frame built
  # without it carried every row the chart left out. A plain vector is
  # applied the way the drawing applied it; an expression -- `subset = g ==
  # "a"` -- is evaluated the way `model.frame()` evaluates it, in the data
  # and then in the snapshot, so a call recorded inside a loop keeps the
  # rows of its own iteration. Without a snapshot to evaluate it in, the
  # frame is declined and the reader falls back rather than announcing the
  # wrong rows.
  subset <- args[["subset"]]
  if (is.language(subset)) {
    if (!is.environment(call_env)) {
      return(NULL)
    }
    subset <- tryCatch(
      eval(subset, if (is.list(data)) data else NULL, call_env),
      error = function(e) NULL
    )
    if (is.null(subset)) {
      return(NULL)
    }
  }

  # Through `do.call()` so the vector itself is in the call:
  # `model.frame()` reads its `subset` with `substitute()`, and handed the
  # bare name it would look that name up in the data and then in the
  # formula's environment -- where `subset` is `base::subset`.
  frame_args <- list(formula, data = data)
  if (!is.null(subset)) {
    frame_args$subset <- subset
  }
  tryCatch(
    do.call(stats::model.frame, frame_args),
    error = function(e) NULL
  )
}

#' The `height` a recorded `barplot()` call draws
#'
#' `barplot()` reads its data from `height`, which is its first formal. The
#' recorder names positional dots but leaves the dispatch argument as the
#' caller wrote it, so `height` arrives unnamed when it was passed by
#' position and named when it was not -- and `barplot(beside = TRUE, height
#' = m)` put `beside` in the first slot, where every reader used to look.
#'
#' @param args Recorded argument list
#' @return The height vector or matrix, or NULL
#' @keywords internal
recorded_barplot_height <- function(args) {
  if (!is.list(args) || length(args) == 0) {
    return(NULL)
  }
  height <- args[["height"]]
  if (!is.null(height)) {
    return(height)
  }
  arg_names <- names(args)
  unnamed <- if (is.null(arg_names)) seq_along(args) else which(!nzchar(arg_names))
  if (length(unnamed) == 0) {
    return(NULL)
  }
  args[[unnamed[1]]]
}

#' Write a `height` back into a recorded `barplot()` call
#'
#' The counterpart of [recorded_barplot_height()]: the value goes back into
#' the slot it was read from, named or positional.
#'
#' @param args Recorded argument list
#' @param height The replacement height
#' @return The argument list with `height` replaced
#' @keywords internal
set_recorded_barplot_height <- function(args, height) {
  if (!is.null(args[["height"]])) {
    args[["height"]] <- height
    return(args)
  }
  arg_names <- names(args)
  unnamed <- if (is.null(arg_names)) seq_along(args) else which(!nzchar(arg_names))
  if (length(unnamed) == 0) {
    return(args)
  }
  args[[unnamed[1]]] <- height
  args
}

#' Is a recorded argument a formula, evaluated or not?
#'
#' A value recorded on the ordinary path is a `formula` object; on the NSE
#' path the same argument is the unevaluated call to `~`, which `inherits()`
#' does not recognise.
#'
#' @param value A recorded argument
#' @return TRUE for either spelling
#' @keywords internal
is_formula_argument <- function(value) {
  inherits(value, "formula") ||
    (is.call(value) && identical(value[[1L]], as.name("~")))
}

#' A recorded argument as a value
#'
#' @param value A recorded argument, a plain value or an expression
#' @param call_env The snapshot to evaluate an expression in, or NULL
#' @return The value, or NULL when an expression has nowhere to be evaluated
#'   or fails there
#' @keywords internal
resolve_recorded_value <- function(value, call_env = NULL) {
  # A formula object is a language object too, and is already the value.
  if (!is.language(value) || inherits(value, "formula")) {
    return(value)
  }
  if (!is.environment(call_env)) {
    return(NULL)
  }
  tryCatch(eval(value, call_env), error = function(e) NULL)
}
