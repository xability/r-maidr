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
PlotOrchestrator <- R6::R6Class("PlotOrchestrator",
  private = list(
    .plot = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .combined_selectors = list(),
    .layout = NULL,
    .gtable = NULL
  ),
  public = list(
    initialize = function(plot) {
      private$.plot <- plot
      self$detect_layers()
      self$create_layer_processors()
      self$process_layers()
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
      geom <- layer$geom
      stat <- layer$stat
      position <- layer$position
      mapping <- layer$mapping
      params <- layer$params

      geom_class <- class(geom)[1]
      stat_class <- class(stat)[1]
      position_class <- class(position)[1]

      layer_type <- self$determine_layer_type(private$.plot, layer_index)

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
    determine_layer_type = function(plot, layer_index) {
      layer <- plot$layers[[layer_index]]
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
    create_layer_processors = function() {
      private$.layer_processors <- list()

      for (i in seq_along(private$.layers)) {
        layer_info <- private$.layers[[i]]
        processor <- self$create_layer_processor(layer_info)
        private$.layer_processors[[i]] <- processor
      }
    },
    create_layer_processor = function(layer_info) {
      layer_type <- layer_info$type

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
    process_layers = function() {
      private$.layout <- self$extract_layout()

      plot_for_render <- private$.plot
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        if (isTRUE(processor$needs_reordering())) {
          if (is.data.frame(plot_for_render$data) && nrow(plot_for_render$data) > 0 && ncol(plot_for_render$data) > 0) {
            reordered <- processor$reorder_layer_data(plot_for_render$data, plot_for_render)
            if (is.data.frame(reordered) && nrow(reordered) > 0 && ncol(reordered) > 0) {
              plot_for_render$data <- reordered
            }
          }
        }
      }

      built_final <- ggplot2::ggplot_build(plot_for_render)
      gt_final <- ggplot2::ggplotGrob(plot_for_render)
      private$.gtable <- gt_final

      layer_results <- list()
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        result <- processor$process(plot_for_render, private$.layout, built_final, gt_final)
        processor$set_last_result(result)
        layer_results[[i]] <- result
      }

      self$combine_layer_results(layer_results)
    },
    extract_layout = function() {
      built <- ggplot2::ggplot_build(private$.plot)

      layout <- list(
        title = if (!is.null(private$.plot$labels$title)) private$.plot$labels$title else "",
        axes = list(
          x = if (!is.null(private$.plot$labels$x)) private$.plot$labels$x else "",
          y = if (!is.null(private$.plot$labels$y)) private$.plot$labels$y else ""
        )
      )

      layout
    },
    combine_layer_results = function(layer_results) {
      combined_data <- list()
      for (i in seq_along(layer_results)) {
        result <- layer_results[[i]]
        combined_data <- c(combined_data, result$data)
      }

      combined_selectors <- list()
      for (result in layer_results) {
        combined_selectors <- c(combined_selectors, result$selectors)
      }

      private$.combined_data <- combined_data
      private$.combined_selectors <- combined_selectors
    },
    generate_maidr_data = function() {
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
    }
  )
)
