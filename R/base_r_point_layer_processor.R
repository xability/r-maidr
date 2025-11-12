#' Base R Point/Scatter Plot Layer Processor
#'
#' Processes Base R scatter plot layers based on recorded plot calls
#'
#' @keywords internal
BaseRPointLayerProcessor <- R6::R6Class("BaseRPointLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, scale_mapping = NULL, grob_id = NULL, panel_id = NULL, panel_ctx = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "point",
        title = title,
        axes = axes
      )
    },
    needs_reordering = function() {
      FALSE
    },
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Get x and y values
      # For plot(): first arg is x, second is y
      # For points(): first arg is x, second is y
      x <- args[[1]]
      y <- args[[2]]

      # Get colors (optional)
      col <- args$col

      # Handle missing x or y
      if (is.null(x) || is.null(y)) {
        return(list())
      }

      # Ensure x and y are same length
      n <- min(length(x), length(y))

      # Convert to data points format (flat array like ggplot2)
      data_points <- list()

      for (i in seq_len(n)) {
        point <- list(
          x = as.numeric(x[i]),
          y = as.numeric(y[i])
        )

        # Add color if available
        if (!is.null(col)) {
          # Handle single color (repeat for all points)
          if (length(col) == 1) {
            point$color <- as.character(col)
          } else if (length(col) >= i) {
            point$color <- as.character(col[i])
          }
        }

        data_points[[i]] <- point
      }

      data_points
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Extract axis titles from plot call arguments
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

      # Extract main title from plot call arguments
      main_title <- if (!is.null(args$main)) args$main else ""
      main_title
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

      # Find the points grob container for THIS specific panel
      points_grob_name <- find_graphics_plot_grob(gt, "points", plot_index = group_index)

      if (!is.null(points_grob_name)) {
        # Generate selector in format: g#graphics-plot-N-points-1.1 > use
        # where N is the group_index (panel number)
        svg_id <- paste0(points_grob_name, ".1")
        escaped_id <- gsub("\\.", "\\\\.", svg_id)
        selector <- paste0("g#", escaped_id, " > use")
        return(list(selector))
      }

      # Fallback: pattern-based selector
      fallback_selector <- paste0("g#graphics-plot-", group_index, "-points-1\\.1 > use")
      list(fallback_selector)
    }
  )
)

