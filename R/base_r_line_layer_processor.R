#' Base R Line Plot Layer Processor
#'
#' Processes Base R line plot layers based on recorded plot calls
#'
#' @keywords internal
BaseRLineLayerProcessor <- R6::R6Class("BaseRLineLayerProcessor",
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
        type = "line",
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
      function_name <- layer_info$function_name

      # Handle abline() calls for regression lines
      if (function_name == "abline") {
        return(self$extract_abline_data(layer_info))
      }

      # Get x and y values for lines() calls
      x <- args[[1]]
      y <- args[[2]]

      # Check if this is a multiline plot (matplot with matrix)
      is_multiline <- is.matrix(y) || (is.array(y) && length(dim(y)) == 2)

      if (is_multiline) {
        return(self$extract_multiline_data(x, y))
      } else {
        return(self$extract_single_line_data(x, y))
      }
    },
    extract_single_line_data = function(x, y) {
      # Convert to data points
      data_points <- list()

      # Ensure x and y are same length
      n <- min(length(x), length(y))

      for (i in 1:n) {
        data_points[[i]] <- list(
          x = as.character(x[i]),
          y = as.numeric(y[i])
        )
      }

      # Return as nested list (one series)
      list(data_points)
    },
    extract_multiline_data = function(x, y_matrix) {
      # Extract column names for series names
      series_names <- colnames(y_matrix)
      if (is.null(series_names)) {
        series_names <- paste0("Col", 1:ncol(y_matrix))
      }

      # Each column is a series
      series_list <- list()

      for (col_idx in 1:ncol(y_matrix)) {
        series_y <- y_matrix[, col_idx]
        series_name <- series_names[col_idx]

        series_points <- list()

        # Ensure x and y are same length
        n <- min(length(x), length(series_y))

        for (i in 1:n) {
          series_points[[i]] <- list(
            x = as.character(x[i]),
            y = as.numeric(series_y[i]),
            fill = as.character(series_name)
          )
        }

        series_list[[col_idx]] <- series_points
      }

      series_list
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }

      function_name <- layer_info$function_name

      # For abline() calls, get axis labels from the HIGH call (plot(x, y))
      # since abline() doesn't have xlab/ylab parameters
      if (function_name == "abline") {
        group <- layer_info$group
        if (!is.null(group) && !is.null(group$high_call)) {
          high_args <- group$high_call$args
          x_title <- if (!is.null(high_args$xlab)) high_args$xlab else ""
          y_title <- if (!is.null(high_args$ylab)) high_args$ylab else ""
          return(list(x = x_title, y = y_title))
        }
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Extract axis titles from plot call arguments
      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""

      list(x = x_title, y = y_title)
    },
    extract_abline_data = function(layer_info) {
      plot_call <- layer_info$plot_call
      args <- plot_call$args
      group <- layer_info$group

      # Get intercept and slope
      intercept <- NULL
      slope <- NULL

      # Check if first argument is an lm object
      first_arg <- args[[1]]
      if (!is.null(first_arg) && inherits(first_arg, "lm")) {
        # Extract coefficients from lm object
        coefs <- coef(first_arg)
        intercept <- coefs[1]
        if (length(coefs) > 1) {
          slope <- coefs[2]
        } else {
          slope <- 0
        }
      } else {
        # Check for named arguments: abline(a=..., b=...)
        if (!is.null(args$a)) {
          intercept <- args$a
        } else if (length(args) > 0 && is.numeric(args[[1]])) {
          intercept <- args[[1]]
        }

        if (!is.null(args$b)) {
          slope <- args$b
        } else if (length(args) > 1 && is.numeric(args[[2]])) {
          slope <- args[[2]]
        } else {
          slope <- 0
        }
      }

      # Handle horizontal and vertical lines
      if (!is.null(args$h)) {
        # Horizontal line: y = constant
        y_val <- args$h
        # Get x range from HIGH call (plot(x, y))
        x_range <- self$get_x_range_from_group(group)
        if (is.null(x_range)) {
          return(list())
        }
        data_points <- list(
          list(x = x_range[1], y = y_val),
          list(x = x_range[2], y = y_val)
        )
        return(list(data_points))
      }

      if (!is.null(args$v)) {
        # Vertical line: x = constant
        x_val <- args$v
        # Get y range from HIGH call (plot(x, y))
        y_range <- self$get_y_range_from_group(group)
        if (is.null(y_range)) {
          return(list())
        }
        data_points <- list(
          list(x = x_val, y = y_range[1]),
          list(x = x_val, y = y_range[2])
        )
        return(list(data_points))
      }

      # For regression lines: use actual endpoints (like SVG has only 2 points)
      if (is.null(intercept) || is.null(slope)) {
        return(list())
      }

      # Get x range from HIGH call (plot(x, y))
      x_range <- self$get_x_range_from_group(group)
      if (is.null(x_range)) {
        return(list())
      }

      # Use the actual endpoints that R renders (same as what's in the SVG)
      # abline() renders only 2 points: the endpoints of the line
      y_min <- intercept + slope * x_range[1]
      y_max <- intercept + slope * x_range[2]

      # Return only the 2 endpoints (like the SVG polyline has)
      data_points <- list(
        list(x = x_range[1], y = y_min),
        list(x = x_range[2], y = y_max)
      )

      list(data_points)
    },

    get_x_range_from_group = function(group) {
      if (is.null(group) || is.null(group$high_call)) {
        return(NULL)
      }

      high_args <- group$high_call$args
      x_data <- high_args[[1]]

      if (is.null(x_data) || !is.numeric(x_data)) {
        return(NULL)
      }

      # Get range with some padding
      x_min <- min(x_data, na.rm = TRUE)
      x_max <- max(x_data, na.rm = TRUE)
      x_padding <- (x_max - x_min) * 0.05
      c(x_min - x_padding, x_max + x_padding)
    },

    get_y_range_from_group = function(group) {
      if (is.null(group) || is.null(group$high_call)) {
        return(NULL)
      }

      high_args <- group$high_call$args
      y_data <- high_args[[2]]

      if (is.null(y_data) || !is.numeric(y_data)) {
        return(NULL)
      }

      # Get range with some padding
      y_min <- min(y_data, na.rm = TRUE)
      y_max <- max(y_data, na.rm = TRUE)
      y_padding <- (y_max - y_min) * 0.05
      c(y_min - y_padding, y_max + y_padding)
    },

    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      function_name <- layer_info$function_name

      # For abline() calls, get title from the HIGH call (plot(x, y))
      # since abline() doesn't have main parameter
      if (function_name == "abline") {
        group <- layer_info$group
        if (!is.null(group) && !is.null(group$high_call)) {
          high_args <- group$high_call$args
          main_title <- if (!is.null(high_args$main)) high_args$main else ""
          return(main_title)
        }
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Extract main title from plot call arguments
      main_title <- if (!is.null(args$main)) args$main else ""
      main_title
    },
    generate_selectors = function(layer_info, gt = NULL) {
      selectors <- list()

      # Get group index for selector generation
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      # Search for polyline grobs in the grob tree
      if (!is.null(gt)) {
        selectors <- self$generate_selectors_from_grob(gt, group_index, layer_info)
      }

      selectors
    },
    find_lines_grobs = function(grob, group_index, grob_type = "lines") {
      names <- character(0)

      # Check if current grob matches Base R lines/abline pattern
      grob_name <- grob$name
      if (!is.null(grob_name)) {
        if (grob_type == "abline") {
          # Pattern for abline: graphics-plot-{group_index}-abline-*
          pattern <- paste0("^graphics-plot-", group_index, "-abline-")
        } else {
          # Pattern for lines: graphics-plot-{group_index}-lines-{index}
          pattern <- paste0("^graphics-plot-", group_index, "-lines-[0-9]+$")
        }
        if (grepl(pattern, grob_name)) {
          names <- c(names, grob_name)
        }
      }

            # Recursively search children
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_lines_grobs(grob[[i]], group_index, grob_type))
        }
      }

      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(names, self$find_lines_grobs(grob$children[[i]], group_index, grob_type))                                                                           
          }
        }
      }

      # Also check grobs field (like histogram processor)
      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_lines_grobs(grob$grobs[[i]], group_index, grob_type))
        }
      }

      names
    },
    generate_selectors_from_grob = function(grob, group_index, layer_info) {
      # Determine grob type based on function name
      function_name <- if (!is.null(layer_info)) layer_info$function_name else "lines"
      grob_type <- if (function_name == "abline") "abline" else "lines"

      # Find lines/abline grobs recursively
      # Returns ALL matching grobs (for multiline support)
      lines_names <- self$find_lines_grobs(grob, group_index, grob_type)

      if (length(lines_names) == 0) {
        return(list())
      }

      # Sort by series index (from grob name: graphics-plot-1-lines-1, lines-2, lines-3)
      # Extract the numeric suffix from grob names
      lines_names <- sort(lines_names)

      # Generate selectors from grob names
      # Each grob becomes one selector
      selectors <- lapply(lines_names, function(name) {
        # Add .1 suffix (gridSVG convention for SVG IDs)
        svg_id <- paste0(name, ".1")
        # Escape dots for CSS selector syntax
        escaped <- gsub("\\.", "\\\\.", svg_id)
        # Create selector targeting polyline within this container
        selector <- paste0("#", escaped, " polyline")
        selector
      })

      selectors
    }
  )
)

