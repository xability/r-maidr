#' Bar Layer Processor
#'
#' Processes bar plot layers with complete logic included
#'
#' @export
BarLayerProcessor <- R6::R6Class("BarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL) {
      # Apply reordering if needed
      if (self$needs_reordering()) {
        plot <- self$apply_reordering(plot)
        # Store the reordered plot for later use
        private$reordered_plot <- plot
      }

      # Extract data from the reordered plot
      data <- self$extract_data_impl(plot, built)

      # Generate selectors using the reordered plot
      selectors <- self$generate_selectors(plot, gt)

      list(
        data = data,
        selectors = selectors
      )
    },

    #' Check if this layer needs reordering
    needs_reordering = function() {
      TRUE # Bar plots need reordering by x-axis
    },

    

    #' Reorder only this layer's data using category order
    reorder_layer_data = function(data, plot) {
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[self$get_layer_index()]]$mapping
      x_col <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
        x_col <- rlang::as_name(layer_mapping$x)
      } else if (!is.null(plot_mapping) && !is.null(plot_mapping$x)) {
        x_col <- rlang::as_name(plot_mapping$x)
      }
      if (!is.null(x_col) && x_col %in% names(data)) {
        data[order(data[[x_col]]), , drop = FALSE]
      } else {
        data
      }
    },

    #' Extract data implementation
    extract_data_impl = function(plot, built = NULL) {
      # Build the plot to get data (use provided built if available)
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      # Find bar layers
      bar_layers <- which(sapply(plot$layers, function(layer) {
        inherits(layer$geom, "GeomBar") || inherits(layer$geom, "GeomCol")
      }))

      if (length(bar_layers) == 0) {
        stop("No bar layers found in plot")
      }

      # Extract data from first bar layer
      built_data <- built$data[[bar_layers[1]]]
      original_data <- plot$data
      x_col <- NULL
      if (!is.null(original_data) && is.data.frame(original_data)) {
        for (col in names(original_data)) {
          if (is.character(original_data[[col]]) ||
                is.factor(original_data[[col]])) {
            x_col <- col
            break
          }
        }
      }

      # Check if user provided fill aesthetic mapping
      has_user_fill <- FALSE
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[bar_layers[1]]]$mapping

      if (!is.null(layer_mapping) && !is.null(layer_mapping$fill)) {
        has_user_fill <- TRUE
      } else if (!is.null(plot_mapping) && !is.null(plot_mapping$fill)) {
        has_user_fill <- TRUE
      }

      # Build data points in original data frame order
      data_points <- list()
      if (nrow(built_data) > 0) {
        for (j in seq_len(nrow(built_data))) {
          point <- list()
          # Add x value (string, for JSON)
          if (!is.null(x_col)) {
            # Get unique values in alphabetical order (ggplot2 default)
            alphabetical_values <- sort(
              unique(as.character(original_data[[x_col]]))
            )
            numeric_index <- built_data$x[j]
            if (numeric_index <= length(alphabetical_values)) {
              point$x <- alphabetical_values[numeric_index]
            } else {
              point$x <- built_data$x[j]
            }
          } else {
            point$x <- built_data$x[j]
          }
          # Add y value
          if ("y" %in% names(built_data)) {
            point$y <- built_data$y[j]
          } else if ("count" %in% names(built_data)) {
            point$y <- built_data$count[j]
          }
          # Only add fill if user explicitly provided fill aesthetic mapping
          if (has_user_fill && "fill" %in% names(built_data)) {
            point$fill <- built_data$fill[j]
          }
          data_points[[j]] <- point
        }
      }

      data_points
    },
    generate_selectors = function(plot, gt = NULL) {
      # Convert to gtable to get grob information if not provided
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      # Find bar grobs using the same logic as original bar.R
      grobs <- self$find_bar_grobs(gt)

      # For bar plots, we expect only one grob
      if (length(grobs) == 0) {
        return(list())
      } else {
        # Use the first (and only) grob
        grob <- grobs[[1]]
        grob_name <- grob$name

        # Extract the numeric part from grob name
        # (e.g., "2" from "geom_rect.rect.2")
        layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)

        # Create selector for this bar
        selector <- self$make_bar_selector(layer_id)
        return(list(selector))
      }
    },

    #' Make bar plot selector (same as original bar.R)
    make_bar_selector = function(layer_id) {
      grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
      paste0("#", escaped_grob_id, " rect")
    },

    #' Find bar grobs from a gtable (same as original bar.R)
    find_bar_grobs = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        stop("No panel found in gtable")
      }

      panel_grob <- gt$grobs[[panel_index]]

      if (!inherits(panel_grob, "gTree")) {
        stop("Panel grob is not a gTree")
      }

      find_geom_rect_grobs_recursive <- function(grob) {
        rect_grobs <- list()

        # Look specifically for geom_rect.rect grobs
        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          rect_grobs[[length(rect_grobs) + 1]] <- grob
        }

        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs_recursive(grob[[i]]))
          }
        }

        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs_recursive(grob$children[[i]]))
          }
        }

        rect_grobs
      }

      find_geom_rect_grobs_recursive(panel_grob)
    },

    #' Get the reordered plot if it exists
    get_reordered_plot = function() {
      private$reordered_plot
    }
  ),
  private = list(
    reordered_plot = NULL
  )
)
