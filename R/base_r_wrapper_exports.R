#' @name base-r-wrappers
#' @title Functions maidr masks on attach
#'
#' @description
#' `library(maidr)` puts maidr's own copies of the Base R plotting functions
#' ahead of the originals on the search path, and R says so with its "The
#' following objects are masked" notice. Each copy is a wrapper: it records
#' the call so that [show()] and [save_html()] can render an accessible
#' chart, then calls the original and returns what the original returns.
#' With interception off ([maidr_off()], or `options(maidr.base_r = FALSE)`)
#' the wrappers pass straight through.
#'
#' @details
#' ## What is masked
#'
#' From graphics: the high-level plotting functions `barplot()`, `plot()`,
#' `hist()`, `boxplot()`, `image()`, `contour()`, `matplot()`, `curve()`,
#' `dotchart()`, `stripchart()`, `stem()`, `pie()`, `mosaicplot()`,
#' `assocplot()`, `pairs()`, `coplot()`, `persp()`, `sunflowerplot()`,
#' `fourfoldplot()`, `spineplot()`, `cdplot()`, `filled.contour()`, `bxp()`
#' and `stars()`; the low-level additions `lines()`, `points()`, `text()`,
#' `mtext()`, `abline()`, `segments()`, `arrows()`, `polygon()`, `rect()`,
#' `symbols()`, `legend()`, `axis()`, `title()` and `grid()`; and the layout
#' functions `par()`, `layout()` and `split.screen()`.
#'
#' From stats: `heatmap()`, `qqnorm()`, `qqplot()`, `qqline()`, `acf()`,
#' `pacf()`, `ccf()`, `cpgram()`, `spectrum()`, `monthplot()`, `termplot()`,
#' `lag.plot()`, `biplot()` and `interaction.plot()`.
#'
#' `plot()` is also masked from base, where its generic has lived since
#' R 4.0, and `show()` from methods: the S4 display generic, which maidr's
#' [show()] hands back any object that is not a plot.
#'
#' `vioplot::vioplot()`, `wordcloud::wordcloud()` and
#' `quantmod::chartSeries()` are wrapped as well, once their package is
#' loaded.
#'
#' ## `show()` and `methods::show()`
#'
#' maidr's [show()] takes a ggplot2 object or, with no argument, the last
#' recorded Base R chart. Anything else it is given goes to
#' `methods::show()`, so `show(x)` on an S4 object prints as it did before
#' maidr was attached. In a script or a package, where what is masked
#' depends on what else is attached, call `maidr::show()` and
#' `methods::show()` by name.
#'
#' ## Attach order for vioplot, wordcloud and quantmod
#'
#' These three are wrapped into maidr's namespace when their package loads,
#' so a bare call reaches the wrapper only while `package:maidr` sits ahead
#' of the package on the search path. Attach them *before* maidr:
#'
#' ```r
#' library(vioplot)
#' library(maidr)
#' ```
#'
#' Attached after it, the package masks the wrapper, a bare `vioplot()`,
#' `wordcloud()` or `chartSeries()` draws without being recorded, and
#' [show()] reports that no Base R plot was detected. maidr says so at the
#' moment the package is attached and again in that error. The other way
#' round it is `maidr::vioplot()`, `maidr::wordcloud()` or
#' `maidr::chartSeries()`, called explicitly.
#'
#' ## Calling an original directly
#'
#' The wrappers add nothing to the drawing and return what the original
#' returns, so there is rarely a reason to go around them. `graphics::barplot()`
#' does, and draws a chart maidr does not record.
#'
#' @param ... Arguments passed to the original graphics function.
#' @return Same as the original Base R function (invisibly when applicable).
#'
#' @seealso [show()] and [save_html()]; [maidr_on()] and [maidr_off()] for
#'   turning interception on and off; `?"maidr-options"`.
NULL

# The stub definitions below are overwritten during package loading by the
# actual wrapper implementations created in `initialize_base_r_patching()`.
# They exist solely to generate the NAMESPACE exports via roxygen2.

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
qqline <- function(...) stats::qqline(...)

#' @rdname base-r-wrappers
#' @export
filled.contour <- function(...) graphics::filled.contour(...)

