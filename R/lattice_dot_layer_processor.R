#' lattice Dot Layer Processor
#'
#' @description
#' Reads a `dotplot()` panel that has at most one value per level -- a
#' Cleveland dot plot -- as a `dot` layer, which the frontend builds on its
#' bar reading: one value per category, walked along the axis. One layer
#' per group, named after it.
#'
#' The panel's rows were sorted by level before drawing
#' ([lattice_prepare()]), so the dots are drawn in the order the levels run
#' along the axis, which is the order the frontend pairs a bar-shaped
#' layer's marks with its values.
#'
#' @keywords internal
LatticeDotLayerProcessor <- R6::R6Class(
  "LatticeDotLayerProcessor",
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
      if (is.null(grob) || !inherits(grob, "points")) {
        return(NULL)
      }

      horizontal <- !isFALSE(panel_ctx$args[["horizontal"]])
      data <- self$extract_data(plot, panel_ctx, grob, horizontal)
      if (is.null(data)) {
        return(NULL)
      }

      result <- list(
        type = "dot",
        data = data,
        selectors = lattice_grob_selector(entry$name, "use"),
        title = panel_ctx$title,
        axes = self$layer_axes(layout, panel_ctx),
        orientation = if (horizontal) "horz" else "vert"
      )
      name <- self$group_label(panel_ctx, entry)
      if (!is.null(name)) {
        result$name <- name
      }
      result
    },

    #' @description Read the drawn dots
    #' @param plot The trellis object
    #' @param panel_ctx The panel
    #' @param grob The points grob
    #' @param horizontal Whether the levels run up the vertical axis
    #' @return List of `x`/`y` points -- the value along the value axis and
    #'   the level's name -- or NULL when the dots are not one per level in
    #'   level order
    extract_data = function(plot, panel_ctx, grob, horizontal) {
      x <- as.numeric(grob$x)
      y <- as.numeric(grob$y)
      drawn <- is.finite(x) & is.finite(y)
      position <- if (horizontal) y[drawn] else x[drawn]
      value <- if (horizontal) x[drawn] else y[drawn]
      limits <- if (horizontal) panel_ctx$y_limits else panel_ctx$x_limits
      if (!is.character(limits)) {
        return(NULL)
      }

      category <- self$category_of(position, limits)
      if (anyNA(category$label) || anyDuplicated(category$position) ||
        is.unsorted(category$position)) {
        return(NULL)
      }
      value <- self$axis_values(value, if (horizontal) "x" else "y", plot)

      lapply(seq_along(value), function(i) {
        if (horizontal) {
          list(x = value[i], y = category$label[i])
        } else {
          list(x = category$label[i], y = value[i])
        }
      })
    }
  )
)
