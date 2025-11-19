#' Base R State Tracking
#'
#' This module tracks the plotting state for each graphics device,
#' including active plot index, panel configuration, and plot grouping.
#'
#' @keywords internal

#' Get or Initialize Device State
#'
#' Retrieves the state object for a specific graphics device.
#'
#' @param device_id Graphics device ID
#' @return Device state list
#' @keywords internal
get_device_state <- function(device_id = grDevices::dev.cur()) {
  storage <- get_device_storage(device_id)

  if (is.null(storage$state)) {
    storage$state <- list(
      current_plot_index = 0,
      panel_config = list(
        type = "single",
        nrows = 1,
        ncols = 1,
        current_panel = 1,
        total_panels = 1
      ),
      layout_active = FALSE,
      last_high_call_index = NULL
    )

    key <- as.character(device_id)
    .maidr_base_r_session$devices[[key]] <- storage
  }

  storage$state
}

#' Update Device State
#'
#' Updates the state for a specific graphics device.
#'
#' @param device_id Graphics device ID
#' @param state Updated state list
#' @return NULL (invisible)
#' @keywords internal
update_device_state <- function(device_id = grDevices::dev.cur(), state) {
  storage <- get_device_storage(device_id)
  storage$state <- state

  key <- as.character(device_id)
  .maidr_base_r_session$devices[[key]] <- storage

  invisible(NULL)
}

#' Handle HIGH-level Call
#'
#' Updates state when a HIGH-level plotting function is called.
#'
#' @param device_id Graphics device ID
#' @param call_index Index of the call in the calls list
#' @return NULL (invisible)
#' @keywords internal
on_high_level_call <- function(device_id = grDevices::dev.cur(), call_index) {
  state <- get_device_state(device_id)

  state$current_plot_index <- state$current_plot_index + 1
  state$last_high_call_index <- call_index

  if (state$layout_active && state$panel_config$type != "single") {
    if (state$current_plot_index <= state$panel_config$total_panels) {
      state$panel_config$current_panel <- state$current_plot_index
    }
  }

  update_device_state(device_id, state)

  invisible(NULL)
}

#' Handle LAYOUT Call
#'
#' Updates state when a layout function (par, layout) is called.
#'
#' @param device_id Graphics device ID
#' @param function_name Name of layout function
#' @param args Function arguments
#' @return NULL (invisible)
#' @keywords internal
on_layout_call <- function(device_id = grDevices::dev.cur(), function_name, args) {
  state <- get_device_state(device_id)

  if (function_name == "par" && !is.null(args$mfrow)) {
    mfrow <- args$mfrow
    state$panel_config <- list(
      type = "mfrow",
      nrows = mfrow[1],
      ncols = mfrow[2],
      current_panel = 0,
      total_panels = mfrow[1] * mfrow[2]
    )
    state$layout_active <- TRUE
    state$current_plot_index <- 0
  } else if (function_name == "layout") {
    mat <- args[[1]]
    if (is.matrix(mat)) {
      unique_panels <- length(unique(as.vector(mat)))
      state$panel_config <- list(
        type = "layout",
        nrows = nrow(mat),
        ncols = ncol(mat),
        current_panel = 0,
        total_panels = unique_panels,
        matrix = mat
      )
      state$layout_active <- TRUE
      state$current_plot_index <- 0
    }
  }

  update_device_state(device_id, state)

  invisible(NULL)
}

#' Get Current Plot Index
#'
#' Returns the current active plot index for a device.
#'
#' @param device_id Graphics device ID
#' @return Current plot index (integer)
#' @keywords internal
get_current_plot_index <- function(device_id = grDevices::dev.cur()) {
  state <- get_device_state(device_id)
  state$current_plot_index
}

#' Get Panel Configuration
#'
#' Returns the panel configuration for a device.
#'
#' @param device_id Graphics device ID
#' @return Panel configuration list
#' @keywords internal
get_panel_config <- function(device_id = grDevices::dev.cur()) {
  state <- get_device_state(device_id)
  state$panel_config
}

#' Check if Multi-panel Layout is Active
#'
#' @param device_id Graphics device ID
#' @return TRUE if multi-panel layout is active, FALSE otherwise
#' @keywords internal
is_multipanel_active <- function(device_id = grDevices::dev.cur()) {
  state <- get_device_state(device_id)
  isTRUE(state$layout_active) &&
    state$panel_config$type != "single" &&
    state$panel_config$total_panels > 1
}

#' Reset Device State
#'
#' Resets the state for a device (called when storage is cleared).
#'
#' @param device_id Graphics device ID
#' @return NULL (invisible)
#' @keywords internal
reset_device_state <- function(device_id = grDevices::dev.cur()) {
  storage <- get_device_storage(device_id)
  storage$state <- NULL

  key <- as.character(device_id)
  .maidr_base_r_session$devices[[key]] <- storage

  invisible(NULL)
}
