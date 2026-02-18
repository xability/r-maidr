#' Base R Function Patching System
#'
#' This module provides function patching capabilities for Base R plotting functions.
#' It intercepts Base R plotting calls and records them for processing by the MAIDR system.
#'
#' @keywords internal

# Package-private environment for function patching state
# Uses emptyenv() as parent to avoid polluting the global environment
.maidr_patching_env <- new.env(parent = emptyenv())
.maidr_patching_env$.saved_graphics_fns <- list()
.maidr_patching_env$.temp_device_file <- NULL
.maidr_patching_env$.temp_device_id <- NULL
.maidr_patching_env$.patching_active <- FALSE

#' Check if Base R patching is currently active
#'
#' Wrappers are installed once during .onLoad and remain in the namespace.
#' This flag controls whether they record calls or act as pass-through.
#'
#' @return TRUE if patching is active
#' @keywords internal
is_patching_enabled <- function() {
  isTRUE(.maidr_patching_env$.patching_active)
}

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
#' Wrappers are installed once into the package namespace during .onLoad
#' (when the namespace is still open). Subsequent calls just activate the
#' patching flag; wrappers check this flag to decide whether to record calls
#' or simply pass through to the original function.
#'
#' @param include_low Include LOW-level functions (lines, points, etc.)
#' @param include_layout Include LAYOUT functions (par, layout, etc.)
#' @return NULL (invisible)
#' @keywords internal
initialize_base_r_patching <- function(include_low = TRUE, include_layout = TRUE) {
  # Only install wrappers if not already done (first call from .onLoad)
  if (length(.maidr_patching_env$.saved_graphics_fns) == 0) {
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
  }

  # Activate patching (wrappers will start recording calls)
  .maidr_patching_env$.patching_active <- TRUE

  invisible(NULL)
}

#' Wrap a single function
#'
#' This is only called during .onLoad when the namespace is still open.
#' The wrapper checks is_patching_enabled() at runtime to decide whether
#' to record calls or pass through.
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

  # Assign wrapper into the package namespace.
  # During .onLoad the namespace is not yet sealed, so assign() works directly.
  # After sealing (e.g., from tests or maidr_on()), the binding already exists
  # from .onLoad so we just skip the assignment silently.
  ns <- asNamespace("maidr")
  tryCatch(
    assign(function_name, wrapper, envir = ns),
    error = function(e) {
      # Namespace is sealed — wrapper was already installed during .onLoad
      NULL
    }
  )

  invisible(TRUE)
}

#' Wrap S3 generic functions (lines and points)
#'
#' Special handling for S3 generics that can't be traced normally.
#' Only called once during .onLoad when namespace is still open.
#' @keywords internal
wrap_s3_generics <- function() {
  ns <- asNamespace("maidr")

  # Wrap lines() function
  if (is.null(.maidr_patching_env$.saved_graphics_fns[["lines"]])) {
    .maidr_patching_env$.saved_graphics_fns[["lines"]] <- graphics::lines
  }

  lines_wrapper <- function(x, ...) {
    # If patching is disabled, pass through to original
    if (!is_patching_enabled()) {
      original_lines <- .maidr_patching_env$.saved_graphics_fns[["lines"]]
      return(original_lines(x, ...))
    }

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

  tryCatch(
    assign("lines", lines_wrapper, envir = ns),
    error = function(e) NULL  # Already installed during .onLoad
  )

  # Wrap points() function
  if (is.null(.maidr_patching_env$.saved_graphics_fns[["points"]])) {
    .maidr_patching_env$.saved_graphics_fns[["points"]] <- graphics::points
  }

  points_wrapper <- function(x, ...) {
    # If patching is disabled, pass through to original
    if (!is_patching_enabled()) {
      return(graphics::points.default(x, ...))
    }

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

  tryCatch(
    assign("points", points_wrapper, envir = ns),
    error = function(e) NULL  # Already installed during .onLoad
  )

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

  # Special handling for axis to capture scales:: format config
  if (function_name == "axis") {
    return(create_axis_wrapper(original_function))
  }

  wrapper <- eval(substitute(
    function(...) {
      # If patching is disabled, pass through to original function
      if (!is_patching_enabled()) {
        return(ORIG(...))
      }

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
    # If patching is disabled, pass through to original function
    if (!is_patching_enabled()) {
      return(original_function(...))
    }

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

#' Create enhanced wrapper for axis to capture scales:: format config
#'
#' This wrapper intercepts axis() calls and checks if the labels argument
#' is a scales:: label function (closure). If so, it extracts the format
#' configuration before applying the function to get the actual labels.
#'
#' @param original_function Original axis function
#' @return Enhanced wrapped function
#' @keywords internal
create_axis_wrapper <- function(original_function) {
  wrapper <- function(side, at = NULL, labels = TRUE, ...) {
    # If patching is disabled, pass through to original function
    if (!is_patching_enabled()) {
      return(original_function(side, at = at, labels = labels, ...))
    }

    this_call <- match.call()

    # Check if labels is a function (scales:: label function)
    format_config <- NULL
    actual_labels <- labels

    if (is.function(labels)) {
      # Extract format config from scales:: closure
      format_config <- extract_from_scales_closure(labels)

      # Apply the function to get actual string labels
      if (!is.null(at)) {
        actual_labels <- labels(at)
      } else {
        # If no 'at' provided, let axis() handle it with TRUE
        actual_labels <- TRUE
      }
    }

    # Build args for logging - use actual_labels (resolved strings) for replay
    # This ensures grob generation works correctly when replaying axis() calls
    args <- list(side = side, at = at, labels = actual_labels, ...)

    # Store format config in the args for later extraction
    if (!is.null(format_config)) {
      args$.maidr_format_config <- format_config
      args$.maidr_axis_side <- side  # 1=bottom, 2=left, 3=top, 4=right
    }

    # Ensure a device is open to suppress default graphics window
    ensure_maidr_device()

    # Call original axis with actual labels (strings, not function)
    result <- original_function(side, at = at, labels = actual_labels, ...)

    device_id <- grDevices::dev.cur()
    log_plot_call_to_device("axis", this_call, args, device_id)

    invisible(result)
  }

  wrapper
}

#' Clean MAIDR internal arguments from args list
#'
#' Removes internal arguments (starting with .maidr_) from an args list
#' before passing to original functions during replay.
#'
#' @param args List of arguments
#' @return Cleaned args list without .maidr_* entries
#' @keywords internal
clean_maidr_args <- function(args) {
  if (is.null(args) || length(args) == 0) {
    return(args)
  }

  # Remove args that start with .maidr_
  maidr_args <- grepl("^\\.maidr_", names(args))
  if (any(maidr_args)) {
    args <- args[!maidr_args]
  }

  args
}

#' Apply modular patches to barplot arguments
#'
#' @param args List of arguments passed to barplot
#' @return Modified arguments with applied patches
#' @keywords internal
apply_barplot_patches <- function(args) {
  # Store patch manager in package-private environment (not .GlobalEnv)
  if (is.null(.maidr_patching_env$patch_manager)) {
    .maidr_patching_env$patch_manager <- PatchManager$new()
  }

  patch_manager <- .maidr_patching_env$patch_manager
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
#' Deactivates patching by flipping the active flag. Wrappers remain in the
#' namespace but act as pass-through (calling the original function directly).
#' This avoids modifying the locked namespace or the search path.
#'
#' @return NULL (invisible)
#' @keywords internal
restore_original_functions <- function() {
  # Deactivate patching — wrappers will pass through to originals

  .maidr_patching_env$.patching_active <- FALSE

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
  isTRUE(.maidr_patching_env$.patching_active)
}
