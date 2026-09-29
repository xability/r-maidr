#' lattice Lollipop Layer Processor
#'
#' @description
#' Reads the spikes `xyplot(type = "h")` draws as a `lollipop` layer: one
#' value per position, standing side by side rather than joined, as Base
#' R's `plot(type = "h")` is read. One layer per group, named after it.
#'
#' Each spike is a segment from the baseline to the value; its value end is
#' `(x0, y0)`. A spike with a missing value is not drawn, and is left out.
#'
#' `horizontal = TRUE` draws the spikes from the left edge instead
#' (`type = "H"`), each standing at a y position with its value along x,
#' which is the frontend's `"horz"` orientation of a bar-like layer. On a
#' factor axis a spike's position is the level's name. A date or date-time
#' axis is emitted in milliseconds with a date format, as the frontend reads
#' a time (`lattice_time_milliseconds()`).
#'
#' @keywords internal
LatticeLollipopLayerProcessor <- R6::R6Class(
  "LatticeLollipopLayerProcessor",
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
      entry <- layer_info$grobs[[1]]
      grob <- self$grob(gt, entry)
      if (is.null(grob) || !inherits(grob, "segments")) {
        return(NULL)
      }

      x <- as.numeric(grob$x0)
      y <- as.numeric(grob$y0)
      ends <- cbind(x, y, as.numeric(grob$x1), as.numeric(grob$y1))
      drawn <- rowSums(!is.finite(ends)) == 0L
      horizontal <- isTRUE(panel_ctx$args[["horizontal"]])
      read <- function(values, axis) {
        limits <- if (axis == "x") panel_ctx$x_limits else panel_ctx$y_limits
        position_axis <- if (horizontal) "y" else "x"
        if (axis == position_axis && is.character(limits)) {
          self$category_of(values, limits)$label
        } else {
          self$position_values(values, axis, plot, panel_ctx)
        }
      }
      x <- read(x[drawn], "x")
      y <- read(y[drawn], "y")

      result <- list(
        type = "lollipop",
        data = lapply(seq_along(x), function(i) list(x = x[i], y = y[i])),
        selectors = lattice_grob_selector(entry$name, "polyline"),
        title = panel_ctx$title,
        axes = self$time_axes(self$layer_axes(layout, panel_ctx), panel_ctx)
      )
      if (horizontal) {
        result$orientation <- "horz"
      }
      name <- self$group_label(panel_ctx, entry)
      if (!is.null(name)) {
        result$name <- name
      }
      result
    }
  )
)
