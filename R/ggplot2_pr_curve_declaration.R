# The third per-layer author declaration, built the way `maidr_roc()` is and
# for the same reason: a precision-recall curve is a path of rates, it
# carries a value `geom_path()` has no aesthetic for (the decision threshold
# at each point), and the only way to get that column through
# `ggplot_build()` is to draw with a geom that names it. `GeomPrCurve` is
# `GeomPath` with `threshold` as an optional aesthetic, and
# `class(layer$geom)[1]` identifies the layer in `R/ggplot2_adapter.R`.

#' A path geom for precision-recall curves that admits a `threshold`
#' aesthetic
#'
#' `ggplot2::GeomPath` with one optional aesthetic added, so that a
#' `threshold` mapped to a `maidr_pr_curve()` layer survives
#' `ggplot_build()` as a column of the built data. Nothing about the drawing
#' changes; the aesthetic reaches no grob.
#'
#' @format A ggproto object inheriting from `ggplot2::GeomPath`
#' @keywords internal
GeomPrCurve <- ggplot2::ggproto(
  "GeomPrCurve",
  ggplot2::GeomPath,
  optional_aes = c("threshold")
)

#' Whether the bundled maidr.js can build a `pr_curve` trace
#'
#' The `pr_curve` trace first shipped in maidr.js 4.14.0. Emitted to an older
#' bundle it is fatal rather than declined, as `roc_trace_available()`
#' explains for the ROC trace, so until `MAIDR_VERSION` reaches 4.14.0 a
#' precision-recall curve keeps the line reading it had.
#'
#' @return TRUE when the pinned bundle carries the trace
#' @keywords internal
pr_curve_trace_available <- function() {
  utils::compareVersion(MAIDR_VERSION, "4.14.0") >= 0
}

