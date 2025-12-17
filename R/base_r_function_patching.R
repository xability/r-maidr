#' Base R Function Patching System
#'
#' This module provides function patching capabilities for Base R plotting functions.
#' It intercepts Base R plotting calls and records them for processing by the MAIDR system.
#'
#' @keywords internal

# Global variables for function patching (using environment)
.maidr_patching_env <- new.env(parent = .GlobalEnv)
.maidr_patching_env$.saved_graphics_fns <- list()
.maidr_patching_env$.temp_device_file <- NULL
.maidr_patching_env$.temp_device_id <- NULL

#' Open a temporary device to suppress default graphics window
#'
#' Called by wrappers when no device is open to prevent R from
#' opening the default interactive graphics device.
#'
#' @return The device ID of the temp device
#' @keywords internal
open_maidr_temp_device <- function() {
  # Only open if we haven't already
  if (!is.null(.maidr_patching_env$.temp_device_id)) {
    current_dev <- grDevices::dev.cur()
    if (current_dev == .maidr_patching_env$.temp_device_id) {
      return(.maidr_patching_env$.temp_device_id)
    }
  }

  temp_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(temp_file, width = 7, height = 7)
  device_id <- grDevices::dev.cur()

  .maidr_patching_env$.temp_device_file <- temp_file
  .maidr_patching_env$.temp_device_id <- device_id

  device_id
}

#' Check if the current device is the MAIDR temp device
#'
#' @return TRUE if current device is the temp device
#' @keywords internal
is_maidr_temp_device <- function() {
  current_dev <- grDevices::dev.cur()
  !is.null(.maidr_patching_env$.temp_device_id) &&
    current_dev == .maidr_patching_env$.temp_device_id
}

#' Close and clean up the MAIDR temp device
#'
#' @return NULL (invisible)
#' @keywords internal
close_maidr_temp_device <- function() {
  if (!is.null(.maidr_patching_env$.temp_device_id)) {
    tryCatch(
      {
        if (.maidr_patching_env$.temp_device_id %in% grDevices::dev.list()) {
          grDevices::dev.off(.maidr_patching_env$.temp_device_id)
        }
      },
      error = function(e) NULL
    )
  }

  if (!is.null(.maidr_patching_env$.temp_device_file)) {
    tryCatch(
      unlink(.maidr_patching_env$.temp_device_file),
      error = function(e) NULL
    )
  }

  .maidr_patching_env$.temp_device_file <- NULL
  .maidr_patching_env$.temp_device_id <- NULL

  invisible(NULL)
}

#' Ensure a device is open before plotting (suppress default window)
#'
#' @return The current device ID after ensuring one is open
#' @keywords internal
ensure_maidr_device <- function() {
  if (grDevices::dev.cur() == 1) {
    # No device open - create temp PDF to prevent default window
    open_maidr_temp_device()
  }
  grDevices::dev.cur()
}

#' Replay Base R plot to native graphics device
#'
#' For unsupported plots, close the temp device and replay
#' the plot calls to the native graphics device.
#'
#' @param device_id The device ID to get plot calls from
#' @return NULL (invisible)
#' @keywords internal
replay_to_native_device <- function(device_id = grDevices::dev.cur()) {
  # Get the grouped plot calls before closing
  grouped <- group_device_calls(device_id)
  plot_groups <- grouped$groups

  # Close the temp device
  close_maidr_temp_device()

  # Open native graphics device
  grDevices::dev.new()

  # Replay all plot groups using ORIGINAL functions (not wrapped)
  for (group in plot_groups) {
    # Replay HIGH-level call with original function
    high_call <- group$high_call
    orig_fn <- get_original_function(high_call$function_name)
    do.call(orig_fn, high_call$args)

    # Replay LOW-level calls with original functions
    if (length(group$low_calls) > 0) {
      for (low_call in group$low_calls) {
        orig_low_fn <- get_original_function(low_call$function_name)
        do.call(orig_low_fn, low_call$args)
      }
    }
  }

  invisible(NULL)
}

#' Get original (unwrapped) function by name
#'
#' @param function_name Name of the function
#' @return The original function
#' @keywords internal
get_original_function <- function(function_name) {
  # First check saved original functions
  orig_fn <- .maidr_patching_env$.saved_graphics_fns[[function_name]]
  if (!is.null(orig_fn)) {
    return(orig_fn)
  }

  # Fall back to graphics namespace
  orig_fn <- tryCatch(
    get(function_name, envir = asNamespace("graphics")),
    error = function(e) NULL
  )
  if (!is.null(orig_fn)) {
    return(orig_fn)
  }

  # Try base namespace
  tryCatch(
    get(function_name, envir = asNamespace("base")),
    error = function(e) get(function_name)
  )
}

