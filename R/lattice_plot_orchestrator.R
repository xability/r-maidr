#' Draw a trellis object off-screen and keep what the reading needs
#'
#' The chart is drawn once, into a grob that is later drawn again onto the
#' svglite page the SVG is exported from; every selector is written against
#' the names this drawing gives. While the off-screen device is still open,
#' two things only lattice and grid can say are kept with it: which packet
#' each layout cell holds (`trellis.currentLayout()`, valid only right after
#' drawing) and every grob drawn, with the viewport it was drawn in
#' (`grid.ls()`), which is how grobs inside a panel are told from its axes
#' and strips.
#'
#' The off-screen device would draw with its own lattice theme, so the theme
#' the reader set on the device they look at is carried over
#' ([lattice_carry_theme()]).
#'
#' No device is opened that a reader could see, or left open. With none
#' open, `grid.grabExpr()` would end by making "the device that was current
#' before" current again with `dev.set(1)`, which opens the default device:
#' a window at the console, an `Rplots.pdf` in a script, for every chart
#' read in a session that had drawn nothing yet. An off-screen device that
#' writes no file stands in as that device, and is closed afterwards.
#'
#' Nor is lattice's record of the chart it drew last left describing this
#' drawing, which no device shows: it is put back afterwards, so
#' `trellis.focus()` and `print(more = TRUE)` carry on with the reader's own
#' chart. A print the console hook opens the viewer for is the exception: it
#' is the reader's own chart.
#'
#' The off-screen page is the size of the chart's canvas. lattice reads the
#' page it draws on to lay a conditioned chart's panels out -- with no
#' `layout =`, a chart of one conditioning variable gets as many columns as
#' the page's shape suits -- so drawn on a page of another shape, the grob
#' would keep that page's columns, squeezed or stretched onto the canvas.
#'
#' @param plot A trellis object, as [lattice_prepare()] returns it
#' @param prefix The grob-name prefix
#' @param size The chart's canvas, from [chart_canvas_size()]
#' @return A list: `grob`, the drawn chart; `packets`, the packet matrix
#'   indexed `[row, column]` as the grob names are; `listing`, a data frame
#'   of every grob and viewport drawn, with its `name`, `vpPath` and `type`.
#' @keywords internal
lattice_draw_scene <- function(plot, prefix = LATTICE_PREFIX, size = MAIDR_CHART_SIZE) {
  restore_status <- lattice_keep_status()
  on.exit(restore_status(), add = TRUE)

  plot <- lattice_carry_theme(plot)
  if (grDevices::dev.cur() == 1L) {
    grDevices::pdf(NULL)
    stand_in <- grDevices::dev.cur()
    on.exit(
      if (stand_in %in% grDevices::dev.list()) grDevices::dev.off(stand_in),
      add = TRUE
    )
  }

  captured <- new.env(parent = emptyenv())
  grob <- grid::grid.grabExpr(
    {
      lattice_draw(plot, prefix)
      captured$packets <- lattice::trellis.currentLayout("packet", prefix = prefix)
      listing <- grid::grid.ls(grobs = TRUE, viewports = TRUE, print = FALSE)
      captured$listing <- data.frame(
        name = as.character(listing$name),
        vpPath = as.character(listing$vpPath),
        type = as.character(listing$type),
        stringsAsFactors = FALSE
      )
      lattice_draw_gaps(captured$packets, prefix)
    },
    width = size[["width"]],
    height = size[["height"]],
    warn = 0,
    name = "maidr.trellis"
  )
  list(grob = grob, packets = captured$packets, listing = captured$listing)
}

#' The empty layout cells that are kept as empty subplots
#'
#' The frontend's subplot rows are left-packed: the k-th subplot of a row
#' is the k-th cell from the left, and Up and Down keep that k. A cell
#' lattice left empty at the end of its row can be left out; one with a
#' panel to its right in its row cannot, or that panel would be counted a
#' column to the left, and Up and Down would land on the panel beside the
#' one lattice drew above or below. Such a cell is kept, as a subplot with
#' no layers. A column no panel is drawn in is left out of every row, as a
#' row no panel is drawn in is.
#'
#' @param packets The packet matrix, `[row, column]`, 0 for an empty cell
#' @return A logical matrix the shape of `packets`, `TRUE` for an empty
#'   cell kept as an empty subplot.
#' @keywords internal
lattice_gap_cells <- function(packets) {
  drawn <- packets > 0
  gaps <- matrix(FALSE, nrow(drawn), ncol(drawn))
  used <- colSums(drawn) > 0
  for (row in seq_len(nrow(drawn))) {
    last <- max(c(0L, which(drawn[row, ])))
    gaps[row, ] <- !drawn[row, ] & used & seq_len(ncol(drawn)) < last
  }
  gaps
}

