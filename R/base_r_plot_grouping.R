#' Base R Plot Grouping
#'
#' This module groups plot calls into logical units:
#' - Only the calls on the page R's device shows are grouped
#' - Each HIGH-level call starts a new plot group
#' - Subsequent LOW-level calls are associated with the current plot group
#' - LAYOUT calls affect multi-panel configuration
#'
#' @noRd
NULL

#' Group Device Calls into Plot Units
#'
#' Groups the calls a device shows into logical plot units: those drawn on
#' its last page, with every layout call (`last_page_calls()`). R's device
#' shows only the page drawn last, so a plot that started a page of its own
#' -- the second of `hist(a); hist(b)` -- leaves the plots before it out.
#' Each group contains one HIGH-level call, or a LOW-level one that started
#' a plot of its own (`starts_base_r_plot()`), and the LOW-level calls drawn
#' on its plot. A LOW-level call drawn on a plot no recorded call started -- a
#' panel `plot.new()` or `frame()` took, as for a legend of its own, or a
#' plot maidr does not record, such as `smoothScatter()` -- is not one of
#' them: it is kept, to be drawn where R drew it, with the group drawn after
#' it (`before_calls`), or, after the last, with the last (`after_calls`).
#' One drawn on a plot started over the group's own, in its panel, after
#' `par(new = TRUE)`, is one of them, marked `overlay`: it is drawn on that
#' plot, in the coordinates it was drawn in (`drawn_over_group_plot()`).
#' One drawn after `par(mfg = )` or `screen()` sent R back to the cell or
#' screen of an earlier group's plot, without starting a plot, is one of
#' that group's, marked `sent_back`: R draws it there, on that plot, in the
#' coordinates R had (`sent_back_to()`).
#'
#' @param device_id Graphics device ID
#' @return List of plot groups, each containing HIGH and LOW calls
#' @keywords internal
group_device_calls <- function(device_id = grDevices::dev.cur()) {
  all_calls <- shown_device_calls(device_id)

  if (length(all_calls) == 0) {
    return(list())
  }

  groups <- list()
  current_group <- NULL
  layout_calls <- list()
  # Drawn on plots no recorded call started, since the last group's.
  unrecorded <- list()

  for (i in seq_along(all_calls)) {
    call <- all_calls[[i]]
    class_level <- call$class_level

    if (class_level == "LAYOUT") {
      # Keep the position in the overall call sequence so panel mapping
      # can tell which plot groups were drawn after the layout change.
      call$storage_index <- i
      layout_calls <- append(layout_calls, list(call))
    } else if (starts_base_r_plot(call)) {
      if (!is.null(current_group)) {
        groups <- append(groups, list(current_group))
      }

      current_group <- list(
        high_call = call,
        high_call_index = i,
        low_calls = list(),
        low_call_indices = integer(0),
        before_calls = unrecorded,
        after_calls = list(),
        panel_info = NULL
      )
      unrecorded <- list()
    } else if (class_level == "LOW") {
      back <- sent_back_to(call, c(groups, list(current_group)))
      if (!is.na(back)) {
        call$sent_back <- TRUE
        if (back > length(groups)) {
          current_group$low_calls <- append(current_group$low_calls, list(call))
          current_group$low_call_indices <- c(current_group$low_call_indices, i)
        } else {
          groups[[back]]$low_calls <- append(groups[[back]]$low_calls, list(call))
          groups[[back]]$low_call_indices <- c(groups[[back]]$low_call_indices, i)
        }
        next
      }
      unrecorded_plot <- drawn_on_unrecorded_plot(call, current_group)
      if (unrecorded_plot && !drawn_over_group_plot(call, current_group)) {
        call$storage_index <- i
        unrecorded <- append(unrecorded, list(call))
      } else if (!is.null(current_group)) {
        if (unrecorded_plot) {
          call$overlay <- TRUE
          call$storage_index <- i
        }
        current_group$low_calls <- append(current_group$low_calls, list(call))
        current_group$low_call_indices <- c(current_group$low_call_indices, i)
      }
    }
  }

  if (!is.null(current_group)) {
    current_group$after_calls <- unrecorded
    groups <- append(groups, list(current_group))
  }

  result <- list(
    groups = groups,
    layout_calls = layout_calls,
    total_groups = length(groups),
    total_layout_calls = length(layout_calls)
  )

  result
}

