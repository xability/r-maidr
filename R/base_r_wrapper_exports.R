#' @name base-r-wrappers
#' @title Base R Graphics Function Wrappers
#'
#' @description
#' MAIDR wraps standard Base R graphics functions to intercept plot calls
#' and enable accessible, interactive visualizations. When the maidr package
#' is loaded, these wrappers automatically replace the standard functions
#' on the search path, recording plot data so that [show()] can render
#' accessible versions.
#'
#' The wrappers are transparent: they call the original graphics functions
#' and return the same results. When patching is disabled (via [maidr_off()]),
#' they pass through directly to the originals with no overhead.
#'
#' @param ... Arguments passed to the original graphics function.
#' @return Same as the original Base R function (invisibly when applicable).
#'
#' @details
#' These stub definitions are overwritten during package loading by the
#' actual wrapper implementations created in [initialize_base_r_patching()].
#' They exist here solely to generate the necessary NAMESPACE exports
#' via roxygen2.
#'
#' @seealso [show()] for displaying accessible plots, [maidr_on()],
#'   [maidr_off()] for controlling patching
#' @keywords internal
NULL

# --- HIGH-level plot creation functions ---

#' @rdname base-r-wrappers
#' @export
barplot <- function(...) graphics::barplot(...)

#' @rdname base-r-wrappers
#' @export
plot <- function(...) graphics::plot(...)

#' @rdname base-r-wrappers
#' @export
hist <- function(...) graphics::hist(...)

#' @rdname base-r-wrappers
#' @export
boxplot <- function(...) graphics::boxplot(...)

#' @rdname base-r-wrappers
#' @export
image <- function(...) graphics::image(...)

#' @rdname base-r-wrappers
#' @export
heatmap <- function(...) stats::heatmap(...)

#' @rdname base-r-wrappers
#' @export
contour <- function(...) graphics::contour(...)

#' @rdname base-r-wrappers
#' @export
matplot <- function(...) graphics::matplot(...)

#' @rdname base-r-wrappers
#' @export
curve <- function(...) graphics::curve(...)

#' @rdname base-r-wrappers
#' @export
dotchart <- function(...) graphics::dotchart(...)

#' @rdname base-r-wrappers
#' @export
stripchart <- function(...) graphics::stripchart(...)

#' @rdname base-r-wrappers
#' @export
stem <- function(...) graphics::stem(...)

#' @rdname base-r-wrappers
#' @export
pie <- function(...) graphics::pie(...)

#' @rdname base-r-wrappers
#' @export
mosaicplot <- function(...) graphics::mosaicplot(...)

#' @rdname base-r-wrappers
#' @export
assocplot <- function(...) graphics::assocplot(...)

#' @rdname base-r-wrappers
#' @export
pairs <- function(...) graphics::pairs(...)

#' @rdname base-r-wrappers
#' @export
coplot <- function(...) graphics::coplot(...)

# The eight below are wrapped so that a chart maidr cannot read still falls
# back to a picture instead of stopping the save. See the note beside them in
# `.base_r_function_classes$HIGH`.

#' @rdname base-r-wrappers
#' @export
persp <- function(...) graphics::persp(...)

#' @rdname base-r-wrappers
#' @export
sunflowerplot <- function(...) graphics::sunflowerplot(...)

#' @rdname base-r-wrappers
#' @export
fourfoldplot <- function(...) graphics::fourfoldplot(...)

#' @rdname base-r-wrappers
#' @export
spineplot <- function(...) graphics::spineplot(...)

#' @rdname base-r-wrappers
#' @export
cdplot <- function(...) graphics::cdplot(...)

#' @rdname base-r-wrappers
#' @export
qqnorm <- function(...) stats::qqnorm(...)

#' @rdname base-r-wrappers
#' @export
qqplot <- function(...) stats::qqplot(...)

#' @rdname base-r-wrappers
#' @export
filled.contour <- function(...) graphics::filled.contour(...)

