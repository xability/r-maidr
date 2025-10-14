#' Plot System Registry
#'
#' Central registry for managing different plotting systems and their adapters.
#' This registry allows dynamic registration and discovery of plotting systems
#' and their associated adapters and processor factories.
#'
#' @format An R6 class
#' @keywords internal

PlotSystemRegistry <- R6::R6Class("PlotSystemRegistry",
  private = list(
    #' Registered plotting systems
    .registered_systems = list(),

    #' System adapters
    .system_adapters = list(),

    #' Processor factories
    .processor_factories = list()
  ),
  public = list(
    #' Register a new plotting system
    #' @param system_name Name of the plotting system (e.g., "ggplot2", "base_r")
    #' @param adapter Adapter instance for this system
    #' @param processor_factory Processor factory instance for this system
    register_system = function(system_name, adapter, processor_factory) {
      # Validate inputs
      if (!inherits(adapter, "SystemAdapter")) {
        stop("Adapter must inherit from SystemAdapter")
      }
      if (!inherits(processor_factory, "ProcessorFactory")) {
        stop("Processor factory must inherit from ProcessorFactory")
      }

      # Register the system
      private$.registered_systems[[system_name]] <- system_name
      private$.system_adapters[[system_name]] <- adapter
      private$.processor_factories[[system_name]] <- processor_factory

      # Set system name in adapter and factory
      adapter$system_name <- system_name

      invisible(self)
    },

    #' Detect which system can handle a plot object
    #' @param plot_object The plot object to check
    #' @return System name if found, NULL otherwise
    detect_system = function(plot_object) {
      for (system_name in names(private$.registered_systems)) {
        adapter <- private$.system_adapters[[system_name]]
        if (adapter$can_handle(plot_object)) {
          return(system_name)
        }
      }
      return(NULL)
    },

    #' Get the adapter for a specific system
    #' @param system_name Name of the system
    #' @return Adapter instance
    get_adapter = function(system_name) {
      if (!system_name %in% names(private$.system_adapters)) {
        stop("System '", system_name, "' is not registered")
      }
      private$.system_adapters[[system_name]]
    },

    #' Get the processor factory for a specific system
    #' @param system_name Name of the system
    #' @return Processor factory instance
    get_processor_factory = function(system_name) {
      if (!system_name %in% names(private$.processor_factories)) {
        stop("System '", system_name, "' is not registered")
      }
      private$.processor_factories[[system_name]]
    },

    #' Get the adapter for a plot object (auto-detect system)
    #' @param plot_object The plot object
    #' @return Adapter instance
    get_adapter_for_plot = function(plot_object) {
      system_name <- self$detect_system(plot_object)
      if (is.null(system_name)) {
        stop("No registered system can handle this plot object")
      }
      self$get_adapter(system_name)
    },

    #' Get the processor factory for a plot object (auto-detect system)
    #' @param plot_object The plot object
    #' @return Processor factory instance
    get_processor_factory_for_plot = function(plot_object) {
      system_name <- self$detect_system(plot_object)
      if (is.null(system_name)) {
        stop("No registered system can handle this plot object")
      }
      self$get_processor_factory(system_name)
    },

    #' List all registered systems
    #' @return Character vector of registered system names
    list_systems = function() {
      names(private$.registered_systems)
    },

    #' Check if a system is registered
    #' @param system_name Name of the system
    #' @return TRUE if registered, FALSE otherwise
    is_system_registered = function(system_name) {
      system_name %in% names(private$.registered_systems)
    },

    #' Unregister a system
    #' @param system_name Name of the system to unregister
    unregister_system = function(system_name) {
      if (system_name %in% names(private$.registered_systems)) {
        private$.registered_systems[[system_name]] <- NULL
        private$.system_adapters[[system_name]] <- NULL
        private$.processor_factories[[system_name]] <- NULL
      }
      invisible(self)
    }
  )
)

# Global registry instance
global_registry <- NULL

#' Get the global plot system registry
#' @return PlotSystemRegistry instance
#' @keywords internal
get_global_registry <- function() {
  if (is.null(global_registry)) {
    global_registry <<- PlotSystemRegistry$new()
  }
  global_registry
}

#' Reset the global registry (mainly for testing)
#' @keywords internal
reset_global_registry <- function() {
  global_registry <<- NULL
}
