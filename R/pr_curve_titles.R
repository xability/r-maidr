#' Whether a line layer is a precision-recall curve by its axis titles
#'
#' A precision-recall curve drawn with Base R's `plot(recall, precision,
#' type = "l")` or lattice's `xyplot(precision ~ recall, type = "l")`
#' carries no evidence of what it is except its axis titles, which both
#' systems default to the names of the variables drawn. Titled exactly
#' `Recall` and `Precision` (any case, surrounding space ignored), with
#' every point a pair of numbers from 0 to 1, those titles are the claim, as
#' the column names `recall` and `precision` are for a ggplot2 line
#' ([layer_maps_pr_rates()]) and the axis titles are in py-maidr; the layer
#' is then the `pr_curve` trace, whose data is the line's own shape. Nothing
#' else is read as one, and nothing is when the bundled maidr.js predates
#' the trace ([pr_curve_trace_available()]).
#'
#' @param axes The layer's canonical axes list
#' @param data The layer's series: a list of lists of points with `x` and `y`
#' @return TRUE when the layer is a precision-recall curve by its titles
#' @keywords internal
titled_pr_curve <- function(axes, data) {
  axis_titled(axes, "x", "recall") &&
    axis_titled(axes, "y", "precision") &&
    pr_curve_trace_available() &&
    all_rate_pairs(data)
}

#' Whether an axis is titled with one word, ignoring case and surrounding
#' space
#'
#' @param axes A canonical axes list
#' @param axis `"x"` or `"y"`
#' @param word The title, lower case
#' @return TRUE when the axis carries that title
#' @keywords internal
axis_titled <- function(axes, axis, word) {
  label <- axes[[axis]]$label
  is.character(label) && length(label) == 1L && !is.na(label) &&
    identical(tolower(trimws(label)), word)
}

#' Whether every point of every series is a pair of fractions of one
#'
#' @param data A list of series, each a list of points with `x` and `y`
#' @return TRUE when there is at least one point and every `x` and `y` is a
#'   number from 0 to 1
#' @keywords internal
all_rate_pairs <- function(data) {
  rate <- function(value) {
    is.numeric(value) && length(value) == 1L && isTRUE(value >= 0 && value <= 1)
  }
  is.list(data) && length(data) > 0L &&
    all(vapply(data, function(series) {
      is.list(series) && length(series) > 0L &&
        all(vapply(series, function(point) rate(point$x) && rate(point$y), logical(1)))
    }, logical(1)))
}
