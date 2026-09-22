#' ggplot2 System Initialization
#'
#' Initialize and register the ggplot2 system with the global registry.
#' This function sets up the ggplot2 adapter and processor factory.
#'
#' @keywords internal
#' @return NULL (invisible)

initialize_ggplot2_system <- function() {
  registry <- get_global_registry()

  if (registry$is_system_registered("ggplot2")) {
    return(invisible(NULL))
  }

  ggplot2_adapter <- Ggplot2Adapter$new()

  ggplot2_factory <- Ggplot2ProcessorFactory$new()

  # Register the system
  registry$register_system("ggplot2", ggplot2_adapter, ggplot2_factory)

  invisible(NULL)
}

# Hook run when quantmod is loaded after maidr, so maidr can wrap quantmod's
# HIGH-level chartSeries() and record candlestick calls. Named (not anonymous)
# so .onUnload can remove exactly this hook on unload.
.maidr_quantmod_onload_hook <- function(...) {
  tryCatch(wrap_function("chartSeries"), error = function(e) NULL)
}

#' The Suggests packages whose plotting entry point maidr wraps
#'
#' Named by package, valued by the function. Each is wrapped into maidr's
#' own namespace when the package loads (the `onLoad` hooks below), so a
#' bare call reaches the wrapper only while `package:maidr` sits ahead of
#' the package on the search path. Attached after maidr, the package masks
#' the wrapper and its calls go unrecorded; see [package_masks_maidr()].
#'
#' @keywords internal
WRAPPED_SUGGESTS <- c(
  quantmod = "chartSeries",
  vioplot = "vioplot",
  wordcloud = "wordcloud"
)

#' Is a package attached ahead of maidr on the search path?
#'
#' `library(quantmod)` after `library(maidr)` puts `package:quantmod` in
#' front of `package:maidr`, so an unqualified `chartSeries()` binds to
#' quantmod's own function and maidr's recording wrapper is never entered.
#' `library(vioplot)` and `library(wordcloud)` after maidr do the same to
#' `vioplot()` and `wordcloud()`: the "No Base R plots detected" error that
#' follows a bare call to either was measured with maidr 0.5.0 (#320).
#'
#' maidr deliberately does not reach into another package's namespace to
#' win this race: overwriting a foreign package's binding would also
#' redirect the package's *internal* calls through maidr's `...`-forwarding
#' wrapper, which for quantmod corrupts the `match.call(expand.dots = TRUE)`
#' it relies on. maidr reports the condition instead.
#'
#' @param package Name of the package, as in [WRAPPED_SUGGESTS].
#' @return `TRUE` when both packages are attached and `package` comes first.
#' @keywords internal
package_masks_maidr <- function(package) {
  path <- search()
  package_pos <- match(paste0("package:", package), path, nomatch = 0L)
  maidr_pos <- match("package:maidr", path, nomatch = 0L)
  package_pos > 0L && maidr_pos > 0L && package_pos < maidr_pos
}

#' Is quantmod attached ahead of maidr on the search path?
#'
#' [package_masks_maidr()] for quantmod, the first package this was noticed
#' with (#97).
#'
#' @return `TRUE` when both packages are attached and quantmod comes first.
#' @keywords internal
quantmod_masks_maidr <- function() {
  package_masks_maidr("quantmod")
}

#' The wrapped Suggests packages attached ahead of maidr right now
#'
#' @return Package names, in [WRAPPED_SUGGESTS] order; empty when none masks.
#' @keywords internal
packages_masking_maidr <- function() {
  packages <- names(WRAPPED_SUGGESTS)
  packages[vapply(packages, package_masks_maidr, logical(1))]
}

