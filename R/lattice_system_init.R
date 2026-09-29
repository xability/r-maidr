#' lattice System Initialization
#'
#' Initialize and register the lattice system with the global registry.
#' This function sets up the lattice adapter and processor factory.
#'
#' Registered between ggplot2 and Base R. The order matters less than it
#' did: the Base R adapter used to claim any object whenever the current
#' device held a recorded call, so a trellis object reached it first and was
#' silently exported as the recorded Base R chart. It now declines the
#' objects another system draws (`BaseRAdapter$can_handle()`), and the order
#' is kept as a second line of defence.
#'
#' @keywords internal
#' @return NULL (invisible)
initialize_lattice_system <- function() {
  registry <- get_global_registry()

  if (registry$is_system_registered("lattice")) {
    return(invisible(NULL))
  }

  lattice_adapter <- LatticeAdapter$new()

  lattice_factory <- LatticeProcessorFactory$new()

  registry$register_system("lattice", lattice_adapter, lattice_factory)

  invisible(NULL)
}
