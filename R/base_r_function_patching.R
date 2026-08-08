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
.maidr_patching_env$.auto_show_callback_id <- NULL

#' Schedule auto-show after the current top-level expression completes
#'
#' Uses R's task callback mechanism. When a HIGH-level plot function is called,
#' this schedules `show()` to run after the expression finishes. If another
#' HIGH-level function is called in the same expression, the previous callback
#' is replaced (only one auto-show fires per expression).
#'
#' @keywords internal
schedule_auto_show <- function() {
  # Cancel any existing callback
  cancel_auto_show()

  # Register a one-shot task callback
  callback_id <- addTaskCallback(function(expr, value, ok, visible) {
    .maidr_patching_env$.auto_show_callback_id <- NULL
    tryCatch(
      maidr::show(plot = NULL),
      error = function(e) {
        # Silently ignore errors (e.g., if device was already closed)
        NULL
      }
    )
    # Return FALSE to remove the callback after it fires once
    FALSE
  }, name = "maidr_auto_show")

  .maidr_patching_env$.auto_show_callback_id <- callback_id

  invisible(NULL)
}

#' Cancel a pending auto-show callback
#'
#' Removes by NAME rather than by the index `addTaskCallback()` returned:
#' that index is a position in R's callback list, and any other package
#' adding or removing a callback in the meantime shifts it. Removing a
#' stale index silently deletes an unrelated package's callback.
#'
#' @keywords internal
cancel_auto_show <- function() {
  if (!is.null(.maidr_patching_env$.auto_show_callback_id)) {
    tryCatch(
      removeTaskCallback("maidr_auto_show"),
      error = function(e) NULL
    )
    .maidr_patching_env$.auto_show_callback_id <- NULL
  }
  invisible(NULL)
}

#' Check if Base R patching is currently active
#'
#' Wrappers are installed once during .onLoad and remain in the namespace.
#' This flag controls whether they record calls or act as pass-through.
#'
#' @return TRUE if patching is active
#' @keywords internal
is_patching_enabled <- function() {
  isTRUE(.maidr_patching_env$.patching_active) && is_base_r_enabled()
}

