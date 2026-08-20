#' Group a contour layer's rows into the curves it drew
#'
#' A contour draws a scalar field as curves of constant value, and
#' `ggplot_build()` has already done the hard half: `level` is a number on
#' every row, and `piece` separates the curves. A field with two peaks crosses
#' a level twice and arrives as two pieces, so nothing has to be split apart
#' here -- which is the one place this reading is easier than the matplotlib
#' one, where both islands come back in a single compound path
#' (xability/py-maidr#540).
#'
#' Pieces are emitted in ascending `piece`, which is ascending level and then
#' draw order within a level, and the returned `order` is that sequence of
#' piece identifiers -- what the selectors are built from, so the highlight
#' follows the grouping rather than relying on the document happening to agree.
#'
#' @param built_data A layer's computed data, carrying `x`, `y`, `level` and
#'   `piece`, one row per vertex
#' @return A list with `data` (one curve per piece, each a list of `x`, `y`
#'   and `level`) and `order` (the piece behind each emitted curve)
#' @keywords internal
contour_curves <- function(built_data) {
  empty <- list(data = list(), order = integer(0))
  if (is.null(built_data) || nrow(built_data) == 0) {
    return(empty)
  }
  if (!all(c("x", "y", "level", "piece") %in% names(built_data))) {
    return(empty)
  }
  # A filled contour computes `level` as a factor of band intervals --
  # "(0.0, 0.1]" -- because it draws the bands *between* levels rather than
  # the levels. The frame says so itself, so the refusal is read off the data
  # rather than inferred from the geom's name.
  if (!is.numeric(built_data$level)) {
    return(empty)
  }

  usable <- is.finite(built_data$x) & is.finite(built_data$y) &
    is.finite(built_data$level)
  if (!any(usable)) {
    return(empty)
  }

  pieces <- sort(unique(built_data$piece[usable]))
  data <- list()
  order <- integer(0)
  for (piece in pieces) {
    rows <- which(usable & built_data$piece == piece)
    if (length(rows) < 2L) {
      # A curve of one vertex is a place the field touched a level rather than
      # a curve along it, and there is nothing to move along.
      next
    }
    data[[length(data) + 1L]] <- lapply(rows, function(i) {
      list(
        x = as.numeric(built_data$x[i]),
        y = as.numeric(built_data$y[i]),
        level = as.numeric(built_data$level[i])
      )
    })
    order <- c(order, piece)
  }

  list(data = data, order = order)
}


#' Contour Layer Processor
#'
#' @description
#' Processes contour layers (\code{geom_contour}, \code{geom_density_2d}).
#'
#' A contour is the one chart of its family whose value is a **number rather
#' than a colour**: ggplot2 computes `level` per row, so both halves of the
#' reading invert exactly and nothing is recovered from a fill. That is what
#' separates it from the same chart in a renderer that keeps its magnitude
#' only in a continuous colour, which is why xability/maidr#1084 left
#' Observable Plot's `contour` unread.
#'
#' The **filled** forms are not this chart. `geom_contour_filled()` and
#' `geom_density_2d_filled()` draw the bands *between* levels, and say so in
#' the frame: their `level` is a factor of intervals rather than a number.
#' Announcing one of those outlines as a level's own curve would be right for
#' half of its points.
#'
#' @keywords internal
Ggplot2ContourLayerProcessor <- R6::R6Class(
  "Ggplot2ContourLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the contour layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return List with data, selectors and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      curves <- contour_curves(self$get_layer_built_data(built, panel_id))

      list(
        data = curves$data,
        selectors = self$generate_selectors(gt, plot, panel_ctx, curves$order),
        axes = self$extract_axes(plot, built)
      )
    },

    #' @description Name the two axes
    #'
    #'   Only x and y. The level is not an axis here: it travels on every
    #'   point of the curve it belongs to, and the frontend's contour trace
    #'   announces it from there under its own heading rather than from a
    #'   third axis label.
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @return An axes payload with x and y
    extract_axes = function(plot, built = NULL) {
      layer_index <- self$get_layer_index()

      build_axes(
        x = positional_axis_label(plot, built, "x", layer_index),
        y = positional_axis_label(plot, built, "y", layer_index)
      )
    },

    #' @description Address each drawn curve by its own element
    #'
    #'   `GeomContour` draws every curve in one `polylineGrob`, and gridSVG
    #'   exports that as one `<polyline>` per piece with an id of the form
    #'   `<grob>.1.<n>` -- measured, a two-level field with two peaks gives
    #'   `GRID.polyline.1.1.1` through `.4`. So a curve is addressed by its
    #'   position among the pieces, which is what `contour_curves()` returns.
    #'
    #'   The grob carries grid's automatic name rather than one derived from
    #'   the geom, so it is found the way a line layer's is -- by position
    #'   among the auto-named polylines of the panel. That is the whole reason
    #'   `polyline_layer_position()` had to learn about this type: a contour
    #'   drawn beside a `geom_line()` sits in the same candidate list, and a
    #'   count that skipped it would give both layers the other's curves.
    #' @param gt Gtable object
    #' @param plot The ggplot2 object, used to build a gtable when none is given
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @param order The piece behind each emitted curve
    #' @return A list of CSS selectors, one per curve
    generate_selectors = function(gt = NULL, plot = NULL, panel_ctx = NULL,
                                  order = integer(0)) {
      if (length(order) == 0) {
        return(list())
      }
      if (is.null(gt)) {
        if (is.null(plot)) {
          return(list())
        }
        gt <- ggplot2::ggplotGrob(plot)
      }

      panel_grob <- if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        find_gtable_panel_grob(gt, panel_ctx)
      } else {
        index <- which(gt$layout$name == "panel")
        if (length(index) == 0) NULL else gt$grobs[[index[[1]]]]
      }
      if (is.null(panel_grob)) {
        return(list())
      }

      grob <- self$find_layer_polyline_grob(plot, panel_grob)
      if (is.null(grob) || is.null(grob$name)) {
        return(list())
      }

      lapply(seq_along(order), function(position) {
        id <- paste0(grob$name, ".1.", position)
        paste0("*[id='", id, "']")
      })
    }
  )
)
