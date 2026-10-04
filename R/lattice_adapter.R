#' The grobs `panel.xyplot()` draws, by what they are
#'
#' See `LATTICE_PANEL_ROLES`. Shared by the panel functions that draw each
#' group or series with `panel.xyplot()`.
#'
#' @keywords internal
LATTICE_XYPLOT_ROLES <- c(
  points = "^xyplot\\.points$",
  lines = "^xyplot\\.lines$",
  segments = "^xyplot\\.segments$",
  fit = "^(lmline\\.segments|loess\\.lines|spline\\.lines)$",
  average = "^linejoin\\.lines$",
  decoration = "^(grid\\.[hv]|abline\\.(h|v|segments))$"
)

#' The grobs each supported lattice panel function draws, by what they are
#'
#' lattice names every grob it draws inside a panel
#' `<prefix>.<what>[.group.<k>].panel.<column>.<row>`, `<what>` being the
#' panel function's identifier and the primitive it drew
#' (`xyplot.points`, `barchart.x.2.rect`, `density rug.x`). This table says,
#' for each supported panel function, what every `<what>` it can draw is:
#'
#' * a **role** names marks a layer is read from;
#' * `observations` marks the data drawn again as marks nobody navigates --
#'   the jittered points and the rug under a density curve;
#' * `decoration` marks reference lines, grids, contour labels and the like,
#'   which carry no observations.
#'
#' A grob drawn inside a panel that matches none of these is something the
#' reading does not know the meaning of, and the chart falls back to an image
#' rather than being read without it ([lattice_panel_audit()]). The table was
#' taken from a sweep of the stock panel functions over their arguments,
#' lattice 0.23, `type` among them: `panel.dotplot()`, `panel.stripplot()`,
#' `panel.qqmath()` and `panel.qq()` hand `type`, `abline` and `grid` on to
#' `panel.xyplot()`, which draws its lines, spikes, fits and averages under
#' their identifier -- or `xyplot`'s, for a group `panel.superpose()` draws
#' -- and its reference lines under its own.
#'
#' @keywords internal
LATTICE_PANEL_ROLES <- list(
  panel.xyplot = LATTICE_XYPLOT_ROLES,
  # A time series' panel: each series is drawn by `panel.xyplot()`.
  panel.superpose = LATTICE_XYPLOT_ROLES,
  panel.superpose.plain = LATTICE_XYPLOT_ROLES,
  panel.barchart = c(
    bars = "^barchart\\.(rect|(x|y|pos|neg)\\.[0-9]+\\.rect)$",
    decoration = "^barchart\\.abline\\.[hv]$"
  ),
  panel.histogram = c(
    bins = "^histogram\\.rect$",
    decoration = "^histogram\\.baseline\\.lines$"
  ),
  panel.bwplot = c(
    boxes = paste0(
      "^bwplot\\.(box\\.polygon|whisker\\.segments|cap\\.segments|",
      "dot\\.points|dot\\.segments|outlier\\.points)$"
    )
  ),
  panel.densityplot = c(
    curve = "^density\\.lines$",
    observations = "^density( rug\\.x|\\.points)$",
    decoration = "^(density abline\\.h|grid\\.[hv])$"
  ),
  panel.dotplot = c(
    dots = "^(dotplot|xyplot)\\.points$",
    lines = "^(dotplot|xyplot)\\.lines$",
    segments = "^(dotplot|xyplot)\\.segments$",
    fit = LATTICE_XYPLOT_ROLES[["fit"]],
    average = LATTICE_XYPLOT_ROLES[["average"]],
    decoration = "^(dotplot\\.abline\\.[hv]|grid\\.[hv]|abline\\.(h|v|segments))$"
  ),
  panel.stripplot = c(
    points = "^(stripplot|xyplot)\\.points$",
    lines = "^(stripplot|xyplot)\\.lines$",
    segments = "^(stripplot|xyplot)\\.segments$",
    fit = LATTICE_XYPLOT_ROLES[["fit"]],
    average = LATTICE_XYPLOT_ROLES[["average"]],
    decoration = LATTICE_XYPLOT_ROLES[["decoration"]]
  ),
  panel.levelplot = c(
    cells = "^levelplot\\.rect$",
    contours = "^levelplot\\.line\\.[0-9]+\\.lines$",
    decoration = "^levelplot\\.label\\.[0-9]+\\.text$"
  ),
  panel.contourplot = c(
    cells = "^levelplot\\.rect$",
    contours = "^levelplot\\.line\\.[0-9]+\\.lines$",
    decoration = "^levelplot\\.label\\.[0-9]+\\.text$"
  ),
  panel.qqmath = c(
    points = "^qqmath\\.points$",
    lines = "^qqmath\\.lines$",
    segments = "^qqmath\\.segments$",
    fit = LATTICE_XYPLOT_ROLES[["fit"]],
    average = LATTICE_XYPLOT_ROLES[["average"]],
    decoration = LATTICE_XYPLOT_ROLES[["decoration"]]
  ),
  panel.qq = c(
    points = "^qq\\.points$",
    lines = "^qq\\.lines$",
    segments = "^qq\\.segments$",
    fit = LATTICE_XYPLOT_ROLES[["fit"]],
    average = LATTICE_XYPLOT_ROLES[["average"]],
    decoration = "^(qq\\.abline\\.segments|grid\\.[hv]|abline\\.(h|v|segments))$"
  )
)

