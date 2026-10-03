# maidr's place in a running knit.
#
# rmarkdown::render() and Quarto put knitr's hooks and options back after
# every render, and `.onLoad()` runs once per session, so nothing installed
# when maidr loads would survive into a second render in the same session
# (`R CMD build` renders every vignette in one process). So every entry point
# a document can reach installs maidr into the knit that is running, the
# first time one is reached: `.onLoad()` when a document's `library(maidr)`
# loads maidr, `maidr_on()`, the `knit_print()` methods, the ggplot2 print
# method, lattice's print hook, and every Base R call maidr records. A
# marker in `opts_knit`, which every knit puts back, makes it once per knit;
# after that, each entry point costs one lookup.
#
# What is installed:
# * the plot hook, which makes a chunk's Base R figure an accessible chart;
# * a `dev` option hook, which gives the chunks of an HTML document svglite
#   in place of knitr's default png, so its static figures are vector images;
# * a chunk hook, which declares the page dependencies of the charts a
#   chunk shows, where knitr's cache keeps them.
# Each wraps the hook it replaces, which it calls first or falls back on, and
# `maidr_off()` puts that hook back.

#' Whether knitr is knitting a document now
#'
#' `knitr.in.progress` alone is an option anyone can set; `out.format` is set
#' by knitr itself for the length of a knit.
#'
#' @return Logical
#' @keywords internal
#' @noRd
knit_in_progress <- function() {
  isTRUE(getOption("knitr.in.progress")) &&
    isNamespaceLoaded("knitr") &&
    !is.null(knitr::opts_knit$get("out.format"))
}

#' Install maidr's knitr integration into the running knit, once
#'
#' Does nothing outside a knit, while interception is off ([maidr_off()],
#' `options(maidr.auto_show = FALSE)`), or when the integration is already in
#' place for this knit: the marker is set and maidr's plot and chunk hooks
#' are the ones knitr will call. The marker alone is not enough. A document
#' rendered from inside another one's chunk inherits the marker, but not the
#' hooks, and a document can set a hook of its own over maidr's; either way,
#' maidr installs itself again, over what is there.
#'
#' @return `TRUE` when the integration is in place for this knit, invisibly
#' @keywords internal
ensure_knitr_integration <- function() {
  if (!knit_in_progress() || !is_maidr_enabled()) {
    return(invisible(FALSE))
  }
  installed <- isTRUE(knitr::opts_knit$get("maidr.integrated")) &&
    is_maidr_knitr_hook(knitr::knit_hooks$get("plot")) &&
    is_maidr_knitr_hook(knitr::knit_hooks$get("chunk"))
  if (!installed) {
    install_knitr_integration()
  }
  invisible(TRUE)
}

#' Install maidr's knitr hooks
#'
#' Each hook is installed over the one in place, unless that one is maidr's.
#' The plot hook is looked up when a figure is written, after its chunk has
#' run, and the chunk hook after that, so hooks installed while a chunk runs
#' already cover that chunk.
#'
#' Base R calls recorded before the first install of a knit belong to no
#' chart of it, and are dropped. A knit whose hooks are already maidr's is a
#' child document, which put its parent's `opts_knit` back when it ended:
#' the current device's calls are then this chunk's, and are kept.
#'
#' @return NULL (invisible)
#' @keywords internal
install_knitr_integration <- function() {
  plot <- knitr::knit_hooks$get("plot")
  fresh <- !is_maidr_knitr_hook(plot)
  knitr::opts_knit$set(maidr.integrated = TRUE)

  if (fresh) {
    knitr::knit_hooks$set(plot = maidr_knitr_plot_hook(plot))
  }
  dev <- knitr::opts_hooks$get("dev")
  if (!is_maidr_knitr_hook(dev)) {
    knitr::opts_hooks$set(dev = maidr_knitr_dev_hook(dev))
  }
  chunk <- knitr::knit_hooks$get("chunk")
  if (!is_maidr_knitr_hook(chunk)) {
    knitr::knit_hooks$set(chunk = maidr_knitr_chunk_hook(chunk))
  }

  if (fresh) {
    reset_knitr_chart_index()
    note_knit_device(NULL)
  }
  drop_stale_device_storage(include_current = fresh)
  invisible(NULL)
}