#' Draw an unseen rectangle in each empty cell kept as a subplot
#'
#' The frontend lays a figure out by measuring every subplot's panel on the
#' page, and one subplot it cannot measure sends the whole layout back to
#' array order, where Up moves down a grid whose rows run top first. An
#' empty cell has no panel, so it is given a rectangle of its own, with
#' neither fill nor border, over the cell a panel would have filled.
#' lattice places a panel in its page layout by its row and by its column
#' alone, so that cell is where a panel of its row meets a panel of its
#' column.
#'
#' @param packets The packet matrix, `[row, column]`, 0 for an empty cell
#' @param prefix The grob-name prefix
#' @return NULL, invisibly. Draws on the current page.
#' @keywords internal
lattice_draw_gaps <- function(packets, prefix = LATTICE_PREFIX) {
  gaps <- which(lattice_gap_cells(packets), arr.ind = TRUE)
  for (k in seq_len(nrow(gaps))) {
    row <- gaps[k, 1L]
    column <- gaps[k, 2L]
    grid::seekViewport(
      lattice::trellis.vpname("panel", which(packets[row, ] > 0)[1L], row, prefix = prefix)
    )
    layout_row <- grid::current.viewport()$layout.pos.row
    grid::seekViewport(
      lattice::trellis.vpname("panel", column, which(packets[, column] > 0)[1L], prefix = prefix)
    )
    layout_column <- grid::current.viewport()$layout.pos.col
    grid::seekViewport(lattice::trellis.vpname("toplevel", prefix = prefix))
    grid::pushViewport(grid::viewport(
      layout.pos.row = layout_row,
      layout.pos.col = layout_column,
      name = sprintf("%s.gap.%d.%d.vp", prefix, column, row)
    ))
    grid::grid.rect(
      name = sprintf("%s.gap.%d.%d", prefix, column, row),
      gp = grid::gpar(col = NA, fill = NA)
    )
    grid::upViewport(0L)
  }
  invisible(NULL)
}

