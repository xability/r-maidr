#' Base R Function Patching System
#'
#' This module provides function patching capabilities for Base R plotting functions.
#' It intercepts Base R plotting calls and records them for processing by the MAIDR system.
#'
#' @keywords internal

# Global variables for function patching (using environment)
.maidr_patching_env <- new.env(parent = .GlobalEnv)
.maidr_patching_env$.maidr_plot_calls <- list()
.maidr_patching_env$.saved_graphics_fns <- list()

# Functions to wrap (only major plot types)
fns_to_wrap <- c(
  "barplot",
  "plot", 
  "hist",
  "boxplot",
  "image",
  "contour",
  "matplot"
)

#' Initialize Base R function patching
#'
#' This function sets up the function patching system by wrapping Base R plotting functions.
#' It should be called before any Base R plotting commands.
#'
#' @return NULL (invisible)
#' @keywords internal
initialize_base_r_patching <- function() {
  # Clear any existing plot calls
  .maidr_patching_env$.maidr_plot_calls <- list()
  
  # Wrap all target functions
  lapply(fns_to_wrap, wrap_function)
  
  invisible(NULL)
}

#' Wrap a single function
#'
#' @param function_name Name of the function to wrap
#' @return TRUE if successful, FALSE otherwise
#' @keywords internal
wrap_function <- function(function_name) {
  # Find original function
  orig <- find_original_function(function_name)
  if (is.null(orig)) {
    message("Could not find function ", function_name, " to wrap.")
    return(FALSE)
  }

  # Store original if not already stored
  if (is.null(.maidr_patching_env$.saved_graphics_fns[[function_name]])) {
    .maidr_patching_env$.saved_graphics_fns[[function_name]] <- orig
  }

  # Create wrapper
  wrapper <- create_function_wrapper(function_name, orig)

  # Assign wrapper to global environment to shadow the original
  assign(function_name, wrapper, envir = .GlobalEnv)
  
  invisible(TRUE)
}

#' Find the original function in loaded namespaces
#'
#' @param function_name Name of the function to find
#' @return Original function or NULL if not found
#' @keywords internal
find_original_function <- function(function_name) {
  # Try global environment first
  if (exists(function_name, envir = .GlobalEnv, inherits = TRUE)) {
    return(get(function_name, mode = "function", inherits = TRUE))
  }
  
  # Try graphics namespace
  orig <- tryCatch(
    get(function_name, envir = asNamespace("graphics")), 
    error = function(e) NULL
  )
  if (!is.null(orig)) return(orig)
  
  # Try stats namespace
  orig <- tryCatch(
    get(function_name, envir = asNamespace("stats")), 
    error = function(e) NULL
  )
  if (!is.null(orig)) return(orig)
  
  # Try grDevices namespace
  orig <- tryCatch(
    get(function_name, envir = asNamespace("grDevices")), 
    error = function(e) NULL
  )
  if (!is.null(orig)) return(orig)
  
  return(NULL)
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
  
  # Create standard wrapper using eval and substitute to capture the function name and original
  wrapper <- eval(substitute(
    function(...) {
      # Capture the function call
      this_call <- match.call()
      
      # Log the call
      log_plot_call(FNAME, this_call, list(...))
      
      # Call original function
      ORIG(...)
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
    # Capture the function call
    this_call <- match.call()
    
    # Log the call
    log_plot_call("barplot", this_call, list(...))
    
    # Apply modular patching system
    args <- list(...)
    patched_args <- apply_barplot_patches(args)
    
    # Call original function with patched arguments
    do.call(original_function, patched_args)
  }
  
  wrapper
}

#' Apply modular patches to barplot arguments
#'
#' @param args List of arguments passed to barplot
#' @return Modified arguments with applied patches
#' @keywords internal
apply_barplot_patches <- function(args) {
  # Initialize patch manager if not already done
  if (!exists("global_patch_manager", envir = .GlobalEnv) || is.null(.GlobalEnv$global_patch_manager)) {
    .GlobalEnv$global_patch_manager <- PatchManager$new()
  }
  
  # Apply patches
  patch_manager <- .GlobalEnv$global_patch_manager
  return(patch_manager$apply_patches("barplot", args))
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
    
    # Sort x values (columns) to natural order for consistent category ordering
    sorted_x_values <- sort(colnames(height))
    
    # Reorder matrix according to sorted values
    reordered_height <- height[sorted_fill_values, sorted_x_values, drop = FALSE]
    
    # Update the first argument (height) with reordered matrix
    args[[1]] <- reordered_height
    
    # Update names.arg if it exists to match reordered columns
    if ("names.arg" %in% names(args)) {
      # Find the indices of the reordered columns in the original names.arg
      original_indices <- match(sorted_x_values, colnames(height))
      args$names.arg <- args$names.arg[original_indices]
    }
  }
  
  return(args)
}

#' Log a plot call
#'
#' @param function_name Name of the function called
#' @param call_expr The call expression
#' @param args List of arguments
#' @return NULL (invisible)
#' @keywords internal
log_plot_call <- function(function_name, call_expr, args) {
  # Create log entry
  log_entry <- list(
    function_name = function_name,
    call_expr = if (!is.null(call_expr)) deparse(call_expr) else NA,
    args = args,
    timestamp = Sys.time()
  )
  
  # Add to plot calls list in environment
  .maidr_patching_env$.maidr_plot_calls <- append(.maidr_patching_env$.maidr_plot_calls, list(log_entry))
  
  invisible(NULL)
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
#' @return List of recorded plot calls
#' @keywords internal
get_plot_calls <- function() {
  .maidr_patching_env$.maidr_plot_calls
}

#' Clear recorded plot calls
#'
#' @return NULL (invisible)
#' @keywords internal
clear_plot_calls <- function() {
  .maidr_patching_env$.maidr_plot_calls <- list()
  invisible(NULL)
}

#' Check if patching is active
#'
#' @return TRUE if patching is active, FALSE otherwise
#' @keywords internal
is_patching_active <- function() {
  length(.maidr_patching_env$.saved_graphics_fns) > 0
}