#' @rdname base-r-wrappers
#' @export
vioplot <- function(...) {
  if (!requireNamespace("vioplot", quietly = TRUE)) {
    stop(
      "Package 'vioplot' is required for vioplot(). ",
      "Please install it via install.packages('vioplot').",
      call. = FALSE
    )
  }

  # Same shape as the chartSeries stub below, and for the same reason: when
  # vioplot loads after maidr the namespace is already sealed, so
  # wrap_function() cannot replace this and it has to be a full recording
  # wrapper resolving the original lazily.
  original <- get("vioplot", envir = asNamespace("vioplot"))
  if (is.null(.maidr_patching_env$.saved_graphics_fns[["vioplot"]])) {
    .maidr_patching_env$.saved_graphics_fns[["vioplot"]] <- original
  }

  if (!is_patching_enabled()) {
    return(original(...))
  }

  this_call <- match.call()
  caller_env <- parent.frame()

  ensure_maidr_device()

  call_failed <- FALSE
  result <- tryCatch(
    original(...),
    error = function(e) {
      call_failed <<- TRUE
      e
    }
  )
  if (call_failed) {
    result <- retry_call_in_caller_frame(original, this_call, caller_env, result)
  }

  args_list <- tryCatch(list(...), error = function(e) NULL)
  call_env <- NULL
  if (is.null(args_list)) {
    args_list <- as.list(this_call)[-1L]
    call_env <- snapshot_call_env(args_list, caller_env)
  }

  log_plot_call_to_device(
    "vioplot",
    this_call,
    args_list,
    grDevices::dev.cur(),
    call_env = call_env
  )

  invisible(result)
}

#' @rdname base-r-wrappers
#' @export
chartSeries <- function(...) {
  if (!requireNamespace("quantmod", quietly = TRUE)) {
    stop(
      "Package 'quantmod' is required for chartSeries(). ",
      "Please install it via install.packages('quantmod').",
      call. = FALSE
    )
  }

  # This stub cannot be replaced by wrap_function() when quantmod loads
  # after maidr (the namespace is sealed by then), so it must be a full
  # recording wrapper itself, resolving the original lazily.
  if (is.null(.maidr_patching_env$.saved_graphics_fns[["chartSeries"]])) {
    .maidr_patching_env$.saved_graphics_fns[["chartSeries"]] <-
      quantmod::chartSeries
  }

  if (!is_patching_enabled()) {
    return(quantmod::chartSeries(...))
  }

  this_call <- match.call()
  caller_env <- parent.frame()

  ensure_maidr_device()

  # quantmod::chartSeries() builds its own argument record with
  # match.call(expand.dots = TRUE). Forwarding through `...` makes that
  # record hold the dot symbols (`..3`) instead of the caller's
  # expressions, so an explicit `TA = NULL` reaches quantmod as a `name`
  # and dies in `sapply(chob@passed.args$TA, function(x) eval(x@call))`.
  # Retrying with the call rebuilt in the caller's frame gives quantmod
  # the literal arguments it expects - the same fallback the generated
  # wrappers use (see retry_call_in_caller_frame()).
  call_failed <- FALSE
  result <- tryCatch(
    quantmod::chartSeries(...),
    error = function(e) {
      call_failed <<- TRUE
      e
    }
  )
  if (call_failed) {
    result <- retry_call_in_caller_frame(
      quantmod::chartSeries, this_call, caller_env, result
    )
  }

  args_list <- tryCatch(list(...), error = function(e) NULL)
  call_env <- NULL
  if (is.null(args_list)) {
    args_list <- as.list(this_call)[-1L]
    call_env <- snapshot_call_env(args_list, caller_env)
  }

  log_plot_call_to_device(
    "chartSeries",
    this_call,
    args_list,
    grDevices::dev.cur(),
    call_env = call_env
  )

  invisible(result)
}

# --- LOW-level drawing functions ---

#' @rdname base-r-wrappers
#' @export
lines <- function(...) graphics::lines(...)

#' @rdname base-r-wrappers
#' @export
points <- function(...) graphics::points(...)

#' @rdname base-r-wrappers
#' @export
text <- function(...) graphics::text(...)

#' @rdname base-r-wrappers
#' @export
mtext <- function(...) graphics::mtext(...)

#' @rdname base-r-wrappers
#' @export
abline <- function(...) graphics::abline(...)

#' @rdname base-r-wrappers
#' @export
segments <- function(...) graphics::segments(...)

#' @rdname base-r-wrappers
#' @export
arrows <- function(...) graphics::arrows(...)

#' @rdname base-r-wrappers
#' @export
polygon <- function(...) graphics::polygon(...)

#' @rdname base-r-wrappers
#' @export
rect <- function(...) graphics::rect(...)

#' @rdname base-r-wrappers
#' @export
symbols <- function(...) graphics::symbols(...)

#' @rdname base-r-wrappers
#' @export
legend <- function(...) graphics::legend(...)

#' @rdname base-r-wrappers
#' @export
axis <- function(...) graphics::axis(...)

#' @rdname base-r-wrappers
#' @export
title <- function(...) graphics::title(...)

#' @rdname base-r-wrappers
#' @export
grid <- function(...) graphics::grid(...)

# --- LAYOUT functions ---

#' @rdname base-r-wrappers
#' @export
par <- function(...) graphics::par(...)

#' @rdname base-r-wrappers
#' @export
layout <- function(...) graphics::layout(...)

#' @rdname base-r-wrappers
#' @export split.screen
split.screen <- function(...) graphics::split.screen(...)
