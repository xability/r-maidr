#' Base R Plot Grouping
#'
#' This module groups plot calls into logical units:
#' - Each HIGH-level call starts a new plot group
#' - Subsequent LOW-level calls are associated with the current plot group
#' - LAYOUT calls affect multi-panel configuration
#'
#' @keywords internal

#' Group Device Calls into Plot Units
#'
#' Groups all calls from a device into logical plot units.
#' Each group contains one HIGH-level call and its associated LOW-level calls.
#'
#' @param device_id Graphics device ID
#' @return List of plot groups, each containing HIGH and LOW calls
#' @keywords internal
group_device_calls <- function(device_id = grDevices::dev.cur()) {
  all_calls <- get_device_calls(device_id)

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

  for (call in layout_calls) {
    if (call$function_name == "par" &&
        (!is.null(call$args$mfrow) || !is.null(call$args$mfcol))) {

      # Handle both mfrow and mfcol
      layout_vec <- if (!is.null(call$args$mfrow)) {
        call$args$mfrow
      } else {
        call$args$mfcol
      }

      layout_type <- if (!is.null(call$args$mfrow)) "mfrow" else "mfcol"

      return(list(
        type = layout_type,
        nrows = layout_vec[1],
        ncols = layout_vec[2],
        total_panels = layout_vec[1] * layout_vec[2]
      ))
    } else if (call$function_name == "layout") {
      mat <- call$args[[1]]
      if (is.matrix(mat)) {
        return(list(
          type = "layout",
          nrows = nrow(mat),
          ncols = ncol(mat),
          total_panels = length(unique(as.vector(mat))),
          matrix = mat
        ))
      }
    }
  }

  NULL
}
