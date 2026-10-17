#' The names the annotation tracks of a pheatmap are exported under
#'
#' `pheatmap()` draws all the column annotation tracks as one rect grob and
#' all the row annotation tracks as another, each with a generated name.
#' They are renamed to these before drawing ([pheatmap_name_annotations()]),
#' so each cell of a track is the SVG element `#<name>.1.<k>`.
#'
#' @keywords internal
PHEATMAP_ANNOTATION_GROBS <- c(
  row = "maidr-pheatmap-row-annotation",
  col = "maidr-pheatmap-col-annotation"
)

#' What a pheatmap's row and column annotations are called in messages
#' @keywords internal
PHEATMAP_ANNOTATION_SIDES <- c(row = "row annotation", col = "column annotation")

#' Give the annotation tracks of a pheatmap names the selectors can rely on
#'
#' @param gt The gtable `pheatmap()` returned
#' @return The gtable, its `"row_annotation"` and `"col_annotation"` rect
#'   grobs named [PHEATMAP_ANNOTATION_GROBS]
#' @keywords internal
pheatmap_name_annotations <- function(gt) {
  for (side in names(PHEATMAP_ANNOTATION_GROBS)) {
    at <- match(paste0(side, "_annotation"), gt$layout$name)
    if (!is.na(at) && inherits(gt$grobs[[at]], "rect")) {
      gt$grobs[[at]]$name <- PHEATMAP_ANNOTATION_GROBS[[side]]
    }
  }
  gt
}

#' The categorical entries of a pheatmap's annotation legend
#'
#' `pheatmap()` draws the legend of its annotations as a run of grobs per
#' variable: its name, then for a categorical variable one rect grob of the
#' levels' colours and one text grob of their names, in the order of
#' `annotation_colors`; for a numeric one two rect grobs (a ramp of four
#' colours, `colorRampPalette(annotation_colors[[name]])(4)`, and its
#' frame) and the two ends of its range. Only the categorical entries say
#' exactly what a colour stands for; a numeric entry's ramp says which
#' colours its values were drawn from.
#'
#' @param legend The gtable's `"annotation_legend"` grob, or NULL
#' @return A named list, by variable: `list(colours, levels)` for a
#'   categorical variable, `list(ramp)` for a numeric one; empty when there
#'   is no legend or it is not laid out so
#' @keywords internal
pheatmap_annotation_legend <- function(legend) {
  if (is.null(legend) || is.null(legend$children)) {
    return(list())
  }
  kids <- unname(as.list(legend$children[legend$childrenOrder]))
  is_a <- function(i, class) i <= length(kids) && inherits(kids[[i]], class)
  out <- list()
  i <- 1L
  while (is_a(i, "text")) {
    name <- as.character(kids[[i]]$label)[1]
    entry <- NULL
    if (is_a(i + 1L, "rect") && is_a(i + 2L, "text")) {
      entry <- list(
        colours = pheatmap_colour_key(as.character(kids[[i + 1L]]$gp$fill)),
        levels = as.character(kids[[i + 2L]]$label)
      )
      i <- i + 3L
    } else if (is_a(i + 1L, "rect") && is_a(i + 2L, "rect") && is_a(i + 3L, "text")) {
      entry <- list(ramp = as.character(kids[[i + 1L]]$gp$fill))
      i <- i + 4L
    } else {
      break
    }
    # A variable annotating both rows and columns is drawn twice, from the
    # same colours.
    if (!name %in% names(out)) {
      out[name] <- list(entry)
    }
  }
  out
}

