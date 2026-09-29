#' The rows of a panel that belong to one group
#'
#' `panel.superpose()` draws each group from the panel's rows whose group is
#' that level, keeping the rows' order, so these are the rows behind a
#' `.group.<k>` grob, in the order its marks were drawn.
#'
#' @param args The panel's arguments, as its panel function received them
#' @param group The group's number (see [lattice_group_levels()]), or NA for
#'   an ungrouped panel
#' @return Logical vector over the panel's rows.
#' @keywords internal
lattice_group_rows <- function(args, group) {
  n <- length(args[["x"]])
  groups <- args[["groups"]]
  if (is.na(group) || is.null(groups)) {
    return(rep(TRUE, n))
  }
  levels <- if (is.factor(groups)) {
    levels(groups)
  } else {
    as.character(sort(unique(groups)))
  }
  subscripts <- args[["subscripts"]]
  row_groups <- groups[if (is.null(subscripts)) seq_len(n) else subscripts]
  !is.na(row_groups) & as.character(row_groups) == levels[group]
}

#' The navigation grid of a numeric lattice axis
#'
#' What the frontend's grid mode needs to lay a scatter out in cells: the
#' drawn range and the step between the ticks lattice draws. Those are
#' `pretty(limits, n = tick.number)` -- the call lattice's own
#' `formattedTicksAndLabels()` makes -- unless the chart placed them with
#' `at =`. Ticks placed unevenly have no one step, and the grid is left
#' without one rather than given a step the axis does not show.
#'
#' @param limits The packet's limits on this axis
#' @param log The axis' `log` scale component
#' @param at The axis' `at` scale component: `FALSE`, the tick positions,
#'   or a list of them with one element per packet
#' @param tick_number The axis' `tick.number` scale component
#' @param packet The packet, to pick its ticks from a per-packet `at`
#' @return A list with `min`, `max` and, when the ticks are evenly spaced,
#'   `tickStep`; `NULL` for an axis that is not a finite numeric range on a
#'   linear scale.
#' @keywords internal
lattice_axis_grid <- function(limits, log = FALSE, at = NULL, tick_number = NULL,
                              packet = 1L) {
  if (!is.numeric(limits) || length(limits) != 2L || any(!is.finite(limits)) ||
    !(is.null(log) || isFALSE(log))) {
    return(NULL)
  }
  limits <- sort(as.numeric(limits))
  if (is.list(at)) {
    at <- if (length(at) >= packet) at[[packet]] else NULL
  }
  ticks <- if (is.numeric(at)) {
    sort(unique(at[is.finite(at)]))
  } else {
    pretty(limits, n = if (is.numeric(tick_number)) tick_number[1] else 5)
  }
  steps <- diff(ticks)
  even <- length(steps) > 0L &&
    isTRUE(all.equal(steps, rep(steps[1], length(steps)), tolerance = 1e-8))
  grid <- list(min = limits[1], max = limits[2])
  if (even) {
    grid$tickStep <- steps[1]
  }
  grid
}

#' The kind of time a lattice axis is drawn in
#'
#' lattice draws a `Date` axis in days since 1970 and a `POSIXct` one in
#' seconds, and keeps the class on the axis' limits, which is how the two
#' are told apart from an axis of plain numbers.
#'
#' @param limits The packet's limits on the axis
#' @return `"date"`, `"datetime"`, or `NULL` for an axis that is not a time.
#' @keywords internal
lattice_time_kind <- function(limits) {
  if (inherits(limits, "Date")) {
    "date"
  } else if (inherits(limits, "POSIXct")) {
    "datetime"
  } else {
    NULL
  }
}

#' Drawn time coordinates as the frontend reads a time
#'
#' maidr.js reads a time as milliseconds since 1970: its `date` axis format
#' is `new Date(value)`, and its own chart adapters carry a time axis that
#' way. Announced as drawn, a date would be the count of days since 1970 --
#' `"19723"` where the axis says January 2024.
#'
#' @param values Numeric values as lattice drew them
#' @param limits The packet's limits on the axis
#' @return The values in milliseconds on a time axis, unchanged otherwise.
#' @keywords internal
lattice_time_milliseconds <- function(values, limits) {
  kind <- lattice_time_kind(limits)
  if (is.null(kind)) {
    return(values)
  }
  values * if (kind == "date") 86400000 else 1000
}

