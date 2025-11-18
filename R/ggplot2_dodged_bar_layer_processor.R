#' Dodged Bar Layer Processor
#'
#' Processes dodged bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2DodgedBarLayerProcessor <- R6::R6Class("Ggplot2DodgedBarLayerProcessor",
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
      x_col <- y_col <- fill_col <- NULL
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
      if (is.null(x_col) || is.null(fill_col) ||
          !(x_col %in% names(data)) || !(fill_col %in% names(data))) {
        return(data)
      }
      x_ordered <- factor(data[[x_col]], levels = sort(unique(data[[x_col]])))
      fill_ordered <- factor(data[[fill_col]], levels = rev(sort(unique(data[[fill_col]]))))

      data[order(x_ordered, fill_ordered), , drop = FALSE]
    },
    extract_data = function(plot, built = NULL) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[1]]$mapping

      x_col <- y_col <- fill_col <- NULL

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

      if (is.null(x_col) || is.null(y_col) || is.null(fill_col)) {
        stop("Could not determine required aesthetic mappings")
      }

      data_by_fill <- split(plot$data, plot$data[[fill_col]])

      lapply(names(data_by_fill), function(fill_name) {
        fill_data <- data_by_fill[[fill_name]]
        fill_data <- fill_data[order(fill_data[[x_col]]), ]

        lapply(seq_len(nrow(fill_data)), function(i) {
          list(
            x = as.character(fill_data[i, x_col]),
            y = fill_data[i, y_col],
            fill = as.character(fill_data[i, fill_col])
          )
        })
      })
    },
    generate_selectors = function(plot, gt = NULL) {
      if (is.null(gt)) gt <- ggplot2::ggplotGrob(plot)

      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        layer_id <- self$get_layer_index()
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        return(list(paste0("#", escaped_grob_id, " rect")))
      }

      panel_grob <- gt$grobs[[panel_index]]

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
