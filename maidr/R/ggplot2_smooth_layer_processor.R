#' Smooth Layer Processor
#'
#' Processes smooth plot layers with complete logic included
#'
#' @keywords internal
Ggplot2SmoothLayerProcessor <- R6::R6Class("Ggplot2SmoothLayerProcessor",
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
    extract_data = function(plot, built = NULL) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      smooth_layers <- which(sapply(plot$layers, function(layer) {
        inherits(layer$geom, "GeomSmooth") ||
          inherits(layer$geom, "GeomLine") ||
          inherits(layer$geom, "GeomDensity")
      }))

      if (length(smooth_layers) == 0) {
        stop("No smooth curve layers found in plot")
      }

      built_data <- built$data[[smooth_layers[1]]]

      data_points <- lapply(seq_len(nrow(built_data)), function(i) {
        list(
          x = built_data$x[i],
          y = built_data$y[i]
        )
      })

      list(data_points)
    },
    generate_selectors = function(plot, gt = NULL) {
      find_polyline_grobs <- function(grob) {
        if (!is.null(grob$name) && grepl("GRID\\.polyline", grob$name)) {
          return(grob$name)
        }

        if ("children" %in% names(grob)) {
          for (child in grob$children) {
            result <- find_polyline_grobs(child)
            if (!is.null(result)) {
              return(result)
            }
          }
        }
        NULL
      }

      if (!is.null(gt)) {
        polyline_grob <- NULL

        if ("grobs" %in% names(gt)) {
          for (grob in gt$grobs) {
            polyline_grob <- find_polyline_grobs(grob)
            if (!is.null(polyline_grob)) break
          }
        }

        if (!is.null(polyline_grob)) {
          layer_id <- gsub("GRID\\.polyline\\.", "", polyline_grob)
          grob_id <- paste0("GRID.polyline.", layer_id, ".1.1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id)
        } else {
          layer_id <- 1
          grob_id <- paste0("GRID.polyline.", layer_id, ".1.1")
          escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
          selector_string <- paste0("#", escaped_grob_id)
        }
      }

      list(selector_string)
    }
  )
)