#' Initialize Base R function patching
#'
#' This function sets up the function patching system by wrapping Base R
#' plotting functions (HIGH, LOW, and LAYOUT levels).
#' It should be called before any Base R plotting commands.
#'
#' @param include_low Include LOW-level functions (lines, points, etc.)
#' @param include_layout Include LAYOUT functions (par, layout, etc.)
#' @return NULL (invisible)
#' @keywords internal
initialize_base_r_patching <- function(include_low = TRUE, include_layout = TRUE) {
  fns_to_wrap <- get_functions_by_class("HIGH")

  if (include_low) {
    fns_to_wrap <- c(fns_to_wrap, get_functions_by_class("LOW"))
  }

  if (include_layout) {
    fns_to_wrap <- c(fns_to_wrap, get_functions_by_class("LAYOUT"))
  }

  lapply(fns_to_wrap, wrap_function)

  # Special handling for S3 generics (lines, points)
  wrap_s3_generics()

  invisible(NULL)
}

#' Wrap a single function
#'
#' @param function_name Name of the function to wrap
#' @return TRUE if successful, FALSE otherwise
#' @keywords internal
wrap_function <- function(function_name) {
  orig <- find_original_function(function_name)
  if (is.null(orig)) {
    return(FALSE)
  }

  if (is.null(.maidr_patching_env$.saved_graphics_fns[[function_name]])) {
    .maidr_patching_env$.saved_graphics_fns[[function_name]] <- orig
  }

  wrapper <- create_function_wrapper(function_name, orig)

  # Assign wrapper to global environment to shadow the original
  assign(function_name, wrapper, envir = .GlobalEnv)

  invisible(TRUE)
}

#' Wrap S3 generic functions (lines and points)
#'
#' Special handling for S3 generics that can't be traced normally
#' @keywords internal
wrap_s3_generics <- function() {
  # Wrap lines() function
  needs_wrapping <- TRUE
  if (exists("lines", where = .GlobalEnv)) {
    lines_fn <- get("lines", envir = .GlobalEnv)
    fn_body <- body(lines_fn)
    if (is.call(fn_body) && length(fn_body) > 1) {
      body_text <- deparse(fn_body)
      if (any(grepl("log_plot_call_to_device", body_text))) {
        needs_wrapping <- FALSE
      }
    }
  }

  if (needs_wrapping) {
    if (is.null(.maidr_patching_env$.saved_graphics_fns[["lines"]])) {
      .maidr_patching_env$.saved_graphics_fns[["lines"]] <- graphics::lines
    }

    lines_wrapper <- function(x, ...) {
      # Prepare for logging
      this_call <- match.call()
      args <- list(x, ...)

      # Ensure a device is open to suppress default graphics window
      ensure_maidr_device()

      # Call the original lines function and let S3 dispatch handle it
      original_lines <- .maidr_patching_env$.saved_graphics_fns[["lines"]]
      result <- original_lines(x, ...)

      device_id <- grDevices::dev.cur()
      # Log the call
      log_plot_call_to_device("lines", this_call, args, device_id)

      invisible(result)
    }

    # Assign to global environment
    assign("lines", lines_wrapper, envir = .GlobalEnv)
  }

  # Wrap points() function
  needs_wrapping_points <- TRUE
  if (exists("points", where = .GlobalEnv)) {
    points_fn <- get("points", envir = .GlobalEnv)
    fn_body <- body(points_fn)
    if (is.call(fn_body) && length(fn_body) > 1) {
      body_text <- deparse(fn_body)
      if (any(grepl("log_plot_call_to_device", body_text))) {
        needs_wrapping_points <- FALSE
      }
    }
  }

  if (needs_wrapping_points) {
    if (is.null(.maidr_patching_env$.saved_graphics_fns[["points"]])) {
      .maidr_patching_env$.saved_graphics_fns[["points"]] <- graphics::points
    }

    points_wrapper <- function(x, ...) {
      # Prepare for logging
      this_call <- match.call()
      args <- list(x, ...)

      # Ensure a device is open to suppress default graphics window
      ensure_maidr_device()

      # Call the default method
      result <- graphics::points.default(x, ...)

      device_id <- grDevices::dev.cur()
      # Log the call
      log_plot_call_to_device("points", this_call, args, device_id)

      invisible(result)
    }

    # Assign to global environment
    assign("points", points_wrapper, envir = .GlobalEnv)
  }

  invisible(TRUE)
}

#' Find the original function in loaded namespaces
#'
#' @param function_name Name of the function to find
#' @return Original function or NULL if not found
#' @keywords internal
find_original_function <- function(function_name) {
  # FIRST: Check if we already have the original saved (prevents double-wrapping)
  if (!is.null(.maidr_patching_env$.saved_graphics_fns[[function_name]])) {
    return(.maidr_patching_env$.saved_graphics_fns[[function_name]])
  }

  # Try graphics namespace
  orig <- tryCatch(
    get(function_name, envir = asNamespace("graphics")),
    error = function(e) NULL
  )
  if (!is.null(orig)) {
    return(orig)
  }

  # Try stats namespace
  orig <- tryCatch(
    get(function_name, envir = asNamespace("stats")),
    error = function(e) NULL
  )
  if (!is.null(orig)) {
    return(orig)
  }

  # Try grDevices namespace
  orig <- tryCatch(
    get(function_name, envir = asNamespace("grDevices")),
    error = function(e) NULL
  )
  if (!is.null(orig)) {
    return(orig)
  }

  NULL
}

