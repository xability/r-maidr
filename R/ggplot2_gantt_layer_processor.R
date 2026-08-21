#' Which axis a layer's segments lay their lanes on
#'
#' A segment whose two ends share a coordinate is a **span** along the other
#' axis, at one position on this one -- an interval in a lane, which is a
#' gantt. A segment whose ends share nothing is an edge in a node-link
#' diagram: it has no lane to sit in and no interval to announce.
#'
#' The question is asked of the **whole layer** rather than of each row, which
#' is the rule xability/maidr#1100 settled for the same reading in the
#' Observable adapter. One `geom_segment()` call can hold spans and edges
#' together, and reading three spans out of four segments would announce a
#' gantt quietly missing a quarter of its chart.
#'
#' A layer whose segments are level on *both* axes is every span reduced to a
#' point. That is not a schedule with milestones in it -- a milestone sits in
#' a lane beside intervals that have length -- so it is refused rather than
#' announced as a chart of zero-length work.
#'
#' @param built_data A layer's computed data, carrying `x`, `xend`, `y` and
#'   `yend`, one row per drawn segment
#' @return `"y"` when the lanes run up the y axis and the spans along x,
#'   `"x"` for the mirror image, or `NULL` when the layer is not a gantt
#' @keywords internal
segment_lane_axis <- function(built_data) {
  if (is.null(built_data) || nrow(built_data) == 0) {
    return(NULL)
  }
  needed <- c("x", "xend", "y", "yend")
  if (!all(needed %in% names(built_data))) {
    return(NULL)
  }

  finite <- built_data[
    stats::complete.cases(built_data[, needed]) &
      is.finite(built_data$x) & is.finite(built_data$xend) &
      is.finite(built_data$y) & is.finite(built_data$yend), ,
    drop = FALSE
  ]
  if (nrow(finite) == 0) {
    return(NULL)
  }

  level_on_y <- all(finite$y == finite$yend)
  level_on_x <- all(finite$x == finite$xend)

  if (level_on_y && level_on_x) {
    return(NULL)
  }
  if (level_on_y) {
    return("y")
  }
  if (level_on_x) {
    return("x")
  }
  NULL
}


#' Group a layer's segments into the lanes they were drawn in
#'
#' @param built_data A layer's computed data, one row per drawn segment
#' @param lane_axis `"y"` or `"x"`, as `segment_lane_axis()` returns
#' @param lane_names The lane names in drawn order, or NULL on a continuous
#'   lane axis. Position `i` on the axis is `lane_names[[i]]`
#' @return A list with `data` (lanes, each a list of `x`/`start`/`end`
#'   intervals), `lanes` (the names of every lane in drawn order, or NULL) and
#'   `order` (the built-data row behind each interval, in emission order)
#' @keywords internal
segment_lanes <- function(built_data, lane_axis, lane_names = NULL) {
  empty <- list(data = list(), lanes = NULL, order = integer(0))
  if (is.null(built_data) || is.null(lane_axis)) {
    return(empty)
  }

  positions <- built_data[[lane_axis]]
  span_axis <- if (identical(lane_axis, "y")) "x" else "y"
  lows <- built_data[[span_axis]]
  highs <- built_data[[paste0(span_axis, "end")]]

  usable <- is.finite(positions) & is.finite(lows) & is.finite(highs)
  if (!any(usable)) {
    return(empty)
  }

  # Every lane the scale lays out, not only the ones something was drawn in.
  # A factor level nothing was booked on survives `scale_y_discrete(drop =
  # FALSE)`, and "nothing is booked here" is a real statement about a
  # schedule -- which is why `GanttData.points` is nested per lane and why an
  # empty lane is a row a reader can navigate onto.
  slots <- if (!is.null(lane_names)) {
    seq_along(lane_names)
  } else {
    sort(unique(positions[usable]))
  }

  data <- list()
  order <- integer(0)
  for (slot in slots) {
    rows <- which(usable & positions == slot)
    # Ascending along the span axis, which is the order a reader sweeps a
    # lane in. `order` carries the built row behind each interval so the
    # selectors follow the regrouping rather than the document.
    rows <- rows[order(pmin(lows[rows], highs[rows]))]
    name <- lane_name(slot, lane_names)

    data[[length(data) + 1L]] <- lapply(rows, function(i) {
      # Sorted rather than taken as written: `aes(x = end, xend = start)`
      # draws the same span backwards, and a negative length is not a
      # statement the chart makes.
      list(
        x = name,
        start = as.numeric(min(lows[i], highs[i])),
        end = as.numeric(max(lows[i], highs[i]))
      )
    })
    order <- c(order, rows)
  }

  list(
    data = data,
    lanes = if (is.null(lane_names)) NULL else as.list(lane_name(slots, lane_names)),
    order = order
  )
}


