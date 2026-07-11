#' Bar Layer Processor
#'
#' Processes bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2BarLayerProcessor <- R6::R6Class(
  "Ggplot2BarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      data <- self$extract_data(plot, built, scale_mapping, panel_id)
      selectors <- self$generate_selectors(plot, gt, grob_id, panel_ctx)
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
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[self$get_layer_index()]]$mapping
      x_col <- NULL
      # Use as_label to handle complex expressions like factor(cyl)
      if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
        x_col <- rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot_mapping) && !is.null(plot_mapping$x)) {
        x_col <- rlang::as_label(plot_mapping$x)
      }
      # Only reorder if x_col is a simple column name that exists in data
      if (!is.null(x_col) && x_col %in% names(data)) {
        data[order(data[[x_col]]), , drop = FALSE]
      } else {
        data
      }
    },
    extract_data = function(plot, built = NULL, scale_mapping = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_index <- self$get_layer_index()
      built_data <- built$data[[layer_index]]

      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, ]
      }

      # For faceted plots, get x values from built data or scale mapping
      if (!is.null(panel_id)) {
        # Use x values from built_data (contains actual axis values)
        # built_data$x contains the position indices, we need the actual axis values
        if (!is.null(scale_mapping)) {
          x_values <- self$apply_scale_mapping(built_data$x, scale_mapping)
        } else {
          plot_mapping <- plot$mapping
          layer_mapping <- plot$layers[[layer_index]]$mapping

          x_col <- NULL
          if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
            x_col <- rlang::as_label(layer_mapping$x)
          } else if (!is.null(plot_mapping) && !is.null(plot_mapping$x)) {
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
          } else {
            # Fallback: use built_data$x but convert to character
            x_values <- as.character(built_data$x)
          }
        }
      } else {
        # Original logic for non-faceted plots
        plot_mapping <- plot$mapping
        layer_mapping <- plot$layers[[layer_index]]$mapping

        x_col <- NULL
        x_expr <- NULL
        if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
          x_expr <- layer_mapping$x
          x_col <- rlang::as_label(layer_mapping$x)
        } else if (!is.null(plot_mapping) && !is.null(plot_mapping$x)) {
          x_expr <- plot_mapping$x
          x_col <- rlang::as_label(plot_mapping$x)
        }

        original_data <- plot$data

        # For bar plots, the built_data has one row per bar (after stat computation).
        # We need per-row x values that match built_data rows.
        #
        # Strategy (in priority order):
        #   1. Read the original data column directly (preserves Date/POSIXct
        #      typing, formatted to ISO strings by `format_x_value()`).
        #   2. Extract the underlying column for wrapped expressions like
        #      `factor(cyl)`.
        #   3. Fall back to the x-scale's break labels from `panel_params`
        #      (covers stat="count" with non-column x mappings).
        #   4. Last resort: row indices.
        #
        # Note: `panel_params$x$get_labels()` returns formatted axis-tick
        # labels (e.g. "Dec 25", "Jan 01" for Date axes). It must NOT be the
        # primary path or per-row dates degrade to sparse axis-break labels.
        x_values <- NULL

        # 1. Primary: per-row x values from the original data column.
        if (!is.null(x_col) && x_col %in% names(original_data)) {
          x_values <- sort(unique(original_data[[x_col]]))
        }

        # 2. Extract column from expression like factor(cyl).
        if (is.null(x_values) && !is.null(x_expr)) {
          expr_str <- rlang::as_label(x_expr)
          match <- regmatches(expr_str, regexec("^(?:factor|as\\.factor|as\\.character)\\(([^)]+)\\)$", expr_str, perl = TRUE))
          if (length(match[[1]]) > 1) {
            base_col <- match[[1]][2]
            if (base_col %in% names(original_data)) {
              x_values <- sort(unique(original_data[[base_col]]))
            }
          }
        }

        # 3. Fall back to x-scale break labels.
        if (is.null(x_values) && !is.null(built)) {
          panel_params <- built$layout$panel_params[[1]]
          if (!is.null(panel_params$x) && !is.null(panel_params$x$get_labels)) {
            scale_labels <- panel_params$x$get_labels()
            scale_labels <- scale_labels[!is.na(scale_labels)]
            if (length(scale_labels) > 0) {
              x_values <- scale_labels
            }
          } else if (!is.null(panel_params$x.labels)) {
            x_values <- panel_params$x.labels
          }
        }

        # 4. Last resort: row indices.
        if (is.null(x_values)) {
          x_values <- seq_len(nrow(built_data))
        }
      }

      data_points <- list()
      n <- min(nrow(built_data), length(x_values))

      for (i in seq_len(n)) {
        point <- list(
          x = self$format_x_value(x_values[i]),
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

    #' @description Format an x-axis value as character.
    #'
    #' Date / POSIXct / POSIXlt values are formatted via `format()` so that a
    #' `Date` column emits ISO date strings ("2024-01-02") rather than the
    #' default scale-tick labels ("Jan 02"). All other types use
    #' `as.character()`. Mirrors `Ggplot2CandlestickProcessor$format_x_value()`
    #' so candle and bar layers from the same Date column align string-wise.
    format_x_value = function(x) {
      if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) {
        return(format(x))
      }
      as.character(x)
    },

    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      # Prefer panel-scoped selection when panel_ctx is provided
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
          svg_id <- paste0(name, ".1")
          escaped <- gsub("\\.", "\\\\.", svg_id)
          paste0("#", escaped, " rect")
        })
        return(selectors)
      }

      if (!is.null(grob_id)) {
        # For faceted plots: use provided grob ID with .1 suffix (gridSVG adds this)
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        selector <- paste0("#", escaped_grob_id, " rect")
        return(list(selector))
      } else {
        # For single plots: use existing logic
        if (is.null(gt)) {
          gt <- ggplot2::ggplotGrob(plot)
        }

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
