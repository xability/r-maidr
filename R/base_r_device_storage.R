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

#' Keep the title chartSeries() would have given the call it was made from
#'
#' Without a `name`, `quantmod::chartSeries()` titles the chart with the
#' expression its `x` was written as (`as.character(match.call()["x"])`), so
#' `chartSeries(AAPL)` is titled "AAPL". The call is replayed later with the
#' recorded value in place of that expression, and the title became the
#' series' numbers printed end to end. The name is taken from the call as
#' written, the way quantmod takes it, and recorded as an explicit `name`.
#'
#' @param args The recorded arguments of the chartSeries() call
#' @param call_expr The call as written
#' @return `args`, with `name` added when the caller gave none
#' @keywords internal
record_chartseries_name <- function(args, call_expr) {
  keep <- !is.null(args[["name"]]) || !is.call(call_expr) ||
    !requireNamespace("quantmod", quietly = TRUE)
  if (keep) {
    return(args)
  }
  matched <- tryCatch(
    match.call(quantmod::chartSeries, call_expr),
    error = function(e) NULL
  )
  if (is.null(matched) || is.null(matched[["x"]])) {
    return(args)
  }
  args[["name"]] <- as.character(matched["x"])
  args
}

#' Recorded values that are calls, as the expressions they stand for
#'
#' A plotmath title is a call: `main = bquote(mu == .(n))` hands the chart
#' the call `mu == 3`, and `xlab = quote(x[i])` the call `x[i]`. Everything
#' that reads a recorded call passes its values on through `do.call()` --
#' the replay that draws maidr's chart, and the processors that compute
#' what `boxplot()` or `qqnorm()` drew -- and `do.call()` evaluates a call
#' it is handed, so each of them stopped looking up `mu`: the exported
#' chart was drawn with nothing on it, and a box plot or Q-Q plot was read
#' with no data. gridGraphics, which turns the replay into maidr's SVG,
#' stops on a title that is a call as well.
#'
#' An expression vector holding the call is drawn as the same plotmath by
#' R and by gridGraphics, is not evaluated by `do.call()`, and reads as its
#' text. A formula is a call too, and stays one: it is read as a formula,
#' and evaluating one gives the formula back.
#'
#' @param args Recorded argument list of evaluated values
#' @return `args`, each call or symbol in it replaced by an expression
#'   vector holding it
#' @keywords internal
calls_as_expressions <- function(args) {
  for (i in seq_along(args)) {
    value <- args[[i]]
    if (is.name(value) || (is.call(value) && !inherits(value, "formula"))) {
      args[i] <- list(as.expression(value))
    }
  }
  args
}

#' Log Plot Call to Device Storage
#'
#' Records a plot call in the device-specific storage.
#'
#' @param function_name Name of the plotting function
#' @param call_expr The call expression
#' @param args List of function arguments
#' @param device_id Graphics device ID
#' @param call_env Optional environment for replaying unevaluated (NSE)
#'   arguments recorded in \code{args}
#' @param arg_text Optional text each argument in \code{args} was written
#'   as, from \code{written_arg_text()}, which the replay titles the chart
#'   after
#' @param rng_state The `.Random.seed` the call started from, which the
#'   replay draws from, so a chart that draws random numbers comes out as
#'   the reader was shown it; by default the state the recording wrapper
#'   noted before it drew (`ensure_maidr_device()`)
#' @return NULL (invisible)
#' @keywords internal
log_plot_call_to_device <- function(
    function_name,
    call_expr,
    args,
    device_id = grDevices::dev.cur(),
    call_env = NULL,
    arg_text = NULL,
    rng_state = .maidr_call_start$rng_state) {
  # The first call a document records installs maidr into the running knit
  # (and drops calls recorded before it); every later one costs a lookup.
  if (isTRUE(getOption("knitr.in.progress"))) {
    ensure_knitr_integration()
  }
  class_level <- classify_function(function_name)
  storage <- get_device_storage(device_id)
  if (is.null(call_env)) {
    args <- calls_as_expressions(args)
  }
  formula <- recorded_formula(args, call_env)
  if (identical(function_name, "chartSeries")) {
    args <- record_chartseries_name(args, call_expr)
  }

  call_entry <- list(
    function_name = function_name,
    call_expr = if (!is.null(call_expr)) deparse(call_expr) else NA,
    args = args,
    class_level = class_level,
    timestamp = Sys.time(),
    device_id = device_id,
    call_env = call_env,
    arg_text = arg_text,
    rng_state = rng_state,
    # Resolved now rather than at render time. A formula is the one recorded
    # argument that is a reference rather than a value, so a reader that
    # resolved it later would read whatever the names are bound to *then* --
    # see `recorded_formula_frame()` for the measurement (#254).
    formula = formula,
    formula_frame = recorded_formula_frame(args, call_env, formula)
  )
  # Taken once: a call recorded without passing through
  # `ensure_maidr_device()` gets no state rather than an earlier call's.
  .maidr_call_start$rng_state <- NULL
  # In a knit, a call that draws leaves a marker on its page, by which the
  # plot hook knows the figure it is on (see knitr_figure_map.R). A layout
  # call draws nothing, and governs the pages after it instead.
  marked <- class_level %in% c("HIGH", "LOW") &&
    identical(as.integer(device_id), as.integer(grDevices::dev.cur())) &&
    knit_figures_active()
  if (marked) {
    call_entry$uid <- new_knit_token("b")
  }

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

  if (marked) {
    mark_knit_page(call_entry$uid, .maidr_knit_figures$call_start_page)
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
get_device_calls_by_class <- function(device_id = grDevices::dev.cur(), class_level = "HIGH") {
  all_calls <- get_device_calls(device_id)

  if (length(all_calls) == 0) {
    return(list())
  }

  Filter(
    function(call) {
      !is.null(call$class_level) && call$class_level == class_level
    },
    all_calls
  )
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
