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
        orientation = self$determine_orientation(plot, built),
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout)
      )
    },
    #' @description Which axis this histogram's bins run along
    #'
    #' `ggplot_build()` fills a flipped layer's `ymin`/`ymax` with the bin
    #' bounds and its `x` with the count, and `extract_data` above passes both
    #' through as they come -- so the emitted data is already transposed
    #' correctly. What was missing is this key saying so.
    #'
    #' Without it the frontend defaults to vertical and reads the bin range
    #' from `xMin`/`xMax`, which on a flipped layer hold the count bounds. A
    #' `geom_histogram()` drawn with `aes(y = v)` was announced with a bin
    #' range of "0 to 5" -- counts -- where the data runs -2.42 to -1.10, and
    #' with every bin centre offered as a value. Every number real, every one
    #' on the wrong axis, and nothing erroring (#163).
    #'
    #' Read from `flipped_aes`, which ggplot2 sets on the built layer, the way
    #' the boxplot and violin processors already do. `coord_flip()` is a
    #' different question and deliberately not answered here: it leaves
    #' `flipped_aes` alone and rotates only the coordinate system, so the data
    #' layout this key describes is genuinely unflipped. Treating it as
    #' horizontal would swap a pair that is already the right way round.
    #'
    #' @param plot The ggplot2 object.
    #' @param built Its `ggplot_build()` result, when the caller already has one.
    #' @return `"horz"` or `"vert"`.
    determine_orientation = function(plot, built = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      layer_index <- self$get_layer_index()
      if (layer_index > length(built$data)) {
        return("vert")
      }
      layer_data <- built$data[[layer_index]]
      if (isTRUE(layer_data$flipped_aes[1])) "horz" else "vert"
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

      # No rect grob means this layer drew no bins here: an empty facet
      # level, a zero-row layer, a coord that renders no rects. Every
      # `geom_rect.rect.N` id carries grid's session-wide grob counter, so
      # a guessed N is right only by coincidence - and when it does land it
      # lands on ANOTHER panel's bins, which highlights the wrong marks
      # while the payload still looks healthy. The caller can tell an empty
      # selector list apart from a wrong one, a user cannot; bar, point,
      # boxplot, line and heatmap already return list() here.
      if (is.null(rect_grob)) {
        return(list())
      }

      layer_id <- gsub("geom_rect\\.rect\\.", "", rect_grob)
      grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)

      list(paste0("#", escaped_grob_id, " rect"))
    }
  )
)
