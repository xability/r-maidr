#' Base R Smooth/Density Layer Processor
#'
#' Processes Base R smooth curves including:
#' - Density plots: plot(density()) or lines(density())
#' - Loess smooth: lines(loess.smooth()) or lines(predict(loess))
#' - Smooth splines: lines(smooth.spline())
#'
#' @keywords internal
BaseRSmoothLayerProcessor <- R6::R6Class(
  "BaseRSmoothLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the layer: read its data, selectors, axis titles and main title from
    #'   the recorded call
    #' @param plot Unused; present for the processor interface
    #' @param layout Unused; present for the processor interface
    #' @param built Unused; present for the processor interface
    #' @param gt Gtable of the replayed drawing, searched for selectors (optional)
    #' @param grob_id Unused; present for the processor interface
    #' @param panel_id Unused; present for the processor interface
    #' @param panel_ctx Unused; present for the processor interface
    #' @param layer_info Layer information with the recorded call
    #' @return List describing the layer for the MAIDR payload
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
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
    #' @description One point per fitted value of the smooth, density or curve
    #' @param layer_info Layer information with the recorded call
    #' @return List of points
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Handle different smooth object types
      if (length(args) > 0) {
        first_arg <- args[[1]]

        x_values <- NULL
        y_values <- NULL

        # Case 1: density object (existing)
        if (inherits(first_arg, "density")) {
          x_values <- first_arg$x
          y_values <- first_arg$y
        } else if (inherits(first_arg, "smooth.spline")) {
          # Case 2: smooth.spline object
          x_values <- first_arg$x
          y_values <- first_arg$y
        } else if (inherits(first_arg, "loess")) {
          # Case 3: loess object (shouldn't happen directly, but handle it)
          x_values <- first_arg$x
          y_values <- fitted(first_arg)
        } else if (is.list(first_arg) && all(c("x", "y") %in% names(first_arg))) {
          # Case 4: list with x,y (loess.smooth result)
          x_values <- first_arg$x
          y_values <- first_arg$y
        } else if (is.numeric(first_arg) && length(args) >= 2 && is.numeric(args[[2]])) {
          # Case 5: Two numeric vectors (e.g., from predict(loess))
          x_values <- first_arg
          y_values <- args[[2]]
        } else {
          # Default: no data
          return(list())
        }

        if (!is.null(x_values) && !is.null(y_values)) {
          data_points <- lapply(seq_along(x_values), function(i) {
            list(x = x_values[i], y = y_values[i])
          })
          return(list(data_points))
        }
      }

      list()
    },
    #' @description The selector for the curve's polyline
    #' @param layer_info Layer information with the recorded call
    #' @param gt Gtable of the replayed drawing (optional)
    #' @return List of selectors
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
    #' @description Find the lines container grob for this layer
    #' @param grob The grob tree to search
    #' @param call_index Index of the recorded plot group, which numbers the panel's grobs
    #' @return Grob name, or NULL
    find_polyline_grobs = function(grob, call_index = NULL) {
      # Use robust utility function to find lines container
      # This doesn't rely on call_index matching the actual grob names
      find_graphics_plot_grob(grob, "lines")
    },
    #' @description Build this layer's selector from the grob tree
    #' @param grob The grob tree to search
    #' @param call_index Index of the recorded plot group, which numbers the panel's grobs
    #' @return A selector string, or an empty string when no grob matches
    generate_selectors_from_grob = function(grob, call_index = NULL) {
      # Scope to this plot group's grobs so multipanel layouts don't
      # match another panel's lines
      selector <- generate_robust_selector(
        grob, "lines", "polyline",
        plot_index = call_index
      )
      if (is.null(selector)) {
        # Fall back to unscoped search before giving up
        selector <- generate_robust_selector(grob, "lines", "polyline")
      }

      if (is.null(selector)) {
        # Never emit list(NULL): it serializes as [null] and breaks the
        # frontend's selector handling
        return(list())
      }

      list(selector)
    },
    #' @description Extract the axis titles for this layer
    #'
    #' The x axis holds whatever variable was smoothed, which the recorded
    #' arguments no longer name, so it carries no default. The y axis does
    #' when the curve came from `density()`: that estimate is a density, and
    #' plot.density() prints exactly that word.
    #'
    #' @param layer_info Layer information
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes())
      }

      args <- layer_info$plot_call$args
      is_density <- length(args) > 0 && inherits(args[[1]], "density")
      y_default <- if (is_density) "Density" else NULL

      # For smooth layers, get axis labels from the HIGH-level call (plot/hist) in the same group
      # since lines() doesn't have xlab/ylab parameters
      group <- layer_info$group
      if (!is.null(group) && !is.null(group$high_call)) {
        high_args <- group$high_call$args
        return(build_axes(
          x = recorded_axis_label(high_args, "xlab"),
          y = recorded_axis_label(high_args, "ylab", y_default)
        ))
      }

      # Fallback to current layer args (for standalone smooth plots)
      build_axes(
        x = recorded_axis_label(args, "xlab"),
        y = recorded_axis_label(args, "ylab", y_default)
      )
    },
    #' @description The main title of the recorded call, or an empty string
    #' @param layer_info Layer information with the recorded call
    #' @return Character string
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      main_title <- recorded_main_title(args)
      main_title
    }
  )
)
