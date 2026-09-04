#' Which of a plot's layers drew no rows
#'
#' The one place the emptiness rule lives, so the orchestrator and the
#' patchwork leaf path cannot disagree about it. A leaf inside a
#' \code{patchwork} composition is classified by
#' \code{ggplot2_patchwork_utils.R} rather than by
#' \code{Ggplot2PlotOrchestrator$detect_layers()}, so a rule written only in
#' the orchestrator would have left every composed chart ghosting (#232).
#'
#' One \code{ggplot_build()} per plot, not per layer. That is what makes this
#' affordable at all: the same question asked inside
#' \code{detect_layer_type()} would multiply the build by the layer count,
#' which is why #231 applied it to one geom only.
#'
#' A build that cannot answer reports nothing empty. A plot that will not
#' build is a bigger problem than this one, and it is about to be met by
#' whatever else needs the build.
#'
#' @param plot A ggplot object.
#' @return Integer indices into \code{plot$layers}, possibly empty.
#' @keywords internal
layers_that_drew_nothing <- function(plot) {
  built <- tryCatch(ggplot2::ggplot_build(plot), error = function(e) NULL)
  if (is.null(built) || is.null(built$data)) {
    return(integer(0))
  }

  which(vapply(
    built$data,
    function(drawn) !is.null(drawn) && isTRUE(nrow(drawn) == 0L),
    logical(1)
  ))
}


