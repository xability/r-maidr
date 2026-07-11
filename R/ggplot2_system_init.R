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
}

# Remove the quantmod onLoad hook installed in .onLoad so the package unloads
# cleanly without leaving global session state behind (CRAN policy).
.onUnload <- function(libpath) {
  tryCatch(
    {
      ev <- packageEvent("quantmod", "onLoad")
      hooks <- getHook(ev)
      if (length(hooks)) {
        keep <- !vapply(
          hooks, identical, logical(1), .maidr_quantmod_onload_hook
        )
        setHook(ev, hooks[keep], action = "replace")
      }
    },
    error = function(e) NULL
  )
}

# Show startup message when package is attached via library()
.onAttach <- function(libname, pkgname) {
  if (!isTRUE(getOption("maidr.startup_message", TRUE))) {
    return(invisible(NULL))
  }

  packageStartupMessage(
    "maidr ", utils::packageVersion(pkgname), " loaded\n",
    "- Plots are displayed in the maidr interactive viewer by default\n",
    "- Use maidr_off() to disable interception\n",
    "- Use options(maidr.auto_show = FALSE) to disable permanently\n",
    "- See ?maidr_off for more details"
  )
}
