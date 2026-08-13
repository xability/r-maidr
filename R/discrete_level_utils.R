#' Discrete Level Utilities
#'
#' One answer to "what are this aesthetic's categories, in drawn order, and
#' what does each one read as" -- shared by the bar processors so a missing
#' value cannot mean one thing on a dodged chart and another on a stacked one.
#'
#' A missing value is a category. ggplot2's discrete scale lays a column out
#' for it after the ordinary levels and draws the two characters "NA" on its
#' tick and in its legend key, exactly as it lays out a facet panel for a
#' missing facet value and draws "NA" on the strip. Announcing it as anything
#' else names a category the reader is not looking at; announcing nothing at
#' all leaves a drawn bar unreachable by any keystroke (#112).
#'
#' The level vector therefore carries the missing category as `NA_character_`
#' rather than as the string "NA", so a column that literally contains those
#' two characters keeps its own separate category -- the same
#' identity-not-string rule `facet_group_rows()` follows for facets.
#' `level_label()` is what turns a level into the text on the tick, and
#' `level_keys()` is what keys a cell without the two collapsing together.
#'
#' @keywords internal
NULL

#' Distinct values of an aesthetic, in the order ggplot2 draws them
#'
#' A factor follows its own level order, minus the levels nothing was drawn
#' for; anything else sorts in its own type's order. Sorting the values AS
#' TEXT reorders the columns twice over: against a factor whose levels are not
#' alphabetical, and against a number, where it puts 10 before 2.
#'
#' The missing category comes last, which is where ggplot2 puts it for a
#' character column, a numeric one and an ordinary factor alike.
#'
#' @param values A vector of aesthetic values
#' @return Character vector of the observed levels, in drawn order, with
#'   `NA_character_` last when the aesthetic has a missing value
#' @keywords internal
discrete_level_order <- function(values) {
  observed <- if (is.factor(values)) {
    levels(values)[levels(values) %in% unique(as.character(values))]
  } else {
    as.character(sort(unique(values)))
  }

  # A factor built with `exclude = NULL` carries the missing level itself,
  # wherever its author put it. That is a stated level order, and ggplot2
  # honours it, so it is left alone rather than moved to the end.
  if (anyNA(values) && !anyNA(observed)) {
    return(c(observed, NA_character_))
  }
  observed
}

#' The text ggplot2 draws for one level
#'
#' The missing level reads as the two characters "NA", which is what is
#' printed on its axis tick and in its legend key, so the announcement names
#' the same category a sighted reader is looking at. A level that is literally
#' the string "NA" reads the same way and is a different level: two categories,
#' two ticks, both saying "NA", which is what ggplot2 draws.
#'
#' @param level One level from `discrete_level_order()`
#' @return A length-1 character string, never `NA`
#' @keywords internal
level_label <- function(level) {
  if (length(level) != 1L || is.na(level)) {
    return("NA")
  }
  as.character(level)
}

#' Key aesthetic values so a missing one stays distinct from the string "NA"
#'
#' `paste()` stringifies `NA` to "NA", which collapses a missing value onto a
#' level that is literally those two characters -- so a grid keyed that way
#' cannot tell the two apart, and a duplicate test built on it does not see
#' the collision. Every present value is prefixed with "=", so the missing
#' key is one nothing else can produce.
#'
#' The missing key is a non-empty string on purpose. `""` would read as the
#' obvious sentinel and is a trap: R lets `"" %in% names(x)` answer TRUE and
#' then throws "subscript out of bounds" on `x[[""]]`, because empty is how a
#' name-less element is spelled. A lookup guarded by `%in%` -- which is how
#' both bar processors read their cells -- would pass the guard and abort.
#'
#' @param values A vector of aesthetic values
#' @return Character vector of keys, one per value, never `NA`
#' @keywords internal
level_keys <- function(values) {
  ifelse(is.na(values), "<missing>", paste0("=", as.character(values)))
}
