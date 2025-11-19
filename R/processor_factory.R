#' Processor Factory Base Class
#'
#' Abstract base class for creating processors specific to different plotting systems.
#' Each plotting system should have its own factory implementation that creates
#' the appropriate processors for different plot types.
#'
#' @format An R6 class
#' @keywords internal

ProcessorFactory <- R6::R6Class(
  "ProcessorFactory",
  public = list(
    #' Abstract method to create a processor for a specific plot type
    #' @param plot_type The type of plot (e.g., "bar", "line", "point")
    #' @param plot_object The plot object to process
    #' @return Processor instance for the specified plot type
    create_processor = function(plot_type, plot_object) {
      stop("create_processor method must be implemented by subclass")
    },

    #' Abstract method to get list of supported plot types
    #' @return Character vector of supported plot types
    get_supported_types = function() {
      stop("get_supported_types method must be implemented by subclass")
    },

    #' Check if a plot type is supported by this factory
    #' @param plot_type The plot type to check
    #' @return TRUE if supported, FALSE otherwise
    supports_plot_type = function(plot_type) {
      plot_type %in% self$get_supported_types()
    },

    #' Get system name (should be overridden by subclasses)
    #' @return System name string
    get_system_name = function() {
      "unknown"
    }
  )
)
