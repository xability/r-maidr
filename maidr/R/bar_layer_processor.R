#' Bar Layer Processor
#'
#' Processes bar plot layers with complete logic included
#'
#' @keywords internal
BarLayerProcessor <- R6::R6Class("BarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, scale_mapping = NULL, grob_id = NULL, panel_id = NULL) {
      data <- self$extract_data(plot, built, scale_mapping, panel_id)
      selectors <- self$generate_selectors(plot, gt, grob_id)
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
    extract_data = function(plot, built = NULL, scale_mapping = NULL, panel_id = NULL) {
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      layer_index <- self$get_layer_index()
      built_data <- built$data[[layer_index]]

      # Filter data for specific panel if panel_id is provided
      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, ]
      }

      # Apply scale mapping if provided (for faceted plots)
      if (!is.null(scale_mapping)) {
        x_values <- self$apply_scale_mapping(built_data$x, scale_mapping)
      } else {
        # Original logic for non-faceted plots
        plot_mapping <- plot$mapping
        layer_mapping <- plot$layers[[layer_index]]$mapping

        x_col <- NULL
        if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
          x_col <- rlang::as_name(layer_mapping$x)
        } else if (!is.null(plot_mapping) && !is.null(plot_mapping$x)) {
          x_col <- rlang::as_name(plot_mapping$x)
        }

        original_data <- plot$data

        # Resolve x values from original data ordered by x_col
        if (!is.null(x_col) && x_col %in% names(original_data)) {
          ordered_idx <- order(original_data[[x_col]])
          x_values <- original_data[[x_col]][ordered_idx]
        } else {
          ordered_idx <- seq_len(nrow(original_data))
          x_values <- original_data[[1]]
        }
      }

      data_points <- list()
      n <- min(nrow(built_data), length(x_values))
      
      for (i in seq_len(n)) {
        point <- list(
          x = as.character(x_values[i]),
          y = built_data$y[i]
        )
        data_points[[i]] <- point
      }

      # If built_data has more rows than x labels, append with NA x labels
      if (nrow(built_data) > n) {
        for (i in seq.int(n + 1, nrow(built_data))) {
          data_points[[i]] <- list(
            x = NA_character_,
            y = built_data$y[i]
          )
        }
      }

      data_points
    },
    generate_selectors = function(plot, gt = NULL, grob_id = NULL) {
      if (!is.null(grob_id)) {
        # For faceted plots: use provided grob ID with .1 suffix (gridSVG adds this)
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        selector <- paste0("#", escaped_grob_id, " rect")
        return(list(selector))
      } else {
        # For single plots: use existing logic
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
    }
  )
)