#' Advice shown when an attached package masks one of maidr's wrappers
#'
#' Shared by `.onAttach`, the attach hooks and the "No Base R plots
#' detected" errors so the wording stays in one place.
#'
#' @param package Name of the package, as in [WRAPPED_SUGGESTS].
#' @return A single advice string.
#' @keywords internal
mask_advice <- function(package) {
  fn <- WRAPPED_SUGGESTS[[package]]
  paste0(
    "'", package, "' is attached ahead of 'maidr' on the search path, so a ",
    "bare ", fn, "() call goes straight to ", package, " and is not ",
    "recorded. Attach '", package, "' before 'maidr', or call maidr::", fn,
    "() explicitly."
  )
}

#' Advice shown when quantmod masks maidr's chartSeries() wrapper
#'
#' [mask_advice()] for quantmod.
#'
#' @return A single advice string.
#' @keywords internal
quantmod_mask_advice <- function() {
  mask_advice("quantmod")
}

#' Message for show()/save_html()/maidr_widget() with nothing recorded
#'
#' Names every masking case that applies: the bare "create a plot first"
#' wording is actively misleading there, because the user *did* draw a
#' chart - it just went to the other package unrecorded.
#'
#' @return The error message string.
#' @keywords internal
no_base_r_plots_message <- function() {
  message_text <- paste0(
    "No Base R plots detected. Please create a plot first ",
    "(e.g., barplot(), plot())."
  )

  for (package in packages_masking_maidr()) {
    message_text <- paste0(message_text, "\n", mask_advice(package))
  }

  message_text
}

#' Say, as a package is attached, that it now masks a maidr wrapper
#'
#' Run from the attach hooks below. By then the package sits ahead of maidr
#' on the search path, so this is the moment to tell the user that bare
#' calls to its entry point will no longer be recorded. Silent when the
#' package does not mask, and under `maidr.startup_message = FALSE`.
#'
#' @param package Name of the package, as in [WRAPPED_SUGGESTS].
#' @keywords internal
announce_masking <- function(package) {
  tryCatch(
    {
      announce <- package_masks_maidr(package) &&
        isTRUE(getOption("maidr.startup_message", TRUE))
      if (announce) {
        packageStartupMessage("maidr: ", mask_advice(package))
      }
    },
    error = function(e) NULL
  )
  invisible(NULL)
}

# The attach hooks, one per wrapped package. Named (not anonymous) so
# .onUnload can remove exactly these hooks on unload.
.maidr_quantmod_attach_hook <- function(...) {
  announce_masking("quantmod")
}

.maidr_vioplot_attach_hook <- function(...) {
  announce_masking("vioplot")
}

.maidr_wordcloud_attach_hook <- function(...) {
  announce_masking("wordcloud")
}

#' Wrap vioplot's entry point once its namespace is available
#'
#' vioplot is in Suggests, so if it loads after maidr its `vioplot()` has not
#' been wrapped yet and user calls would go unrecorded. Same shape as the
#' quantmod hook above, and registered beside it in `.onLoad`.
#'
#' @keywords internal
.maidr_vioplot_onload_hook <- function(...) {
  tryCatch(wrap_function("vioplot"), error = function(e) NULL)
}

#' Wrap wordcloud's entry point once its namespace is available
#'
#' Same shape and same reason as the vioplot hook above: `wordcloud` is in
#' Suggests, so a call made after a late `library(wordcloud)` would otherwise
#' go unrecorded entirely.
#'
#' @keywords internal
.maidr_wordcloud_onload_hook <- function(...) {
  tryCatch(wrap_function("wordcloud"), error = function(e) NULL)
}