#' Rearrange a trellis object's rows so its marks are drawn in reading order
#'
#' The drawing is unchanged; only the order the marks are drawn in is.
#'
#' * `panel.barchart()` and `panel.dotplot()` draw a mark per row, in the
#'   order of the rows, and the frontend pairs a bar-shaped layer's marks
#'   with its values in document order. Sorting each packet's rows by
#'   category -- then by group -- makes that the order the categories run
#'   along the axis, which is the order a reader walks them in.
#' * Whatever else those panels hand out by row keeps the row it went to.
#'   Without groups, a style given as a vector -- `col = c("red", "blue")`
#'   -- colours the marks in the order they are drawn, first mark first, so
#'   sorting the rows alone would repaint the bars; the style is sorted with
#'   them, into a copy for each packet, since each packet sorts its own rows
#'   and starts again from the style's first value. With groups a style goes
#'   by group rather than by row. A dot plot draws a guide line per level in
#'   the order the rows first name the levels, and is given that order.
#' * A dot plot joined by lines (`type` holding `"l"`, `"b"` or `"o"`) keeps
#'   its rows: the lines run through them in their order, which is the shape
#'   of the line. Its dots are then in level order only where the rows
#'   already were; where they are not, [LatticeDotLayerProcessor] cannot
#'   pair them with their levels, and the chart falls back to an image.
#' * `panel.bwplot()` gives a level whose values are all missing a box of
#'   missing statistics, which the exporter draws as no polygon; the boxes
#'   after it are then numbered one short. Naming the levels that hold a
#'   value as the ones to draw (`levels.fos`) leaves the same boxes drawn,
#'   numbered as they are counted. The rows themselves are kept:
#'   `varwidth = TRUE` sizes each box by the rows of the level holding the
#'   most, missing values included.
#'
#' @param plot A trellis object
#' @return The object, with each packet's rows reordered and what they were
#'   drawn with kept with them.
#' @keywords internal
lattice_prepare <- function(plot) {
  panel_name <- lattice_panel_name(plot[["panel"]])
  if (panel_name == "panel.xyplot") {
    return(lattice_prepare_spikes(plot))
  }
  if (!panel_name %in% c("panel.barchart", "panel.dotplot", "panel.bwplot")) {
    return(plot)
  }

  common <- plot$panel.args.common
  horizontal <- !isFALSE(common[["horizontal"]])
  groups <- common[["groups"]]
  group_codes <- if (is.null(groups)) NULL else as.integer(factor(groups))
  # A `levels.fos` the chart was given is drawn as given.
  name_levels <- panel_name != "panel.barchart" && is.null(common[["levels.fos"]])
  # Lines are drawn through the rows in their order.
  joined <- panel_name == "panel.dotplot" &&
    any(c("l", "b", "o") %in% as.character(common[["type"]]))

  # The styles an ungrouped panel hands its marks one value per mark, as
  # its panel function passes them to the marks.
  styles <- if (!is.null(groups)) {
    character(0)
  } else if (panel_name == "panel.barchart") {
    c("col", "border", "lty", "lwd")
  } else if (panel_name == "panel.dotplot") {
    c("col", "col.symbol", "pch", "cex", "fill", "alpha", "font", "fontface", "fontfamily")
  } else {
    character(0)
  }
  styles <- styles[lengths(common[styles]) > 1L]

  for (packet in seq_along(plot$panel.args)) {
    args <- plot$panel.args[[packet]]
    n <- length(args[["x"]])
    category <- if (horizontal) args[["y"]] else args[["x"]]
    value <- if (horizontal) args[["x"]] else args[["y"]]
    rows <- seq_len(n)
    levels_drawn <- NULL

    if (n > 0L && length(args[["y"]]) == n) {
      if (panel_name == "panel.bwplot") {
        levels_drawn <- sort(unique(as.numeric(category)[!is.na(value)]))
      } else {
        # `panel.dotplot()`'s own default, taken before the rows move.
        levels_drawn <- unique(as.numeric(category))
        group <- if (is.null(group_codes) || is.null(args[["subscripts"]])) {
          rep(0L, n)
        } else {
          group_codes[args[["subscripts"]]]
        }
        if (!joined) {
          rows <- order(as.numeric(category), group, na.last = TRUE)
        }
      }
    }

    # Which of each style's values every row was drawn with: the bars skip a
    # row with a missing value, the dots draw every row, a missing one as
    # nothing.
    marked <- if (panel_name == "panel.barchart") {
      !is.na(args[["x"]]) & !is.na(args[["y"]])
    } else {
      rep(TRUE, n)
    }
    restyled <- lapply(styles, function(style) {
      if (n == 0L) {
        return(common[[style]])
      }
      slot <- rep(NA_integer_, n)
      slot[marked] <- (seq_len(sum(marked)) - 1L) %% length(common[[style]]) + 1L
      common[[style]][slot[rows][marked[rows]]]
    })

    if (!identical(rows, seq_len(n))) {
      args <- lapply(args, function(values) {
        if (length(values) == n) values[rows] else values
      })
    }
    args[styles] <- restyled
    if (name_levels && !is.null(levels_drawn)) {
      args[["levels.fos"]] <- levels_drawn
    }
    plot$panel.args[[packet]] <- args
  }
  plot$panel.args.common[styles] <- NULL

  plot
}

#' Rearrange an xyplot's rows so its spikes are drawn along the axis
#'
#' `type = "h"` draws a spike per row, in the order of the rows, and joins
#' none of them, so that order is not one a reader can see -- but the
#' frontend walks, pans and pairs a lollipop's marks in document order.
#' When nothing else the panel draws is joined in row order (`"l"`, `"b"`,
#' `"o"`), each packet's rows are sorted by position, x or `horizontal =
#' TRUE`'s y, which draws the same chart. Without groups a style given as a
#' vector is drawn one value per row, a missing row included, and is sorted
#' with the rows, as [lattice_prepare()] does for a bar.
#'
#' @param plot A trellis object drawn with `panel.xyplot()`
#' @return The object, with each packet's rows in position order when it
#'   draws spikes and nothing joined.
#' @keywords internal
lattice_prepare_spikes <- function(plot) {
  common <- plot$panel.args.common
  type <- as.character(common[["type"]])
  if (!"h" %in% type || any(c("l", "b", "o") %in% type)) {
    return(plot)
  }
  horizontal <- isTRUE(common[["horizontal"]])
  styles <- if (is.null(common[["groups"]])) {
    c(
      "col", "col.line", "col.symbol", "lty", "lwd", "alpha", "pch", "cex",
      "fill", "font", "fontface", "fontfamily"
    )
  } else {
    character(0)
  }
  styles <- styles[lengths(common[styles]) > 1L]

  for (packet in seq_along(plot$panel.args)) {
    args <- plot$panel.args[[packet]]
    n <- length(args[["x"]])
    position <- if (horizontal) args[["y"]] else args[["x"]]
    rows <- if (length(position) == n) {
      order(as.numeric(position), na.last = TRUE)
    } else {
      seq_len(n)
    }
    args <- lapply(args, function(values) {
      if (length(values) == n) values[rows] else values
    })
    args[styles] <- lapply(styles, function(style) {
      if (n == 0L) common[[style]] else rep_len(common[[style]], n)[rows]
    })
    plot$panel.args[[packet]] <- args
  }
  plot$panel.args.common[styles] <- NULL

  plot
}

