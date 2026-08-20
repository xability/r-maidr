#' Collapse a dot stack into the bins it counts
#'
#' A Wilkinson dot plot is a histogram drawn one dot per observation: the
#' values are binned, and each bin's dots are stacked so the stack's height
#' *is* the bin's count. \code{ggplot_build()} says so directly -- it returns
#' one row per observation carrying that observation's bin centre, the bin
#' width, and the bin's count -- so the histogram is read off rather than
#' reconstructed:
#'
#' \preformatted{
#'    y x binwidth count countidx
#' 1  0 1        1     3        1
#' 2  0 1        1     3        2
#' 3  0 1        1     3        3
#' 4  0 2        1     2        1
#' }
#'
#' Three rows for the bin at 1, each saying \code{count = 3}. Collapsing on
#' the centre gives four bins of 3, 2, 1 and 4.
#'
#' The count is taken from the \code{count} column rather than by counting
#' rows. Measured, the two agree everywhere ggplot2 will build a dot plot --
#' \code{aes(weight = w)} expands a bin to one row per weighted unit, and a
#' fractional weight is refused outright ("`weight` must be nonnegative
#' integers") -- so this is not a correction, it is a preference for the
#' stat's own answer over a count of the rows that happen to represent it.
#'
#' Bin bounds come from the centre and the width rather than from
#' \code{xmin}/\code{xmax}, which name the bin only in one of the two
#' orientations: measured, \code{binaxis = "y"} puts the panel's whole range
#' in \code{ymin}/\code{ymax} and the dot's own width in
#' \code{xmin}/\code{xmax}, so neither pair is the bin there.
#'
#' @param built_data A layer's computed data, carrying the bin centre on
#'   \code{x} or \code{y} plus \code{binwidth} and \code{count}
#' @param horizontal \code{TRUE} when the bins run up the y axis
#' @return A list of bins, each with \code{centre}, \code{half} and
#'   \code{count}, ascending; empty when the layer drew nothing readable
#' @keywords internal
dotplot_bins <- function(built_data, horizontal = FALSE) {
  if (is.null(built_data) || nrow(built_data) == 0) {
    return(list())
  }

  axis <- if (horizontal) "y" else "x"
  if (!all(c(axis, "binwidth", "count") %in% names(built_data))) {
    return(list())
  }

  centres <- as.numeric(built_data[[axis]])
  widths <- as.numeric(built_data$binwidth)
  counts <- as.numeric(built_data$count)
  if (anyNA(centres) || anyNA(widths) || anyNA(counts)) {
    return(list())
  }

  # `stat_bindot` counts *per group*, so a `fill =` plot puts several rows on
  # one centre carrying different counts -- measured, `aes(fill = g)` over
  # five observations at one bin gives `count` 3 for one group and 2 for the
  # other. Taking the first row's count would announce a bin of five as three
  # and say nothing about the two it dropped.
  groups <- if ("group" %in% names(built_data)) built_data$group else rep(1L, length(centres))

  # Grouped on the centre by exact equality, which is exact rather than
  # approximate here for the reason `hexbin_lattice()` gives: every dot of a
  # bin takes the centre from the same bin computation, so the values are
  # identical bit for bit.
  order <- sort(unique(centres))
  lapply(order, function(centre) {
    rows <- which(centres == centre)
    # Summed across the groups at this centre, not maxed and not taken from
    # the first. What the sum is: the number of observations the bin holds,
    # which is what a histogram announces and what `stackgroups = TRUE` draws
    # -- measured, that spelling continues the stack to 3.5 and 4.5, so the
    # column really is five tall.
    #
    # The default does *not* draw that. Both groups start at `stackpos` 0.5
    # and overlap, so the pile is three high and two observations are hidden
    # behind it. Neither number is free of objection: three is the height of
    # a pile that conceals data, five is the bin. Five is announced, because
    # a `hist` layer's value is the count of observations in the bin, and
    # because the overlap is the rendering caveat ggplot2 documents rather
    # than a fact about the data.
    per_group <- vapply(
      unique(groups[rows]),
      function(id) counts[rows[which(groups[rows] == id)[1]]],
      numeric(1)
    )
    list(
      centre = centre,
      half = widths[rows[1]] / 2,
      count = sum(per_group)
    )
  })
}

