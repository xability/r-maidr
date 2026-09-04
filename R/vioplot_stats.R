#' vioplot's own violin statistics, recovered
#'
#' @description
#' `vioplot::vioplot()` draws a violin but returns only its box summary, so the
#' density curve it drew is not available to a caller. This module recovers
#' both by replaying the call vioplot makes internally -- the same approach the
#' base R boxplot processor takes when it re-calls `boxplot(plot = FALSE)`.
#'
#' Nothing here is an approximation. `vioplot:::vioplot.default` computes its
#' curve with
#'
#' ```r
#' est.xlim <- c(min(lower, data.min), max(upper, data.max))
#' smout <- do.call("sm.density", c(list(data, xlim = est.xlim), args))
#' base[[i]]   <- smout$eval.points
#' height[[i]] <- smout$estimate * hscale
#' ```
#'
#' with `args <- list(display = "none")`, plus `h = h` when the caller passed a
#' bandwidth. `sm.density` is deterministic, so replaying it returns the curve
#' vioplot drew rather than a defensible curve of our own -- which matters,
#' because a kernel density estimate computed with different defaults is not
#' wrong in any way a reader could detect. It simply describes a shape the
#' chart does not draw.
#'
#' Both halves are checkable, from directions that do not touch each other:
#'
#' * `vioplot()` returns `upper`, `lower`, `median`, `q1` and `q3`, and every
#'   one comes back `identical()` to what this module computes.
#' * The violin body grob carries exactly twice as many vertices as
#'   `sm.density` returns evaluation points -- the curve mirrored about the
#'   category position -- so the replayed curve and the drawn one are the same.
#'
#' Both are asserted in `tests/testthat/test-vioplot-stats.R`.
#'
#' @noRd
NULL

#' vioplot's default whisker reach, in interquartile ranges
#' @keywords internal
.maidr_vioplot_default_range <- 1.5

#' Compute one violin's statistics the way vioplot does
#'
#' @param data Numeric vector for one violin.
#' @param h Bandwidth, when the caller passed one. `NULL` lets `sm.density`
#'   choose, which is vioplot's default.
#' @param range Whisker reach in interquartile ranges, as vioplot's `range`.
#' @return A list with `min`, `q1`, `median`, `q3`, `max`, `positions`,
#'   `density` and `bandwidth`, or `NULL` when there is nothing to describe.
#' @keywords internal
compute_vioplot_stats <- function(data,
                                  h = NULL,
                                  range = .maidr_vioplot_default_range) {
  data <- data[is.finite(data)]

  # A single point, or a sample with no spread, has no distribution to
  # describe. Inventing a curve would announce a spread the chart does not
  # show, so this declines and lets the caller decide what to do about it.
  if (length(data) < 2L || diff(base::range(data)) == 0) {
    return(NULL)
  }

  if (!has_sm_package()) {
    return(NULL)
  }

  q1 <- unname(stats::quantile(data, 0.25))
  q3 <- unname(stats::quantile(data, 0.75))
  iqd <- q3 - q1
  data_min <- min(data)
  data_max <- max(data)

  # vioplot's whiskers: the Tukey reach, pulled back to the nearest actual
  # observation so a whisker never extends past the data.
  upper <- min(q3 + range * iqd, data_max)
  lower <- max(q1 - range * iqd, data_min)

  # vioplot spells this `c(min(lower, data.min), max(upper, data.max))`, which
  # simplifies to the data range: by the two lines above `lower` is never below
  # `data_min` and `upper` never above `data_max`, so both outer calls collapse.
  # Kept in the simplified form, with the derivation recorded here rather than
  # the arithmetic repeated.
  est_xlim <- c(data_min, data_max)

  args <- list(display = "none")
  if (!is.null(h)) {
    args <- c(args, h = h)
  }

  smout <- tryCatch(
    do.call(sm::sm.density, c(list(data, xlim = est_xlim), args)),
    error = function(e) NULL
  )
  if (is.null(smout) || !length(smout$estimate)) {
    return(NULL)
  }

  list(
    min = lower,
    q1 = q1,
    median = unname(stats::median(data)),
    q3 = q3,
    max = upper,
    positions = as.numeric(smout$eval.points),
    density = as.numeric(smout$estimate),
    bandwidth = as.numeric(smout$h)
  )
}

#' Whether the density half of a violin can be computed at all
#'
#' `sm` is in vioplot's `Depends`, so it is attached wherever a violin can have
#' been drawn: in any normal installation this cannot fail, and the branch is
#' unreachable. Kept as a guard rather than an assumption only so a broken or
#' partial installation surfaces as no violin layer rather than a bare "there
#' is no package called 'sm'" thrown from inside a rendering path.
#'
#' @return `TRUE` when `sm` can be loaded.
#' @keywords internal
has_sm_package <- function() {
  requireNamespace("sm", quietly = TRUE)
}

#' Split a vioplot call's arguments into one sample per violin
#'
#' `vioplot()` takes its groups the way `boxplot()` does: as separate vectors
#' (`vioplot(a, b, c)`), as a single list or data frame, or as a formula. Only
#' the first two are read here; a formula call is left for the caller to
#' decline, because resolving it needs the environment the call was made in and
#' reconstructing that would be guesswork.
#'
#' @param args The recorded call's arguments.
#' @return A named list of numeric vectors, one per violin, or an empty list.
#' @keywords internal
extract_vioplot_samples <- function(args) {
  arg_names <- names(args)
  if (is.null(arg_names)) {
    arg_names <- rep("", length(args))
  }

  # `vioplot()`'s first formal is named `x`, so `vioplot(x = a, b)` records it
  # as a *named* argument and the rest positionally. Reading only the unnamed
  # ones drops that group -- and `vioplot(x = a)` alone then yields nothing at
  # all, so a single-violin chart written that way announced nothing. `x` is
  # therefore treated as data, in call order, while every other named argument
  # (`names`, `horizontal`, `h`, `range`, `col`, ...) stays out of it.
  is_data <- !nzchar(arg_names) | arg_names == "x"
  positional <- args[is_data]
  if (!length(positional)) {
    return(list())
  }

  first <- positional[[1]]

  # Three call shapes, and they label differently. Measured against what
  # vioplot draws on the category axis:
  #
  #   vioplot(a, b)               ->  "1", "2"    positions
  #   vioplot(x = a, b)           ->  "1", "2"    positions -- `x` is the
  #                                               argument's name, not a label
  #   vioplot(list(p = , q = ))   ->  "p", "q"    element names
  #   vioplot(data.frame(p =, q =)) -> "p", "q"   column names
  #
  # So a group's name is a label only when it came from inside a list or a
  # data frame. Taking the argument names for the vector form would announce
  # a violin as "x" that the chart labels "1".
  if (is.data.frame(first)) {
    samples <- as.list(first)
    named_groups <- TRUE
  } else if (is.list(first)) {
    samples <- first
    named_groups <- TRUE
  } else {
    samples <- positional
    named_groups <- FALSE
  }

  numeric_only <- Filter(function(s) is.numeric(s) && length(s), samples)
  if (!length(numeric_only)) {
    return(list())
  }

  by_position <- as.character(seq_along(numeric_only))
  labels <- by_position
  if (named_groups) {
    from_names <- names(numeric_only)
    if (!is.null(from_names)) {
      labels <- ifelse(nzchar(from_names), from_names, by_position)
    }
  }

  # An explicit `names =` wins over both, since that is what vioplot draws.
  supplied <- args[["names"]]
  if (!is.null(supplied) && length(supplied) == length(numeric_only)) {
    labels <- as.character(supplied)
  }

  stats::setNames(numeric_only, labels)
}
