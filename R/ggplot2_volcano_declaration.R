# The fourth and fifth per-layer author declarations, built the way
# `maidr_roc()` is. A volcano or a Manhattan plot is a scatter, and nothing in
# its points says which side of which line matters: the threshold is a
# convention of the field (-log10(p) at 1.3, genome-wide significance at 7.3,
# a raw p axis running the other way), so maidr.js deliberately has no default
# and the author is asked for it. Each point also carries what a scatter has
# no aesthetic for -- the gene or SNP it stands for, and the chromosome it sits
# on -- and the only way to get those through `ggplot_build()` is a geom that
# names them. `GeomVolcano` and `GeomManhattan` are `GeomPoint` with `label`
# and `region` as optional aesthetics, and `class(layer$geom)[1]` identifies
# the layer in `R/ggplot2_adapter.R`.

#' Point geoms for volcano and Manhattan plots
#'
#' `ggplot2::GeomPoint` with two optional aesthetics added, `label` and
#' `region`, so that both survive `ggplot_build()` as columns of the built
#' data rather than being dropped with `Ignoring unknown aesthetics`. Nothing
#' about the drawing changes; neither aesthetic reaches a grob.
#'
#' @format ggproto objects inheriting from `ggplot2::GeomPoint`
#' @keywords internal
#' @name GeomVolcano
GeomVolcano <- ggplot2::ggproto(
  "GeomVolcano",
  ggplot2::GeomPoint,
  optional_aes = c("label", "region")
)

#' @rdname GeomVolcano
#' @keywords internal
GeomManhattan <- ggplot2::ggproto(
  "GeomManhattan",
  ggplot2::GeomPoint,
  optional_aes = c("label", "region")
)

#' The `thresholdOptions` a volcano or Manhattan layer declares
#'
#' Checked here, when the layer is built, so that a threshold the core would
#' ignore -- a string, a vector, `NA` -- is an error the author sees rather
#' than a chart that silently claims nothing is significant.
#'
#' @param significance The cutoff on the y axis
#' @param direction `"above"` or `"below"`
#' @param effect The cutoff on the magnitude of x, or NULL
#' @param caller The declaring function's name, for the error messages
#' @return A list shaped as maidr.js's `ThresholdOptions`
#' @keywords internal
volcano_threshold_options <- function(significance,
                                      direction,
                                      effect = NULL,
                                      caller = "maidr_volcano") {
  is_number <- function(value) {
    is.numeric(value) && length(value) == 1L && is.finite(value)
  }
  if (!is_number(significance)) {
    stop(
      "`significance` must be one finite number: the cutoff on the y axis, ",
      "in the units the axis is read in (for example -log10(0.05) on a ",
      "-log10(p) axis). ", caller, "() has no default, because a guessed ",
      "line would put every point on the wrong side of it.",
      call. = FALSE
    )
  }
  if (!is.null(effect) && (!is_number(effect) || effect < 0)) {
    stop(
      "`effect` must be NULL or one finite, non-negative number: the cutoff ",
      "on the magnitude of x (for example 1 for a two-fold change on a log2 ",
      "axis).",
      call. = FALSE
    )
  }

  options <- list(
    significance = as.numeric(significance),
    significanceDirection = direction
  )
  if (!is.null(effect)) {
    options$effect <- as.numeric(effect)
  }
  options
}

#' Build a declared volcano or Manhattan layer
#'
#' `ggplot2::layer()` directly, as `maidr_roc()` calls it: the geom is what
#' identifies the layer, and the thresholds are consumed here rather than
#' passed down, where `layer()` would drop them with `Ignoring unknown
#' parameters`. The thresholds are kept on the layer instance, which is an
#' environment of its own, where `maidr_roc()` keeps its `auc`.
#'
#' @param geom `GeomVolcano` or `GeomManhattan`
#' @param thresholds The list [volcano_threshold_options()] returned
#' @inheritParams maidr_volcano
#' @return A ggplot2 layer
#' @keywords internal
declared_threshold_layer <- function(geom,
                                     thresholds,
                                     mapping,
                                     data,
                                     position,
                                     na.rm,
                                     show.legend,
                                     inherit.aes,
                                     ...) {
  layer <- ggplot2::layer(
    stat = "identity",
    geom = geom,
    data = data,
    mapping = mapping,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(na.rm = na.rm, ...)
  )
  layer$maidr_threshold_options <- thresholds
  layer
}