#' Take maidr's knitr integration out of the running knit
#'
#' Called by [maidr_off()]. Puts back each hook maidr installed over, and
#' removes the marker, so a later [maidr_on()] in the same document installs
#' them again. A hook of the document's own set over maidr's is left alone;
#' maidr's hook under it acts as the one it replaced once interception is
#' off. Outside a knit it removes what a plain `knitr::knit()` left behind,
#' which, unlike `rmarkdown::render()`, does not put the option hooks back.
#'
#' @return NULL (invisible)
#' @keywords internal
uninstall_knitr_integration <- function() {
  if (!isNamespaceLoaded("knitr")) {
    return(invisible(NULL))
  }
  for (name in c("plot", "chunk")) {
    hook <- knitr::knit_hooks$get(name)
    if (is_maidr_knitr_hook(hook)) {
      previous <- list(attr(hook, "previous"))
      names(previous) <- name
      if (is.function(previous[[1L]])) {
        knitr::knit_hooks$set(previous)
      } else {
        knitr::knit_hooks$delete(name)
      }
    }
  }
  dev <- knitr::opts_hooks$get("dev")
  if (is_maidr_knitr_hook(dev)) {
    previous <- attr(dev, "previous")
    if (is.function(previous)) {
      knitr::opts_hooks$set(dev = previous)
    } else {
      knitr::opts_hooks$delete("dev")
    }
  }
  knitr::opts_knit$delete("maidr.integrated")
  reset_knitr_chart_index()
  note_knit_device(NULL)
  invisible(NULL)
}

#' Mark a hook as maidr's, keeping the one it was installed over
#'
#' @param hook maidr's hook
#' @param previous The hook it replaces, or `NULL`
#' @return `hook`, marked
#' @keywords internal
#' @noRd
mark_maidr_knitr_hook <- function(hook, previous) {
  attr(hook, "maidr_knitr") <- TRUE
  attr(hook, "previous") <- previous
  hook
}

#' Whether a knitr hook is one of maidr's
#'
#' @param hook A hook, or `NULL`
#' @return Logical
#' @keywords internal
#' @noRd
is_maidr_knitr_hook <- function(hook) {
  isTRUE(attr(hook, "maidr_knitr"))
}

#' maidr's knitr plot hook, over the hook it replaces
#'
#' The replaced hook is kept in the closure rather than in a global, so a
#' document rendered from inside another one's chunk keeps its own, and a
#' hook a document wraps around maidr's cannot be called back into.
#'
#' @param original The plot hook in place before
#' @return A plot hook calling `maidr_plot_hook()`
#' @keywords internal
maidr_knitr_plot_hook <- function(original) {
  force(original)
  hook <- function(x, options) maidr_plot_hook(x, options, original)
  mark_maidr_knitr_hook(hook, original)
}

