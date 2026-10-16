#' The name the drawn cells of a pheatmap are exported under
#'
#' `pheatmap()` draws its cells as one rect grob with a generated name
#' (`GRID.rect.<n>`), which changes from one session to the next. It is
#' renamed to this before drawing ([pheatmap_name_cells()]), so each cell
#' is the SVG element `#maidr-pheatmap-cells.1.<k>`.
#'
#' @keywords internal
PHEATMAP_CELLS_GROB <- "maidr-pheatmap-cells"

#' What a pheatmap layer's title says of values that are not exact
#'
#' By where the values were read from; see [PheatmapHeatmapLayerProcessor].
#' A matrix kept by [pheatmap()] is exact and says nothing.
#'
#' @keywords internal
PHEATMAP_VALUE_NOTES <- list(
  printed = "values as printed in the cells, rounded",
  legend = "approximate values, read from the colour legend to within one colour band"
)

#' A grob of a pheatmap's gtable, by its layout name
#'
#' @param gt The gtable `pheatmap()` returned
#' @param name The layout name: `"matrix"`, `"row_names"`, `"col_names"`,
#'   `"legend"`, `"main"`, ...
#' @return The grob, or NULL when the chart has none of that name
#' @keywords internal
pheatmap_grob <- function(gt, name) {
  at <- match(name, gt$layout$name)
  if (is.na(at)) NULL else gt$grobs[[at]]
}

#' The first child of a gTree that is a grob of a class
#' @param tree A gTree, or NULL
#' @param class The grob class, `"rect"` or `"text"`
#' @return The child, or NULL
#' @keywords internal
pheatmap_child <- function(tree, class) {
  if (is.null(tree) || is.null(tree$children)) {
    return(NULL)
  }
  for (child in tree$children) {
    if (inherits(child, class)) {
      return(child)
    }
  }
  NULL
}

#' Give the cells of a pheatmap a name the selectors can rely on
#'
#' @param gt The gtable `pheatmap()` returned
#' @return The gtable with its cell rect grob named [PHEATMAP_CELLS_GROB],
#'   or NULL when it has no matrix of cells
#' @keywords internal
pheatmap_name_cells <- function(gt) {
  at <- match("matrix", gt$layout$name)
  if (is.na(at)) {
    return(NULL)
  }
  matrix_grob <- gt$grobs[[at]]
  kids <- matrix_grob$children
  is_rect <- vapply(kids, function(k) inherits(k, "rect"), logical(1))
  if (!any(is_rect)) {
    return(NULL)
  }
  first <- which(is_rect)[1]
  kids[[first]]$name <- PHEATMAP_CELLS_GROB
  gt$grobs[[at]] <- grid::setChildren(matrix_grob, do.call(grid::gList, unname(as.list(kids))))
  gt
}

#' Measure positions pheatmap gives in units of its legend's height
#'
#' `pheatmap`'s legend places its colour bands and labels at
#' `h * p + (1npc - h)`, `h` being `min(1npc, 150bigpts)` and `p` a
#' position from 0 at the lowest break to 1 at the highest. Measured in a
#' viewport one inch high, `h` is one inch and each unit is `p` itself.
#'
#' @param units A list of grid units
#' @return A list of numeric vectors, one per unit
#' @keywords internal
pheatmap_legend_positions <- function(units) {
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
    width = grid::unit(1, "inches"),
    height = grid::unit(1, "inches")
  ))
  lapply(units, function(u) grid::convertY(u, "inches", valueOnly = TRUE))
}

