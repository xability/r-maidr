#' The name the cells of one slice of a ComplexHeatmap body are exported under
#'
#' `ComplexHeatmap` draws the cells of each slice of the body -- one per
#' combination of row and column slice, `row_split`/`row_km` by
#' `column_split`/`column_km`, a single one without splits -- as one rect
#' grob with a generated name (`GRID.rect.<n>`). Each is renamed to this
#' prefix followed by `-<h>-<kr>-<kc>`: the heat map's place among the heat
#' maps of the list, and its row and column slice in drawn order, so each
#' cell is the SVG element `#maidr-complexheatmap-cells-<h>-<kr>-<kc>.1.<k>`.
#' The heat map's place, not its `name`, which may hold any character.
#'
#' @keywords internal
COMPLEXHEATMAP_CELLS_GROB <- "maidr-complexheatmap-cells"

#' Give the cells of a ComplexHeatmap body names the selectors can rely on
#'
#' `draw_heatmap_body()` pushes a viewport named
#' `<name>_heatmap_body_<kr>_<kc>` for each slice and draws its cells there
#' as one rect, column by column, each column top to bottom, at the middles
#' of an even grid. A slice's rect is renamed only when that is what it is:
#' one rect per cell of the slice, at exactly those places. When any slice
#' has none -- drawn as a raster image (`use_raster = TRUE`, which
#' 'ComplexHeatmap' chooses itself for more than 2000 rows or columns), or
#' with `rect_gp = gpar(type = "none")` -- no cell is named, and the chart
#' is read without highlighting.
#'
#' @param grob The gTree the drawing was grabbed as
#' @param heatmap The `Heatmap` drawn, its row and column order set
#' @param h The heat map's place among the heat maps of the list
#' @return A list: `grob`, with the cells renamed; `cells`, a list of the
#'   names given, `[[kr]][[kc]]`, or NULL when the cells cannot be selected
#' @keywords internal
complexheatmap_name_cells <- function(grob, heatmap, h = 1L) {
  rows <- heatmap@row_order_list
  cols <- heatmap@column_order_list
  kids <- grob$children[grob$childrenOrder]
  prefix <- paste0(heatmap@name, "_heatmap_body_")
  cells <- lapply(seq_along(rows), function(kr) vector("list", length(cols)))
  for (at in seq_along(kids)) {
    slice <- complexheatmap_body_slice(kids[[at]], prefix, lengths(rows), lengths(cols))
    if (is.null(slice) || !is.null(cells[[slice[1]]][[slice[2]]])) {
      next
    }
    name <- paste(COMPLEXHEATMAP_CELLS_GROB, h, slice[1], slice[2], sep = "-")
    kids[[at]]$name <- name
    cells[[slice[1]]][[slice[2]]] <- name
  }
  # Every slice named, or none: a cell that cannot be selected leaves a
  # grid the frontend would misalign.
  if (length(unlist(cells)) != length(rows) * length(cols)) {
    return(list(grob = grob, cells = NULL))
  }
  grob <- grid::setChildren(grob, do.call(grid::gList, unname(kids)))
  list(grob = grob, cells = cells)
}

#' The body slice a grob draws the cells of, if it does
#'
#' @param grob A child of the grabbed drawing
#' @param prefix The body viewports' name before `<kr>_<kc>`
#' @param nrows,ncols The number of rows in each row slice, and of columns
#'   in each column slice
#' @return `c(kr, kc)` when the grob is a rect in the body viewport of that
#'   slice, drawing its cells ([complexheatmap_rect_is_cells()]); else NULL
#' @keywords internal
complexheatmap_body_slice <- function(grob, prefix, nrows, ncols) {
  vp <- grob$vp
  if (!inherits(grob, "rect") || !inherits(vp, "vpPath") || !startsWith(vp$name, prefix)) {
    return(NULL)
  }
  suffix <- substring(vp$name, nchar(prefix) + 1L)
  slice <- as.integer(regmatches(suffix, regexec("^([0-9]+)_([0-9]+)$", suffix))[[1]][-1])
  if (length(slice) != 2L || slice[1] > length(nrows) || slice[2] > length(ncols)) {
    return(NULL)
  }
  if (!complexheatmap_rect_is_cells(grob, nrows[slice[1]], ncols[slice[2]])) {
    return(NULL)
  }
  slice
}