# The twelve below were classified and given layer processors, but never
# exported -- and an unexported stub is invisible to a caller. `.onLoad` runs
# `wrap_function()`, which installs the recording wrapper into maidr's *own*
# namespace, so a bare call only reaches it when it resolves through that
# namespace. A user's call resolves through the search path instead, finds
# `stats::`/`graphics::` directly, and the chart draws unrecorded. Exporting
# the name is what puts maidr's copy in front of the original.

#' @rdname base-r-wrappers
#' @export
acf <- function(...) stats::acf(...)

#' @rdname base-r-wrappers
#' @export
pacf <- function(...) stats::pacf(...)

#' @rdname base-r-wrappers
#' @export
ccf <- function(...) stats::ccf(...)

#' @rdname base-r-wrappers
#' @export
cpgram <- function(...) stats::cpgram(...)

#' @rdname base-r-wrappers
#' @export
spectrum <- function(...) stats::spectrum(...)

#' @rdname base-r-wrappers
#' @export
monthplot <- function(...) stats::monthplot(...)

#' @rdname base-r-wrappers
#' @export
termplot <- function(...) stats::termplot(...)

#' @rdname base-r-wrappers
#' @export lag.plot
#' @usage lag.plot(...)
# Both tags are given explicitly, and for the same reason: roxygen reads
# `lag.plot` as an S3 method for a `lag` generic on class `plot`. Left to
# infer, it writes `S3method(lag, plot)` -- exporting nothing a caller can
# reach -- and renders the usage as `\method{lag}{plot}(...)`, so the man
# page describes a dispatch that does not exist. `@export` fixes the first,
# `@usage` the second; neither implies the other.
lag.plot <- function(...) stats::lag.plot(...)

#' @rdname base-r-wrappers
#' @export
biplot <- function(...) stats::biplot(...)

#' @rdname base-r-wrappers
#' @export
interaction.plot <- function(...) stats::interaction.plot(...)

#' @rdname base-r-wrappers
#' @export
bxp <- function(...) graphics::bxp(...)

#' @rdname base-r-wrappers
#' @export
stars <- function(...) graphics::stars(...)

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
wordcloud <- function(...) {
  if (!requireNamespace("wordcloud", quietly = TRUE)) {
    stop(
      "Package 'wordcloud' is required for wordcloud(). ",
      "Please install it via install.packages('wordcloud').",
      call. = FALSE
    )
  }

  # Same shape and same reason as the vioplot stub above: `wordcloud` is in
  # Suggests, so when it loads after maidr the namespace is already sealed and
  # `wrap_function()` cannot replace this stub. Without a full recording
  # wrapper here the call draws and is never recorded -- which is exactly what
  # happened before, and which only shows up against an *installed* package,
  # since `load_all()` leaves the namespace open and lets `wrap_function()`
  # succeed.
  original <- get("wordcloud", envir = asNamespace("wordcloud"))
  if (is.null(.maidr_patching_env$.saved_graphics_fns[["wordcloud"]])) {
    .maidr_patching_env$.saved_graphics_fns[["wordcloud"]] <- original
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
  # `wordcloud(words, freq)` is as natural to write positionally as by name,
  # and the layer reads `args$words` / `args$freq`. Name-matching here is what
  # keeps the positional spelling from recording a call with nothing to read.
  #
  # Called on both paths, including after the NSE fallback above -- which the
  # generated wrapper template deliberately does not do, because matching an
  # unevaluated `as.list(this_call)` would force `args[[1]]` to find an S3
  # method. That only happens for a generic: `dispatched_definition()` looks at
  # the first argument solely when the target's body contains `UseMethod`.
  # Measured, `wordcloud::wordcloud()` does not -- it is a plain function -- so
  # the concern cannot arise here. Written down because it would if this stub
  # were ever copied for a function that is generic (`vioplot()` is one, which
  # is why its stub records the arguments unmatched).
  args_list <- tryCatch(
    match_recorded_args("wordcloud", original, args_list),
    error = function(e) args_list
  )

  log_plot_call_to_device(
    "wordcloud",
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
