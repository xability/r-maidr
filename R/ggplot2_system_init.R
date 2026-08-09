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

#' Is quantmod attached ahead of maidr on the search path?
#'
#' `library(quantmod)` after `library(maidr)` puts `package:quantmod` in
#' front of `package:maidr`, so an unqualified `chartSeries()` binds to
#' quantmod's own function and maidr's recording wrapper is never entered.
#'
#' maidr deliberately does not reach into quantmod's namespace to win this
#' race: overwriting a foreign package's binding would also redirect
#' quantmod's *internal* `chartSeries()` calls through maidr's `...`-
#' forwarding wrapper, which corrupts the `match.call(expand.dots = TRUE)`
#' that quantmod relies on. maidr reports the condition instead.
#'
#' @return `TRUE` when both packages are attached and quantmod comes first.
#' @keywords internal
quantmod_masks_maidr <- function() {
  path <- search()
  quantmod_pos <- match("package:quantmod", path, nomatch = 0L)
  maidr_pos <- match("package:maidr", path, nomatch = 0L)
  quantmod_pos > 0L && maidr_pos > 0L && quantmod_pos < maidr_pos
}

#' Advice shown when quantmod masks maidr's chartSeries() wrapper
#'
#' Shared by `.onAttach`, the quantmod attach hook and the
#' "No Base R plots detected" errors so the wording stays in one place.
#'
#' @return A single advice string.
#' @keywords internal
quantmod_mask_advice <- function() {
  paste0(
    "'quantmod' is attached ahead of 'maidr' on the search path, so a bare ",
    "chartSeries() call goes straight to quantmod and is not recorded. ",
    "Attach 'quantmod' before 'maidr', or call maidr::chartSeries() ",
    "explicitly."
  )
}

#' Message for show()/save_html()/maidr_widget() with nothing recorded
#'
#' Names the quantmod masking case when it applies: the bare
#' "create a plot first" wording is actively misleading there, because the
#' user *did* draw a chart — it just went to quantmod unrecorded.
#'
#' @return The error message string.
#' @keywords internal
no_base_r_plots_message <- function() {
  message_text <- paste0(
    "No Base R plots detected. Please create a plot first ",
    "(e.g., barplot(), plot())."
  )

  if (quantmod_masks_maidr()) {
    message_text <- paste0(message_text, "\n", quantmod_mask_advice())
  }

  message_text
}

# Hook run when quantmod is *attached* (not merely loaded). By then quantmod
# sits ahead of maidr on the search path, so this is the moment to tell the
# user that bare chartSeries() calls will no longer be recorded. Named (not
# anonymous) so .onUnload can remove exactly this hook on unload.
.maidr_quantmod_attach_hook <- function(...) {
  tryCatch(
    {
      announce <- quantmod_masks_maidr() &&
        isTRUE(getOption("maidr.startup_message", TRUE))
      if (announce) {
        packageStartupMessage("maidr: ", quantmod_mask_advice())
      }
    },
    error = function(e) NULL
  )
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
      # Not critical — ggplot2 may not be installed
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
}

# Remove the quantmod onLoad hook installed in .onLoad so the package unloads
# cleanly without leaving global session state behind (CRAN policy).
.onUnload <- function(libpath) {
  drop_hook <- function(event, fn) {
    tryCatch(
      {
        ev <- packageEvent("quantmod", event)
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
  # The common ordering problem — quantmod attached *after* maidr — is
  # caught by .maidr_quantmod_attach_hook instead.
  if (quantmod_masks_maidr()) {
    packageStartupMessage("maidr: ", quantmod_mask_advice())
  }
}
