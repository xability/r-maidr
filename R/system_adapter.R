#' System Adapter Base Class
#'
#' Abstract base class for adapting different plotting systems to the unified
#' maidr interface. Each plotting system (ggplot2, base R, lattice, etc.) should
#' have its own adapter implementation.
#'
#' @format An R6 class
#' @keywords internal

SystemAdapter <- R6::R6Class(
  "SystemAdapter",
  public = list(
    #' System name (e.g., "ggplot2", "base_r", "lattice")
    system_name = NULL,

    #' Initialize the adapter
    #' @param system_name Name of the plotting system
    initialize = function(system_name) {
      self$system_name <- system_name
    },

    #' Abstract method to check if this adapter can handle a plot object
    #' @param plot_object The plot object to check
    #' @return TRUE if this adapter can handle the object, FALSE otherwise
    can_handle = function(plot_object) {
      stop("can_handle method must be implemented by subclass")
    },

    #' Abstract method to create an orchestrator for this system
    #' @param plot_object The plot object to process
    #' @return Orchestrator instance specific to this system
    create_orchestrator = function(plot_object) {
      stop("create_orchestrator method must be implemented by subclass")
    }
  )
)