#' One annotation track from the values the caller passed
#'
#' The values are taken only when they are what the track was drawn from:
#' a missing value exactly where no colour was drawn, and for a categorical
#' variable each level in one colour. A numeric variable is drawn by
#' cutting its range into 100 bins coloured along
#' `colorRampPalette(annotation_colors[[name]])(100)`; its colours are
#' computed so, from the colours the caller gave or else from the legend's
#' ramp of four (pheatmap's own palettes have four, which the ramp then
#' repeats exactly), and must be the colours drawn. With neither, each bin
#' must be in one colour.
#'
#' @param values The variable's values, in drawn order
#' @param fill The colours the track was drawn in, in the same order
#' @param colours The variable's `annotation_colors` entry, or NULL
#' @param ramp The variable's ramp in the annotation legend, or NULL
#' @return `list(values, levels)` -- `levels` NULL for a numeric variable,
#'   and a categorical one's values the 1-based position of each in
#'   `levels` -- or NULL
#' @keywords internal
pheatmap_track_from_values <- function(values, fill, colours = NULL, ramp = NULL) {
  key <- pheatmap_colour_key(fill)
  if (length(values) != length(key) || !identical(is.na(values), is.na(key))) {
    return(NULL)
  }
  one_colour_each <- function(groups) {
    present <- !is.na(key)
    all(tapply(key[present], groups[present], function(k) length(unique(k))) == 1L)
  }
  if (is.character(values) || is.factor(values)) {
    levels <- if (!is.null(names(colours))) names(colours) else levels(as.factor(values))
    codes <- match(as.character(values), levels)
    if (any(is.na(codes) & !is.na(values)) || !one_colour_each(codes)) {
      return(NULL)
    }
    return(list(values = as.numeric(codes), levels = levels))
  }
  if (!is.numeric(values) || all(is.na(values))) {
    return(NULL)
  }
  bins <- tryCatch(as.integer(cut(values, breaks = 100)), error = function(e) NULL)
  if (is.null(bins)) {
    return(NULL)
  }
  palette <- if (length(colours) && !is.list(colours)) colours else ramp
  agrees <- if (length(palette)) {
    expected <- tryCatch(
      pheatmap_colour_key(grDevices::colorRampPalette(palette)(100)[bins]),
      error = function(e) NULL
    )
    identical(expected, key)
  } else {
    one_colour_each(bins)
  }
  if (!agrees) {
    return(NULL)
  }
  list(values = as.numeric(values), levels = NULL)
}

#' One categorical annotation track from the legend's colours
#'
#' Exact when each colour the legend draws stands for one level: every
#' colour of the track must be one of them, and no two levels share one.
#'
#' @param fill The colours the track was drawn in
#' @param entry The variable's entry of [pheatmap_annotation_legend()]
#' @return `list(values, levels)` as [pheatmap_track_from_values()], or NULL
#' @keywords internal
pheatmap_track_from_legend <- function(fill, entry) {
  colours <- entry$colours
  if (is.null(colours) || length(colours) != length(entry$levels) ||
    anyNA(colours) || anyDuplicated(colours)) {
    return(NULL)
  }
  key <- pheatmap_colour_key(fill)
  codes <- match(key, entry$colours)
  if (any(is.na(codes) & !is.na(key))) {
    return(NULL)
  }
  list(values = as.numeric(codes), levels = entry$levels)
}

#' Whether a pheatmap's annotation rects are one per value, in drawn order
#'
#' `pheatmap()` draws a side's tracks as one rect per value, variable by
#' variable: a column track's left to right, each variable one step
#' further from the matrix (up), a row track's top to bottom, each one
#' step further (left). Measured in a scratch viewport, every rect must be
#' where that puts it, so the `k`-th rect is the cell its selector names.
#'
#' @param grob The side's rect grob
#' @param count The number of rows or columns of the matrix
#' @param variables The number of tracks on the side
#' @param side `"row"` or `"col"`
#' @return TRUE or FALSE
#' @keywords internal
pheatmap_track_cells_placed <- function(grob, count, variables, side) {
  n <- count * variables
  current <- grDevices::dev.cur()
  grDevices::pdf(NULL)
  scratch <- grDevices::dev.cur()
  on.exit(
    {
      grDevices::dev.off(scratch)
      if (current > 1L && current %in% grDevices::dev.list()) {
        grDevices::dev.set(current)
      }
    },
    add = TRUE
  )
  grid::pushViewport(grid::viewport(
    width = grid::unit(4, "inches"),
    height = grid::unit(4, "inches")
  ))
  at <- tryCatch(
    list(
      x = grid::convertX(grob$x, "inches", valueOnly = TRUE),
      y = grid::convertY(grob$y, "inches", valueOnly = TRUE)
    ),
    error = function(e) NULL
  )
  if (is.null(at) || length(at$x) != n || length(at$y) != n || n == 0L) {
    return(FALSE)
  }
  along <- matrix(if (identical(side, "row")) -at$y else at$x, count, variables)
  across <- matrix(if (identical(side, "row")) -at$x else at$y, count, variables)
  steps <- function(m) if (nrow(m) > 1L) all(diff(m) > 0) else TRUE
  same <- apply(across, 2L, function(v) diff(range(v)) < 1e-9)
  steps(along) && all(same) && steps(t(across[1L, , drop = FALSE]))
}