#' Plot Orchestrator Class
#'
#' @description
#' This class orchestrates the detection and processing of multiple layers
#' in a ggplot2 object. It analyzes each layer individually and combines
#' the results into a comprehensive interactive plot.
#'
#' @keywords internal
Ggplot2PlotOrchestrator <- R6::R6Class(
  "Ggplot2PlotOrchestrator",
  private = list(
    .plot = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .combined_selectors = list(),
    .layout = NULL,
    .gtable = NULL,
    .adapter = NULL,
    .format_config = NULL
  ),
  public = list(
    initialize = function(plot) {
      private$.plot <- plot

      # The jitter recovery memoises per layer, and a layer is not enough to
      # identify a plot: ggplot2 documents a layer as reusable across plots,
      # and `+.gg` appends the same ggproto object rather than a clone. Two
      # plots built from one `geom_jitter()` are therefore `identical()` at
      # that layer, and the second was answered with the first's values --
      # silently, whenever the row counts matched (#174 review).
      #
      # Cleared here rather than guarded inside the cache, because this is the
      # boundary the cache was scoped to in the first place: it exists to stop
      # a faceted plot rebuilding once per panel, and a panel only belongs to
      # the run that is starting now.
      reset_jitter_cache()

      registry <- get_global_registry()
      system_name <- registry$detect_system(plot)
      private$.adapter <- registry$get_adapter(system_name)

      if (self$is_patchwork_plot()) {
        self$process_patchwork_plot()
      } else if (self$is_faceted_plot()) {
        self$process_faceted_plot()
      } else {
        self$detect_layers()
        self$create_layer_processors()
        self$process_layers()
      }
    },
    detect_layers = function() {
      layers <- private$.plot$layers
      private$.layers <- list()

      for (i in seq_along(layers)) {
        layer_info <- self$analyze_single_layer(layers[[i]], i)
        private$.layers[[i]] <- layer_info
      }

      self$skip_layers_that_drew_nothing()
    },

    #' @description Retag every layer that drew no rows as \code{"skip"}.
    #'
    #' A layer can be typed perfectly well and still have nothing in it -- a
    #' \code{data =} filtered to nothing, a stat that dropped every row, a
    #' facet arrangement in which one layer's data is empty, a **Suggests**
    #' package absent so the stat could not run. It then reaches the schema
    #' as a layer a reader can walk into and find nothing in. Measured on ten
    #' points, the second layer drawn from \code{d[0, ]}:
    #'
    #' \preformatted{
    #' geom_point()   point(0)      an empty layer of points
    #' geom_col()     bar(0)        an empty layer of bars
    #' geom_line()    line(1x0)     one series, holding nothing
    #' geom_smooth()  smooth(1x0)   one series, holding nothing
    #' }
    #'
    #' Asked here rather than in \code{detect_layer_type()} because emptiness
    #' is not a fact about what *kind* of chart a layer is, and because the
    #' classifier runs per layer: one \code{ggplot_build()} for the whole
    #' pass costs a chart ~37 ms once, where asking per layer would multiply
    #' it. \code{"skip"} rather than a fourth answer, because that is the tag
    #' the rest of the orchestrator already understands -- including the #176
    #' guard, so a chart whose *only* layer is empty falls back to an image
    #' rather than announcing itself as interactive with nothing in it.
    #'
    #' A build that cannot answer changes nothing. That is the same posture
    #' \code{layer_drew_nothing()} takes: a plot that will not build is a
    #' bigger problem than this, and it is about to be met by whatever else
    #' needs the build.
    #'
    #' @return NULL, invisibly. Rewrites \code{private$.layers} in place.
    skip_layers_that_drew_nothing = function() {
      for (i in layers_that_drew_nothing(private$.plot)) {
        if (i <= length(private$.layers)) {
          private$.layers[[i]]$type <- "skip"
        }
      }

      invisible(NULL)
    },
    analyze_single_layer = function(layer, layer_index) {
      # Safely extract layer components with error handling
      geom <- tryCatch(layer$geom, error = function(e) NULL)
      stat <- tryCatch(layer$stat, error = function(e) NULL)
      position <- tryCatch(layer$position, error = function(e) NULL)
      mapping <- tryCatch(layer$mapping, error = function(e) NULL)
      params <- tryCatch(layer$params, error = function(e) list())

      geom_class <- if (!is.null(geom)) class(geom)[1] else "unknown"
      stat_class <- if (!is.null(stat)) class(stat)[1] else "unknown"
      position_class <- if (!is.null(position)) class(position)[1] else "unknown"

      layer_type <- private$.adapter$detect_layer_type(layer, private$.plot)

      layer_info <- list(
        index = layer_index,
        type = layer_type,
        geom_class = geom_class,
        stat_class = stat_class,
        position_class = position_class,
        aesthetics = if (!is.null(mapping)) names(mapping) else character(0),
        parameters = if (!is.null(params)) names(params) else character(0),
        layer_object = layer
      )

      layer_info
    },
    determine_layer_type = function(plot, layer_index) {
      layer <- plot$layers[[layer_index]]
      if (is.null(layer)) {
        return("unknown")
      }

      # Delegate layer type detection to the adapter
      private$.adapter$detect_layer_type(layer, plot)
    },
    create_layer_processors = function() {
      private$.layer_processors <- list()

      for (i in seq_along(private$.layers)) {
        layer_info <- private$.layers[[i]]
        # Skip layers that don't need processing (like text labels)
        if (layer_info$type != "skip") {
          processor <- self$create_layer_processor(layer_info)
          private$.layer_processors[[i]] <- processor
        }
      }
    },
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
    process_layers = function() {
      plot_for_render <- private$.plot
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        if (is.null(processor)) next
        if (isTRUE(processor$needs_reordering())) {
          if (
            is.data.frame(plot_for_render$data) &&
              nrow(plot_for_render$data) > 0 &&
              ncol(plot_for_render$data) > 0
          ) {
            reordered <- processor$reorder_layer_data(plot_for_render$data, plot_for_render)
            if (is.data.frame(reordered) && nrow(reordered) > 0 && ncol(reordered) > 0) {
              plot_for_render$data <- reordered
            }
          }
        }
      }

      # Allow processors to augment the plot (e.g., violin injects boxplot)
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        if (!is.null(processor) && isTRUE(processor$needs_augmentation())) {
          plot_for_render <- processor$augment_plot(plot_for_render)
        }
      }

      # Suppress native R graphics window by using a null PDF device.
      # This ensures only the HTML output is displayed. `finally` guards
      # the device/tempfile cleanup against build errors.
      # Build ONCE and derive the gtable from the built object:
      # ggplotGrob() would re-run the whole ggplot_build() internally.
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = 7, height = 5)
      built_final <- tryCatch(
        {
          built <- ggplot2::ggplot_build(plot_for_render)
          private$.gtable <- ggplot2::ggplot_gtable(built)
          built
        },
        finally = {
          grDevices::dev.off()
          if (current_dev > 1) grDevices::dev.set(current_dev)
          unlink(null_pdf)
        }
      )

      # Reuse the build for layout labels instead of building again
      private$.layout <- self$extract_layout(built_final)

      # Extract format configuration from scale label functions (maidr:: label wrappers)
      private$.format_config <- extract_format_config(built_final)

      layer_results <- list()
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        if (is.null(processor)) next

        result <- processor$process(
          plot_for_render,
          private$.layout,
          built = built_final,
          gt = private$.gtable
        )
        processor$set_last_result(result)
        layer_results[[i]] <- result
      }

      self$combine_layer_results(layer_results)
    },
    extract_layout = function(built = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(private$.plot)
      }

      # Use built$plot$labels (post-build) which includes stat-generated labels
      # like "count" for geom_bar(). In ggplot2 v4, the pre-build plot$labels
      # may be empty; labels are only resolved after ggplot_build().
      built_labels <- built$plot$labels

      # Extract x label: try built labels first, then user labels, then mapping
      x_label <- built_labels$x
      if (is.null(x_label)) x_label <- private$.plot$labels$x
      if (is.null(x_label) && !is.null(private$.plot$mapping$x)) {
        x_label <- rlang::as_label(private$.plot$mapping$x)
      }
      if (is.null(x_label)) x_label <- ""

      # Extract y label: try built labels first, then user labels, then mapping
      y_label <- built_labels$y
      if (is.null(y_label)) y_label <- private$.plot$labels$y
      if (is.null(y_label) && !is.null(private$.plot$mapping$y)) {
        y_label <- rlang::as_label(private$.plot$mapping$y)
      }
      if (is.null(y_label)) y_label <- ""

      # Extract title/subtitle/caption from built labels (includes user labs())
      plot_title <- built_labels$title
      if (is.null(plot_title)) plot_title <- private$.plot$labels$title

      plot_subtitle <- built_labels$subtitle
      if (is.null(plot_subtitle)) plot_subtitle <- private$.plot$labels$subtitle

      plot_caption <- built_labels$caption
      if (is.null(plot_caption)) plot_caption <- private$.plot$labels$caption

      layout <- list(
        title = if (!is.null(plot_title)) plot_title else "",
        subtitle = if (!is.null(plot_subtitle)) plot_subtitle else NULL,
        caption = if (!is.null(plot_caption)) plot_caption else NULL,
        axes = build_axes(x = x_label, y = y_label)
      )

      layout
    },
    combine_layer_results = function(layer_results) {
      combined_data <- list()

      layer_counter <- 0
      for (i in seq_along(layer_results)) {
        result <- layer_results[[i]]
        # Skip layers that were filtered out (e.g. GeomLinerangeBC wick layer
        # tagged "skip" by the adapter; the orchestrator leaves a NULL slot).
        if (is.null(result)) next

        # --- Multi-layer expansion (e.g. violin -> violin_box + violin_kde) ---
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
            validate_axes(sub_axes, context = "ggplot2 orchestrator (multi-layer)")
            layer_obj <- list(
              id = layer_counter,
              selectors = sub$selectors,
              type = sub$type,
              data = sub$data,
              title = sub$title,
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
            combined_data[[layer_counter]] <- layer_obj
          }
          next
        }

        # --- Normal single-layer result ---
        layer_counter <- layer_counter + 1

        layer_type <- result$type
        if (is.null(layer_type) || length(layer_type) == 0) {
          layer <- private$.plot$layers[[i]]
          layer_type <- private$.adapter$detect_layer_type(layer, private$.plot)
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
        validate_axes(layer_axes, context = "ggplot2 orchestrator")

        layer_obj <- list(
          id = layer_counter,
          selectors = result$selectors,
          type = layer_type,
          data = result$data,
          title = result$title,
          axes = layer_axes
        )

        # Preserve all other fields from the processor result (like orientation, etc.)
        for (field_name in names(result)) {
          if (!field_name %in% c("selectors", "data", "title", "axes", "labels")) {
            layer_obj[[field_name]] <- result[[field_name]]
          }
        }

        if (!is.null(result$labels) && length(result$labels) > 0) {
          layer_obj$labels <- result$labels
        }

        combined_data[[layer_counter]] <- layer_obj
      }

      combined_selectors <- list()
      for (result in layer_results) {
        if (is.null(result)) next
        combined_selectors <- c(combined_selectors, result$selectors)
      }

      # For single plots, wrap the combined_data in the correct 2D grid format
      # This ensures all plot types have the same structure
      if (!self$is_patchwork_plot() && !self$is_faceted_plot()) {
        # Single plot: create 1x1 grid
        single_subplot <- list(
          id = paste0("maidr-subplot-", generate_unique_id()),
          layers = combined_data
        )
        # Collapse multiple line layers (e.g. candlestick + several MAs)
        # into one multi-series line layer so the JS frontend announces
        # them as one multiline layer (matching py-maidr).
        single_subplot <- collapse_lines_to_multiseries(single_subplot)
        private$.combined_data <- list(list(single_subplot))
      } else {
        # Faceted/patchwork plots already have the correct 2D grid format
        private$.combined_data <- combined_data
      }

      private$.combined_selectors <- combined_selectors
    },
    generate_maidr_data = function() {
      # All plot types use the same unified structure
      # The combined_data already has the correct format for each plot type
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
    get_gtable = function() {
      private$.gtable
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

    #' @description Check if the plot is a patchwork composition
    #' @return Logical indicating if the plot is a patchwork plot
    is_patchwork_plot = function() {
      inherits(private$.plot, "patchwork")
    },

    #' @description Check if the plot is faceted
    #' @return Logical indicating if the plot is faceted
    is_faceted_plot = function() {
      if (is.null(private$.plot$facet)) {
        return(FALSE)
      }

      facet_class <- class(private$.plot$facet)[1]
      facet_class != "FacetNull"
    },

    #' @description Process a faceted plot using utility functions
    #' @return NULL (sets internal state)
    process_faceted_plot = function() {
      # Create layer processors to access reorder functions
      self$detect_layers()
      self$create_layer_processors()

      # Reorder data before rendering (same as process_layers does for normal plots)
      # This ensures grob tree order matches data order within each facet panel
      plot_for_render <- private$.plot
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        if (is.null(processor)) next
        if (isTRUE(processor$needs_reordering())) {
          if (
            is.data.frame(plot_for_render$data) &&
              nrow(plot_for_render$data) > 0 &&
              ncol(plot_for_render$data) > 0
          ) {
            reordered <- processor$reorder_layer_data(plot_for_render$data, plot_for_render)
            if (is.data.frame(reordered) && nrow(reordered) > 0 && ncol(reordered) > 0) {
              plot_for_render$data <- reordered
            }
          }
        }
      }

      # Suppress native R graphics window by using a null PDF device.
      # Build ONCE and derive the gtable from the built object; `finally`
      # guards cleanup against build errors.
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = 7, height = 5)
      built <- tryCatch(
        {
          built_plot <- ggplot2::ggplot_build(plot_for_render)
          private$.gtable <- ggplot2::ggplot_gtable(built_plot)
          built_plot
        },
        finally = {
          grDevices::dev.off()
          if (current_dev > 1) grDevices::dev.set(current_dev)
          unlink(null_pdf)
        }
      )

      # Reuse the build for layout labels instead of building again
      private$.layout <- self$extract_layout(built)

      # Extract format configuration from scale label functions
      private$.format_config <- extract_format_config(built)

      # Use utility function to process faceted plot (use reordered plot)
      private$.combined_data <- process_faceted_plot_data(
        plot_for_render,
        private$.layout,
        built,
        private$.gtable,
        format_config = private$.format_config
      )
      private$.combined_selectors <- list()
    },

    #' @description Process a patchwork multipanel plot using utility functions
    #' @return NULL (sets internal state)
    process_patchwork_plot = function() {
      # Minimal layout information
      private$.layout <- list(
        title = if (!is.null(private$.plot$labels$title)) private$.plot$labels$title else "",
        subtitle = if (!is.null(private$.plot$labels$subtitle)) {
          private$.plot$labels$subtitle
        } else {
          NULL
        },
        caption = if (!is.null(private$.plot$labels$caption)) {
          private$.plot$labels$caption
        } else {
          NULL
        },
        axes = list()
      )

      # Let processors add the geoms their selectors need (violin injects a
      # thin boxplot). The augmented composition must be both rendered and
      # processed: grob names come from a global counter, so selectors
      # computed against one build do not resolve against another.
      plot_for_render <- augment_patchwork_leaves(private$.plot)

      # Suppress native R graphics window by using a null PDF device
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = 7, height = 5)

      tryCatch(
        {
          if (requireNamespace("patchwork", quietly = TRUE)) {
            private$.gtable <- patchwork::patchworkGrob(plot_for_render)
          } else {
            private$.gtable <- ggplot2::ggplotGrob(ggplot2::ggplot())
          }
        },
        finally = {
          # Close null device and restore previous device
          grDevices::dev.off()
          if (current_dev > 1) grDevices::dev.set(current_dev)
          unlink(null_pdf)
        }
      )

      # Use utility function to process patchwork plot
      private$.combined_data <- process_patchwork_plot_data(
        plot_for_render,
        private$.layout,
        private$.gtable,
        original_plot = private$.plot
      )
      private$.combined_selectors <- list()
    },

    #' @description Check if any layers are unsupported (unknown type)
    #' @return Logical indicating if there are unsupported layers
    has_unsupported_layers = function() {
      if (length(private$.layers) == 0) {
        return(FALSE)
      }

      if (any(sapply(private$.layers, function(layer) {
        isTRUE(layer$type == "unknown")
      }))) {
        return(TRUE)
      }

      # Nothing unsupported, and also nothing to read. A layer the adapter
      # tags "skip" is drawn but carries no observations -- a reference line,
      # a text annotation, a candlestick's wick folded into its body -- so a
      # plot made only of those emits zero layers.
      #
      # That has to keep falling back. #176 stopped one `geom_hline()` costing
      # a whole chart its interactivity by skipping the line instead of
      # declaring the plot unsupported, and the trap on the other side of that
      # is "no unsupported layers" quietly coming to mean "no layers at all":
      # a chart announcing itself as interactive with nothing in it is worse
      # than an image, because an image at least says what it is.
      all(sapply(private$.layers, function(layer) {
        isTRUE(layer$type == "skip")
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
