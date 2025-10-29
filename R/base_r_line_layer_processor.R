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

      # Get x and y values
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
    find_lines_grobs = function(grob, group_index) {
      names <- character(0)

      # Check if current grob matches Base R lines pattern
      # Pattern: graphics-plot-{group_index}-lines-{index}
      grob_name <- grob$name
      if (!is.null(grob_name)) {
        pattern <- paste0("^graphics-plot-", group_index, "-lines-[0-9]+$")
        if (grepl(pattern, grob_name)) {
          names <- c(names, grob_name)
        }
      }

      # Recursively search children
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_lines_grobs(grob[[i]], group_index))
        }
      }

      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(names, self$find_lines_grobs(grob$children[[i]], group_index))
          }
        }
      }

      # Also check grobs field (like histogram processor)
      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_lines_grobs(grob$grobs[[i]], group_index))
        }
      }

      names
    },
    generate_selectors_from_grob = function(grob, group_index, layer_info) {
      # Find lines grobs recursively
      # Returns ALL matching grobs (for multiline support)
      lines_names <- self$find_lines_grobs(grob, group_index)

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