#' Whether a recorded call starts a plot of its own
#'
#' A HIGH-level call does, and a LOW-level one that started a plot itself
#' (`own_plot`, see `end_base_r_call()`): `symbols()` without `add = TRUE`
#' draws a plot, on a page of its own after another plot, as `plot()`
#' does. Read as a call added to the plot before it, it was left out with
#' that plot's page, and its own page held no plot at all.
#'
#' @param call A recorded call entry
#' @return Logical
#' @keywords internal
#' @noRd
starts_base_r_plot <- function(call) {
  identical(call$class_level, "HIGH") ||
    (identical(call$class_level, "LOW") && isTRUE(call$own_plot))
}

#' Whether a low-level call was drawn on a plot no recorded call started
#'
#' R numbers the plots it starts on a page (`end_base_r_call()`). A
#' low-level call drawn on a plot after the last the group before it drew
#' -- or before the page's first group -- was drawn on a plot something else
#' started: `plot.new()`, `frame()`, or a plot maidr does not record. A
#' call recorded without its plot, by code that records calls itself, is
#' taken to be drawn on the group before it.
#'
#' @param call The recorded LOW-level call
#' @param group The plot group recorded before it, or NULL for none
#' @return Logical
#' @keywords internal
#' @noRd
drawn_on_unrecorded_plot <- function(call, group) {
  on <- call$end_plot
  if (!is.numeric(on) || length(on) != 1L) {
    return(FALSE)
  }
  if (is.null(group)) {
    return(TRUE)
  }
  last <- group$high_call$end_plot
  is.numeric(last) && length(last) == 1L && on > last
}

#' Whether a low-level call on a plot no recorded call started is drawn
#' over a group's plot
#'
#' A plot started after `par(new = TRUE)` with `plot.new()`, as a second
#' series with an axis of its own is drawn, is in the panel of the plot
#' before it: R's count of panels did not move on (`end_base_r_call()`).
#' What is drawn on it is drawn over that plot, which R shows it with, and
#' is read with it (`overlay`, see `group_device_calls()`), in the
#' coordinates it was drawn in. `par(mfg = )` does not move R's count on
#' either, but sends the plot to another cell of the grid, as for a legend
#' in a panel of its own: one started there is in another panel, and what
#' is drawn on it is not drawn over the group's plot.
#'
#' @param call The recorded LOW-level call
#' @param group The plot group recorded before it, or NULL for none
#' @return Logical
#' @keywords internal
#' @noRd
drawn_over_group_plot <- function(call, group) {
  panel <- call$end_figure
  group_panel <- group$high_call$end_figure
  same_panel <- length(panel) == 1L && length(group_panel) == 1L &&
    isTRUE(as.integer(panel) == as.integer(group_panel))
  same_panel && !in_another_cell(call$cell, group$high_call$end_cell)
}

#' The group whose plot R was sent back to before a low-level call drew
#'
#' `par(mfg = )` sends R to a cell of the grid, and `screen()` of
#' `split.screen()` to a screen -- with `new = FALSE`, as `?split.screen`'s
#' own example does to add to a screen -- without starting a plot. What is
#' drawn next is drawn in that cell or screen, over the plot drawn there,
#' and not on the plot R started last: `abline()` after `screen(1, new =
#' FALSE)` is drawn on screen 1's plot, in the coordinates `screen()` put
#' back. It was read as a layer of the last plot, and drawn on it.
#'
#' @param call The recorded LOW-level call
#' @param groups The page's plot groups recorded before it, in order
#' @return The index in `groups` of the last group whose plot is in the
#'   cell and region R drew `call` in (`drawn_cell`, `drawn_fig`), where
#'   that is not the region of the plot R started last; NA where it is, or
#'   where no group's plot is there
#' @keywords internal
#' @noRd
sent_back_to <- function(call, groups) {
  # Where R started its last plot, as against where it drew the call.
  last_plot_known <- same_region(call$cell, call$fig, call$cell, call$fig)
  if (!last_plot_known || same_region(call$drawn_cell, call$drawn_fig, call$cell, call$fig)) {
    return(NA_integer_)
  }
  there <- vapply(
    groups,
    function(group) {
      same_region(group$high_call$cell, group$high_call$fig, call$drawn_cell, call$drawn_fig)
    },
    logical(1)
  )
  if (any(there)) max(which(there)) else NA_integer_
}

