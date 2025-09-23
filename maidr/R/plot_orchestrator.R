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
#' @export
PlotOrchestrator <- R6::R6Class("PlotOrchestrator",
  private = list(
    # Private fields
    .plot = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .combined_selectors = list(),
    .layout = NULL,
    .gtable = NULL
  ),
  public = list(
    # Constructor
    initialize = function(plot) {
      private$.plot <- plot
      self$detect_layers()
      self$create_layer_processors()
      self$process_layers()
    },

    #' Detect all layers in the plot
    detect_layers = function() {
      layers <- private$.plot$layers
      private$.layers <- list()

      for (i in seq_along(layers)) {
        layer_info <- self$analyze_single_layer(layers[[i]], i)
        private$.layers[[i]] <- layer_info
      }
    },

    #' Analyze a single layer
    analyze_single_layer = function(layer, layer_index) {
      # Extract layer components
      geom <- layer$geom
      stat <- layer$stat
      position <- layer$position
      mapping <- layer$mapping
      params <- layer$params

      # Get class information
      geom_class <- class(geom)[1]
      stat_class <- class(stat)[1]
      position_class <- class(position)[1]

      # Determine layer type using class-based logic
      layer_type <- self$determine_layer_type(private$.plot, layer_index)

      # Create layer information
      layer_info <- list(
        index = layer_index,
        type = layer_type,
        geom_class = geom_class,
        stat_class = stat_class,
        position_class = position_class,
        aesthetics = if (!is.null(mapping)) names(mapping) else character(0),
        parameters = names(params),
        layer_object = layer
      )

      layer_info
    },

    #' Determine layer type using class-based ggplot2 semantics
    determine_layer_type = function(plot, layer_index) {
      layer <- plot$layers[[layer_index]]
      if (is.null(layer)) return("unknown")

      geom_class <- class(layer$geom)[1]
      stat_class <- class(layer$stat)[1]
      position_class <- class(layer$position)[1]

      if (geom_class %in% c("GeomLine", "GeomPath")) return("line")
      if (geom_class == "GeomSmooth" || stat_class == "StatDensity") return("smooth")

      if (geom_class %in% c("GeomBar", "GeomCol")) {
        if (stat_class == "StatBin") return("hist")

        if (position_class %in% c("PositionDodge", "PositionDodge2")) return("dodged_bar")

        if (position_class %in% c("PositionStack", "PositionFill")) {
          layer_mapping <- layer$mapping
          plot_mapping <- plot$mapping
          has_fill <- (!is.null(layer_mapping) && !is.null(layer_mapping$fill)) ||
            (!is.null(plot_mapping) && !is.null(plot_mapping$fill))
          if (has_fill) {
            return("stacked_bar")
          }
        }

        return("bar")
      }
      "unknown"
    },

    # =======================================================================
    # LAYER PROCESSOR CREATION
    # =======================================================================

    #' Create layer-specific processors
    create_layer_processors = function() {
      private$.layer_processors <- list()

      for (i in seq_along(private$.layers)) {
        layer_info <- private$.layers[[i]]
        processor <- self$create_layer_processor(layer_info)
        private$.layer_processors[[i]] <- processor
      }
    },

    #' Create a layer-specific processor
    create_layer_processor = function(layer_info) {
      layer_type <- layer_info$type

      # Create processor based on layer type (only existing types)
      processor <- switch(layer_type,
        "bar" = BarLayerProcessor$new(layer_info),
        "stacked_bar" = StackedBarLayerProcessor$new(layer_info),
        "dodged_bar" = DodgedBarLayerProcessor$new(layer_info),
        "hist" = HistogramLayerProcessor$new(layer_info),
        "line" = LineLayerProcessor$new(layer_info),
        "smooth" = SmoothLayerProcessor$new(layer_info),
        UnknownLayerProcessor$new(layer_info) # Default for unknown types
      )

      processor
    },

    # =======================================================================
    # LAYER PROCESSING
    # =======================================================================

    #' Process all layers
    process_layers = function() {
      # Phase 0: layout from original plot
      private$.layout <- self$extract_layout()

      # Phase 1: determine final plot for rendering via layer-local data reorders
      plot_for_render <- private$.plot
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        if (isTRUE(processor$needs_reordering())) {
          # Effective data for this layer
          layer_data <- plot_for_render$layers[[i]]$data
          if (is.null(layer_data)) layer_data <- plot_for_render$data
          if (!is.null(layer_data) && is.data.frame(layer_data)) {
            reordered <- processor$reorder_layer_data(layer_data, plot_for_render)
            if (is.data.frame(reordered)) {
              # Assign back only to this layer
              plot_for_render$layers[[i]]$data <- reordered
            }
          }
        }
      }

      # Phase 2: build and gtable once
      built_final <- ggplot2::ggplot_build(plot_for_render)
      gt_final <- ggplot2::ggplotGrob(plot_for_render)
      private$.gtable <- gt_final

      # Phase 3: process each layer using shared artifacts
      layer_results <- list()
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        result <- processor$process(plot_for_render, private$.layout, built_final, gt_final)
        processor$set_last_result(result)
        layer_results[[i]] <- result
      }

      # Results are stored on processors; combined aggregation not required
    },

    #' Extract layout information
    extract_layout = function() {
      # Build the plot to get actual axis labels
      built <- ggplot2::ggplot_build(private$.plot)

      # Extract title, axes labels, etc.
      layout <- list(
        title = if (!is.null(private$.plot$labels$title)) private$.plot$labels$title else "",
        axes = list(
          x = if (!is.null(private$.plot$labels$x)) private$.plot$labels$x else "",
          y = if (!is.null(private$.plot$labels$y)) private$.plot$labels$y else ""
        )
      )

      layout
    },

    #' Combine results from all layers
    combine_layer_results = function(layer_results) {
      # Combine data without additional annotation
      combined_data <- list()
      for (i in seq_along(layer_results)) {
        result <- layer_results[[i]]
        combined_data <- c(combined_data, result$data)
      }

      # Combine selectors
      combined_selectors <- list()
      for (result in layer_results) {
        combined_selectors <- c(combined_selectors, result$selectors)
      }

      # Store combined results
      private$.combined_data <- combined_data
      private$.combined_selectors <- combined_selectors
    },

    # =======================================================================
    # OUTPUT GENERATION
    # =======================================================================

    #' Generate final maidr data structure
    generate_maidr_data = function() {
      # Create the final data structure
      maidr_data <- list(
        id = paste0("maidr-plot-", as.integer(Sys.time())),
        subplots = list(
          list(
            list(
              id = paste0("maidr-subplot-", as.integer(Sys.time())),
              layers = private$.combined_data
            )
          )
        )
      )

      maidr_data
    },

   

    #' Get the gtable (for consistent layer IDs)
    get_gtable = function() {
      private$.gtable
    },


    #' Get layout information
    get_layout = function() {
      private$.layout
    },

    #' Get combined data
    get_combined_data = function() {
      private$.combined_data
    },

    #' Get layer processors
    get_layer_processors = function() {
      private$.layer_processors
    }

  )
)