#' Split a lattice grob name into what it is and where it was drawn
#'
#' @param name Grob names
#' @param prefix The grob-name prefix
#' @return A data frame with `what`, `group`, `column` and `row`; `what` is
#'   `NA` for a name that is not a lattice panel grob.
#' @keywords internal
lattice_parse_grob_name <- function(name, prefix = LATTICE_PREFIX) {
  pattern <- paste0(
    "^", gsub(".", "\\.", prefix, fixed = TRUE),
    "\\.(.+?)(?:\\.group\\.([0-9]+))?\\.panel\\.([0-9]+)\\.([0-9]+)$"
  )
  parts <- regmatches(name, regexec(pattern, name, perl = TRUE))
  field <- function(i, convert) {
    vapply(parts, function(p) if (length(p)) convert(p[i]) else convert(NA), convert(NA))
  }
  data.frame(
    name = name,
    what = field(2L, as.character),
    group = field(3L, function(v) suppressWarnings(as.integer(v))),
    column = field(4L, function(v) suppressWarnings(as.integer(v))),
    row = field(5L, function(v) suppressWarnings(as.integer(v))),
    stringsAsFactors = FALSE
  )
}

#' The grobs drawn inside a chart's panels, classified
#'
#' A grob counts as inside a panel when it was drawn in the panel's data
#' viewport, `<prefix>.panel.<column>.<row>.vp`, which is where lattice runs
#' the panel function -- and any viewport the panel function pushes there.
#' Axes, ticks, the border and the strips are drawn in other viewports.
#'
#' @param listing The grob listing of the drawn chart
#' @param plot The trellis object that was drawn
#' @param adapter The lattice adapter
#' @param prefix The grob-name prefix
#' @return A data frame with one row per grob drawn in a panel, in drawing
#'   order: `name`, `what`, `group`, `column`, `row` and `role`.
#' @keywords internal
lattice_panel_grobs <- function(listing, plot, adapter, prefix = LATTICE_PREFIX) {
  rx <- gsub(".", "\\.", prefix, fixed = TRUE)
  grobs <- listing[listing$type == "grobListing", , drop = FALSE]
  in_panel <- grepl(
    paste0("::", rx, "\\.panel\\.[0-9]+\\.[0-9]+\\.vp(::|$)"),
    grobs$vpPath
  )
  entries <- lattice_parse_grob_name(grobs$name[in_panel], prefix)
  entries$role <- vapply(seq_len(nrow(entries)), function(i) {
    what <- entries$what[i]
    if (is.na(what)) {
      "unknown"
    } else if (identical(what, "fill")) {
      "decoration"
    } else {
      adapter$detect_layer_type(list(what = what), plot)
    }
  }, character(1))
  entries
}

#' Why the grobs drawn in a chart's panels cannot be read
#'
#' The reading of each panel function is written against what it draws.
#' A grob a panel draws that is not in `LATTICE_PANEL_ROLES` -- an error
#' message a panel function printed instead of its marks, a primitive a
#' custom `identifier =` renamed, a region lattice fills with polygons rather
#' than cells -- is something the reading would silently leave out, and a
#' name drawn twice in one panel is two overlays the selectors cannot tell
#' apart -- unless it is decoration, which no selector addresses.
#'
#' @param entries The panel grobs, from [lattice_panel_grobs()]
#' @return Character vector of reasons, empty when every panel can be read.
#' @keywords internal
lattice_panel_audit <- function(entries) {
  why <- character(0)
  unknown <- entries$name[entries$role == "unknown"]
  if (length(unknown)) {
    why <- c(why, sprintf("a panel draws %s, which is not read", unknown[1]))
  }
  # A grouped panel can draw a reference line once per group: it is never
  # read, so drawing it twice addresses nothing twice.
  twice <- entries$name[duplicated(entries$name) & entries$role != "decoration"]
  if (length(twice)) {
    why <- c(why, sprintf("a panel draws %s more than once", twice[1]))
  }
  why
}

