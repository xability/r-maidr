#' lattice Point Layer Processor
#'
#' @description
#' Reads the points an `xyplot()`, `stripplot()`, `qqmath()` or `qq()` panel
#' draws, and a `dotplot()` panel that has several values on a level, as a
#' `point` layer: one layer per group, named after it.
#'
#' The values are the drawn coordinates, which lattice draws in data units
#' (`default.units = "native"`), so a `qqmath()` layer reads the quantiles
#' the panel computed rather than the sample it was given. On a factor axis
#' a coordinate is the level's position; it is emitted as that position with
#' the level's name as `xLabel` or `yLabel`, which is how the frontend reads
#' a strip of points by category.
#'
#' An axis the panel jittered -- `xyplot(jitter.x = TRUE)`,
#' `stripplot(jitter.data = TRUE)` -- is drawn at a random offset from each
#' value, a precise number for a quantity that does not exist and a
#' different one at every print; rounded back to a level, a point jittered
#' by more than half of one is named by the next. On such an axis the value
#' is read from the panel's own rows instead, which those panel functions
#' draw one point each, in order.
#'
#' A date or date-time axis is emitted in milliseconds with a date format,
#' as the frontend reads a time (`lattice_time_milliseconds()`).
#'
#' A point whose coordinates are missing is not drawn, and the exporter
#' skips it without renumbering the others, so it is left out here too: the
#' frontend pairs points with their marks by position only when the counts
#' agree.
#'
#' @keywords internal
LatticePointLayerProcessor <- R6::R6Class(
  "LatticePointLayerProcessor",
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

      result <- list(
        type = "point",
        data = self$extract_data(plot, panel_ctx, grob, entry),
        selectors = lattice_grob_selector(entry$name, "use"),
        title = panel_ctx$title,
        axes = self$point_axes(plot, layout, panel_ctx)
      )
      name <- self$group_label(panel_ctx, entry)
      if (!is.null(name)) {
        result$name <- name
      }
      result
    },

    #' @description Read the drawn points
    #' @param plot The trellis object
    #' @param panel_ctx The panel
    #' @param grob The points grob
    #' @param entry The grob's entry, which says the group it was drawn for;
    #'   without it a jittered axis is read as drawn
    #' @return List of points, each `x`, `y` and a level name where an axis
    #'   holds categories
    extract_data = function(plot, panel_ctx, grob, entry = NULL) {
      x <- as.numeric(grob$x)
      y <- as.numeric(grob$y)

      # The rows are the points only when there are as many of them as the
      # grob drew; anything else is not a drawing these panels make, and is
      # read as drawn.
      jittered <- self$jittered_axes(plot, panel_ctx$args)
      if (any(jittered) && !is.null(entry)) {
        rows <- lattice_group_rows(panel_ctx$args, entry$group)
        if (sum(rows) == length(x)) {
          if (jittered[["x"]]) {
            x <- as.numeric(panel_ctx$args[["x"]])[rows]
          }
          if (jittered[["y"]]) {
            y <- as.numeric(panel_ctx$args[["y"]])[rows]
          }
        }
      }

      drawn <- is.finite(x) & is.finite(y)
      x <- x[drawn]
      y <- y[drawn]

      x_categories <- is.character(panel_ctx$x_limits)
      y_categories <- is.character(panel_ctx$y_limits)
      x_value <- if (x_categories) {
        self$category_of(x, panel_ctx$x_limits)
      } else {
        list(position = self$position_values(x, "x", plot, panel_ctx))
      }
      y_value <- if (y_categories) {
        self$category_of(y, panel_ctx$y_limits)
      } else {
        list(position = self$position_values(y, "y", plot, panel_ctx))
      }

      lapply(seq_along(x), function(i) {
        point <- list(x = x_value$position[i], y = y_value$position[i])
        if (x_categories && !is.na(x_value$label[i])) {
          point$xLabel <- x_value$label[i]
        }
        if (y_categories && !is.na(y_value$label[i])) {
          point$yLabel <- y_value$label[i]
        }
        point
      })
    },

    #' @description The axes a panel drew its points on at a random offset
    #'
    #' `panel.xyplot()` jitters x for `jitter.x = TRUE` and y for
    #' `jitter.y = TRUE`, and `panel.stripplot()` its category axis for
    #' `jitter.data = TRUE`; `panel.dotplot()` hands both flags on to
    #' `panel.xyplot()`. The other panel functions draw points that are not
    #' the panel's rows -- `qqmath()`'s quantiles -- and are read as drawn.
    #'
    #' @param plot The trellis object
    #' @param args The panel's arguments
    #' @return Named logical `c(x = , y = )`
    jittered_axes = function(plot, args) {
      panel <- lattice_panel_name(plot[["panel"]])
      jittering <- c(
        "panel.xyplot", "panel.superpose", "panel.superpose.plain",
        "panel.stripplot", "panel.dotplot"
      )
      if (!panel %in% jittering) {
        return(c(x = FALSE, y = FALSE))
      }
      x <- isTRUE(args[["jitter.x"]])
      y <- isTRUE(args[["jitter.y"]])
      if (identical(panel, "panel.stripplot") && isTRUE(args[["jitter.data"]])) {
        horizontal <- !isFALSE(args[["horizontal"]])
        x <- x || !horizontal
        y <- y || horizontal
      }
      c(x = x, y = y)
    },

    #' @description The axes of a point layer, with their navigation grid
    #' @param plot The trellis object
    #' @param layout The figure's layout
    #' @param panel_ctx The panel
    #' @return Canonical axes list
    point_axes = function(plot, layout, panel_ctx) {
      grid <- function(scales, limits) {
        lattice_axis_grid(
          limits,
          log = scales$log,
          at = scales$at,
          tick_number = scales$tick.number,
          packet = panel_ctx$packet %||% 1L
        )
      }
      x_grid <- grid(plot$x.scales, panel_ctx$x_limits)
      y_grid <- grid(plot$y.scales, panel_ctx$y_limits)
      axes <- build_axes(
        x = do.call(build_axis_config, c(list(label = layout$x_label), x_grid)),
        y = do.call(build_axis_config, c(list(label = layout$y_label), y_grid))
      )
      self$time_axes(axes, panel_ctx)
    }
  )
)
