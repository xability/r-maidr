#' Base R Smooth/Density Layer Processor
#'
#' Processes Base R smooth/density plots (created with plot(density()))
#'
#' @keywords internal
BaseRSmoothLayerProcessor <- R6::R6Class("BaseRSmoothLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL,
                      scale_mapping = NULL, grob_id = NULL,
                      panel_id = NULL, panel_ctx = NULL,
                      layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "smooth",
        title = title,
        axes = axes
      )
    },

    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      density_obj <- args[[1]]

      if (!inherits(density_obj, "density")) {
        return(list())
      }

      x_values <- density_obj$x
      y_values <- density_obj$y

      data_points <- lapply(seq_along(x_values), function(i) {
        list(x = x_values[i], y = y_values[i])
      })

      list(data_points)
    },

    generate_selectors = function(layer_info, gt = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      # Use group_index for grob lookup (not layer index)
      # Multiple layers in same group share same grob with group-based naming
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      selectors <- self$generate_selectors_from_grob(gt, group_index)

      selectors
    },

    find_polyline_grobs = function(grob, call_index = NULL) {
      # Use robust utility function to find lines container
      # This doesn't rely on call_index matching the actual grob names
      find_graphics_plot_grob(grob, "lines")
    },

    generate_selectors_from_grob = function(grob, call_index = NULL) {
      # Use robust selector generation without panel detection
      selector <- generate_robust_selector(grob, "lines", "polyline")
      
      return(list(selector))
    },

    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }

      # For smooth layers, get axis labels from the histogram layer in the same group
      # since lines() doesn't have xlab/ylab parameters
      group <- layer_info$group
      if (!is.null(group) && !is.null(group$high_call)) {
        hist_args <- group$high_call$args
        x_title <- if (!is.null(hist_args$xlab)) hist_args$xlab else ""
        y_title <- if (!is.null(hist_args$ylab)) hist_args$ylab else ""
        return(list(x = x_title, y = y_title))
      }

      # Fallback to current layer args (for standalone smooth plots)
      plot_call <- layer_info$plot_call
      args <- plot_call$args

      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""

      list(x = x_title, y = y_title)
    },

    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      main_title <- if (!is.null(args$main)) args$main else ""
      main_title
    }
  )
)

