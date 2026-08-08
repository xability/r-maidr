#' Histogram Layer Processor
#'
#' Processes histogram plot layers with complete logic included
#'
#' @keywords internal
Ggplot2HistogramLayerProcessor <- R6::R6Class(
  "Ggplot2HistogramLayerProcessor",
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
      data <- self$extract_data(plot, built, panel_id = panel_id)
      selectors <- self$generate_selectors(plot, gt, panel_ctx = panel_ctx)

      list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout)
      )
    },
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      # Use this processor's OWN layer: filtering built$data by column
      # shape would also swallow bins from other rect-shaped layers in
      # multi-layer plots.
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      required_cols <- c("x", "y", "xmin", "xmax", "ymin", "ymax")
      if (!all(required_cols %in% names(layer_data))) {
        return(list())
      }

      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        layer_data <- layer_data[layer_data$PANEL == panel_id, , drop = FALSE]
      }

      lapply(seq_len(nrow(layer_data)), function(i) {
        list(
          x = layer_data$x[i],
          y = layer_data$y[i],
          xMin = layer_data$xmin[i],
          xMax = layer_data$xmax[i],
          yMin = layer_data$ymin[i],
          yMax = layer_data$ymax[i]
        )
      })
    },
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      if (is.null(gt)) {
        return(list())
      }

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

      rect_grob <- NULL

      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        # Facet / patchwork path: scope the search to this panel's grob so
        # each subplot gets its own rect group
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (!is.null(panel_grob)) {
          rect_grob <- find_rect_grobs(panel_grob)
        }
      } else if ("grobs" %in% names(gt)) {
        for (grob in gt$grobs) {
          rect_grob <- find_rect_grobs(grob)
          if (!is.null(rect_grob)) break
        }
      }

      if (!is.null(rect_grob)) {
        layer_id <- gsub("geom_rect\\.rect\\.", "", rect_grob)
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
      } else {
        grob_id <- "geom_rect.rect.1.1"
      }
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
      selector_string <- paste0("#", escaped_grob_id, " rect")

      list(selector_string)
    }
  )
)
