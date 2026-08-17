#' Base R Line Plot Layer Processor
#'
#' @description
#' Processes Base R line plot layers based on recorded plot calls
#'
#' @keywords internal
BaseRLineLayerProcessor <- R6::R6Class(
  "BaseRLineLayerProcessor",
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

      # curve()'s own arguments hold no coordinates -- the first one is an
      # unevaluated expression -- so the wrapper stores the x/y curve()
      # returned after drawing them. See curve_recorded_values().
      curve_data <- args$.maidr_curve_data
      if (!is.null(curve_data)) {
        return(self$extract_single_line_data(
          curve_data$x,
          curve_data$y,
          self$get_axis_labels(layer_info, axis_side = 1)
        ))
      }

      # Resolve x/y the way plot()/lines() do: named args win, then the
      # first two UNNAMED arguments. Positional args[[2]] would grab
      # graphical parameters instead (plot(x, type = "l") -> y = "l") and
      # crash for single-argument calls like lines(v).
      xy <- resolve_xy_args(args)
      x <- xy$x
      y <- xy$y

      if (is.null(x) || is.language(x) || is.language(y)) {
        # Formula interface / NSE-recorded expressions carry no plottable
        # values here; emit no points rather than garbage.
        return(list())
      }

      is_multiline <- is.matrix(y) || (is.array(y) && length(dim(y)) == 2)

      # matplot()/matlines()/matpoints() draw one series per COLUMN against
      # the row index, so a lone matrix argument is a set of series, not an
      # xy.coords pair. Letting xy.coords() interpret it would read a
      # two-column matrix as x = column 1, y = column 2 -- discarding every
      # series but one and announcing series 1's values as x coordinates.
      # plot()/lines() keep the xy.coords reading, which is correct there.
      matrix_series_call <- function_name %in%
        c("matplot", "matlines", "matpoints")

      if (
        is.null(y) &&
          matrix_series_call &&
          (is.matrix(x) || (is.array(x) && length(dim(x)) == 2))
      ) {
        y <- x
        x <- seq_len(nrow(y))
        is_multiline <- TRUE
      }

      if (is.null(y) && !is_multiline) {
        # Single-vector call (plot(v, type = "l"), lines(v)):
        # x becomes the index and the vector supplies the y values.
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

      # Check for custom axis labels from axis() calls
      x_labels <- self$get_axis_labels(layer_info, axis_side = 1)

      if (is_multiline) {
        self$extract_multiline_data(x, y, x_labels)
      } else {
        self$extract_single_line_data(x, y, x_labels)
      }
    },
    #' @description Get custom axis labels from axis() LOW-level calls
    #' @param layer_info Layer information containing group data
    #' @param axis_side Which axis (1=bottom/x, 2=left/y, 3=top, 4=right)
    #' @return Character vector of labels or NULL if not found
    get_axis_labels = function(layer_info, axis_side = 1) {
      if (is.null(layer_info$group)) {
        return(NULL)
      }

      low_calls <- layer_info$group$low_calls
      if (is.null(low_calls) || length(low_calls) == 0) {
        return(NULL)
      }

      # Search for axis() call with matching side and labels
      for (call in low_calls) {
        if (call$function_name == "axis") {
          call_args <- call$args
          # First argument is the side (1=bottom, 2=left, etc.)
          side <- call_args[[1]]
          if (!is.null(side) && side == axis_side && !is.null(call_args$labels)) {
            return(as.character(call_args$labels))
          }
        }
      }

      NULL
    },
    extract_single_line_data = function(x, y, x_labels = NULL) {
      data_points <- list()

      # Ensure x and y are same length
      n <- min(length(x), length(y))

      # Use custom axis labels if available, otherwise use x values
      use_labels <- !is.null(x_labels) && length(x_labels) >= n

      for (i in 1:n) {
        x_value <- if (use_labels) x_labels[i] else as.character(x[i])
        data_points[[i]] <- list(
          x = x_value,
          y = as.numeric(y[i])
        )
      }

      list(data_points)
    },
    extract_multiline_data = function(x, y_matrix, x_labels = NULL) {
      series_names <- colnames(y_matrix)
      if (is.null(series_names)) {
        series_names <- paste0("Col", seq_len(ncol(y_matrix)))
      }

      # Each column is a series
      series_list <- list()

      for (col_idx in seq_len(ncol(y_matrix))) {
        series_y <- y_matrix[, col_idx]
        series_name <- series_names[col_idx]

        series_points <- list()

        # Ensure x and y are same length
        n <- min(length(x), length(series_y))

        # Use custom axis labels if available, otherwise use x values
        use_labels <- !is.null(x_labels) && length(x_labels) >= n

        for (i in 1:n) {
          x_value <- if (use_labels) x_labels[i] else as.character(x[i])
          series_points[[i]] <- list(
            x = x_value,
            y = as.numeric(series_y[i]),
            z = as.character(series_name)
          )
        }

        series_list[[col_idx]] <- series_points
      }

      series_list
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes())
      }

      function_name <- layer_info$function_name

      # For LOW-level calls (abline, lines, etc.), get axis labels from the HIGH call (plot(x, y))
      # since LOW-level functions don't have xlab/ylab parameters
      if (function_name %in% c("abline", "lines", "points")) {
        group <- layer_info$group
        if (!is.null(group) && !is.null(group$high_call)) {
          high_args <- group$high_call$args
          return(build_axes(
            x = recorded_axis_label(high_args, "xlab"),
            y = recorded_axis_label(high_args, "ylab")
          ))
        }
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # curve() derives its labels internally (x name, deparsed
      # expression) rather than taking them from the call, so they are
      # recorded alongside the drawn points. An explicit xlab/ylab still
      # wins, exactly as it does inside curve().
      #
      # Nothing else here carries a default: a line drawn by plot() or
      # matplot() runs over whatever the caller measured, and the recorded
      # arguments are evaluated values that no longer name it. The renderer's
      # generic is the honest answer, so no label is emitted.
      curve_labels <- args$.maidr_curve_data$labels

      build_axes(
        x = recorded_axis_label(args, "xlab", curve_labels$x),
        y = recorded_axis_label(args, "ylab", curve_labels$y)
      )
    },
    extract_abline_data = function(layer_info) {
      plot_call <- layer_info$plot_call
      args <- plot_call$args
      group <- layer_info$group

      intercept <- NULL
      slope <- NULL

      first_arg <- args[[1]]
      if (!is.null(first_arg) && inherits(first_arg, "lm")) {
        coefs <- coef(first_arg)
        intercept <- coefs[1]
        if (length(coefs) > 1) {
          slope <- coefs[2]
        } else {
          slope <- 0
        }
      } else {
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

      x_range <- self$get_x_range_from_group(group)
      if (is.null(x_range)) {
        return(list())
      }

      # Use the actual endpoints that R renders (same as what's in the SVG)
      # abline() renders only 2 points: the endpoints of the line
      y_min <- intercept + slope * x_range[1]
      y_max <- intercept + slope * x_range[2]

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

      main_title <- if (!is.null(args$main)) args$main else ""
      main_title
    },
    generate_selectors = function(layer_info, gt = NULL) {
      selectors <- list()

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

      grob_name <- grob$name
      if (!is.null(grob_name)) {
        if (grob_type == "abline") {
          # Pattern for abline: graphics-plot-{group_index}-abline-*
          pattern <- paste0("^graphics-plot-", group_index, "-abline-")
        } else if (grob_type == "step") {
          # gridGraphics names a stairstep grob after the `type` letter that
          # drew it -- `-step-` for type = "s", `-Step-` for type = "S" --
          # never `-lines-`. A step layer searching for the line name finds
          # nothing, and a layer that emits zero selectors is dropped by the
          # frontend's `selectors.length === series count` precondition,
          # which kills highlighting for the whole layer.
          pattern <- paste0("^graphics-plot-", group_index, "-[sS]tep-[0-9]+$")
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
    # Which family of grob names this layer's selectors are drawn from:
    # "abline", "lines" or "step". Overridden by subclasses whose geometry
    # lands under a different grob name (see BaseRStepLayerProcessor).
    selector_grob_type = function(layer_info) {
      function_name <- if (!is.null(layer_info)) layer_info$function_name else "lines"
      if (function_name == "abline") "abline" else "lines"
    },
    generate_selectors_from_grob = function(grob, group_index, layer_info) {
      grob_type <- self$selector_grob_type(layer_info)

      # Returns ALL matching grobs (for multiline support)
      lines_names <- self$find_lines_grobs(grob, group_index, grob_type)

      if (length(lines_names) == 0) {
        return(list())
      }

      # Sort by the trailing grob number: lexicographic sort would place
      # "...-lines-10" before "...-lines-2", mapping series 10+ to the
      # wrong polylines.
      grob_numbers <- suppressWarnings(
        as.integer(sub(".*-([0-9]+)$", "\\1", lines_names))
      )
      lines_names <- lines_names[order(grob_numbers)]

      # Each grob becomes one selector
      selectors <- lapply(lines_names, function(name) {
        svg_id <- paste0(name, ".1")
        # Escape dots for CSS selector syntax
        escaped <- gsub("\\.", "\\\\.", svg_id)
        selector <- paste0("#", escaped, " polyline")
        selector
      })

      selectors
    }
  )
)
