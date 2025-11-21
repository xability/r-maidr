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

      list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout)
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
          rlang::as_name(expr)
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
      x_col <- rlang::as_name(plot_mapping$x)
      y_col <- rlang::as_name(plot_mapping$y)
      fill_col <- rlang::as_name(plot_mapping$fill)

      built_data <- ggplot2::ggplot_build(plot)
      if (length(built_data$data) > 0) {
        built_data_layer <- built_data$data[[1]]
        first_bar_data <- built_data_layer[built_data_layer$x == 1, ]
        first_bar_data <- first_bar_data[order(first_bar_data$ymin), ]
        color_to_fill <- setNames(original_data[[fill_col]], built_data_layer$fill)
        stacking_order <- unique(color_to_fill[first_bar_data$fill])
      } else {
        stacking_order <- unique(original_data[[fill_col]])
      }

      fill_groups <- split(original_data, original_data[[fill_col]])

      lapply(stacking_order, function(fill_value) {
        group_data <- fill_groups[[fill_value]]
        group_data <- group_data[order(group_data[[x_col]]), ]

        lapply(seq_len(nrow(group_data)), function(i) {
          list(
            x = as.character(group_data[[x_col]][i]),
            y = group_data[[y_col]][i],
            fill = as.character(fill_value)
          )
        })
      })
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