#' Declare that a point layer draws a volcano plot
#'
#' @description
#' `maidr_volcano()` is `ggplot2::geom_point()` with three things added: the
#' author saying that the points are a volcano plot, the significance
#' threshold the chart is read against, and two aesthetics for what each
#' point is -- `label` (the gene) and `region` (any grouping announced
#' alongside it, such as up- or down-regulated). A declared layer is read as
#' a `volcano`: the description says how many points clear the threshold and
#' names them, a rotor mode steps through only those points, and
#' every point is announced with its label and region. The same points drawn
#' with `geom_point()` read as a scatter, which says two coordinates and
#' withholds which gene they belong to.
#'
#' Nothing about the picture changes: the geom draws exactly what
#' `geom_point()` draws, and neither `label` nor `region` reaches a mark.
#' Draw the threshold lines yourself, with `geom_hline()` and `geom_vline()`;
#' maidr leaves reference lines out of the reading.
#'
#' The `volcano` layer type \[experimental\] is one of the experimental plot
#' types: it has not been through a user study, and its reading may change
#' without a deprecation period. See "Experimental Plot Types" in the README.
#'
#' @details
#' # The threshold is stated, never guessed
#'
#' A point is significant when its y is at or above `significance` (at or
#' below it with `direction = "below"`) and, when `effect` is given, the
#' magnitude of its x is at least `effect` -- a fold change of -2 is as large
#' an effect as one of +2. Both are in the units the axes are announced in,
#' which are the data's own: `significance = -log10(0.05)` for `y =
#' -log10(pvalue)`, and `significance = 0.05, direction = "below"` for a raw
#' p value, even on a log-scaled y axis, whose points are announced as the p
#' values they are.
#'
#' There is no default, because these charts sit on transformed axes whose
#' conventions differ by field and by tool, and a line drawn in the wrong
#' place would put every point on the wrong side of it without saying so.
#'
#' @param mapping Aesthetics, as for [ggplot2::geom_point()]: `x` (the effect
#'   size, such as a log2 fold change) and `y` (the significance, such as
#'   -log10 of the p value) are required. `label` may name each point (the
#'   gene) and `region` the group it belongs to; both are announced with the
#'   point. Every other point aesthetic (`colour`, `size`, `alpha`, ...)
#'   behaves exactly as it does there.
#' @param data The layer's data, as for [ggplot2::geom_point()].
#' @param position Position adjustment, as for [ggplot2::geom_point()].
#' @param ... Other arguments passed to the layer, as for
#'   [ggplot2::geom_point()] -- except `stat`, which is fixed at
#'   `"identity"`: a declared layer is always drawn from the author's own
#'   points.
#' @param significance The significance cutoff on the y axis, one number in
#'   the units y is announced in. Required.
#' @param effect The effect-size cutoff, applied to the magnitude of x, or
#'   `NULL` (the default) for none.
#' @param direction Which side of `significance` the significant points are
#'   on: `"above"` (the default) for a -log10(p) axis, `"below"` for a raw p
#'   value.
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
#'   genes <- data.frame(
#'     gene = c("TP53", "MYC", "EGFR", "BRCA1", "KRAS", "PTEN", "GAPDH"),
#'     log2fc = c(2.8, -3.1, 1.6, -0.4, 0.3, -2.2, 0.1),
#'     padj = c(1e-8, 1e-6, 0.02, 0.4, 0.7, 1e-4, 0.9)
#'   )
#'
#'   volcano <- ggplot2::ggplot(
#'     genes,
#'     ggplot2::aes(x = log2fc, y = -log10(padj))
#'   ) +
#'     maidr_volcano(
#'       ggplot2::aes(label = gene),
#'       significance = -log10(0.05),
#'       effect = 1
#'     ) +
#'     ggplot2::geom_hline(yintercept = -log10(0.05), linetype = "dashed") +
#'     ggplot2::geom_vline(xintercept = c(-1, 1), linetype = "dashed") +
#'     ggplot2::labs(x = "log2 fold change", y = "-log10 adjusted p")
#'
#'   if (interactive()) {
#'     show(volcano)
#'   }
#' }
#'
#' @seealso [maidr_manhattan()] for a Manhattan plot; [save_html()] and
#'   [show()] for rendering the declared chart
#' @export
maidr_volcano <- function(mapping = NULL,
                          data = NULL,
                          position = "identity",
                          ...,
                          significance,
                          effect = NULL,
                          direction = c("above", "below"),
                          na.rm = FALSE,
                          show.legend = NA,
                          inherit.aes = TRUE) {
  direction <- match.arg(direction)
  thresholds <- volcano_threshold_options(
    if (missing(significance)) NULL else significance,
    direction,
    effect,
    caller = "maidr_volcano"
  )
  declared_threshold_layer(
    GeomVolcano, thresholds,
    mapping = mapping, data = data, position = position, na.rm = na.rm,
    show.legend = show.legend, inherit.aes = inherit.aes, ...
  )
}

