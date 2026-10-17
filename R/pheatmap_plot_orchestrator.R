#' pheatmap Plot Orchestrator
#'
#' @description
#' Reads the object `pheatmap::pheatmap()` returns as a `heat` layer
#' ([PheatmapHeatmapLayerProcessor]) and, for each side with a drawn
#' dendrogram, a `tree` layer ([PheatmapTreeLayerProcessor]), and draws its
#' `gtable` for the SVG. Each variable of `annotation_col` and
#' `annotation_row` it can read exactly is a further layer of the heat
#' layer's subplot, after it -- the column tracks, then the row tracks, each
#' in its data frame's column order ([PheatmapAnnotationLayerProcessor],
#' [pheatmap_annotation_tracks()]). Experimental.
#'
#' **Grid.** Each layer is a subplot placed where pheatmap draws it: the row
#' tree left of the matrix, the column tree above it, and nothing in the
#' corner above the row tree -- `[[row tree, heat], [empty, column tree]]`,
#' as far as each side is drawn. The grid's rows run **bottom first**.
#' maidr.js does not measure this grid in the SVG -- it places a subplot
#' by its layer's first selector, which neither the heat layer's grid of
#' selectors nor the empty corner gives it -- so it orders it as written,
#' where the up arrow moves to the next row; written bottom first, up moves
#' from the matrix to the column tree above it, and the reader starts in
#' the bottom left subplot, the row tree.
#'
#' When the cells' values cannot be read -- not drawn with [pheatmap()],
#' which keeps them, and with no legend (`legend = FALSE`) or one labelled
#' with words, and no numbers printed in the cells -- the chart falls back
#' to an image rather than being read without them.
#'
#' @format An R6 class
#' @keywords internal
PheatmapPlotOrchestrator <- R6::R6Class(
  "PheatmapPlotOrchestrator",
  private = list(
    .plot = NULL,
    .gtable = NULL,
    .layout = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .unsupported = character(0),
    .canvas = NULL
  ),
  public = list(
    #' @description Read a pheatmap object
    #' @param plot The pheatmap object
    #' @param width,height The size to draw the chart at, in inches, or `NULL`
    #'   for maidr's own; see [chart_canvas_size()]
    #' @param asked Whether that size was asked for, by default when either
    #'   side is given; see [chart_canvas_size()]
    initialize = function(plot, width = NULL, height = NULL,
                          asked = !is.null(width) || !is.null(height)) {
      private$.plot <- plot
      private$.canvas <- chart_canvas_size(width, height, asked = asked)

      private$.gtable <- pheatmap_name_cells(plot$gtable)
      if (is.null(private$.gtable)) {
        private$.unsupported <- "it draws no matrix of cells"
        return(invisible(self))
      }
      private$.gtable <- pheatmap_name_annotations(private$.gtable)
      private$.layout <- self$extract_layout()

      factory <- get_global_registry()$get_processor_factory("pheatmap")
      layer_info <- list(index = 1L, type = "heat")
      private$.layers <- list(layer_info)
      processor <- factory$create_processor("heat", layer_info)
      private$.layer_processors <- list(processor)
      result <- processor$process(plot, private$.layout, gt = private$.gtable)
      processor$set_last_result(result)
      if (is.null(result)) {
        private$.unsupported <- paste(
          "the values of its cells cannot be read: it was not drawn with",
          "maidr::pheatmap(), prints no numbers in its cells and has no",
          "legend with numeric labels"
        )
        return(invisible(self))
      }
      validate_axes(result$axes, context = "pheatmap orchestrator")
      heat <- pheatmap_layer_object(result, 1L)

      trees <- list()
      for (side in c("row", "col")) {
        info <- list(index = length(private$.layers) + 1L, type = "tree", side = side)
        tree_processor <- factory$create_processor("tree", info)
        private$.gtable <- pheatmap_mark_tree(plot, private$.gtable, side)
        tree <- tree_processor$process(plot, private$.layout, gt = private$.gtable)
        tree_processor$set_last_result(tree)
        if (is.null(tree)) {
          next
        }
        validate_axes(tree$axes, context = "pheatmap orchestrator")
        private$.layers <- c(private$.layers, list(info))
        private$.layer_processors <- c(private$.layer_processors, list(tree_processor))
        trees[[side]] <- pheatmap_layer_object(tree, info$index)
      }

      tracks <- list()
      for (side in c("col", "row")) {
        labels <- if (side == "row") result$data$y else result$data$x
        for (track in pheatmap_annotation_tracks(plot, private$.gtable, side)) {
          info <- list(
            index = length(private$.layers) + 1L, type = "annotation",
            track = track, labels = labels
          )
          track_processor <- factory$create_processor("annotation", info)
          layer <- track_processor$process(plot, private$.layout)
          track_processor$set_last_result(layer)
          validate_axes(layer$axes, context = "pheatmap orchestrator")
          private$.layers <- c(private$.layers, list(info))
          private$.layer_processors <- c(private$.layer_processors, list(track_processor))
          tracks <- c(tracks, list(pheatmap_layer_object(layer, info$index)))
        }
      }

      grid <- pheatmap_subplot_grid(heat, trees$row, trees$col)
      # The heat layer is the last subplot of the bottom row; its tracks
      # follow it there.
      last <- length(grid[[1L]])
      grid[[1L]][[last]]$layers <- c(grid[[1L]][[last]]$layers, tracks)
      private$.combined_data <- grid
      invisible(self)
    },

    #' @description Read the chart's title
    #' @return List with `title`
    extract_layout = function() {
      main <- pheatmap_grob(private$.gtable, "main")
      title <- if (!is.null(main) && length(main$label)) as.character(main$label[[1]]) else ""
      list(title = title)
    },

    #' @description Assemble the MAIDR data object for the figure
    #' @return List with an id, the subplot and the title
    generate_maidr_data = function() {
      if (length(private$.unsupported)) {
        stop(
          "This pheatmap cannot be read interactively: ",
          paste(private$.unsupported, collapse = "; "), ".",
          call. = FALSE
        )
      }
      maidr_obj <- list(
        id = paste0("maidr-plot-", generate_unique_id()),
        subplots = private$.combined_data
      )
      if (nzchar(private$.layout$title)) {
        maidr_obj$title <- private$.layout$title
      }
      maidr_obj
    },

    #' @description The gtable drawn for the SVG, its cells renamed
    #' @return A gtable, or NULL
    get_gtable = function() {
      private$.gtable
    },

    #' @description The size the chart is drawn at
    #' @return A named numeric vector, `width` and `height`, in inches
    canvas_size = function() {
      private$.canvas
    },

    #' @description The figure-level layout
    #' @return List
    get_layout = function() {
      private$.layout
    },

    #' @description The subplot grid
    #' @return List of rows of subplots
    get_combined_data = function() {
      private$.combined_data
    },

    #' @description The processors created for the layers
    #' @return List
    get_layer_processors = function() {
      private$.layer_processors
    },

    #' @description The layers read
    #' @return List of layer descriptions
    get_layers = function() {
      private$.layers
    },

    #' @description Why the chart cannot be read, if it cannot
    #' @return Character vector, empty when it can be read
    unsupported_reasons = function() {
      private$.unsupported
    },

    #' @description Check if the chart holds anything that cannot be read
    #' @return Logical
    has_unsupported_layers = function() {
      length(private$.unsupported) > 0L
    },

    #' @description Determine if the chart should fall back to an image
    #' @return Logical
    should_fallback = function() {
      if (!is_fallback_enabled()) {
        return(FALSE)
      }
      self$has_unsupported_layers()
    }
  )
)

