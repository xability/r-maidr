# The second per-layer author declaration, after `maidr_gantt()`. That file
# said a generic `maidr_declare()` should wait for a second ambiguous geom,
# and this is one -- but the mechanism it needs turned out to be different
# rather than a generalisation. A gantt is `geom_rect()`'s own aesthetics
# with a meaning attached, so it rides on the layer object. A ROC curve
# carries a value `geom_path()` has no aesthetic for, the decision threshold
# at each operating point, and the only way to get a column through
# `ggplot_build()` is to draw with a geom that names it. So the declaration
# is a geom: `GeomRoc` is `GeomPath` with `threshold` as an optional
# aesthetic, and `class(layer$geom)[1]` identifies the layer the way every
# other geom is identified in `R/ggplot2_adapter.R`, with no second carrier
# to keep in step.

#' A path geom that admits a `threshold` aesthetic
#'
#' `ggplot2::GeomPath` with one optional aesthetic added, so that a
#' `threshold` mapped to a `maidr_roc()` layer survives `ggplot_build()` as a
#' column of the built data rather than being dropped with `Ignoring unknown
#' aesthetics`. Nothing about the drawing changes; the aesthetic reaches no
#' grob.
#'
#' @format A ggproto object inheriting from `ggplot2::GeomPath`
#' @keywords internal
GeomRoc <- ggplot2::ggproto(
  "GeomRoc",
  ggplot2::GeomPath,
  optional_aes = c("threshold")
)

#' Declare that a path layer draws a ROC curve
#'
#' @description
#' `maidr_roc()` is `ggplot2::geom_path()` with two things added: the author
#' saying that the path is a receiver operating characteristic curve, and a
#' `threshold` aesthetic for the decision threshold each point was scored
#' at. A declared layer is read as a `roc` -- each point announced as its
#' false and true positive rates, its threshold and its height above the
#' chance diagonal, the area under each curve and the best operating point
#' in the description -- where the same path drawn with `geom_path()` or
#' `geom_line()` reads as a line, which says the rates and nothing a ROC
#' curve is drawn to say.
#'
#' Nothing about the picture changes: the geom draws exactly what
#' `geom_path()` draws, and `threshold` reaches no mark.
#'
#' @details
#' # What is asked of the data
#'
#' `x` is the false positive rate and `y` the true positive rate, both
#' fractions of one, in the order the curve is to be walked -- from (0, 0)
#' up, as `sklearn.metrics.roc_curve()` returns them, or from (1, 1) down, as
#' `pROC::coords()` does; the area is measured over the points sorted by `x`
#' either way. Several classifiers on one chart are several groups, split by
#' `colour`, `linetype` or `group` as a multi-series line is, and each is
#' announced by its group's name.
#'
#' # Curves maidr reads without a declaration
#'
#' Two idioms name their axes after the ROC's own vocabulary, and are read
#' as ROC curves as they stand: [pROC::ggroc()], whose `geom_line()` maps
#' `specificity` (or `1-specificity` with `legacy.axes = TRUE`) against
#' `sensitivity`, and `ggplot2::autoplot()` of a [yardstick::roc_curve()],
#' whose `geom_path()` maps `1 - specificity` against `sensitivity`. Where
#' `x` is `specificity` itself -- pROC's default, drawn on a reversed axis --
#' the announced rate is `1 - specificity` and the axis is named so, because
#' the height above chance is measured against the false positive rate and a
#' rate read off a reversed axis would put every point on the wrong side of
#' the diagonal. Neither idiom carries thresholds or the area into the plot,
#' so the area is measured from the points and no threshold is announced;
#' `maidr_roc()` is how an author supplies both.
#'
#' # What it costs not to declare
#'
#' A `geom_line()` of rates under any other column names keeps the line
#' reading it has today, deliberately: every chart already written keeps
#' exactly the reading it has.
#'
#' @param mapping Aesthetics, as for [ggplot2::geom_path()]: `x` (the false
#'   positive rate) and `y` (the true positive rate) are required, and
#'   `threshold` may name the decision threshold at each point. Every other
#'   path aesthetic (`colour`, `linetype`, `group`, ...) behaves exactly as
#'   it does there.
#' @param data The layer's data, as for [ggplot2::geom_path()].
#' @param position Position adjustment, as for [ggplot2::geom_path()].
#' @param ... Other arguments passed to the layer, as for
#'   [ggplot2::geom_path()] -- except `stat`, which is fixed at
#'   `"identity"`: a declared curve is always drawn from the author's own
#'   rates.
#' @param auc The area under each curve as the author computed it -- with
#'   [pROC::auc()], `yardstick::roc_auc()` or by hand -- announced in the
#'   description in place of the trapezoid rule over the drawn points. One
#'   number for a single curve; for several, a vector named by the groups'
#'   names, or unnamed and in the groups' sorted order. `NULL` (the default)
#'   measures the area from the points, which is what the trapezoid rule
#'   gives and what those functions compute for an empirical curve.
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
#'     fpr = c(0, 0.05, 0.1, 0.2, 0.35, 0.6, 1),
#'     tpr = c(0, 0.55, 0.75, 0.86, 0.93, 0.98, 1),
#'     cutoff = c(1, 0.8, 0.6, 0.45, 0.3, 0.15, 0)
#'   )
#'
#'   roc <- ggplot2::ggplot(curve) +
#'     maidr_roc(ggplot2::aes(x = fpr, y = tpr, threshold = cutoff)) +
#'     ggplot2::geom_abline(linetype = "dashed") +
#'     ggplot2::labs(x = "False positive rate", y = "True positive rate")
#'
#'   # The same path written with `geom_path()` draws the same chart and is
#'   # read as a line: the rates, and none of what a ROC curve is read for.
#'   if (interactive()) {
#'     show(roc)
#'   }
#' }
#'
#' @seealso [maidr_gantt()], the other per-layer declaration; [save_html()]
#'   and [show()] for rendering the declared chart
#' @export
maidr_roc <- function(mapping = NULL,
                      data = NULL,
                      position = "identity",
                      ...,
                      auc = NULL,
                      na.rm = FALSE,
                      show.legend = NA,
                      inherit.aes = TRUE) {
  if (!is.null(auc) && (!is.numeric(auc) || length(auc) == 0L || anyNA(auc))) {
    stop("`auc` must be NULL or a numeric vector with no missing values.")
  }

  # `ggplot2::layer()` directly, as `maidr_gantt()` calls it: the geom is
  # what identifies the layer, and `auc` is consumed here rather than passed
  # down, where `layer()` would drop a parameter neither the geom nor the
  # stat knows and say `Ignoring unknown parameters` on the way.
  layer <- ggplot2::layer(
    stat = "identity",
    geom = GeomRoc,
    data = data,
    mapping = mapping,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(na.rm = na.rm, ...)
  )

  # On the layer instance, where `maidr_gantt()` keeps its declaration and
  # for the same reason: `GeomRoc` is shared by every declared layer, and a
  # `LayerInstance` is an environment of its own.
  layer$maidr_auc <- auc
  layer
}
