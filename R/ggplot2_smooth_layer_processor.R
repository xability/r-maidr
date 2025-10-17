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
      collect_all_polyline_grobs <- function(grob) {
        polyline_grobs <- list()

        if (!is.null(grob$name) && grepl("GRID\\.polyline", grob$name)) {
          polyline_grobs <- append(polyline_grobs, grob$name)
        }

        if ("children" %in% names(grob)) {
          for (child in grob$children) {
            child_grobs <- collect_all_polyline_grobs(child)
            polyline_grobs <- append(polyline_grobs, child_grobs)
          }
        }

        return(polyline_grobs)
      }

      if (!is.null(gt)) {
        all_polyline_grobs <- list()

        if ("grobs" %in% names(gt)) {
          for (grob in gt$grobs) {
            grob_results <- collect_all_polyline_grobs(grob)
            all_polyline_grobs <- append(all_polyline_grobs, grob_results)
          }
        }

        if (length(all_polyline_grobs) > 0) {
          # Extract the numeric IDs from all polyline grobs
          numeric_ids <- sapply(all_polyline_grobs, function(grob_name) {
            match_result <- regmatches(grob_name, regexpr("GRID\\.polyline\\.(\\d+)", grob_name))
            if (length(match_result) > 0) {
              as.numeric(gsub("GRID\\.polyline\\.", "", match_result))
            } else {
              0
            }
          })

          # Remove any NA or 0 values
          numeric_ids <- numeric_ids[numeric_ids > 0]

          if (length(numeric_ids) > 0) {
            # For geom_smooth, the actual fitted line is typically the LAST (highest numbered) polyline
            # This is because ggplot2 renders confidence interval first, then the fitted line
            target_id <- max(numeric_ids)
            grob_id <- paste0("GRID.polyline.", target_id, ".1.1")
            escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
            selector_string <- paste0("#", escaped_grob_id)
          } else {
            # Fallback to first found grob
            grob_id <- paste0(all_polyline_grobs[[1]], ".1")
            escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
            selector_string <- paste0("#", escaped_grob_id)
          }
        } else {
          # No polyline grobs found, use fallback
          selector_string <- "#GRID\\.polyline\\.1\\.1\\.1"
        }
      } else {
        selector_string <- "#GRID\\.polyline\\.1\\.1\\.1"
      }

      list(selector_string)
    }
  )
)
