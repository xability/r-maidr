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


#' Read a rectangle layer's bounds as the spans and lanes they draw
#'
#' A declared \code{maidr_gantt()} layer builds \code{xmin}, \code{xmax},
#' \code{ymin} and \code{ymax}, and none of the four columns
#' \code{segment_lane_axis()} is keyed on. Measured, today's processor fed a
#' rect frame unchanged answers \code{data lanes: 0 | lanes: NULL |
#' selectors: 0} -- a confident empty schedule, which is a false claim of a
#' different kind from the one #197 is about. So the frame is renamed into the
#' segment spelling here and every landed function downstream runs unchanged.
#'
#' The lane is the band's midpoint rather than either edge, so a lane sits
#' where a reader sees it and a band drawn upside down (\code{ymin > ymax})
#' lands in the same place. The span keeps both bounds; \code{segment_lanes()}
#' already sorts a span written backwards.
#'
#' Measured on the repository's own four-interval schedule (\code{ymin =
#' 0.6, 1.6, 2.6, 1.6}), the normalised frame gives \code{segment_lane_axis()
#' = "y"}, lane sizes \code{1, 2, 1} and emission order \code{1, 2, 4, 3};
#' the processed layer's \code{data}, \code{lanes}, \code{orientation} and
#' \code{axes} come back \code{identical()} to the \code{geom_segment()}
#' spelling of the same schedule, and only the grob the selectors name
#' differs.
#'
#' The degenerate guard falls out of the renaming rather than being a rule:
#' rectangles of zero width normalise to level on both axes, which
#' \code{segment_lane_axis()} already refuses.
#'
#' @param built_data A layer's computed data, carrying \code{xmin},
#'   \code{xmax}, \code{ymin} and \code{ymax}, one row per drawn rectangle
#' @param lane_axis \code{"y"} when the lanes run up y and the spans along x,
#'   \code{"x"} for the mirror image, as the author declared it
#' @return The frame with \code{x}, \code{xend}, \code{y} and \code{yend}
#'   added, or NULL when it is not a rectangle layer's frame
#' @keywords internal
rect_gantt_frame <- function(built_data, lane_axis = "y") {
  if (is.null(built_data) || nrow(built_data) == 0) {
    return(NULL)
  }
  if (!all(c("xmin", "xmax", "ymin", "ymax") %in% names(built_data))) {
    return(NULL)
  }
  # A frame that already carries the segment spelling is a segment layer's
  # and is left to the functions that were written for it. Nothing in
  # ggplot2 3.4.4 builds both spellings at once, so this refuses a shape that
  # does not arise rather than guessing between two readings of one that does.
  if (all(c("x", "xend", "y", "yend") %in% names(built_data))) {
    return(NULL)
  }

  if (identical(lane_axis, "x")) {
    lane <- (built_data$xmin + built_data$xmax) / 2
    built_data$x <- lane
    built_data$xend <- lane
    built_data$y <- built_data$ymin
    built_data$yend <- built_data$ymax
  } else {
    lane <- (built_data$ymin + built_data$ymax) / 2
    built_data$y <- lane
    built_data$yend <- lane
    built_data$x <- built_data$xmin
    built_data$xend <- built_data$xmax
  }

  built_data
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


#' Whether an axis label names a lane or just writes its own coordinate out
#'
#' A continuous axis has labels too -- "1", "0.5", "1,000" -- but those are
#' formatted renderings of the numbers rather than names for them, which is
#' the distinction \code{discrete_axis_labels()} already draws for a discrete
#' scale and xability/py-maidr#533 settled for lanes: an explicit tick names
#' the lane it sits in, and the axis's own coordinates do not.
#'
#' So the test is "is this label a rendering of its own number", not "is there
#' a label". Measured on ggplot2 3.4.4, bands at 0.6-1.4, 1.6-2.4, 2.6-3.4:
#'
#' \preformatted{
#' default scale                             1, 2, 3            -> position
#' breaks = 1:3, labels = c("design", ...)   design, build, test -> name
#' breaks = 1:3, labels = c("1", "2", "3")   1, 2, 3            -> position
#' breaks = 1:3                              1, 2, 3            -> position
#' breaks = seq(0, 4, 0.5)                   0.5, 1.0, 1.5, ... -> position
#' }
#'
#' An author who writes \code{labels = c("1", "2", "3")} is deliberately
#' naming lanes "1", "2" and "3" and gets positions instead. That is the trade
#' py-maidr made, and it is the safe direction: a lane called "2" says less
#' than a lane called by the position 2 it sits at.
#'
#' The strip is what keeps \code{scales::comma}, \code{scales::dollar} and a
#' padded label from reading as names -- measured, \code{"1,000"} at the
#' break 1000 and \code{"$1"} at 1 both come back FALSE. It does not save
#' \code{scales::percent}, which renders the break 1 as \code{"100\%"}:
#' measured, that reads as a name and a lane is called \code{"100\%"} rather
#' than 1.
#' The cost is a cosmetic mis-name inside a schedule the author already
#' declared, not a false claim, so it is recorded rather than chased.
#'
#' @param label One axis label
#' @param break_value The break the label was drawn at
#' @return TRUE when the label is a name rather than the break written out
#' @keywords internal
label_names_its_lane <- function(label, break_value) {
  if (length(label) != 1L || is.na(label) || !nzchar(label)) {
    return(FALSE)
  }
  number <- suppressWarnings(as.numeric(gsub("[ ,$%]", "", label)))
  if (is.na(number)) {
    return(TRUE)
  }
  !isTRUE(all.equal(number, break_value))
}


#' Gantt Layer Processor
#'
#' @description
#' Processes \code{geom_segment()} layers that draw intervals in lanes, and
#' \code{maidr_gantt()} layers whose author declared that their rectangles do.
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
#' A declared rectangle layer has none of those four columns -- it builds
#' \code{xmin}, \code{xmax}, \code{ymin} and \code{ymax} -- so
#' \code{rect_gantt_frame()} renames its bounds into them before anything
#' here runs. That is the whole of the rect path: the lanes, the ordering,
#' the orientation and the axes are then this class answering one question
#' rather than two implementations of it, and the processed layer comes back
#' \code{identical()} to the \code{geom_segment()} spelling of the same
#' schedule in everything but the grob its selectors name. Only the lane
#' *names* need their own route, because a rectangle layer's lane axis is
#' continuous and \code{lane_names()} reads levels off a discrete one.
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

      # A declared `maidr_gantt()` layer arrives as rectangles and is renamed
      # into the segment spelling before anything below runs, so the lanes,
      # the ordering, the orientation and the axes are the landed code
      # answering one question rather than two implementations of it.
      rect <- rect_gantt_frame(built_data, self$declared_lane_axis(plot))
      if (!is.null(rect)) {
        built_data <- rect
      }

      lane_axis <- segment_lane_axis(built_data)
      grouped <- segment_lanes(
        built_data, lane_axis,
        self$lane_names(built, lane_axis, panel_id)
      )
      if (!is.null(rect)) {
        grouped <- self$name_rect_lanes(
          grouped, built, built_data, lane_axis, panel_id
        )
      }

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

    #' @description Which axis this layer's author said the lanes run up
    #'
    #'   Read off the layer rather than inferred, because inference is not
    #'   available: measured, both axes partition for the target schedule and
    #'   for one whose tasks all take the same time, so structure can neither
    #'   confirm nor contradict what the author meant. \code{"y"} when nothing
    #'   was declared, which is what a \code{geom_segment()} gantt drawn the
    #'   ordinary way also reads as.
    #' @param plot The ggplot2 object
    #' @return \code{"y"} or \code{"x"}
    declared_lane_axis = function(plot) {
      layer_declared_lane_axis(self$get_own_layer(plot))
    },

    #' @description Name a rectangle gantt's lanes from the ticks inside them
    #'
    #'   \code{lane_names()} above cannot serve, and the reason is measured:
    #'   it requires \code{view$is_discrete()}, and a rectangle layer written
    #'   with the author's own numeric \code{ymin}/\code{ymax} trains a
    #'   continuous scale -- measured, \code{is_discrete()} is FALSE and
    #'   \code{limits} is the range \code{0.6, 3.4} rather than a list of
    #'   levels. The lanes are there; the scale just has no names to lend them.
    #'
    #'   So a lane is named by the single explicit tick drawn inside it, and
    #'   by its position otherwise -- the rule xability/py-maidr#533 settled.
    #'   Two guards come with it and both are that issue's: a band holding
    #'   more than one tick is named by none of them, and a band holding none
    #'   is named by its position.
    #'
    #'   Read off \code{built$layout$panel_params}, never
    #'   \code{layer_scales()}: measured on the default scale the panel's
    #'   view gives breaks \code{NA, 1, 2, 3, NA} while \code{layer_scales()}
    #'   gives \code{NA, 1, 1.5, 2, 2.5, 3, NA} -- two ticks per band, which
    #'   defeats the one-tick rule in exactly the case the rule exists for.
    #'   The \code{NA} padding is dropped.
    #' @param grouped The lanes as \code{segment_lanes()} grouped them
    #' @param built Built plot data
    #' @param built_data The normalised frame, carrying the bounds and the lane
    #' @param lane_axis "y", "x", or NULL
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return \code{grouped} with its named lanes renamed
    name_rect_lanes = function(grouped, built, built_data, lane_axis,
                               panel_id = NULL) {
      if (is.null(lane_axis) || length(grouped$data) == 0 ||
        !is.null(grouped$lanes)) {
        return(grouped)
      }

      lows <- built_data[[paste0(lane_axis, "min")]]
      highs <- built_data[[paste0(lane_axis, "max")]]
      positions <- built_data[[lane_axis]]
      if (is.null(lows) || is.null(highs) || is.null(positions)) {
        return(grouped)
      }
      usable <- is.finite(positions) & is.finite(lows) & is.finite(highs)
      slots <- sort(unique(positions[usable]))
      if (length(slots) != length(grouped$data)) {
        return(grouped)
      }

      ticks <- self$lane_ticks(built, lane_axis, panel_id)
      if (is.null(ticks)) {
        return(grouped)
      }

      names <- vapply(slots, function(slot) {
        rows <- usable & positions == slot
        band_low <- min(pmin(lows[rows], highs[rows]))
        band_high <- max(pmax(lows[rows], highs[rows]))
        inside <- which(ticks$breaks > band_low & ticks$breaks < band_high)
        if (length(inside) != 1L) {
          return(NA_character_)
        }
        if (!label_names_its_lane(ticks$labels[[inside]], ticks$breaks[[inside]])) {
          return(NA_character_)
        }
        ticks$labels[[inside]]
      }, character(1))

      # `lanes` is only emitted once something is named. A chart where no tick
      # names anything keeps the reading a continuous `geom_segment()` gantt
      # has -- numeric positions and no `lanes` key -- rather than being given
      # a list of its own coordinates spelled out twice.
      if (all(is.na(names))) {
        return(grouped)
      }

      for (i in seq_along(grouped$data)) {
        if (is.na(names[[i]])) {
          next
        }
        grouped$data[[i]] <- lapply(grouped$data[[i]], function(one) {
          one$x <- names[[i]]
          one
        })
      }
      grouped$lanes <- lapply(seq_along(slots), function(i) {
        if (is.na(names[[i]])) as.numeric(slots[[i]]) else names[[i]]
      })
      grouped
    },

    #' @description The lane axis's drawn ticks, with the padding dropped
    #'
    #'   \code{panel_params} is keyed by the axis the chart *draws*, not the
    #'   axis the data lives on, and \code{coord_flip()} swaps the two. So the
    #'   panel is asked for the drawn counterpart of \code{lane_axis} rather
    #'   than for \code{lane_axis} itself.
    #'
    #'   Indexing by \code{lane_axis} reads the span axis under a flip, and
    #'   the wrong answer is worth writing down because it is two different
    #'   wrong answers. Measured on ggplot2 3.4.4, the example schedule with
    #'   \code{coord_flip()} added: with the time axis given its own named
    #'   breaks the lanes came back \code{Jan, Feb, Mar} -- names the chart
    #'   draws along the other axis -- and with the ordinary numeric time
    #'   breaks \code{0, 5, 10, 15} every label failed
    #'   \code{label_names_its_lane()} and the lanes silently lost their names
    #'   altogether, on a chart drawing \code{design, build, test}. Both are
    #'   pinned in \code{tests/testthat/test-gantt-rect.R}.
    #'
    #'   The breaks travel with the labels, so they stay comparable with the
    #'   bands: measured under the flip, \code{panel_params[[1]]$x} gives
    #'   breaks \code{1, 2, 3} against bands \code{0.6-1.4}, \code{1.6-2.4}
    #'   and \code{2.6-3.4}, which are data-space \code{ymin}/\code{ymax}.
    #'
    #'   \code{class()[1]} is \code{"CoordFlip"} here -- measured -- but the
    #'   test is \code{inherits()}, because it is asking whether the coord
    #'   flips rather than which coord it is.
    #'
    #'   \code{lane_names()} above indexes by \code{lane_axis} too and is
    #'   deliberately left alone: it requires \code{view$is_discrete()}, a
    #'   rectangle layer's numeric bounds always train a continuous lane axis,
    #'   and so it cannot reach a rect gantt at all. Measured, the
    #'   \code{geom_segment()} spelling of the same flipped chart comes back
    #'   with no \code{lanes} rather than with borrowed ones, which is the
    #'   reading it has today and not this issue's to change.
    #' @param built Built plot data
    #' @param lane_axis "y", "x", or NULL
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of \code{breaks} and \code{labels}, or NULL
    lane_ticks = function(built, lane_axis, panel_id = NULL) {
      if (is.null(lane_axis) || is.null(built$layout$panel_params)) {
        return(NULL)
      }
      drawn <- if (inherits(built$layout$coord, "CoordFlip")) {
        c(x = "y", y = "x")[[lane_axis]]
      } else {
        lane_axis
      }
      view <- built$layout$panel_params[[
        self$resolve_panel_index(built, panel_id)
      ]][[drawn]]
      if (is.null(view)) {
        return(NULL)
      }
      breaks <- tryCatch(view$get_breaks(), error = function(e) NULL)
      labels <- tryCatch(view$get_labels(), error = function(e) NULL)
      if (is.null(breaks) || is.null(labels) ||
        length(breaks) != length(labels)) {
        return(NULL)
      }
      labels <- as.character(labels)
      # The panel's view pads its breaks with NA at both ends -- measured,
      # `NA, 1, 2, 3, NA` on the default scale -- and an NA break is not a
      # tick any band can hold.
      keep <- !is.na(breaks) & !is.na(labels)
      if (!any(keep)) {
        return(NULL)
      }
      list(breaks = breaks[keep], labels = labels[keep])
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

    #' @description Which grid grob class a segment-family geom draws
    #' @details
    #'   \code{geom_curve()} draws a \code{curve} grob and everything else in
    #'   the family -- \code{geom_segment()}, and \code{geom_spoke()} which is
    #'   a \code{GeomSegment} subclass -- draws \code{segments}. Asked of the
    #'   geom rather than assumed from the layer type, because it decides both
    #'   which grobs \code{find_segments_name()} gathers and which layers it
    #'   counts itself among, and those two have to be the same population.
    #' @param geom The layer's geom object
    #' @return \code{"curve"} or \code{"segments"}
    segments_grob_class = function(geom) {
      if (identical(class(geom)[1], "GeomCurve")) "curve" else "segments"
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

      # A declared rectangle gantt is looked up by name instead, because the
      # search below is by grob *class* and the theme draws rects too. See
      # `find_rect_name()` for the measurement.
      if (identical(class(plot$layers[[target]]$geom)[1], "GeomRect")) {
        return(self$find_rect_name(plot, gt, panel_ctx, target))
      }

      # Counted among the layers drawing the *same grob class*, not among
      # gantt layers generally and not among layers of the same geom either.
      #
      # Not generally, because a `geom_curve()` after a `geom_segment()` is
      # the first curve grob of the panel, and counting both together would
      # send it to the second segments grob -- which does not exist.
      #
      # Not by geom, because two different geoms can draw one grob class:
      # `geom_spoke()` is a `GeomSegment` subclass and draws `segments` too
      # (#225). Counting by geom gave a segment layer and a spoke layer
      # `position == 1` apiece while `names` held one entry for each, so both
      # resolved to the first grob and the second layer highlighted the
      # first's intervals while announcing its own. Measured before the fix,
      # a two-lane segment layer and a three-lane spoke layer:
      #
      #     gantt (2 lanes)  GRID.segments.1.1.1  GRID.segments.1.1.2
      #     gantt (3 lanes)  GRID.segments.1.1.1  GRID.segments.1.1.2  ...
      #
      # `grob_class` is what `collect()` below gathers by, so counting on it
      # is counting the same population the index is into.
      grob_class <- self$segments_grob_class(plot$layers[[target]]$geom)

      position <- 0L
      for (i in seq_along(plot$layers)) {
        same <- identical(
          self$segments_grob_class(plot$layers[[i]]$geom), grob_class
        )
        if (same) {
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
    },

    #' @description Find the name of the grob holding a rect layer's bars
    #'
    #'   The opposite way round from \code{find_segments_name()}, and for a
    #'   measured reason: a rectangle layer *is* given a geom-prefixed grob
    #'   name, and the grob class is useless because the theme draws rects
    #'   too. Collecting every \code{rect}-class grob of a lone rect chart
    #'   gave, in tree order,
    #'
    #'   \preformatted{
    #'   plot.background..rect.33  panel.background..rect.6  geom_rect.rect.2
    #'   }
    #'
    #'   so position 1 is the plot background and the reader would have the
    #'   whole page highlighted for their first task. The name prefix
    #'   \code{^geom_rect\\.} matches the drawn bars and none of the theme's
    #'   rects.
    #'
    #'   Every number in a grob name here is grid's global counter, which
    #'   \code{find_segments_name()} above already records as not stable
    #'   between sessions -- the same chart measured second in a session
    #'   numbers higher. What was measured is the tree order and the rect
    #'   counts; each listing below is from its own fresh session.
    #'
    #'   The counter is the other half. ggplot2 names a drawn grob after the
    #'   geom whose \code{draw_panel()} made it, and \code{GeomRect$
    #'   draw_panel()} hard-codes \code{geom_rect}, so \code{geom_tile()},
    #'   \code{geom_bar()} and \code{geom_col()} all emit
    #'   \code{geom_rect.rect.*} grobs while \code{geom_grob_prefix()} calls
    #'   them \code{geom_tile}/\code{geom_bar}/\code{geom_col}. Measured,
    #'   \code{geom_col(5 bars) + geom_rect(4 rects)} draws two of them --
    #'   \code{geom_rect.rect.2} holding the 5 bars and
    #'   \code{geom_rect.rect.4} holding the 4 bands -- and the base class's
    #'   \code{find_layer_grob_tree()} hands the rect layer the first, the
    #'   column chart's bars. Counting the target among
    #'   \code{inherits(geom, "GeomRect")} layers makes the counted
    #'   population the drawn population and resolves it to the second;
    #'   measured the same for \code{geom_tile(9) + geom_rect(4)}, which
    #'   draws 9 then 4 under the same two names.
    #'
    #'   \code{inherits()} rather than a written-out list of class names, so
    #'   that a rect subclass this package has never heard of is counted as
    #'   what it draws. Measured, \code{GeomTile}, \code{GeomBar} and
    #'   \code{GeomCol} all inherit \code{GeomRect}; \code{GeomRaster} does
    #'   not, and draws \code{GRID.rastergrob.*} rather than a rect, so the
    #'   two populations agree on it as well. \code{GeomRectCS}, the
    #'   candlestick body, inherits it too -- measured against tidyquant
    #'   1.0.12, where \code{inherits(GeomRectCS, "GeomRect")} is TRUE and
    #'   \code{class(GeomRectCS)[1]} is \code{"GeomRectCS"}.
    #'
    #'   Scoped to this lookup. The same miscount reaches any bar, heat or
    #'   candlestick layer sharing a panel with another rect-drawn geom
    #'   through \code{find_layer_grob_tree()}; that is a defect this change
    #'   did not introduce and does not widen.
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @param target This layer's index among the plot's layers
    #' @return The grob name, or NULL when it cannot be resolved
    find_rect_name = function(plot, gt, panel_ctx = NULL, target = NULL) {
      if (is.null(target)) {
        target <- self$get_layer_index()
      }

      position <- 0L
      for (i in seq_along(plot$layers)) {
        if (inherits(plot$layers[[i]]$geom, "GeomRect")) {
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
        name <- node$name
        if (!is.null(name) && is.character(name) && length(name) == 1L &&
          grepl("^geom_rect\\.", name)) {
          names <<- c(names, name)
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
