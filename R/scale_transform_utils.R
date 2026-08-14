#' Read a ggplot2 scale's transformation
#'
#' ggplot2 3.5 renamed the accessor; the field it reads is the same one.
#' Returns NULL when the scale carries no transformation at all, which is
#' the case for a discrete scale.
#'
#' @param scale A panel scale from \code{built$layout$panel_scales_x} or
#'   \code{panel_scales_y}
#' @return The transformation object, or NULL
#' @keywords internal
scale_transformation <- function(scale) {
  if (is.null(scale)) {
    return(NULL)
  }
  transformation <- tryCatch(scale$get_transformation(), error = function(e) NULL)
  if (is.null(transformation)) {
    transformation <- tryCatch(scale$trans, error = function(e) NULL)
  }
  transformation
}

#' The transformation applied to one axis of a built plot
#'
#' @param built Built plot from \code{ggplot2::ggplot_build()}
#' @param axis \code{"x"} or \code{"y"}
#' @param panel_id Panel index for faceted plots, or NULL for the first
#' @return The transformation object, or NULL when there is none to undo
#' @keywords internal
panel_transformation <- function(built, axis = "x", panel_id = NULL) {
  if (is.null(built) || is.null(built$layout)) {
    return(NULL)
  }
  scales <- if (identical(axis, "y")) {
    built$layout$panel_scales_y
  } else {
    built$layout$panel_scales_x
  }
  if (is.null(scales) || length(scales) == 0) {
    return(NULL)
  }

  index <- 1L
  if (!is.null(panel_id)) {
    candidate <- suppressWarnings(as.integer(panel_id))
    # Free scales give one entry per panel; fixed scales give one for all,
    # and a panel id past the end there is not an error but the shared scale.
    if (!is.na(candidate) && candidate >= 1L && candidate <= length(scales)) {
      index <- candidate
    }
  }

  transformation <- scale_transformation(scales[[index]])
  if (is.null(transformation) || identical(transformation$name, "identity")) {
    return(NULL)
  }
  transformation
}

#' Put built positions back into the space the reader sees
#'
#' ggplot2 applies a scale transformation \emph{before} the stat runs, so
#' \code{ggplot_build()}'s data is in transformed space. Read straight
#' through, a \code{scale_x_log10()} chart announces log10 coordinates under
#' the original axis label: a scatter of prices from $5.50 to $9,403 reads as
#' 0.744 to 3.973 under "Price (USD)" (#158).
#'
#' Nothing is missing from such a chart and nothing errors. The structure is
#' right, the point count is right, the label is right, and the numbers are
#' false -- with no signal a reader could catch, since "these look small" is
#' not checkable without the chart you cannot see.
#'
#' \code{coord_trans()} needs no special case and deliberately gets none. It
#' transforms at draw time, after the stat, so its built data is already in
#' data space \emph{and} its scale reports \code{identity} -- the same
#' comparison that skips an untransformed chart skips it too. Testing for
#' "is there a log axis" would have inverted it wrongly.
#'
#' Applied at the point a value is emitted rather than to the frame as a
#' whole, and that placement is load-bearing: \code{scale_*_reverse()}
#' negates, so a frame inverted before a sort would order rows opposite to
#' the way they were drawn, and selectors indexed by that order would land on
#' the wrong element. Ordering follows the drawn scale; only the announced
#' number is put back.
#'
#' @param values Positions read from the built data
#' @param built Built plot from \code{ggplot2::ggplot_build()}
#' @param axis \code{"x"} or \code{"y"}
#' @param panel_id Panel index for faceted plots, or NULL for the first
#' @return The values in data space, unchanged when there is nothing to undo
#' @keywords internal
untransform_positions <- function(values, built, axis = "x", panel_id = NULL) {
  if (!is.numeric(values) || length(values) == 0) {
    # A discrete position is an index into the scale's levels, not a
    # measurement, and has no transformation to undo.
    return(values)
  }
  transformation <- panel_transformation(built, axis, panel_id)
  if (is.null(transformation) || !is.function(transformation$inverse)) {
    return(values)
  }
  restored <- tryCatch(transformation$inverse(values), error = function(e) NULL)
  if (is.null(restored) || length(restored) != length(values)) {
    return(values)
  }
  restored
}
