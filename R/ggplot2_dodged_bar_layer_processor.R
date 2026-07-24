#' Dodged Bar Layer Processor
#'
#' Processes dodged bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2DodgedBarLayerProcessor <- R6::R6Class(
  "Ggplot2DodgedBarLayerProcessor",
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
      data <- self$extract_data(plot, built, panel_ctx = panel_ctx)

      selectors <- self$generate_selectors(plot, gt, panel_ctx = panel_ctx)

      # Build axes including fill label for dodged bars
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
        axes$z <- list(label = fill_label)
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
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[self$get_layer_index()]]$mapping
      x_col <- y_col <- fill_col <- NULL
      if (!is.null(layer_mapping)) {
        if (!is.null(layer_mapping$x)) {
          x_col <- rlang::as_label(layer_mapping$x)
        }
        if (!is.null(layer_mapping$y)) {
          y_col <- rlang::as_label(layer_mapping$y)
        }
        if (!is.null(layer_mapping$fill)) fill_col <- rlang::as_label(layer_mapping$fill)
      }
      if (!is.null(plot_mapping)) {
        if (is.null(x_col) && !is.null(plot_mapping$x)) {
          x_col <- rlang::as_label(plot_mapping$x)
        }
        if (is.null(y_col) && !is.null(plot_mapping$y)) {
          y_col <- rlang::as_label(plot_mapping$y)
        }
        if (is.null(fill_col) && !is.null(plot_mapping$fill)) {
          fill_col <- rlang::as_label(plot_mapping$fill)
        }
      }
      if (
        is.null(x_col) ||
          is.null(fill_col) ||
          !(x_col %in% names(data)) ||
          !(fill_col %in% names(data))
      ) {
        return(data)
      }
      x_ordered <- factor(data[[x_col]], levels = sort(unique(data[[x_col]])))
      fill_ordered <- factor(data[[fill_col]], levels = rev(sort(unique(data[[fill_col]]))))

      data[order(x_ordered, fill_ordered), , drop = FALSE]
    },
    extract_data = function(plot, built = NULL, panel_ctx = NULL) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[1]]$mapping

      x_col <- y_col <- fill_col <- NULL

      if (!is.null(layer_mapping)) {
        if (!is.null(layer_mapping$x)) {
          x_col <- rlang::as_label(layer_mapping$x)
        }
        if (!is.null(layer_mapping$y)) {
          y_col <- rlang::as_label(layer_mapping$y)
        }
        if (!is.null(layer_mapping$fill)) fill_col <- rlang::as_label(layer_mapping$fill)
      }
      if (!is.null(plot_mapping)) {
        if (is.null(x_col) && !is.null(plot_mapping$x)) {
          x_col <- rlang::as_label(plot_mapping$x)
        }
        if (is.null(y_col) && !is.null(plot_mapping$y)) {
          y_col <- rlang::as_label(plot_mapping$y)
        }
        if (is.null(fill_col) && !is.null(plot_mapping$fill)) {
          fill_col <- rlang::as_label(plot_mapping$fill)
        }
      }

      if (is.null(x_col) || is.null(y_col) || is.null(fill_col)) {
        stop("Could not determine required aesthetic mappings")
      }

      source_data <- plot$data

      # Facet path: restrict to this panel's facet group(s)
      if (!is.null(panel_ctx) && length(panel_ctx$facet_groups) > 0) {
        for (facet_var in names(panel_ctx$facet_groups)) {
          if (facet_var %in% names(source_data)) {
            source_data <- source_data[
              as.character(source_data[[facet_var]]) ==
                as.character(panel_ctx$facet_groups[[facet_var]]),
              ,
              drop = FALSE
            ]
          }
        }
      }

      data_by_fill <- split(source_data, source_data[[fill_col]])

      lapply(names(data_by_fill), function(fill_name) {
        fill_data <- data_by_fill[[fill_name]]
        fill_data <- fill_data[order(fill_data[[x_col]]), ]

        lapply(seq_len(nrow(fill_data)), function(i) {
          list(
            x = as.character(fill_data[i, x_col]),
            y = fill_data[i, y_col],
            z = as.character(fill_data[i, fill_col])
          )
        })
      })
    },
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        panel_index <- which(
          grepl(paste0("^", panel_ctx$panel_name, "\\b"), gt$layout$name)
        )
      } else {
        panel_index <- which(gt$layout$name == "panel")
      }
      if (length(panel_index) == 0) {
        layer_id <- self$get_layer_index()
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        return(list(paste0("#", escaped_grob_id, " rect")))
      }

      panel_grob <- gt$grobs[[panel_index[1]]]

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

      if (length(rect_names) > 0) {
        grob_name <- rect_names[1]
        layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        selector_string <- paste0("#", escaped_grob_id, " rect")
      } else {
        layer_id <- self$get_layer_index()
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        selector_string <- paste0("#", escaped_grob_id, " rect")
      }

      list(selector_string)
    }
  )
)
