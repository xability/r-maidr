#' Plot Orchestrator Class
#'
#' This class orchestrates the detection and processing of multiple layers
#' in a ggplot2 object. It analyzes each layer individually and combines
#' the results into a comprehensive interactive plot.
#'
#' @field plot The ggplot2 object being processed
#' @field layers List of detected layer information
#' @field layer_processors List of layer-specific processors
#' @field combined_data Combined data from all layers
#' @field combined_selectors Combined selectors from all layers
#' @field layout Layout information from the plot
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
    .adapter = NULL
  ),
  public = list(
    initialize = function(plot) {
      private$.plot <- plot

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

      plot_for_render <- private$.plot
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
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

      # Suppress native R graphics window by using a null PDF device
      # This ensures only the HTML output is displayed
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = 7, height = 5)

      built_final <- ggplot2::ggplot_build(plot_for_render)
      gt_final <- ggplot2::ggplotGrob(plot_for_render)

      # Close null device and restore previous device
      grDevices::dev.off()
      if (current_dev > 1) grDevices::dev.set(current_dev)
      unlink(null_pdf)
      private$.gtable <- gt_final

      layer_results <- list()
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]

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
    extract_layout = function() {
      built <- ggplot2::ggplot_build(private$.plot)

      # Extract x label: try labels$x first, fall back to mapping
      x_label <- private$.plot$labels$x
      if (is.null(x_label) && !is.null(private$.plot$mapping$x)) {
        x_label <- rlang::as_label(private$.plot$mapping$x)
      }
      if (is.null(x_label)) x_label <- ""

      # Extract y label: try labels$y first, fall back to mapping
      y_label <- private$.plot$labels$y
      if (is.null(y_label) && !is.null(private$.plot$mapping$y)) {
        y_label <- rlang::as_label(private$.plot$mapping$y)
      }
      if (is.null(y_label)) y_label <- ""

      layout <- list(
        title = if (!is.null(private$.plot$labels$title)) private$.plot$labels$title else "",
        axes = list(
          x = x_label,
          y = y_label
        )
      )

      layout
    },
    combine_layer_results = function(layer_results) {
      combined_data <- list()

      for (i in seq_along(layer_results)) {
        result <- layer_results[[i]]

        layer_type <- result$type
        if (is.null(layer_type) || length(layer_type) == 0) {
          layer <- private$.plot$layers[[i]]
          layer_type <- private$.adapter$detect_layer_type(layer, private$.plot)
        }

        layer_obj <- list(
          id = i,
          selectors = result$selectors,
          type = layer_type,
          data = result$data,
          title = result$title,
          axes = result$axes
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

        combined_data[[i]] <- layer_obj
      }

      combined_selectors <- list()
      for (result in layer_results) {
        combined_selectors <- c(combined_selectors, result$selectors)
      }

      # For single plots, wrap the combined_data in the correct 2D grid format
      # This ensures all plot types have the same structure
      if (!self$is_patchwork_plot() && !self$is_faceted_plot()) {
        # Single plot: create 1x1 grid
        single_subplot <- list(
          id = paste0("maidr-subplot-", as.integer(Sys.time())),
          layers = combined_data
        )
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
      list(
        id = paste0("maidr-plot-", generate_unique_id()),
        subplots = private$.combined_data
      )
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
      private$.layout <- self$extract_layout()

      # Suppress native R graphics window by using a null PDF device
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = 7, height = 5)

      private$.gtable <- ggplot2::ggplotGrob(private$.plot)

      # Built plot data
      built <- ggplot2::ggplot_build(private$.plot)

      # Close null device and restore previous device
      grDevices::dev.off()
      if (current_dev > 1) grDevices::dev.set(current_dev)
      unlink(null_pdf)

      # Use utility function to process faceted plot
      private$.combined_data <- process_faceted_plot_data(
        private$.plot,
        private$.layout,
        built,
        private$.gtable
      )
      private$.combined_selectors <- list()
    },

    #' @description Process a patchwork multipanel plot using utility functions
    #' @return NULL (sets internal state)
    process_patchwork_plot = function() {
      # Minimal layout information
      private$.layout <- list(
        title = if (!is.null(private$.plot$labels$title)) private$.plot$labels$title else "",
        axes = list()
      )

      # Suppress native R graphics window by using a null PDF device
      current_dev <- grDevices::dev.cur()
      null_pdf <- tempfile(fileext = ".pdf")
      grDevices::pdf(null_pdf, width = 7, height = 5)

      if (requireNamespace("patchwork", quietly = TRUE)) {
        private$.gtable <- patchwork::patchworkGrob(private$.plot)
      } else {
        private$.gtable <- ggplot2::ggplotGrob(ggplot2::ggplot())
      }

      # Close null device and restore previous device
      grDevices::dev.off()
      if (current_dev > 1) grDevices::dev.set(current_dev)
      unlink(null_pdf)

      # Use utility function to process patchwork plot
      private$.combined_data <- process_patchwork_plot_data(
        private$.plot,
        private$.layout,
        private$.gtable
      )
      private$.combined_selectors <- list()
    }
  )
)