#' Whether two plots are in the same cell and region of the page
#'
#' @param cell,fig The cell (`par("mfg")`) and region (`par("fig")`) of
#'   one
#' @param other_cell,other_fig Those of the other
#' @return Logical: `FALSE` where either is not known
#' @keywords internal
#' @noRd
same_region <- function(cell, fig, other_cell, other_fig) {
  known <- function(cell, fig) {
    length(cell) == 4L && !anyNA(cell) && length(fig) == 4L && !anyNA(fig)
  }
  known(cell, fig) && known(other_cell, other_fig) &&
    identical(as.integer(cell), as.integer(other_cell)) &&
    max(abs(fig - other_fig)) < 1e-6
}

#' Whether a plot is in another cell of the same grid as a plot before it
#'
#' @param cell,before The cells R put each in (`par("mfg")`): the row and
#'   column, and the grid's rows and columns; or `NULL`
#' @return Logical: `FALSE` where either is not known, or the two are cells
#'   of grids of different shapes, as a region `par(fig = )` gave a plot is
#'   a cell of a grid of one
#' @keywords internal
#' @noRd
in_another_cell <- function(cell, before) {
  length(cell) == 4L && length(before) == 4L && !anyNA(cell) && !anyNA(before) &&
    identical(as.integer(cell[3:4]), as.integer(before[3:4])) &&
    !identical(as.integer(cell[1:2]), as.integer(before[1:2]))
}

#' Get Plot Group by Index
#'
#' Retrieves a specific plot group.
#'
#' @param device_id Graphics device ID
#' @param group_index Index of the group to retrieve
#' @return Plot group list or NULL if not found
#' @keywords internal
get_plot_group <- function(device_id = grDevices::dev.cur(), group_index) {
  grouped <- group_device_calls(device_id)

  if (group_index < 1 || group_index > length(grouped$groups)) {
    return(NULL)
  }

  grouped$groups[[group_index]]
}

#' Get All Plot Groups
#'
#' Retrieves all plot groups for a device.
#'
#' @param device_id Graphics device ID
#' @return List of plot groups
#' @keywords internal
get_all_plot_groups <- function(device_id = grDevices::dev.cur()) {
  grouped <- group_device_calls(device_id)
  grouped$groups
}

#' Get Group Count
#'
#' Returns the number of plot groups for a device.
#'
#' @param device_id Graphics device ID
#' @return Number of groups (integer)
#' @keywords internal
get_group_count <- function(device_id = grDevices::dev.cur()) {
  grouped <- group_device_calls(device_id)
  grouped$total_groups
}

#' Detect Multi-panel Configuration
#'
#' Analyzes layout calls to determine multi-panel configuration.
#'
#' @param device_id Graphics device ID
#' @return Panel configuration list or NULL
#' @keywords internal
detect_panel_configuration <- function(device_id = grDevices::dev.cur()) {
  grouped <- group_device_calls(device_id)
  layout_calls <- grouped$layout_calls

  if (length(layout_calls) == 0) {
    return(grid_of_cells(grouped$groups))
  }

  # A layout call only governs the plots drawn AFTER it, so a layout call
  # that comes after the last plot describes nothing that was drawn. That
  # is the idiomatic trailing reset:
  #
  #   par(mfrow = c(2, 2)); plot(a); plot(b); plot(c); plot(d)
  #   par(mfrow = c(1, 1))   # restore for the next figure
  #
  # Without this filter the trailing reset wins and the 2x2 grid collapses
  # to a single panel, dropping three quarters of the accessible output.
  # With no plots recorded there is nothing for a layout call to come after,
  # so the filter does not apply: the call still describes the grid the user
  # set up for plots yet to be drawn.
  if (length(grouped$groups) > 0) {
    last_plot_index <- max(
      vapply(grouped$groups, function(g) g$high_call_index, numeric(1))
    )
    layout_calls <- Filter(
      function(call) isTRUE(call$storage_index < last_plot_index),
      layout_calls
    )

    if (length(layout_calls) == 0) {
      return(grid_of_cells(grouped$groups))
    }
  }

  # Among the layout calls that do govern drawn plots, the last one wins.
  config <- NULL
  for (call in layout_calls) {
    args <- call$args
    if (call$function_name == "par") {
      args <- par_setting_arguments(args)
    }
    if (
      call$function_name == "par" &&
        (!is.null(args[["mfrow"]]) || !is.null(args[["mfcol"]]))
    ) {
      # Handle both mfrow and mfcol
      layout_vec <- if (!is.null(args[["mfrow"]])) {
        args[["mfrow"]]
      } else {
        args[["mfcol"]]
      }

      layout_type <- if (!is.null(args[["mfrow"]])) "mfrow" else "mfcol"

      config <- list(
        type = layout_type,
        nrows = layout_vec[1],
        ncols = layout_vec[2],
        total_panels = layout_vec[1] * layout_vec[2],
        layout_index = call$storage_index
      )
    } else if (call$function_name == "layout" && length(args) > 0) {
      # layout() takes a vector as a one-column matrix: `layout(1)` puts
      # the device back to a single panel.
      mat <- args[[1]]
      if (is.numeric(mat) && !is.matrix(mat)) {
        mat <- as.matrix(mat)
      }
      if (is.matrix(mat)) {
        config <- list(
          type = "layout",
          nrows = nrow(mat),
          ncols = ncol(mat),
          # 0 marks empty cells in a layout() matrix, not a panel
          total_panels = length(unique(as.vector(mat[mat > 0]))),
          matrix = mat,
          layout_index = call$storage_index
        )
      }
    }
  }

  if (!is.null(config) && !grid_holds_a_plot(grouped$groups, config)) {
    config <- NULL
  }

  config %||% grid_of_cells(grouped$groups)
}

