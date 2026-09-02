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

      # For plot()/points(): named x/y win, then unnamed positionals
      xy <- self$resolve_coordinates(plot_call)
      x <- xy$x
      y <- xy$y

      col <- args[["col"]]

      if (is.null(x) || is.language(x) || is.language(y)) {
        return(list())
      }

      if (is.null(y)) {
        # Single-vector call plot(v): index on x, values on y
        coords <- tryCatch(
          grDevices::xy.coords(x, NULL),
          error = function(e) NULL
        )
        if (is.null(coords)) {
          return(list())
        }
        x <- coords$x
        y <- coords$y
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
    # The x and y a recorded call plots, resolved as plot() resolves them.
    #
    # `plot(y ~ x, data = d)` carries a formula rather than two vectors, and
    # its coordinates are the two columns of the model frame the recording
    # kept (#254). Read from `resolve_xy_args()` alone, the formula is a
    # language object and the layer came out with no points at all -- an
    # interactive chart with nothing in it.
    #
    # @param plot_call The recorded call
    # @return A list with `x` and `y`, either of which may be NULL
    resolve_coordinates = function(plot_call) {
      frame <- self$formula_variables(plot_call)
      if (!is.null(frame)) {
        return(list(x = frame$x, y = frame$y))
      }
      resolve_xy_args(plot_call$args)
    },
    # The two numeric variables of a recorded formula call, or NULL.
    #
    # Only a numeric pair is a scatter: `plot(y ~ f)` on a factor draws a
    # box plot through `plot.factor()`, and a frame with more than one
    # predictor draws something else again. Both are left as they were.
    #
    # @param plot_call The recorded call
    # @return A list with `x`, `y`, `x_name`, `y_name`, or NULL
    formula_variables = function(plot_call) {
      args <- plot_call$args
      handed <- resolve_xy_args(args)$x
      if (!inherits(handed, "formula")) {
        return(NULL)
      }
      frame <- plot_call$formula_frame
      if (!is.data.frame(frame) || ncol(frame) != 2) {
        return(NULL)
      }
      response <- attr(attr(frame, "terms"), "response")
      if (!is.numeric(response) || !response %in% c(1L, 2L)) {
        return(NULL)
      }
      predictor <- setdiff(1:2, response)
      x <- frame[[predictor]]
      y <- frame[[response]]
      if (!is.numeric(x) || !is.numeric(y)) {
        return(NULL)
      }
      list(
        x = x,
        y = y,
        x_name = names(frame)[predictor],
        y_name = names(frame)[response]
      )
    },
    # Extract axis information from Base R plot call
    #
    # Returns per-axis objects with an optional label and optional grid
    # navigation fields (min, max, tickStep). Grid fields are derived from
    # xlim/ylim args or data range, and tick intervals via pretty(). Every
    # field is included only when extraction succeeds, and an axis that ends
    # up with none of them is left out of the payload entirely.
    #
    # @param layer_info Layer information with recorded plot call
    # @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # No default title: a scatter plot's axes hold whatever the caller
      # measured, and the call carries no name for it. plot() prints the
      # deparsed arguments, but those are lost once the wrapper records
      # evaluated values -- and reconstructing them would misname every
      # single-argument form, which plot() labels "Index" against the data,
      # or by the column names of a matrix or data frame. A guessed noun is
      # worse than none, so the axis is left for the renderer's generic.
      x_axis <- build_axis_config(label = recorded_axis_label(args, "xlab"))
      y_axis <- build_axis_config(label = recorded_axis_label(args, "ylab"))

      # `plot(y ~ x, data = d)` labels its axes with the two variable names,
      # which the recorded frame still carries.
      frame <- self$formula_variables(plot_call)
      if (!is.null(frame)) {
        if (is.null(x_axis$label)) {
          x_axis <- build_axis_config(label = frame$x_name)
        }
        if (is.null(y_axis$label)) {
          y_axis <- build_axis_config(label = frame$y_name)
        }
      }

      # --- Optionally extract grid navigation fields ---
      xy <- self$resolve_coordinates(plot_call)
      x_data <- xy$x
      y_data <- xy$y
      # Let R resolve the coordinates, the way extract_data() already does.
      # Re-deriving the single-argument fallback by hand got plot(matrix)
      # wrong: it read all 10 cells of a 5x2 matrix as y and indexed x over
      # 1:10, so the announced grid was twice as wide as the drawn one (#98).
      # xy.coords() is the resolution plot() itself uses, and it covers
      # matrices, data frames, ts and list inputs in the same step.
      # Warnings are muffled because this is our own probe, not the user's
      # call: categorical coordinates make xy.coords() report "NAs introduced
      # by coercion", and the drawn plot has already had its say.
      # Both aesthetics are tested, matching extract_data()'s guard above: an
      # unevaluated argument is not a coordinate, and xy.coords() would try
      # to coerce it. Raised in review of the PR for #98.
      if (!is.language(x_data) && !is.language(y_data)) {
        coords <- suppressWarnings(tryCatch(
          grDevices::xy.coords(x_data, y_data),
          error = function(e) NULL
        ))
        if (usable_xy_coords(coords)) {
          x_data <- coords$x
          y_data <- coords$y
        }
      }

      x_grid <- self$extract_base_r_axis_grid_info(x_data, args[["xlim"]])
      y_grid <- self$extract_base_r_axis_grid_info(y_data, args[["ylim"]])

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

      build_axes(x = x_axis, y = y_axis)
    },

    # Extract grid navigation info for a Base R axis
    #
    # Computes min, max from xlim/ylim or data range, and tickStep from
    # pretty() tick positions. Returns NULL if extraction fails.
    #
    # @param data Numeric vector of data values
    # @param lim Optional axis limits (xlim or ylim)
    # @return List with min, max, tickStep or NULL
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

      main_title <- recorded_main_title(args)
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
