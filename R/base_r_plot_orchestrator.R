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
    .grob_list = list(),
    .format_config = NULL,
    .format_config_by_group = list(),
    .cached_gtable = NULL,
    .fallback_mode = "none",
    .fallback_groups = integer(0),
    .fallback_panels = integer(0)
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
      self$resolve_fallback_scope()
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

    #' Extract Format Configuration from axis() Calls
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
    combine_layer_results = function(layer_results) {
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
          layer_info <- private$.layers[[i]]
          group_idx <- layer_info$group_index

          slot <- panel_slots[group_idx]
          if (is.na(slot)) {
            next
          }
          position <- panel_slot_position(slot, panel_config)
          if (is.null(position)) {
            next
          }
          row <- position[1]
          col <- position[2]

          # Ensure we're within bounds
          if (row > nrows || col > ncols) {
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
            build_axes(x = "", y = "")
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

        # Fill cells with no layers with a valid empty subplot: a bare
        # NULL serializes as `{}`, which the maidr frontend cannot parse.
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
            title = result$title,
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

      # Replaying every recorded call and rasterizing grobs is expensive;
      # the recorded calls never change within an orchestrator's lifetime,
      # so build the gtable once and reuse it.
      if (!is.null(private$.cached_gtable)) {
        return(private$.cached_gtable)
      }

      # Suppress native R graphics window by using a null PDF device
      # This ensures only the HTML output is displayed.
      # chartSeries (candlestick) needs a wider canvas (10x5) because its
      # title + bracketed date range and 2-row month/year tick labels
      # require ~10 in to render without clipping/overlap. quantmod
      # centers the title at ~10% of canvas width and the date bracket at
      # ~91%; at 9 in long titles still clipped on the left and the
      # bracket extended past the right edge. Bumping to 10 in clears
      # both for realistic ticker/title lengths. (See quantmod GH issue
      # #129 for the underlying upstream layout limitation.) We widen
      # ONLY when a chartSeries call is present, leaving all other plot
      # types' visual aspect ratio (7x5) unchanged.
      has_chartseries <- any(vapply(
        private$.plot_groups,
        function(g) identical(g$high_call$function_name, "chartSeries"),
        logical(1)
      ))
      # Enlarge BOTH dimensions for chartSeries plots so the
      # right-side date-range header (e.g. "[2024-01-12/2024-01-15]")
      # and the bottom x-axis date labels (e.g. "Jan 12 / 2024")
      # fit inside the gridSVG viewBox. With 10x5 in (720x360 px),
      # short-timeseries chartSeries layouts overhung by ~18px right
      # and ~22px bottom -- clipped by SVG root's default
      # overflow:hidden. Bumping to 12x6 in (864x432 px) gives the
      # internal layout 144 more px horizontally and 72 more px
      # vertically, comfortably absorbing both overhangs. We CANNOT
      # work around this with CSS `overflow: visible` because
      # chartSeries also draws volume <rect>s with intentionally-
      # negative y coordinates that rely on root clipping. We widen
      # ONLY when a chartSeries call is present, leaving all other
      # plot types' visual aspect ratio (7x5) unchanged.
      gt_width  <- if (has_chartseries) 12 else 7
      gt_height <- if (has_chartseries)  6 else 5
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = gt_width, height = gt_height)
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
          oldpar <- graphics::par(no.readonly = TRUE)
          on.exit(graphics::par(oldpar), add = TRUE)
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
            composite_grob <- ggplotify::as.grob(composite_func)

            # Also store individual grobs for reference
            private$.grob_list <- list(composite_grob)
            private$.cached_gtable <- composite_grob

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
          private$.cached_gtable <- grob_list[[1]]
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
      # are not known to survive the SVG export (pie() does not). Keeping
      # such a figure whole means it falls back to an image that is at
      # least correct, rather than to an interactive render that may fail.
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