#' The name of the lane at one position on the lane axis
#'
#' A discrete scale lays its levels out at 1, 2, 3 and so on, so the name is
#' the level at that index. A continuous lane axis has no names and the
#' position itself is what a reader is told -- `GanttPoint$x` takes a number
#' or a string for exactly this reason.
#'
#' @param slot One or more positions on the lane axis
#' @param lane_names The lane names in drawn order, or NULL
#' @return The lane names, or the positions unchanged
#' @keywords internal
lane_name <- function(slot, lane_names = NULL) {
  if (is.null(lane_names)) {
    return(as.numeric(slot))
  }
  index <- as.integer(round(slot))
  named <- index >= 1L & index <= length(lane_names)
  out <- as.character(slot)
  out[named] <- as.character(lane_names)[index[named]]
  out
}


#' Gantt Layer Processor
#'
#' @description
#' Processes \code{geom_segment()} layers that draw intervals in lanes.
#'
#' A segment with the two ends of a span on one axis and a lane on the other
#' is how ggplot2 draws a schedule, a range plot and a high-low chart.
#' \code{ggplot_build} computes both ends and the lane exactly, so nothing is
#' inverted from a pixel: the four columns \code{x}, \code{xend}, \code{y} and
#' \code{yend} are the interval and the lane the caller wrote.
#'
#' \code{geom_curve()} computes the same four columns and would read the same
#' way, but is not claimed -- \code{gridSVG} cannot export the \code{curve}
#' grob it draws, so reading it would turn a curve chart from a static image
#' into a \code{save_html()} that raises. See the adapter's own note.
#'
#' @keywords internal
Ggplot2GanttLayerProcessor <- R6::R6Class(
  "Ggplot2GanttLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the gantt layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return List with data, selectors, axes and orientation
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

      built_data <- self$get_layer_built_data(built, panel_id)
      lane_axis <- segment_lane_axis(built_data)
      grouped <- segment_lanes(
        built_data, lane_axis,
        self$lane_names(built, lane_axis, panel_id)
      )

      list(
        data = grouped$data,
        lanes = grouped$lanes,
        # A gantt drawn the ordinary way runs its bars left to right, which
        # puts the axis on x and the lanes on y. The frontend calls that
        # orientation "horz" and swaps the two axis labels itself, so the
        # labels below stay the plot's own.
        orientation = if (identical(lane_axis, "y")) "horz" else "vert",
        selectors = self$generate_selectors(gt, plot, panel_ctx, grouped$order),
        axes = self$extract_axes(plot, built)
      )
    },

    #' @description Name the lanes, in the order the scale lays them out
    #'
    #'   Read off the panel's own view of the scale rather than off the
    #'   source column: the built data records a discrete lane as the position
    #'   ggplot2 gave it (1, 2, 3), and the panel's limits are the levels in
    #'   the same order, so the two line up by index. That is also what makes
    #'   an undrawn level visible -- `scale_y_discrete(drop = FALSE)` keeps it
    #'   in the limits, and it is a lane holding nothing.
    #'
    #'   NULL for a continuous lane axis, which has no names to give.
    #' @param built Built plot data
    #' @param lane_axis "y", "x", or NULL
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return Character vector of lane names, or NULL
    lane_names = function(built, lane_axis, panel_id = NULL) {
      if (is.null(lane_axis) || is.null(built$layout$panel_params)) {
        return(NULL)
      }
      index <- self$resolve_panel_index(built, panel_id)
      view <- built$layout$panel_params[[index]][[lane_axis]]
      if (is.null(view)) {
        return(NULL)
      }
      discrete <- tryCatch(view$is_discrete(), error = function(e) FALSE)
      if (!isTRUE(discrete) || is.null(view$limits)) {
        return(NULL)
      }
      as.character(view$limits)
    },

    #' @description Name the two axes
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

    #' @description Address each drawn interval by its own element
    #'
    #'   \code{GeomSegment} draws every interval in one \code{segmentsGrob},
    #'   and gridSVG exports that as one element per segment carrying an id of
    #'   the form \code{<grob>.1.<n>} -- measured, a four-interval chart gives
    #'   \code{GRID.segments.38.1.1} through \code{.4}, in built-data order.
    #'   So an interval is addressed by the built row it came from, and the
    #'   list follows the regrouping rather than the document.
    #'
    #'   Flat rather than nested, because the frontend slices it per lane
    #'   using the lane lengths it already has -- and withdraws highlighting
    #'   outright unless the resolved count matches the interval count
    #'   exactly. A partial list is therefore worse than none, so an empty
    #'   list is returned when the grob cannot be found rather than a guess at
    #'   its name.
    #' @param gt Gtable object
    #' @param plot The ggplot2 object, used to build a gtable when none is given
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @param order The built-data row behind each interval, in emission order
    #' @return A list of CSS selectors, one per interval
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

      grob_name <- self$find_segments_name(plot, gt, panel_ctx)
      if (is.null(grob_name)) {
        return(list())
      }

      # The two geoms put the row number in different places, because the two
      # grobs reach one-element-per-row by different routes. gridSVG splits a
      # `segments` grob itself and numbers the pieces after the grob's own
      # `.1`; a `curve` grob is split by `split_vectorised_curve_grobs()` into
      # children already named `<grob>.<row>`, and gridSVG then appends its
      # `.1` to each. Measured: `GRID.segments.1.1.3` against
      # `GRID.curve.1.3.1` for the same third interval.
      curve <- identical(self$target_geom_class(plot), "GeomCurve")
      lapply(order, function(index) {
        id <- if (curve) {
          paste0(grob_name, ".", index, ".1")
        } else {
          paste0(grob_name, ".1.", index)
        }
        paste0("*[id='", id, "']")
      })
    },

    #' @description The class of the geom this layer was drawn with
    #'
    #'   Both the grob to look for and the shape of its exported element ids
    #'   follow from it, so it is asked once and answered from the plot rather
    #'   than inferred from what happens to be in the panel.
    #' @param plot The ggplot2 object
    #' @return The geom's class name, or NULL when the layer cannot be found
    target_geom_class = function(plot) {
      target <- self$get_layer_index()
      if (is.null(plot) || is.null(plot$layers) || is.null(target) ||
        target < 1L || target > length(plot$layers)) {
        return(NULL)
      }
      class(plot$layers[[target]]$geom)[1]
    },

    #' @description Find the name of the grob holding this layer's segments
    #'
    #'   The base class's \code{find_layer_grob_tree()} cannot serve here, and
    #'   the reason is worth recording: it matches a grob whose name begins
    #'   with the geom's own prefix, and ggplot2 does not give a segment layer
    #'   one. The grob arrives with grid's automatic name -- measured,
    #'   \code{GRID.segments.38} -- so there is no \code{geom_segment.} to
    #'   match and the lookup returns NULL, which is a layer that announces
    #'   every interval and highlights none of them.
    #'
    #'   The disambiguation rule is the same one that helper applies, keyed on
    #'   the grob's **class** instead: the nth segment layer of the plot draws
    #'   the nth segments grob of the panel. Two \code{geom_segment()} layers
    #'   would otherwise both resolve to the first one's elements, and the
    #'   second would highlight the first's intervals while announcing its own.
    #'
    #'   The number in that automatic name is grid's global counter and is not
    #'   stable between sessions, which is exactly why it is read off the
    #'   gtable being exported rather than reconstructed.
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return The grob name, or NULL when it cannot be resolved
    find_segments_name = function(plot, gt, panel_ctx = NULL) {
      target <- self$get_layer_index()
      if (is.null(plot) || is.null(plot$layers) || is.null(target) ||
        target < 1L || target > length(plot$layers)) {
        return(NULL)
      }

      # Counted among its own kind, not among gantt layers generally: a
      # `geom_curve()` after a `geom_segment()` is the *first* curve grob of
      # the panel, and counting both together would send it to the second
      # segments grob -- which does not exist.
      geom_class <- class(plot$layers[[target]]$geom)[1]
      grob_class <- if (identical(geom_class, "GeomCurve")) "curve" else "segments"

      position <- 0L
      for (i in seq_along(plot$layers)) {
        if (identical(class(plot$layers[[i]]$geom)[1], geom_class)) {
          position <- position + 1L
          if (i == target) break
        }
      }

      roots <- if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (is.null(panel_grob)) list() else list(panel_grob)
      } else if ("grobs" %in% names(gt)) {
        gt$grobs
      } else {
        list(gt)
      }

      names <- character(0)
      collect <- function(node) {
        if (inherits(node, grob_class)) {
          name <- node$name
          if (!is.null(name) && is.character(name) && length(name) == 1L) {
            names <<- c(names, name)
          }
          return(invisible(NULL))
        }
        if (inherits(node, "gTree")) {
          for (child in node$children) collect(child)
        }
        if (inherits(node, "gList")) {
          for (i in seq_along(node)) collect(node[[i]])
        }
        invisible(NULL)
      }
      for (root in roots) collect(root)

      if (position < 1L || position > length(names)) {
        return(NULL)
      }
      names[[position]]
    }
  )
)