#' One layer of a pheatmap as the payload carries it
#' @param result A processor's result
#' @param index The layer's number
#' @return The layer; with no `selectors` when it has none, and a `name`
#'   when it has one
#' @keywords internal
pheatmap_layer_object <- function(result, index) {
  layer <- list(id = paste0("maidr-layer-", index))
  if (!is.null(result$selectors)) {
    layer$selectors <- result$selectors
  }
  c(layer, result[intersect(c("type", "name", "data", "title", "axes"), names(result))])
}

#' A pheatmap's subplot grid: each layer where it is drawn, rows bottom first
#'
#' See [PheatmapPlotOrchestrator] for why the rows run bottom first.
#'
#' @param heat The heat layer
#' @param row_tree,col_tree The tree layers, or NULL for a side with none
#' @return A list of rows of subplots
#' @keywords internal
pheatmap_subplot_grid <- function(heat, row_tree = NULL, col_tree = NULL) {
  subplot <- function(row, col, layer = NULL) {
    list(
      id = paste0("maidr-subplot-", row, "-", col),
      layers = if (is.null(layer)) list() else list(layer)
    )
  }
  bottom <- c(if (!is.null(row_tree)) list(row_tree), list(heat))
  grid <- list(lapply(seq_along(bottom), function(col) subplot(1L, col, bottom[[col]])))
  if (!is.null(col_tree)) {
    grid[[2L]] <- if (is.null(row_tree)) {
      list(subplot(2L, 1L, col_tree))
    } else {
      list(subplot(2L, 1L), subplot(2L, 2L, col_tree))
    }
  }
  grid
}

#' Draw a pheatmap on the current device, as `print()` on it does
#' @param plot The pheatmap object
#' @return NULL (invisible)
#' @keywords internal
draw_pheatmap_natively <- function(plot) {
  grid::grid.newpage()
  grid::grid.draw(plot$gtable)
  invisible(NULL)
}