#' The grid R drew a page's plots in, from the cells it put them in
#'
#' Where no recorded layout call sets up the grid the page's plots are in,
#' R still reports the cell it put each in (`par("mfg")`): a
#' `par(mfrow = )` made through `graphics::par()` or `withr::with_par()`,
#' before `maidr_on()`, or before an earlier `show()` or `save_html()` on
#' the device, which cleared the calls recorded with it. Without it the
#' page's plots were read as one, and drawn over each other at full size.
#' Its plots are read in the panels of an `mfrow` grid of that shape, and
#' each drawn in its cell, where R drew it. Where R drew a plot across
#' several cells, as a `layout()` panel that spans them, the grid is that
#' `layout()` (`layout_of_regions()`), with a panel too for each plot no
#' recorded call started that a low-level call was drawn on, as a legend's
#' `plot.new()` is. A plot that laid out a grid of its own (`laid_out`, see
#' `end_base_r_call()`) or that a region of the page was given, by
#' `par(fig = )` or `screen()`, in a cell of a grid of one, is not one of
#' them.
#'
#' @param groups Plot groups from group_device_calls()
#' @return Panel configuration list, with `derived` TRUE, or NULL when the
#'   cells name no grid of more than one panel, or several
#' @keywords internal
#' @noRd
grid_of_cells <- function(groups) {
  in_cell <- function(call) {
    length(call$cell) == 4L && !anyNA(call$cell) && !isTRUE(call$laid_out) &&
      prod(call$cell[3:4]) > 1L
  }
  highs <- Filter(in_cell, lapply(groups, function(g) g$high_call))
  if (length(highs) == 0L) {
    return(NULL)
  }
  dims <- unique(lapply(highs, function(high) as.integer(high$cell[3:4])))
  if (length(dims) != 1L || prod(dims[[1]]) < 2L) {
    return(NULL)
  }
  # Every plot drawn on, in the order R drew them: a low-level call on a
  # plot no recorded call started is drawn before the group after it, or,
  # after the last, with the last.
  drawn <- unlist(
    lapply(groups, function(g) c(g$before_calls, list(g$high_call), g$after_calls)),
    recursive = FALSE
  )
  regions <- Filter(
    function(call) in_cell(call) && identical(as.integer(call$cell[3:4]), dims[[1]]),
    drawn
  )
  config <- layout_of_regions(regions, dims[[1]]) %||% list(
    type = "mfrow",
    nrows = dims[[1]][[1]],
    ncols = dims[[1]][[2]],
    total_panels = prod(dims[[1]])
  )
  config$derived <- TRUE
  if (!all(vapply(highs, plot_in_grid, logical(1), config = config))) {
    return(NULL)
  }
  config
}

