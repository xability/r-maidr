#' lattice Line Layer Processor
#'
#' @description
#' Reads the lines an `xyplot()` panel draws -- `type = "l"`, `"b"`, `"o"`,
#' the average line of `"a"` -- and a `qqmath()` panel's, as a `line` layer
#' with one series per group; and the staircase of `type = "s"` or `"S"` as
#' a `step` layer.
#'
#' A line is read in the order it was drawn, which for lattice is the order
#' of the data: `panel.xyplot()` joins the points as they come, so unsorted
#' x draws a zigzag, and reading it sorted would describe a line the chart
#' does not show. A missing y breaks the drawn line and is emitted as a gap
#' (`y: null`) at its x. A row with no x breaks it too, but has no position
#' a gap could be put at -- the frontend places a line's points by their x,
#' a number or a string -- and is left out, as py-maidr leaves out the
#' matplotlib points with no x: the pieces on either side are read as one.
#'
#' A staircase is drawn through `2n - 1` vertices for `n` samples, sorted
#' by x; the samples are the odd vertices, and `stepDirection` says which
#' way each riser runs: `"hv"` for `"s"`, `"vh"` for `"S"`. A missing value
#' breaks the staircase into pieces, and maidr.js 4.11.0 outlines most
#' samples of a staircase drawn in pieces at a corner rather than at the
#' sample; what is read is right, only the outline is not. With
#' `distribute.type = TRUE` that is the type of the layer's own groups,
#' which the adapter keeps apart by direction, not of the chart's `type`
#' vector as a whole.
#'
#' A line on a factor axis runs through the levels' positions: its x is the
#' level's name, and on a factor y axis the name goes with the position as
#' `label`, since the frontend sonifies y and needs it a number. A date or
#' date-time axis is emitted in milliseconds with a date format, as the
#' frontend reads a time (`lattice_time_milliseconds()`).
#'
#' @keywords internal
LatticeLineLayerProcessor <- R6::R6Class(
  "LatticeLineLayerProcessor",
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
      step <- identical(layer_info$type, "step")
      entries <- lattice_sort_entries(layer_info$grobs)
      grouped <- any(!is.na(vapply(entries, function(e) e$group, integer(1))))

      series <- list()
      selectors <- list()
      for (entry in entries) {
        grob <- self$grob(gt, entry)
        if (is.null(grob) || !inherits(grob, "lines")) {
          return(NULL)
        }
        points <- self$extract_series(plot, panel_ctx, grob, step)
        # A line through no finite value draws nothing: lattice skips a
        # group whose values are all missing, but not one whose values are
        # infinite -- a zero on a log scale is -Inf -- and its series would be
        # all gaps, with no mark to highlight.
        if (all(vapply(points, function(point) is.na(point$y), logical(1)))) {
          next
        }
        name <- self$group_label(panel_ctx, entry)
        if (!is.null(name)) {
          points <- lapply(points, function(point) c(point, list(z = name)))
        }
        series[[length(series) + 1L]] <- points
        selectors[[length(selectors) + 1L]] <- lattice_grob_selector(entry$name, "polyline")
      }

      result <- list(
        type = if (step) "step" else "line",
        data = series,
        selectors = selectors,
        title = panel_ctx$title,
        axes = self$time_axes(
          self$layer_axes(layout, panel_ctx, grouped = grouped),
          panel_ctx
        )
      )
      if (step) {
        # The type the layer's groups were drawn with: under
        # `distribute.type = TRUE` the chart's `type` vector names every
        # group's, and holds an "S" whenever any group is drawn with one.
        type <- lattice_group_type(panel_ctx$args, entries[[1]]$group)
        result$stepDirection <- if ("S" %in% type) "vh" else "hv"
      }
      result
    },

    #' @description Read one drawn line as a series of points
    #' @param plot The trellis object
    #' @param panel_ctx The panel
    #' @param grob The lines grob
    #' @param step Whether the line is a staircase
    #' @return List of points
    extract_series = function(plot, panel_ctx, grob, step = FALSE) {
      x <- as.numeric(grob$x)
      y <- as.numeric(grob$y)
      if (step) {
        samples <- seq(1L, length(x), by = 2L)
        x <- x[samples]
        y <- y[samples]
      }
      # A row with no x has no position, gap or not.
      drawn <- is.finite(x)
      x <- x[drawn]
      y <- y[drawn]
      # A gap is where no line was drawn, which is decided in the units
      # lattice drew in: a zero on a log scale is drawn at -Inf, which is no
      # position, and back on the data's scale it would read as 0.
      gap <- !is.finite(y)

      x_value <- if (is.character(panel_ctx$x_limits)) {
        self$category_of(x, panel_ctx$x_limits)$label
      } else {
        self$position_values(x, "x", plot, panel_ctx)
      }
      y_categories <- is.character(panel_ctx$y_limits)
      y_value <- if (y_categories) y else self$position_values(y, "y", plot, panel_ctx)
      y_label <- if (y_categories) self$category_of(y, panel_ctx$y_limits)$label

      lapply(seq_along(x), function(i) {
        point <- list(x = x_value[i], y = if (gap[i]) NA else y_value[i])
        if (y_categories && !is.na(y_label[i])) {
          point$label <- y_label[i]
        }
        point
      })
    }
  )
)

#' A layer's grob entries in group order
#'
#' @param entries Grob entries of one layer
#' @return The entries, ungrouped first, then by group number
#' @keywords internal
lattice_sort_entries <- function(entries) {
  groups <- vapply(entries, function(e) {
    if (is.null(e$group) || is.na(e$group)) 0L else as.integer(e$group)
  }, integer(1))
  entries[order(groups)]
}