#' maidr's knitr chunk hook, over the hook it replaces
#'
#' Runs once a chunk's output is complete, after the hook it replaces. A
#' chunk whose output holds an inline chart declares the page dependencies
#' (`maidr_knitr_dependencies()`) through `knitr::knit_meta_add()`, whichever
#' way the chart got there: a returned plot, a figure, or
#' `cat(knit_print(p))` in a `results = "asis"` loop, which drops the meta
#' a `knit_asis` object carries.
#'
#' A chunk cached with `cache = TRUE` is not run again, and only what knitr
#' cached of it comes back: its output, and the meta its `knit_asis` output
#' carried, which knitr keeps under `.<hash>_meta` in `knit_global()` until
#' it saves the chunk -- just after this hook. The dependencies are added
#' there too, or a later render would bring the chart back without
#' maidr.js. The name is knitr's (`knitr:::cache_meta_name()`), and a test
#' checks it has not changed.
#'
#' @param previous The chunk hook in place before
#' @return A chunk hook
#' @keywords internal
maidr_knitr_chunk_hook <- function(previous) {
  force(previous)
  hook <- function(x, options) {
    if (is.function(previous)) {
      x <- previous(x, options)
    }
    reset_knitr_chart_index()
    note_knit_device(NULL)
    shown <- !isFALSE(options$include) &&
      any(grepl("data-maidr-knitr=", x, fixed = TRUE))
    if (shown) {
      deps <- maidr_knitr_dependencies()
      knitr::knit_meta_add(deps, if (is.null(options$label)) "" else options$label)
      if (identical(as.numeric(options$cache), 3) && is.character(options$hash)) {
        name <- sprintf(".%s_meta", options$hash)
        env <- knitr::knit_global()
        cached <- if (exists(name, envir = env, inherits = FALSE)) {
          get(name, envir = env, inherits = FALSE)
        }
        assign(name, c(cached, deps), envir = env)
      }
    }
    x
  }
  mark_maidr_knitr_hook(hook, previous)
}

#' maidr's `dev` option hook, over the hook it replaces
#'
#' knitr runs it at the start of every chunk, before the chunk's device
#' opens, after the hook it replaces (flexdashboard has one). It drops the
#' Base R calls of devices that have closed since -- a chunk whose plot hook
#' never ran (`fig.show = "hide"`, an error) would otherwise leave its calls
#' to the next chunk, which knitr gives the same device number -- and picks
#' the chunk's device (`maidr_chunk_device()`). It does nothing in a knit
#' maidr was not installed into: a plain `knitr::knit()` leaves it behind.
#'
#' @param previous The `dev` option hook in place before
#' @return An option hook
#' @keywords internal
maidr_knitr_dev_hook <- function(previous) {
  force(previous)
  hook <- function(options) {
    if (is.function(previous)) {
      options <- previous(options)
    }
    if (!isTRUE(knitr::opts_knit$get("maidr.integrated"))) {
      return(options)
    }
    drop_stale_device_storage()
    note_knit_device(NULL)
    options$dev <- maidr_chunk_device(options)
    options
  }
  mark_maidr_knitr_hook(hook, previous)
}

#' The device a chunk records and saves its figures with
#'
#' svglite, in place of the `png` knitr gives HTML documents, so the static
#' figures of a page with inline charts are vector images too. Only that
#' default is replaced, in an R chunk of HTML output that shows charts
#' inline; any device the author chose is kept:
#'
#' * a `dev` the chunk names, in its header or a `#|` line, or through an
#'   `opts.label` template;
#' * a document device other than `png`: YAML `dev:`, `opts_chunk$set()`,
#'   or Quarto's `fig-format:` other than its default `retina`, which is
#'   `png` at `fig.retina = 2`;
#' * several devices, a `fig.ext`, or `dev.args` svglite cannot take
#'   (knitr hands flat `dev.args` to the device unfiltered);
#' * a cached chunk: the device is part of the chunk's cache key, which knitr
#'   computes before the chunk can load maidr, so switching it would miss the
#'   cache on every render;
#' * a chunk of another engine: Python saves its figures in the format
#'   `dev` names;
#' * `options(maidr.knitr_dev = FALSE)`, for a document whose `png` is a
#'   choice (`dev: png` in R Markdown's YAML cannot be told from the default).
#'
#' knitr records a chunk's figures on svglite only from 1.44.
#'
#' @param options Chunk options, as option hooks see them: before knitr's
#'   own fix-ups
#' @return The device's name
#' @keywords internal
maidr_chunk_device <- function(options) {
  keep <- !is_maidr_enabled() ||
    isFALSE(getOption("maidr.knitr_dev", TRUE)) ||
    !identical(tolower(options$engine %||% "r"), "r") ||
    !identical(options$dev, "png") ||
    !identical(knitr::opts_chunk$get("dev"), "png") ||
    chunk_sets_option(options, "dev") ||
    !is.null(options$fig.ext) ||
    chunk_is_cached(options) ||
    (!is.null(knitr::opts_knit$get("quarto.version")) &&
       !identical(as.numeric(options$fig.retina), 2)) ||
    !dev_args_suit_svglite(options$dev.args) ||
    utils::packageVersion("knitr") < "1.44" ||
    !inline_output_ok()
  if (keep) options$dev else "svglite"
}

