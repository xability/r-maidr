#' Processor Factory Base Class
#'
#' @description
#' Abstract base class for creating processors specific to different plotting systems.
#' Each plotting system should have its own factory implementation that creates
#' the appropriate processors for different plot types.
#'
#' @format An R6 class
#' @keywords internal

ProcessorFactory <- R6::R6Class(
  "ProcessorFactory",
  public = list(
    #' @description Abstract method to create a processor for a specific plot type
    #' @param plot_type The type of plot (e.g., "bar", "line", "point")
    #' @param plot_object The plot object to process
    #' @return Processor instance for the specified plot type
    create_processor = function(plot_type, plot_object) {
      stop("create_processor method must be implemented by subclass")
    },

    #' @description Abstract method to get list of supported plot types
    #' @return Character vector of supported plot types
    get_supported_types = function() {
      stop("get_supported_types method must be implemented by subclass")
    },

    #' @description Check if a plot type is supported by this factory
    #' @param plot_type The plot type to check
    #' @return TRUE if supported, FALSE otherwise
    supports_plot_type = function(plot_type) {
      plot_type %in% self$get_supported_types()
    },

    #' @description Get system name (should be overridden by subclasses)
    #' @return System name string
    get_system_name = function() {
      "unknown"
    }
  )
)

#' Whether a name refers to a processor class this package ships
#'
#' The check used to be `exists(name, mode = "function")`, and a processor is
#' an R6 *generator* rather than a function, so it matched nothing --
#' `is.function(Ggplot2BarLayerProcessor)` is `FALSE` and
#' `class(...)` is `"R6ClassGenerator"`. Every entry a factory offered was
#' filtered out by it, so both factories reported an empty registry for every
#' processor they ship (#200).
#'
#' @param processor_class_name Name of the processor class.
#' @return `TRUE` when the name is an R6 generator that is reachable.
#' @keywords internal
processor_class_exists <- function(processor_class_name) {
  if (!is.character(processor_class_name) || length(processor_class_name) != 1) {
    return(FALSE)
  }
  exists(processor_class_name) &&
    inherits(get(processor_class_name), "R6ClassGenerator")
}

#' The processor classes a factory's `create_processor()` dispatches to
#'
#' Read off the method rather than kept beside it. The list a factory used to
#' return was written out by hand and consulted by nothing, so it drifted
#' freely: by the time #200 was filed it was missing four of the twenty
#' ggplot2 processors and one of the fourteen base R ones, and nothing in the
#' package or its tests could tell. A second list is a second thing to keep
#' true; asking the dispatch itself is one thing that cannot disagree with
#' itself.
#'
#' `deparse(body(...))` is used rather than reading `R/`, because an installed
#' package has no `R/` to read -- the sources are gone by then and only the
#' parsed function survives.
#'
#' @param generator The factory's `R6ClassGenerator`.
#' @param prefix The class-name prefix its processors share.
#' @return Character vector of class names, in the order first dispatched.
#' @keywords internal
dispatched_processor_classes <- function(generator, prefix) {
  method <- generator$public_methods$create_processor
  if (!is.function(method)) {
    return(character(0))
  }
  source <- paste(deparse(body(method)), collapse = "\n")
  pattern <- paste0(prefix, "[A-Za-z0-9]*Processor(?=\\$new)")
  unique(regmatches(source, gregexpr(pattern, source, perl = TRUE))[[1]])
}
