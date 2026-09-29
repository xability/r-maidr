#' lattice Smooth Layer Processor
#'
#' @description
#' Reads the curves lattice computes while it draws as a `smooth` layer,
#' one series per group: the density estimate of a `densityplot()`, and the
#' loess, spline and least-squares fits of `xyplot(type = "smooth")`,
#' `"spline"` and `"r"`.
#'
#' The curve is read off the drawn grob rather than computed again: it is
#' the curve the panel function drew, whatever bandwidth, span or limits it
#' was given. A least-squares fit is drawn as one segment, clipped to the
#' panel, and is read as its two ends.
#'
#' The observations `densityplot()` draws under its curve -- jittered
#' points or a rug -- are the data again rather than the reading, and are
#' left out, as the curve is what the chart is drawn to show.
#'
#' @keywords internal
LatticeSmoothLayerProcessor <- R6::R6Class(
  "LatticeSmoothLayerProcessor",
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
      entries <- lattice_sort_entries(layer_info$grobs)
      grouped <- any(!is.na(vapply(entries, function(e) e$group, integer(1))))

      series <- list()
      selectors <- list()
      for (entry in entries) {
        grob <- self$grob(gt, entry)
        points <- self$extract_series(plot, grob, panel_ctx)
        if (is.null(points)) {
          return(NULL)
        }
        if (length(points) == 0L) {
          next
        }
        name <- self$group_label(panel_ctx, entry)
        if (!is.null(name)) {
          points <- lapply(points, function(point) c(point, list(z = name)))
        }
        series[[length(series) + 1L]] <- points
        selectors[[length(selectors) + 1L]] <- lattice_grob_selector(entry$name, "polyline")
      }

      list(
        type = "smooth",
        data = series,
        selectors = selectors,
        title = panel_ctx$title,
        axes = self$time_axes(
          self$layer_axes(layout, panel_ctx, grouped = grouped),
          panel_ctx
        )
      )
    },

    #' @description Read one drawn curve as a series of points
    #' @param plot The trellis object
    #' @param grob The lines or segments grob
    #' @param panel_ctx The panel, which says whether an axis is a time; a
    #'   time axis is read as drawn without it
    #' @return List of points, or NULL for a grob that is not a curve
    extract_series = function(plot, grob, panel_ctx = NULL) {
      if (inherits(grob, "lines")) {
        x <- as.numeric(grob$x)
        y <- as.numeric(grob$y)
      } else if (inherits(grob, "segments")) {
        x <- as.numeric(c(grob$x0, grob$x1))
        y <- as.numeric(c(grob$y0, grob$y1))
      } else {
        return(NULL)
      }
      drawn <- is.finite(x) & is.finite(y)
      x <- self$position_values(x[drawn], "x", plot, panel_ctx)
      y <- self$position_values(y[drawn], "y", plot, panel_ctx)
      lapply(seq_along(x), function(i) list(x = x[i], y = y[i]))
    }
  )
)
