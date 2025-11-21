#' Histogram Layer Processor
#'
#' Processes histogram plot layers with complete logic included
#'
#' @keywords internal
Ggplot2HistogramLayerProcessor <- R6::R6Class(
  "Ggplot2HistogramLayerProcessor",
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
    extract_data = function(plot, built = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      histogram_layers <- built$data[sapply(built$data, function(layer_data) {
        all(c("x", "y", "xmin", "xmax", "ymin", "ymax") %in% names(layer_data))
      })]

      result <- lapply(histogram_layers, function(layer_data) {
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
      })

      unlist(result, recursive = FALSE)
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
          layer_id <- 1
          grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id, " rect")
        }
      }

      list(selector_string)
    }
  )
)
