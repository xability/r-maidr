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
#' Each group contains one HIGH-level call and its associated LOW-level calls.
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

  for (i in seq_along(all_calls)) {
    call <- all_calls[[i]]
    class_level <- call$class_level

    if (class_level == "LAYOUT") {
      # Keep the position in the overall call sequence so panel mapping
      # can tell which plot groups were drawn after the layout change.
      call$storage_index <- i
      layout_calls <- append(layout_calls, list(call))
    } else if (class_level == "HIGH") {
      if (!is.null(current_group)) {
        groups <- append(groups, list(current_group))
      }

      current_group <- list(
        high_call = call,
        high_call_index = i,
        low_calls = list(),
        low_call_indices = integer(0),
        panel_info = NULL
      )
    } else if (class_level == "LOW") {
      if (!is.null(current_group)) {
        current_group$low_calls <- append(current_group$low_calls, list(call))
        current_group$low_call_indices <- c(current_group$low_call_indices, i)
      }
    }
  }

  if (!is.null(current_group)) {
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
    return(NULL)
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
      return(NULL)
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
    return(NULL)
  }

  config
}

#' Whether R drew a plot of the page in a grid
#'
#' A grid the recorded layout calls set up is the page's only where R drew
#' a plot of the page in one of its cells. A function that lays out a page
#' of its own, as `heatmap()` does with `layout()`, draws in a grid it
#' sets up itself, unrecorded: after `par(mfrow = c(1, 2)); plot(x);
#' heatmap(m)` R's page is the heatmap alone, not a panel of two. Plots
#' recorded without their cell, by code that records calls itself, are
#' taken to be in the grid.
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
  cells <- Filter(Negate(is.null), lapply(after, function(g) g$high_call$cell))
  dims <- as.integer(c(config$nrows, config$ncols))
  length(cells) == 0L ||
    any(vapply(cells, function(cell) identical(as.integer(cell[3:4]), dims), logical(1)))
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
