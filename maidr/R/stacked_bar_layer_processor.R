#' Stacked Bar Layer Processor
#'
#' Processes stacked bar plot layers with complete logic included
#'
#' @export
StackedBarLayerProcessor <- R6::R6Class("StackedBarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL) {
      # Extract data
      data <- self$extract_data_impl(plot, built)

      # Generate selectors
      selectors <- self$generate_selectors(plot, gt)

      list(
        data = data,
        selectors = selectors
      )
    },

    #' Check if this layer needs reordering
    needs_reordering = function() {
      TRUE # Stacked bars need reordering
    },


    #' Reorder only this layer's data by applying global category order and reversed stacking order
    reorder_layer_data = function(data, plot) {
      columns <- self$extract_plot_columns(plot)
      fill_col <- columns$fill_col
      category_col <- columns$category_col
      if (is.null(fill_col) || is.null(category_col)) return(data)
      if (!(fill_col %in% names(data)) || !(category_col %in% names(data))) return(data)

      # Determine stacking order using a temporary built layer
      y_col <- setdiff(names(data), c(fill_col, category_col))[1]
      if (is.na(y_col)) return(data)
      temp_plot <- ggplot2::ggplot(data, ggplot2::aes_string(x = category_col, y = y_col, fill = fill_col)) +
        ggplot2::geom_bar(stat = "identity", position = "stack")
      computed <- ggplot2::ggplot_build(temp_plot)$data[[1]]
      first_bar <- computed[computed$x == 1, ]
      first_bar <- first_bar[order(first_bar$ymin), ]
      color_to_fill <- setNames(data[[fill_col]], computed$fill)
      stacking_order <- unique(color_to_fill[first_bar$fill])

      # Reverse for JS layering
      data[[fill_col]] <- factor(data[[fill_col]], levels = rev(stacking_order))

      # Order by category then reversed fill
      data <- data[order(data[[category_col]], data[[fill_col]]), , drop = FALSE]
      # Ensure fill back to character to avoid factor issues downstream if needed
      data[[fill_col]] <- as.character(data[[fill_col]])
      data
    },

    #' Reorder data for stacked bar plots to ensure correct DOM element order
    reorder_for_stacked_bar = function(data, fill_col, category_col) {
      # Find the y column (the numeric column that's not fill_col or category_col)
      y_col <- setdiff(names(data), c(fill_col, category_col))[1]
      if (is.na(y_col)) {
        stop("Could not find y column in data")
      }

      # Create a temporary plot to determine the actual stacking order
      temp_plot <- ggplot2::ggplot(data, ggplot2::aes_string(x = category_col, y = y_col, fill = fill_col)) +
        ggplot2::geom_bar(stat = "identity", position = "stack")

      # Extract computed data to see the actual stacking order
      computed_data <- ggplot2::ggplot_build(temp_plot)$data[[1]]

      # Get the stacking order by looking at the first bar's layers
      first_bar_data <- computed_data[computed_data$x == 1, ]
      first_bar_data <- first_bar_data[order(first_bar_data$ymin), ] # Order by ymin (bottom to top)

      # Map colors back to fill values
      color_to_fill <- setNames(data[[fill_col]], computed_data$fill)
      stacking_order <- unique(color_to_fill[first_bar_data$fill])

      # Create a factor with the REVERSE stacking order for JavaScript
      # Visual stacking: Normal (bottom) → Below (middle) → Above (top)
      # JavaScript expects: Above (top) → Below (middle) → Normal (bottom)
      # So we reverse the stacking order
      data[[fill_col]] <- factor(data[[fill_col]], levels = rev(stacking_order))

      # Apply category-first ordering: category first, then fill in reverse stacking order
      reordered_data <- data[order(data[[category_col]], data[[fill_col]]), ]

      # Convert back to character to avoid factor issues
      reordered_data[[fill_col]] <- as.character(reordered_data[[fill_col]])

      reordered_data
    },


    #' Extract fill and category column names from plot aesthetics
    extract_plot_columns = function(plot) {
      # Get plot mappings
      plot_mapping <- plot$mapping

      # Extract fill column
      fill_col <- NULL
      if (!is.null(plot_mapping$fill)) {
        # Handle quosures and calls like factor(column)
        fill_expr <- rlang::quo_get_expr(plot_mapping$fill)
        if (is.call(fill_expr) && fill_expr[[1]] == "factor") {
          fill_col <- as.character(fill_expr[[2]])
        } else {
          fill_col <- rlang::as_name(fill_expr)
        }
      }

      # Extract x column (category)
      category_col <- NULL
      if (!is.null(plot_mapping$x)) {
        # Handle quosures and calls like factor(column)
        x_expr <- rlang::quo_get_expr(plot_mapping$x)
        if (is.call(x_expr) && x_expr[[1]] == "factor") {
          category_col <- as.character(x_expr[[2]])
        } else {
          category_col <- rlang::as_name(x_expr)
        }
      }

      list(
        fill_col = fill_col,
        category_col = category_col
      )
    },

    #' Extract data implementation
    extract_data_impl = function(plot, built = NULL) {
      # Get original data to retain text values
      original_data <- plot$data

      # Build the plot to get built data for segment calculations
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      # Find bar layers
      bar_layers <- which(sapply(plot$layers, function(layer) {
        inherits(layer$geom, "GeomBar") || inherits(layer$geom, "GeomCol")
      }))

      if (length(bar_layers) == 0) {
        stop("No bar layers found in plot")
      }

      # Extract built data from first bar layer for segment heights
      built_data <- built$data[[bar_layers[1]]]

      # For stacked bars, we need to calculate segment heights
      # y values in built_data are cumulative, so we need ymax - ymin
      if ("ymax" %in% names(built_data) && "ymin" %in% names(built_data)) {
        built_data$segment_height <- built_data$ymax - built_data$ymin
      } else {
        built_data$segment_height <- built_data$y
      }

      # Get the actual column names from the plot aesthetics
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[1]]$mapping

      # Determine x, y, and fill column names
      x_col <- NULL
      y_col <- NULL
      fill_col <- NULL

      # Check layer mapping first, then plot mapping
      if (!is.null(layer_mapping)) {
        if (!is.null(layer_mapping$x)) x_col <- rlang::as_name(layer_mapping$x)
        if (!is.null(layer_mapping$y)) y_col <- rlang::as_name(layer_mapping$y)
        if (!is.null(layer_mapping$fill)) fill_col <- rlang::as_name(layer_mapping$fill)
      }
      if (!is.null(plot_mapping)) {
        if (is.null(x_col) && !is.null(plot_mapping$x)) x_col <- rlang::as_name(plot_mapping$x)
        if (is.null(y_col) && !is.null(plot_mapping$y)) y_col <- rlang::as_name(plot_mapping$y)
        if (is.null(fill_col) && !is.null(plot_mapping$fill)) fill_col <- rlang::as_name(plot_mapping$fill)
      }

      # Ensure required columns are found
      if (is.null(x_col)) {
        stop("Could not determine x aesthetic mapping")
      }
      if (is.null(y_col)) {
        stop("Could not determine y aesthetic mapping")
      }
      if (!x_col %in% names(original_data)) {
        stop("x aesthetic column '", x_col, "' not found in data")
      }
      if (!y_col %in% names(original_data)) {
        stop("y aesthetic column '", y_col, "' not found in data")
      }

      # Group by fill values - this is a stacked bar plot with fill aesthetic
      fill_groups <- split(original_data, original_data[[fill_col]])

      # Extract the stacking order from the built data
      built_data <- ggplot2::ggplot_build(plot)
      if (length(built_data$data) > 0) {
        built_data_layer <- built_data$data[[1]]

        # Get the stacking order by looking at the first bar's layers
        first_bar_data <- built_data_layer[built_data_layer$x == 1, ]
        first_bar_data <- first_bar_data[order(first_bar_data$ymin), ] # Order by ymin (bottom to top)

        # Map colors back to fill values
        color_to_fill <- setNames(original_data[[fill_col]], built_data_layer$fill)
        stacking_order <- unique(color_to_fill[first_bar_data$fill])

        # Use the stacking order (bottom to top)
        fill_order <- stacking_order
      } else {
        # Fallback to alphabetical order if we can't determine stacking order
        fill_order <- unique(original_data[[fill_col]])
      }

      maidr_data <- list()
      for (fill_value in fill_order) {
        if (fill_value %in% names(fill_groups)) {
          group_data <- fill_groups[[fill_value]]
          # Sort by x position to match visual order
          if (!is.null(x_col)) {
            group_data <- group_data[order(group_data[[x_col]]), ]
          }

          group_points <- list()
          for (i in seq_len(nrow(group_data))) {
            # Create point with original text values (not ggplot2's internal representations)
            point <- list(
              x = as.character(group_data[[x_col]][i]),
              y = group_data[[y_col]][i],
              fill = as.character(fill_value)
            )
            group_points[[i]] <- point
          }
          maidr_data[[length(maidr_data) + 1]] <- group_points
        }
      }

      maidr_data
    },
    generate_selectors = function(plot, gt = NULL) {
      # Helper function to recursively search for geom_rect grobs
      find_geom_rect_grobs <- function(grob) {
        rect_grobs <- character(0)

        # Check if this grob is a geom_rect
        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          rect_grobs <- c(rect_grobs, grob$name)
        }

        # Recursively search children
        if ("children" %in% names(grob) && length(grob$children) > 0) {
          for (child in grob$children) {
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs(child))
          }
        }

        rect_grobs
      }

      # Find the actual grob ID from the gtable
      if (!is.null(gt)) {
        # Try to find rect grobs by recursively searching the grob tree
        rect_grobs <- character(0)

        # Search through all top-level grobs
        if ("grobs" %in% names(gt) && length(gt$grobs) > 0) {
          for (i in seq_along(gt$grobs)) {
            grob <- gt$grobs[[i]]
            rect_grobs <- c(rect_grobs, find_geom_rect_grobs(grob))
          }
        }

        # If not found, look in layout
        if (length(rect_grobs) == 0 && "layout" %in% names(gt)) {
          if ("grobs" %in% names(gt$layout) && length(gt$layout$grobs) > 0) {
            for (i in seq_along(gt$layout$grobs)) {
              grob <- gt$layout$grobs[[i]]
              rect_grobs <- c(rect_grobs, find_geom_rect_grobs(grob))
            }
          }
        }

        if (length(rect_grobs) > 0) {
          # Use the first rect grob found
          grob_name <- rect_grobs[1]
          # Extract the numeric part from grob name (e.g., "58" from "geom_rect.rect.58")
          layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
          # Create selector with .1 suffix as per original logic
          grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id, " rect")
        } else {
          # Fallback to layer index if no rect grobs found
          layer_id <- self$get_layer_index()
          grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id, " rect")
        }
      } else {
        # No gtable provided, use layer index
        layer_id <- self$get_layer_index()
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        selector_string <- paste0("#", escaped_grob_id, " rect")
      }

      list(selector_string)
    }
  )
)