#' Whether a rect grob is the cells of an `nr` by `nc` slice
#'
#' One rect per cell, column by column and each column top to bottom: the
#' `k`-th at the middle of row `(k - 1) %% nr + 1` from the top and column
#' `(k - 1) %/% nr + 1` from the left, in npc of the slice's viewport.
#'
#' @param rect A rect grob
#' @param nr,nc The slice's number of rows and columns
#' @return TRUE when the rect draws exactly those cells, in that order
#' @keywords internal
complexheatmap_rect_is_cells <- function(rect, nr, nc) {
  n <- nr * nc
  sizes <- c(length(rect$x), length(rect$y), length(rect$gp$fill))
  if (n == 0L || any(sizes != n)) {
    return(FALSE)
  }
  k <- seq_len(n) - 1L
  at_middle <- function(position, expected) {
    all(grid::unitType(position) == "npc") &&
      isTRUE(all.equal(as.numeric(position), expected))
  }
  at_middle(rect$x, (k %/% nr + 0.5) / nc) && at_middle(rect$y, (nr - k %% nr - 0.5) / nr)
}

#' ComplexHeatmap Heatmap Layer Processor
#'
#' @description
#' Reads the `heat` layer of one ComplexHeatmap heat map from the
#' `HeatmapList` its drawing returned ([complexheatmap_capture()]): the one
#' heat map of a chart, or one of a list's.
#'
#' **Order.** The rows and columns are read in the order drawn, the heat
#' map's own row and column order in the drawn list: by the dendrograms
#' when clustered, by `row_order`/`column_order` when given, and in a list
#' by the order the list shares -- the main heat map's rows in a horizontal
#' list, its columns in a vertical one. Rows are top first, as maidr.js
#' reads `data.points`.
#'
#' **Splits.** A heat map split into slices (`row_split`, `row_km`,
#' `column_split`, `column_km`) is read as one grid, its slices put side by
#' side in the order drawn, top to bottom and left to right. The gaps
#' between slices are not cells, and are not read: moving past the last
#' row of one slice reaches the first row of the next.
#'
#' **Values.** Each cell is the value of the heat map's own matrix (the
#' `matrix` slot), exactly; a missing or infinite value is a hole (`null`).
#' A value the colour mapping clips is still its own value, not the end of
#' the scale.
#'
#' **Labels.** The row and column labels drawn (`row_labels`,
#' `column_labels`, which default to the matrix's dimnames); when the names
#' are not shown (`show_row_names = FALSE`), the matrix's dimnames; and for
#' an unnamed matrix, each row's or column's number in the matrix.
#'
#' **Selectors.** Each cell is selected by its own id, in a grid whose rows
#' run bottom first, as maidr.js's heat grid does. When the body was drawn
#' as a raster image there are no cells to select, and the layer is read
#' without highlighting; a message (class `maidr_complexheatmap_raster`)
#' says so.
#'
#' @keywords internal
ComplexHeatmapLayerProcessor <- R6::R6Class(
  "ComplexHeatmapLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param layout The layer's title and its rows' title
    #' @param built Unused
    #' @param gt The capture, from [complexheatmap_capture()], its `heatmap`
    #'   and `cells` those of the heat map read
    #' @param grob_id Unused
    #' @param panel_id Unused
    #' @param panel_ctx Unused
    #' @param layer_info Unused
    #' @return The layer
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      heatmap <- gt$heatmap
      row_title <- layout$row_title %||% ""
      list(
        type = "heat",
        data = self$extract_data(plot, gt),
        selectors = self$generate_selectors(plot, gt),
        title = layout$title %||% "",
        axes = build_axes(
          x = "Columns",
          y = if (nzchar(row_title)) row_title else "Rows",
          z = complexheatmap_legend_title(heatmap)
        )
      )
    },

    #' @description The cells' values and labels, rows top first
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param built The capture, from [complexheatmap_capture()]
    #' @return List with `x`, `y` and `points`
    extract_data = function(plot, built = NULL) {
      heatmap <- built$heatmap
      rows <- unlist(heatmap@row_order_list, use.names = FALSE)
      cols <- unlist(heatmap@column_order_list, use.names = FALSE)
      values <- heatmap@matrix[rows, cols, drop = FALSE]
      values <- matrix(as.double(values), length(rows), length(cols))
      values[!is.finite(values)] <- NA_real_
      list(
        x = as.list(self$labels(heatmap@column_names_param, colnames(heatmap@matrix), cols)),
        y = as.list(self$labels(heatmap@row_names_param, rownames(heatmap@matrix), rows)),
        points = lapply(seq_len(nrow(values)), function(i) as.list(values[i, ]))
      )
    },

    #' @description The labels of one axis, in drawn order
    #' @param param The heat map's `row_names_param` or `column_names_param`
    #' @param dimnames The matrix's names along the axis, or NULL
    #' @param order The rows or columns drawn, as indices into the matrix
    #' @return Character vector
    labels = function(param, dimnames, order) {
      drawn <- param$labels
      if (isTRUE(param$show) && length(drawn) >= max(order)) {
        return(as.character(drawn[order]))
      }
      if (length(dimnames) >= max(order)) {
        return(as.character(dimnames[order]))
      }
      as.character(order)
    },

    #' @description One selector per cell, rows bottom first
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param gt The capture, from [complexheatmap_capture()]
    #' @param grob_id Unused
    #' @param panel_ctx Unused
    #' @return A grid of selectors, `[row][column]`, or an empty list when
    #'   the cells cannot be selected
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      if (is.null(gt$cells)) {
        rlang::inform(
          paste(
            "maidr: this heat map's cells are drawn as one image",
            "(`use_raster = TRUE`), or not drawn, so they are read but not",
            "highlighted. Pass `use_raster = FALSE` to Heatmap() to highlight them."
          ),
          class = "maidr_complexheatmap_raster"
        )
        return(list())
      }
      heatmap <- gt$heatmap
      row_slices <- lengths(heatmap@row_order_list)
      col_slices <- lengths(heatmap@column_order_list)
      # Each drawn row and column: its slice, and its place within it.
      row_slice <- rep(seq_along(row_slices), row_slices)
      row_local <- sequence(row_slices)
      col_slice <- rep(seq_along(col_slices), col_slices)
      col_local <- sequence(col_slices)
      n <- length(row_slice)
      lapply(rev(seq_len(n)), function(r) {
        kr <- row_slice[r]
        lapply(seq_along(col_slice), function(c) {
          kc <- col_slice[c]
          lattice_shape_selector(
            gt$cells[[kr]][[kc]],
            (col_local[c] - 1L) * row_slices[kr] + row_local[r]
          )
        })
      })
    }
  )
)

#' What a ComplexHeatmap's values are called
#'
#' The title of its colour legend, which is the heat map's `name` unless
#' `heatmap_legend_param` gives one, or "value" when that is the name
#' 'ComplexHeatmap' made up (`matrix_<n>`).
#'
#' @param heatmap The `Heatmap`
#' @return A single string
#' @keywords internal
complexheatmap_legend_title <- function(heatmap) {
  title <- heatmap@matrix_legend_param$title %||% heatmap@name
  if (length(title) != 1L || is.na(title)) {
    return("value")
  }
  title <- as.character(title)
  made_up <- identical(title, heatmap@name) && grepl("^matrix_[0-9]+$", title)
  if (!nzchar(title) || made_up) "value" else title
}
