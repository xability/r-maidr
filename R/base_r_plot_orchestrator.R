#' Base R Plot Orchestrator Class
#'
#' This class orchestrates the detection and processing of multiple layers
#' in Base R plots. It analyzes each recorded plot call individually and combines
#' the results into a comprehensive interactive plot.
#'
#' @field plot_calls List of recorded Base R plot calls
#' @field layers List of detected layer information
#' @field layer_processors List of layer-specific processors
#' @field combined_data Combined data from all layers
#' @field combined_selectors Combined selectors from all layers
#' @field layout Layout information from the plot
#'
#' @keywords internal
BaseRPlotOrchestrator <- R6::R6Class("BaseRPlotOrchestrator",
  private = list(
    .plot_calls = list(),
    .plot_groups = list(),
    .device_id = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .combined_selectors = list(),
    .layout = NULL,
    .adapter = NULL,
    .grob_list = list()
  ),
  public = list(
    initialize = function(device_id = grDevices::dev.cur()) {
      private$.device_id <- device_id
      registry <- get_global_registry()
      private$.adapter <- registry$get_adapter("base_r")

      private$.plot_calls <- get_device_calls(device_id)

      grouped <- group_device_calls(device_id)
      private$.plot_groups <- grouped$groups

      self$detect_layers()
      self$create_layer_processors()
      self$process_layers()
    },
    detect_layers = function() {
      plot_groups <- private$.plot_groups
      private$.layers <- list()

      if (length(plot_groups) == 0) {
        return(invisible(NULL))
      }

      for (i in seq_along(plot_groups)) {
        group <- plot_groups[[i]]
        high_call <- group$high_call

        layer_info <- self$analyze_single_layer(high_call, i, group)
        private$.layers[[i]] <- layer_info
      }
    },
    analyze_single_layer = function(plot_call, layer_index, group = NULL) {
      function_name <- plot_call$function_name
      args <- plot_call$args
      call_expr <- plot_call$call_expr

      layer_type <- private$.adapter$detect_layer_type(plot_call)

      layer_info <- list(
        index = layer_index,
        type = layer_type,
        function_name = function_name,
        args = args,
        call_expr = call_expr,
        plot_call = plot_call,
        group = group
      )

      layer_info
    },
    create_layer_processors = function() {
      private$.layer_processors <- list()

      for (i in seq_along(private$.layers)) {
        layer_info <- private$.layers[[i]]
        # Skip layers that don't need processing
        if (layer_info$type != "unknown") {
          processor <- self$create_layer_processor(layer_info)
          private$.layer_processors[[i]] <- processor
        }
      }
    },
    create_layer_processor = function(layer_info) {
      # Use unified layer processor creation logic
      self$create_unified_layer_processor(layer_info)
    },

    #' Unified layer processor creation - used by all plot types
    #' @param layer_info Layer information
    #' @return Layer processor instance
    create_unified_layer_processor = function(layer_info) {
      layer_type <- layer_info$type

      # Get the processor factory from the registry
      registry <- get_global_registry()
      system_name <- private$.adapter$get_system_name()
      factory <- registry$get_processor_factory(system_name)

      # Create processor using the factory
      processor <- factory$create_processor(layer_type, layer_info)

      processor
    },
    process_layers = function() {
      private$.layout <- self$extract_layout()

      layer_results <- list()
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]

        # Get the grob for this layer (convert from plot call if needed)
        layer_grob <- self$get_grob_for_layer(i)

        # Pass grob to processor (similar to ggplot2 passing gt)
        # For Base R, we don't have a built plot object like ggplot2
        # We pass the layer info directly and the grob for selector generation
        result <- processor$process(NULL, private$.layout, layer_info = private$.layers[[i]], gt = layer_grob)
        processor$set_last_result(result)
        layer_results[[i]] <- result
      }

      self$combine_layer_results(layer_results)
    },
    extract_layout = function() {
      # For Base R, we extract layout from the recorded plot calls
      # This is a simplified version - in practice, we might need to
      # analyze the plot calls more carefully to extract titles, axis labels, etc.

      layout <- list(
        title = "", # TODO: Extract from plot calls
        axes = list(
          x = "", # TODO: Extract from plot calls
          y = "" # TODO: Extract from plot calls
        )
      )

      layout
    },
    combine_layer_results = function(layer_results) {
      combined_data <- list()

      for (i in seq_along(layer_results)) {
        result <- layer_results[[i]]

        # Get layer type from the result
        layer_type <- result$type
        if (is.null(layer_type) || length(layer_type) == 0) {
          layer_info <- private$.layers[[i]]
          layer_type <- private$.adapter$detect_layer_type(layer_info$plot_call)
        }

        # Create layer object with standard structure
        layer_obj <- list(
          id = i,
          selectors = result$selectors,
          type = layer_type,
          data = result$data,
          title = result$title,
          axes = result$axes
        )

        # Preserve all other fields from the processor result
        for (field_name in names(result)) {
          if (!field_name %in% c("selectors", "data", "title", "axes", "labels")) {
            layer_obj[[field_name]] <- result[[field_name]]
          }
        }

        # Add labels if they exist and are not empty
        if (!is.null(result$labels) && length(result$labels) > 0) {
          layer_obj$labels <- result$labels
        }

        combined_data[[i]] <- layer_obj
      }

      combined_selectors <- list()
      for (result in layer_results) {
        combined_selectors <- c(combined_selectors, result$selectors)
      }

      # For Base R, create single plot structure
      single_subplot <- list(
        id = paste0("maidr-subplot-", as.integer(Sys.time())),
        layers = combined_data
      )
      private$.combined_data <- list(list(single_subplot))

      private$.combined_selectors <- combined_selectors
    },
    generate_maidr_data = function() {
      # Base R plots use the same unified structure as ggplot2
      list(
        id = paste0("maidr-plot-", as.integer(Sys.time())),
        subplots = private$.combined_data
      )
    },
    get_layout = function() {
      private$.layout
    },
    get_combined_data = function() {
      private$.combined_data
    },
    get_layer_processors = function() {
      private$.layer_processors
    },
    get_layers = function() {
      private$.layers
    },
    get_plot_calls = function() {
      private$.plot_calls
    },
    get_gtable = function() {

      if (length(private$.plot_groups) == 0) {
        return(NULL)
      }

      grob_list <- list()

      for (i in seq_along(private$.plot_groups)) {
        group <- private$.plot_groups[[i]]
        high_call <- group$high_call
        low_calls <- group$low_calls

        plot_func <- function() {
          do.call(high_call$function_name, high_call$args)

          if (length(low_calls) > 0) {
            for (low_call in low_calls) {
              do.call(low_call$function_name, low_call$args)
            }
          }
        }

        tryCatch(
          {
            grob <- ggplotify::as.grob(plot_func)
            grob_list[[i]] <- grob
          },
          error = function(e) {
            grob_list[[i]] <- NULL
          }
        )
      }

      # Store the grob list for use by get_grob_for_layer
      private$.grob_list <- grob_list

      # Return the first grob as the main gtable (for compatibility)
      if (length(grob_list) > 0 && !is.null(grob_list[[1]])) {
        return(grob_list[[1]])
      }

      return(NULL)
    },
    get_grob_for_layer = function(layer_index) {
      if (layer_index < 1 || layer_index > length(private$.plot_groups)) {
        return(NULL)
      }

      if (length(private$.grob_list) == 0) {
        self$get_gtable()
      }

      if (layer_index <= length(private$.grob_list)) {
        return(private$.grob_list[[layer_index]])
      }

      return(NULL)
    }
  )
)
