#' The cells of a levelplot panel
#'
#' `panel.levelplot()` draws one cell per row of the panel -- `x`, `y` and
#' `z` are shared by every packet, and each packet names its rows with
#' `subscripts` -- at the positions `x` and `y` take on the axes.
#'
#' @param args The panel's arguments
#' @return A list with the panel's `x`, `y` and `z` over its rows, and the
#'   sorted distinct positions `ux` and `uy`; NULL when the panel has no rows
#' @keywords internal
lattice_level_cells <- function(args) {
  subscripts <- args[["subscripts"]]
  if (length(subscripts) == 0L) {
    return(NULL)
  }
  x <- as.numeric(args[["x"]])[subscripts]
  y <- as.numeric(args[["y"]])[subscripts]
  z <- as.numeric(args[["z"]])[subscripts]
  list(
    x = x,
    y = y,
    z = z,
    ux = sort(unique(x[is.finite(x)])),
    uy = sort(unique(y[is.finite(y)]))
  )
}

#' What the values of a levelplot are called
#'
#' The colour key's title when it has one, otherwise the variable on the
#' formula's left-hand side.
#'
#' The key is found by what draws it rather than by where it sits:
#' `colorkey = list(space = "left")` puts it on another side than the
#' right, and a legend of the chart's own can take the right instead.
#'
#' @param plot A trellis object
#' @return A string
#' @keywords internal
lattice_z_label <- function(plot) {
  for (legend in plot$legend) {
    draws_key <- identical(legend$fun, "draw.colorkey") ||
      identical(legend$fun, lattice::draw.colorkey)
    title <- if (draws_key) lattice_label_text(legend$args$key$title)
    if (!is.null(title)) {
      return(title)
    }
  }
  formula <- plot$formula
  if (inherits(formula, "formula") && length(formula) == 3L) {
    return(paste(deparse(formula[[2]], width.cutoff = 500L), collapse = " "))
  }
  "value"
}

#' lattice Heatmap Layer Processor
#'
#' @description
#' Reads the cells a `levelplot()` panel fills as a `heat` layer: a grid of
#' values, with the levels or positions of `x` along its columns and of `y`
#' down its rows. A position the data has no row for, or a row whose value
#' is missing or lies outside `at`, which lattice leaves unfilled, is a hole
#' (`null`). A numeric position is named by its value
#' on the data's own scale, as the axis labels it, rather than by the
#' logarithm lattice hands a log-scale panel; a date or date-time by the
#' instant it stands for, which the axis' time format reads out.
#'
#' **Selectors.** The cells are drawn in the order of the panel's rows --
#' for a matrix, row by row from the bottom -- which is neither order the
#' frontend reads one selector for a whole heat grid in. So each cell is
#' named by its own id, in a grid whose rows run bottom first, as the
#' frontend's heat grid does, with `null` for a cell that was not drawn.
#'
#' @keywords internal
LatticeHeatmapLayerProcessor <- R6::R6Class(
  "LatticeHeatmapLayerProcessor",
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
      cells <- lattice_level_cells(panel_ctx$args)
      if (is.null(cells) || length(cells$ux) == 0L || length(cells$uy) == 0L) {
        return(list(data = list()))
      }
      # Each row's cell, found by position rather than by printed value, which
      # would take two positions that print alike for one.
      at <- cbind(match(cells$y, cells$uy), match(cells$x, cells$ux))
      finite <- is.finite(cells$x) & is.finite(cells$y)
      if (anyDuplicated(at[finite, , drop = FALSE])) {
        return(NULL)
      }

      # A row with a missing value is drawn as nothing and is a hole, and so
      # is one whose value lies outside `at`, which lattice leaves unfilled
      # -- `at` limits the range a chart shows. The rects keep the numbers of
      # their rows either way.
      entry <- layer_info$grobs[[1]]
      breaks <- panel_ctx$args[["at"]]
      coloured <- if (is.null(breaks)) {
        TRUE
      } else {
        !is.na(lattice::level.colors(cells$z, breaks, colors = FALSE))
      }
      drawn <- which(finite & is.finite(cells$z) & coloured)
      if (length(drawn) == 0L) {
        return(list(data = list()))
      }
      values <- matrix(NA_real_, length(cells$uy), length(cells$ux))
      ids <- matrix(NA_character_, length(cells$uy), length(cells$ux))
      values[at[drawn, , drop = FALSE]] <- cells$z[drawn]
      ids[at[drawn, , drop = FALSE]] <- lattice_shape_selector(entry$name, drawn)

      # A numeric position is announced on the data's own scale -- lattice
      # hands a log-scale panel the logarithms, a date axis days -- and
      # formatted on its own: `format()` gives a vector one width and one
      # number of decimals, so -2 among thirds would read "-2.0000000". A
      # time is named by the instant it stands for, in ISO 8601, which the
      # axis' time format reads out as the date the axis labels.
      label <- function(values, positions, limits, axis) {
        if (is.factor(values)) {
          return(levels(values)[positions])
        }
        if (is.character(limits) && all(positions %in% seq_along(limits))) {
          return(limits[positions])
        }
        shown <- self$position_values(positions, axis, plot, panel_ctx)
        kind <- lattice_time_kind(limits)
        if (!is.null(kind)) {
          return(format(
            as.POSIXct(shown / 1000, origin = "1970-01-01", tz = "UTC"),
            if (kind == "date") "%Y-%m-%d" else "%Y-%m-%dT%H:%M:%SZ"
          ))
        }
        vapply(shown, format, character(1), digits = 7L, scientific = FALSE, trim = TRUE)
      }
      args <- panel_ctx$args
      x_labels <- label(args[["x"]], cells$ux, panel_ctx$x_limits, "x")
      y_labels <- label(args[["y"]], cells$uy, panel_ctx$y_limits, "y")

      list(
        type = "heat",
        data = list(
          x = as.list(x_labels),
          y = as.list(rev(y_labels)),
          points = lapply(rev(seq_len(nrow(values))), function(r) as.list(values[r, ]))
        ),
        selectors = lapply(seq_len(nrow(ids)), function(r) as.list(ids[r, ])),
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
    }
  )
)
