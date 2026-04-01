#' Point Layer Processor
#'
#' Processes scatter plot layers (geom_point) to extract point data and generate selectors
#' for individual points in the SVG structure.
#'
#' @keywords internal
Ggplot2PointLayerProcessor <- R6::R6Class(
  "Ggplot2PointLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' Process the point layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with data and selectors
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      extracted_data <- self$extract_data(plot, built, scale_mapping, panel_id)

      selectors <- self$generate_selectors(plot, gt, grob_id, panel_ctx)

      axes <- self$extract_axes_labels(plot, built, panel_id)

      # For point plots, data is directly the array of points
      data <- extracted_data

      list(
        data = data,
        selectors = selectors,
        axes = axes
      )
    },

    #' Extract axis information from the plot
    #'
    #' Returns per-axis objects with label and optional grid navigation fields
    #' (min, max, tickStep). Grid fields are only included when they can be
    #' successfully extracted from the built plot scales.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with x and y per-axis objects
    extract_axes_labels = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      # --- Extract labels ---
      x_label <- ""
      y_label <- ""

      if (!is.null(built$plot$labels$x)) {
        x_label <- built$plot$labels$x
      } else if (!is.null(plot$labels$x)) {
        x_label <- plot$labels$x
      } else {
        if (!is.null(plot$mapping$x)) {
          x_label <- rlang::as_label(plot$mapping$x)
        }
      }

      if (!is.null(built$plot$labels$y)) {
        y_label <- built$plot$labels$y
      } else if (!is.null(plot$labels$y)) {
        y_label <- plot$labels$y
      } else {
        if (!is.null(plot$mapping$y)) {
          y_label <- rlang::as_label(plot$mapping$y)
        }
      }

      # Build per-axis objects (always include label)
      x_axis <- list(label = x_label)
      y_axis <- list(label = y_label)

      # --- Optionally extract grid navigation fields (min, max, tickStep) ---
      x_grid <- self$extract_axis_grid_info(built, "x", panel_id)
      y_grid <- self$extract_axis_grid_info(built, "y", panel_id)

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

    #' Extract grid navigation info (min, max, tickStep) for a single axis
    #'
    #' Attempts to extract range and tick interval from the built plot's
    #' panel parameters. Returns NULL if any required value cannot be
    #' determined, allowing graceful fallback to non-grid scatter navigation.
    #'
    #' @param built Built plot data
    #' @param axis Character, either "x" or "y"
    #' @param panel_id Panel index for faceted plots (optional, defaults to 1)
    #' @return List with min, max, tickStep or NULL if extraction fails
    extract_axis_grid_info = function(built, axis = "x", panel_id = NULL) {
      tryCatch(
        {
          panel_idx <- if (!is.null(panel_id)) as.integer(panel_id) else 1L
          panel_params <- built$layout$panel_params[[panel_idx]]

          if (is.null(panel_params)) {
            return(NULL)
          }

          pp_axis <- panel_params[[axis]]
          if (is.null(pp_axis)) {
            return(NULL)
          }

          # Extract range from continuous_range
          axis_range <- pp_axis$continuous_range
          if (is.null(axis_range) || length(axis_range) < 2) {
            return(NULL)
          }

          axis_min <- axis_range[1]
          axis_max <- axis_range[2]

          # Extract breaks to compute tickStep
          axis_breaks <- pp_axis$breaks
          if (is.null(axis_breaks) || length(axis_breaks) < 2) {
            # Try alternative: get_breaks() from panel_scales
            scale_obj <- if (axis == "x") {
              built$layout$panel_scales_x[[panel_idx]]
            } else {
              built$layout$panel_scales_y[[panel_idx]]
            }
            if (!is.null(scale_obj)) {
              axis_breaks <- tryCatch(scale_obj$get_breaks(), error = function(e) NULL)
            }
          }

          if (is.null(axis_breaks) || length(axis_breaks) < 2) {
            return(NULL)
          }

          # Remove NAs from breaks
          axis_breaks <- axis_breaks[!is.na(axis_breaks)]
          if (length(axis_breaks) < 2) {
            return(NULL)
          }

          # Sort breaks and compute tickStep from first interval
          axis_breaks <- sort(axis_breaks)
          tick_step <- diff(axis_breaks)[1]

          # Validate: all values must be finite and sensible
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

    #' Extract data from point layer
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with points array and color information
    extract_data = function(plot, built = NULL, scale_mapping = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]

      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        layer_data <- layer_data[layer_data$PANEL == panel_id, ]
      }

      # For faceted plots, get x values from original data or scale mapping
      if (!is.null(panel_id)) {
        # For faceted plots, we need to get the actual x values from the original data
        if (!is.null(scale_mapping)) {
          layer_data$x <- self$apply_scale_mapping(layer_data$x, scale_mapping)
        } else {
          plot_mapping <- plot$mapping
          layer_mapping <- plot$layers[[layer_index]]$mapping

          x_col <- NULL
          if (!is.null(layer_mapping$x)) {
            x_col <- rlang::as_label(layer_mapping$x)
          } else if (!is.null(plot_mapping$x)) {
            x_col <- rlang::as_label(plot_mapping$x)
          }

          # For faceted plots, we need to get the x values for this specific panel
          if (!is.null(x_col) && x_col %in% names(plot$data)) {
            panel_data <- plot$data
            if ("PANEL" %in% names(panel_data)) {
              panel_data <- panel_data[panel_data$PANEL == panel_id, ]
            }
            x_values <- unique(panel_data[[x_col]])
            x_values <- sort(x_values)

            # Only map indices for discrete scales (where x values are integer indices 1, 2, 3, etc.)
            # For continuous scales, layer_data$x already contains the actual numeric values
            x_looks_like_indices <- all(layer_data$x == floor(layer_data$x)) &&
              min(layer_data$x) >= 1 &&
              max(layer_data$x) <= length(x_values) &&
              !is.numeric(plot$data[[x_col]])

            if (x_looks_like_indices) {
              layer_data$x <- x_values[layer_data$x]
            }
            # For continuous scales, keep layer_data$x as-is (already numeric values)
          } else {
            # Fallback: use layer_data$x but convert to character
            layer_data$x <- as.character(layer_data$x)
          }
        }
      } else {
        if (!is.null(scale_mapping)) {
          layer_data$x <- self$apply_scale_mapping(layer_data$x, scale_mapping)
        }
      }

      original_data <- plot$data

      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[layer_index]]$mapping

      # Determine x, y column names
      x_col <- if (!is.null(layer_mapping$x)) {
        rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot_mapping$x)) {
        rlang::as_label(plot_mapping$x)
      } else {
        names(original_data)[1]
      }

      y_col <- if (!is.null(layer_mapping$y)) {
        rlang::as_label(layer_mapping$y)
      } else if (!is.null(plot_mapping$y)) {
        rlang::as_label(plot_mapping$y)
      } else {
        names(original_data)[2]
      }

      # Determine color column name
      color_col <- if (!is.null(layer_mapping$colour)) {
        rlang::as_label(layer_mapping$colour)
      } else if (!is.null(layer_mapping$color)) {
        rlang::as_label(layer_mapping$color)
      } else if (!is.null(plot_mapping$colour)) {
        rlang::as_label(plot_mapping$colour)
      } else if (!is.null(plot_mapping$color)) {
        rlang::as_label(plot_mapping$color)
      } else {
        NULL
      }

      points <- list()
      for (i in seq_len(nrow(layer_data))) {
        point <- list(
          x = layer_data$x[i],
          y = layer_data$y[i]
        )

        if (!is.null(color_col) && color_col %in% names(layer_data)) {
          point$color <- as.character(layer_data[[color_col]][i])
        }

        points[[i]] <- point
      }

      # For point plots, return the points array directly
      points
    },

    #' Generate selectors for point elements
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      if (!is.null(panel_ctx) && !is.null(gt)) {
        pn <- panel_ctx$panel_name
        idx <- which(grepl(paste0("^", pn, "\\b"), gt$layout$name))
        if (length(idx) == 0) {
          return(list())
        }
        panel_grob <- gt$grobs[[idx[1]]]
        if (!inherits(panel_grob, "gTree")) {
          return(list())
        }

        # Look for geom_point container(s) within this panel
        point_names <- c()
        find_points <- function(grob) {
          if (!is.null(grob$name) && grepl("geom_point\\.points", grob$name)) {
            point_names <<- c(point_names, grob$name)
          }
          if (inherits(grob, "gList")) {
            for (i in seq_along(grob)) {
              find_points(grob[[i]])
            }
          }
          if (inherits(grob, "gTree")) {
            for (i in seq_along(grob$children)) {
              find_points(grob$children[[i]])
            }
          }
        }
        find_points(panel_grob)
        if (length(point_names) == 0) {
          return(list())
        }
        selectors <- lapply(point_names, function(nm) {
          svg_id <- paste0(nm, ".1")
          escaped <- gsub("\\.", "\\\\.", svg_id)
          paste0("g#", escaped, " > use")
        })
        return(selectors)
      }

      if (!is.null(grob_id)) {
        # For faceted plots: use provided grob ID with .1 suffix (gridSVG adds this)
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        return(list(paste0("g#", escaped_grob_id, " > use")))
      } else {
        # For single plots: use existing logic
        if (is.null(gt)) {
          gt <- ggplot2::ggplotGrob(plot)
        }

        panel_grob <- self$find_panel_grob(gt)
        if (is.null(panel_grob)) {
          return(list())
        }

        # Look for geom_point elements
        point_children <- self$find_children_by_type(panel_grob, "geom_point")
        if (length(point_children) == 0) {
          return(list())
        }

        # Use the first geom_point container
        master_container <- point_children[1]
        svg_id <- paste0(master_container, ".1")
        escaped_id <- gsub("\\.", "\\\\.", svg_id)
        css_selector <- paste0("g#", escaped_id, " > use")

        list(css_selector)
      }
    },

    #' Find the main panel grob
    #' @param gt The gtable to search
    #' @return The panel grob or NULL
    find_panel_grob = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        return(NULL)
      }

      panel_grob <- gt$grobs[[panel_index]]
      if (!inherits(panel_grob, "gTree")) {
        return(NULL)
      }

      panel_grob
    },

    #' Find children by type pattern
    #' @param grob The grob to search
    #' @param type_pattern Pattern to match
    #' @return List of matching children
    find_children_by_type = function(grob, type_pattern) {
      children <- list()

      if (inherits(grob, "gTree")) {
        for (i in seq_along(grob$children)) {
          child <- grob$children[[i]]
          if (!is.null(child$name) && grepl(type_pattern, child$name)) {
            children[[length(children) + 1]] <- child$name
          }
        }
      }

      children
    }
  )
)
