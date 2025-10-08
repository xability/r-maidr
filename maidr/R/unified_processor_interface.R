#' Unified Processor Interface
#'
#' Abstract base class that defines the common interface for all plot processors
#' regardless of the plotting system (ggplot2, base R, lattice, etc.).
#'
#' @format An R6 class
#' @keywords internal

UnifiedProcessorInterface <- R6::R6Class("UnifiedProcessorInterface",
  public = list(
    #' Abstract method to extract data from plot object
    #' @param plot_object The plot object to process
    #' @param ... Additional arguments
    #' @return List of data points
    extract_data = function(plot_object, ...) {
      stop("extract_data method must be implemented by subclass")
    },

    #' Abstract method to generate CSS selectors for plot elements
    #' @param plot_object The plot object to process
    #' @param gtable The grob table (for ggplot2) or equivalent structure
    #' @param ... Additional arguments
    #' @return List of CSS selectors
    generate_selectors = function(plot_object, gtable, ...) {
      stop("generate_selectors method must be implemented by subclass")
    },

    #' Abstract method to create grob tree from plot object
    #' @param plot_object The plot object to process
    #' @return Grob tree or equivalent structure
    create_grob_tree = function(plot_object) {
      stop("create_grob_tree method must be implemented by subclass")
    },

    #' Abstract method to extract plot metadata
    #' @param plot_object The plot object to process
    #' @return List containing plot metadata
    get_plot_metadata = function(plot_object) {
      stop("get_plot_metadata method must be implemented by subclass")
    },

    #' Common processing workflow that calls all abstract methods
    #' @param plot_object The plot object to process
    #' @param ... Additional arguments
    #' @return List containing processed data, selectors, metadata, and grob tree
    process_plot = function(plot_object, ...) {
      list(
        data = self$extract_data(plot_object, ...),
        selectors = self$generate_selectors(plot_object, ...),
        metadata = self$get_plot_metadata(plot_object),
        gtable = self$create_grob_tree(plot_object)
      )
    }
  )
)
