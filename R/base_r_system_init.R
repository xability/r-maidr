#' Base R System Initialization
#'
#' Initialize and register the Base R system with the global registry.
#' This function sets up the Base R adapter and processor factory.
#'
#' @keywords internal
#' @return NULL (invisible)

initialize_base_r_system <- function() {
  registry <- get_global_registry()

  if (registry$is_system_registered("base_r")) {
    return(invisible(NULL))
  }

  base_r_adapter <- BaseRAdapter$new()

  base_r_factory <- BaseRProcessorFactory$new()

  # Register the system
  registry$register_system("base_r", base_r_adapter, base_r_factory)

  invisible(NULL)
}

# Auto-initialize Base R system when package is loaded
# Note: This will be called after the ggplot2 system initialization
# We need to override the .onLoad function from ggplot2_system_init.R
# So we'll call this from the main .onLoad function
