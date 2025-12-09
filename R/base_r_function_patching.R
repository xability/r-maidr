#' Base R Function Patching System
#'
#' This module provides function patching capabilities for Base R plotting functions.
#' It intercepts Base R plotting calls and records them for processing by the MAIDR system.
#'
#' @keywords internal

# Global variables for function patching (using environment)
.maidr_patching_env <- new.env(parent = .GlobalEnv)
.maidr_patching_env$.saved_graphics_fns <- list()

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
      device_id <- grDevices::dev.cur()

      # Log the call
      log_plot_call_to_device("lines", this_call, args, device_id)

      # Call the original lines function and let S3 dispatch handle it
      original_lines <- .maidr_patching_env$.saved_graphics_fns[["lines"]]
      result <- original_lines(x, ...)
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
      device_id <- grDevices::dev.cur()

      # Log the call
      log_plot_call_to_device("points", this_call, args, device_id)

      # Call the default method
      result <- graphics::points.default(x, ...)
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