#' The limits of one packet's axis
#'
#' `x.limits` and `y.limits` hold one range for the whole chart, or, when an
#' axis' `relation` is `"free"` or `"sliced"`, one per packet.
#'
#' @param limits The `x.limits` or `y.limits` field
#' @param packet The packet
#' @return The packet's limits: a numeric range, or character levels.
#' @keywords internal
lattice_packet_limits <- function(limits, packet) {
  if (is.list(limits)) limits[[packet]] else limits
}

#' Split a layer of curves no one x value joins into a layer per curve
#'
#' The frontend moves Up and Down between the series of a line, step or
#' smooth layer only onto a series with a point at the very x the reader
#' is on. Grouped curves drawn over each group's own x values -- the
#' densities of a grouped `densityplot()`, lines through each group's own
#' observations -- may share none, and the reader could then reach no
#' series but the first. So a layer whose series have no x value in common
#' is split into one layer per series, named by its group, which PageUp and
#' PageDown reach whatever x the reader is on. A layer whose series all
#' pass through one x value is kept whole: from there Up and Down reach
#' each series, and compare them at every x they share.
#'
#' @param layer A layer, as `process_layer()` returns it
#' @return A list of layers: `layer` alone, or one per series. A split
#'   layer keeps `layer`'s id; the others have none yet.
#' @keywords internal
lattice_split_series <- function(layer) {
  curves <- c("line", "step", "smooth")
  if (!layer$type %in% curves || length(layer$data) < 2L) {
    return(list(layer))
  }
  # A point with no x -- a level the axis does not hold -- meets nothing.
  xs <- lapply(layer$data, function(series) {
    x <- unlist(lapply(series, `[[`, "x"))
    x[!is.na(x)]
  })
  if (length(Reduce(intersect, xs)) > 0L) {
    return(list(layer))
  }
  lapply(seq_along(layer$data), function(k) {
    one <- layer
    if (k > 1L) {
      one["id"] <- list(NULL)
    }
    one$data <- layer$data[k]
    one$selectors <- layer$selectors[k]
    name <- layer$data[[k]][[1]]$z
    if (!is.null(name)) {
      one$name <- name
    }
    one
  })
}

#' What kind of curve a layer is, in lattice's own words
#'
#' `panel.xyplot()` draws two curves read as a type another of its curves
#' is also read as: the line through each x value's average (`type = "a"`)
#' is a `line`, as the line through the data is, and a loess, a spline and
#' a regression line are each a `smooth`. These are named as lattice's
#' `smooth` argument and `?panel.xyplot` name them, so that two of them
#' drawn for one group can be told apart ([lattice_qualify_layer_names()]).
#'
#' @param layer A layer description from the adapter
#' @param type The type the layer was read as
#' @return `"average"`, `"loess"`, `"spline"` or `"regression"` for those
#'   curves; `type` for anything else.
#' @keywords internal
lattice_layer_kind <- function(layer, type) {
  if (identical(layer$role, "average")) {
    return("average")
  }
  if (identical(layer$role, "fit")) {
    fits <- c(loess = "loess", spline = "spline", lmline = "regression")
    kind <- fits[sub("\\..*$", "", layer$grobs[[1]]$what)]
    if (!is.na(kind)) {
      return(unname(kind))
    }
  }
  type
}

