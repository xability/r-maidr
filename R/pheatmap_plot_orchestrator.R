#' pheatmap Plot Orchestrator
#'
#' @description
#' Reads the object `pheatmap::pheatmap()` returns as one subplot holding one
#' `heat` layer ([PheatmapHeatmapLayerProcessor]), and draws its `gtable`
#' for the SVG. Experimental.
#'
#' Only the matrix is read. The dendrograms set the order the cells are read
#' in but are not read themselves, and neither are annotation tracks.
#'
#' When the cells' values cannot be read -- no legend (`legend = FALSE`),
#' a legend labelled with words, and no numbers printed in the cells -- the
#' chart falls back to an image rather than being read without them.
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
      private$.layout <- self$extract_layout()

      layer_info <- list(index = 1L, type = "heat")
      private$.layers <- list(layer_info)
      processor <- get_global_registry()$get_processor_factory("pheatmap")$create_processor(
        "heat", layer_info
      )
      private$.layer_processors <- list(processor)
      result <- processor$process(plot, private$.layout, gt = private$.gtable)
      processor$set_last_result(result)
      if (is.null(result)) {
        private$.unsupported <- paste(
          "the values of its cells cannot be read: it prints no numbers",
          "in them and has no legend with numeric labels"
        )
        return(invisible(self))
      }
      validate_axes(result$axes, context = "pheatmap orchestrator")

      private$.combined_data <- list(list(list(
        id = "maidr-subplot-1-1",
        layers = list(list(
          id = "maidr-layer-1",
          selectors = result$selectors,
          type = result$type,
          data = result$data,
          title = result$title,
          axes = result$axes
        ))
      )))
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

#' Draw a pheatmap on the current device, as `print()` on it does
#' @param plot The pheatmap object
#' @return NULL (invisible)
#' @keywords internal
draw_pheatmap_natively <- function(plot) {
  grid::grid.newpage()
  grid::grid.draw(plot$gtable)
  invisible(NULL)
}