#' The annotation tracks of one side of a pheatmap
#'
#' Each variable of `annotation_row` or `annotation_col` is drawn as a track
#' of cells along the matrix, one per row or column. The variables are read
#' in the order pheatmap draws them outward from the matrix -- the data
#' frame's first column next to it -- and each is named by its column name.
#'
#' **Values.** pheatmap matches the data frame's rows to the matrix by the
#' matrix's row or column names, and draws them in the trees' order. Each
#' track is, in order of preference:
#'
#' * the data frame [pheatmap()] kept with the chart
#'   (`"maidr_annotations"`), matched as pheatmap matches it -- exact for
#'   a numeric variable and a categorical one alike;
#' * for a categorical variable, the level each colour stands for in the
#'   annotation legend, when every colour of the legend is one level's --
#'   also exact.
#'
#' A numeric track drawn by `pheatmap::pheatmap()` directly, whose legend
#' only shows a ramp and the ends of its range, and a categorical one with
#' no legend (`annotation_legend = FALSE`) are not read, and a message
#' (class `maidr_pheatmap_annotations`) names them.
#'
#' With `kmeans_k` the rows are cluster centres, and pheatmap matches
#' `annotation_row` to their row names, the cluster numbers (the `1` of
#' `"Cluster: 1 Size: 12"`), not to the input's rows; so is it read. A data
#' frame of the input's rows matches no centre, and pheatmap stops before
#' drawing it.
#'
#' @param plot The pheatmap object
#' @param gt The gtable, its tracks named [PHEATMAP_ANNOTATION_GROBS]
#' @param side `"row"` or `"col"`
#' @return A list of tracks, in the data frame's column order (nearest the
#'   matrix first): `list(name, side, values, levels, cells)`, `levels`
#'   NULL for a numeric track, `cells` each cell's selector in drawn order,
#'   NULL when the drawn rects are not one per value in drawn order
#' @keywords internal
pheatmap_annotation_tracks <- function(plot, gt, side) {
  track_grob <- pheatmap_grob(gt, paste0(side, "_annotation"))
  fill <- track_grob$gp$fill
  if (!inherits(track_grob, "rect") || !is.matrix(fill) || ncol(fill) == 0L) {
    return(list())
  }
  noun <- PHEATMAP_ANNOTATION_SIDES[[side]]
  cells <- pheatmap_child(pheatmap_grob(gt, "matrix"), "rect")$gp$fill
  items <- if (identical(side, "row")) rownames(cells) else colnames(cells)
  count <- if (identical(side, "row")) nrow(cells) else ncol(cells)
  if (nrow(fill) != count) {
    return(list())
  }

  kept <- attr(plot, "maidr_annotations", exact = TRUE)
  data <- kept[[side]]
  legend <- pheatmap_annotation_legend(pheatmap_grob(gt, "annotation_legend"))
  names <- colnames(fill) %||% rep("", ncol(fill))
  placed <- pheatmap_track_cells_placed(track_grob, count, ncol(fill), side)
  tracks <- list()
  skipped <- character(0)
  for (j in seq_len(ncol(fill))) {
    track <- NULL
    if (is.data.frame(data) && !is.null(items) && names[j] %in% names(data)) {
      values <- data[items, , drop = FALSE][[names[j]]]
      track <- pheatmap_track_from_values(
        values, fill[, j], kept$colors[[names[j]]], legend[[names[j]]]$ramp
      )
    }
    if (is.null(track) && nzchar(names[j])) {
      track <- pheatmap_track_from_legend(fill[, j], legend[[names[j]]])
    }
    if (is.null(track)) {
      skipped <- c(skipped, names[j])
      next
    }
    cells <- if (placed) {
      vapply((j - 1L) * count + seq_len(count), function(k) {
        lattice_shape_selector(PHEATMAP_ANNOTATION_GROBS[[side]], k)
      }, character(1))
    }
    tracks[[length(tracks) + 1L]] <- c(
      list(name = names[j], side = side),
      track,
      list(cells = cells)
    )
  }
  if (length(skipped)) {
    rlang::inform(
      paste0(
        "maidr: this pheatmap's ", noun, if (length(skipped) > 1L) "s", " ",
        paste0("'", skipped, "'", collapse = ", "),
        " cannot be read exactly and ", if (length(skipped) > 1L) "are" else "is",
        " left out. Draw it with maidr::pheatmap() to read every track."
      ),
      class = "maidr_pheatmap_annotations"
    )
  }
  tracks
}