#' Say what kind each named layer is, in a panel of more than one kind
#'
#' A layer's `name` is announced on a layer switch in place of its type, which
#' is what a group's name is for when a panel's layers are all the same kind
#' of thing. Where they are not -- a group's points and the line through
#' them, `type = "b"`; points under a fitted curve -- the bare group names
#' would say "4", "6", "8", "4", "6", "8" with nothing to tell the points
#' from the lines, so each named layer says its type too: "4 (line)".
#'
#' Two curves of one type -- the line through the data and the line through
#' its averages, `type = c("l", "a")`; a loess and a spline -- would still be
#' announced alike: by group alone or by group and type when they are named,
#' and by their type when they are not, as a curve whose groups share an x is
#' kept whole and unnamed ([lattice_split_series()]). So those say which
#' curve they are instead: "4 (line)" and "4 (average)", "4 (loess)" and
#' "4 (spline)", or, unnamed, "line" and "average" ([lattice_layer_kind()]).
#'
#' @param layers A subplot's layers
#' @param kinds What kind of curve or mark each layer is, from
#'   [lattice_layer_kind()]
#' @return The layers, their names qualified by type when the subplot's
#'   layers are not all one type, and by kind where two would otherwise be
#'   announced alike.
#' @keywords internal
lattice_qualify_layer_names <- function(layers, kinds) {
  if (length(layers) == 0L) {
    return(layers)
  }
  types <- vapply(layers, function(layer) layer$type, character(1))
  bare <- vapply(layers, function(layer) layer$name %||% NA_character_, character(1))
  named <- !is.na(bare)
  qualifier <- if (length(unique(types)) > 1L) types else rep(NA_character_, length(types))
  # What each layer is announced as: its name, or its type when it has none.
  announced <- function(qualifier) {
    ifelse(!named, types, ifelse(is.na(qualifier), bare, sprintf("%s (%s)", bare, qualifier)))
  }
  said <- announced(qualifier)
  alike <- duplicated(said) | duplicated(said, fromLast = TRUE)
  qualifier[alike] <- kinds[alike]
  said <- announced(qualifier)
  for (i in which(named)) {
    layers[[i]]$name <- said[[i]]
  }
  for (i in which(alike & !named)) {
    layers[[i]]$name <- kinds[[i]]
  }
  layers
}

