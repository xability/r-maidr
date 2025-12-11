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
BaseRPlotOrchestrator <- R6::R6Class(
  "BaseRPlotOrchestrator",
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

      layer_counter <- 0

      for (group_idx in seq_along(plot_groups)) {
        group <- plot_groups[[group_idx]]
        high_call <- group$high_call

        # LAYER 1: HIGH-level call
        layer_counter <- layer_counter + 1
        high_layer_type <- private$.adapter$detect_layer_type(high_call)

        private$.layers[[layer_counter]] <- list(
          index = layer_counter,
          type = high_layer_type,
          function_name = high_call$function_name,
          args = high_call$args,
          call_expr = high_call$call_expr,
          plot_call = high_call,
          group = group,
          group_index = group_idx,
          source = "HIGH"
        )

        # LAYERS 2+: LOW-level calls (NEW)
        if (length(group$low_calls) > 0) {
          for (low_idx in seq_along(group$low_calls)) {
            low_call <- group$low_calls[[low_idx]]
            low_layer_type <- private$.adapter$detect_layer_type(low_call)

            # Only create layer if we can identify its type
            if (low_layer_type != "unknown") {
              layer_counter <- layer_counter + 1

              private$.layers[[layer_counter]] <- list(
                index = layer_counter,
                type = low_layer_type,
                function_name = low_call$function_name,
                args = low_call$args,
                call_expr = low_call$call_expr,
                plot_call = low_call,
                group = group,
                group_index = group_idx,
                source = "LOW",
                low_call_index = low_idx
              )
            }
          }
        }
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

      registry <- get_global_registry()
      system_name <- private$.adapter$get_system_name()
      factory <- registry$get_processor_factory(system_name)

      processor <- factory$create_processor(layer_type, layer_info)

      processor
    },
    process_layers = function() {
      private$.layout <- self$extract_layout()

      layer_results <- list()
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]

        layer_grob <- self$get_grob_for_layer(i)

        # Pass grob to processor (similar to ggplot2 passing gt)
        # For Base R, we don't have a built plot object like ggplot2
        # We pass the layer info directly and the grob for selector generation
        result <- processor$process(
          NULL,
          private$.layout,
          layer_info = private$.layers[[i]],
          gt = layer_grob
        )
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
      panel_config <- detect_panel_configuration(private$.device_id)

      if (
        !is.null(panel_config) &&
          panel_config$type %in% c("mfrow", "mfcol") &&
          (panel_config$nrows > 1 || panel_config$ncols > 1)
      ) {
        # Multipanel case - create 2D grid
        nrows <- panel_config$nrows
        ncols <- panel_config$ncols

        subplot_grid <- vector("list", nrows)
        for (r in seq_len(nrows)) {
          subplot_grid[[r]] <- vector("list", ncols)
        }

        # Map layers to panels based on their group index
        for (i in seq_along(layer_results)) {
          result <- layer_results[[i]]
          layer_info <- private$.layers[[i]]
          group_idx <- layer_info$group_index

          if (panel_config$type == "mfrow") {
            # Row-major order
            row <- ceiling(group_idx / ncols)
            col <- ((group_idx - 1) %% ncols) + 1
          } else {
            # Column-major order (mfcol)
            col <- ceiling(group_idx / nrows)
            row <- ((group_idx - 1) %% nrows) + 1
          }

          # Ensure we're within bounds
          if (row > nrows || col > ncols) {
            next
          }

          layer_type <- result$type
          if (is.null(layer_type) || length(layer_type) == 0) {
            layer_type <- private$.adapter$detect_layer_type(layer_info$plot_call)
          }

          layer_obj <- list(
            id = paste0("maidr-layer-", i),
            selectors = result$selectors,
            type = layer_type,
            data = result$data,
            title = if (!is.null(result$title)) result$title else "",
            axes = if (!is.null(result$axes)) result$axes else list(x = "", y = "")
          )

          if (!is.null(result$labels) && length(result$labels) > 0) {
            layer_obj$labels <- result$labels
          }

          if (is.null(subplot_grid[[row]][[col]])) {
            subplot_grid[[row]][[col]] <- list(
              id = paste0("maidr-subplot-", row, "-", col),
              layers = list()
            )
          }

          subplot_grid[[row]][[col]]$layers <- append(
            subplot_grid[[row]][[col]]$layers,
            list(layer_obj)
          )
        }

        private$.combined_data <- subplot_grid

        # Collect all selectors
        combined_selectors <- list()
        for (result in layer_results) {
          combined_selectors <- c(combined_selectors, result$selectors)
        }
        private$.combined_selectors <- combined_selectors
      } else {
        # Single panel case - original logic
        combined_data <- list()

        for (i in seq_along(layer_results)) {
          result <- layer_results[[i]]

          layer_type <- result$type
          if (is.null(layer_type) || length(layer_type) == 0) {
            layer_info <- private$.layers[[i]]
            layer_type <- private$.adapter$detect_layer_type(layer_info$plot_call)
          }

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
          id = paste0("maidr-subplot-", generate_unique_id()),
          layers = combined_data
        )
        private$.combined_data <- list(list(single_subplot))

        private$.combined_selectors <- combined_selectors
      }
    },
    generate_maidr_data = function() {
      # Base R plots use the same unified structure as ggplot2
      list(
        id = paste0("maidr-plot-", generate_unique_id()),
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

      # Suppress native R graphics window by using a null PDF device
      # This ensures only the HTML output is displayed
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = 7, height = 5)
      on.exit(
        {
          grDevices::dev.off()
          if (current_dev > 1) grDevices::dev.set(current_dev)
          unlink(null_pdf)
        },
        add = TRUE
      )

      panel_config <- detect_panel_configuration(private$.device_id)

      if (
        !is.null(panel_config) &&
          panel_config$type %in% c("mfrow", "mfcol") &&
          (panel_config$nrows > 1 || panel_config$ncols > 1)
      ) {
        # Multipanel case - create composite grob
        composite_func <- function() {
          if (panel_config$type == "mfrow") {
            graphics::par(mfrow = c(panel_config$nrows, panel_config$ncols))
          } else if (panel_config$type == "mfcol") {
            graphics::par(mfcol = c(panel_config$nrows, panel_config$ncols))
          }

          # Debug logging
          if (getOption("maidr.debug", FALSE)) {
            cat("DEBUG: Replaying", length(private$.plot_groups), "plot groups\n")
            cat("DEBUG: Panel config:", panel_config$nrows, "x", panel_config$ncols, "\n")
          }

          # Replay all plot groups
          for (i in seq_along(private$.plot_groups)) {
            group <- private$.plot_groups[[i]]

            if (getOption("maidr.debug", FALSE)) {
              cat("DEBUG: Replaying group", i, "-", group$high_call$function_name, "\n")
            }

            invisible(do.call(group$high_call$function_name, group$high_call$args))

            if (length(group$low_calls) > 0) {
              for (low_call in group$low_calls) {
                invisible(do.call(low_call$function_name, low_call$args))
              }
            }
          }
        }

        tryCatch(
          {
            composite_grob <- ggplotify::as.grob(composite_func)

            # Also store individual grobs for reference
            private$.grob_list <- list(composite_grob)

            return(composite_grob)
          },
          error = function(e) {
            warning("Failed to create multipanel grob: ", e$message)
            NULL
          }
        )
      } else {
        # Single panel case - original logic
        grob_list <- list()

        for (i in seq_along(private$.plot_groups)) {
          group <- private$.plot_groups[[i]]
          high_call <- group$high_call
          low_calls <- group$low_calls

          plot_func <- function() {
            invisible(do.call(high_call$function_name, high_call$args))

            if (length(low_calls) > 0) {
              for (low_call in low_calls) {
                invisible(do.call(low_call$function_name, low_call$args))
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

        private$.grob_list <- grob_list

        if (length(grob_list) > 0 && !is.null(grob_list[[1]])) {
          return(grob_list[[1]])
        }

        NULL
      }
    },
    get_grob_for_layer = function(layer_index) {
      if (layer_index < 1 || layer_index > length(private$.layers)) {
        return(NULL)
      }

      if (length(private$.grob_list) == 0) {
        self$get_gtable()
      }

      panel_config <- detect_panel_configuration(private$.device_id)
      is_multipanel <- !is.null(panel_config) &&
        panel_config$type %in% c("mfrow", "mfcol") &&
        (panel_config$nrows > 1 || panel_config$ncols > 1)

      if (is_multipanel) {
        # For multipanel, all layers share the same composite grob
        # The processors will use group_index to find their specific elements
        if (length(private$.grob_list) > 0) {
          return(private$.grob_list[[1]])
        }
      } else {
        # For single panel, return the grob for this layer's group
        layer_info <- private$.layers[[layer_index]]
        group_index <- layer_info$group_index

        if (group_index <= length(private$.grob_list)) {
          return(private$.grob_list[[group_index]])
        }
      }

      NULL
    },

    #' @description Check if any layers are unsupported (unknown type)
    #' @return Logical indicating if there are unsupported layers
    has_unsupported_layers = function() {
      if (length(private$.layers) == 0) {
        return(FALSE)
      }

      any(sapply(private$.layers, function(layer) {
        isTRUE(layer$type == "unknown")
      }))
    },

    #' @description Determine if the plot should fall back to image rendering
    #' @return Logical indicating if fallback should be used
    should_fallback = function() {
      # Check if fallback is enabled globally
      if (!is_fallback_enabled()) {
        return(FALSE)
      }

      # Check if we have unsupported layers
      self$has_unsupported_layers()
    }
  )
)
