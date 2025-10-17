#' ggplot2 System Initialization
#'
#' Initialize and register the ggplot2 system with the global registry.
#' This function sets up the ggplot2 adapter and processor factory.
#'
#' @keywords internal
#' @return NULL (invisible)

initialize_ggplot2_system <- function() {
  # Get the global registry
  registry <- get_global_registry()

  # Check if ggplot2 system is already registered
  if (registry$is_system_registered("ggplot2")) {
    return(invisible(NULL))
  }

  # Create ggplot2 adapter
  ggplot2_adapter <- Ggplot2Adapter$new()

  # Create ggplot2 processor factory
  ggplot2_factory <- Ggplot2ProcessorFactory$new()

  # Register the system
  registry$register_system("ggplot2", ggplot2_adapter, ggplot2_factory)

  invisible(NULL)
}

# Auto-initialize ggplot2 system when package is loaded
.onLoad <- function(libname, pkgname) {
  # Initialize ggplot2 system
  tryCatch(
    {
      initialize_ggplot2_system()
    },
    error = function(e) {
      warning("Failed to initialize ggplot2 system: ", e$message)
    }
  )

  # Initialize Base R system
  tryCatch(
    {
      initialize_base_r_system()
    },
    error = function(e) {
      warning("Failed to initialize Base R system: ", e$message)
    }
  )

  # Auto-start Base R patching
  tryCatch(
    {
      initialize_base_r_patching()
    },
    error = function(e) {
      warning("Failed to initialize Base R patching: ", e$message)
    }
  )
}