#' Whether a chunk sets an option itself
#'
#' In its header or a `#|` line, which knitr keeps with the chunk's code, or
#' through an `opts.label` template; not from the document's defaults.
#'
#' @param options Chunk options
#' @param name The option's name
#' @return Logical
#' @keywords internal
#' @noRd
chunk_sets_option <- function(options, name) {
  sets <- function(label) {
    name %in% names(attr(knitr::knit_code$get(label), "chunk_opts"))
  }
  if (!is.null(options$label) && sets(options$label)) {
    return(TRUE)
  }
  templates <- options$opts.label
  if (!is.character(templates)) {
    return(FALSE)
  }
  any(vapply(templates, function(label) {
    !is.null(knitr::opts_template$get(label)[[name]]) || sets(label)
  }, logical(1)))
}

#' Whether a chunk is cached
#'
#' @param options Chunk options, before knitr turns `cache` into a number
#' @return Logical
#' @keywords internal
#' @noRd
chunk_is_cached <- function(options) {
  cache <- options$cache
  isTRUE(cache) || (is.numeric(cache) && length(cache) == 1L && isTRUE(cache > 0))
}

#' Whether a chunk's `dev.args` can be handed to svglite
#'
#' Flat `dev.args` go to the device as they are, and svglite has no `...`
#' to take `type = "cairo"` and the like. `dev.args` given per device are
#' read for svglite only.
#'
#' @param dev_args The `dev.args` chunk option
#' @return Logical
#' @keywords internal
#' @noRd
dev_args_suit_svglite <- function(dev_args) {
  if (length(dev_args) == 0L) {
    return(TRUE)
  }
  if (is.list(dev_args) && all(vapply(dev_args, is.list, logical(1)))) {
    dev_args <- dev_args[["svglite"]]
  }
  all(names(dev_args) %in% names(formals(svglite::svglite)))
}

#' The device the chunk being knitted draws on
#'
#' The plot hook reads a chunk's Base R calls from the chunk's device, which
#' is no longer the current one when the hook runs if another device is
#' open: knitr saves each figure on a device of its own, and closing that
#' one makes R's next open device current -- the first one, say a `pdf()`
#' left open or an IDE's screen, rather than the chunk's. So the device a
#' chunk records a call on, or draws a ggplot2 or lattice chart on, is
#' noted, and forgotten when the chunk ends.
#'
#' @return The chunk's device when one was noted and is still open, the
#'   current device otherwise
#' @keywords internal
knit_chunk_device <- function() {
  device <- .maidr_knitr_state$device
  if (!is.null(device) && device %in% grDevices::dev.list()) {
    return(device)
  }
  grDevices::dev.cur()
}

#' Note the device a knitted chunk draws on
#'
#' @param device_id Graphics device ID; `NULL` forgets it
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
note_knit_device <- function(device_id) {
  .maidr_knitr_state$device <- device_id
  invisible(NULL)
}

#' Drop the Base R calls recorded on devices that are no longer open
#'
#' Calls are kept by device number, and knitr gives every chunk the same
#' number: calls a chunk recorded without its plot hook running would become
#' layers of the next chunk's chart.
#'
#' @param include_current Drop the current device's calls as well
#' @return NULL (invisible)
#' @keywords internal
drop_stale_device_storage <- function(include_current = FALSE) {
  keys <- names(.maidr_base_r_session$devices)
  stale <- setdiff(keys, as.character(grDevices::dev.list()))
  if (include_current) {
    stale <- union(stale, intersect(keys, as.character(grDevices::dev.cur())))
  }
  for (key in stale) {
    clear_device_storage(as.integer(key))
  }
  invisible(NULL)
}