#' The `layout()` R drew a page's plots in, from the regions it gave them
#'
#' Under `layout()` R reports the cell at the top left of a plot's panel
#' (`par("mfg")`) and the panel's region of the page (`par("fig")`), which
#' covers as many cells of the grid as the panel spans. The panels are
#' numbered in the order R drew in them, as it numbers a `layout()`'s
#' panels; a cell no plot was drawn in is empty. A plot drawn over another
#' after `par(new = TRUE)` is in its panel.
#'
#' @param highs The recorded calls drawn on the page's plots, in the order
#'   R drew them, each with the `cell` and `fig` of its plot
#' @param dims The grid's rows and columns
#' @return A `layout` panel configuration with its `matrix`, or NULL where
#'   each plot is in one cell, or where a region is not cells of a grid of
#'   equal rows and columns, as one of a `layout()` with `widths` or
#'   `heights` is not
#' @keywords internal
#' @noRd
layout_of_regions <- function(highs, dims) {
  nrows <- dims[[1]]
  ncols <- dims[[2]]
  mat <- matrix(0L, nrows, ncols)
  spans <- FALSE
  near <- function(a, b) isTRUE(abs(a - b) < 1e-6)
  for (high in highs) {
    fig <- high$fig
    if (length(fig) != 4L || anyNA(fig)) {
      return(NULL)
    }
    row <- high$cell[[1]]
    col <- high$cell[[2]]
    across <- (fig[[2]] - fig[[1]]) * ncols
    down <- (fig[[4]] - fig[[3]]) * nrows
    aligned <- round(across) >= 1 && round(down) >= 1 &&
      near(across, round(across)) && near(down, round(down)) &&
      near(fig[[1]], (col - 1) / ncols) && near(fig[[4]], 1 - (row - 1) / nrows)
    if (!aligned) {
      return(NULL)
    }
    rows <- row + seq_len(round(down)) - 1L
    cols <- col + seq_len(round(across)) - 1L
    if (max(rows) > nrows || max(cols) > ncols) {
      return(NULL)
    }
    spans <- spans || length(rows) > 1L || length(cols) > 1L
    taken <- mat[rows, cols]
    if (all(taken == 0L)) {
      mat[rows, cols] <- max(mat) + 1L
    } else if (!all(taken == taken[[1]]) || sum(mat == taken[[1]]) != length(taken)) {
      return(NULL)
    }
  }
  if (!spans) {
    return(NULL)
  }
  list(
    type = "layout",
    nrows = nrows,
    ncols = ncols,
    total_panels = max(mat),
    matrix = mat
  )
}

#' Whether R drew a plot of the page in a grid
#'
#' A grid the recorded layout calls set up is the page's only where R drew
#' a plot of the page in one of its cells (`plot_in_grid()`). A function
#' that lays out a page of its own, as `heatmap()` does with `layout()`,
#' draws in a grid it sets up itself, unrecorded: after
#' `par(mfrow = c(1, 2)); plot(x); heatmap(m)` R's page is the heatmap
#' alone, not a panel of two. Plots recorded without their cell, by code
#' that records calls itself, are taken to be in the grid.
#'
#' @param groups Plot groups from group_device_calls()
#' @param config The grid, from the layout call that set it up
#' @return Logical
#' @keywords internal
#' @noRd
grid_holds_a_plot <- function(groups, config) {
  after <- Filter(
    function(g) is.null(config$layout_index) || isTRUE(g$high_call_index > config$layout_index),
    groups
  )
  highs <- Filter(function(high) !is.null(high$cell), lapply(after, function(g) g$high_call))
  length(highs) == 0L ||
    any(vapply(highs, plot_in_grid, logical(1), config = config))
}

#' Whether R drew a recorded plot in a cell of a grid
#'
#' R put the plot in a cell of a grid of the same shape (its `cell`, from
#' `par("mfg")`). A plot that started a page is in the grid's first panel:
#' R starts a page of an `mfrow` or `mfcol` grid in its first cell -- a
#' plot `par(mfg = )` sends elsewhere starts none -- and a page of a
#' `layout()` in its panel 1. One that started a page anywhere else, as
#' the image of `heatmap()` does in the corner of the 2 x 2 layout it sets
#' up, is in a grid of its own that has that shape; and so is one that laid
#' out a grid of its own (`laid_out`, see `end_base_r_call()`).
#'
#' @param high The plot's recorded call
#' @param config The grid
#' @return Logical
#' @keywords internal
#' @noRd
plot_in_grid <- function(high, config) {
  cell <- high$cell
  dims <- as.integer(c(config$nrows, config$ncols))
  if (length(cell) != 4L || !identical(as.integer(cell[3:4]), dims) || isTRUE(high$laid_out)) {
    return(FALSE)
  }
  !isTRUE(high$opens_page) || identical(panel_of_cell(cell, config), 1L)
}