#' Open a temporary device to suppress default graphics window
#'
#' Called by wrappers when no device is open to prevent R from
#' opening the default interactive graphics device.
#'
#' @return The device ID of the temp device
#' @keywords internal
open_maidr_temp_device <- function() {
  existing_id <- .maidr_patching_env$.temp_device_id
  if (!is.null(existing_id)) {
    open_devices <- grDevices::dev.list()
    if (existing_id %in% open_devices) {
      # Reuse the existing temp device instead of opening a duplicate
      if (grDevices::dev.cur() != existing_id) {
        grDevices::dev.set(existing_id)
      }
      return(existing_id)
    }
    # The tracked device was closed externally (e.g. dev.off()); its ID may
    # be recycled by an unrelated device later, so drop the stale tracking
    # and clean up the leaked temp file before opening a fresh device.
    if (!is.null(.maidr_patching_env$.temp_device_file)) {
      tryCatch(
        unlink(.maidr_patching_env$.temp_device_file),
        error = function(e) NULL
      )
    }
    .maidr_patching_env$.temp_device_file <- NULL
    .maidr_patching_env$.temp_device_id <- NULL
  }

  temp_file <- tempfile(fileext = ".pdf")
  # Match the gridSVG export device size (R/svg_utils.R) so that grobs
  # drawn here are not resampled into a different aspect ratio. A
  # mismatch causes chartSeries title/date bracket to be clipped and
  # x-axis tick labels (month/year) to overlap on export.
  grDevices::pdf(temp_file, width = 7, height = 5)
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
        open_devices <- grDevices::dev.list()
        temp_id <- .maidr_patching_env$.temp_device_id
        if (temp_id %in% open_devices) {
          # Only close the device if it is still a pdf device: after an
          # external dev.off() the ID can be recycled by a user device,
          # which we must not close.
          device_name <- names(open_devices)[match(temp_id, open_devices)]
          if (identical(device_name, "pdf")) {
            grDevices::dev.off(temp_id)
          }
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
  # Get all recorded calls (HIGH, LOW, and LAYOUT) before closing
  all_calls <- get_device_calls(device_id)

  # Close the temp device
  close_maidr_temp_device()

  # Open native graphics device
  grDevices::dev.new()

  # Replay every call in its original order using ORIGINAL functions
  # (not wrapped). Replaying in order preserves interleaved LAYOUT calls
  # (par(mfrow=...), layout(...)) so multi-panel plots reproduce correctly.
  for (call_entry in all_calls) {
    replay_plot_call(
      call_entry$function_name,
      call_entry$args,
      call_entry$call_env
    )
  }

  invisible(NULL)
}

#' Replay a recorded plot call with the original (unwrapped) function
#'
#' Strips maidr-internal arguments and re-executes the call. When the
#' recorded args contain unevaluated expressions (from non-standard
#' evaluation, e.g. `curve(sin(x))` or `plot(y ~ x, subset = g == 1)`),
#' the call is rebuilt and evaluated in the environment captured at record
#' time so those expressions resolve exactly as they did originally.
#'
#' @param function_name Name of the recorded function
#' @param args Recorded argument list (values and/or expressions)
#' @param call_env Environment captured when NSE arguments could not be
#'   forced at record time, or NULL when all args are plain values
#' @return The result of the replayed call (invisibly)
#' @keywords internal
replay_plot_call <- function(function_name, args, call_env = NULL) {
  orig_fn <- get_original_function(function_name)
  args <- clean_maidr_args(args)

  has_language_args <- any(vapply(args, is.language, logical(1)))
  if (has_language_args && !is.null(call_env) && is.environment(call_env)) {
    replay_call <- as.call(c(list(orig_fn), args))
    return(invisible(eval(replay_call, envir = call_env)))
  }

  invisible(do.call(orig_fn, args))
}

#' Find the environment a name is bound in
#'
#' Walks the enclosing chain from \code{env} the way R's own lookup does,
#' stopping once the global environment has been checked: names that resolve
#' beyond it live in attached packages, which no plotting loop rebinds.
#'
#' @param name Name to look up
#' @param env Environment to start from
#' @return The environment holding \code{name}, or NULL when unbound
#' @keywords internal
locate_binding_env <- function(name, env) {
  while (!identical(env, emptyenv())) {
    if (exists(name, envir = env, inherits = FALSE)) {
      return(env)
    }
    if (identical(env, globalenv())) {
      return(NULL)
    }
    env <- parent.env(env)
  }
  NULL
}

#' Snapshot the bindings a recorded NSE call will need at replay time
#'
#' Recorded expressions are re-evaluated when the figure is rendered, long
#' after the caller has moved on -- and R reuses ONE frame for every
#' iteration of a `for` loop. Storing that frame therefore makes every
#' iteration replay with the LAST iteration's values:
#'
#' \preformatted{
#' par(mfrow = c(1, 2))
#' for (g in c("a", "b")) plot(y ~ x, data = d, subset = grp == g)
#' }
#'
#' Both panels drew `grp == "b"`, silently and without an error. Copying the
#' whole frame would fix that but brings its own problems (large objects,
#' active bindings, unforced promises, frames that are shared and mutated),
#' so only the names the recorded expressions actually mention are copied,
#' into a CHILD of the caller's frame. Everything else -- including anything
#' reached through the enclosing scopes -- still resolves exactly as before,
#' and the copies are references, so R's copy-on-write keeps them free.
#'
#' Active bindings are deliberately left behind: reading one is a side
#' effect, and re-reading it at replay time is the whole point of declaring
#' it active. Names that cannot be read are skipped for the same reason --
#' the fall-through to the caller's frame preserves today's behaviour.
#'
#' @param args Recorded argument list holding the unevaluated expressions
#' @param caller_env The frame the recorded call was made from
#' @return An environment whose parent is \code{caller_env}
#' @keywords internal
snapshot_call_env <- function(args, caller_env) {
  snapshot <- new.env(parent = caller_env)

  referenced <- unique(unlist(lapply(args, all.vars), use.names = FALSE))
  referenced <- setdiff(referenced, "...")

  for (name in referenced) {
    source_env <- locate_binding_env(name, caller_env)
    if (is.null(source_env)) {
      next
    }
    if (bindingIsActive(name, source_env)) {
      next
    }
    captured <- tryCatch(
      list(get(name, envir = source_env, inherits = FALSE)),
      error = function(e) NULL
    )
    if (is.null(captured)) {
      next
    }
    assign(name, captured[[1L]], envir = snapshot)
  }

  snapshot
}

#' Evaluate an expression, muffling the retry's promise-restart warning
#'
#' When a call fails part-way through forcing an argument, that argument's
#' promise is left interrupted. Forcing it again — which both the retry and
#' the argument recording do — makes R warn "restarting interrupted promise
#' evaluation". It is an artifact of retrying, not anything the user's call
#' did, so it is muffled; every other warning passes through untouched.
#'
#' @param expr Expression to evaluate (lazily, inside the handler)
#' @return The value of `expr`
#' @keywords internal
muffle_promise_restart <- function(expr) {
  withCallingHandlers(
    expr,
    warning = function(w) {
      if (grepl("interrupted promise evaluation", conditionMessage(w))) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

#' Retry a failed plot call from the caller's own frame
#'
#' The formula methods resolve non-standard arguments relative to
#' `parent.frame()`: `plot.formula()` evaluates `subset =` there, and
#' `boxplot.formula()` reaches into the caller's `...`. A wrapper puts its
#' own frame in that position, so calls that work in plain R fail through
#' maidr:
#'
#' \preformatted{
#' plot(y ~ x, data = d, subset = g == 1)   # object 'g' not found
#' boxplot(y ~ g, data = d, subset = x > 5) # ..3 used in an incorrect context
#' }
#'
#' Rebuilding the call and evaluating it in the caller's frame gives those
#' methods the frame they expect. This runs only after the direct call has
#' already failed, so working calls keep the single-evaluation fast path and
#' a genuinely invalid call still reports its original error.
#'
#' Known trade-off: on this retry path an argument can be evaluated more
#' than once. The failed first attempt already forced some promises, the
#' rebuilt call evaluates the argument expressions afresh, and the argument
#' recording that follows forces the interrupted promise again. An argument
#' carrying a side effect therefore runs it more than once here. The
#' alternative is the pre-existing behaviour, where the whole call simply
#' errored, so the retry is the better trade -- but it is a trade.
#'
#' @param original_function The unwrapped plotting function
#' @param recorded_call `match.call()` captured by the wrapper
#' @param caller_env The wrapper's calling frame
#' @param original_error The error condition the direct call raised
#' @return Result of the retried call
#' @keywords internal
retry_call_in_caller_frame <- function(original_function,
                                       recorded_call,
                                       caller_env,
                                       original_error) {
  rebuilt_call <- as.call(
    c(list(original_function), as.list(recorded_call)[-1L])
  )

  tryCatch(
    muffle_promise_restart(eval(rebuilt_call, caller_env)),
    # The retry is a fallback, not a diagnosis: if it fails too, report the
    # error the user's actual call produced.
    error = function(e) stop(original_error)
  )
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

  # Try stats namespace (heatmap lives here)
  orig_fn <- tryCatch(
    get(function_name, envir = asNamespace("stats")),
    error = function(e) NULL
  )
  if (!is.null(orig_fn)) {
    return(orig_fn)
  }

  # Try quantmod namespace (chartSeries) when loaded. This must come
  # before the generic get() fallback, which would otherwise resolve to
  # maidr's own recording wrapper and re-log calls during replay.
  if ("quantmod" %in% loadedNamespaces()) {
    orig_fn <- tryCatch(
      get(function_name, envir = asNamespace("quantmod")),
      error = function(e) NULL
    )
    if (!is.null(orig_fn)) {
      return(orig_fn)
    }
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
  fns_to_wrap <- get_functions_by_class("HIGH")

  if (include_low) {
    fns_to_wrap <- c(fns_to_wrap, get_functions_by_class("LOW"))
  }

  if (include_layout) {
    fns_to_wrap <- c(fns_to_wrap, get_functions_by_class("LAYOUT"))
  }

  # Wrap each function. wrap_function() is idempotent: if the original
  # has already been saved, find_original_function() returns it and we
  # simply re-install the wrapper (no-op for sealed namespaces).
  # Functions whose original is not yet available (e.g. chartSeries when
  # quantmod has not been attached) silently skip and may be wrapped on
  # a later call (e.g. via a packageEvent hook for quantmod).
  lapply(fns_to_wrap, wrap_function)

  # Special handling for S3 generics (lines, points) — only the first
  # call actually installs them (gated on .saved_graphics_fns).
  if (is.null(.maidr_patching_env$.saved_graphics_fns[["lines"]]) ||
      is.null(.maidr_patching_env$.saved_graphics_fns[["points"]])) {
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

  # Also update the package environment on the search path (if attached).
  # This ensures library(maidr) users get the wrapper, not the stub export.
  pkg_env_name <- "package:maidr"
  if (pkg_env_name %in% search()) {
    pkg_env <- as.environment(pkg_env_name)
    tryCatch(
      assign(function_name, wrapper, envir = pkg_env),
      error = function(e) NULL
    )
  }

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
    caller_env <- parent.frame()

    # Ensure a device is open to suppress default graphics window
    ensure_maidr_device()

    # Call the original lines function and let S3 dispatch handle it
    original_lines <- .maidr_patching_env$.saved_graphics_fns[["lines"]]
    result <- original_lines(x, ...)

    # Force args only after the original call succeeded (NSE safety)
    args <- tryCatch(list(x, ...), error = function(e) NULL)
    call_env <- NULL
    if (is.null(args)) {
      args <- as.list(this_call)[-1L]
      call_env <- snapshot_call_env(args, caller_env)
    }

    device_id <- grDevices::dev.cur()
    # Log the call
    log_plot_call_to_device("lines", this_call, args, device_id, call_env = call_env)

    invisible(result)
  }

  tryCatch(
    assign("lines", lines_wrapper, envir = ns),
    error = function(e) NULL  # Already installed during .onLoad
  )

  # Also update the package environment on the search path (if attached)
  pkg_env_name <- "package:maidr"
  if (pkg_env_name %in% search()) {
    pkg_env <- as.environment(pkg_env_name)
    tryCatch(
      assign("lines", lines_wrapper, envir = pkg_env),
      error = function(e) NULL
    )
  }

  # Wrap points() function
  if (is.null(.maidr_patching_env$.saved_graphics_fns[["points"]])) {
    .maidr_patching_env$.saved_graphics_fns[["points"]] <- graphics::points
  }

  points_wrapper <- function(x, ...) {
    # If patching is disabled, pass through to original
    if (!is_patching_enabled()) {
      original_points <- .maidr_patching_env$.saved_graphics_fns[["points"]]
      return(original_points(x, ...))
    }

    # Prepare for logging
    this_call <- match.call()
    caller_env <- parent.frame()

    # Ensure a device is open to suppress default graphics window
    ensure_maidr_device()

    # Call the original generic so S3 dispatch works
    # (e.g. points(y ~ x), points(density_obj))
    original_points <- .maidr_patching_env$.saved_graphics_fns[["points"]]
    result <- original_points(x, ...)

    # Force args only after the original call succeeded (NSE safety)
    args <- tryCatch(list(x, ...), error = function(e) NULL)
    call_env <- NULL
    if (is.null(args)) {
      args <- as.list(this_call)[-1L]
      call_env <- snapshot_call_env(args, caller_env)
    }

    device_id <- grDevices::dev.cur()
    # Log the call
    log_plot_call_to_device("points", this_call, args, device_id, call_env = call_env)

    invisible(result)
  }

  tryCatch(
    assign("points", points_wrapper, envir = ns),
    error = function(e) NULL  # Already installed during .onLoad
  )

  # Also update the package environment on the search path (if attached)
  if (pkg_env_name %in% search()) {
    pkg_env <- as.environment(pkg_env_name)
    tryCatch(
      assign("points", points_wrapper, envir = pkg_env),
      error = function(e) NULL
    )
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

  # Try quantmod namespace (only if quantmod is loaded). chartSeries
  # is the only HIGH function we currently expect from quantmod.
  if ("quantmod" %in% loadedNamespaces()) {
    orig <- tryCatch(
      get(function_name, envir = asNamespace("quantmod")),
      error = function(e) NULL
    )
    if (!is.null(orig)) {
      return(orig)
    }
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

  # Functions whose primary argument is an unevaluated expression must
  # never have their arguments forced: curve(sin(x)) evaluates `sin(x)`
  # lazily with `x` bound inside curve(), so forcing either errors or
  # (worse) silently captures an unrelated `x` from the caller.
  if (function_name %in% c("curve")) {
    return(create_nse_wrapper(function_name, original_function))
  }

  is_high <- is_high_level_function(function_name)

  wrapper <- eval(substitute(
    function(...) {
      # If patching is disabled, pass through to original function
      if (!is_patching_enabled()) {
        return(ORIG(...))
      }

      this_call <- match.call()
      caller_env <- parent.frame()

      # Ensure a device is open to suppress default graphics window
      ensure_maidr_device()

      # Fast path: forward the promises untouched, so each argument is
      # evaluated exactly once and lazily.
      call_failed <- FALSE
      result <- tryCatch(
        ORIG(...),
        error = function(e) {
          call_failed <<- TRUE
          e
        }
      )
      if (call_failed) {
        result <- retry_call_in_caller_frame(ORIG, this_call, caller_env, result)
      }

      # Force arguments only AFTER the original call succeeded. For
      # NSE arguments (e.g. curve(sin(x)), plot(y ~ x, subset = g == 1))
      # forcing fails; record the unevaluated expressions plus a snapshot of
      # the bindings they name so replay can re-evaluate them faithfully.
      # The snapshot rather than the caller frame itself: R reuses one frame
      # across loop iterations, so storing it by reference would make every
      # iteration replay the last one's values.
      args_list <- muffle_promise_restart(
        tryCatch(list(...), error = function(e) NULL)
      )
      call_env <- NULL
      if (is.null(args_list)) {
        args_list <- as.list(this_call)[-1L]
        call_env <- snapshot_call_env(args_list, caller_env)
      }

      # Computation-only calls (hist(x, plot = FALSE), boxplot(x,
      # plot = FALSE)) draw nothing: recording them would inject phantom
      # layers into the next render.
      if (identical(args_list[["plot"]], FALSE)) {
        return(invisible(result))
      }

      device_id <- grDevices::dev.cur()
      log_plot_call_to_device(
        FNAME, this_call, args_list, device_id,
        call_env = call_env
      )

      # NOTE: auto-show is deliberately NOT scheduled here. show() ends the
      # Base R session (it clears the recorded calls and closes the temp
      # device), so firing it after every top-level expression breaks the
      # most basic Base R idiom: `plot(x, y)` followed by `abline(h = 1)`
      # fails with "plot.new has not been called yet". Auto-display needs a
      # non-destructive render path first; see NEWS.

      # Return invisibly to prevent auto-printing in knitr
      # Users can still capture the result with assignment
      invisible(result)
    },
    list(FNAME = function_name, ORIG = original_function, IS_HIGH = is_high)
  ))

  wrapper
}

#' Create a wrapper for functions taking unevaluated expressions
#'
#' Used for functions like curve() whose arguments must stay lazy. The
#' recorded args are the unevaluated call expressions together with the
#' caller environment, so replay evaluates them exactly as the user's
#' call did.
#'
#' @param function_name Name of the function
#' @param original_function Original function to wrap
#' @return Wrapped function
#' @keywords internal
create_nse_wrapper <- function(function_name, original_function) {
  force(function_name)
  force(original_function)

  function(...) {
    if (!is_patching_enabled()) {
      return(original_function(...))
    }

    this_call <- match.call()
    caller_env <- parent.frame()

    ensure_maidr_device()

    result <- original_function(...)

    recorded_args <- as.list(this_call)[-1L]
    # Snapshot FIRST: the snapshot walks the recorded args with all.vars(),
    # which only accepts language objects, and the curve values appended
    # below are a plain list.
    call_env <- snapshot_call_env(recorded_args, caller_env)

    if (identical(function_name, "curve")) {
      curve_values <- curve_recorded_values(recorded_args, result)
      if (!is.null(curve_values)) {
        recorded_args$.maidr_curve_data <- curve_values
      }
    }

    log_plot_call_to_device(
      function_name,
      this_call,
      recorded_args,
      grDevices::dev.cur(),
      call_env = call_env
    )

    invisible(result)
  }
}

#' Keep the points curve() itself evaluated
#'
#' curve() returns, invisibly, the exact x/y vectors it just drew. Keeping
#' them means the accessible data is read back from the user's own call --
#' evaluated once, at the moment it was made, in the frame that made it.
#'
#' The alternative -- re-deriving the points when the figure is emitted --
#' means running user code a second time, later, in a rebuilt frame. That
#' is the failure mode #59 fixed for `for` loops, where every panel
#' replayed the last iteration's bindings; snapshot_call_env() narrows the
#' window but cannot close it, and the recorded call alone is not enough
#' anyway: `from`/`to` arrive unevaluated too (`to = 2 * pi` is recorded as
#' a call), so emit time would have to redo curve()'s own seq/log/xname
#' handling on top of evaluating the expression. Reading back what was
#' drawn is neither. The SVG still comes from replaying the call, so a
#' deliberately non-deterministic expression can draw a second, different
#' curve -- that is true of every recorded call and is not made worse here.
#'
#' The values are stored under a `.maidr_` name, so clean_maidr_args()
#' drops them before the call is replayed.
#'
#' @param recorded_args Recorded (unevaluated) argument list of the call
#' @param result The value curve() returned
#' @return A list with `x`, `y` and `labels`, or NULL when the returned
#'   value is not a usable pair of coordinate vectors
#' @keywords internal
curve_recorded_values <- function(recorded_args, result) {
  if (!is.list(result) || !all(c("x", "y") %in% names(result))) {
    return(NULL)
  }

  x <- result$x
  y <- result$y
  if (!is.numeric(x) || !is.numeric(y)) {
    return(NULL)
  }
  if (length(x) == 0 || length(x) != length(y)) {
    return(NULL)
  }

  list(x = x, y = y, labels = curve_default_labels(recorded_args))
}

#' Reproduce the axis labels curve() derives for itself
#'
#' curve() computes its default labels internally and does not return them:
#' the x label is `xname` ("x" unless the caller overrides it) and the y
#' label is the deparsed expression, with a bare function name rewritten as
#' `fname(xname)`. Reading them off the recorded call keeps the announced
#' axes matching the drawn ones; without them a visibly labelled plot would
#' be announced with two empty axis titles.
#'
#' An explicit `xlab`/`ylab` in the call wins over these defaults; the line
#' processor applies that precedence.
#'
#' @param recorded_args Recorded (unevaluated) argument list of the call
#' @return List with `x` and `y` label strings
#' @keywords internal
curve_default_labels <- function(recorded_args) {
  arg_names <- names(recorded_args)
  if (is.null(arg_names)) {
    arg_names <- rep("", length(recorded_args))
  }

  xname <- "x"
  if ("xname" %in% arg_names) {
    recorded_xname <- tryCatch(
      as.character(recorded_args[["xname"]])[1L],
      error = function(e) NA_character_
    )
    if (!is.na(recorded_xname) && nzchar(recorded_xname)) {
      xname <- recorded_xname
    }
  }

  expr <- if ("expr" %in% arg_names) {
    recorded_args[["expr"]]
  } else {
    unnamed <- which(!nzchar(arg_names))
    if (length(unnamed) > 0) recorded_args[[unnamed[1L]]] else NULL
  }

  if (is.null(expr)) {
    return(list(x = xname, y = ""))
  }

  # curve(sin, 0, 1) labels its y axis "sin(x)", not "sin".
  if (is.name(expr)) {
    expr <- call(as.character(expr), as.name(xname))
  }

  list(x = xname, y = paste(deparse(expr), collapse = ""))
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
    caller_env <- parent.frame()

    # Ensure a device is open to suppress default graphics window
    ensure_maidr_device()

    # Force args defensively: barplot(y ~ x, subset = ...) style NSE
    # arguments cannot be forced outside the original call.
    args <- tryCatch(list(...), error = function(e) NULL)

    if (is.null(args)) {
      # NSE arguments: skip sorting patches, record expressions + a snapshot
      # of the caller bindings they name so replay evaluates them in the
      # right context, with the values they had when the call was made.
      result <- original_function(...)
      recorded_args <- as.list(this_call)[-1L]
      log_plot_call_to_device(
        "barplot",
        this_call,
        recorded_args,
        grDevices::dev.cur(),
        call_env = snapshot_call_env(recorded_args, caller_env)
      )
    } else {
      patched_args <- apply_barplot_patches(args)

      result <- do.call(original_function, patched_args)

      # Computation-only calls (barplot(x, plot = FALSE) returns the bar
      # midpoints without drawing) must not be recorded, or they inject a
      # phantom bar layer into the next render. The generic wrapper applies
      # the same rule; barplot has its own path and needs it too.
      if (identical(args[["plot"]], FALSE)) {
        return(invisible(result))
      }

      # Log the PATCHED args: replay (both the exported SVG and the native
      # fallback) re-draws from the recorded args, so recording the raw
      # args while drawing the patched ones would desynchronize the SVG
      # bar order from the extracted data order.
      log_plot_call_to_device(
        "barplot",
        this_call,
        patched_args,
        grDevices::dev.cur()
      )
    }

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

      # If no 'at' was provided, compute the default tick positions so the
      # label function can still be applied (axTicks() reproduces the
      # positions axis() would choose). Without this, the drawn axis would
      # silently fall back to unformatted default labels.
      if (is.null(at)) {
        at <- tryCatch(graphics::axTicks(side), error = function(e) NULL)
      }

      # Apply the function to get actual string labels
      if (!is.null(at)) {
        actual_labels <- labels(at)
      } else {
        # No plot yet - let axis() handle it with TRUE
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
