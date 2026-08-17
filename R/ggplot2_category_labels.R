# The name a discrete position stands for.
#
# ggplot2 maps a discrete scale onto consecutive integers and marks the result
# `mapped_discrete`, so a point drawn in category "a" arrives as `x = 1`. That
# integer is what a point layer announced. Measured on a three-category chart
# whose axis is labelled `g` and whose ticks read `a`, `b`, `c`:
#
#     geom_jitter(x = g)   first point  x = 1 (mapped_discrete)
#     geom_point(x = g)    first point  x = 1 (mapped_discrete)
#
# A reader heard "g is 1" where the chart says "a". Which is not a partial
# reading -- the number is a slot index, and announcing it under the axis'
# label reports an internal coordinate as though it were the observation.
#
# The name travels alongside the position rather than replacing it, because
# the core sorts on the number, measures distance with it and groups columns
# by it: `'a' - 'b'` is NaN, so a string in `x` would give an unstable sort and
# a highlight that lands nowhere. That is the shape `ScatterPoint.xLabel` was
# added for (xability/maidr#927), and the Python binding emits the same fields
# for `sns.stripplot` and `sns.swarmplot` (xability/py-maidr#439).

#' Positions to category names for one axis of one panel
#'
#' @param built The built ggplot2 object
#' @param axis `"x"` or `"y"`
#' @param panel_id The panel to read, defaulting to the first
#' @return A named character vector keyed by position (as character), or
#'   `NULL` when the axis is continuous. Empty names are dropped, so a scale
#'   with a blank label yields the number rather than a blank announcement.
#' @keywords internal
discrete_axis_labels <- function(built, axis = "x", panel_id = NULL) {
  panel_index <- if (is.null(panel_id)) 1L else as.integer(panel_id)
  params <- tryCatch(
    built$layout$panel_params[[panel_index]],
    error = function(e) NULL
  )
  if (is.null(params)) {
    return(NULL)
  }

  view <- params[[axis]]
  if (is.null(view) || is.null(view$get_breaks) || is.null(view$get_labels)) {
    return(NULL)
  }

  # `is_discrete()` is the scale's own answer and the only one worth trusting.
  # A continuous axis has breaks and labels too -- "0", "25", "1.00" -- but
  # those are formatted renderings of the numbers rather than names for them,
  # so substituting one would cost the value both its type and its precision.
  # The same rule the Python binding draws from matplotlib's `UnitData`.
  discrete <- tryCatch(isTRUE(view$is_discrete()), error = function(e) FALSE)
  if (!discrete) {
    return(NULL)
  }

  # On a discrete scale `get_breaks()` returns the *level names*, and carries
  # the integer positions in a `pos` attribute -- so the numbers have to come
  # from there. `break_positions()` is the other candidate and is the wrong
  # one: it rescales to 0..1 (0.1875, 0.5, 0.8125 for three levels), which is
  # not the space the layer's own `x` is in.
  breaks <- tryCatch(view$get_breaks(), error = function(e) NULL)
  labels <- tryCatch(as.character(view$get_labels()), error = function(e) NULL)
  positions <- suppressWarnings(as.numeric(attr(breaks, "pos")))
  if (is.null(labels) || length(positions) != length(labels)) {
    return(NULL)
  }

  keep <- !is.na(positions) & !is.na(labels) & nzchar(labels)
  if (!any(keep)) {
    return(NULL)
  }

  stats::setNames(labels[keep], as.character(positions[keep]))
}

#' The name at one position, or `NULL`
#'
#' A point drawn *off* an integer is still in that integer's category.
#' `position_dodge` shifts a point sideways to make room for a sibling series
#' and `position_jitter` scatters it, and both displacements stay *within* the
#' category's own slot -- so the tick it was moved from is the category it is
#' in, not a category it is being falsely assigned to. Measured on a dodged
#' scatter over two groups, `x` arrives as 0.875, 1.125, 1.875, 2.125, and an
#' exact match names none of the 24 points.
#'
#' Rounding is what recovers them, which is the answer the Python binding
#' reached for the same situation: "a point drawn off one is a group a `dodge`
#' shifted aside to make room for its neighbour -- still that group, and still
#' named by the tick it was moved from."
#'
#' Bounded at half a tick, which is what keeps it honest. ggplot2 keeps both
#' displacements inside the slot -- a dodge divides the category's width, and
#' `position_jitter`'s default reaches 40% of the resolution -- so anything
#' further out is not a displaced member of that category and is left unnamed.
#' The `is_discrete()` gate above does the rest: on a continuous axis there are
#' no names to round onto, so a measurement cannot be renamed after whichever
#' tick it happens to fall nearest.
#'
#' @param position A drawn coordinate
#' @param labels The map from [discrete_axis_labels()]
#' @return The name, or `NULL` when there is none
#' @keywords internal
category_at <- function(position, labels) {
  if (is.null(labels) || length(position) != 1L) {
    return(NULL)
  }

  # Only a numeric position has a name to look up, and coercing one that is
  # not would warn "NAs introduced by coercion" once per point. Which is how
  # the faceted disagreement surfaced: that path used to replace the position
  # with the category it indexed before emission, so `x` arrived here as the
  # character "a" rather than the number 1, and adding this lookup took the
  # suite from 8 warnings to 228. The point processor no longer relabels
  # (#178), so both paths now hand this a number -- `mapped_discrete` inherits
  # numeric, so a discrete position passes.
  #
  # The guard stays because it is the honest answer for any caller: a position
  # that is not a number has no slot to be nearest to, and a bar layer's `x`
  # is legitimately `string | number` in the grammar.
  if (!is.numeric(position) || is.na(position)) {
    return(NULL)
  }

  # Single-bracket, not `[[`: a position with no name is the ordinary case
  # here (an axis whose breaks are a subset of its levels), and `[[` *throws*
  # "subscript out of bounds" on one where `[` answers NA.
  exact <- labels[as.character(as.numeric(position))]
  if (!is.na(exact)) {
    return(unname(exact))
  }

  slots <- suppressWarnings(as.numeric(names(labels)))
  distance <- abs(slots - as.numeric(position))
  nearest <- which.min(distance)
  if (!length(nearest) || is.na(distance[nearest]) || distance[nearest] >= 0.5) {
    return(NULL)
  }
  unname(labels[nearest])
}