#' The value range each colour of a pheatmap's legend stands for
#'
#' The legend draws one band per colour, from break to break, and labels
#' some breaks with their values (`grid.pretty()` of the range, or the
#' caller's numeric `legend_breaks`). Two labelled values fix the scale;
#' every band's breaks follow from where it is drawn. A colour drawn in more
#' than one band stands for the whole span of them.
#'
#' @param legend The gtable's `"legend"` grob, or NULL
#' @return A data frame with `colour` (normalised `#RRGGBBAA`), `lo` and
#'   `hi`, or NULL when the legend is missing or its labels are not numbers
#'   that agree with where they are drawn
#' @keywords internal
pheatmap_legend_bands <- function(legend) {
  rect <- pheatmap_child(legend, "rect")
  text <- pheatmap_child(legend, "text")
  if (is.null(rect) || is.null(text)) {
    return(NULL)
  }
  values <- suppressWarnings(as.numeric(as.character(text$label)))
  measured <- tryCatch(
    pheatmap_legend_positions(list(text$y, rect$y, rect$height)),
    error = function(e) NULL
  )
  if (is.null(measured)) {
    return(NULL)
  }
  positions <- rep_len(measured[[1]], length(values))
  keep <- is.finite(values) & is.finite(positions)
  values <- values[keep]
  positions <- positions[keep]
  if (length(unique(positions)) < 2L) {
    return(NULL)
  }
  low <- which.min(positions)
  high <- which.max(positions)
  span <- (values[high] - values[low]) / (positions[high] - positions[low])
  origin <- values[low] - positions[low] * span
  # Labels that are not the values at their places -- `legend_labels`
  # naming the breaks with other numbers -- say nothing about the scale.
  tolerance <- 1e-6 * max(abs(c(values, span)), 1)
  if (!is.finite(span) || span <= 0 ||
    any(abs(origin + positions * span - values) > tolerance)) {
    return(NULL)
  }

  # One band per rect. The fill can hold one colour more than there are
  # bands -- pheatmap drops the colours of the infinite end breaks by a
  # subscript one longer than the colours -- and grid recycles it to the
  # rects, so only the first colour per band is drawn.
  n <- length(measured[[2]])
  fill <- rep_len(as.character(rect$gp$fill), n)
  bottoms <- measured[[2]]
  heights <- rep_len(measured[[3]], n)
  if (n == 0L || any(!is.finite(c(bottoms, heights)))) {
    return(NULL)
  }
  colours <- pheatmap_colour_key(fill)
  lo <- origin + bottoms * span
  hi <- origin + (bottoms + heights) * span
  keys <- unique(colours)
  data.frame(
    colour = keys,
    lo = vapply(keys, function(k) min(lo[colours == k]), numeric(1)),
    hi = vapply(keys, function(k) max(hi[colours == k]), numeric(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' Colours in one spelling, so a cell's fill can be found in the legend
#' @param colours Character vector of R colours
#' @return Character vector of `#RRGGBBAA`, NA for a missing colour
#' @keywords internal
pheatmap_colour_key <- function(colours) {
  out <- rep(NA_character_, length(colours))
  ok <- !is.na(colours)
  if (any(ok)) {
    rgba <- grDevices::col2rgb(colours[ok], alpha = TRUE)
    out[ok] <- grDevices::rgb(rgba[1, ], rgba[2, ], rgba[3, ], rgba[4, ], maxColorValue = 255)
  }
  out
}

#' Read the numbers a pheatmap printed in its cells
#'
#' With `display_numbers = TRUE` each cell carries its value as drawn,
#' formatted by `number_format` (`"%.2f"`). A matrix the caller passed as
#' `display_numbers` may print anything -- significance stars, say -- and is
#' only taken when every label is a number or `NA`.
#'
#' @param text The matrix's text grob, or NULL
#' @param n,m The number of rows and columns of cells
#' @return An `n` by `m` numeric matrix, or NULL
#' @keywords internal
pheatmap_printed_numbers <- function(text, n, m) {
  if (is.null(text)) {
    return(NULL)
  }
  labels <- trimws(as.character(text$label))
  if (length(labels) != n * m) {
    return(NULL)
  }
  values <- suppressWarnings(as.numeric(labels))
  missing <- is.na(labels) | labels %in% c("", "NA", "NaN")
  if (any(is.na(values) & !missing)) {
    return(NULL)
  }
  values[missing] <- NA_real_
  decimals <- nchar(sub("^[^.]*\\.?", "", sub("[eE].*$", "", labels[!missing])))
  structure(
    matrix(values, n, m),
    precision = 0.5 * 10^-max(c(0L, decimals))
  )
}

#' Whether values agree with the colours their cells were drawn in
#'
#' Each value must lie in the legend band of its cell's colour, give or take
#' `tolerance`; a value beyond the outermost breaks is drawn in the end
#' colour, so those two bands are open-ended. This is how a matrix kept
#' with the chart, or numbers printed in its cells, are known to be the
#' values the colours were drawn from -- and not, say, p-values a caller
#' printed over them.
#'
#' @param values A numeric matrix, the shape of `fill`
#' @param fill The cells' fill colours
#' @param bands The legend's bands, from [pheatmap_legend_bands()]
#' @param tolerance How far outside its band a value may lie
#' @return TRUE when every finite value agrees
#' @keywords internal
pheatmap_values_agree <- function(values, fill, bands, tolerance) {
  at <- match(pheatmap_colour_key(as.vector(fill)), bands$colour)
  v <- as.vector(values)
  check <- is.finite(v)
  if (any(is.na(at[check]))) {
    return(FALSE)
  }
  lo <- bands$lo[at[check]]
  hi <- bands$hi[at[check]]
  lo[lo <= min(bands$lo)] <- -Inf
  hi[hi >= max(bands$hi)] <- Inf
  all(v[check] >= lo - tolerance & v[check] <= hi + tolerance)
}

#' Whether a matrix kept with a pheatmap is the one its cells were drawn from
#' @param values The `"maidr_matrix"` attribute, or NULL
#' @param fill The cells' fill colours
#' @return TRUE when it has the cells' shape and names
#' @keywords internal
pheatmap_matrix_fits <- function(values, fill) {
  is.matrix(values) && is.numeric(values) && identical(dim(values), dim(fill)) &&
    (is.null(rownames(fill)) || identical(rownames(values), rownames(fill))) &&
    (is.null(colnames(fill)) || identical(colnames(values), colnames(fill)))
}

#' The labels of one axis of a pheatmap, in drawn order
#'
#' The drawn labels when the axis shows them (`labels_row`, the k-means
#' clusters' names); else the matrix's dimnames; else, as for an unnamed
#' matrix, each row's or column's number in the input, in tree order. The
#' heat layer names its rows and columns by these, and a dendrogram its
#' leaves.
#'
#' @param gt The gtable
#' @param name `"row_names"` or `"col_names"`
#' @param dimnames The fill matrix's names along the axis
#' @param tree The axis' `hclust`, or NA when it was not clustered
#' @param count The number of rows or columns drawn
#' @return Character vector
#' @keywords internal
pheatmap_axis_labels <- function(gt, name, dimnames, tree, count) {
  drawn <- pheatmap_grob(gt, name)
  if (!is.null(drawn) && length(drawn$label) == count) {
    return(as.character(drawn$label))
  }
  if (length(dimnames) == count) {
    return(as.character(dimnames))
  }
  if (inherits(tree, "hclust") && length(tree$order) == count) {
    return(as.character(tree$order))
  }
  as.character(seq_len(count))
}

#' pheatmap Heatmap Layer Processor
#'
#' @description
#' Reads the one `heat` layer of a pheatmap from its drawn gtable.
#'
#' **Order.** `pheatmap()` reorders the matrix by its trees
#' (`tree_row$order`, `tree_col$order`) before drawing, and the gtable holds
#' it in that order: the cells' fill matrix, the row and column labels. Its
#' rows are top first, as maidr.js reads `data.points`.
#'
#' **Values.** Each cell's value is, in order of preference:
#'
#' * exact: the matrix [pheatmap()] -- maidr's wrapper -- kept with the
#'   chart (`"maidr_matrix"`), the matrix as drawn;
#' * otherwise the number printed in the cell, with `display_numbers`;
#' * otherwise the middle of the legend band the cell's colour stands for,
#'   rounded to the band's width -- with the default 100 colours, to a
#'   hundredth of the range drawn.
#'
#' `pheatmap::pheatmap()` itself does not return its matrix, so a chart it
#' drew directly has only the last two. Neither is exact, and the layer's
#' title says which was used, as does a message (class
#' `maidr_pheatmap_values`). A kept matrix or printed numbers are used only
#' when each value lies in the legend band of its cell's colour, so numbers
#' printed over the cells that are not their values -- p-values, say -- are
#' not read as them.
#'
#' Every source is the matrix as drawn, so with `scale = "row"` or
#' `"column"` it is the scaled value (a z-score) the legend shows, not the
#' input, and with `kmeans_k` the cluster centres. A cell drawn in `na_col`
#' is a hole (`null`).
#'
#' **Selectors.** The cells are one rect grob drawn column by column, each
#' column top to bottom. Each is selected by its own id, in a grid whose rows
#' run bottom first, as maidr.js's heat grid does.
#'
#' @keywords internal
PheatmapHeatmapLayerProcessor <- R6::R6Class(
  "PheatmapHeatmapLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The pheatmap object
    #' @param layout The figure's layout: its title
    #' @param built Unused
    #' @param gt The gtable, its cells named [PHEATMAP_CELLS_GROB]
    #' @param grob_id Unused
    #' @param panel_id Unused
    #' @param panel_ctx Unused
    #' @param layer_info Unused
    #' @return The layer, or NULL when its values cannot be read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      data <- self$extract_data(plot, gt)
      if (is.null(data)) {
        return(NULL)
      }
      title <- layout$title %||% ""
      note <- PHEATMAP_VALUE_NOTES[[attr(data, "source")]]
      if (!is.null(note)) {
        title <- if (nzchar(title)) paste0(title, " (", note, ")") else note
        rlang::inform(
          paste0(
            "maidr: announcing this pheatmap's cells with ", note, ". ",
            "For exact values, draw it with maidr::pheatmap()."
          ),
          class = "maidr_pheatmap_values"
        )
      }
      attr(data, "source") <- NULL
      list(
        type = "heat",
        data = data,
        selectors = self$generate_selectors(plot, gt),
        title = title,
        axes = build_axes(x = "Columns", y = "Rows", z = "value")
      )
    },

    #' @description The cells' values and labels, rows top first
    #' @param plot The pheatmap object
    #' @param built The gtable, its cells named [PHEATMAP_CELLS_GROB]
    #' @return List with `x`, `y` and `points`, its `"source"` attribute
    #'   `"matrix"`, `"printed"` or `"legend"`; or NULL
    extract_data = function(plot, built = NULL) {
      gt <- built
      matrix_grob <- pheatmap_grob(gt, "matrix")
      rect <- pheatmap_child(matrix_grob, "rect")
      fill <- rect$gp$fill
      if (is.null(fill) || !is.matrix(fill) || length(fill) == 0L) {
        return(NULL)
      }
      n <- nrow(fill)
      m <- ncol(fill)
      bands <- pheatmap_legend_bands(pheatmap_grob(gt, "legend"))
      agrees <- function(values, tolerance) {
        is.null(bands) || pheatmap_values_agree(values, fill, bands, tolerance)
      }
      exact <- 1e-6 * if (is.null(bands)) 1 else max(1, diff(range(c(bands$lo, bands$hi))))

      source <- "matrix"
      values <- attr(plot, "maidr_matrix", exact = TRUE)
      if (!pheatmap_matrix_fits(values, fill) || !agrees(values, exact)) {
        source <- "printed"
        values <- pheatmap_printed_numbers(pheatmap_child(matrix_grob, "text"), n, m)
        if (!is.null(values) && !agrees(values, attr(values, "precision") + exact)) {
          values <- NULL
        }
      }
      if (is.null(values)) {
        if (is.null(bands)) {
          return(NULL)
        }
        source <- "legend"
        at <- match(pheatmap_colour_key(as.vector(fill)), bands$colour)
        middle <- (bands$lo + bands$hi) / 2
        width <- min(bands$hi - bands$lo)
        digits <- if (is.finite(width) && width > 0) max(0L, ceiling(-log10(width))) else 6L
        values <- matrix(round(middle[at], digits), n, m)
      }
      values <- unname(values)
      attributes(values) <- list(dim = c(n, m))

      structure(
        list(
          x = as.list(self$labels(gt, "col_names", colnames(fill), plot$tree_col, m)),
          y = as.list(self$labels(gt, "row_names", rownames(fill), plot$tree_row, n)),
          points = lapply(seq_len(n), function(i) as.list(values[i, ]))
        ),
        source = source
      )
    },

    #' @description The labels of one axis, in drawn order; see
    #'   [pheatmap_axis_labels()]
    #' @param gt The gtable
    #' @param name `"row_names"` or `"col_names"`
    #' @param dimnames The fill matrix's names along the axis
    #' @param tree The axis' `hclust`, or NA when it was not clustered
    #' @param count The number of rows or columns drawn
    #' @return Character vector
    labels = function(gt, name, dimnames, tree, count) {
      pheatmap_axis_labels(gt, name, dimnames, tree, count)
    },

    #' @description One selector per cell, rows bottom first
    #' @param plot The pheatmap object
    #' @param gt The gtable, its cells named [PHEATMAP_CELLS_GROB]
    #' @param grob_id Unused
    #' @param panel_ctx Unused
    #' @return A grid of selectors, `[row][column]`
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      fill <- pheatmap_child(pheatmap_grob(gt, "matrix"), "rect")$gp$fill
      n <- nrow(fill)
      m <- ncol(fill)
      lapply(rev(seq_len(n)), function(i) {
        lapply(seq_len(m), function(j) {
          lattice_shape_selector(PHEATMAP_CELLS_GROB, (j - 1L) * n + i)
        })
      })
    }
  )
)
