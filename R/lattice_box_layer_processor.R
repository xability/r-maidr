#' lattice Box Layer Processor
#'
#' @description
#' Reads a `bwplot()` panel as a `box` layer: one box per level the panel
#' holds, each with its five statistics and its outliers.
#'
#' The statistics are computed the way `panel.bwplot()` computes them --
#' its `stats` function, `boxplot.stats()` unless the chart gave another,
#' with the chart's `coef` and `do.out` -- over the levels the panel holds,
#' so a level with no rows in a packet has no box there. A box's whiskers
#' end at `min` and `max`, and its outliers are the values outside them, in
#' the order they were drawn; an outlier lattice cannot place, such as a zero
#' on a log scale, draws no mark and is not read.
#'
#' On a log scale lattice hands the panel the logarithms and computes the
#' statistics over them, so the box is drawn at those; each statistic is
#' then read back on the data's own scale, the one the axis is labelled in,
#' as the other lattice readings are ([lattice_untransform()]). On a date or
#' date-time axis it is the instant it stands for, which the axis' time
#' format announces as a date (`lattice_time_milliseconds()`).
#'
#' **Selectors.** `panel.bwplot()` draws each part of every box in one grob:
#' the boxes as polygons, the whisker caps as segments (the lower caps
#' first, then the upper), the medians as points -- or segments, with
#' `pch = "|"` -- and the outliers box by box. Each part of each box is
#' named by its own id.
#'
#' A horizontal panel -- `factor ~ numeric`, the default -- runs its levels
#' up the vertical axis; the layer is emitted top first, which the frontend
#' turns round so a reader starts at the bottom, as every other horizontal
#' box chart in this package does ([reverse_horizontal_box_layer()]).
#'
#' @keywords internal
LatticeBoxLayerProcessor <- R6::R6Class(
  "LatticeBoxLayerProcessor",
  inherit = LatticeLayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The trellis object
    #' @param layout The figure's layout: title and axis labels
    #' @param built Unused for lattice
    #' @param gt The drawn chart
    #' @param grob_id Unused for lattice
    #' @param panel_id Unused for lattice
    #' @param panel_ctx The panel the layer was drawn in
    #' @param layer_info The layer: its type, role and grobs
    #' @return The layer, or NULL when its marks cannot be read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      args <- panel_ctx$args
      horizontal <- isTRUE(args[["horizontal"]])
      category <- if (horizontal) args[["y"]] else args[["x"]]
      value <- as.numeric(if (horizontal) args[["x"]] else args[["y"]])
      code <- as.numeric(category)
      if (all(is.na(value) | is.na(code))) {
        return(list(data = list()))
      }

      drawn <- vapply(layer_info$grobs, function(e) e$what, character(1))
      part <- function(what) {
        sprintf(
          "%s.bwplot.%s.panel.%d.%d",
          LATTICE_PREFIX, what, panel_ctx$column, panel_ctx$row
        )
      }
      if (!all(c("bwplot.box.polygon", "bwplot.cap.segments") %in% drawn)) {
        return(NULL)
      }
      median_part <- if ("bwplot.dot.segments" %in% drawn) "dot.segments" else "dot.points"

      levels_drawn <- args[["levels.fos"]]
      if (is.null(levels_drawn)) {
        levels_drawn <- sort(unique(code))
      }
      stats <- args[["stats"]]
      if (is.null(stats)) {
        stats <- grDevices::boxplot.stats
      }
      boxes <- tapply(
        value,
        factor(code, levels = levels_drawn),
        stats,
        coef = if (is.null(args[["coef"]])) 1.5 else args[["coef"]],
        do.out = if (is.null(args[["do.out"]])) TRUE else args[["do.out"]]
      )
      n <- length(levels_drawn)
      labels <- if (is.factor(category)) {
        levels(category)[levels_drawn]
      } else {
        as.character(levels_drawn)
      }
      # `bwplot(~x)` has no categories: lattice draws its box on a dummy
      # level named "", and the frontend names every box "<axis> is
      # <name>", so that box is named after what it summarises instead. A
      # blank or missing level of the chart's own factor is a category the
      # box is drawn over and keeps its name; a missing one is emitted as
      # null, which the frontend announces as missing, as it does a bar.
      one_sided <- inherits(plot$formula, "formula") && length(plot$formula) == 2L
      if (one_sided && identical(levels(as.factor(category)), "")) {
        value_label <- if (horizontal) layout$x_label else layout$y_label
        labels[] <- if (length(value_label) && nzchar(value_label)) {
          value_label
        } else {
          "All"
        }
      }
      # Which values fall outside the whiskers is decided on the drawn scale,
      # where the statistics were computed; only what is announced moves to
      # the data's scale -- or, on a time axis, to the instant it stands for
      # -- which keeps every value in its order.
      on_data_scale <- function(values) {
        self$position_values(values, if (horizontal) "x" else "y", plot, panel_ctx)
      }

      offset <- 0L
      data <- vector("list", n)
      selectors <- vector("list", n)
      for (k in seq_len(n)) {
        box <- boxes[[k]]
        if (is.null(box) || anyNA(box$stats)) {
          return(NULL)
        }
        five <- box$stats
        out <- box$out
        # An outlier at no position -- a zero on a log scale is -Inf -- is
        # not drawn, so it is not read either; the exporter skips its mark
        # without renumbering the others, so it still counts in the offset.
        lower <- which(is.finite(out) & out < five[1])
        upper <- which(is.finite(out) & out > five[5])
        outlier_selectors <- function(indices) {
          as.list(lattice_shape_selector(part("outlier.points"), offset + indices))
        }
        shown <- on_data_scale(five)

        data[[k]] <- list(
          z = labels[k],
          lowerOutliers = as.list(on_data_scale(out[lower])),
          min = shown[1],
          q1 = shown[2],
          q2 = shown[3],
          q3 = shown[4],
          max = shown[5],
          upperOutliers = as.list(on_data_scale(out[upper]))
        )
        selectors[[k]] <- list(
          lowerOutliers = if (length(lower)) outlier_selectors(lower) else list(),
          min = lattice_shape_selector(part("cap.segments"), k),
          iq = lattice_shape_selector(part("box.polygon"), k),
          q2 = lattice_shape_selector(part(median_part), k),
          max = lattice_shape_selector(part("cap.segments"), k + n),
          upperOutliers = if (length(upper)) outlier_selectors(upper) else list()
        )
        offset <- offset + length(out)
      }

      reverse_horizontal_box_layer(list(
        type = "box",
        data = data,
        selectors = selectors,
        title = panel_ctx$title,
        axes = self$time_axes(self$layer_axes(layout, panel_ctx), panel_ctx),
        orientation = if (horizontal) "horz" else "vert",
        domMapping = list(iqrDirection = if (horizontal) "forward" else "reverse")
      ))
    }
  )
)