#' The time zone a time axis is announced in
#'
#' A date is a calendar day, which [lattice_time_milliseconds()] puts at
#' midnight UTC, so it is announced in UTC. A date-time axis is labelled by
#' lattice in the time zone its limits carry and otherwise in the session's
#' own -- the `TZ` environment variable when it is set, which
#' `Sys.timezone()` does not report, and the system's zone when not -- and
#' is announced in the same one. `Intl.DateTimeFormat` throws on a zone it
#' does not know, which would take the announcement out rather than the
#' zone, so only a zone in the Olson database is passed on.
#'
#' @param limits The packet's limits on the axis
#' @return An IANA time zone name.
#' @keywords internal
lattice_time_zone <- function(limits) {
  if (!identical(lattice_time_kind(limits), "datetime")) {
    return("UTC")
  }
  zones <- c(attr(limits, "tzone"), Sys.getenv("TZ"), Sys.timezone())
  zones <- zones[!is.na(zones) & nzchar(zones)]
  zones <- zones[zones %in% OlsonNames()]
  if (length(zones)) zones[1] else "UTC"
}

#' The format a time axis is announced with
#'
#' @param limits The packet's limits on the axis
#' @return An axis `format` list, or `NULL` for an axis that is not a time.
#' @keywords internal
lattice_time_format <- function(limits) {
  kind <- lattice_time_kind(limits)
  if (is.null(kind)) {
    return(NULL)
  }
  options <- list(year = "numeric", month = "short", day = "numeric")
  if (kind == "datetime") {
    options <- c(options, list(hour = "numeric", minute = "2-digit", second = "2-digit"))
  }
  options$timeZone <- lattice_time_zone(limits)
  list(type = "date", dateOptions = options)
}

#' The format a time series' time axis is announced with
#'
#' A time series is drawn against `time()`, in years, which the frontend
#' announces to two decimals unless told otherwise. That keeps apart the
#' observations of a series sampled fewer than 100 times a year, but not of
#' a daily one: `EuStockMarkets`, at 260 a year, read "Time is 1991.5" for
#' three trading days running. R prints such a series' times with the digits
#' that tell them apart (`1991.496`, `1991.500`, `1991.504`), and so are they
#' announced.
#'
#' @param plot A trellis object
#' @param times The panel's x values
#' @return A `fixed` axis format, or `NULL` when the default keeps the times
#'   apart or the chart is not of a time series.
#' @keywords internal
lattice_series_time_format <- function(plot, times) {
  if (!lattice_is_time_series(plot)) {
    return(NULL)
  }
  times <- as.numeric(times)
  times <- sort(unique(times[is.finite(times)]))
  if (length(times) < 2L) {
    return(NULL)
  }
  # The fewest decimals whose step is finer than the sampling interval; the
  # small allowance keeps a frequency of 1000 from reading as 999.9999.
  decimals <- floor(log10(1 / min(diff(times))) + 1e-6) + 1L
  if (decimals <= 2L) {
    return(NULL)
  }
  list(type = "fixed", decimals = as.integer(decimals))
}

