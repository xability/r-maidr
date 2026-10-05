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
#' One drawn on a plot started over an earlier group's, in its cell or
#' screen, after `par(mfg = )` or `screen()` sent R back there, is read with
#' that group, marked `overlay` and `read_only`, and drawn with the calls on
#' plots no recorded call started, in its place among them
#' (`drawn_over_earlier_plot()`).
#' One drawn after `par(mfg = )` or `screen()` sent R back to the cell or
#' screen of an earlier group's plot, without starting a plot, is one of
#' that group's, marked `sent_back`: R draws it there, on that plot, in the
#' coordinates R had (`sent_back_to()`). One R clipped away, as it does
#' what `screen()` sends it back to draw before anything works its clip out
#' again, is in no group (`clipped_away_calls()`).
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
  # Drawn where R clipped all of it away: not drawn, and not read.
  clipped <- clipped_away_calls(all_calls)

  for (i in seq_along(all_calls)) {
    call <- all_calls[[i]]
    class_level <- call$class_level
    if (clipped[[i]]) {
      next
    }

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
      over <- if (unrecorded_plot) drawn_over_earlier_plot(call, groups, current_group) else NA
      if (!is.na(over)) {
        # Read with the plot it is drawn over; drawn in its place among
        # the calls on plots no recorded call started, as R started its
        # plot after the plots between them.
        call$storage_index <- i
        unrecorded <- append(unrecorded, list(call))
        call$overlay <- TRUE
        call$read_only <- TRUE
        groups[[over]]$low_calls <- append(groups[[over]]$low_calls, list(call))
        groups[[over]]$low_call_indices <- c(groups[[over]]$low_call_indices, i)
      } else if (unrecorded_plot && !drawn_over_group_plot(call, current_group)) {
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

#' The low-level calls R draws clipped away
#'
#' R clips what it draws to the plot region of the plot it was drawing on
#' when it last worked its clip out: as it started a plot, or was sent to a
#' cell of a grid with `par(mfg = )`, and as `xpd` changes, which `axis()`,
#' `title()`, `mtext()` and `box()` do to draw in the margins, as does a
#' call given `xpd`, or `par(xpd = )`, and as `par(fig = )` gives it a
#' region. `screen(n, new = FALSE)` of `split.screen()` sends R to another
#' region of the page without starting a plot, and sets the cell before
#' the region, which keeps the clip R had: an `abline()`, `text()` or
#' `legend()` drawn there next, as `?split.screen` adds to a screen, is
#' clipped to the plot region of the plot drawn before, in another screen,
#' and R shows none of it, until one of those works the clip out again.
#' maidr drew it, and a reader heard a line R's page does not show. A plot
#' region the clip overlaps would show part of it; it is read as clipped,
#' and so is what is drawn after a region `graphics::par(fig = )` gave R,
#' which maidr does not record.
#'
#' @param calls The recorded calls on the page R shows, in order
#' @return Logical, one per call: TRUE for a low-level call drawn in
#'   another region of the page than the one R clipped to
#' @keywords internal
#' @noRd
clipped_away_calls <- function(calls) {
  clipped <- logical(length(calls))
  # Where R clips to: the region of the page, and `xpd`, as it last worked
  # the clip out; NULL where it is not known.
  clip <- NULL
  plots <- 0L
  resets <- c("axis", "title", "mtext", "box")
  for (i in seq_along(calls)) {
    call <- calls[[i]]
    region <- call$drawn_fig %||% call$fig
    xpd <- call$pars$xpd
    level <- call$class_level
    if (identical(level, "LAYOUT")) {
      settings <- if (identical(call$function_name, "par")) par_setting_arguments(call$args)
      if (any(c("xpd", "mfg", "fig") %in% names(settings))) {
        clip <- NULL
      }
      next
    }
    on <- call$end_plot
    if (!identical(level, "LOW") || starts_base_r_plot(call)) {
      clip <- list(region = region, xpd = xpd)
      plots <- max(plots, if (is.numeric(on) && length(on) == 1L) on else plots)
      next
    }
    if (is.numeric(on) && length(on) == 1L && on > plots) {
      # Drawn on a plot no recorded call started, which R worked the clip
      # out for as it started it.
      plots <- on
      clip <- list(region = call$fig, xpd = xpd)
    }
    resets_clip <- call$function_name %in% resets || "xpd" %in% names(call$args)
    in_region <- length(call$drawn_cell) == 4L &&
      identical(as.integer(call$drawn_cell[3:4]), c(1L, 1L))
    if (resets_clip || is.null(clip) || !identical(clip$xpd, xpd) || !in_region) {
      clip <- list(region = region, xpd = xpd)
      next
    }
    clipped[[i]] <- length(region) == 4L && length(clip$region) == 4L &&
      !same_region(region, clip$region) && isFALSE(is.na(xpd))
  }
  clipped
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
#' FALSE)` and `axis(4)` is drawn on screen 1's plot, in the coordinates
#' `screen()` put back. It was read as a layer of the last plot, and drawn
#' on it. (Without `axis()`, which works R's clip out again, R clips the
#' line away: `clipped_away_calls()`.)
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
  last_plot_known <- same_cell_and_region(call$cell, call$fig, call$cell, call$fig)
  drawn_there <- same_cell_and_region(call$drawn_cell, call$drawn_fig, call$cell, call$fig)
  if (!last_plot_known || drawn_there) {
    return(NA_integer_)
  }
  there <- vapply(
    groups,
    function(group) {
      same_cell_and_region(
        group$high_call$cell, group$high_call$fig, call$drawn_cell, call$drawn_fig
      )
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
same_cell_and_region <- function(cell, fig, other_cell, other_fig) {
  known <- function(cell, fig) {
    length(cell) == 4L && !anyNA(cell) && length(fig) == 4L && !anyNA(fig)
  }
  known(cell, fig) && known(other_cell, other_fig) &&
    identical(as.integer(cell), as.integer(other_cell)) &&
    max(abs(fig - other_fig)) < 1e-6
}

#' The earlier group a plot no recorded call started was drawn over
#'
#' A plot started after `par(mfg = )` or `screen()` sent R back to the cell
#' or screen of an earlier plot, as a second series with an axis of its
#' own is started with `par(new = TRUE)` and `plot.new()`, is drawn over
#' that plot: R does not clear a panel of its page. What is drawn on it was
#' read as part of no plot, or with the plot drawn last.
#'
#' @param call The recorded LOW-level call, drawn on that plot
#' @param groups The page's plot groups before the one recorded last
#' @param current_group The plot group recorded last, or NULL
#' @return The index in `groups` of the last group whose plot is in the
#'   cell and region of the plot `call` is drawn on (`cell`, `fig`); NA
#'   where none is, or where the last group's plot is there too, which
#'   `drawn_over_group_plot()` finds
#' @keywords internal
#' @noRd
drawn_over_earlier_plot <- function(call, groups, current_group) {
  on <- function(group) {
    same_cell_and_region(group$high_call$cell, group$high_call$fig, call$cell, call$fig)
  }
  if (!is.null(current_group) && on(current_group)) {
    return(NA_integer_)
  }
  there <- vapply(groups, on, logical(1))
  if (any(there)) max(which(there)) else NA_integer_
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
  #
  # A grid of one set up between two plots of the page, as
  # `par(mfrow = c(1, 1), new = TRUE)` is to draw a legend for a grid over
  # the whole page, lays out only the plot drawn over the page after it,
  # which R started no page for: the plots before it keep their panels.
  if (length(grouped$groups) > 0) {
    plot_indices <- vapply(grouped$groups, function(g) g$high_call_index, numeric(1))
    last_plot_index <- max(plot_indices)
    over_page <- function(call) {
      after <- which(plot_indices > call$storage_index)
      next_plot <- if (length(after) > 0) grouped$groups[[min(after)]]$high_call
      # Whether it sets a grid of one is read last: a layout() call's
      # arguments are matched against layout() to find its matrix.
      isTRUE(call$storage_index > min(plot_indices)) && isFALSE(next_plot$opens_page) &&
        sets_grid_of_one(call)
    }
    layout_calls <- Filter(
      function(call) isTRUE(call$storage_index < last_plot_index) && !over_page(call),
      layout_calls
    )

    if (length(layout_calls) == 0) {
      return(grid_of_cells(grouped$groups))
    }
  }

  # Among the layout calls that do govern drawn plots, the last one that
  # sets a grid wins. They are read from the last back, and no further than
  # that one: a save comes here about once for each plot the device holds,
  # and reading every layout() call each time made saving a device of many
  # layout() pages take twice as long.
  config <- NULL
  for (call in rev(layout_calls)) {
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
      args <- layout_arguments(args)
      mat <- layout_matrix(args)
      if (is.matrix(mat)) {
        config <- list(
          type = "layout",
          nrows = nrow(mat),
          ncols = ncol(mat),
          # 0 marks empty cells in a layout() matrix, not a panel
          total_panels = length(unique(as.vector(mat[mat > 0]))),
          matrix = mat,
          # The room the call gave the matrix's columns and rows, and which
          # of them keep their shape, to set up the grid again with.
          sizes = args[intersect(names(args), c("widths", "heights", "respect"))],
          layout_index = call$storage_index
        )
      }
    }
    if (!is.null(config)) {
      break
    }
  }

  if (!is.null(config) && !grid_holds_a_plot(grouped$groups, config)) {
    config <- NULL
  }
  if (identical(config$type, "layout") && length(config$matrix) == 1L) {
    config$cell_fig <- layout_cell_region(grouped$groups, config, layout_calls)
  }

  config %||% grid_of_cells(grouped$groups)
}

#' Whether a recorded layout call sets up a grid of one panel
#'
#' @param call A recorded LAYOUT call
#' @return Logical: `par(mfrow = c(1, 1))` or `par(mfcol = c(1, 1))`, or a
#'   `layout()` of one panel
#' @keywords internal
#' @noRd
sets_grid_of_one <- function(call) {
  args <- call$args
  if (identical(call$function_name, "par")) {
    args <- par_setting_arguments(args)
    grid <- args[["mfrow"]] %||% args[["mfcol"]]
    return(is.numeric(grid) && length(grid) == 2L && all(grid == 1))
  }
  mat <- if (identical(call$function_name, "layout")) layout_matrix(layout_arguments(args))
  is.numeric(mat) && length(unique(mat[mat > 0])) == 1L
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

#' A recorded `layout()` call's arguments, each named as R matched it
#'
#' The recording names an argument written without its name only when it is
#' not the first of `layout()`'s own, `mat` (see [match_recorded_args()]): the
#' matrix of `layout(widths = c(3, 1), m)` keeps no name, and its widths come
#' first. Matched here against `layout()` itself, the matrix is `mat` and the
#' sizes `widths`, `heights` and `respect`, however each was written.
#'
#' A call that leaves an argument empty, as `layout(m, , c(1, 3))` leaves its
#' widths, is recorded with each of its values already named and the empty
#' one left out (see `given_argument_values()`).
#'
#' @param args The recorded arguments
#' @return `args` named by the arguments of `layout()` R matched them to, or
#'   as recorded when they cannot be matched
#' @keywords internal
#' @noRd
layout_arguments <- function(args) {
  matched <- matched_arg_formals("layout", graphics::layout, args)
  if (!is.null(matched)) {
    names(args) <- matched
  }
  args
}

#' The matrix a recorded `layout()` call lays the page out by
#'
#' The argument R matched to `mat`, wherever it was written, as a matrix:
#' `layout()` takes a vector as a one-column matrix, so `layout(1)` puts the
#' device back to a single panel. Read as the first argument, the matrix of
#' `layout(widths = c(3, 1), mat = m)` was its widths.
#'
#' @param args The call's arguments, named as [layout_arguments()] names them
#' @return A numeric matrix, or NULL
#' @keywords internal
#' @noRd
layout_matrix <- function(args) {
  if (length(args) == 0L) {
    return(NULL)
  }
  mat <- args[["mat"]] %||% args[[1]]
  if (is.numeric(mat) && !is.matrix(mat)) {
    mat <- as.matrix(mat)
  }
  if (is.numeric(mat) && is.matrix(mat)) mat
}

#' The region of the page R gave the cell of a `layout()` of one cell
#'
#' `lcm()` sizes or `respect` leave the one cell of such a layout less than
#' the page, and R reports the region of each plot it draws there
#' (`par("fig")`) as a share of the page the author drew on, with the cell
#' of a grid of one, as it reports a region `par(fig = )` gave a plot. The
#' cell is the region of the first plot R started after the `layout()`
#' call, which R put there; the layout set up again puts the plots drawn in
#' it in its cell on the chart's page (`is_figure_region()`). A
#' `par(fig = )` recorded between the two gave that plot a region of its
#' own, and R draws in the layout no more after it.
#'
#' @param groups Plot groups from group_device_calls()
#' @param config The page's `layout()` of one cell, from
#'   [detect_panel_configuration()]
#' @param layout_calls The recorded layout calls
#' @return The region, as `par("fig")` gives it, or NULL where the call
#'   sizes no cell or no plot is known to be in it
#' @keywords internal
#' @noRd
layout_cell_region <- function(groups, config, layout_calls) {
  if (length(config$sizes) == 0L) {
    return(NULL)
  }
  first <- Find(
    function(group) {
      isTRUE(group$high_call_index > config$layout_index) && isTRUE(group$high_call$new_plot)
    },
    groups
  )
  fig <- first$high_call$fig
  given <- Find(
    function(call) {
      identical(call$function_name, "par") &&
        isTRUE(call$storage_index > config$layout_index) &&
        isTRUE(call$storage_index < first$high_call_index) &&
        "fig" %in% names(par_setting_arguments(call$args))
    },
    layout_calls
  )
  if (length(fig) == 4L && is.null(given)) fig
}

#' Whether R drew in the cell of a page's `layout()` of one cell
#'
#' @param fig The region R reported for it (`par("fig")`)
#' @param panel_config The page's configuration, or NULL
#' @return Logical
#' @keywords internal
#' @noRd
in_layout_cell <- function(fig, panel_config) {
  cell <- panel_config$cell_fig
  length(cell) == 4L && length(fig) == 4L && !anyNA(fig) && same_region(fig, cell)
}

#' Whether a page's `layout()` call sizes any of its cells with `lcm()`
#'
#' `lcm()` gives a size as text, "5 cm", and `layout()` takes each of its
#' sizes that says "cm" as centimetres.
#'
#' @param panel_config The page's configuration, from
#'   [detect_panel_configuration()], or NULL
#' @return Logical
#' @keywords internal
#' @noRd
layout_sizes_in_cm <- function(panel_config) {
  if (!identical(panel_config$type, "layout")) {
    return(FALSE)
  }
  sizes <- panel_config$sizes[intersect(names(panel_config$sizes), c("widths", "heights"))]
  any(vapply(sizes, function(size) {
    is.character(size) && any(grepl("cm", size, fixed = TRUE))
  }, logical(1)))
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

#' Which plots are drawn over one another
#'
#' `par(new = TRUE)` draws the next plot over the last one, as a chart of two
#' y axes does, and a high-level call given `add = TRUE` draws onto it
#' (`shared_plots()`). Each such plot is in the run of the plot it is drawn
#' over. `par(new = TRUE)` is read from a recorded `par()` call, or else from
#' where R started the plot (`stayed_in_panel()`): made through
#' `graphics::par()` or `withr::with_par()`, it is not recorded. With
#' `par(fig = , new = TRUE)` or `par(plt = , new = TRUE)` the next
#' plot is drawn on the same page but in another region of it, beside the
#' last one or inset in it, so it is drawn over the last one only where R
#' drew both in the same plot region (`device_plot_region()`).
#'
#' @param groups The plot groups, from [group_device_calls()]
#' @param layout_calls The recorded LAYOUT calls, from [group_device_calls()]
#' @return Integer vector, one entry per group: the index of the first plot
#'   of its run
#' @keywords internal
#' @noRd
overlay_runs <- function(groups, layout_calls) {
  runs <- seq_along(groups)
  for (g in seq_along(groups)[-1L]) {
    after <- groups[[g - 1L]]$high_call_index
    before <- groups[[g]]$high_call_index
    if (is.null(after) || is.null(before)) {
      next
    }
    new <- FALSE
    for (call in layout_calls) {
      at <- call$storage_index
      if (identical(call$function_name, "par") && !is.null(at) && at > after && at < before) {
        settings <- par_setting_arguments(call$args)
        if ("new" %in% names(settings)) {
          new <- isTRUE(as.logical(settings[["new"]]))
        }
      }
    }
    drawn_over <- new || recorded_flag(groups[[g]]$high_call$args, "add") ||
      stayed_in_panel(groups[[g - 1L]]$high_call, groups[[g]]$high_call)
    if (drawn_over && same_plot_region(groups[[g - 1L]], groups[[g]])) {
      runs[[g]] <- runs[[g - 1L]]
    }
  }
  runs
}

#' Whether R started a plot over the one it was on once the call before was done
#'
#' R moves on a panel for every plot it starts, unless `par(new = TRUE)`
#' keeps it in the panel of the last (`note_base_r_plot_new()`), however
#' that was set. So a plot started on the page and in the panel R was in
#' when the call before it was done, as the next plot R started there, was
#' drawn after `par(new = TRUE)`, or sent to that panel with `par(mfg = )`
#' or `screen(n, new = FALSE)`. `screen(n)` itself erases the screen first,
#' with a plot of its own that it fills with the background: a plot drawn
#' after it is drawn over that one, where the plot before is no longer seen,
#' and is not drawn over it.
#'
#' @param before,high The high-level calls of two plot groups, in the order
#'   they were made
#' @return TRUE or FALSE; FALSE for a call recorded without where R drew it
#' @keywords internal
#' @noRd
stayed_in_panel <- function(before, high) {
  isTRUE(high$new_plot) && is.numeric(high$figure) &&
    identical(high$page, before$page) &&
    identical(high$figure, before$end_figure %||% before$figure) &&
    identical(as.integer(high$plot), as.integer((before$end_plot %||% before$plot) + 1L))
}

#' The plot each high-level call draws on
#'
#' A high-level call given `add = TRUE`, such as `contour(add = TRUE)` or
#' `boxplot(add = TRUE)`, draws onto the plot drawn last, against its axes,
#' rather than drawing a plot of its own.
#'
#' @param groups The plot groups, from [group_device_calls()]
#' @return Integer vector, one entry per group: the index of the group that
#'   drew the plot it draws on, its own where it draws a plot of its own
#' @keywords internal
#' @noRd
shared_plots <- function(groups) {
  plots <- seq_along(groups)
  for (g in seq_along(groups)[-1L]) {
    added <- recorded_flag(groups[[g]]$high_call$args, "add")
    if (added && same_plot_region(groups[[g - 1L]], groups[[g]])) {
      plots[[g]] <- plots[[g - 1L]]
    }
  }
  plots
}

#' Whether R drew two plots in the same plot region
#'
#' @param a,b Two plot groups, from [group_device_calls()]
#' @return TRUE where the regions recorded with their high-level calls are
#'   the same, or where either was not recorded
#' @keywords internal
#' @noRd
same_plot_region <- function(a, b) {
  first <- a$high_call$plot_region
  second <- b$high_call$plot_region
  is.null(first) || is.null(second) || same_region(first, second)
}

#' Whether two regions recorded by `device_plot_region()` are the same
#'
#' @param a,b Two recorded regions
#' @return TRUE or FALSE
#' @keywords internal
#' @noRd
same_region <- function(a, b) {
  length(a) == length(b) && all(abs(a - b) < 1e-8)
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
#' `layout()`, puts `cex` and `mex` back to the grid's own, as R does
#' (`grid_cex()`): a plot drawn after the grid on a page of its own, as one
#' after `par(fig = c(0, 1, 0, 1))` is, is drawn with them, and was drawn
#' with text 20% to 50% larger than R's.
#'
#' @param layout_calls The recorded LAYOUT calls, from [group_device_calls()]
#' @param before The position in the recording of the plot's HIGH-level call
#' @return The settings, as a named list for `par()`
#' @keywords internal
#' @noRd
par_margin_settings <- function(layout_calls, before) {
  margins <- c("mar", "mai", "oma", "omi", "mex", "cex")
  settings <- list()
  # Moved to the end, as each is set: the last of `mar` and `mai` set wins.
  set <- function(settings, name, value) {
    settings[[name]] <- NULL
    settings[[name]] <- value
    settings
  }
  # A grid of a shape not known leaves them to the grid the drawing sets.
  set_up_grid <- function(settings, dims) {
    if (!is.numeric(dims) || length(dims) != 2L || anyNA(dims)) {
      settings[c("cex", "mex")] <- NULL
      return(settings)
    }
    set(set(settings, "cex", grid_cex(dims[[1]], dims[[2]])), "mex", 1)
  }
  for (call in layout_calls) {
    if (call$storage_index > before) {
      break
    }
    if (call$function_name == "layout") {
      settings <- set_up_grid(settings, dim(layout_matrix(layout_arguments(call$args))))
    }
    if (call$function_name != "par") {
      next
    }
    args <- par_setting_arguments(call$args)
    for (name in names(args)) {
      if (name %in% c("mfrow", "mfcol")) {
        settings <- set_up_grid(settings, args[[name]])
      } else if (name %in% margins && is.numeric(args[[name]])) {
        settings <- set(settings, name, args[[name]])
      }
    }
  }
  settings
}

#' The margins R drew a recorded call's plot with
#'
#' Read from R, they are those it drew the plot with whatever set them: a
#' `par()` call maidr records, or one it does not, made through
#' `graphics::par()` or `withr::with_par()`, `screen()`, which puts back the
#' margins and size of text of each screen of `split.screen()`, or
#' `split.screen()` itself, which sets the outer margins to none while its
#' screens are in use. Read from the recorded `par()` calls instead
#' (`par_margin_settings()`), a screen's plot was drawn with the margins set
#' for another screen, and under outer margins R had taken away.
#'
#' They are the margins in inches R drew the plot with, where R did not
#' work them out again as it started it (`end_base_r_call()`): a
#' `par(cex = )` set after `screen()`, or before a plot drawn over another
#' after `par(new = TRUE)`, does not change them; with the size of text,
#' and `mex`, which sets the height of a line of margin text, as R had them
#' as the call started. Else they are the margins in lines with those
#' (`begin_base_r_call()`), which R works them out from, as the drawing
#' does.
#'
#' @param call A recorded call, with the `margins` of the plot it started
#'   or drew on and the `pars` it started with
#' @return The settings, as a named list for `par()`, or NULL where they
#'   were not read, or where `par(plt = )` gave the plot its region
#' @keywords internal
#' @noRd
recorded_margins <- function(call) {
  pars <- call$pars
  margins <- call$margins
  if (!is.numeric(pars$cex) || isTRUE(margins$region_set)) {
    return(NULL)
  }
  if (is.numeric(margins$mai) && is.numeric(margins$omi) && is.numeric(pars$mex)) {
    return(list(mai = margins$mai, omi = margins$omi, mex = pars$mex, cex = pars$cex))
  }
  lines <- c("mar", "oma", "mex", "cex")
  if (!all(vapply(pars[lines], is.numeric, logical(1)))) {
    return(NULL)
  }
  pars[lines]
}

#' The size of text R sets for a grid of plots
#'
#' `par(mfrow = )`, `par(mfcol = )` and `layout()` set `cex` for the grid
#' they set up: 0.83 for two rows and two columns, 0.66 for three or more of
#' either, 1 otherwise.
#'
#' @param nrows,ncols The grid's rows and columns
#' @return The `cex`
#' @keywords internal
#' @noRd
grid_cex <- function(nrows, ncols) {
  if (nrows > 2 || ncols > 2) {
    0.66
  } else if (nrows == 2 && ncols == 2) {
    0.83
  } else {
    1
  }
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