#' The settings a recorded `par()` call made
#'
#' `par()` takes its settings as arguments, or as one list of them: the
#' list an earlier `par()` call returned, as in the idiom
#' `op <- par(mfrow = c(1, 2)); ...; par(op)`, which puts the device back
#' to the grid it had.
#'
#' @param args The recorded arguments of the `par()` call
#' @return The settings, as a named list
#' @keywords internal
#' @noRd
par_setting_arguments <- function(args) {
  if (length(args) == 1L && is.list(args[[1L]])) args[[1L]] else args
}

#' The margins a recorded plot was drawn with
#'
#' Base R gives a plot the room its figure has less its margins, and the
#' margins are what `par()` set before the plot was drawn: `mar` or `mai`,
#' `oma` or `omi`, and the height of a margin's line, which `mex` and `cex`
#' scale. A chart drawn again with R's own margins can be too small for them
#' at a size R drew it at with the author's -- a `par(mfrow = c(5, 1), mar =
#' c(1, 2, 1, 1))` grid at 7 x 5 in -- so they are set again before each
#' plot is.
#'
#' The settings are those the `par()` calls recorded before the plot left in
#' place, in the order they were last set, as `mar` and `mai` set the same
#' margins. Setting up a grid, with `par(mfrow = )`, `par(mfcol = )` or
#' `layout()`, puts `cex` and `mex` back to the grid's own, as R does.
#'
#' @param layout_calls The recorded LAYOUT calls, from [group_device_calls()]
#' @param before The position in the recording of the plot's HIGH-level call
#' @return The settings, as a named list for `par()`
#' @keywords internal
#' @noRd
par_margin_settings <- function(layout_calls, before) {
  margins <- c("mar", "mai", "oma", "omi", "mex", "cex")
  settings <- list()
  for (call in layout_calls) {
    if (call$storage_index > before) {
      break
    }
    if (call$function_name == "layout") {
      settings[c("cex", "mex")] <- NULL
    }
    if (call$function_name != "par") {
      next
    }
    args <- par_setting_arguments(call$args)
    for (name in names(args)) {
      if (name %in% c("mfrow", "mfcol")) {
        settings[c("cex", "mex")] <- NULL
      } else if (name %in% margins && is.numeric(args[[name]])) {
        # Moved to the end: the last of `mar` and `mai` set wins.
        settings[[name]] <- NULL
        settings[[name]] <- args[[name]]
      }
    }
  }
  settings
}

#' Check Whether a Panel Configuration Describes a Multi-panel Grid
#'
#' @param panel_config Panel configuration from detect_panel_configuration()
#' @return TRUE for a multi-panel (mfrow/mfcol/layout) grid
#' @keywords internal
is_multipanel_config <- function(panel_config) {
  !is.null(panel_config) &&
    panel_config$type %in% c("mfrow", "mfcol", "layout") &&
    (panel_config$nrows > 1 || panel_config$ncols > 1)
}

