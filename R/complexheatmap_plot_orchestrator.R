#' ComplexHeatmap Plot Orchestrator
#'
#' @description
#' Reads a 'ComplexHeatmap' heat map -- a `Heatmap`, or a `HeatmapList`
#' holding exactly one -- as one subplot holding one `heat` layer
#' ([ComplexHeatmapLayerProcessor]). Experimental.
#'
#' The object is drawn once, with `ComplexHeatmap::draw()`, and the drawing
#' is grabbed as a grid tree ([complexheatmap_capture()]). The SVG is that
#' tree, and the layer is read from the `HeatmapList` that same draw
#' returned, so the order of the rows and columns read is the order drawn
#' even where drawing decides it afresh -- `row_km`'s k-means, say, which an
#' undrawn `Heatmap` runs again on every draw. Pass what `draw()` returned
#' to read the very chart that was shown.
#'
#' Only the matrix is read. The dendrograms set the order the cells are read
#' in but are not read themselves, and neither are annotations or legends.
#' A list of more than one heat map, or a matrix that is not numeric (a
#' discrete heat map of categories), falls back to an image.
#'
#' @format An R6 class
#' @keywords internal
ComplexHeatmapPlotOrchestrator <- R6::R6Class(
  "ComplexHeatmapPlotOrchestrator",
  private = list(
    .plot = NULL,
    .capture = NULL,
    .layout = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .unsupported = character(0),
    .canvas = NULL
  ),
  public = list(
    #' @description Read a ComplexHeatmap object
    #' @param plot The `Heatmap` or `HeatmapList`
    #' @param width,height The size to draw the chart at, in inches, or `NULL`
    #'   for maidr's own; see [chart_canvas_size()]
    #' @param asked Whether that size was asked for, by default when either
    #'   side is given; see [chart_canvas_size()]
    initialize = function(plot, width = NULL, height = NULL,
                          asked = !is.null(width) || !is.null(height)) {
      private$.plot <- plot
      private$.canvas <- chart_canvas_size(width, height, asked = asked)

      count <- complexheatmap_count(plot)
      if (count != 1L) {
        private$.unsupported <- paste0(
          "it holds ", count, " heat maps, and only a single heat map is read"
        )
        return(invisible(self))
      }
      capture <- tryCatch(
        complexheatmap_capture(plot, private$.canvas),
        error = function(e) conditionMessage(e)
      )
      if (is.character(capture)) {
        private$.unsupported <- paste0("it could not be drawn (", capture, ")")
        return(invisible(self))
      }
      private$.capture <- capture
      if (!is.numeric(capture$heatmap@matrix) || length(capture$heatmap@matrix) == 0L) {
        private$.unsupported <- "its matrix is not a non-empty numeric matrix"
        return(invisible(self))
      }
      private$.layout <- self$extract_layout()

      layer_info <- list(index = 1L, type = "heat")
      private$.layers <- list(layer_info)
      processor <- get_global_registry()$get_processor_factory("complexheatmap")$create_processor(
        "heat", layer_info
      )
      private$.layer_processors <- list(processor)
      result <- processor$process(plot, private$.layout, gt = capture)
      processor$set_last_result(result)
      validate_axes(result$axes, context = "ComplexHeatmap orchestrator")

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

    #' @description Read the chart's title and its rows' title
    #'
    #' The title is the column title `draw()` was given for the whole list,
    #' else the heat map's own column title when it is one string; the rows'
    #' title likewise from the row titles. A title per slice of a split names
    #' no axis and is not read.
    #' @return List with `title` and `row_title`
    extract_layout = function() {
      drawn <- private$.capture$drawn
      heatmap <- private$.capture$heatmap
      list(
        title = complexheatmap_title(drawn@column_title, heatmap@column_title),
        row_title = complexheatmap_title(drawn@row_title, heatmap@row_title)
      )
    },

    #' @description Assemble the MAIDR data object for the figure
    #' @return List with an id, the subplot and the title
    generate_maidr_data = function() {
      if (length(private$.unsupported)) {
        stop(
          "This ComplexHeatmap chart cannot be read interactively: ",
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

    #' @description The grid tree drawn for the SVG, its cells renamed
    #' @return A gTree, or NULL when the chart could not be drawn
    get_gtable = function() {
      private$.capture$grob
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

#' The number of heat maps a ComplexHeatmap object holds
#'
#' Annotations added to a list with `+` are not heat maps and are not
#' counted; they are drawn, and not read.
#'
#' @param plot A `Heatmap` or `HeatmapList`
#' @return An integer
#' @keywords internal
complexheatmap_count <- function(plot) {
  if (inherits(plot, "Heatmap")) {
    return(1L)
  }
  sum(vapply(plot@ht_list, function(h) inherits(h, "Heatmap"), logical(1)))
}

#' A title that names the whole chart or axis, or ""
#' @param ... Candidate titles, in order of preference: character vectors,
#'   one string per slice
#' @return The first that is a single non-empty string, or ""
#' @keywords internal
complexheatmap_title <- function(...) {
  for (title in list(...)) {
    if (length(title) == 1L && !is.na(title) && nzchar(as.character(title))) {
      return(as.character(title))
    }
  }
  ""
}

#' Draw a ComplexHeatmap object once, and grab the drawing
#'
#' `ComplexHeatmap::draw()` draws on an off-screen device the size of the
#' canvas, and the drawing is grabbed with `grid::grid.grabExpr()`: a gTree
#' that redraws it, its viewports included, which [create_enhanced_svg()]
#' draws again for the SVG. The cells of the heat map body are then given
#' names the selectors can rely on ([complexheatmap_name_cells()]).
#'
#' @param plot A `Heatmap`, or a `HeatmapList` holding one
#' @param canvas The canvas size, from [chart_canvas_size()]
#' @return A list: `grob`, the gTree; `drawn`, the `HeatmapList` the draw
#'   returned; `heatmap`, the one `Heatmap` in it, with its row and column
#'   order as drawn; `cells`, the names given to the body's cells, by slice,
#'   or NULL when they cannot be selected
#' @keywords internal
complexheatmap_capture <- function(plot, canvas) {
  if (!requireNamespace("ComplexHeatmap", quietly = TRUE)) {
    stop("package 'ComplexHeatmap' is not installed", call. = FALSE)
  }
  drawn <- NULL
  grob <- grid::grid.grabExpr(
    drawn <- ComplexHeatmap::draw(plot),
    width = canvas[["width"]],
    height = canvas[["height"]]
  )
  is_heatmap <- vapply(drawn@ht_list, function(h) inherits(h, "Heatmap"), logical(1))
  heatmap <- drawn@ht_list[[which(is_heatmap)[1]]]
  named <- complexheatmap_name_cells(grob, heatmap)
  list(grob = named$grob, drawn = drawn, heatmap = heatmap, cells = named$cells)
}

#' Draw a ComplexHeatmap object on the current device, as printing it does
#' @param plot A `Heatmap` or `HeatmapList`
#' @return NULL (invisible)
#' @keywords internal
draw_complexheatmap_natively <- function(plot) {
  ComplexHeatmap::draw(plot)
  invisible(NULL)
}
