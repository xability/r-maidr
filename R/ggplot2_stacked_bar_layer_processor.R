#' Stacked Bar Layer Processor
#'
#' Processes stacked bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2StackedBarProcessor <- R6::R6Class(
  "Ggplot2StackedBarProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL) {
      data <- self$extract_data(plot, built)

      selectors <- self$generate_selectors(plot, gt)

      # Build axes including fill label for stacked bars
      axes <- self$extract_layer_axes(plot, layout)

      # Add fill axis label from built plot labels (includes labs(fill = ...))
      if (!is.null(built)) {
        fill_label <- built$plot$labels$fill
      } else {
        b <- ggplot2::ggplot_build(plot)
        fill_label <- b$plot$labels$fill
      }
      if (is.null(fill_label)) {
        # Fallback: get fill label from mapping expression
        layer_index <- self$get_layer_index()
        fill_quo <- plot$layers[[layer_index]]$mapping$fill
        if (is.null(fill_quo)) fill_quo <- plot$mapping$fill
        if (!is.null(fill_quo)) {
          fill_label <- rlang::as_label(fill_quo)
        }
      }
      if (!is.null(fill_label)) {
        axes$z <- fill_label
      }

      list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = axes
      )
    },
    needs_reordering = function() {
      TRUE
    },
    reorder_layer_data = function(data, plot) {
      columns <- self$extract_plot_columns(plot)
      fill_col <- columns$fill_col
      category_col <- columns$category_col
      if (is.null(fill_col) || is.null(category_col)) {
        return(data)
      }
      if (!(fill_col %in% names(data)) || !(category_col %in% names(data))) {
        return(data)
      }

      data <- data[order(data[[category_col]], data[[fill_col]]), , drop = FALSE]
      data
    },
    extract_plot_columns = function(plot) {
      plot_mapping <- plot$mapping

      extract_col_name <- function(quo) {
        if (is.null(quo)) {
          return(NULL)
        }
        expr <- rlang::quo_get_expr(quo)
        if (is.call(expr) && expr[[1]] == "factor") {
          as.character(expr[[2]])
        } else {
          rlang::as_label(expr)
        }
      }

      list(
        fill_col = extract_col_name(plot_mapping$fill),
        category_col = extract_col_name(plot_mapping$x)
      )
    },
    extract_data = function(plot, built = NULL) {
      original_data <- plot$data
      plot_mapping <- plot$mapping
      layer_index <- self$get_layer_index()
      layer_mapping <- plot$layers[[layer_index]]$mapping

      x_col <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
        x_col <- rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot_mapping$x)) {
        x_col <- rlang::as_label(plot_mapping$x)
      }

      fill_col <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$fill)) {
        fill_col <- rlang::as_label(layer_mapping$fill)
      } else if (!is.null(plot_mapping$fill)) {
        fill_col <- rlang::as_label(plot_mapping$fill)
      }

      # Check if y mapping exists (stat="identity") or is stat-computed (stat="count")
      y_quo <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$y)) {
        y_quo <- layer_mapping$y
      } else if (!is.null(plot_mapping$y)) {
        y_quo <- plot_mapping$y
      }
      has_y_mapping <- !is.null(y_quo)
      y_col <- if (has_y_mapping) rlang::as_label(y_quo) else NULL

      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      built_data_layer <- built$data[[layer_index]]

      # Determine stacking order from built data (bottom-to-top at first x position)
      first_bar_data <- built_data_layer[built_data_layer$x == min(built_data_layer$x), ]
      first_bar_data <- first_bar_data[order(first_bar_data$ymin), ]

      if (has_y_mapping && !is.null(y_col) && y_col %in% names(original_data) &&
          !is.null(fill_col) && fill_col %in% names(original_data) &&
          !is.null(x_col) && x_col %in% names(original_data)) {
        # stat="identity": original data and built data have same row count,
        # so setNames mapping is valid
        color_to_fill <- setNames(
          as.character(original_data[[fill_col]]),
          built_data_layer$fill
        )
        stacking_order <- unique(color_to_fill[first_bar_data$fill])

        # Read values from original data (original approach)
        fill_groups <- split(original_data, original_data[[fill_col]])

        lapply(stacking_order, function(fill_value) {
          group_data <- fill_groups[[as.character(fill_value)]]
          group_data <- group_data[order(group_data[[x_col]]), ]

          lapply(seq_len(nrow(group_data)), function(i) {
            list(
              x = as.character(group_data[[x_col]][i]),
              y = group_data[[y_col]][i],
              z = as.character(fill_value)
            )
          })
        })
      } else {
        # stat="count" or other stat-computed: use built data
        # Get x-axis scale labels for readable category names
        x_labels <- NULL
        panel_params <- built$layout$panel_params[[1]]
        if (!is.null(panel_params$x) && !is.null(panel_params$x$get_labels)) {
          x_labels <- panel_params$x$get_labels()
        } else if (!is.null(panel_params$x.labels)) {
          x_labels <- panel_params$x.labels
        }
        all_x_positions <- sort(unique(built_data_layer$x))

        # Build color-to-label mapping using the fill scale
        fill_color_to_label <- NULL
        for (sc in built$plot$scales$scales) {
          if ("fill" %in% sc$aesthetics && !is.null(sc$map) &&
              is.function(sc$map) && !is.null(sc$range$range)) {
            fill_labels <- sc$get_labels()
            mapped_colors <- sc$map(sc$range$range)
            if (length(fill_labels) == length(mapped_colors)) {
              fill_color_to_label <- setNames(fill_labels, mapped_colors)
            }
            break
          }
        }

        # Determine global stacking order from built data.
        # ggplot2 renders SVG rects top-first within each column (descending
        # ymin). maidr.js default groupDirection is "reverse": for each column
        # it iterates data rows from last to first, mapping to DOM rects in
        # order. So data[last] maps to DOM rect[0] (top segment) and data[0]
        # maps to the last DOM rect (bottom segment).
        # Therefore: data[0] = bottom fill level, data[last] = top fill level.
        fill_max_y <- tapply(built_data_layer$ymax, built_data_layer$fill, max)
        ordered_colors <- names(sort(fill_max_y, decreasing = FALSE))

        # Build full grid: every fill group has an entry for EVERY x-category.
        # maidr.js requires rectangular data (same # of columns per row).
        # Missing segments get y = 0; maidr.js skips zero-value DOM matching.
        lapply(ordered_colors, function(hex_color) {
          group_rows <- built_data_layer[built_data_layer$fill == hex_color, ]

          fill_label <- if (!is.null(fill_color_to_label) &&
                           hex_color %in% names(fill_color_to_label)) {
            fill_color_to_label[[hex_color]]
          } else {
            hex_color
          }

          # Create a lookup of x_pos -> count for this fill color
          vals <- setNames(
            if ("count" %in% names(group_rows)) group_rows$count else (group_rows$ymax - group_rows$ymin),
            group_rows$x
          )

          lapply(all_x_positions, function(x_pos) {
            x_name <- if (!is.null(x_labels) && x_pos >= 1 &&
                         x_pos <= length(x_labels)) {
              x_labels[x_pos]
            } else {
              as.character(x_pos)
            }
            y_val <- if (as.character(x_pos) %in% names(vals)) {
              vals[[as.character(x_pos)]]
            } else {
              0
            }
            list(
              x = as.character(x_name),
              y = y_val,
              z = as.character(fill_label)
            )
          })
        })
      }
    },
    generate_selectors = function(plot, gt = NULL) {
      find_rect_grobs <- function(grob) {
        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          return(grob$name)
        }

        if ("children" %in% names(grob)) {
          for (child in grob$children) {
            result <- find_rect_grobs(child)
            if (!is.null(result)) {
              return(result)
            }
          }
        }
        NULL
      }

      if (!is.null(gt)) {
        rect_grob <- NULL

        if ("grobs" %in% names(gt)) {
          for (grob in gt$grobs) {
            rect_grob <- find_rect_grobs(grob)
            if (!is.null(rect_grob)) break
          }
        }

        if (!is.null(rect_grob)) {
          layer_id <- gsub("geom_rect\\.rect\\.", "", rect_grob)
          grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id, " rect")
        } else {
          layer_id <- self$get_layer_index()
          grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id, " rect")
        }
      }

      list(selector_string)
    }
  )
)