#' pheatmap Annotation Track Layer Processor
#'
#' @description
#' Reads one annotation track of a pheatmap -- one variable of
#' `annotation_row` or `annotation_col`, found by
#' [pheatmap_annotation_tracks()] -- as a layer of the heat layer's own
#' subplot, after it, named by the variable (`name`).
#'
#' **Shape.** Every track is one row of cells, one per column (a column
#' annotation) or per row (a row annotation) of the heat layer, in the
#' order the heat layer reads them, a row track's top first. Its `x`
#' labels are the heat layer's column or row labels, so switching layers
#' from a heat cell to a column track keeps the column.
#'
#' - A numeric track is a `heat` layer of one row: `y` the variable's
#'   name, `points` its values, exactly; a value with no colour drawn is a
#'   hole.
#' - A categorical track is a `step` layer of one series, one point per
#'   cell: `x` its label, `y` the level's place among the levels (the
#'   order of `annotation_colors`, or else the factor's), and `label` the
#'   level, which maidr.js announces in place of `y`. A missing value is
#'   `y: null` with no `label`. maidr.js's `heat` cell is a number only, so a
#'   level can be announced only by a trace that carries a name beside its
#'   number.
#'
#' The ComplexHeatmap reader emits its tracks in the same shape
#' (`ComplexHeatmapAnnotationLayerProcessor`, #392).
#'
#' **Selectors.** Each cell is the rect it is drawn as, in the grob named
#' [PHEATMAP_ANNOTATION_GROBS]: for `heat`, a one-row grid; for `step`, one
#' selector listing every cell, which match in drawn order. A track whose
#' rects are not one per value, placed in drawn order, has none.
#'
#' @keywords internal
PheatmapAnnotationLayerProcessor <- R6::R6Class(
  "PheatmapAnnotationLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The pheatmap object
    #' @param layout The figure's layout: its title
    #' @param built Unused
    #' @param gt Unused
    #' @param grob_id Unused
    #' @param panel_id Unused
    #' @param panel_ctx Unused
    #' @param layer_info Unused; the track is the processor's `layer_info`
    #' @return The layer
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      track <- self$layer_info$track
      along <- if (identical(track$side, "row")) "Rows" else "Columns"
      categorical <- !is.null(track$levels)
      layer <- list(
        type = if (categorical) "step" else "heat",
        name = track$name,
        data = self$extract_data(plot),
        title = layout$title %||% "",
        axes = if (categorical) {
          build_axes(x = along, y = track$name)
        } else {
          build_axes(x = along, y = "Annotation", z = track$name)
        }
      )
      selectors <- self$generate_selectors(plot)
      if (!is.null(selectors)) {
        layer$selectors <- selectors
      }
      layer
    },

    #' @description The track's cells, in the heat layer's order
    #' @param plot Unused
    #' @param built Unused
    #' @return For `heat`, a list with `x`, `y` and `points`; for `step`, a
    #'   list of one series of points
    extract_data = function(plot, built = NULL) {
      track <- self$layer_info$track
      labels <- as.character(unlist(self$layer_info$labels))
      if (is.null(track$levels)) {
        return(list(
          x = as.list(labels),
          y = list(track$name),
          points = list(as.list(track$values))
        ))
      }
      list(lapply(seq_along(labels), function(i) {
        code <- track$values[i]
        if (is.na(code)) {
          return(list(x = labels[i], y = NA_real_))
        }
        list(x = labels[i], y = code, label = track$levels[code])
      }))
    },

    #' @description The selectors of the track's cells
    #' @param plot Unused
    #' @param gt Unused
    #' @param grob_id Unused
    #' @param panel_ctx Unused
    #' @return For `heat`, a one-row grid; for `step`, a list of one
    #'   selector; NULL when the cells cannot be selected
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      ids <- self$layer_info$track$cells
      if (is.null(ids)) {
        return(NULL)
      }
      if (is.null(self$layer_info$track$levels)) list(as.list(ids)) else list(paste(ids, collapse = ", "))
    }
  )
)