#' Declare that a path layer draws a precision-recall curve
#'
#' @description
#' `maidr_pr_curve()` is `ggplot2::geom_path()` with three things added: the
#' author saying that the path is a precision-recall curve, a `threshold`
#' aesthetic for the decision threshold each point was scored at, and the
#' share of positives in the data -- the precision a classifier that guesses
#' keeps at every recall, which every point of the curve is read against. A
#' declared layer is read as a `pr_curve`: each point announced as its recall
#' and precision, its threshold and how far its precision sits above that
#' baseline, with the average precision of each curve and the point with the
#' best F1 score in the description. The same path drawn with `geom_path()`
#' or `geom_line()` reads as a line, which says the rates and nothing a
#' precision-recall curve is drawn to say.
#'
#' Nothing about the picture changes: the geom draws exactly what
#' `geom_path()` draws, and `threshold` reaches no mark.
#'
#' The `pr_curve` layer type \[experimental\] is one of the experimental plot
#' types: it has not been through a user study, and its reading may change
#' without a deprecation period. See "Experimental Plot Types" in the README.
#'
#' @details
#' # What is asked of the data
#'
#' `x` is the recall and `y` the precision, both fractions of one, in any
#' order: the average precision is measured over the points sorted by
#' recall. Several classifiers on one chart are several groups, split by
#' `colour`, `linetype` or `group` as a multi-series line is, and each is
#' announced by its group's name.
#'
#' # Curves maidr reads without a declaration
#'
#' `ggplot2::autoplot()` of a [yardstick::pr_curve()] draws a `geom_path()`
#' that maps `recall` against `precision`, and is read as a precision-recall
#' curve as it stands -- as is any `geom_line()` or `geom_path()` of columns
#' named `recall` and `precision`. Such a curve carries neither the
#' thresholds nor the share of positives into the plot, so no threshold is
#' announced, the average precision is measured from the points, and the
#' points are not read against a baseline; `maidr_pr_curve()` is how an
#' author supplies them.
#'
#' A Base R `plot(recall, precision, type = "l")` (or `type = "s"`) and a
#' lattice `xyplot(precision ~ recall, type = "l")` are read the same way
#' when their axes are titled `Recall` and `Precision` -- which both take
#' from the variables' names unless `xlab` and `ylab` say otherwise -- and
#' every value is a fraction of one.
#'
#' # Until the bundled maidr.js carries the trace
#'
#' The `pr_curve` trace shipped in maidr.js 4.14.0. While the copy this
#' package bundles is older (see `maidr:::MAIDR_VERSION`), a declared or
#' detected curve is read as a line, so that every chart keeps rendering.
#'
#' @param mapping Aesthetics, as for [ggplot2::geom_path()]: `x` (the recall)
#'   and `y` (the precision) are required, and `threshold` may name the
#'   decision threshold at each point. Every other path aesthetic (`colour`,
#'   `linetype`, `group`, ...) behaves exactly as it does there.
#' @param data The layer's data, as for [ggplot2::geom_path()].
#' @param position Position adjustment, as for [ggplot2::geom_path()].
#' @param ... Other arguments passed to the layer, as for
#'   [ggplot2::geom_path()] -- except `stat`, which is fixed at
#'   `"identity"`.
#' @param prevalence The share of positives in the data each curve was scored
#'   on, from 0 to 1: the height of the chance baseline. One number for a
#'   single curve or for curves scored on the same data; for several scored
#'   on different data, a vector named by the groups' names, or unnamed and in
#'   the groups' sorted order. `NULL` (the default) reads the curve without a
#'   baseline.
#' @param ap The average precision of each curve as the author computed it --
#'   with `yardstick::average_precision()`, say -- announced in the
#'   description in place of the step-wise area over the drawn points. Given
#'   as `prevalence` is. `NULL` (the default) measures it from the points.
#' @param na.rm If `FALSE` (the default), rows with missing values are
#'   removed with a warning.
#' @param show.legend Whether this layer is included in the legends.
#' @param inherit.aes If `FALSE`, the plot's default aesthetics are not
#'   inherited.
#'
#' @return A ggplot2 layer, to be added to a plot with `+`.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   curve <- data.frame(
#'     recall = c(0, 0.2, 0.4, 0.6, 0.8, 1),
#'     precision = c(1, 1, 0.89, 0.8, 0.62, 0.3),
#'     cutoff = c(1, 0.9, 0.75, 0.6, 0.4, 0)
#'   )
#'
#'   pr <- ggplot2::ggplot(curve) +
#'     maidr_pr_curve(
#'       ggplot2::aes(x = recall, y = precision, threshold = cutoff),
#'       prevalence = 0.3
#'     ) +
#'     ggplot2::geom_hline(yintercept = 0.3, linetype = "dashed") +
#'     ggplot2::labs(x = "Recall", y = "Precision")
#'
#'   if (interactive()) {
#'     show(pr)
#'   }
#' }
#'
#' @seealso [maidr_roc()], the ROC curve's declaration; [save_html()] and
#'   [show()] for rendering the declared chart
#' @export
maidr_pr_curve <- function(mapping = NULL,
                           data = NULL,
                           position = "identity",
                           ...,
                           prevalence = NULL,
                           ap = NULL,
                           na.rm = FALSE,
                           show.legend = NA,
                           inherit.aes = TRUE) {
  check_rate <- function(value, name) {
    if (!is.null(value) && (!is.numeric(value) || length(value) == 0L ||
      anyNA(value) || any(value < 0 | value > 1))) {
      stop(
        "`", name, "` must be NULL or a numeric vector of values from 0 to 1."
      )
    }
  }
  check_rate(prevalence, "prevalence")
  check_rate(ap, "ap")

  # `ggplot2::layer()` directly, as `maidr_roc()` calls it, so `prevalence`
  # and `ap` are consumed here rather than dropped by `layer()` with a
  # warning.
  layer <- ggplot2::layer(
    stat = "identity",
    geom = GeomPrCurve,
    data = data,
    mapping = mapping,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(na.rm = na.rm, ...)
  )

  # On the layer instance, as `maidr_roc()` keeps its `auc`.
  layer$maidr_prevalence <- prevalence
  layer$maidr_ap <- ap
  layer
}
