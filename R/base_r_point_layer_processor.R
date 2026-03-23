#' Base R Point/Scatter Plot Layer Processor
#'
#' Processes Base R scatter plot layers based on recorded plot calls
#'
#' @keywords internal
BaseRPointLayerProcessor <- R6::R6Class(
  "BaseRPointLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
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

      # For plot(): first arg is x, second is y
      # For points(): first arg is x, second is y
      x <- args[[1]]
      y <- args[[2]]

      col <- args$col

      if (is.null(x) || is.null(y)) {
        return(list())
      }

      # Ensure x and y are same length
      n <- min(length(x), length(y))

      data_points <- list()

      for (i in seq_len(n)) {
        point <- list(
          x = as.numeric(x[i]),
          y = as.numeric(y[i])
        )

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
    #' Extract axis information from Base R plot call
    #'
    #' Returns per-axis objects with label and optional grid navigation fields
    #' (min, max, tickStep). Grid fields are derived from xlim/ylim args or
    #' data range, and tick intervals via pretty(). Only included when
    #' extraction succeeds.
    #'
    #' @param layer_info Layer information with recorded plot call
    #' @return List with x and y per-axis objects
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(
          x = list(label = ""),
          y = list(label = "")
        ))
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""

      # Build per-axis objects (always include label)
      x_axis <- list(label = x_title)
      y_axis <- list(label = y_title)

      # --- Optionally extract grid navigation fields ---
      x_data <- args[[1]]
      y_data <- args[[2]]

      x_grid <- self$extract_base_r_axis_grid_info(x_data, args$xlim)
      y_grid <- self$extract_base_r_axis_grid_info(y_data, args$ylim)

      if (!is.null(x_grid)) {
        x_axis$min <- x_grid$min
        x_axis$max <- x_grid$max
        x_axis$tickStep <- x_grid$tickStep
      }

      if (!is.null(y_grid)) {
        y_axis$min <- y_grid$min
        y_axis$max <- y_grid$max
        y_axis$tickStep <- y_grid$tickStep
      }

      list(x = x_axis, y = y_axis)
    },

    #' Extract grid navigation info for a Base R axis
    #'
    #' Computes min, max from xlim/ylim or data range, and tickStep from
    #' pretty() tick positions. Returns NULL if extraction fails.
    #'
    #' @param data Numeric vector of data values
    #' @param lim Optional axis limits (xlim or ylim)
    #' @return List with min, max, tickStep or NULL
    extract_base_r_axis_grid_info = function(data, lim = NULL) {
      tryCatch(
        {
          if (is.null(data) || !is.numeric(data) || length(data) < 1) {
            return(NULL)
          }

          # Determine range: use explicit limits if provided, otherwise pretty range
          if (!is.null(lim) && length(lim) == 2 && all(is.finite(lim))) {
            axis_min <- lim[1]
            axis_max <- lim[2]
          } else {
            # Use pretty() to get the axis range Base R would use
            pretty_vals <- pretty(range(data, na.rm = TRUE))
            axis_min <- min(pretty_vals)
            axis_max <- max(pretty_vals)
          }

          # Compute tick positions using pretty()
          tick_vals <- pretty(c(axis_min, axis_max))
          tick_vals <- tick_vals[!is.na(tick_vals)]

          if (length(tick_vals) < 2) {
            return(NULL)
          }

          tick_step <- diff(tick_vals)[1]

          # Validate
          if (!is.finite(axis_min) || !is.finite(axis_max) || !is.finite(tick_step)) {
            return(NULL)
          }
          if (axis_min >= axis_max) {
            return(NULL)
          }
          if (tick_step <= 0 || tick_step > (axis_max - axis_min)) {
            return(NULL)
          }

          list(min = axis_min, max = axis_max, tickStep = tick_step)
        },
        error = function(e) {
          NULL
        }
      )
    },
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

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

      points_grob_name <- find_graphics_plot_grob(gt, "points", plot_index = group_index)

      if (!is.null(points_grob_name)) {
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
