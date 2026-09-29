#' lattice Histogram Layer Processor
#'
#' @description
#' Reads the bins a `histogram()` panel draws as a `hist` layer.
#'
#' The bins are read off the drawn rectangles, one per bin from left to
#' right, in the units the panel drew them in: percent of the panel's
#' observations by default, or counts or densities as `type =` asks. That
#' is what the chart shows, and it holds even where the breaks are computed
#' per panel or from a function; lattice widens the data's range before it
#' breaks it, so recomputing the bins from the data would not give the same
#' ones. A bin that holds nothing is still drawn, with no height, and is
#' read as zero. The frontend's description of a `hist` layer takes every
#' height for a count and sums them as the number of observations, which a
#' percent or density histogram's heights are not; the payload has no way
#' to say what the heights measure.
#'
#' A factor is binned one level to a bin, each bin centred on the level's
#' position along the axis, where the axis names the level. That chart is a
#' bar chart of the levels, and is read as one: a `bar` layer, a bar per
#' level, named by it. As a `hist` layer each bin would be announced by the
#' range it spans -- "0.5 through 1.5" -- which on a factor's axis is only
#' positions, never the name the chart shows under the bar.
#'
#' @keywords internal
LatticeHistogramLayerProcessor <- R6::R6Class(
  "LatticeHistogramLayerProcessor",
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
      if (is.null(grob) || !inherits(grob, "rect")) {
        return(NULL)
      }

      bins <- self$extract_data(plot, grob)
      level_names <- self$bin_levels(bins, panel_ctx$x_limits)
      data <- if (is.null(level_names)) {
        bins
      } else {
        lapply(seq_along(bins), function(i) list(x = level_names[i], y = bins[[i]]$y))
      }

      list(
        type = if (is.null(level_names)) "hist" else "bar",
        data = data,
        selectors = lattice_grob_selector(entry$name, "rect"),
        title = panel_ctx$title,
        axes = self$layer_axes(layout, panel_ctx),
        orientation = "vert"
      )
    },

    #' @description Read the drawn bins
    #' @param plot The trellis object
    #' @param grob The rect grob
    #' @return List of bins, each `x` (its middle), `y` (its height) and the
    #'   extents `xMin`, `xMax`, `yMin`, `yMax`
    extract_data = function(plot, grob) {
      just <- grid::valid.just(grob$just)
      hjust <- if (is.null(grob$hjust)) just[1] else grob$hjust
      vjust <- if (is.null(grob$vjust)) just[2] else grob$vjust
      n <- max(length(grob$x), length(grob$width), length(grob$height))
      x <- rep_len(as.numeric(grob$x), n)
      y <- rep_len(as.numeric(grob$y), n)
      width <- rep_len(as.numeric(grob$width), n)
      height <- rep_len(as.numeric(grob$height), n)

      left <- self$axis_values(x - hjust * width, "x", plot)
      right <- self$axis_values(x + (1 - hjust) * width, "x", plot)
      bottom <- y - vjust * height
      top <- y + (1 - vjust) * height
      drawn <- is.finite(left) & is.finite(right) & is.finite(bottom) & is.finite(top)

      lapply(which(drawn), function(i) {
        list(
          x = (left[i] + right[i]) / 2,
          y = top[i] - bottom[i],
          xMin = left[i],
          xMax = right[i],
          yMin = bottom[i],
          yMax = top[i]
        )
      })
    },

    #' @description The levels a factor's bins count, one level to a bin
    #'
    #' Breaks given for a factor can span several levels, and a bin that
    #' counts more than one has no one name; the bins are then read as bins.
    #'
    #' @param bins The drawn bins, from `extract_data()`
    #' @param x_limits The packet's x limits: the level names on a factor axis
    #' @return The level each bin counts, or NULL
    bin_levels = function(bins, x_limits) {
      if (!is.character(x_limits) || length(bins) == 0L) {
        return(NULL)
      }
      middle <- vapply(bins, function(bin) bin$x, numeric(1))
      width <- vapply(bins, function(bin) bin$xMax - bin$xMin, numeric(1))
      position <- round(middle)
      one_level <- abs(middle - position) < 1e-8 & abs(width - 1) < 1e-8 &
        position >= 1 & position <= length(x_limits)
      if (!all(one_level)) {
        return(NULL)
      }
      x_limits[position]
    }
  )
)