# Auto-initialize systems when package is loaded
.onLoad <- function(libname, pkgname) {
  # Set default options (respects user's .Rprofile settings)
  initialize_maidr_options()

  tryCatch(
    {
      initialize_ggplot2_system()
    },
    error = function(e) {
      warning("Failed to initialize ggplot2 system: ", e$message)
    }
  )

  tryCatch(
    {
      initialize_base_r_system()
    },
    error = function(e) {
      warning("Failed to initialize Base R system: ", e$message)
    }
  )

  # Install Base R wrappers (always, so exports exist).
  # Whether they intercept or pass through is controlled by
  # is_patching_enabled() which checks the runtime options.
  tryCatch(
    {
      initialize_base_r_patching()
    },
    error = function(e) {
      warning("Failed to initialize Base R patching: ", e$message)
    }
  )

  # Register custom print.ggplot method for interactive auto-display
  tryCatch(
    {
      register_ggplot2_print_method()
    },
    error = function(e) {
      # Not critical - ggplot2 may not be installed
      NULL
    }
  )

  # Late-binding wrapper installation for optional Suggests packages.
  # quantmod is in Suggests; if it is loaded AFTER maidr we still need
  # to wrap its HIGH-level chartSeries() so user calls get recorded.
  tryCatch(
    setHook(
      packageEvent("quantmod", "onLoad"),
      .maidr_quantmod_onload_hook
    ),
    error = function(e) NULL
  )

  # Attaching quantmod after maidr masks maidr's chartSeries() wrapper.
  # maidr cannot win that race without patching quantmod's own bindings,
  # so it says so out loud instead of failing silently at export time.
  tryCatch(
    setHook(
      packageEvent("quantmod", "attach"),
      .maidr_quantmod_attach_hook
    ),
    error = function(e) NULL
  )

  # vioplot and wordcloud are in Suggests for the same reason and need the
  # same late binding, and attaching either after maidr masks its wrapper
  # on the search path exactly as quantmod does (#320), so each gets the
  # same attach hook.
  for (package in c("vioplot", "wordcloud")) {
    tryCatch(
      setHook(
        packageEvent(package, "onLoad"),
        get(paste0(".maidr_", package, "_onload_hook"), envir = asNamespace("maidr"))
      ),
      error = function(e) NULL
    )
    tryCatch(
      setHook(
        packageEvent(package, "attach"),
        get(paste0(".maidr_", package, "_attach_hook"), envir = asNamespace("maidr"))
      ),
      error = function(e) NULL
    )
  }
}

# Remove the quantmod onLoad hook installed in .onLoad so the package unloads
# cleanly without leaving global session state behind (CRAN policy).
.onUnload <- function(libpath) {
  drop_hook <- function(event, fn, package = "quantmod") {
    tryCatch(
      {
        ev <- packageEvent(package, event)
        hooks <- getHook(ev)
        if (length(hooks)) {
          keep <- !vapply(hooks, identical, logical(1), fn)
          setHook(ev, hooks[keep], action = "replace")
        }
      },
      error = function(e) NULL
    )
  }

  drop_hook("onLoad", .maidr_quantmod_onload_hook)
  drop_hook("attach", .maidr_quantmod_attach_hook)
  drop_hook("onLoad", .maidr_vioplot_onload_hook, package = "vioplot")
  drop_hook("attach", .maidr_vioplot_attach_hook, package = "vioplot")
  drop_hook("onLoad", .maidr_wordcloud_onload_hook, package = "wordcloud")
  drop_hook("attach", .maidr_wordcloud_attach_hook, package = "wordcloud")
}

# Show startup message when package is attached via library()
.onAttach <- function(libname, pkgname) {
  if (!isTRUE(getOption("maidr.startup_message", TRUE))) {
    return(invisible(NULL))
  }

  packageStartupMessage(
    "maidr ", utils::packageVersion(pkgname), " loaded\n",
    "- ggplot2 plots open in the maidr interactive viewer automatically\n",
    "- Base R plots are recorded; call show() to open the viewer\n",
    "- Use maidr_off() to disable interception\n",
    "- Use options(maidr.auto_show = FALSE) to disable permanently\n",
    "- See ?maidr_off for more details"
  )

  # maidr is normally attached at position 2, ahead of anything loaded
  # earlier, so this only fires for an explicit library(maidr, pos = ...).
  # The common ordering problem - quantmod, vioplot or wordcloud attached
  # *after* maidr - is caught by their attach hooks instead.
  for (package in packages_masking_maidr()) {
    packageStartupMessage("maidr: ", mask_advice(package))
  }
}