#' Dot Plot Layer Processor
#'
#' @description
#' Processes Wilkinson dot plots (\code{geom_dotplot}).
#'
#' The layer emits type \code{hist}, because that is the chart: a stack of
#' dots is a bar, and the bin and its count are what a reader navigates. The
#' y axis a dot plot draws is not one -- ggplot2's own documentation says the
#' values on it are meaningless -- so the count goes on it here.
#'
#' Highlighting is not offered, and that is a real limit rather than an
#' oversight. \code{GeomDotplot} draws the whole chart as one
#' \code{dotstackGrob}, which gridSVG exports as one \code{<circle>} per
#' *observation*: a bin of three dots has three elements and no element of
#' its own, while the frontend's bar traces resolve exactly one element per
#' announced value. So the bins are announced, sonified and brailled, and
#' nothing lights up -- which is the highlight-only blind spot
#' xability/maidr#814 names, and strictly better than the static image this
#' chart was before (#201). \code{geom_histogram()} draws the same
#' distribution with a rect per bin and highlights.
#'
#' @keywords internal
Ggplot2DotplotLayerProcessor <- R6::R6Class(
  "Ggplot2DotplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the dot plot layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return List with type, data, orientation, selectors and axes
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
      horizontal <- self$bins_run_up_the_y_axis(plot)

      list(
        type = "hist",
        data = self$extract_data(plot, built, panel_id, horizontal),
        orientation = if (horizontal) "horz" else "vert",
        selectors = list(),
        axes = self$extract_axes(plot, built, horizontal)
      )
    },

    #' @description Which axis the values were binned along
    #'
    #'   Read from the layer's own \code{binaxis} parameter, which is what
    #'   decides it: \code{geom_dotplot(binaxis = "y")} is the form drawn
    #'   beside a categorical x, and its bins run up the y axis. Defaulted to
    #'   \code{"x"} to match ggplot2's own default rather than guessed at from
    #'   the data.
    #' @param plot The ggplot2 object
    #' @return \code{TRUE} when the bins run up the y axis
    bins_run_up_the_y_axis = function(plot) {
      layer <- plot$layers[[self$get_layer_index()]]
      params <- tryCatch(layer$geom_params, error = function(e) NULL)
      axis <- params$binaxis
      identical(as.character(axis), "y")
    },

    #' @description Read the bins out of the built data
    #'
    #'   Emitted in the shape \code{Ggplot2HistogramLayerProcessor} emits, so
    #'   the frontend's histogram trace reads it unchanged: the bin's centre
    #'   and count as \code{x}/\code{y}, and the bin's own bounds as
    #'   \code{xMin}/\code{xMax}. A bar rises from zero, so \code{yMin} is 0
    #'   and \code{yMax} is the count.
    #'
    #'   Both are swapped for a layer binned up the y axis, matching what
    #'   \code{orientation = "horz"} tells the frontend to expect.
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param horizontal Whether the bins run up the y axis
    #' @return A list of bins, ascending
    extract_data = function(plot, built = NULL, panel_id = NULL,
                            horizontal = FALSE) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      built_data <- self$get_layer_built_data(built, panel_id)
      bins <- dotplot_bins(built_data, horizontal)

      lapply(bins, function(bin) {
        low <- bin$centre - bin$half
        high <- bin$centre + bin$half
        if (horizontal) {
          list(
            x = bin$count, y = bin$centre,
            xMin = 0, xMax = bin$count,
            yMin = low, yMax = high
          )
        } else {
          list(
            x = bin$centre, y = bin$count,
            xMin = low, xMax = high,
            yMin = 0, yMax = bin$count
          )
        }
      })
    },

    #' @description Name the two axes
    #'
    #'   The bin axis keeps the variable's name through the package's shared
    #'   \code{labs()}-then-mapping chain. The other one is named "count"
    #'   here rather than read from the plot: ggplot2 labels a dot plot's
    #'   count axis "count" while drawing values on it that its own
    #'   documentation calls meaningless, and reading that label back would
    #'   pair a real count with whatever the caller renamed the fiction to.
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param horizontal Whether the bins run up the y axis
    #' @return An axes payload with x and y
    extract_axes = function(plot, built = NULL, horizontal = FALSE) {
      layer_index <- self$get_layer_index()
      binned <- positional_axis_label(
        plot, built, if (horizontal) "y" else "x", layer_index
      )

      if (horizontal) {
        build_axes(x = "count", y = binned)
      } else {
        build_axes(x = binned, y = "count")
      }
    }
  )
)
