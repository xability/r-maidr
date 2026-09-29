#' lattice Contour Layer Processor
#'
#' @description
#' Reads the contour lines of a `contourplot()` panel -- or of a
#' `levelplot(contour = TRUE)` one -- as a `contour` layer: one series per
#' drawn curve, each point carrying the curve's `level`.
#'
#' `panel.levelplot()` computes the curves with `contourLines()` over the
#' panel's grid at the chart's `at` levels, and draws the `k`th piece as the
#' grob `levelplot.line.<k>.lines`. The curves are computed here the same
#' way, and paired with the drawn grobs by that `k`; a panel whose curves
#' and grobs do not agree in number cannot be read, and falls back. Their
#' vertices are read on the data's own scale, as the axes label them: back
#' from a log scale, and on a time axis as the instant they stand for.
#'
#' @keywords internal
LatticeContourLayerProcessor <- R6::R6Class(
  "LatticeContourLayerProcessor",
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
      curves <- self$extract_curves(panel_ctx$args)
      drawn <- vapply(layer_info$grobs, function(e) e$name, character(1))
      expected <- sprintf(
        "%s.levelplot.line.%d.lines.panel.%d.%d",
        LATTICE_PREFIX, seq_along(curves), panel_ctx$column, panel_ctx$row
      )
      if (!setequal(expected, drawn)) {
        return(NULL)
      }

      list(
        type = "contour",
        data = lapply(curves, function(curve) {
          # The curves run through the panel's own units -- logarithms on a
          # log scale, days on a date axis -- and a reader hears them on the
          # scale the axes are labelled in.
          x <- self$position_values(curve$x, "x", plot, panel_ctx)
          y <- self$position_values(curve$y, "y", plot, panel_ctx)
          lapply(seq_along(x), function(j) {
            list(x = x[j], y = y[j], level = curve$level)
          })
        }),
        selectors = as.list(vapply(expected, lattice_grob_selector, character(1),
          element = "polyline", USE.NAMES = FALSE
        )),
        title = panel_ctx$title,
        axes = self$time_axes(
          build_axes(
            x = layout$x_label,
            y = layout$y_label,
            z = lattice_z_label(plot)
          ),
          panel_ctx
        )
      )
    },

    #' @description Compute the panel's contour lines as the panel did
    #' @param args The panel's arguments
    #' @return The list `contourLines()` returns, empty when no level
    #'   crosses the panel
    extract_curves = function(args) {
      cells <- lattice_level_cells(args)
      if (is.null(cells) || length(cells$ux) < 2L || length(cells$uy) < 2L) {
        return(list())
      }
      finite <- is.finite(cells$x) & is.finite(cells$y)
      grid <- matrix(NA_real_, length(cells$ux), length(cells$uy))
      at_cell <- cbind(match(cells$x, cells$ux), match(cells$y, cells$uy))
      grid[at_cell[finite, , drop = FALSE]] <- cells$z[finite]
      at <- args[["at"]]
      grDevices::contourLines(
        x = cells$ux,
        y = cells$uy,
        z = grid,
        nlevels = length(at),
        levels = at
      )
    }
  )
)
