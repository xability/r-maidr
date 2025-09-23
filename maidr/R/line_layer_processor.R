#' Line Layer Processor
#'
#' Processes line plot layers (geom_line) to extract data and generate selectors.
#'
#' @field layer_info Information about the layer being processed
#' @field reordered_plot The plot after reordering (if needed)
#' @field last_result The last processing result
#'
#' @export
LineLayerProcessor <- R6::R6Class("LineLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' Process the line layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param gt Gtable object (optional)
    #' @return List with data and selectors
    process = function(plot, layout, built = NULL, gt = NULL) {
      # Extract data from the line layer
      data <- self$extract_data_impl(plot, built)

      # Generate selectors for the line elements
      selectors <- self$generate_selectors(plot, gt)

      # Return the result (orchestrator will handle setting last_result)
      result <- list(
        type = "line",
        data = data,
        selectors = selectors
      )

      result
    },

    #' Extract data from line layer
    #' @param plot The ggplot2 object
    #' @return List of data points
    extract_data_impl = function(plot, built = NULL) {
      # Build the plot to get the processed data
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      # Get the layer data for this specific layer
      layer_data <- built$data[[self$layer_info$index]]

      # Extract x and y coordinates
      x_col <- "x"
      y_col <- "y"

      # Check if x and y columns exist
      if (!x_col %in% names(layer_data) || !y_col %in% names(layer_data)) {
        stop("Could not find x and y columns in line layer data")
      }

      # Create data points list
      data_points <- list()

      for (i in seq_len(nrow(layer_data))) {
        point <- list(
          x = layer_data[[x_col]][i],
          y = layer_data[[y_col]][i]
        )

        data_points[[i]] <- point
      }

      # Wrap in array to match Python maidr format: [[{x,y}, {x,y}, ...]]
      list(data_points)
    },

    #' Generate selectors for line elements
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @return List of selectors
    generate_selectors = function(plot, gt) {
      if (is.null(gt)) {
        # If no gtable provided, try to get it from the plot
        gt <- ggplot2::ggplotGrob(plot)
      }

      # Find polyline elements (lines)
      polylines <- self$find_polyline_grobs(gt)

      # Only return the main data line (GRID.polyline), not grid lines
      data_polylines <- list()
      for (polyline in polylines) {
        if (grepl("^GRID\\.polyline", polyline$name)) {
          data_polylines <- c(data_polylines, list(polyline))
        }
      }

      # Return only the first data polyline (should be only one)
      if (length(data_polylines) > 0) {
        polyline <- data_polylines[[1]]
        grob_name <- polyline$name

        # Extract the numeric part from grob name
        # (e.g., "155" from "GRID.polyline.155")
        layer_id <- gsub("GRID\\.polyline\\.", "", grob_name)

        # Create selector matching R maidr format: #escaped_id element_type
        # Use the grob name with escaped dots and add .1 suffix
        escaped_id <- gsub("\\.", "\\\\.", paste0(grob_name, ".1"))

        # Return as R-style selector: #escaped_id polyline
        css_selector <- paste0("#", escaped_id, " polyline")

        list(css_selector)
      } else {
        list()
      }
    },

    #' Find polyline grobs in the gtable
    #' @param gt The gtable to search
    #' @return List of polyline grobs
    find_polyline_grobs = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        stop("No panel found in gtable")
      }

      panel_grob <- gt$grobs[[panel_index]]

      if (!inherits(panel_grob, "gTree")) {
        stop("Panel grob is not a gTree")
      }

      find_polyline_grobs_recursive <- function(grob) {
        polyline_grobs <- list()

        # Look specifically for polyline grobs
        if (!is.null(grob$name) && grepl("polyline", grob$name, ignore.case = TRUE)) {
          polyline_grobs[[length(polyline_grobs) + 1]] <- grob
        }

        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            polyline_grobs <- c(polyline_grobs, find_polyline_grobs_recursive(grob[[i]]))
          }
        }

        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            polyline_grobs <- c(polyline_grobs, find_polyline_grobs_recursive(grob$children[[i]]))
          }
        }

        polyline_grobs
      }

      polyline_grobs <- find_polyline_grobs_recursive(panel_grob)
      polyline_grobs
    },



    #' Check if layer needs reordering
    #' @return FALSE (line plots typically don't need reordering)
    needs_reordering = function() {
      FALSE
    },

    #' Apply reordering to plot (not needed for lines)
    #' @param plot The ggplot2 object
    #' @return The original plot (no reordering needed)
    apply_reordering = function(plot) {
      # Line plots don't need reordering
      plot
    },

    #' Get reordered plot (same as original for lines)
    #' @return The plot (no reordering applied)
    get_reordered_plot = function() {
      private$.reordered_plot
    }
  ),
  private = list(
    reordered_plot = NULL,
    last_result = NULL
  )
)
