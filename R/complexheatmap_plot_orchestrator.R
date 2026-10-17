#' ComplexHeatmap Plot Orchestrator
#'
#' @description
#' Reads a 'ComplexHeatmap' heat map -- a `Heatmap`, or a `HeatmapList`
#' holding one or more -- as one subplot per heat map, each holding one
#' `heat` layer ([ComplexHeatmapLayerProcessor]), and a subplot for the
#' `tree` layers of each side's dendrograms. Experimental.
#'
#' The object is drawn once, with `ComplexHeatmap::draw()`, and the drawing
#' is grabbed as a grid tree ([complexheatmap_capture()]). The SVG is that
#' tree, and the layer is read from the `HeatmapList` that same draw
#' returned, so the order of the rows and columns read is the order drawn
#' even where drawing decides it afresh -- `row_km`'s k-means, say, which an
#' undrawn `Heatmap` runs again on every draw. Pass what `draw()` returned
#' to read the very chart that was shown.
#'
#' **Lists.** A list of several heat maps (`ht1 + ht2`, `ht1 %v% ht2`) is
#' read heat map by heat map, each from its own matrix, labels and drawn
#' order -- which the drawing shares across the list, the rows of a
#' horizontal list and the columns of a vertical one -- into a subplot of
#' its own. A horizontal list's heat maps are one row of subplots, left to
#' right; a vertical list's one column of them, its rows written **bottom
#' first**, as
#' pheatmap's grid is ([PheatmapPlotOrchestrator]): a heat layer's
#' selectors are a grid, which maidr.js does not measure a subplot by, so
#' it orders the subplots as written, where Up moves to the next row. Each
#' heat map's title is its own column title, and the chart's the one
#' `draw()` was given for the whole list.
#'
#' **Trees.** Each dendrogram drawn is read as a `tree` layer
#' ([ComplexHeatmapTreeLayerProcessor]) in a subplot placed where it is
#' drawn ([complexheatmap_subplot_grid()]). In a list each heat map's own
#' drawn settings say which it draws: a horizontal list's shared rows have
#' one row tree, the main heat map's, beside the heat map that draws it,
#' and each heat map its own column tree; a vertical list the reverse.
#'
#' The matrices and dendrograms are read; annotations, between heat maps or
#' around them, and legends are not. A heat map whose matrix is not
#' numeric (a discrete heat map of categories) is left out of a list that
#' holds a numeric one, its dendrograms with it, with a message (class
#' `maidr_complexheatmap_skipped`) naming it; a chart with no numeric heat
#' map falls back to an image.
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
    .canvas = NULL,

    # Read the k-th heat map of the drawing as the n-th layer, in a subplot
    # of its own.
    read_heatmap = function(plot, k, n) {
      layer_info <- list(index = n, type = "heat")
      processor <- get_global_registry()$get_processor_factory("complexheatmap")$create_processor(
        "heat", layer_info
      )
      view <- private$.capture
      view$heatmap <- view$heatmaps[[k]]$heatmap
      view$cells <- view$heatmaps[[k]]$cells
      layout <- if (length(view$heatmaps) == 1L) private$.layout else self$heatmap_layout(k)
      result <- processor$process(plot, layout, gt = view)
      processor$set_last_result(result)
      validate_axes(result$axes, context = "ComplexHeatmap orchestrator")
      private$.layers[[n]] <- layer_info
      private$.layer_processors[[n]] <- processor
      list(layers = list(list(
        id = paste0("maidr-layer-", n),
        selectors = result$selectors,
        type = result$type,
        data = result$data,
        title = result$title,
        axes = result$axes
      )))
    }
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
      if (count == 0L) {
        private$.unsupported <- "it holds no heat map"
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
      heatmaps <- capture$heatmaps
      numeric <- vapply(heatmaps, function(h) complexheatmap_is_numeric(h$heatmap), logical(1))
      if (!any(numeric)) {
        private$.unsupported <- if (count == 1L) {
          "its matrix is not a non-empty numeric matrix"
        } else {
          paste0("none of its ", count, " heat maps is a non-empty numeric matrix")
        }
        return(invisible(self))
      }
      complexheatmap_inform_skipped(heatmaps[!numeric])
      private$.layout <- self$extract_layout()

      subplots <- list()
      for (k in which(numeric)) {
        subplots[[length(subplots) + 1L]] <- private$read_heatmap(plot, k, length(subplots) + 1L)
      }
      trees <- lapply(which(numeric), self$read_trees)
      private$.combined_data <- complexheatmap_subplot_grid(
        subplots, capture$drawn@direction, trees
      )
      invisible(self)
    },

    #' @description Read the dendrograms one heat map of the drawing draws
    #'
    #' Each side's dendrograms are read by a
    #' [ComplexHeatmapTreeLayerProcessor], as the layers after every heat
    #' layer. Each heat map's own drawn settings say what it draws: in a
    #' horizontal list only the heat map that draws the shared row
    #' dendrogram -- the main one -- has a row tree, and in a vertical list
    #' only that one has a column tree.
    #' @param k The heat map's place among the drawing's heat maps
    #' @return A list: `row` and `column`, the tree layers of each side,
    #'   possibly none, and `row_side` and `column_side`, where each side's
    #'   are drawn
    read_trees = function(k) {
      factory <- get_global_registry()$get_processor_factory("complexheatmap")
      view <- private$.capture
      view$heatmap <- view$heatmaps[[k]]$heatmap
      view$cells <- view$heatmaps[[k]]$cells
      out <- list(row = list(), column = list(), row_side = "left", column_side = "top")
      for (side in c("row", "column")) {
        info <- list(index = length(private$.layers) + 1L, type = "tree", side = side)
        processor <- factory$create_processor("tree", info)
        layers <- processor$process(private$.plot, private$.layout, gt = view)
        processor$set_last_result(layers)
        if (!length(layers)) {
          next
        }
        out[[paste0(side, "_side")]] <- processor$drawn_side(view)
        private$.layer_processors <- c(private$.layer_processors, list(processor))
        for (layer in layers) {
          validate_axes(layer$axes, context = "ComplexHeatmap orchestrator")
          info <- list(index = length(private$.layers) + 1L, type = "tree", side = side)
          private$.layers <- c(private$.layers, list(info))
          out[[side]] <- c(out[[side]], list(pheatmap_layer_object(layer, info$index)))
        }
      }
      out
    },

    #' @description Read the chart's title and its rows' title
    #'
    #' The title is the column title `draw()` was given for the whole list,
    #' else, for a single heat map, its own column title when it is one
    #' string; the rows' title likewise from the row titles. A title per
    #' slice of a split names no axis and is not read.
    #' @return List with `title` and `row_title`
    extract_layout = function() {
      drawn <- private$.capture$drawn
      if (length(private$.capture$heatmaps) > 1L) {
        return(list(
          title = complexheatmap_title(drawn@column_title),
          row_title = complexheatmap_title(drawn@row_title)
        ))
      }
      heatmap <- private$.capture$heatmap
      list(
        title = complexheatmap_title(drawn@column_title, heatmap@column_title),
        row_title = complexheatmap_title(drawn@row_title, heatmap@row_title)
      )
    },

    #' @description The title and rows' title of one heat map of a list
    #'
    #' Its own column title, and the rows' title `draw()` was given, else its
    #' own row title, else, in a horizontal list, whose rows are shared, the
    #' main heat map's: the one row title 'ComplexHeatmap' draws for them.
    #' @param k The heat map's place among the list's heat maps
    #' @return List with `title` and `row_title`
    heatmap_layout = function(k) {
      drawn <- private$.capture$drawn
      heatmap <- private$.capture$heatmaps[[k]]$heatmap
      main <- drawn@ht_list[[drawn@ht_list_param$main_heatmap]]
      shared <- if (identical(drawn@direction, "horizontal") && inherits(main, "Heatmap")) {
        main@row_title
      }
      list(
        title = complexheatmap_title(heatmap@column_title),
        row_title = complexheatmap_title(drawn@row_title, heatmap@row_title, shared)
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

#' The subplot grid of a ComplexHeatmap chart: its heat maps and their trees
#'
#' One subplot per heat map read, in drawn order -- a horizontal list left
#' to right, a vertical list top to bottom -- and one for each side's
#' trees, where they are drawn: a row tree beside its heat map, left or
#' right, a column tree above or below it, a side's trees (one per slice
#' when the slices are not clustered) as layers of one subplot. Every
#' other place on the grid is an empty subplot, and a row or column of the
#' grid with nothing in it is left out. The rows are written bottom first;
#' see [ComplexHeatmapPlotOrchestrator] for why.
#'
#' A single heat map with both trees is
#' `[[row tree, heat], [empty, column tree]]`, as a pheatmap's grid is.
#'
#' @param subplots The heat maps' subplots, in drawn order
#' @param direction The drawn list's `direction`, `"horizontal"` or
#'   `"vertical"`
#' @param trees For each heat map, what [ComplexHeatmapPlotOrchestrator]'s
#'   `read_trees()` gives, or NULL for none
#' @return A list of rows of subplots, each given its id
#' @keywords internal
complexheatmap_subplot_grid <- function(subplots, direction, trees = NULL) {
  vertical <- identical(direction, "vertical")
  # Each subplot at a place on the grid as drawn, top first: along the list
  # a heat map, its trees across the list before or after it on their own
  # line, `1` before the heat maps' line `2` and `3` after it.
  cells <- list()
  at <- 0L
  put <- function(along, across, subplot) {
    cells[[length(cells) + 1L]] <<- if (vertical) {
      list(row = along, col = across, subplot = subplot)
    } else {
      list(row = across, col = along, subplot = subplot)
    }
  }
  for (k in seq_along(subplots)) {
    tree <- trees[[k]] %||% list()
    # Along the list, a heat map's own trees take a place of their own:
    # a horizontal list's row trees, a vertical one's column trees.
    beside <- if (vertical) "column" else "row"
    across <- if (vertical) "row" else "column"
    first <- if (vertical) "top" else "left"
    before <- length(tree[[beside]]) && identical(tree[[paste0(beside, "_side")]], first)
    if (before) {
      at <- at + 1L
      put(at, 2L, list(layers = tree[[beside]]))
    }
    at <- at + 1L
    put(at, 2L, subplots[[k]])
    if (length(tree[[across]])) {
      side <- tree[[paste0(across, "_side")]]
      put(at, if (side %in% c("top", "left")) 1L else 3L, list(layers = tree[[across]]))
    }
    if (length(tree[[beside]]) && !before) {
      at <- at + 1L
      put(at, 2L, list(layers = tree[[beside]]))
    }
  }
  rows <- sort(unique(vapply(cells, `[[`, 0L, "row")))
  cols <- sort(unique(vapply(cells, `[[`, 0L, "col")))
  grid <- lapply(rows, function(r) lapply(cols, function(c) list(layers = list())))
  for (cell in cells) {
    grid[[match(cell$row, rows)]][[match(cell$col, cols)]] <- cell$subplot
  }
  grid <- rev(grid)
  lapply(seq_along(grid), function(r) {
    lapply(seq_along(grid[[r]]), function(c) {
      c(list(id = paste0("maidr-subplot-", r, "-", c)), grid[[r]][[c]])
    })
  })
}

#' Whether a ComplexHeatmap heat map is read: a non-empty numeric matrix
#' @param heatmap A `Heatmap`
#' @return Logical
#' @keywords internal
complexheatmap_is_numeric <- function(heatmap) {
  is.numeric(heatmap@matrix) && length(heatmap@matrix) > 0L
}

#' Say which heat maps of a list are drawn and not read
#'
#' A message of class `maidr_complexheatmap_skipped` naming them, or none.
#'
#' @param heatmaps The skipped entries of a capture's `heatmaps`
#' @return NULL (invisible)
#' @keywords internal
complexheatmap_inform_skipped <- function(heatmaps) {
  if (length(heatmaps) == 0L) {
    return(invisible(NULL))
  }
  names <- paste0("'", vapply(heatmaps, function(h) h$heatmap@name, character(1)), "'")
  one <- length(names) == 1L
  if (!one) {
    names <- paste(paste(names[-length(names)], collapse = ", "), "and", names[length(names)])
  }
  rlang::inform(
    paste0(
      "maidr: ", names, if (one) " is a heat map" else " are heat maps",
      " of categories, not numbers, and ", if (one) "is" else "are", " drawn but not read."
    ),
    class = "maidr_complexheatmap_skipped"
  )
  invisible(NULL)
}

#' Draw a ComplexHeatmap object once, and grab the drawing
#'
#' `ComplexHeatmap::draw()` draws on an off-screen device the size of the
#' canvas, and the drawing is grabbed with `grid::grid.grabExpr()`: a gTree
#' that redraws it, its viewports included, which [create_enhanced_svg()]
#' draws again for the SVG. The cells of each heat map's body are then
#' given names the selectors can rely on ([complexheatmap_name_cells()]).
#'
#' @param plot A `Heatmap` or `HeatmapList`
#' @param canvas The canvas size, from [chart_canvas_size()]
#' @return A list: `grob`, the gTree; `drawn`, the `HeatmapList` the draw
#'   returned; `heatmaps`, one entry per `Heatmap` in it, in drawn order,
#'   each a list of `heatmap`, with its row and column order as drawn, and
#'   `cells`, the names given to its body's cells, by slice, or NULL when
#'   they cannot be selected; and `heatmap` and `cells`, those of the first
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
  heatmaps <- list()
  for (heatmap in drawn@ht_list[is_heatmap]) {
    k <- length(heatmaps) + 1L
    named <- complexheatmap_name_cells(grob, heatmap, k)
    grob <- named$grob
    heatmaps[[k]] <- list(heatmap = heatmap, cells = named$cells)
  }
  list(
    grob = grob, drawn = drawn, heatmaps = heatmaps,
    heatmap = heatmaps[[1]]$heatmap, cells = heatmaps[[1]]$cells
  )
}

#' Draw a ComplexHeatmap object on the current device, as printing it does
#' @param plot A `Heatmap` or `HeatmapList`
#' @return NULL (invisible)
#' @keywords internal
draw_complexheatmap_natively <- function(plot) {
  ComplexHeatmap::draw(plot)
  invisible(NULL)
}
