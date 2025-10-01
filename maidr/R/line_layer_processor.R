#' Final Line Layer Processor - Uses Actual SVG Structure
#'
#' Processes line plot layers using the actual gridSVG structure discovered:
#' - Lines: GRID.polyline.61.1.1, GRID.polyline.61.1.2, GRID.polyline.61.1.3
#' - Points: geom_point.points.63.1.1 through geom_point.points.63.1.24 (grouped by series)
#'
#' @field layer_info Information about the layer being processed
#' @field last_result The last processing result
#'
#' @keywords internal
LineLayerProcessor <- R6::R6Class("LineLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' Process the line layer with actual SVG structure
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with data and selectors
    process = function(plot, layout, built = NULL, gt = NULL, scale_mapping = NULL, grob_id = NULL, panel_id = NULL) {
      # Extract data from the line layer
      data <- self$extract_data(plot, built, scale_mapping, panel_id)

      # Generate selectors for the line elements
      selectors <- self$generate_selectors(plot, gt, grob_id)

      list(
        data = data,
        selectors = selectors
      )
    },

    #' Extract data from line layer (single or multiline)
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List of arrays, each containing series data points
    extract_data = function(plot, built = NULL, scale_mapping = NULL, panel_id = NULL) {
      # Build the plot to get the processed data
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      # Get the layer data for this specific layer
      layer_data <- built$data[[self$layer_info$index]]

      # Filter data for specific panel if panel_id is provided
      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        layer_data <- layer_data[layer_data$PANEL == panel_id, ]
      }

      # Apply scale mapping if provided (for faceted plots)
      if (!is.null(scale_mapping)) {
        layer_data$x <- self$apply_scale_mapping(layer_data$x, scale_mapping)
      }

      # Check if we have multiple groups (more than just the default -1 group)
      if ("group" %in% names(layer_data)) {
        unique_groups <- unique(layer_data$group)
        # Only treat as multiline if we have more than one group and not just the default -1
        if (length(unique_groups) > 1 || (length(unique_groups) == 1 && unique_groups[1] != -1)) {
          # Multiline plot - group by series
          series_data <- self$extract_multiline_data(layer_data, plot)
          return(series_data)
        }
      }

      # Single line plot - maintain backward compatibility
      return(self$extract_single_line_data(layer_data))
    },

    #' Extract data for multiple line series
    #' @param layer_data The built layer data
    #' @param plot The original ggplot2 object
    #' @return List of arrays, each containing series data
    extract_multiline_data = function(layer_data, plot) {
      # Get the original data from the plot (following BarLayerProcessor pattern)
      original_data <- plot$data
      mapping_col <- self$get_group_column(plot)

      # Get unique groups from built data and unique categories from original data
      unique_groups <- sort(unique(layer_data$group))

      # Extract unique values from the mapping column in original data
      if (!is.null(original_data) && mapping_col %in% names(original_data)) {
        unique_categories <- sort(unique(original_data[[mapping_col]]))
      } else {
        # Fallback: use group numbers
        unique_categories <- paste0("Series ", unique_groups)
      }

      # Split built data by group
      series_groups <- split(layer_data, layer_data$group)

      # Extract data for each series
      series_data <- list()
      for (group_num in names(series_groups)) {
        series_points <- series_groups[[group_num]]

        # Map group number to category name (following BarLayerProcessor pattern)
        group_idx <- as.numeric(group_num)
        category_idx <- which(unique_groups == group_idx)
        series_name <- if (length(category_idx) > 0 && category_idx <= length(unique_categories)) {
          as.character(unique_categories[category_idx])
        } else {
          paste0("Series ", group_num)
        }

        points <- list()
        for (i in seq_len(nrow(series_points))) {
          point <- list(
            x = as.character(series_points$x[i]),
            y = series_points$y[i],
            fill = series_name
          )
          points[[i]] <- point
        }

        series_data[[length(series_data) + 1]] <- points
      }

      series_data
    },

    #' Extract data for single line (backward compatibility)
    #' @param layer_data The built layer data
    #' @return List containing single series data
    extract_single_line_data = function(layer_data) {
      points <- list()
      for (i in seq_len(nrow(layer_data))) {
        point <- list(
          x = as.character(layer_data$x[i]),
          y = layer_data$y[i]
        )
        points[[i]] <- point
      }

      list(points)
    },

    #' Get the grouping column name from plot mappings
    #' @param plot The ggplot2 object
    #' @return Name of the grouping column
    get_group_column = function(plot) {
      # Check layer mapping first
      layer_mapping <- plot$layers[[self$layer_info$index]]$mapping
      if (!is.null(layer_mapping)) {
        if (!is.null(layer_mapping$colour)) {
          return(rlang::as_name(layer_mapping$colour))
        }
        if (!is.null(layer_mapping$color)) {
          return(rlang::as_name(layer_mapping$color))
        }
      }

      # Check plot mapping
      plot_mapping <- plot$mapping
      if (!is.null(plot_mapping)) {
        if (!is.null(plot_mapping$colour)) {
          return(rlang::as_name(plot_mapping$colour))
        }
        if (!is.null(plot_mapping$color)) {
          return(rlang::as_name(plot_mapping$color))
        }
      }

      # Default to 'group' if no color mapping found
      "group"
    },

    #' Generate selectors using actual SVG structure
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @return List of selectors for each series
    generate_selectors = function(plot, gt = NULL, grob_id = NULL) {
      if (!is.null(grob_id)) {
        # For faceted plots: use provided grob ID with .1.1 suffix (gridSVG adds this)
        full_grob_id <- paste0(grob_id, ".1.1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        return(list(paste0("#", escaped_grob_id)))
      } else {
        # For single plots: use existing logic
        if (is.null(gt)) {
          gt <- ggplot2::ggplotGrob(plot)
        }

        # Find the main polyline grob (GRID.polyline.61)
        main_polyline_grob <- self$find_main_polyline_grob(gt)

        if (is.null(main_polyline_grob)) {
          return(list())
        }

        # Extract the base ID from the grob name (e.g., "61" from "GRID.polyline.61")
        grob_name <- main_polyline_grob$name
        base_id <- gsub("^GRID\\.polyline\\.", "", grob_name)

        # Check if this is multiline by examining the built data
        built <- ggplot2::ggplot_build(plot)
        layer_data <- built$data[[self$layer_info$index]]

        if ("group" %in% names(layer_data)) {
          # Multiline plot - use the actual structure: GRID.polyline.61.1.1, .2, .3
          num_series <- length(unique(layer_data$group))
          return(self$generate_multiline_selectors(base_id, num_series))
        } else {
          # Single line plot
          return(self$generate_single_line_selector(base_id))
        }
      }
    },

    #' Generate selectors for multiline plots using actual structure
    #' @param base_id The base ID from the grob (e.g., "61")
    #' @param num_series Number of series
    #' @return List of selectors
    generate_multiline_selectors = function(base_id, num_series) {
      selectors <- list()

      # Use the actual structure discovered: GRID.polyline.{base_id}.1.{series_index}
      for (i in 1:num_series) {
        # Create selector targeting the specific polyline element
        # Format: #GRID\.polyline\.{base_id}\.1\.{series_index}
        escaped_id <- gsub("\\.", "\\\\.", paste0("GRID.polyline.", base_id, ".1.", i))
        selector <- paste0("#", escaped_id)
        selectors[[i]] <- selector
      }

      selectors
    },

    #' Generate selector for single line plot
    #' @param base_id The base ID from the grob
    #' @return List with single selector
    generate_single_line_selector = function(base_id) {
      escaped_id <- gsub("\\.", "\\\\.", paste0("GRID.polyline.", base_id, ".1.1"))
      selector <- paste0("#", escaped_id)
      list(selector)
    },

    #' Find the main polyline grob (GRID.polyline.XX)
    #' @param gt The gtable to search
    #' @return The main polyline grob or NULL
    find_main_polyline_grob = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        return(NULL)
      }

      panel_grob <- gt$grobs[[panel_index]]

      if (!inherits(panel_grob, "gTree")) {
        return(NULL)
      }

      # Search for the main GRID.polyline grob
      find_main_polyline_recursive <- function(grob) {
        if (!is.null(grob$name) && grepl("^GRID\\.polyline\\.\\d+$", grob$name)) {
          return(grob)
        }

        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            result <- find_main_polyline_recursive(grob[[i]])
            if (!is.null(result)) {
              return(result)
            }
          }
        }

        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            result <- find_main_polyline_recursive(grob$children[[i]])
            if (!is.null(result)) {
              return(result)
            }
          }
        }

        NULL
      }

      find_main_polyline_recursive(panel_grob)
    },

    #' Check if layer needs reordering
    #' @return FALSE (line plots typically don't need reordering)
    needs_reordering = function() {
      FALSE
    }
  ),
  private = list(
    last_result = NULL
  )
)