#' Plot Orchestrator for lattice
#'
#' @description
#' Reads a trellis object as a MAIDR figure: one subplot per panel, laid out
#' as lattice lays the panels out, each holding the layers its panel
#' function drew.
#'
#' The chart is checked before it is drawn ([lattice_static_check()]) and
#' audited after ([lattice_panel_audit()]); a chart that fails either is
#' shown as an image rather than read, as an unsupported ggplot2 or Base R
#' chart is. A chart laid out over several pages is read from its first.
#'
#' @keywords internal
LatticePlotOrchestrator <- R6::R6Class(
  "LatticePlotOrchestrator",
  private = list(
    .plot = NULL,
    .drawn_plot = NULL,
    .adapter = NULL,
    .gtable = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .layout = NULL,
    .unsupported = character(0),
    .pages = 1,
    .canvas = NULL
  ),
  public = list(
    #' @description Create an orchestrator for a trellis object
    #' @param plot The trellis object
    #' @param width,height The size to draw the chart at, in inches, or `NULL`
    #'   for maidr's own; see [chart_canvas_size()]
    initialize = function(plot, width = NULL, height = NULL) {
      private$.plot <- plot
      private$.canvas <- chart_canvas_size(width, height)
      private$.adapter <- get_global_registry()$get_adapter("lattice")

      private$.unsupported <- lattice_static_check(plot)
      if (length(private$.unsupported)) {
        return(invisible(self))
      }

      drawn <- lattice_prepare(lattice_first_page(plot))
      private$.drawn_plot <- drawn
      private$.pages <- attr(drawn, "maidr_pages")

      scene <- tryCatch(
        lattice_draw_scene(drawn, size = private$.canvas),
        error = function(e) e
      )
      if (inherits(scene, "error")) {
        private$.unsupported <- paste("drawing it failed:", conditionMessage(scene))
        return(invisible(self))
      }
      private$.gtable <- scene$grob

      entries <- lattice_panel_grobs(scene$listing, drawn, private$.adapter)
      private$.unsupported <- lattice_panel_audit(entries)
      if (length(private$.unsupported)) {
        return(invisible(self))
      }

      private$.layout <- self$extract_layout()
      self$process_panels(scene$packets, entries)

      if (isTRUE(private$.pages > 1) && !self$should_fallback() &&
        is_fallback_warning_enabled()) {
        warning(
          "This lattice chart is laid out on ", private$.pages, " pages. ",
          "Only the first page is rendered interactively; set `layout =` ",
          "to fit every panel on one page.",
          call. = FALSE
        )
      }

      invisible(self)
    },

    #' @description Read the figure's title, subtitle and axis labels
    #' @return List with `title`, `subtitle` and `axes`
    extract_layout = function() {
      plot <- private$.drawn_plot
      x_label <- lattice_axis_label(plot$xlab, plot$xlab.default)
      series <- lattice_series_name(plot)
      y_label <- if (is.null(plot$ylab) && !is.null(series)) {
        series
      } else {
        lattice_axis_label(plot$ylab, plot$ylab.default)
      }
      list(
        title = lattice_label_text(plot$main) %||% "",
        subtitle = lattice_label_text(plot$sub),
        axes = build_axes(x = x_label, y = y_label),
        x_label = x_label,
        y_label = y_label
      )
    },

    #' @description Read every panel and lay the subplots out as lattice did
    #'
    #' lattice numbers its layout rows from the bottom unless `as.table` is
    #' set; MAIDR's grid runs top to bottom. The frontend's rows are
    #' left-packed, so a row may end early but not start late: a cell
    #' lattice left empty at the end of its row -- a `layout` larger than
    #' the packets -- is not emitted, but one with a panel to its right --
    #' left by `skip` -- is kept as a subplot with no layers, selecting the
    #' unseen rectangle [lattice_draw_gaps()] drew there, since the frontend
    #' measures every subplot to lay the figure out
    #' ([lattice_gap_cells()]). A row or column with no panel at all is not
    #' emitted.
    #'
    #' Each layer is titled with its packet's strip label whenever the chart
    #' is conditioned, even when only one panel is drawn -- a conditioning
    #' variable with one level, or the first page of a chart laid out one
    #' panel to a page -- since the strip is what says which slice of the
    #' data the panel is. An unconditioned chart's one panel is titled with
    #' the chart's `main`.
    #'
    #' @param packets The packet matrix, `[row, column]`, 0 for an empty cell
    #' @param entries The panel grobs, from [lattice_panel_grobs()]
    #' @return NULL, invisibly. Sets the combined data.
    process_panels = function(packets, entries) {
      plot <- private$.drawn_plot
      n_rows <- nrow(packets)
      n_cols <- ncol(packets)
      multi_panel <- sum(packets > 0) > 1L
      gaps <- lattice_gap_cells(packets)
      cond_dim <- lengths(plot$condlevels)
      counter <- 0L

      # The lattice rows that hold a panel, top row first.
      top_first <- if (isTRUE(plot$as.table)) seq_len(n_rows) else rev(seq_len(n_rows))
      top_first <- top_first[rowSums(packets[top_first, , drop = FALSE] > 0) > 0]

      rows <- vector("list", length(top_first))
      for (grid_row in seq_along(top_first)) {
        row <- top_first[grid_row]
        cells <- vector("list", n_cols)
        for (column in seq_len(n_cols)) {
          packet <- packets[row, column]
          subplot <- list(
            id = paste0("maidr-subplot-", grid_row, "-", column),
            layers = list()
          )
          if (packet > 0) {
            level_index <- as.vector(arrayInd(packet, cond_dim))
            strip <- lattice_packet_label(plot, level_index)
            args <- lattice::trellis.panelArgs(plot, packet)
            panel_ctx <- list(
              packet = packet,
              column = column,
              row = row,
              args = args,
              x_format = lattice_series_time_format(plot, args$x),
              title = if (nzchar(strip)) strip else private$.layout$title,
              x_limits = lattice_packet_limits(plot$x.limits, packet),
              y_limits = lattice_packet_limits(plot$y.limits, packet),
              group_levels = lattice_group_names(plot),
              group_title = lattice_group_title(plot)
            )
            here <- entries[
              entries$column == column & entries$row == row &
                !entries$role %in% c("decoration", "observations"), ,
              drop = FALSE
            ]
            here <- lapply(seq_len(nrow(here)), function(i) as.list(here[i, ]))
            layers <- private$.adapter$detect_panel_layers(here, plot, panel_ctx$args)
            kinds <- character(0)
            for (layer in layers) {
              counter <- counter + 1L
              result <- self$process_layer(layer, counter, panel_ctx)
              if (is.null(result)) {
                private$.unsupported <- c(
                  private$.unsupported,
                  sprintf("its %s marks could not be read", layer$type)
                )
                next
              }
              if (length(result$data) == 0L) {
                next
              }
              for (part in lattice_split_series(result)) {
                if (is.null(part$id)) {
                  counter <- counter + 1L
                  part$id <- paste0("maidr-layer-", counter)
                }
                subplot$layers[[length(subplot$layers) + 1L]] <- part
                kinds[length(kinds) + 1L] <- lattice_layer_kind(layer, part$type)
              }
            }
            subplot$layers <- lattice_qualify_layer_names(subplot$layers, kinds)
            if (multi_panel) {
              subplot$selector <- lattice_grob_selector(
                sprintf("%s.border.panel.%d.%d", LATTICE_PREFIX, column, row),
                "rect"
              )
            }
          }
          if (gaps[row, column]) {
            subplot$selector <- lattice_grob_selector(
              sprintf("%s.gap.%d.%d", LATTICE_PREFIX, column, row),
              "rect"
            )
          }
          cells[[column]] <- subplot
        }
        # An empty cell with a panel to its right stays, as an empty
        # subplot; the others are left out.
        rows[[grid_row]] <- cells[packets[row, ] > 0 | gaps[row, ]]
      }

      private$.combined_data <- rows
      invisible(NULL)
    },

    #' @description Read one layer of one panel
    #' @param layer A layer description from the adapter
    #' @param index The layer's number across the figure
    #' @param panel_ctx The panel the layer was drawn in
    #' @return The layer, or NULL when its marks could not be read
    process_layer = function(layer, index, panel_ctx) {
      layer_info <- list(
        index = index,
        type = layer$type,
        role = layer$role,
        grobs = layer$grobs
      )
      private$.layers[[length(private$.layers) + 1L]] <- layer_info

      factory <- get_global_registry()$get_processor_factory("lattice")
      processor <- factory$create_processor(layer$type, layer_info)
      private$.layer_processors[[length(private$.layer_processors) + 1L]] <- processor

      result <- processor$process(
        private$.drawn_plot,
        private$.layout,
        gt = private$.gtable,
        panel_ctx = panel_ctx,
        layer_info = layer_info
      )
      processor$set_last_result(result)
      if (is.null(result)) {
        return(NULL)
      }

      axes <- if (!is.null(result$axes)) result$axes else build_axes()
      validate_axes(axes, context = "lattice orchestrator")
      layer_obj <- list(
        id = paste0("maidr-layer-", index),
        selectors = result$selectors,
        type = result$type,
        data = result$data,
        title = if (!is.null(result$title)) result$title else "",
        axes = axes
      )
      for (field in setdiff(names(result), names(layer_obj))) {
        layer_obj[[field]] <- result[[field]]
      }
      layer_obj
    },

    #' @description Assemble the MAIDR data object for the figure
    #' @return List with an id, the subplots and the figure's titles
    generate_maidr_data = function() {
      if (length(private$.unsupported)) {
        stop(
          "This lattice chart cannot be read interactively: ",
          paste(private$.unsupported, collapse = "; "), ".",
          call. = FALSE
        )
      }

      maidr_obj <- list(
        id = paste0("maidr-plot-", generate_unique_id()),
        subplots = private$.combined_data
      )
      title <- private$.layout$title
      if (!is.null(title) && nzchar(title)) {
        maidr_obj$title <- title
      }
      subtitle <- private$.layout$subtitle
      if (!is.null(subtitle) && nzchar(subtitle)) {
        maidr_obj$subtitle <- subtitle
      }
      maidr_obj
    },

    #' @description The drawn chart
    #' @return The grob the chart was drawn into, or NULL when it was not
    #'   drawn
    get_gtable = function() {
      private$.gtable
    },

    #' @description The size the chart is drawn at
    #' @return A named numeric vector, `width` and `height`, in inches
    canvas_size = function() {
      private$.canvas
    },

    #' @description The figure-level layout read by `extract_layout()`
    #' @return List
    get_layout = function() {
      private$.layout
    },

    #' @description The subplot grid
    #' @return List of rows of subplots
    get_combined_data = function() {
      private$.combined_data
    },

    #' @description The processors created for the layers
    #' @return List
    get_layer_processors = function() {
      private$.layer_processors
    },

    #' @description The layers detected across the panels
    #' @return List of layer descriptions
    get_layers = function() {
      private$.layers
    },

    #' @description Why the chart cannot be read, if it cannot
    #' @return Character vector, empty when it can be read
    unsupported_reasons = function() {
      private$.unsupported
    },

    #' @description Check if the chart holds anything that cannot be read
    #'
    #' That is a failed check before or after drawing, a layer whose marks
    #' could not be read, or no layer at all: a chart that announces itself
    #' as interactive with nothing in it is worse than an image, because an
    #' image at least says what it is.
    #'
    #' @return Logical
    has_unsupported_layers = function() {
      if (length(private$.unsupported)) {
        return(TRUE)
      }
      layers <- unlist(
        lapply(private$.combined_data, function(row) {
          lapply(row, function(cell) cell$layers)
        }),
        recursive = FALSE
      )
      !any(lengths(layers) > 0L)
    },

    #' @description Determine if the chart should fall back to an image
    #' @return Logical
    should_fallback = function() {
      if (!is_fallback_enabled()) {
        return(FALSE)
      }
      self$has_unsupported_layers()
    }
  )
)
