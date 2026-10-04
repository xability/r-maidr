#' Base R Plot Orchestrator Class
#'
#' @description
#' This class orchestrates the detection and processing of multiple layers
#' in Base R plots. It analyzes each recorded plot call individually and combines
#' the results into a comprehensive interactive plot.
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
    .grob_list = list(),
    .format_config = NULL,
    .format_config_by_group = list(),
    .cached_gtable = NULL,
    .fallback_mode = "none",
    .fallback_groups = integer(0),
    .fallback_panels = integer(0),
    .canvas = NULL,

    # The one result that declares its own subplot grid, or NULL.
    #
    # `pairs()` is the case: it draws an `n x n` matrix of panels, sets its
    # own `par(mfrow)` internally and restores it, so nothing reaches the
    # device's layout calls and `detect_panel_configuration()` sees a single
    # panel (#272). The grid has to come from the reading.
    #
    # Only when it is the *only* result. A call that takes over the device's
    # layout is by construction the whole page, and a second chart beside it
    # would have no cell of its own to go in -- so a mixed page falls through
    # to the ordinary path, where the grid-declaring result carries no `type`
    # and is skipped, leaving the figure on the static fallback rather than
    # in a grid that describes half of it.
    declared_grid = function(layer_results) {
      present <- Filter(Negate(is.null), layer_results)
      if (length(present) != 1) {
        return(NULL)
      }
      result <- present[[1]]
      if (!isTRUE(result$multi_panel) || !length(result$panels)) {
        return(NULL)
      }
      if (!is.numeric(result$nrows) || !is.numeric(result$ncols)) {
        return(NULL)
      }
      result
    },

    # The subplot grid a declaring result asks for.
    #
    # A cell it named no layer for stays empty rather than absent: the
    # orchestrator's own note for the layout() case applies unchanged -- "a
    # bare NULL serializes as `{}`, which the maidr frontend cannot parse" --
    # and a scatterplot matrix's diagonal is exactly that cell, drawing the
    # variable's name and no marks.
    build_declared_grid = function(result) {
      grid <- vector("list", result$nrows)
      for (r in seq_len(result$nrows)) {
        grid[[r]] <- vector("list", result$ncols)
        for (c_idx in seq_len(result$ncols)) {
          grid[[r]][[c_idx]] <- list(
            id = paste0("maidr-subplot-", r, "-", c_idx),
            layers = list()
          )
        }
      }

      counter <- 0
      for (panel in result$panels) {
        row <- panel$row
        col <- panel$col
        if (row < 1 || col < 1 || row > result$nrows || col > result$ncols) {
          next
        }
        for (layer in panel$layers) {
          counter <- counter + 1
          layer_axes <- if (!is.null(layer$axes)) layer$axes else build_axes()
          validate_axes(layer_axes, context = "base_r orchestrator (declared grid)")
          layer_obj <- list(
            id = paste0("maidr-layer-", counter),
            selectors = layer$selectors,
            type = layer$type,
            data = layer$data,
            title = if (!is.null(layer$title)) layer$title else "",
            axes = layer_axes
          )
          for (field_name in names(layer)) {
            if (!field_name %in% c("selectors", "data", "title", "axes", "type")) {
              layer_obj[[field_name]] <- layer[[field_name]]
            }
          }
          grid[[row]][[col]]$layers <- append(
            grid[[row]][[col]]$layers, list(layer_obj)
          )
        }
      }

      grid
    }
  ),
  public = list(
    #' @description Create an orchestrator for the calls recorded on a device
    #' @param device_id Graphics device ID
    #' @param width,height The size to draw the chart at, in inches, or `NULL`
    #'   for maidr's own; see [chart_canvas_size()]
    initialize = function(device_id = grDevices::dev.cur(), width = NULL, height = NULL) {
      private$.device_id <- device_id
      registry <- get_global_registry()
      private$.adapter <- registry$get_adapter("base_r")

      private$.plot_calls <- get_device_calls(device_id)

      grouped <- group_device_calls(device_id)
      private$.plot_groups <- grouped$groups

      # Settled before anything is drawn: the recorded calls are drawn again
      # at this size (see `get_gtable()`). A chartSeries() chart is held to
      # the candlestick minimum, whose layout it is.
      has_chartseries <- any(vapply(
        private$.plot_groups,
        function(g) identical(g$high_call$function_name, "chartSeries"),
        logical(1)
      ))
      private$.canvas <- chart_canvas_size(width, height, candlestick = has_chartseries)

      self$detect_layers()
      self$resolve_fallback_scope()
      self$create_layer_processors()
      self$process_layers()
    },
    #' @description Turn each recorded plot group into layer entries: one for its HIGH-level call
    #'   and one per LOW-level overlay
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

            # Include ALL low-level calls, including "unknown" ones
            # This allows has_unsupported_layers() to detect them and trigger fallback
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
    },
    #' @description Describe one recorded call as a layer entry with its detected type
    #' @param plot_call The recorded call
    #' @param layer_index Index of the layer
    #' @param group The recorded plot group holding the HIGH-level call
    #' @return Layer information list
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
    #' @description Create a processor for every layer of a known type
    create_layer_processors = function() {
      # Pre-allocate list to avoid sparse list issues
      # In R, list[[i]] <- NULL deletes instead of setting NULL
      n_layers <- length(private$.layers)
      private$.layer_processors <- vector("list", n_layers)

      for (i in seq_along(private$.layers)) {
        layer_info <- private$.layers[[i]]
        # Only create processors for known types; unknown stays NULL (pre-allocated)
        if (layer_info$type != "unknown") {
          processor <- self$create_layer_processor(layer_info)
          private$.layer_processors[[i]] <- processor
        }
        # Unknown types keep their pre-allocated NULL value
      }
    },
    #' @description Create the processor for one layer
    #' @param layer_info Layer information with the recorded call
    #' @return A layer processor, or NULL for an unknown type
    create_layer_processor = function(layer_info) {
      # Use unified layer processor creation logic
      self$create_unified_layer_processor(layer_info)
    },

    #' @description Unified layer processor creation - used by all plot types
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
    #' @description Run every layer processor and combine the results
    process_layers = function() {
      private$.layout <- self$extract_layout()

      # Extract format config from axis() calls
      private$.format_config <- self$extract_format_config_from_axis_calls()

      # A multipanel replay redraws only the panel-visible groups, so the
      # exported SVG numbers its panels 1..n in replay order. A skipped
      # group (drawn before the layout call, or on an earlier page) shifts
      # every later group's panel number down, so processors have to look
      # up their grobs by panel SLOT, not by the group's own index.
      panel_config <- detect_panel_configuration(private$.device_id)
      panel_slots <- if (is_multipanel_config(panel_config)) {
        compute_panel_slots(private$.plot_groups, panel_config)
      } else {
        NULL
      }

      layer_results <- vector("list", length(private$.layers))
      for (i in seq_along(private$.layers)) {
        processor <- private$.layer_processors[[i]]

        # Skip layers without processors (unknown types)
        # layer_results is pre-allocated so NULL is already set
        if (is.null(processor)) {
          next
        }

        # A panel scoped out by resolve_fallback_scope() emits no data at
        # all: its unsupported overlay may carry values we cannot read, so
        # publishing only the layers we did understand would describe that
        # panel incompletely without saying so.
        #
        # This asks with the group's OWN index, before the panel-slot
        # rewrite below: resolve_fallback_scope() records which plot GROUPS
        # were scoped out, so testing a panel slot here would ask the
        # question about a different group entirely.
        if (self$is_group_scoped_out(private$.layers[[i]]$group_index)) {
          next
        }

        layer_info <- private$.layers[[i]]
        if (!is.null(panel_slots)) {
          slot <- panel_slots[layer_info$group_index]
          if (!is.na(slot)) {
            layer_info$group_index <- slot
          }
        }

        layer_grob <- self$get_grob_for_layer(i)

        # Pass grob to processor (similar to ggplot2 passing gt)
        # For Base R, we don't have a built plot object like ggplot2
        # We pass the layer info directly and the grob for selector generation
        result <- processor$process(
          NULL,
          private$.layout,
          layer_info = layer_info,
          gt = layer_grob
        )
        processor$set_last_result(result)
        layer_results[[i]] <- result
      }

      self$combine_layer_results(layer_results)
    },

    #' @description Extract Format Configuration from axis() Calls
    #'
    #' Scans logged axis() calls for format config stored by the axis wrapper.
    #' The wrapper stores .maidr_format_config when labels is a scales:: function.
    #'
    #' @return A list with x and/or y format configurations, or NULL
    extract_format_config_from_axis_calls = function() {
      config <- list()
      private$.format_config_by_group <- list()

      # Scan all plot groups for axis() calls
      for (group_idx in seq_along(private$.plot_groups)) {
        group <- private$.plot_groups[[group_idx]]
        group_config <- list()

        # Check low-level calls for axis()
        if (length(group$low_calls) > 0) {
          for (low_call in group$low_calls) {
            if (low_call$function_name == "axis") {
              args <- low_call$args

              # Check if this axis() call has format config
              if (!is.null(args$.maidr_format_config)) {
                format_config <- args$.maidr_format_config
                side <- args$.maidr_axis_side

                # Map axis side to x/y: 1=bottom (x), 2=left (y), 3=top, 4=right
                if (side == 1 || side == 3) {
                  config$x <- format_config
                  group_config$x <- format_config
                } else if (side == 2 || side == 4) {
                  config$y <- format_config
                  group_config$y <- format_config
                }
              }
            }
          }
        }

        if (length(group_config) > 0) {
          # Keyed by group index so multipanel plots apply each panel's
          # axis() format only to that panel
          private$.format_config_by_group[[as.character(group_idx)]] <-
            group_config
        }
      }

      if (length(config) == 0) {
        return(NULL)
      }

      config
    },

    #' @description Read the figure-level title, subtitle and axis labels from the recorded
    #'   HIGH-level calls
    #' @return List
    extract_layout = function() {
      # Extract layout from the recorded HIGH-level plot calls
      # We scan all plot groups for main, sub, xlab, ylab arguments
      title <- ""
      subtitle <- NULL
      x_label <- ""
      y_label <- ""

      # Exact-match lookup: `args$sub` would partial-match an unrelated
      # `subset` argument (e.g. plot(y ~ x, subset = ...)), and recorded
      # values can be non-character (expressions from NSE calls), which
      # nzchar() cannot handle.
      get_label_arg <- function(args, name) {
        value <- args[[name]]
        if (is.null(value) || is.language(value)) {
          return(NULL)
        }
        value <- tryCatch(as.character(value)[1], error = function(e) NULL)
        if (is.null(value) || is.na(value) || !nzchar(value)) {
          return(NULL)
        }
        value
      }

      for (group in private$.plot_groups) {
        high_call <- group$high_call
        args <- high_call$args

        value <- get_label_arg(args, "main")
        if (!is.null(value)) title <- value
        value <- get_label_arg(args, "sub")
        if (!is.null(value)) subtitle <- value
        value <- get_label_arg(args, "xlab")
        if (!is.null(value)) x_label <- value
        value <- get_label_arg(args, "ylab")
        if (!is.null(value)) y_label <- value

        # Also check low-level title() calls which can set main/sub
        for (low_call in group$low_calls) {
          if (low_call$function_name == "title") {
            low_args <- low_call$args
            value <- get_label_arg(low_args, "main")
            if (!is.null(value)) title <- value
            value <- get_label_arg(low_args, "sub")
            if (!is.null(value)) subtitle <- value
            value <- get_label_arg(low_args, "xlab")
            if (!is.null(value)) x_label <- value
            value <- get_label_arg(low_args, "ylab")
            if (!is.null(value)) y_label <- value
          }
        }
      }

      layout <- list(
        title = title,
        subtitle = subtitle,
        caption = NULL, # Base R has no native caption concept
        axes = build_axes(x = x_label, y = y_label)
      )

      layout
    },
    #' @description Combine the per-layer results into the subplot grid
    #' @param layer_results List of per-layer results, one per processor
    combine_layer_results = function(layer_results) {
      grid_result <- private$declared_grid(layer_results)
      if (!is.null(grid_result)) {
        private$.combined_data <- private$build_declared_grid(grid_result)
        private$.combined_selectors <- list()
        for (panel in grid_result$panels) {
          for (layer in panel$layers) {
            private$.combined_selectors <- c(
              private$.combined_selectors, layer$selectors
            )
          }
        }
        return(invisible(NULL))
      }

      panel_config <- detect_panel_configuration(private$.device_id)

      if (is_multipanel_config(panel_config)) {
        # Multipanel case - create 2D grid
        nrows <- panel_config$nrows
        ncols <- panel_config$ncols

        subplot_grid <- vector("list", nrows)
        for (r in seq_len(nrows)) {
          subplot_grid[[r]] <- vector("list", ncols)
        }

        # Panel slot for each plot group (NA = drawn before the layout
        # call or on an earlier, no-longer-visible page)
        panel_slots <- compute_panel_slots(private$.plot_groups, panel_config)

        # Map layers to panels based on their group's panel slot
        for (i in seq_along(layer_results)) {
          result <- layer_results[[i]]
          # Skip NULL results (from unknown/unsupported layers)
          if (is.null(result)) {
            next
          }
          # A result that declared its own grid but was not the only one on
          # the page. `declared_grid()` has already refused it, and it
          # carries no `type` and no `data` -- emitted here it would become a
          # layer announcing nothing, with the grid's own bookkeeping leaked
          # into the payload beside it (#272). Skipping leaves the figure
          # reading exactly as it did before grids existed.
          if (isTRUE(result$multi_panel)) {
            next
          }
          layer_info <- private$.layers[[i]]
          group_idx <- layer_info$group_index

          slot <- panel_slots[group_idx]
          if (is.na(slot)) {
            next
          }
          # A layout() panel can span several cells; it belongs in all of them.
          positions <- panel_slot_positions(slot, panel_config)
          if (length(positions) == 0) {
            next
          }

          layer_type <- result$type
          if (is.null(layer_type) || length(layer_type) == 0) {
            layer_type <- private$.adapter$detect_layer_type(layer_info$plot_call)
          }

          # Build axes with optional per-panel format config from this
          # panel's own axis() calls (nested per-axis)
          layer_axes <- if (!is.null(result$axes)) {
            result$axes
          } else {
            build_axes()
          }
          group_format <- private$.format_config_by_group[[as.character(group_idx)]]
          if (!is.null(group_format)) {
            layer_axes <- attach_axis_format(layer_axes, "x", group_format$x)
            layer_axes <- attach_axis_format(layer_axes, "y", group_format$y)
          }
          validate_axes(layer_axes, context = "base_r orchestrator (multipanel)")

          layer_obj <- list(
            id = paste0("maidr-layer-", i),
            selectors = result$selectors,
            type = layer_type,
            data = result$data,
            title = if (!is.null(result$title)) result$title else "",
            axes = layer_axes
          )

          # Preserve all other fields from the processor result
          # (orientation, domMapping, ...)
          for (field_name in names(result)) {
            if (!field_name %in% c(
              "selectors", "data", "title", "axes",
              "labels", "multi_layer", "layers", "type"
            )) {
              layer_obj[[field_name]] <- result[[field_name]]
            }
          }

          if (!is.null(result$labels) && length(result$labels) > 0) {
            layer_obj$labels <- result$labels
          }

          # The same panel object goes into every cell of its span, so
          # navigating across the span keeps announcing that panel instead of
          # falling into a cell with nothing to sonify.
          for (position in positions) {
            row <- position[1]
            col <- position[2]

            # Ensure we're within bounds
            if (row > nrows || col > ncols) {
              next
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
        }

        # Whatever is still unclaimed is genuinely blank -- a `0` in the
        # layout() matrix, or a declared panel the user never drew. Give it a
        # valid empty subplot: a bare NULL serializes as `{}`, which the maidr
        # frontend cannot parse.
        for (r in seq_len(nrows)) {
          for (c_idx in seq_len(ncols)) {
            if (is.null(subplot_grid[[r]][[c_idx]])) {
              subplot_grid[[r]][[c_idx]] <- list(
                id = paste0("maidr-subplot-", r, "-", c_idx),
                layers = list()
              )
            }
          }
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
        layer_counter <- 0

        for (i in seq_along(layer_results)) {
          result <- layer_results[[i]]
          # Skip NULL results (from unknown/unsupported layers)
          if (is.null(result)) {
            next
          }
          # A result that declared its own grid but was not the only one on
          # the page. `declared_grid()` has already refused it, and it
          # carries no `type` and no `data` -- emitted here it would become a
          # layer announcing nothing, with the grid's own bookkeeping leaked
          # into the payload beside it (#272). Skipping leaves the figure
          # reading exactly as it did before grids existed.
          if (isTRUE(result$multi_panel)) {
            next
          }

          # --- Multi-layer expansion (e.g. candlestick + addVo volume) ---
          if (isTRUE(result$multi_layer) && !is.null(result$layers)) {
            for (sub in result$layers) {
              layer_counter <- layer_counter + 1
              sub_axes <- sub$axes
              if (!is.null(private$.format_config)) {
                sub_axes <- attach_axis_format(
                  sub_axes, "x", private$.format_config$x
                )
                sub_axes <- attach_axis_format(
                  sub_axes, "y", private$.format_config$y
                )
              }
              validate_axes(
                sub_axes, context = "base_r orchestrator (multi-layer)"
              )
              layer_obj <- list(
                id = layer_counter,
                selectors = sub$selectors,
                type = sub$type,
                data = sub$data,
                title = if (!is.null(sub$title)) sub$title else "",
                axes = sub_axes
              )
              for (field_name in names(sub)) {
                if (!field_name %in% c(
                  "selectors", "data", "title", "axes",
                  "labels", "multi_layer", "layers"
                )) {
                  layer_obj[[field_name]] <- sub[[field_name]]
                }
              }
              if (!is.null(sub$labels) && length(sub$labels) > 0) {
                layer_obj$labels <- sub$labels
              }
              combined_data <- append(combined_data, list(layer_obj))
            }
            next
          }

          layer_type <- result$type
          if (is.null(layer_type) || length(layer_type) == 0) {
            layer_info <- private$.layers[[i]]
            layer_type <- private$.adapter$detect_layer_type(layer_info$plot_call)
          }

          # Build axes with optional format config (nested per-axis)
          layer_axes <- result$axes
          if (!is.null(private$.format_config)) {
            layer_axes <- attach_axis_format(
              layer_axes, "x", private$.format_config$x
            )
            layer_axes <- attach_axis_format(
              layer_axes, "y", private$.format_config$y
            )
          }
          validate_axes(layer_axes, context = "base_r orchestrator")

          layer_counter <- layer_counter + 1
          layer_obj <- list(
            id = layer_counter,
            selectors = result$selectors,
            type = layer_type,
            data = result$data,
            # The same default the multipanel branch applies: a NULL title
            # serialises as `{}`, which is not a string.
            title = if (!is.null(result$title)) result$title else "",
            axes = layer_axes
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

          # Use append to avoid sparse list (no NULL gaps from skipped layers)
          combined_data <- append(combined_data, list(layer_obj))
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
    #' @description Assemble the MAIDR data object for the figure
    #' @return List with an id and the subplots
    generate_maidr_data = function() {
      # Base R plots use the same unified structure as ggplot2
      # title, subtitle, caption are figure-level (root of the Maidr object)
      # Only include keys when they have non-empty string values;
      # R NULL serializes as {} in jsonlite, so we must omit them entirely.
      maidr_obj <- list(
        id = paste0("maidr-plot-", generate_unique_id()),
        subplots = private$.combined_data
      )

      if (!is.null(private$.layout$title) && nzchar(private$.layout$title)) {
        maidr_obj$title <- private$.layout$title
      }
      if (!is.null(private$.layout$subtitle) && nzchar(private$.layout$subtitle)) {
        maidr_obj$subtitle <- private$.layout$subtitle
      }
      if (!is.null(private$.layout$caption) && nzchar(private$.layout$caption)) {
        maidr_obj$caption <- private$.layout$caption
      }

      maidr_obj
    },
    #' @description The figure-level layout read by `extract_layout()`
    #' @return List
    get_layout = function() {
      private$.layout
    },
    #' @description The combined per-layer data
    #' @return List
    get_combined_data = function() {
      private$.combined_data
    },
    #' @description The processors created for the layers
    #' @return List
    get_layer_processors = function() {
      private$.layer_processors
    },
    #' @description The detected layer entries
    #' @return List
    get_layers = function() {
      private$.layers
    },
    #' @description The recorded plot calls
    #' @return List
    get_plot_calls = function() {
      private$.plot_calls
    },
    #' @description The gtable of the replayed drawing, built once and cached
    #' @return A gtable, or NULL when nothing was recorded. Stops when the
    #'   chart is too small for R to draw (see [base_r_drawing_grob()]).
    get_gtable = function() {
      if (length(private$.plot_groups) == 0) {
        return(NULL)
      }

      # Replaying every recorded call and rasterizing grobs is expensive;
      # the recorded calls never change within an orchestrator's lifetime,
      # so build the gtable once and reuse it.
      if (!is.null(private$.cached_gtable)) {
        return(private$.cached_gtable)
      }

      # Suppress native R graphics window by using a null PDF device
      # This ensures only the HTML output is displayed. The drawing itself is
      # made on a page of the chart's size (`base_r_drawing_grob()`).
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      canvas <- private$.canvas
      grDevices::pdf(null_pdf, width = canvas[["width"]], height = canvas[["height"]])
      on.exit(
        {
          grDevices::dev.off()
          if (current_dev > 1) grDevices::dev.set(current_dev)
          unlink(null_pdf)
        },
        add = TRUE
      )

      panel_config <- detect_panel_configuration(private$.device_id)

      if (is_multipanel_config(panel_config)) {
        # Multipanel case - create composite grob
        panel_slots <- compute_panel_slots(private$.plot_groups, panel_config)

        composite_func <- function() {
          # Restored with care, as in `base_r_drawing_grob()`: on a page too
          # small for the margins, restoring would fail too and hide why.
          oldpar <- graphics::par(no.readonly = TRUE)
          on.exit(try(graphics::par(oldpar), silent = TRUE), add = TRUE)
          if (panel_config$type == "mfrow") {
            graphics::par(mfrow = c(panel_config$nrows, panel_config$ncols))
          } else if (panel_config$type == "mfcol") {
            graphics::par(mfcol = c(panel_config$nrows, panel_config$ncols))
          } else if (panel_config$type == "layout" && !is.null(panel_config$matrix)) {
            graphics::layout(panel_config$matrix)
          }

          # Debug logging
          if (getOption("maidr.debug", FALSE)) {
            message("DEBUG: Replaying ", length(private$.plot_groups), " plot groups")
            message("DEBUG: Panel config: ", panel_config$nrows, " x ", panel_config$ncols)
          }

          # Replay the panel-visible plot groups using ORIGINAL (unwrapped)
          # functions to prevent logging new calls during replay. Groups
          # with an NA slot (drawn before the layout call, or on an
          # earlier page) are excluded so the SVG matches the data grid.
          for (i in seq_along(private$.plot_groups)) {
            if (is.na(panel_slots[i])) {
              next
            }
            group <- private$.plot_groups[[i]]

            if (getOption("maidr.debug", FALSE)) {
              message("DEBUG: Replaying group ", i, " - ", group$high_call$function_name)
            }

            replay_plot_call(
              group$high_call$function_name,
              group$high_call$args,
              group$high_call$call_env
            )

            if (length(group$low_calls) > 0) {
              for (low_call in group$low_calls) {
                replay_plot_call(
                  low_call$function_name,
                  low_call$args,
                  low_call$call_env
                )
              }
            }
          }
        }

        tryCatch(
          {
            composite_grob <- base_r_drawing_grob(composite_func, canvas)

            # Also store individual grobs for reference
            private$.grob_list <- list(composite_grob)
            private$.cached_gtable <- composite_grob

            return(composite_grob)
          },
          error = function(e) {
            # A chart too small to draw stops, naming its size
            # (`base_r_drawing_grob()`).
            if (inherits(e, "maidr_chart_draw_error")) {
              stop(e)
            }
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

          # Use ORIGINAL (unwrapped) functions to prevent logging new calls
          plot_func <- function() {
            replay_plot_call(
              high_call$function_name,
              high_call$args,
              high_call$call_env
            )

            if (length(low_calls) > 0) {
              for (low_call in low_calls) {
                replay_plot_call(
                  low_call$function_name,
                  low_call$args,
                  low_call$call_env
                )
              }
            }
          }

          tryCatch(
            {
              grob <- base_r_drawing_grob(plot_func, canvas)
              grob_list[[i]] <- grob
            },
            error = function(e) {
              # As above, a chart too small to draw stops.
              if (inherits(e, "maidr_chart_draw_error")) {
                stop(e)
              }
              grob_list[[i]] <- NULL
            }
          )
        }

        private$.grob_list <- grob_list

        if (length(grob_list) > 0 && !is.null(grob_list[[1]])) {
          private$.cached_gtable <- grob_list[[1]]
          return(grob_list[[1]])
        }

        NULL
      }
    },
    #' @description The size the chart is drawn at
    #' @return A named numeric vector, `width` and `height`, in inches
    canvas_size = function() {
      private$.canvas
    },
    #' @description The grob a layer's processor searches for its selectors
    #' @param layer_index Index of the layer
    #' @return A grob, or NULL
    get_grob_for_layer = function(layer_index) {
      if (layer_index < 1 || layer_index > length(private$.layers)) {
        return(NULL)
      }

      if (length(private$.grob_list) == 0) {
        self$get_gtable()
      }

      panel_config <- detect_panel_configuration(private$.device_id)
      is_multipanel <- is_multipanel_config(panel_config)

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

    #' @description Flag each detected layer maidr cannot process
    #'
    #' Decorations carry no data of their own; leaving them out of the
    #' interactive output loses nothing. Data-bearing LOW-level overlays
    #' (polygon, rect, segments, ...) with no processor would silently
    #' disappear from the accessible output, so they count as unsupported.
    #'
    #' @return Logical vector, one entry per detected layer
    unsupported_layer_flags = function() {
      if (length(private$.layers) == 0) {
        return(logical(0))
      }

      decoration_functions <- c(
        "axis", "title", "legend", "text", "mtext", "grid", "box"
      )

      vapply(private$.layers, function(layer) {
        if (!isTRUE(layer$type == "unknown")) {
          return(FALSE)
        }
        if (isTRUE(layer$source == "HIGH")) {
          return(TRUE)
        }
        !isTRUE(layer$function_name %in% decoration_functions)
      }, logical(1))
    },

    #' @description Check if any HIGH-level layers are unsupported (unknown type)
    #' @return Logical indicating if there are unsupported layers
    has_unsupported_layers = function() {
      any(self$unsupported_layer_flags())
    },

    #' @description Plot groups holding a layer maidr cannot process
    #' @return Integer vector of plot-group indices, in ascending order
    unsupported_group_indices = function() {
      unsupported <- self$unsupported_layer_flags()
      if (!any(unsupported)) {
        return(integer(0))
      }

      groups <- vapply(
        private$.layers[unsupported],
        function(layer) as.integer(layer$group_index %||% NA_integer_),
        integer(1)
      )
      sort(unique(groups[!is.na(groups)]))
    },

    #' @description Work out how far an unsupported layer reaches
    #'
    #' An unsupported LOW-level overlay sits on top of a chart maidr does
    #' understand, so it only makes the panel that owns it undescribable.
    #' In a multi-panel figure the other panels are drawn from their own
    #' calls and stay fully accessible, so the fallback is scoped to the
    #' affected panels. It widens to the whole figure when there is nothing
    #' left to scope to: a single-panel figure, a figure whose every
    #' visible panel is affected, an unsupported call that belongs to no
    #' panel of the exported page, or an unsupported HIGH-level call.
    #'
    #' @return Invisible NULL; the scope is cached on the orchestrator
    resolve_fallback_scope = function() {
      private$.fallback_mode <- "none"
      private$.fallback_groups <- integer(0)
      private$.fallback_panels <- integer(0)

      if (!is_fallback_enabled()) {
        return(invisible(NULL))
      }

      unsupported <- self$unsupported_layer_flags()
      if (!any(unsupported)) {
        return(invisible(NULL))
      }

      # An unsupported HIGH-level call is not an annotation over a chart we
      # can read -- the panel's entire content is unknown, and its grobs
      # are not known to survive the SVG export. Keeping such a figure whole
      # means it falls back to an image that is at least correct, rather
      # than to an interactive render that may fail.
      sources <- vapply(
        private$.layers[unsupported],
        function(layer) as.character(layer$source %||% "HIGH"),
        character(1)
      )
      if (any(sources == "HIGH")) {
        private$.fallback_mode <- "figure"
        return(invisible(NULL))
      }

      unsupported_groups <- self$unsupported_group_indices()
      if (length(unsupported_groups) == 0) {
        # Unsupported layers that name no group cannot be scoped.
        private$.fallback_mode <- "figure"
        return(invisible(NULL))
      }

      panel_config <- detect_panel_configuration(private$.device_id)
      if (!is_multipanel_config(panel_config)) {
        private$.fallback_mode <- "figure"
        return(invisible(NULL))
      }

      panel_slots <- compute_panel_slots(private$.plot_groups, panel_config)
      affected_slots <- panel_slots[unsupported_groups]

      # An NA slot means the group is not on the exported page at all, so
      # there is no panel to scope the fallback to.
      if (anyNA(affected_slots)) {
        private$.fallback_mode <- "figure"
        return(invisible(NULL))
      }

      visible_slots <- panel_slots[!is.na(panel_slots)]
      if (length(setdiff(visible_slots, affected_slots)) == 0) {
        # Every panel that was drawn is affected; scoping would leave an
        # interactive figure with no data anywhere.
        private$.fallback_mode <- "figure"
        return(invisible(NULL))
      }

      private$.fallback_mode <- "panel"
      private$.fallback_groups <- unsupported_groups
      private$.fallback_panels <- sort(unique(as.integer(affected_slots)))

      invisible(NULL)
    },

    #' @description Check whether a plot group is scoped out of the payload
    #' @param group_index Plot-group index to test
    #' @return TRUE when the group's panel falls back on its own
    is_group_scoped_out = function(group_index) {
      if (!identical(private$.fallback_mode, "panel")) {
        return(FALSE)
      }
      isTRUE(group_index %in% private$.fallback_groups)
    },

    #' @description Panels rendered without accessible data
    #' @return Integer vector of 1-based panel numbers, empty when the whole
    #'   figure renders normally or falls back as a whole
    fallback_panels = function() {
      private$.fallback_panels
    },

    #' @description Determine if the plot should fall back to image rendering
    #' @return Logical indicating if fallback should be used
    should_fallback = function() {
      # Check if fallback is enabled globally
      if (!is_fallback_enabled()) {
        return(FALSE)
      }

      identical(private$.fallback_mode, "figure")
    }
  )
)

#' A Base R drawing as a grob, laid out on a page of the chart's size
#'
#' What [ggplotify::as.grob()] makes of a drawing function -- the base
#' graphics echoed as grid grobs by gridGraphics, drawn with the graphical
#' parameters it sets (`xpd = NA`, a transparent background, axis titles two
#' lines out) -- with the page the drawing is made on sized as the chart's
#' canvas. `as.grob()` makes every drawing on a 7 x 7 in page of its own,
#' whatever device is open, and the echo keeps what base graphics laid out
#' on that page: margins, the lines of text around a plot and a legend's box
#' are fixed in inches. Drawn on a canvas of another shape they no longer
#' fit -- measured at 4 x 3 in, the title was cut off at the top of the SVG,
#' the axis titles were lost and a legend's text ran out of its box, and
#' even maidr's own 7 x 5 in squeezed a legend's lines together. Made on a
#' page of the canvas's size, the drawing is the one R draws at that size.
#'
#' The grob names, which every selector is written against, are those
#' `as.grob()` gives. A drawing gridGraphics cannot echo is grabbed as drawn,
#' as `as.grob()` does. An echoed drawing keeps only the tick labels R draws
#' ([thin_axis_labels()]).
#'
#' A chart too small to draw stops, with an error of class
#' `maidr_chart_draw_error` that names the size and R's reason. Base R gives
#' a chart's margins and text the same room in inches on any page, so a
#' page too small for them -- 6 x 1.5 in for a `barplot()`, 4 x 3 in for a
#' 2 x 2 `par(mfrow)` -- leaves the plot none and R stops with "figure
#' margins too large". The device the author drew on may have had the room,
#' and maidr draws the chart again at a size of its own. An empty chart in
#' its place would not say so, and a picture is drawn at the same size, so
#' neither is made. A drawing is taken to have failed for its size when it
#' fits a page four times as wide and high; any other failure is raised as
#' R raised it, for the caller to handle as before.
#'
#' @param draw A function of no arguments that draws the chart
#' @param size The chart's canvas, from [chart_canvas_size()]
#' @return A gTree
#' @keywords internal
base_r_drawing_grob <- function(draw, size) {
  # Restored as ggplotify restores them. On a page too small for the
  # margins R reports a negative plot size ("pin") that it then refuses to
  # be given back, and that refusal would hide why the drawing failed.
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(try(suppressWarnings(graphics::par(old_par)), silent = TRUE), add = TRUE)

  draw_as_ggplotify_does <- function() {
    graphics::par(xpd = NA, bg = "transparent", mgp = c(2, 1, 0))
    draw()
  }
  grab <- function(expr, page = size) {
    grid::grid.grabExpr(
      expr,
      warn = 0,
      width = page[["width"]],
      height = page[["height"]]
    )
  }

  cannot_draw <- function(e) {
    fits_larger <- tryCatch(
      {
        grab(draw_as_ggplotify_does(), page = size * 4)
        TRUE
      },
      error = function(e) FALSE
    )
    if (!fits_larger) {
      stop(e)
    }
    stop(errorCondition(
      paste0(
        "maidr could not draw this chart at ", format_inches(size), ": ",
        conditionMessage(e), ". A Base R chart's margins and text take the ",
        "same room at every size, and at this size they leave the plot none: ",
        "give the chart a larger size."
      ),
      class = "maidr_chart_draw_error"
    ))
  }

  echoed <- tryCatch(
    grab(gridGraphics::grid.echo(draw_as_ggplotify_does)),
    error = function(e) NULL
  )
  if (is.null(echoed)) {
    return(tryCatch(grab(draw_as_ggplotify_does()), error = cannot_draw))
  }
  thin_axis_labels(echoed, size)
}

#' Keep only the tick labels R draws on each axis of an echoed drawing
#'
#' R's `axis()` draws a tick label only when it clears the last label drawn
#' by a gap: an "m" wide for labels along the axis, a quarter of an "m" high
#' for labels across it (`gap.axis`, whose default this is). Labels that
#' would collide are left out, which is how the y axis of a short panel goes
#' from 10, 12, 14 to 10, 14. gridGraphics echoes every label, so they ran
#' into each other wherever R thins them: a Base R chart at 4 x 3 in, or the
#' panels of a 2 x 2 `par(mfrow)` at 10 x 4 in. Each axis's labels are
#' measured as R measures them, in inches along the axis on a page of the
#' chart's size, and the ones R leaves out are taken out of the text grob.
#' Labels that are expressions are all kept, as R draws them all.
#'
#' @param drawing The gTree [base_r_drawing_grob()] echoed
#' @param size The chart's canvas, from [chart_canvas_size()]
#' @return The gTree, its axis-label text grobs holding only the labels R
#'   draws
#' @keywords internal
thin_axis_labels <- function(drawing, size) {
  pattern <- "-(bottom|left|top|right)-axis-labels-[0-9]+$"
  names <- grep(pattern, grid::grid.ls(drawing, print = FALSE)$name, value = TRUE)
  if (length(names) == 0L || is.null(drawing$childrenvp)) {
    return(drawing)
  }

  # The viewports the labels are placed in, on a page of the chart's size.
  current <- grDevices::dev.cur()
  grDevices::pdf(NULL, width = size[["width"]], height = size[["height"]])
  on.exit(
    {
      grDevices::dev.off()
      if (current > 1) grDevices::dev.set(current)
    },
    add = TRUE
  )
  grid::grid.newpage()
  grid::pushViewport(drawing$childrenvp)
  grid::upViewport(0)

  for (name in names) {
    labels <- grid::getGrob(drawing, name)
    if (is.null(labels$vp) || !is.character(labels$label)) {
      next
    }
    side <- sub(paste0("^.*", pattern), "\\1", name)
    keep <- axis_labels_kept(labels, horizontal = side %in% c("bottom", "top"))
    if (all(keep)) {
      next
    }
    for (field in c("label", "x", "y", "hjust", "vjust")) {
      if (length(labels[[field]]) == length(keep)) {
        labels[[field]] <- labels[[field]][keep]
      }
    }
    drawing <- grid::setGrob(drawing, name, labels)
  }
  drawing
}

#' Which of an axis's tick labels R draws
#'
#' Called with the labels' viewports pushed on the current device; see
#' [thin_axis_labels()].
#'
#' @param labels An echoed axis-label text grob
#' @param horizontal Whether the axis runs across the page (sides 1 and 3)
#' @return A logical vector, one value per label
#' @keywords internal
axis_labels_kept <- function(labels, horizontal) {
  grid::downViewport(labels$vp)
  on.exit(grid::upViewport(0), add = TRUE)
  at <- if (horizontal) {
    grid::convertX(labels$x, "in", valueOnly = TRUE)
  } else {
    grid::convertY(labels$y, "in", valueOnly = TRUE)
  }
  at <- rep_len(at, length(labels$label))

  # A label along its axis takes its width there, one across it its height.
  along <- (labels$rot %% 180 == 0) == horizontal
  grid::pushViewport(grid::viewport(gp = labels$gp))
  if (along) {
    extent <- grid::convertWidth(grid::stringWidth(labels$label), "in", valueOnly = TRUE)
    gap <- grid::convertWidth(grid::stringWidth("m"), "in", valueOnly = TRUE)
  } else {
    extent <- grid::convertHeight(grid::stringHeight(labels$label), "in", valueOnly = TRUE)
    gap <- 0.25 * grid::convertHeight(grid::stringHeight("m"), "in", valueOnly = TRUE)
  }
  grid::popViewport()

  keep <- logical(length(at))
  last <- -Inf
  for (i in order(at)) {
    if (at[[i]] - extent[[i]] / 2 - last >= gap) {
      keep[[i]] <- TRUE
      last <- at[[i]] + extent[[i]] / 2
    }
  }
  keep
}
