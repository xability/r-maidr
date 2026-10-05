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
    .layout_calls = list(),
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
    .size_asked = TRUE,

    # A drawing as a grob on the chart's canvas (`base_r_drawing_grob()`),
    # the canvas enlarged first where the drawing is too small for one no one
    # asked for (`enlarge_canvas()`).
    drawing_grob = function(draw) {
      tryCatch(
        base_r_drawing_grob(draw, private$.canvas),
        maidr_chart_draw_error = function(e) {
          private$enlarge_canvas(draw, e)
          base_r_drawing_grob(draw, private$.canvas)
        }
      )
    },

    # Settle the canvas for a drawing too small for it, which stopped with
    # `e`, a `maidr_chart_draw_error`. A canvas no one asked for is enlarged
    # to a page the drawing fits (`base_r_page_that_fits()`), with a message
    # naming the size: a `par(mfrow)` grid of five rows, which does not fit
    # maidr's own 7 x 5 in, was drawn before maidr drew a chart at its size,
    # and still is. A size asked for is not changed, and stops.
    enlarge_canvas = function(draw, e) {
      if (private$.size_asked) {
        stop(e)
      }
      canvas <- private$.canvas
      private$.canvas <- base_r_page_that_fits(draw, canvas)
      # Classed as the candlestick's is (`chart_canvas_size()`), so that a
      # knitted chart says it too (`knit_chart_content()`).
      rlang::inform(
        paste0(
          "maidr: this Base R chart is drawn at ", format_inches(private$.canvas),
          " rather than ", format_inches(canvas), ", where its margins and ",
          "text leave the plot no room. Give it a size of its own to draw ",
          "it at another."
        ),
        class = "maidr_chart_size_message"
      )
    },

    # Set the margins the author's `par()` calls gave the plot a call at
    # `index` in the recording draws on, before it is drawn again
    # (`par_margin_settings()`), and answer them. Only those that differ from
    # `set`, the ones the page's last plot was drawn with, are set: setting
    # the outer margins starts a new page, in R as here, and a grid's later
    # plots would each have a page of their own.
    set_recorded_margins = function(index, set = list()) {
      settings <- par_margin_settings(private$.layout_calls, index)
      changed <- settings[!mapply(identical, settings, set[names(settings)])]
      if (length(changed) > 0) {
        graphics::par(changed)
      }
      settings
    },

    # The number of each plot group's plot on the page, which the drawing
    # names the elements of the plot after (`graphics-plot-<n>-...`), and
    # by which the group's processors find them: the number R gave the plot
    # as it started it, counting every plot started on the page -- one drawn
    # over the plot before it after `par(new = TRUE)`, and a panel
    # `plot.new()` or `frame()` passed over -- as `replay_page()` starts
    # them again. A group that started no plot, as an `add = TRUE` call
    # does, has its elements named after the plot it is drawn over, among
    # that plot's own, which its processors would find in its place: it has
    # a number no plot on the page has, and its selectors name nothing. A
    # group recorded by code that records calls itself, which R did not
    # number, has its panel's (`panel_slots`), and on a page of one panel
    # its place among the groups.
    plot_numbers = function(panel_slots = NULL) {
      groups <- private$.plot_groups
      drawn <- unlist(lapply(groups, function(group) {
        calls <- c(list(group$high_call), group$low_calls, group$before_calls, group$after_calls)
        lapply(calls, function(call) c(call$plot, call$end_plot))
      }))
      last <- as.integer(max(c(0L, drawn)))
      vapply(
        seq_along(groups),
        function(i) {
          high <- groups[[i]]$high_call
          if (isTRUE(high$new_plot) && is.numeric(high$plot)) {
            return(as.integer(high$plot))
          }
          if (isFALSE(high$new_plot)) {
            return(last + i)
          }
          slot <- if (is.null(panel_slots)) NA_integer_ else panel_slots[[i]]
          as.integer(if (is.na(slot)) i else slot)
        },
        integer(1)
      )
    },

    # Draw the plot groups of the page R shows again, each in the panel R
    # drew it in (`slots`, NA for a group not drawn, of the grid
    # `panel_config` describes, NULL for a page of one panel) and numbered as
    # R numbered it (`numbers`, from `plot_numbers()`): the plots R started
    # between two groups are started again, a panel `plot.new()` or
    # `frame()` passed over with `plot.new()`, and a plot drawn in the panel
    # of the one before it after `par(new = TRUE)`, as R drew it. A plot R
    # was sent to out of turn, with `par(mfg = )`, is sent there again, and
    # one `par(fig = )` or `screen()` placed outside the grid is drawn in
    # the same region of the page (`place_replayed_plot()`). A group that
    # starts no plot, as an `add = TRUE` call does, draws where it is. A
    # low-level call drawn on a plot no recorded call started -- a legend
    # on a panel of its own, after `plot.new()` -- is drawn on a plot
    # started for it in the panel R drew it in, in the coordinates it was
    # drawn in (`replay_unrecorded_plot_call()`). One drawn after R was sent
    # back to a plot without starting one, by `par(mfg = )` or `screen()`,
    # is drawn with that plot's group, where the drawing is on that plot
    # (`sent_back_to()`). The recorded calls are
    # replayed with the ORIGINAL (unwrapped) functions, so nothing new is
    # recorded.
    replay_page = function(slots, numbers, panel_config = NULL) {
      # Where the drawing is: the panel it is in, as `slots` number them,
      # and the panel R's count had reached there (`figure`, see
      # `end_base_r_call()`); the plots started on its page; the margins it
      # set, and the coordinates it gave a plot it started.
      at <- list(slot = 0L, figure = NULL, plots = 0L, margins = list(), window = NULL)
      for (i in seq_along(private$.plot_groups)) {
        slot <- slots[[i]]
        if (is.na(slot)) {
          next
        }
        group <- private$.plot_groups[[i]]
        high <- group$high_call

        if (getOption("maidr.debug", FALSE)) {
          message("DEBUG: Replaying group ", i, " - ", high$function_name)
        }

        for (call in group$before_calls) {
          at <- private$replay_unrecorded_plot_call(call, at, panel_config)
        }
        at$margins <- private$set_recorded_margins(group$high_call_index, at$margins)
        if (!isFALSE(high$new_plot)) {
          at <- start_skipped_plots(at, numbers[[i]] - 1L, slot)
          # A call that drew plots on a page before this one -- `plot()` of
          # a fitted model after a plot, under `par(mfrow = c(2, 2))` -- is
          # started in the panel R started it in, so those plots fill that
          # page, as R's did, and not this one; in a knit too, where the
          # figure's calls are read without their pages (`with_figure_calls()`).
          if (isTRUE(high$spans_pages)) {
            for (k in seq_len(max(high$start_figure - 1L, 0L))) {
              start_replayed_plot(FALSE)
            }
          }
          place_replayed_plot(high, slot, at$slot, panel_config)
          at$slot <- slot
          at$figure <- high$figure
          at$plots <- numbers[[i]]
        }

        calls <- c(list(high), group$low_calls)
        window <- high$window
        for (call in calls) {
          if (isTRUE(call$read_only)) {
            # Drawn in its place among the calls on plots no recorded call
            # started (`drawn_over_earlier_plot()`).
            next
          }
          if (isTRUE(call$overlay)) {
            at <- private$replay_unrecorded_plot_call(call, at, panel_config)
            window <- at$window
          } else {
            # Drawn after R was sent back to this plot, in the coordinates
            # R had then: those of the plot it was sent back from, after
            # `par(mfg = )`, which keeps them.
            if (isTRUE(call$sent_back) && !identical(call$window, window)) {
              window <- replay_plot_window(call$window) %||% window
              at$window <- window
            }
            replay_plot_call(
              call$function_name, call$args, call$call_env, call$arg_text, call$rng_state
            )
          }
        }
        # Where R was once the group was drawn: a call that draws several
        # plots, as `plot()` of a fitted model does, moves on as many from
        # the panel its first is in. One drawn after R was sent back to it
        # was drawn later, from another, and one only read with it is drawn
        # elsewhere.
        ends <- Filter(
          function(call) {
            is.numeric(call$end_plot) && !isTRUE(call$sent_back) && !isTRUE(call$read_only)
          },
          calls
        )
        if (length(ends) > 0) {
          end <- ends[[length(ends)]]
          at$slot <- slot + end$end_figure - (high$figure %||% end$end_figure)
          at$figure <- end$end_figure
          at$plots <- end$end_plot
        }

        for (call in group$after_calls) {
          at <- private$replay_unrecorded_plot_call(call, at, panel_config)
        }
      }
    },

    # Draw a low-level call that R drew on a plot no recorded call started
    # -- a panel `plot.new()` or `frame()` took, or a plot maidr does not
    # record -- on the drawing `at` describes (see `replay_page()`), and
    # answer where the drawing is then. The plot it was drawn on is started
    # first, if the drawing has not started it yet, in the panel R drew it
    # in: the cell R put it in, or else as many panels on from the last as
    # R's count moved. It is given the coordinates the call was drawn in,
    # which what started it set, unrecorded. Only the call is drawn: what
    # else that plot holds was not recorded. A call R counted on no plot is
    # drawn on the page's first: R draws none before a plot is started.
    replay_unrecorded_plot_call = function(call, at, panel_config) {
      at$margins <- private$set_recorded_margins(call$storage_index, at$margins)
      on <- max(call$end_plot, 1L)
      if (on > at$plots) {
        slot <- if (is.null(panel_config)) {
          1L
        } else {
          panel_of_cell(call$cell, panel_config) %||%
            (at$slot + max(call$figure - (at$figure %||% call$figure), 0L))
        }
        at <- start_skipped_plots(at, on - 1L, slot)
        place_replayed_plot(call, slot, at$slot, panel_config)
        graphics::plot.new()
        at$slot <- slot
        at$figure <- call$figure
        at$plots <- on
        at$window <- NULL
      }
      if (!identical(call$window, at$window)) {
        at$window <- replay_plot_window(call$window) %||% at$window
      }
      replay_plot_call(
        call$function_name, call$args, call$call_env, call$arg_text, call$rng_state
      )
      at
    },

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
    #' @param asked Whether that size was asked for, by default when either
    #'   side is given. A chart too small for a size not asked for is drawn
    #'   larger (`base_r_page_that_fits()`); one too small for a size asked
    #'   for stops.
    initialize = function(device_id = grDevices::dev.cur(), width = NULL, height = NULL,
                          asked = !is.null(width) || !is.null(height)) {
      private$.device_id <- device_id
      registry <- get_global_registry()
      private$.adapter <- registry$get_adapter("base_r")

      # The calls on the page R's device shows: the last. A plot that started
      # a page of its own leaves those before it out of the chart's data,
      # titles and drawing, and out of the size it is drawn at.
      private$.plot_calls <- shown_device_calls(device_id)

      grouped <- group_device_calls(device_id)
      private$.plot_groups <- grouped$groups
      private$.layout_calls <- grouped$layout_calls

      # Settled before anything is drawn: the recorded calls are drawn again
      # at this size (see `get_gtable()`), which enlarges it only for a
      # drawing that does not fit a size no one asked for. A chartSeries()
      # chart is held to the candlestick minimum, whose layout it is.
      has_chartseries <- any(vapply(
        private$.plot_groups,
        function(g) identical(g$high_call$function_name, "chartSeries"),
        logical(1)
      ))
      private$.size_asked <- asked
      private$.canvas <- chart_canvas_size(
        width,
        height,
        candlestick = has_chartseries,
        asked = asked
      )

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

      # The drawing numbers the plots of the page as R started them, so a
      # group's processor looks its grobs up by its plot's number on the
      # page (`plot_numbers()`), not by the group's own index: a group drawn
      # before the layout call is not drawn, and a plot drawn over another,
      # or a panel passed over, takes a number of its own.
      panel_config <- detect_panel_configuration(private$.device_id)
      panel_slots <- if (is_multipanel_config(panel_config)) {
        compute_panel_slots(private$.plot_groups, panel_config)
      } else {
        NULL
      }
      plot_numbers <- private$plot_numbers(panel_slots)

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
        layer_info$group_index <- plot_numbers[[layer_info$group_index]]
        # Drawn over the group's plot on one of its own, after
        # `par(new = TRUE)`, a call's marks are that plot's
        # (`drawn_over_group_plot()`).
        overlay <- layer_info$plot_call
        if (isTRUE(overlay$overlay) && length(overlay$end_plot) == 1L) {
          layer_info$group_index <- as.integer(overlay$end_plot)
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

        # Check low-level calls for axis(), but for one drawn over the
        # group's plot in coordinates of its own (`drawn_over_group_plot()`)
        if (length(group$low_calls) > 0) {
          for (low_call in group$low_calls) {
            if (low_call$function_name == "axis" && !isTRUE(low_call$overlay)) {
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
    #'   chart is too small for R to draw at a size asked for (see
    #'   [base_r_drawing_grob()]); one not asked for is enlarged to fit
    #'   ([base_r_page_that_fits()]).
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

          # Each group in its panel. Groups with an NA slot (drawn before
          # the layout call) are excluded so the SVG matches the data grid.
          private$replay_page(panel_slots, private$plot_numbers(panel_slots), panel_config)
        }

        tryCatch(
          {
            composite_grob <- private$drawing_grob(composite_func)

            # Also store individual grobs for reference
            private$.grob_list <- list(composite_grob)
            private$.cached_gtable <- composite_grob

            return(composite_grob)
          },
          error = function(e) {
            # A chart too small to draw at a size asked for stops, naming
            # its size (`base_r_drawing_grob()`).
            if (inherits(e, "maidr_chart_draw_error")) {
              stop(e)
            }
            warning("Failed to create multipanel grob: ", e$message)
            NULL
          }
        )
      } else {
        # A single panel: the page R shows holds one plot, and the plots
        # drawn over it -- after `par(new = TRUE)`, or with `add = TRUE` --
        # which R drew on the same page and are drawn on it here too, as R
        # drew them. Plots on the pages before are not among the groups
        # (`last_page_calls()`).
        page_func <- function() {
          private$replay_page(rep(1L, length(private$.plot_groups)), private$plot_numbers())
        }

        # The drawing settles the canvas, enlarging it or stopping as
        # above; one that fails for another reason leaves no drawing.
        grob <- tryCatch(
          private$drawing_grob(page_func),
          error = function(e) {
            if (inherits(e, "maidr_chart_draw_error")) {
              stop(e)
            }
            NULL
          }
        )
        private$.grob_list <- if (is.null(grob)) list() else list(grob)
        private$.cached_gtable <- grob
        grob
      }
    },
    #' @description The size the chart is drawn at
    #' @return A named numeric vector, `width` and `height`, in inches
    canvas_size = function() {
      private$.canvas
    },
    #' @description The size a picture of the chart is drawn at, in place of
    #'   a chart maidr cannot read or export
    #'
    #' The picture draws every recorded call again, as R drew them, and is
    #' held to the chart's size as the chart is: too small for a size asked
    #' for, it stops; too small for one no one asked for, it is drawn larger,
    #' with a message naming the size. A picture R cannot draw at any size
    #' is drawn at the chart's, as before: it shows what R draws of it.
    #' @return A named numeric vector, `width` and `height`, in inches
    picture_size = function() {
      draw <- function() {
        for (call in private$.plot_calls) {
          replay_plot_call(
            call$function_name, call$args, call$call_env,
            rng_state = call$rng_state
          )
        }
      }
      canvas <- private$.canvas
      failure <- tryCatch(
        {
          suppressWarnings(grid::grid.grabExpr(
            draw(),
            warn = 0,
            width = canvas[["width"]],
            height = canvas[["height"]]
          ))
          NULL
        },
        error = function(e) e
      )
      largest <- c(width = MAIDR_MAX_CHART_SIZE, height = MAIDR_MAX_CHART_SIZE)
      if (!is.null(failure) && base_r_draws_at(draw, largest)) {
        private$enlarge_canvas(draw, base_r_too_small(failure, canvas))
      }
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

      # Every layer shares the drawing of the page: the processors find their
      # own elements in it by their group's number (`group_index`).
      if (length(private$.grob_list) > 0) {
        return(private$.grob_list[[1]])
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

#' Give the plot a drawing is on the coordinates a call was drawn in
#'
#' Those of a plot no recorded call started, which what set them --
#' `plot.window()`, or a plot maidr does not record -- set unrecorded
#' (`base_r_plot_window()`).
#'
#' @param window A recorded call's `window`
#' @return `window`, or NULL where it holds no coordinates, and none are set
#' @keywords internal
#' @noRd
replay_plot_window <- function(window) {
  if (length(window$usr) != 4L) {
    return(NULL)
  }
  log <- paste(c(if (isTRUE(window$xlog)) "x", if (isTRUE(window$ylog)) "y"), collapse = "")
  limits <- function(usr, logged) if (isTRUE(logged)) 10^usr else usr
  graphics::plot.window(
    xlim = limits(window$usr[1:2], window$xlog),
    ylim = limits(window$usr[3:4], window$ylog),
    log = log,
    xaxs = "i",
    yaxs = "i"
  )
  window
}

#' Start the plots R started before the one a drawing draws next
#'
#' Up to plot `upto` of the page, plots no recorded call started and no
#' recorded call drew on: a panel `plot.new()` or `frame()` passed over, or
#' a plot maidr does not record. Each moves on a panel while the panel of
#' the plot drawn next (`slot`) is still ahead, and is drawn over the last
#' panel once it is not, as R's would have been.
#'
#' @param at Where the drawing is (see `replay_page()`)
#' @param upto The number of the last plot to start
#' @param slot The panel of the plot drawn next
#' @return Where the drawing is then
#' @keywords internal
#' @noRd
start_skipped_plots <- function(at, upto, slot) {
  for (k in seq_len(max(upto - at$plots, 0L))) {
    stays <- at$slot > 0L && at$slot >= slot - 1L
    if (!stays) {
      at$slot <- at$slot + 1L
      at$figure <- if (is.numeric(at$figure)) at$figure + 1L
    }
    start_replayed_plot(stays)
    at$plots <- at$plots + 1L
  }
  at
}

#' Send the plot a recorded call starts where R put it, as it is drawn again
#'
#' In the panel of the plot before it (`slot`, the panel R drew it in, is
#' `figure`, the one the drawing is in), in the next, or, where R was sent
#' to it out of turn with `par(mfg = )`, in that panel of the `mfrow` or
#' `mfcol` grid; `layout()` takes no `par(mfg = )`. A plot R drew in a
#' region `par(fig = )` or `screen()` set, outside any grid, is drawn in
#' that region (`is_figure_region()`).
#'
#' @param high The recorded call, with the `cell` and `fig` R put its plot
#'   in (`end_base_r_call()`)
#' @param slot,figure The panel R drew the plot in, and the one the drawing
#'   is in, each 0 for none
#' @param panel_config The page's grid, or NULL for a page of one panel
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
place_replayed_plot <- function(high, slot, figure, panel_config = NULL) {
  jumps <- figure > 0L && slot != figure && slot != figure + 1L &&
    isTRUE(panel_config$type %in% c("mfrow", "mfcol"))
  if (jumps) {
    graphics::par(mfg = panel_slot_positions(slot, panel_config)[[1]])
  } else {
    if (is_figure_region(high, panel_config, graphics::par("fig"))) {
      graphics::par(fig = high$fig)
    }
    start_replayed_plot(slot <= figure, start = FALSE)
  }
  invisible(NULL)
}

#' Whether R drew a recorded call's plot in a region of the page it was given
#'
#' `par(fig = )`, and `screen()` with it, give the plot drawn next a region
#' of the page outside any grid: R reports the cell of a grid of one, and a
#' region that is not the whole page -- or is the whole page, on a page laid
#' out as a grid of several panels, or where the drawing is in another
#' region, as on a page of regions or screens: a legend for them all is
#' drawn over the page after `par(fig = c(0, 1, 0, 1), new = TRUE)`.
#'
#' @param high The recorded call
#' @param panel_config The page's grid, or NULL for a page of one panel
#' @param drawing_fig The region of the page the drawing is in, before the
#'   plot is drawn
#' @return Logical
#' @keywords internal
#' @noRd
is_figure_region <- function(high, panel_config = NULL, drawing_fig = c(0, 1, 0, 1)) {
  page <- c(0, 1, 0, 1)
  apart <- function(fig) isTRUE(max(abs(fig - page)) > 1e-6)
  length(high$cell) == 4L && identical(as.integer(high$cell[3:4]), c(1L, 1L)) &&
    length(high$fig) == 4L &&
    (apart(high$fig) || is_multipanel_config(panel_config) || apart(drawing_fig))
}

#' Say whether the next plot of a drawing stays in the panel of the last
#'
#' `par(new = )` is set either way, never left as it was. R clears it once a
#' plot draws anything, but gridGraphics, which echoes the drawing as grobs
#' (`base_r_drawing_grob()`), follows only `par()` and `plot.new()`: after
#' one plot drawn with `par(new = TRUE)` it kept every later plot in that
#' plot's panel, so after `par(new = TRUE); plot(b); plot(c)` in a grid `c`
#' was drawn over `b`, where R draws it in the next panel.
#'
#' @param stays Whether the plot stays in the panel of the plot before it
#' @param start Whether to start the plot here, with `plot.new()`, or leave
#'   it to the recorded call that draws it
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
start_replayed_plot <- function(stays, start = TRUE) {
  graphics::par(new = stays)
  if (start) {
    graphics::plot.new()
  }
  invisible(NULL)
}

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
#' fits the largest page a chart is drawn on, [MAIDR_MAX_CHART_SIZE] on each
#' side; any other failure is raised as R raised it, for the caller to
#' handle as before. A size no one asked for is the orchestrator's to
#' enlarge ([base_r_page_that_fits()]).
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

  draw_as_ggplotify_does <- ggplotify_drawing(draw)
  grab <- function(expr) {
    grid::grid.grabExpr(
      expr,
      warn = 0,
      width = size[["width"]],
      height = size[["height"]]
    )
  }

  cannot_draw <- function(e) {
    largest <- c(width = MAIDR_MAX_CHART_SIZE, height = MAIDR_MAX_CHART_SIZE)
    if (!base_r_draws_at(draw, largest)) {
      stop(e)
    }
    stop(base_r_too_small(e, size))
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

#' The error a Base R chart too small to draw at a size stops with
#'
#' @param e R's error drawing it at that size
#' @param size The size, a named numeric vector, `width` and `height`, in
#'   inches
#' @return A condition of class `maidr_chart_draw_error`, naming the size and
#'   R's reason
#' @keywords internal
#' @noRd
base_r_too_small <- function(e, size) {
  errorCondition(
    paste0(
      "maidr could not draw this chart at ", format_inches(size), ": ",
      conditionMessage(e), ". A Base R chart's margins and text take the ",
      "same room at every size, and at this size they leave the plot none: ",
      "give the chart a larger size."
    ),
    class = "maidr_chart_draw_error"
  )
}

#' A Base R drawing with the graphical parameters ggplotify draws it with
#'
#' `xpd = NA`, a transparent background and axis titles two lines out, as
#' [ggplotify::as.grob()] sets them before it draws.
#'
#' @param draw A function of no arguments that draws the chart
#' @return A function of no arguments
#' @keywords internal
#' @noRd
ggplotify_drawing <- function(draw) {
  function() {
    graphics::par(xpd = NA, bg = "transparent", mgp = c(2, 1, 0))
    draw()
  }
}

#' Whether R can draw a Base R drawing on a page of a size
#'
#' Drawn as [base_r_drawing_grob()] draws it, but not echoed: R stops
#' drawing a chart whose margins and text leave its plot no room on the
#' page, which is all this asks. What the drawing warns of is said when the
#' chart is drawn.
#'
#' @param draw A function of no arguments that draws the chart
#' @param size The page, a named numeric vector, `width` and `height`, in
#'   inches
#' @return Logical
#' @keywords internal
#' @noRd
base_r_draws_at <- function(draw, size) {
  !is.na(base_r_plot_room(draw, size))
}

#' The room R gives the plots of a Base R drawing on a page of a size
#'
#' Drawn as [base_r_drawing_grob()] draws it, but not echoed, the size of
#' each plot as R lays it out is read as the plot is started, and when the
#' drawing is done: the last covers a plot R starts without `plot.new()`,
#' as `persp()` does.
#'
#' @param draw A function of no arguments that draws the chart
#' @param size The page, a named numeric vector, `width` and `height`, in
#'   inches
#' @return The shorter side of the smallest plot, in inches, or `NA` when R
#'   cannot draw the drawing on the page
#' @keywords internal
#' @noRd
base_r_plot_room <- function(draw, size) {
  rooms <- numeric()
  measure <- function() rooms <<- c(rooms, min(graphics::par("pin")))
  hooks <- getHook("plot.new")
  setHook("plot.new", measure)
  on.exit(setHook("plot.new", hooks, "replace"), add = TRUE)
  tryCatch(
    {
      suppressWarnings(grid::grid.grabExpr(
        {
          ggplotify_drawing(draw)()
          measure()
        },
        warn = 0,
        width = size[["width"]],
        height = size[["height"]]
      ))
      min(rooms)
    },
    error = function(e) NA_real_
  )
}

#' The page a Base R chart too small for a size no one asked for is drawn on
#'
#' Before maidr drew a Base R chart at its size it laid every one out on the
#' 7 x 7 in page [ggplotify::as.grob()] draws on (see
#' [base_r_drawing_grob()]), so a chart too tall for maidr's own 7 x 5 in --
#' a `par(mfrow)` grid of five rows -- was drawn. Such a chart still is, on
#' that page, or on one as large as the canvas on a side where the canvas
#' is larger. A chart too large for that page as well, as a grid of six
#' rows is, is drawn on the smallest page larger than the canvas that gives
#' each of its plots at least a sixth of an inch, 12 px, each way: about
#' what a five-row grid's plots have on the 7 x 7 in page, and enough to be
#' seen, where the least R draws on leaves a plot a pixel high. Each side is
#' the canvas's own or a whole number of inches: it grows an inch at a time
#' to the least that gives the plots their room while the other side has
#' all it could want, and then both together for as long as the chart still
#' does not fit, as a layout that keeps its panels' shape (`respect = TRUE`)
#' may need. A chart no page gives that room, a grid of forty rows, is drawn
#' on the smallest page R draws it on.
#'
#' Called once the chart has failed for its size, with a
#' `maidr_chart_draw_error`: it then fits the largest page a chart is drawn
#' on, [MAIDR_MAX_CHART_SIZE] on each side, which is as large as this grows
#' the page.
#'
#' @param draw A function of no arguments that draws the chart
#' @param size The canvas it is too small for, from [chart_canvas_size()]
#' @return The page, a named numeric vector, `width` and `height`, in inches
#' @keywords internal
base_r_page_that_fits <- function(draw, size) {
  fits <- function(page) isTRUE(base_r_plot_room(draw, page) >= 1 / 6)
  page <- pmax(size, c(width = 7, height = 7))
  if (fits(page)) {
    return(page)
  }

  largest <- c(width = MAIDR_MAX_CHART_SIZE, height = MAIDR_MAX_CHART_SIZE)
  if (!fits(largest)) {
    fits <- function(page) base_r_draws_at(draw, page)
  }
  least <- function(side) {
    trial <- largest
    for (value in c(size[[side]], seq(floor(size[[side]]) + 1, largest[[side]]))) {
      trial[[side]] <- value
      if (fits(trial)) {
        return(value)
      }
    }
    largest[[side]]
  }
  page <- c(width = least("width"), height = least("height"))
  while (!fits(page) && any(page < largest)) {
    page <- pmin(floor(page) + 1, largest)
  }
  page
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
