#' ggplot2 System Adapter
#'
#' Adapter for the ggplot2 plotting system. This adapter wraps the existing
#' ggplot2 functionality to work with the new extensible architecture.
#'
#' @format An R6 class inheriting from SystemAdapter
#' @keywords internal

Ggplot2Adapter <- R6::R6Class("Ggplot2Adapter",
  inherit = SystemAdapter,
  public = list(
    #' Initialize the ggplot2 adapter
    initialize = function() {
      super$initialize("ggplot2")
    },

    #' Check if this adapter can handle a plot object
    #' @param plot_object The plot object to check
    #' @return TRUE if this adapter can handle the object, FALSE otherwise
    can_handle = function(plot_object) {
      inherits(plot_object, "ggplot")
    },


    #' Detect the type of a single layer
    #' @param layer The ggplot2 layer object to analyze
    #' @param plot_object The parent plot object (for context)
    #' @return String indicating the layer type (e.g., "bar", "line", "point")
    detect_layer_type = function(layer, plot_object) {
      if (is.null(layer)) {
        return("unknown")
      }

      geom_class <- class(layer$geom)[1]
      stat_class <- class(layer$stat)[1]
      position_class <- class(layer$position)[1]

      if (geom_class %in% c("GeomLine", "GeomPath")) {
        return("line")
      }
      if (geom_class == "GeomSmooth" || stat_class == "StatDensity") {
        return("smooth")
      }

      if (geom_class %in% c("GeomBar", "GeomCol")) {
        if (stat_class == "StatBin") {
          return("hist")
        }

        if (position_class %in% c("PositionDodge", "PositionDodge2")) {
          return("dodged_bar")
        }

        if (position_class %in% c("PositionStack", "PositionFill")) {
          layer_mapping <- layer$mapping
          plot_mapping <- plot_object$mapping
          has_fill <- (!is.null(layer_mapping) && !is.null(layer_mapping$fill)) ||
            (!is.null(plot_mapping) && !is.null(plot_mapping$fill))
          if (has_fill) {
            return("stacked_bar")
          }
        }

        return("bar")
      }

      if (geom_class == "GeomTile") {
        return("heat")
      }

      if (geom_class == "GeomPoint") {
        return("point")
      }

      if (geom_class == "GeomBoxplot") {
        return("box")
      }

      if (geom_class == "GeomText") {
        return("skip")
      }

      return("unknown")
    },

    #' Create an orchestrator for this system (ggplot2)
    #' @param plot_object The ggplot2 plot object to process
    #' @return PlotOrchestrator instance
    create_orchestrator = function(plot_object) {
      if (!self$can_handle(plot_object)) {
        stop("Plot object is not a ggplot2 object")
      }

      # Use the existing PlotOrchestrator for ggplot2
      Ggplot2PlotOrchestrator$new(plot_object)
    },


    #' Get the system name
    #' @return System name string
    get_system_name = function() {
      self$system_name
    },

    #' Get a reference to this adapter (for use by orchestrator)
    #' @return Self reference
    get_adapter = function() {
      self
    },

    #' Check if plot has facets
    #' @param plot_object The ggplot2 plot object
    #' @return TRUE if plot has facets, FALSE otherwise
    has_facets = function(plot_object) {
      if (!self$can_handle(plot_object)) {
        return(FALSE)
      }

      facet_class <- class(plot_object$facet)[1]
      facet_class != "FacetNull"
    },

    #' Check if plot is a patchwork plot
    #' @param plot_object The ggplot2 plot object
    #' @return TRUE if plot is patchwork, FALSE otherwise
    is_patchwork = function(plot_object) {
      # Check if the plot object has patchwork attributes
      inherits(plot_object, "patchwork") ||
        !is.null(attr(plot_object, "patchwork"))
    }
  )
)
