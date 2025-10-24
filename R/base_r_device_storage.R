#' Base R Device-Scoped Storage
#'
#' This module provides device-scoped storage for Base R plot calls,
#' enabling proper isolation between devices and preventing call accumulation.
#'
#' @keywords internal

.maidr_base_r_session <- new.env(parent = emptyenv())
.maidr_base_r_session$devices <- list()
.maidr_base_r_session$internal_guard <- FALSE

#' Get or Initialize Device Storage
#'
#' Retrieves storage for a specific graphics device, creating it if needed.
#'
#' @param device_id Graphics device ID (from grDevices::dev.cur())
#' @return Device storage list
#' @keywords internal
get_device_storage <- function(device_id = grDevices::dev.cur()) {
  if (is.null(device_id) || is.na(device_id) || device_id <= 0) {
    device_id <- grDevices::dev.cur()
  }

  key <- as.character(device_id)

  if (is.null(.maidr_base_r_session$devices[[key]])) {
    .maidr_base_r_session$devices[[key]] <- list(
      device_id = device_id,
      calls = list(),
      metadata = list(
        created = Sys.time(),
        call_count = 0
      )
    )
  }

  .maidr_base_r_session$devices[[key]]
}

#' Log Plot Call to Device Storage
#'
#' Records a plot call in the device-specific storage.
#'
#' @param function_name Name of the plotting function
#' @param call_expr The call expression
#' @param args List of function arguments
#' @param device_id Graphics device ID
#' @return NULL (invisible)
#' @keywords internal
log_plot_call_to_device <- function(function_name, call_expr, args,
                                     device_id = grDevices::dev.cur()) {
  class_level <- classify_function(function_name)
  storage <- get_device_storage(device_id)

  call_entry <- list(
    function_name = function_name,
    call_expr = if (!is.null(call_expr)) deparse(call_expr) else NA,
    args = args,
    class_level = class_level,
    timestamp = Sys.time(),
    device_id = device_id
  )

  storage$calls <- append(storage$calls, list(call_entry))
  storage$metadata$call_count <- length(storage$calls)
  call_index <- storage$metadata$call_count

  key <- as.character(device_id)
  .maidr_base_r_session$devices[[key]] <- storage

  if (class_level == "HIGH") {
    on_high_level_call(device_id, call_index)
  } else if (class_level == "LAYOUT") {
    on_layout_call(device_id, function_name, args)
  }

  invisible(NULL)
}

#' Get Plot Calls from Device Storage
#'
#' Retrieves all plot calls for a specific device.
#'
#' @param device_id Graphics device ID
#' @return List of plot call entries
#' @keywords internal
get_device_calls <- function(device_id = grDevices::dev.cur()) {
  if (is.null(device_id) || is.na(device_id) || device_id <= 0) {
    return(list())
  }

  storage <- get_device_storage(device_id)
  calls <- storage$calls

  if (is.null(calls)) list() else calls
}

#' Clear Device Storage
#'
#' Clears all stored plot calls for a specific device.
#'
#' @param device_id Graphics device ID
#' @return NULL (invisible)
#' @keywords internal
clear_device_storage <- function(device_id = grDevices::dev.cur()) {
  if (is.null(device_id) || is.na(device_id) || device_id <= 0) {
    return(invisible(NULL))
  }

  key <- as.character(device_id)

  if (!is.null(.maidr_base_r_session$devices[[key]])) {
    .maidr_base_r_session$devices[[key]] <- NULL
    reset_device_state(device_id)
  }

  invisible(NULL)
}

#' Clear All Device Storage
#'
#' Clears storage for all devices.
#'
#' @return NULL (invisible)
#' @keywords internal
clear_all_device_storage <- function() {
  device_count <- length(.maidr_base_r_session$devices)

  if (device_count > 0) {
    .maidr_base_r_session$devices <- list()
  }

  invisible(NULL)
}

#' Check if Device Has Calls
#'
#' Checks whether a specific device has any recorded plot calls.
#'
#' @param device_id Graphics device ID
#' @return TRUE if device has calls, FALSE otherwise
#' @keywords internal
has_device_calls <- function(device_id = grDevices::dev.cur()) {
  if (is.null(device_id) || is.na(device_id) || device_id <= 0) {
    return(FALSE)
  }

  key <- as.character(device_id)

  if (is.null(.maidr_base_r_session$devices[[key]])) {
    return(FALSE)
  }

  length(.maidr_base_r_session$devices[[key]]$calls) > 0
}

#' Get Device Storage Summary
#'
#' Returns summary information about device storage (for debugging).
#'
#' @return List with device storage statistics
#' @keywords internal
get_device_storage_summary <- function() {
  devices <- .maidr_base_r_session$devices

  summary <- list(
    total_devices = length(devices),
    devices = list()
  )

  for (key in names(devices)) {
    device_info <- devices[[key]]
    summary$devices[[key]] <- list(
      device_id = device_info$device_id,
      call_count = length(device_info$calls),
      created = device_info$metadata$created
    )
  }

  summary
}

#' Filter Device Calls by Classification
#'
#' Retrieves plot calls of a specific classification level.
#'
#' @param device_id Graphics device ID
#' @param class_level Classification level: "HIGH", "LOW", "LAYOUT"
#' @return List of filtered plot call entries
#' @keywords internal
get_device_calls_by_class <- function(device_id = grDevices::dev.cur(),
                                       class_level = "HIGH") {
  all_calls <- get_device_calls(device_id)

  if (length(all_calls) == 0) {
    return(list())
  }

  Filter(function(call) {
    !is.null(call$class_level) && call$class_level == class_level
  }, all_calls)
}

#' Get HIGH-level Calls
#'
#' @param device_id Graphics device ID
#' @return List of HIGH-level plot calls
#' @keywords internal
get_high_level_calls <- function(device_id = grDevices::dev.cur()) {
  get_device_calls_by_class(device_id, "HIGH")
}

#' Get LOW-level Calls
#'
#' @param device_id Graphics device ID
#' @return List of LOW-level plot calls
#' @keywords internal
get_low_level_calls <- function(device_id = grDevices::dev.cur()) {
  get_device_calls_by_class(device_id, "LOW")
}

#' Get LAYOUT Calls
#'
#' @param device_id Graphics device ID
#' @return List of LAYOUT-level plot calls
#' @keywords internal
get_layout_calls <- function(device_id = grDevices::dev.cur()) {
  get_device_calls_by_class(device_id, "LAYOUT")
}

#' Set Internal Guard Flag
#'
#' Guards against recursive tracing by setting an internal flag.
#'
#' @param value TRUE to set guard, FALSE to clear
#' @return NULL (invisible)
#' @keywords internal
set_internal_guard <- function(value) {
  .maidr_base_r_session$internal_guard <- isTRUE(value)
  invisible(NULL)
}

#' Check Internal Guard Flag
#'
#' Checks if we're currently in internal code (to prevent recursive tracing).
#'
#' @return TRUE if internal guard is set, FALSE otherwise
#' @keywords internal
is_internal_call <- function() {
  isTRUE(.maidr_base_r_session$internal_guard)
}