#' Declare that a point layer draws a Manhattan plot
#'
#' @description
#' `maidr_manhattan()` is `ggplot2::geom_point()` with three things added:
#' the author saying that the points are a Manhattan plot, the significance
#' threshold the chart is read against, and two aesthetics for what each
#' point is -- `label` (the SNP or variant) and `region` (its chromosome). A
#' declared layer is read as a `manhattan`: the description says how many
#' points clear the threshold and names them, a rotor mode steps
#' through only those points, and every point is announced with its label
#' and chromosome. The same points drawn with `geom_point()` read as a
#' scatter of tens of thousands of positions, walked one at a time.
#'
#' Nothing about the picture changes: the geom draws exactly what
#' `geom_point()` draws, and neither `label` nor `region` reaches a mark.
#'
#' The `manhattan` layer type \[experimental\] is one of the experimental
#' plot types: it has not been through a user study, and its reading may
#' change without a deprecation period. See "Experimental Plot Types" in the
#' README.
#'
#' @details
#' `x` is the position along the genome -- usually each variant's position
#' offset by the length of the chromosomes before it, with the axis labelled
#' by chromosome through `scale_x_continuous(breaks = , labels = )` -- and `y`
#' the significance. A point is significant when its y is at or above
#' `significance` (at or below it with `direction = "below"`), in the units y
#' is announced in: `significance = -log10(5e-8)` for genome-wide significance
#' on a -log10(p) axis. There is no default, for the reason
#' [maidr_volcano()] gives.
#'
#' @inheritParams maidr_volcano
#' @param mapping Aesthetics, as for [ggplot2::geom_point()]: `x` (the
#'   position along the genome) and `y` (the significance, such as -log10 of
#'   the p value) are required. `label` may name each point (the SNP) and
#'   `region` its chromosome; both are announced with the point. Every other
#'   point aesthetic (`colour`, `size`, `alpha`, ...) behaves exactly as it
#'   does there.
#'
#' @return A ggplot2 layer, to be added to a plot with `+`.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   snps <- data.frame(
#'     snp = paste0("rs", 1:8),
#'     chr = rep(c("1", "2"), each = 4),
#'     pos = c(1, 2, 3, 4, 6, 7, 8, 9),
#'     p = c(0.3, 2e-9, 0.01, 0.6, 0.05, 0.8, 4e-10, 0.2)
#'   )
#'
#'   manhattan <- ggplot2::ggplot(
#'     snps,
#'     ggplot2::aes(x = pos, y = -log10(p), colour = chr)
#'   ) +
#'     maidr_manhattan(
#'       ggplot2::aes(label = snp, region = chr),
#'       significance = -log10(5e-8)
#'     ) +
#'     ggplot2::geom_hline(yintercept = -log10(5e-8), linetype = "dashed") +
#'     ggplot2::scale_x_continuous(breaks = c(2.5, 7.5), labels = c("1", "2")) +
#'     ggplot2::labs(x = "Chromosome", y = "-log10 p")
#'
#'   if (interactive()) {
#'     show(manhattan)
#'   }
#' }
#'
#' @seealso [maidr_volcano()] for a volcano plot; [save_html()] and [show()]
#'   for rendering the declared chart
#' @export
maidr_manhattan <- function(mapping = NULL,
                            data = NULL,
                            position = "identity",
                            ...,
                            significance,
                            direction = c("above", "below"),
                            na.rm = FALSE,
                            show.legend = NA,
                            inherit.aes = TRUE) {
  direction <- match.arg(direction)
  thresholds <- volcano_threshold_options(
    if (missing(significance)) NULL else significance,
    direction,
    caller = "maidr_manhattan"
  )
  declared_threshold_layer(
    GeomManhattan, thresholds,
    mapping = mapping, data = data, position = position, na.rm = na.rm,
    show.legend = show.legend, inherit.aes = inherit.aes, ...
  )
}
