#' Heatmap Layer Processor
#'
#' Processes heatmap layers (geom_tile) with generic data and grob reordering
#'
#' @keywords internal
Ggplot2HeatmapLayerProcessor <- R6::R6Class("Ggplot2HeatmapLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL) {
      # Extract data from the heatmap layer
      extracted_data <- self$extract_data(plot, built)

      # Generate selectors for the heatmap elements
      selectors <- self$generate_selectors(plot, gt)

      # Extract the fill label and put it in axes.fill
      fill_label <- extracted_data$fill_label
      # Remove fill_label from data
      data <- extracted_data[names(extracted_data) != "fill_label"]

      # Create axes with fill label
      axes <- list(
        x = "x",
        y = "y",
        fill = fill_label
      )

      list(
        data = data,
        selectors = selectors,
        axes = axes
      )
    },
    needs_reordering = function() {
      TRUE
    },
    reorder_layer_data = function(data, plot) {
      # Generic data reordering for heatmaps
      # Reorder data to match visual order (row-wise)
      if (nrow(data) == 0) {
        return(data)
      }

      # Get column names
      x_col <- names(data)[1]
      y_col <- names(data)[2]

      # Get plot scales to determine order
      x_scale <- plot$scales$get_scales("x")
      y_scale <- plot$scales$get_scales("y")

      # Determine x-axis order
      if (!is.null(x_scale) && !is.null(x_scale$limits)) {
        x_order <- x_scale$limits
      } else {
        x_order <- sort(unique(data[[x_col]]))
      }

      # Determine y-axis order
      if (!is.null(y_scale) && !is.null(y_scale$limits)) {
        y_order <- y_scale$limits
      } else {
        y_order <- sort(unique(data[[y_col]]))
      }

      # Convert to factors with specified levels
      data[[x_col]] <- factor(data[[x_col]], levels = x_order)
      data[[y_col]] <- factor(data[[y_col]], levels = y_order)

      # Reorder data column-wise (x first, then y) for column-major DOM order
      # Keep y order as-is so bottom row comes first (for navigation starting from bottom-left)
      reordered_data <- data[order(data[[x_col]], data[[y_col]]), , drop = FALSE]
      rownames(reordered_data) <- NULL

      return(reordered_data)
    },
    extract_data = function(plot, built = NULL) {
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      layer_index <- self$get_layer_index()
      built_data <- built$data[[layer_index]]

      # Get the original data
      original_data <- plot$data

      # Get column names from plot mapping
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[layer_index]]$mapping

      # Determine x, y, and fill column names
      x_col <- if (!is.null(layer_mapping$x)) {
        rlang::as_name(layer_mapping$x)
      } else if (!is.null(plot_mapping$x)) {
        rlang::as_name(plot_mapping$x)
      } else {
        names(original_data)[1]
      }

      y_col <- if (!is.null(layer_mapping$y)) {
        rlang::as_name(layer_mapping$y)
      } else if (!is.null(plot_mapping$y)) {
        rlang::as_name(plot_mapping$y)
      } else {
        names(original_data)[2]
      }

      fill_col <- if (!is.null(layer_mapping$fill)) {
        rlang::as_name(layer_mapping$fill)
      } else if (!is.null(plot_mapping$fill)) {
        rlang::as_name(plot_mapping$fill)
      } else {
        names(original_data)[3]
      }

      # Get unique values in original order
      x_values <- unique(original_data[[x_col]])
      y_values <- unique(original_data[[y_col]])

      # Create mapping from numeric positions to original values
      x_mapping <- setNames(x_values, seq_along(x_values))
      y_mapping <- setNames(y_values, seq_along(y_values))

      # Create matrix structure
      score_matrix <- matrix(NA, nrow = length(y_values), ncol = length(x_values))
      rownames(score_matrix) <- y_values
      colnames(score_matrix) <- x_values

      # Fill the matrix with scores using built data
      for (i in seq_len(nrow(built_data))) {
        x_pos <- built_data$x[i]
        y_pos <- built_data$y[i]

        # Map positions back to original values
        x_val <- x_mapping[as.character(x_pos)]
        y_val <- y_mapping[as.character(y_pos)]

        # Get the original score value
        score_val <- original_data[[fill_col]][original_data[[x_col]] == x_val & original_data[[y_col]] == y_val]

        if (length(score_val) > 0) {
          row_idx <- which(y_values == y_val)
          col_idx <- which(x_values == x_val)
          score_matrix[row_idx, col_idx] <- score_val[1]
        }
      }

      # Convert matrix to list format
      # Reverse y_values to match DOM order (bottom row first)
      y_values_reversed <- rev(y_values)

      points <- lapply(seq_len(nrow(score_matrix)), function(i) {
        as.numeric(score_matrix[i, ])
      })

      # Reverse points array to match reversed y_values
      points <- rev(points)


      return(list(
        points = points,
        x = as.character(x_values),
        y = as.character(y_values_reversed),
        fill_label = fill_col
      ))
    },
    generate_selectors = function(plot, gt = NULL) {
      # Generate selectors for heatmap elements
      selectors <- list()

      if (!is.null(gt)) {
        # Find heatmap-specific grob elements
        panel_grob <- find_panel_grob(gt)
        if (!is.null(panel_grob)) {
          # Look for geom_rect elements (master container)
          rect_children <- find_children_by_type(panel_grob, "geom_rect")
          if (length(rect_children) > 0) {
            # Create CSS selector to target all rect elements inside the master container
            master_container <- rect_children[1]
            # Convert grob name to SVG ID by appending .1 (following bar layer processor pattern)
            svg_id <- paste0(master_container, ".1")
            # Escape dots in the ID for CSS selector
            escaped_id <- gsub("\\.", "\\\\.", svg_id)
            css_selector <- paste0("g#", escaped_id, " > rect")
            selectors <- css_selector
          }
        }
      }

      return(selectors)
    }
  )
)