#' Compute Panel Slot for Each Plot Group
#'
#' Maps plot groups to panel slots (1-based) for a multi-panel
#' configuration: the panel R drew each group's plot in, as its call was
#' recorded -- the cell R put it in, so a plot `par(mfg = )` sent out of
#' turn is in that panel. A plot drawn after `par(new = TRUE)`, or in a
#' region `par(fig = )` gave it, shares the panel of the plot before it,
#' and a panel `plot.new()` or `frame()` passed over is left empty. Groups
#' recorded without their panel, by code that records calls itself, take
#' one each in drawing order:
#' \itemize{
#'   \item Groups drawn BEFORE the layout call are not part of the grid
#'     (the next high-level plot starts a fresh page), so they get NA.
#'   \item When more groups than panels were drawn, R flows onto a new
#'     page; only the final (visible) page is exported, so groups on
#'     earlier pages get NA.
#' }
#'
#' @param plot_groups List of plot groups from group_device_calls()
#' @param panel_config Panel configuration from detect_panel_configuration()
#' @return Integer vector (one entry per group): panel slot or NA
#' @keywords internal
compute_panel_slots <- function(plot_groups, panel_config) {
  n_groups <- length(plot_groups)
  slots <- rep(NA_integer_, n_groups)
  if (n_groups == 0) {
    return(slots)
  }

  eligible <- seq_len(n_groups)
  if (!is.null(panel_config$layout_index)) {
    after_layout <- vapply(
      plot_groups,
      function(g) {
        is.null(g$high_call_index) ||
          g$high_call_index > panel_config$layout_index
      },
      logical(1)
    )
    eligible <- which(after_layout)
  }

  n_eligible <- length(eligible)
  if (n_eligible == 0) {
    return(slots)
  }

  total <- max(1L, as.integer(panel_config$total_panels))

  # The panel R drew each in, where every one was recorded with it: the
  # cell R said it put the plot in, in this grid, or else the panel R moved
  # on to. A plot `par(fig = )` placed is in no cell of the grid, and stays
  # in the panel of the plot before it.
  figures <- lapply(plot_groups[eligible], function(g) {
    panel_of_cell(g$high_call$cell, panel_config) %||% g$high_call$figure
  })
  if (!any(vapply(figures, is.null, logical(1)))) {
    figures <- as.integer(unlist(figures))
    figures[figures < 1L | figures > total] <- NA_integer_
    slots[eligible] <- figures
    return(slots)
  }

  last_page_start <- ((n_eligible - 1L) %/% total) * total + 1L
  visible <- eligible[seq.int(last_page_start, n_eligible)]
  slots[visible] <- seq_along(visible)
  slots
}

#' The panel of a grid a plot was drawn in, from its cell
#'
#' @param cell The cell R put the plot in, `par("mfg")` once it was started:
#'   its row and column, and the grid's rows and columns; or `NULL`
#' @param panel_config Panel configuration from detect_panel_configuration()
#' @return The panel's number in the grid's order -- by row for `mfrow`, by
#'   column for `mfcol`, the number `layout()` gave it -- or `NULL` for a
#'   cell of another grid, or none
#' @keywords internal
#' @noRd
panel_of_cell <- function(cell, panel_config) {
  if (length(cell) != 4L || anyNA(cell)) {
    return(NULL)
  }
  nrows <- as.integer(panel_config$nrows)
  ncols <- as.integer(panel_config$ncols)
  if (!identical(as.integer(cell[3:4]), c(nrows, ncols))) {
    return(NULL)
  }
  row <- cell[[1]]
  col <- cell[[2]]
  if (identical(panel_config$type, "layout")) {
    panel <- panel_config$matrix[row, col]
    return(if (isTRUE(panel > 0)) as.integer(panel))
  }
  if (identical(panel_config$type, "mfcol")) {
    return(as.integer((col - 1L) * nrows + row))
  }
  as.integer((row - 1L) * ncols + col)
}

#' Convert a Panel Slot Number to its (row, column) Grid Positions
#'
#' A `layout()` matrix may name the same panel in several cells; R draws that
#' panel once, spanning all of them. Returning every matching cell (in reading
#' order) lets the caller advertise the panel in each cell it actually covers,
#' so a spanned region is not mistaken for empty space. An `mfrow`/`mfcol`
#' grid cannot span, so it always yields exactly one cell.
#'
#' @param slot Panel slot number (1-based)
#' @param panel_config Panel configuration from detect_panel_configuration()
#' @return List of integer vectors c(row, col); empty list if the slot
#'   occupies no cell
#' @keywords internal
panel_slot_positions <- function(slot, panel_config) {
  nrows <- panel_config$nrows
  ncols <- panel_config$ncols

  if (identical(panel_config$type, "layout") && !is.null(panel_config$matrix)) {
    pos <- which(panel_config$matrix == slot, arr.ind = TRUE)
    if (nrow(pos) == 0) {
      return(list())
    }
    # Reading order: top-to-bottom, then left-to-right.
    ordered <- order(pos[, 1], pos[, 2])
    return(lapply(ordered, function(i) {
      c(as.integer(pos[i, 1]), as.integer(pos[i, 2]))
    }))
  }

  if (identical(panel_config$type, "mfcol")) {
    col <- ceiling(slot / nrows)
    row <- ((slot - 1) %% nrows) + 1
  } else {
    row <- ceiling(slot / ncols)
    col <- ((slot - 1) %% ncols) + 1
  }
  list(c(as.integer(row), as.integer(col)))
}