#' lattice System Adapter
#'
#' @description
#' Adapter for the lattice plotting system. It claims trellis objects, and
#' says which layers each panel of one holds.
#'
#' A trellis object carries no layers of its own: what a panel holds is
#' what its panel function drew there. So the layers are read off the drawn
#' grobs -- which exist, how many there are, and which group each belongs
#' to -- while the values themselves come from the trellis object where it
#' holds them exactly (`panel.args`) and from the grobs where lattice
#' computed them while drawing (a density curve, a loess fit).
#'
#' @format An R6 class inheriting from SystemAdapter
#' @keywords internal
LatticeAdapter <- R6::R6Class(
  "LatticeAdapter",
  inherit = SystemAdapter,
  public = list(
    #' @description Initialize the lattice adapter
    initialize = function() {
      super$initialize("lattice")
    },

    #' @description Check if this adapter can handle a plot object
    #'
    #' A bare latticeExtra `layer()` is also classed `"trellis"`, but it is
    #' an overlay waiting for a chart rather than a chart.
    #'
    #' @param plot_object The plot object to check
    #' @return TRUE for a trellis object, FALSE otherwise
    can_handle = function(plot_object) {
      inherits(plot_object, "trellis") && !inherits(plot_object, "layer")
    },

    #' @description Classify one grob a panel function drew
    #' @param layer A grob entry: a list with the grob's `what` part
    #' @param plot_object The trellis object
    #' @return The grob's role (see `LATTICE_PANEL_ROLES`), `"decoration"`,
    #'   `"observations"`, or `"unknown"`
    detect_layer_type = function(layer, plot_object) {
      panel_name <- lattice_panel_name(plot_object[["panel"]])
      roles <- LATTICE_PANEL_ROLES[[panel_name]]
      if (is.null(roles) || is.null(layer$what)) {
        return("unknown")
      }
      for (role in names(roles)) {
        if (grepl(roles[[role]], layer$what, perl = TRUE)) {
          return(role)
        }
      }
      "unknown"
    },

    #' @description Group one panel's grobs into the layers it is read as
    #'
    #' Each layer is a list with the maidr `type` it is emitted as, the
    #' `role` of its grobs and the `grobs` themselves. A mark-per-observation
    #' type -- points, dots, spikes -- is one layer per group, named after it;
    #' a curve type is one layer per kind of curve, holding a series per
    #' group; bars, bins, boxes and cells are one layer for the panel.
    #'
    #' @param entries Grob entries drawn in the panel, in drawing order: lists
    #'   with `name`, `what`, `group` and `role`
    #' @param plot_object The trellis object
    #' @param args The panel's arguments, as its panel function received them
    #' @return A list of layer descriptions, in drawing order
    detect_panel_layers = function(entries, plot_object, args) {
      layers <- list()
      keys <- character(0)

      add <- function(key, type, role, entry) {
        at <- match(key, keys)
        if (is.na(at)) {
          keys[length(keys) + 1L] <<- key
          layers[[length(layers) + 1L]] <<- list(
            type = type, role = role, grobs = list(entry)
          )
        } else {
          layers[[at]]$grobs[[length(layers[[at]]$grobs) + 1L]] <<- entry
        }
      }

      for (entry in entries) {
        role <- entry$role
        group_key <- if (is.na(entry$group)) "" else entry$group
        switch(role,
          points = add(paste("points", entry$what, group_key), "point", role, entry),
          dots = add(
            paste("dots", entry$what, group_key),
            if (self$is_one_dot_per_level(args, entry$group)) "dot" else "point",
            role,
            entry
          ),
          segments = add(paste("segments", group_key), "lollipop", role, entry),
          # One layer per kind of line, not one for every `xyplot.lines`:
          # with `distribute.type = TRUE` one group can be a line and the
          # next a staircase, and read as the other kind a staircase gains a
          # sample at every riser while a line loses every other one. The
          # two directions of staircase are kept apart for the same reason.
          lines = {
            steps <- self$draws_steps(args, entry$group)
            direction <- if (!steps) {
              ""
            } else if ("S" %in% lattice_group_type(args, entry$group)) {
              "vh"
            } else {
              "hv"
            }
            add(
              paste("lines", entry$what, direction),
              if (steps) "step" else "line",
              role,
              entry
            )
          },
          average = add(paste("average", entry$what), "line", role, entry),
          fit = add(paste("fit", entry$what), "smooth", role, entry),
          curve = add("curve", "smooth", role, entry),
          bars = add("bars", self$bar_type(args), role, entry),
          bins = add("bins", "hist", role, entry),
          boxes = add("boxes", "box", role, entry),
          cells = add("cells", "heat", role, entry),
          contours = add("contours", "contour", role, entry),
          NULL
        )
      }

      # A kind of mark before the next, and within a kind by group: a
      # grouped `type = "b"` draws each group's points and then its line, and
      # a reader should meet every group's points before the lines.
      role_rank <- match(
        vapply(layers, function(layer) layer$role, character(1)),
        unique(vapply(entries, function(entry) entry$role, character(1)))
      )
      group_rank <- vapply(layers, function(layer) {
        group <- layer$grobs[[1]]$group
        if (is.null(group) || is.na(group)) 0L else as.integer(group)
      }, integer(1))
      layers[order(role_rank, group_rank)]
    },

    #' @description The bar layer type a barchart panel is read as
    #' @param args The panel's arguments
    #' @return `"bar"`, `"dodged_bar"` or `"stacked_bar"`
    bar_type = function(args) {
      if (is.null(args[["groups"]])) {
        "bar"
      } else if (isTRUE(args[["stack"]])) {
        "stacked_bar"
      } else {
        "dodged_bar"
      }
    },

    #' @description Whether an xyplot draws its lines as steps
    #'
    #' `type = "s"` and `"S"` draw the one `xyplot.lines` grob `"l"` does,
    #' as a staircase. With `distribute.type = TRUE` each group has a type of
    #' its own, the types recycled over the groups
    #' ([lattice_group_type()]).
    #'
    #' @param args The panel's arguments
    #' @param group The group the lines belong to, or NA
    #' @return TRUE for steps
    draws_steps = function(args, group) {
      type <- lattice_group_type(args, group)
      any(c("s", "S") %in% type) && !any(c("l", "b", "o") %in% type)
    },

    #' @description Whether a dotplot draws at most one dot per level
    #'
    #' A Cleveland dot plot -- one value per category, marked with a dot on
    #' a guide line -- is read as a `dot` layer, a bar chart's reading with a
    #' different mark, as Base R's `dotchart()` is. A dotplot with several
    #' values on a level is a strip of points instead, and read as points
    #' named by their level.
    #'
    #' @param args The panel's arguments
    #' @param group The group the dots belong to, or NA
    #' @return TRUE when no level holds two dots
    is_one_dot_per_level = function(args, group) {
      horizontal <- !isFALSE(args[["horizontal"]])
      category <- if (horizontal) args[["y"]] else args[["x"]]
      value <- if (horizontal) args[["x"]] else args[["y"]]
      if (!is.factor(category)) {
        return(FALSE)
      }
      keep <- lattice_group_rows(args, group) & !is.na(category) & !is.na(value)
      !anyDuplicated(as.integer(category)[keep])
    },

    #' @description Create an orchestrator for a trellis object
    #' @param plot_object The trellis object
    #' @param width,height The size to draw the chart at, in inches, or `NULL`
    #'   for maidr's own; see [chart_canvas_size()]
    #' @return LatticePlotOrchestrator instance
    create_orchestrator = function(plot_object, width = NULL, height = NULL) {
      if (!self$can_handle(plot_object)) {
        stop("Plot object is not a lattice (trellis) object")
      }
      LatticePlotOrchestrator$new(plot_object, width = width, height = height)
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      "lattice"
    }
  )
)
