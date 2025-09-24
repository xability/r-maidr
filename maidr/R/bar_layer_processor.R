#' Bar Layer Processor
#'
#' Processes bar plot layers with complete logic included
#'
#' @keywords internal
BarLayerProcessor <- R6::R6Class("BarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL) {
      data <- self$extract_data(plot, built)
      selectors <- self$generate_selectors(plot, gt)
      list(
        data = data,
        selectors = selectors
      )
    },
    needs_reordering = function() {
      TRUE
    },
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
    extract_data = function(plot, built = NULL) {
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      layer_index <- self$get_layer_index()
      built_data <- built$data[[layer_index]]

      original_data <- plot$data

      unique_groups <- sort(unique(built_data$group))
      unique_categories <- sort(unique(original_data[[1]]))

      data_points <- list()
      for (i in seq_len(nrow(built_data))) {
        group_idx <- built_data$group[i]
        category_idx <- which(unique_groups == group_idx)

        point <- list(
          x = unique_categories[category_idx],
          y = built_data$y[i]
        )

        data_points[[i]] <- point
      }

      data_points
    },
    generate_selectors = function(plot, gt = NULL) {
      if (is.null(gt)) gt <- ggplot2::ggplotGrob(plot)

      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        return(list())
      }

      panel_grob <- gt$grobs[[panel_index]]
      if (!inherits(panel_grob, "gTree")) {
        return(list())
      }

      find_rect_names <- function(grob) {
        names <- character(0)

        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          names <- c(names, grob$name)
        }

        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            names <- c(names, find_rect_names(grob[[i]]))
          }
        }

        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            names <- c(names, find_rect_names(grob$children[[i]]))
          }
        }

        names
      }

      rect_names <- find_rect_names(panel_grob)

      if (length(rect_names) == 0) {
        return(list())
      }

      selectors <- lapply(rect_names, function(name) {
        layer_id <- gsub("geom_rect\\.rect\\.", "", name)
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        paste0("#", escaped_grob_id, " rect")
      })

      selectors
    }
  )
)