#' lattice Layer Processor
#'
#' @description
#' Base class for the processors that read a layer of a lattice panel. A
#' processor is handed the trellis object, the panel it reads
#' (`panel_ctx`) and the grobs its layer was drawn as (`layer_info$grobs`),
#' and answers the layer as the orchestrator emits it -- or `NULL` when its
#' marks cannot be read, which makes the whole chart fall back to an image.
#'
#' A layer with nothing drawn in it -- a group with no finite value -- is
#' answered with empty `data`, and the orchestrator leaves it out.
#'
#' `panel_ctx` carries `packet`, `column` and `row` (the layout cell lattice
#' drew the panel in), `args` (the panel's arguments, as its panel function
#' received them), `title`, the packet's `x_limits` and `y_limits`, and the
#' chart's `group_levels` and `group_title`.
#'
#' @keywords internal
LatticeLayerProcessor <- R6::R6Class(
  "LatticeLayerProcessor",
  inherit = LayerProcessor,
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
      stop("process() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description The grob one of the layer's entries was drawn as
    #'
    #' [lattice_draw_scene()] grabs every grob lattice draws as a child of
    #' the scene, so the grob is looked up by name among those first.
    #' `grid::getGrob()` walks the children from the first, and a walk for
    #' every group's grob made reading a chart quadratic in its number of
    #' groups; it is kept for a grob drawn inside another.
    #'
    #' @param gt The drawn chart
    #' @param entry A grob entry of the layer
    #' @return The grob, or NULL when the chart holds none of that name
    grob = function(gt, entry) {
      tryCatch(
        gt[["children"]][[entry$name]] %||% grid::getGrob(gt, entry$name),
        error = function(e) NULL
      )
    },

    #' @description The name of the group a grob entry was drawn for
    #' @param panel_ctx The panel
    #' @param entry A grob entry of the layer
    #' @return A string, or NULL for an ungrouped entry
    group_label = function(panel_ctx, entry) {
      group <- entry$group
      levels <- panel_ctx$group_levels
      if (is.null(group) || is.na(group) || is.null(levels) || group > length(levels)) {
        return(NULL)
      }
      # A time series is grouped by a dummy factor with one level, "1".
      if (length(levels) == 1L && identical(levels, "1")) {
        return(NULL)
      }
      levels[group]
    },

    #' @description The layer's axes, with the grouping variable as z
    #' @param layout The figure's layout
    #' @param panel_ctx The panel
    #' @param grouped Whether the layer names its series or layers by group
    #' @return Canonical axes list
    layer_axes = function(layout, panel_ctx, grouped = FALSE) {
      build_axes(
        x = layout$x_label,
        y = layout$y_label,
        z = if (grouped) panel_ctx$group_title
      )
    },

    #' @description A drawn coordinate on the data's own scale
    #' @param values Numeric values as lattice drew them
    #' @param axis `"x"` or `"y"`
    #' @param plot The trellis object
    #' @return The values, back-transformed from a log scale
    axis_values = function(values, axis, plot) {
      scales <- if (axis == "x") plot$x.scales else plot$y.scales
      lattice_untransform(as.numeric(values), scales$log)
    },

    #' @description A drawn coordinate as a point or a line carries it
    #'
    #' `axis_values()`, and on a date or date-time axis the instant it
    #' stands for, in milliseconds since 1970 (see
    #' `lattice_time_milliseconds()`); a processor that emits it so gives
    #' the layer's axes the time format with `time_axes()`.
    #'
    #' @param values Numeric values as lattice drew them
    #' @param axis `"x"` or `"y"`
    #' @param plot The trellis object
    #' @param panel_ctx The panel
    #' @return Numeric values
    position_values = function(values, axis, plot, panel_ctx) {
      limits <- if (axis == "x") panel_ctx$x_limits else panel_ctx$y_limits
      lattice_time_milliseconds(self$axis_values(values, axis, plot), limits)
    },

    #' @description Axes with the format of each time axis attached
    #'
    #' The format that announces the milliseconds `position_values()` emits
    #' on a date or date-time axis as the date they stand for, and, on a
    #' time series' time axis, the decimals that keep its observations apart
    #' ([lattice_series_time_format()]).
    #'
    #' @param axes Canonical axes list
    #' @param panel_ctx The panel
    #' @return The axes
    time_axes = function(axes, panel_ctx) {
      x_format <- lattice_time_format(panel_ctx$x_limits) %||% panel_ctx$x_format
      axes <- attach_axis_format(axes, "x", x_format)
      attach_axis_format(axes, "y", lattice_time_format(panel_ctx$y_limits))
    },

    #' @description The category a drawn coordinate on a factor axis stands for
    #'
    #' lattice draws a factor at its level's position, `1..nlevels`, and
    #' `stripplot()` jitters it by less than half a position.
    #'
    #' @param values Numeric positions as lattice drew them
    #' @param limits The packet's limits on that axis: the level names
    #' @return A list with the integer `position` and the level `label`
    category_of = function(values, limits) {
      position <- as.integer(round(as.numeric(values)))
      label <- ifelse(
        !is.na(position) & position >= 1L & position <= length(limits),
        as.character(limits)[pmax(1L, pmin(position, length(limits)))],
        NA_character_
      )
      list(position = position, label = label)
    }
  )
)
