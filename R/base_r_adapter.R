#' Base R System Adapter
#'
#' Adapter for the Base R plotting system. This adapter uses function patching
#' to intercept Base R plotting calls and detect plot types.
#'
#' @format An R6 class inheriting from SystemAdapter
#' @keywords internal

BaseRAdapter <- R6::R6Class("BaseRAdapter",
  inherit = SystemAdapter,
  public = list(
    #' Initialize the Base R adapter
    initialize = function() {
      super$initialize("base_r")
    },

    #' Check if this adapter can handle a plot object
    #' @param plot_object The plot object to check (should be NULL for Base R)
    #' @return TRUE if Base R plotting is active, FALSE otherwise
    can_handle = function(plot_object) {
      active <- is_patching_active()
      device_id <- grDevices::dev.cur()
      has_calls <- has_device_calls(device_id)
      calls_count <- length(get_device_calls(device_id))
      can_handle_result <- active && has_calls
      return(can_handle_result)
    },

    #' Detect the type of a single layer from Base R plot calls
    #' @param layer The plot call entry from our logger
    #' @param plot_object The parent plot object (NULL for Base R)
    #' @return String indicating the layer type (e.g., "bar", "dodged_bar",
    #'   "stacked_bar", "smooth", "line", "point")
    detect_layer_type = function(layer, plot_object = NULL) {
      if (is.null(layer)) {
        return("unknown")
      }

      function_name <- layer$function_name
      args <- layer$args

      # HIGH-level function detection
      layer_type <- switch(function_name,
        "barplot" = {
          if (self$is_dodged_barplot(args)) {
            "dodged_bar"
          } else if (self$is_stacked_barplot(args)) {
            "stacked_bar"
          } else {
            "bar"
          }
        },
        "plot" = {
          first_arg <- args[[1]]
          if (!is.null(first_arg) && inherits(first_arg, "density")) {
            "smooth"
          } else {
            "line"
          }
        },
        "hist" = "hist",
        "boxplot" = "box",
        "image" = "heat",
        "contour" = "contour",
        "matplot" = "line",
        NULL
      )

      if (!is.null(layer_type)) {
        return(layer_type)
      }

      # LOW-level function detection (NEW)
      layer_type <- switch(function_name,
        "lines" = {
          first_arg <- args[[1]]
          if (!is.null(first_arg) && inherits(first_arg, "density")) {
            "smooth"
          } else {
            "line"
          }
        },
        "points" = "point",
        "abline" = "line",
        "polygon" = "polygon",
        "unknown"
      )

      return(layer_type)
    },

    #' Check if a barplot call represents a dodged bar plot
    #' @param args The arguments from the barplot call
    #' @return TRUE if this is a dodged bar plot, FALSE otherwise
    is_dodged_barplot = function(args) {
      # Get height data (first argument)
      height <- args[[1]]
      beside <- args$beside

      # Check if height is a matrix
      is_matrix <- is.matrix(height) || (is.array(height) && length(dim(height)) == 2)

      # Check beside parameter
      # For matrices, beside = TRUE creates dodged bars
      beside_true <- if (is.null(beside)) FALSE else beside

      return(is_matrix && beside_true)
    },

    #' Check if a barplot call represents a stacked bar plot
    #' @param args The arguments from the barplot call
    #' @return TRUE if this is a stacked bar plot, FALSE otherwise
    is_stacked_barplot = function(args) {
      # Get height data (first argument)
      height <- args[[1]]
      beside <- args$beside

      # Check if height is a matrix
      is_matrix <- is.matrix(height) || (is.array(height) && length(dim(height)) == 2)

      # Check beside parameter
      # For matrices, beside = FALSE creates stacked bars
      beside_false <- if (is.null(beside)) FALSE else !beside

      return(is_matrix && beside_false)
    },

    #' Create an orchestrator for this system (Base R)
    #' @param plot_object The plot object to process (NULL for Base R)
    #' @return PlotOrchestrator instance
    create_orchestrator = function(plot_object = NULL) {
      if (!self$can_handle(plot_object)) {
        stop("Base R plotting system is not active or no plot calls recorded")
      }

      device_id <- grDevices::dev.cur()
      BaseRPlotOrchestrator$new(device_id = device_id)
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

    #' Check if plot has facets (Base R doesn't support facets)
    #' @param plot_object The plot object (ignored for Base R)
    #' @return FALSE (Base R doesn't support facets)
    has_facets = function(plot_object = NULL) {
      FALSE
    },

    #' Check if plot is a patchwork plot (Base R doesn't support patchwork)
    #' @param plot_object The plot object (ignored for Base R)
    #' @return FALSE (Base R doesn't support patchwork)
    is_patchwork = function(plot_object = NULL) {
      FALSE
    },

    #' Get recorded plot calls for processing
    #' @param device_id Graphics device ID (defaults to current device)
    #' @return List of recorded plot calls
    get_plot_calls = function(device_id = grDevices::dev.cur()) {
      get_device_calls(device_id)
    },

    #' Clear recorded plot calls (for cleanup)
    #' @param device_id Graphics device ID (defaults to current device)
    clear_plot_calls = function(device_id = grDevices::dev.cur()) {
      clear_device_storage(device_id)
    },

    #' Initialize function patching
    #' @return NULL (invisible)
    initialize_patching = function() {
      initialize_base_r_patching()
      invisible(NULL)
    },

    #' Restore original functions
    #' @return NULL (invisible)
    restore_functions = function() {
      restore_original_functions()
      invisible(NULL)
    }
  )
)