#' Create a function wrapper
#'
#' @param function_name Name of the function
#' @param original_function Original function to wrap
#' @return Wrapped function
#' @keywords internal
create_function_wrapper <- function(function_name, original_function) {
  # Special handling for barplot to include sorting logic
  if (function_name == "barplot") {
    return(create_barplot_wrapper(original_function))
  }

  wrapper <- eval(substitute(
    function(...) {
      this_call <- match.call()
      args_list <- list(...)

      # Ensure a device is open to suppress default graphics window
      ensure_maidr_device()

      result <- ORIG(...)

      device_id <- grDevices::dev.cur()
      log_plot_call_to_device(FNAME, this_call, args_list, device_id)

      # Return invisibly to prevent auto-printing in knitr
      # Users can still capture the result with assignment
      invisible(result)
    },
    list(FNAME = function_name, ORIG = original_function)
  ))

  wrapper
}

#' Create enhanced wrapper for barplot with sorting logic
#'
#' @param original_function Original barplot function
#' @return Enhanced wrapped function
#' @keywords internal
create_barplot_wrapper <- function(original_function) {
  wrapper <- function(...) {
    this_call <- match.call()
    args <- list(...)

    patched_args <- apply_barplot_patches(args)

    # Ensure a device is open to suppress default graphics window
    ensure_maidr_device()

    result <- do.call(original_function, patched_args)

    device_id <- grDevices::dev.cur()
    log_plot_call_to_device("barplot", this_call, args, device_id)

    # Return invisibly to prevent auto-printing in knitr
    invisible(result)
  }

  wrapper
}

#' Apply modular patches to barplot arguments
#'
#' @param args List of arguments passed to barplot
#' @return Modified arguments with applied patches
#' @keywords internal
apply_barplot_patches <- function(args) {
  if (
    !exists("global_patch_manager", envir = .GlobalEnv) || is.null(.GlobalEnv$global_patch_manager)
  ) {
    .GlobalEnv$global_patch_manager <- PatchManager$new()
  }

  patch_manager <- .GlobalEnv$global_patch_manager
  patch_manager$apply_patches("barplot", args)
}

#' Apply sorting logic to barplot arguments for consistent visual ordering
#'
#' @param args List of arguments passed to barplot
#' @return Modified arguments with sorted matrix data
#' @keywords internal
apply_barplot_sorting <- function(args) {
  height <- args[[1]]

  # Only apply sorting if height is a matrix with row/column names (dodged bars)
  if (is.matrix(height) && !is.null(rownames(height)) && !is.null(colnames(height))) {
    # Sort fill values (rows) to A,B,C order for consistent visual ordering
    sorted_fill_values <- sort(rownames(height))

    sorted_x_values <- sort(colnames(height))

    # Reorder matrix according to sorted values
    reordered_height <- height[sorted_fill_values, sorted_x_values, drop = FALSE]

    args[[1]] <- reordered_height

    if ("names.arg" %in% names(args)) {
      original_indices <- match(sorted_x_values, colnames(height))
      args$names.arg <- args$names.arg[original_indices]
    }
  }

  args
}


#' Restore original functions
#'
#' This function restores the original Base R plotting functions.
#' It should be called when patching is no longer needed.
#'
#' @return NULL (invisible)
#' @keywords internal
restore_original_functions <- function() {
  for (function_name in names(.maidr_patching_env$.saved_graphics_fns)) {
    original_function <- .maidr_patching_env$.saved_graphics_fns[[function_name]]
    assign(function_name, original_function, envir = .GlobalEnv)
  }

  # Clear saved functions
  .maidr_patching_env$.saved_graphics_fns <- list()

  invisible(NULL)
}

#' Get recorded plot calls
#'
#' @param device_id Graphics device ID (defaults to current device)
#' @return List of recorded plot calls
#' @keywords internal
get_plot_calls <- function(device_id = grDevices::dev.cur()) {
  get_device_calls(device_id)
}

#' Clear recorded plot calls
#'
#' @param device_id Graphics device ID (defaults to current device)
#' @return NULL (invisible)
#' @keywords internal
clear_plot_calls <- function(device_id = grDevices::dev.cur()) {
  clear_device_storage(device_id)
  invisible(NULL)
}

#' Check if patching is active
#'
#' @return TRUE if patching is active, FALSE otherwise
#' @keywords internal
is_patching_active <- function() {
  length(.maidr_patching_env$.saved_graphics_fns) > 0
}
