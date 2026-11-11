#' Heatmap Layer Processor
#'
#' Processes heatmap layers (geom_tile) with generic data and grob reordering
#'
#' @keywords internal
Ggplot2HeatmapLayerProcessor <- R6::R6Class(
  "Ggplot2HeatmapLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the layer: read its tiles, selectors and axis names from the built plot
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List describing the layer for the MAIDR payload
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      extracted_data <- self$extract_data(plot, built, panel_id = panel_id)

      selectors <- self$generate_selectors(plot, gt, panel_ctx = panel_ctx)

      fill_label <- extracted_data$fill_label
      fill_levels <- extracted_data$fill_levels
      cells <- extracted_data$cells
      data <- extracted_data[
        !names(extracted_data) %in% c("fill_label", "fill_levels", "cells")
      ]

      # A grid a stat computed is named cell by cell, with `null` where no
      # tile was drawn, which the frontend's heatmap model reads as a hole.
      # One selector over all the rects gives the model nothing to pair
      # where bins are empty: it wants exactly one element per cell from a
      # string, so the layer had no highlight at all (#316). Nor where every
      # cell is drawn: a stat draws its grid a row at a time from the
      # bottom, and the model pairs a string's rects a column at a time, so
      # cells were highlighted on other cells' tiles.
      if (!is.null(cells) && is.character(selectors) && length(selectors) == 1L) {
        selectors <- self$binned_selector_grid(selectors, cells)
      }

      # The names ggplot2 prints, not the letters. These were two string
      # literals, so a heatmap announced "x: y, y: a, score: 3" -- where the
      # first `y` is a category value and the second is the axis name that
      # should have been "Model". A `labs()` override and the mapped column
      # name were both discarded, and nothing a caller could write reached
      # the reader. The base R adapter had always read real labels; only
      # this side did not (#156).
      #
      # The values are named by the legend's title, as the stacked and
      # dodged bars' groups are: `labs(fill = "Correlation")` titled the
      # legend while the reader heard "value is 0.8", the name of the column
      # the cells were read from. That name, or the variable a stat computed
      # the fill from, remains the fallback. A fill neither mapped nor
      # computed draws every tile in one colour, under no legend, and is read
      # as missing under no title: `stat_summary_2d(fill = "steelblue")` was
      # read under "value", the title its stat would have given a legend.
      layer_index <- self$get_layer_index()
      axes <- build_axes(
        x = positional_axis_label(plot, built, "x", layer_index),
        y = positional_axis_label(plot, built, "y", layer_index),
        z = if (!is.null(fill_label)) {
          resolve_legend_label(plot, built, "fill", layer_index) %||% fill_label
        }
      )
      # A cell of categories holds its category's place in the legend, and
      # is read by the category's name (`heat_level_format()`). maidr.js
      # 4.17.0 states the description's "Min value" and "Max value" without
      # the format, so those two read the first and last places, 1 and the
      # number of categories, until it reads them through it.
      if (length(fill_levels) > 0L && !is.null(axes$z)) {
        axes <- attach_axis_format(axes, "z", heat_level_format(fill_levels))
      }

      list(
        data = data,
        selectors = selectors,
        axes = axes
      )
    },
    #' @description Whether the plot data must be reordered before drawing, so the emitted order
    #'   matches the drawn tiles
    #' @return TRUE
    needs_reordering = function() {
      TRUE
    },
    #' @description One selector per drawn tile of a grid a stat computed, `NA` where
    #'   none was drawn
    #'
    #' ggplot2 draws the tiles in the order the built data lists them, so the
    #' k-th rect under the layer's group is the k-th built row; `cells` holds
    #' that row number per cell, in the emitted row order.
    #'
    #' @param selector The layer's `<group> > rect` selector
    #' @param cells Per-row lists of built row numbers, `NA` where no bin was drawn
    #' @return A per-cell selector grid
    binned_selector_grid = function(selector, cells) {
      group <- sub(" > rect$", "", selector)
      lapply(cells, function(row) {
        lapply(row, function(k) {
          if (is.na(k)) {
            NA_character_
          } else {
            paste0(group, " > rect:nth-of-type(", k, ")")
          }
        })
      })
    },
    #' @description Reorder the plot data row-wise so the emitted cells match the drawn tiles
    #' @param data The data frame ggplot2 will draw from
    #' @param plot The ggplot2 object
    #' @return The reordered data frame
    reorder_layer_data = function(data, plot) {
      # Generic data reordering for heatmaps
      # Reorder data to match visual order (row-wise)
      if (nrow(data) == 0) {
        return(data)
      }

      # Not for a grid a stat computes. Below, the heatmap's x and y are made
      # into factors so the tiles sort into DOM order -- correct when they
      # are its categories, and destructive when they are the observations a
      # stat computes the grid from: ggplot2 then maps 200 data points to
      # 200 *discrete* positions. `StatBin2d` binned those integers instead
      # of the numbers, one bin per observation, which made a four-by-four
      # binned scatter come out as a 200x200 grid labelled "0.5 to 1.5",
      # "1.5 to 2.5", and so on (#136); `stat_summary_2d()` drew a tile per
      # observation the same way, and `stat_density_2d()` drew no tiles at
      # all: "Computation failed in `stat_density2d()`".
      if (self$is_computed_grid(plot)) {
        return(data)
      }

      # The heatmap's own x and y, by its mapping. The data's first two
      # columns were taken for them: in `data.frame(score, x, y)` the fill
      # was made a factor, drawn with a discrete legend, and the rows sorted
      # by it, out of the order the cells are paired with; and where the
      # tiles draw data of their own, the plot's data is another layer's,
      # whose points were moved to discrete positions.
      positions <- heat_positions(self$get_own_layer(plot), plot, data)
      if (is.null(positions)) {
        return(data)
      }

      # Each axis sorts by its positions in the order ggplot2 draws them: a
      # continuous scale's numbers, else a discrete scale's limits or the
      # values sorted. A column the mapping names is made a factor so its
      # tiles take those positions, unless its scale is continuous, which a
      # factor would stop the plot from drawing on ("Discrete value supplied
      # to a continuous scale"). An expression is sorted by what it
      # evaluates to, and its columns are left alone.
      keys <- list()
      for (aesthetic in c("x", "y")) {
        position <- positions[[aesthetic]]
        values <- if (!is.null(position$column)) data[[position$column]] else position$values
        scale <- plot$scales$get_scales(aesthetic)
        discrete <- isTRUE(tryCatch(scale$is_discrete(), error = function(e) FALSE))
        if (!is.null(scale) && !discrete) {
          keys[[aesthetic]] <- xtfrm(values)
          next
        }
        limits <- if (!is.null(scale)) scale$limits
        order <- if (is.atomic(limits) && length(limits) > 0L) limits else sort(unique(values))
        if (!is.null(position$column)) {
          data[[position$column]] <- factor(values, levels = order)
          keys[[aesthetic]] <- as.integer(data[[position$column]])
        } else {
          keys[[aesthetic]] <- match(as.character(values), as.character(order))
        }
      }

      # Column-major: x first, then y from the bottom row up, the order the
      # tiles are paired with the cells.
      reordered_data <- data[order(keys$x, keys$y), , drop = FALSE]
      rownames(reordered_data) <- NULL

      reordered_data
    },
    #' @description Report whether this layer's grid was computed by a stat.
    #'
    #'   `geom_bin_2d()` is `GeomTile` + `StatBin2d`, so it arrives here
    #'   classified as a heatmap -- correctly, since a rectangular bin grid
    #'   is one. What differs is where the grid comes from: a `geom_tile()`
    #'   heatmap is handed one in `plot$data`, and a binned one has its
    #'   computed for it. So do `stat_summary_2d()`, a summary of the values
    #'   in each bin, and `stat_density_2d(geom = "raster", contour = FALSE)`,
    #'   the density at each point of a lattice; and a stat built on one of
    #'   the three, as ggplot2 4.0 builds `StatBin2d` on `StatSummary2d`.
    #'
    #'   Matched on the stat rather than on the presence of a `count`
    #'   column, because a tidy heatmap whose value column happens to be
    #'   named `count` is not a binned layer and must not take that path.
    #'   Reached through `get_own_layer()`, which already answers "is there
    #'   a layer at my index?" -- a second bounds check here would be a
    #'   second place for the answer to change.
    #' @param plot The ggplot object
    #' @return `TRUE` when the layer's stat computes its grid
    is_computed_grid = function(plot) {
      layer <- self$get_own_layer(plot)
      if (is.null(layer)) {
        return(FALSE)
      }
      inherits(layer$stat, c("StatBin2d", "StatSummary2d", "StatDensity2d"))
    },
    #' @description Read a grid a stat computed out of the built data.
    #'
    #'   The built data *is* the grid: one row per drawn tile, carrying its
    #'   edges and the value its fill was computed from
    #'   (`heat_stat_fill()`). A binned grid lists only the bins that hold
    #'   something, so the full rectangle is rebuilt from the distinct
    #'   positions and the empty cells left missing rather than scored zero
    #'   -- an empty bin genuinely counted nothing, but the frontend reads a
    #'   zero as "no rect here" for highlighting, and every cell of a
    #'   heatmap has one.
    #'
    #'   Axis labels are the tile's coordinate *range*, not its index: "a
    #'   count of 4" means nothing without "between -2.2 and -1.1", and the
    #'   range is what a sighted reader gets from the axis (#136).
    #' @param built_data This layer's computed data, already panel-filtered,
    #'   with each tile's value in `.maidr_heat_fill`
    #' @param fill_label The fill's name, or NULL where the stat computes none
    #' @return The same shape `extract_data` returns for a tidy heatmap
    extract_computed_grid = function(built_data, fill_label) {
      if (nrow(built_data) == 0 || !all(c("x", "y") %in% names(built_data))) {
        return(list(points = list(), x = character(0), y = character(0),
                    fill_label = fill_label))
      }

      x_positions <- sort(unique(built_data$x))
      y_positions <- sort(unique(built_data$y))

      scores <- matrix(
        NA_real_,
        nrow = length(y_positions),
        ncol = length(x_positions)
      )
      # Which built row -- and so which drawn rect -- each cell is.
      rows_of <- matrix(
        NA_integer_,
        nrow = length(y_positions),
        ncol = length(x_positions)
      )
      for (i in seq_len(nrow(built_data))) {
        row <- match(built_data$y[i], y_positions)
        col <- match(built_data$x[i], x_positions)
        scores[row, col] <- built_data$.maidr_heat_fill[i]
        rows_of[row, col] <- i
      }

      # Bottom row first, matching the DOM order the tidy path also emits.
      y_labels <- rev(self$bin_labels(built_data, y_positions, "y"))
      points <- rev(lapply(seq_len(nrow(scores)), function(i) as.numeric(scores[i, ])))
      # NOT reversed: the frontend's heatmap model reverses `points` and `y`
      # as it reads them, and indexes a selector grid by its own row -- so
      # the grid runs the other way round from the rows above. Measured in
      # headless Chromium: reversed like `points`, the bottom row's cells were
      # outlined on the top row (#316).
      cells <- lapply(seq_len(nrow(rows_of)), function(i) as.integer(rows_of[i, ]))

      list(
        points = points,
        x = self$bin_labels(built_data, x_positions, "x"),
        y = y_labels,
        fill_label = fill_label,
        cells = cells
      )
    },
    #' @description Render one bin edge as a short, readable number.
    #'
    #'   Bin edges are floating point and print at full precision by
    #'   default -- "-1.1076174999999999 to 1.1076180000000001e-07" is an
    #'   announcement nobody can hold in their head. Rounded to a few
    #'   significant figures, and trimmed, so the label reads as a
    #'   coordinate rather than as a machine number.
    #' @param value A single numeric bin edge or centre
    #' @return A length-1 character string
    format_bin_edge = function(value) {
      format(signif(value, 4), trim = TRUE, scientific = FALSE)
    },
    #' @description Label each bin by the range it covers.
    #'
    #'   `xmin`/`xmax` are computed alongside the count, so the range costs
    #'   nothing to report and is the only thing that makes the count
    #'   meaningful. Falls back to the bin centre when the edges are absent,
    #'   which is still a coordinate rather than an index.
    #' @param built_data This layer's computed data
    #' @param positions The distinct bin centres, sorted
    #' @param axis `"x"` or `"y"`
    #' @return Character labels, one per position, in the same order
    bin_labels = function(built_data, positions, axis) {
      min_col <- paste0(axis, "min")
      max_col <- paste0(axis, "max")
      has_edges <- all(c(min_col, max_col) %in% names(built_data))

      vapply(positions, function(position) {
        if (!has_edges) {
          return(self$format_bin_edge(position))
        }
        row <- which(built_data[[axis]] == position)[1]
        lower <- built_data[[min_col]][row]
        upper <- built_data[[max_col]][row]
        if (is.na(lower) || is.na(upper)) {
          return(self$format_bin_edge(position))
        }
        paste0(self$format_bin_edge(lower), " to ", self$format_bin_edge(upper))
      }, character(1))
    },
    #' @description One row per tile plus the fill label, read from the built plot
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_index <- self$get_layer_index()
      built_data <- built$data[[layer_index]]

      # A grid a stat computed is coloured by what the stat computed, which
      # is in the built data and nowhere else. It is evaluated over every
      # panel's tiles at once, as ggplot2 evaluates it, before this panel's
      # are taken: `after_stat(count / max(count))` is a share of the
      # layer's largest count, not of the panel's.
      computed <- self$is_computed_grid(plot)
      if (computed) {
        fill <- heat_stat_fill(self$get_own_layer(plot), plot, built_data)
        built_data[[".maidr_heat_fill"]] <- fill$values
      }

      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, , drop = FALSE]
      }

      # A computed 2D grid is already a grid, and reconstructing one from
      # the source columns cannot work: everything below assumes a
      # `geom_tile()` heatmap built from tidy data, one row per cell. On a
      # binned scatter the source columns are the raw observations, so the
      # axis levels come out as one per data point and the built x is a bin
      # *centre* that matches none of them -- a complete, well-formed and
      # entirely empty grid, 200x200 of missing against 18 drawn tiles
      # (#136).
      if (computed) {
        return(self$extract_computed_grid(built_data, fill$label))
      }

      # The values each tile was drawn from, evaluated as ggplot2 evaluates
      # them (`heat_source_frame()`). A fill of categories is placed in its
      # legend, which lists the discrete fill scale's limits in order. Their
      # NA, which ggplot2 draws in its `na.value` grey, is no category: such
      # a tile is read as missing, as a numeric fill's NA is.
      fill_scale <- tryCatch(built$plot$scales$get_scales("fill"), error = function(e) NULL)
      fill_levels <- if (!is.null(fill_scale) && isTRUE(fill_scale$is_discrete())) {
        tryCatch(as.character(fill_scale$get_limits()), error = function(e) NULL)
      }
      fill_levels <- fill_levels[!is.na(fill_levels)]
      fill_labels <- heat_legend_labels(fill_scale, fill_levels)
      source <- heat_source_frame(plot, layer_index, fill_levels, fill_labels)
      original_data <- source$data
      x_col <- ".maidr_heat_x"
      y_col <- ".maidr_heat_y"
      fill_col <- ".maidr_heat_fill"

      # Order categories the same way ggplot2 assigns discrete positions
      # (factor level order, otherwise sorted): position i in built data
      # is the i-th LEVEL, not the i-th value in data-appearance order.
      discrete_levels <- function(values) {
        if (is.factor(values)) {
          levels(values)
        } else if (is.character(values)) {
          sort(unique(values))
        } else {
          unique(values)
        }
      }
      # Axis levels come from the WHOLE data: ggplot2 assigns discrete
      # positions from the full scale, so every panel shares them.
      x_values <- discrete_levels(original_data[[x_col]])
      y_values <- discrete_levels(original_data[[y_col]])

      # Cell VALUES, in contrast, must come from this panel's rows only.
      # `built_data` is filtered to the panel but `original_data` is not, so
      # the (x, y) lookup below matched rows in every panel and took the
      # first one - each panel reported panel 1's values.
      panel_source <- original_data
      panel_layout <- built$layout$layout
      if (!is.null(panel_id) && !is.null(panel_layout)) {
        panel_row <- panel_layout[panel_layout$PANEL == panel_id, , drop = FALSE]
        if (nrow(panel_row) == 1) {
          facet_vars <- setdiff(
            names(panel_layout),
            c("PANEL", "ROW", "COL", "SCALE_X", "SCALE_Y")
          )
          # NA-safe, for the reason spelled out on facet_group_rows(): a bare
          # `==` answers NA for every row whose facet value is missing, and
          # `[` fabricates an all-NA row from an NA index, so the panel
          # ggplot2 draws for the missing value scored no cells at all (#102).
          for (facet_var in facet_vars) {
            if (facet_var %in% names(panel_source)) {
              panel_source <- panel_source[
                facet_group_rows(
                  panel_source[[facet_var]],
                  panel_row[[facet_var]]
                ), ,
                drop = FALSE
              ]
            }
          }
        }
      }

      score_matrix <- matrix(NA, nrow = length(y_values), ncol = length(x_values))
      rownames(score_matrix) <- y_values
      colnames(score_matrix) <- x_values
      # A discrete scale draws a tile at its level's index, the position the
      # lookup takes; a continuous one at the value itself, which is matched
      # to its level here. Read as an index, a tile at x = 10 matched none.
      as_index <- function(built, values) {
        if (inherits(built, "mapped_discrete") || !is.numeric(values)) {
          return(built)
        }
        match(built, values)
      }
      score_matrix <- heat_fill_scores(
        score_matrix, panel_source, x_col, y_col, fill_col,
        x_values, y_values,
        as_index(built_data$x, x_values), as_index(built_data$y, y_values)
      )

      # Reverse y_values to match DOM order (bottom row first)
      y_values_reversed <- rev(y_values)

      points <- lapply(seq_len(nrow(score_matrix)), function(i) {
        as.numeric(score_matrix[i, ])
      })

      # Reverse points array to match reversed y_values
      points <- rev(points)

      return(list(
        points = points,
        x = as.character(x_values),
        y = as.character(y_values_reversed),
        fill_label = source$fill_label,
        fill_levels = source$fill_levels
      ))
    },
    #' @description Selectors for the tiles, scoped to the panel
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      selectors <- list()

      if (!is.null(gt)) {
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (!is.null(panel_grob)) {
          # Look for geom_rect elements (master container)
          rect_children <- find_children_by_type(panel_grob, "geom_rect")
          if (length(rect_children) > 0) {
            master_container <- rect_children[1]
            svg_id <- paste0(master_container, ".1")
            # Escape dots in the ID for CSS selector
            escaped_id <- gsub("\\.", "\\\\.", svg_id)
            css_selector <- paste0("g#", escaped_id, " > rect")
            selectors <- css_selector
          }
        }
      }

      return(selectors)
    }
  )
)

#' The data a heatmap layer drew its tiles from, one column per aesthetic
#'
#' ggplot2 evaluates each aesthetic in the data the layer draws, its own
#' `data` or else the plot's (`Layer$layer_data()`), under the layer's
#' mapping and, unless `inherit.aes = FALSE`, the plot's. So
#' `aes(fill = score * 2)` draws each tile from twice its score. Each was
#' looked up instead as a column named after its mapping: "score * 2"
#' names none, so every cell was read missing, and an expression for `x` or
#' `y`, as `factor(month, levels = month.abb)`, or a layer drawn from data
#' of its own, stopped the reading.
#'
#' An `x` or `y` the layer does not map is read from the data's first or
#' second column, as it was before, and as missing where the data has no
#' such column. A fill the layer does not map is read as missing: its tiles
#' are all drawn in one colour, so no column of the data is what they show.
#' It was read from the data's third column, whatever that held. An
#' aesthetic that cannot be evaluated against the layer's data, or is no
#' vector there, is read as missing too. An `after_stat()` of a variable
#' the stat computes names no column of it, as `after_stat(group)` does, or
#' names a function: `after_stat(density)` is `stats::density()` there,
#' which stopped the reading. A grid a stat computes is read from what the
#' stat computed instead ([heat_stat_fill()]). A fill of categories is read
#' by the numbers its legend shows, as `factor(score * 10)` shows 10, 20
#' and 30, and by the names it shows where they are not numbers, as
#' `fill = grade` shows "high", "low" and "mid" ([heat_fill_numbers()]); the
#' colours `after_scale()` gives, under no legend, are missing. A factor was
#' read as its level codes.
#'
#' @param plot The ggplot2 object
#' @param layer_index The layer's index in `plot$layers`
#' @param fill_levels The categories of the fill's legend in its order, or
#'   NULL where it has none (`heat_fill_numbers()`)
#' @param fill_labels What the legend shows for each of `fill_levels`
#'   (`heat_legend_labels()`)
#' @return A list: `data`, the layer's data with each tile's x, y and fill in
#'   the columns `.maidr_heat_x`, `.maidr_heat_y` and `.maidr_heat_fill`;
#'   `fill_label`, the fill's name as ggplot2 labels it ("score * 2"), or
#'   `NULL` when the fill is not mapped; and `fill_levels`, the names of the
#'   places the fill's cells hold, as the legend shows them, or `NULL`
#' @keywords internal
heat_source_frame <- function(plot, layer_index, fill_levels = NULL, fill_labels = fill_levels) {
  layer <- plot$layers[[layer_index]]
  data <- tryCatch(layer$layer_data(plot$data), error = function(e) plot$data)
  if (!is.data.frame(data)) {
    data <- as.data.frame(data)
  }

  mapping <- as.list(layer$mapping)
  if (!isFALSE(layer$inherit.aes)) {
    inherited <- as.list(plot$mapping)
    mapping <- c(mapping, inherited[setdiff(names(inherited), names(mapping))])
  }

  # An unmapped aesthetic with a `position` is read from that column of the
  # layer's own data, counted before any column is added below; one without
  # is read as missing.
  rows <- nrow(data)
  columns <- names(data)
  read <- function(aesthetic, position = NULL) {
    quo <- mapping[[aesthetic]]
    if (is.null(quo)) {
      if (is.null(position) || position > length(columns)) {
        return(rep(NA, rows))
      }
      return(data[[columns[position]]])
    }
    value <- tryCatch(rlang::eval_tidy(quo, data), error = function(e) NULL)
    if (!is.atomic(value)) {
      return(rep(NA, rows))
    }
    if (length(value) == 1L && rows != 1L) {
      value <- rep(value, rows)
    }
    if (length(value) == rows) value else rep(NA, rows)
  }

  fill_mapping <- mapping[["fill"]]
  fill_label <- if (!is.null(fill_mapping)) rlang::as_label(fill_mapping)

  x <- read("x", 1L)
  y <- read("y", 2L)
  fill <- heat_fill_numbers(read("fill"), fill_levels, fill_labels)
  placed_in <- attr(fill, "maidr_levels")
  attr(fill, "maidr_levels") <- NULL
  data[[".maidr_heat_x"]] <- x
  data[[".maidr_heat_y"]] <- y
  data[[".maidr_heat_fill"]] <- fill
  list(data = data, fill_label = fill_label, fill_levels = placed_in)
}

#' A heatmap's fill values as the numbers its legend shows
#'
#' Each cell holds a number. A category's is the one its legend shows, where
#' its name is a number, as `factor(score * 10)` shows 10, 20 and 30. Where
#' a name is not one, as `fill = grade` shows "high", "low" and "mid", a
#' category is its place in the legend, 1 for the first: the layer's z axis
#' names each place (`heat_level_format()`), so the cell is read by its
#' category's name, or by the label the legend shows for it where a scale
#' relabels it (`heat_legend_labels()`), numbers too. Where there is no
#' legend to place them in, as for the colours `after_scale()` gives, they
#' are missing. Read as numbers, a factor gave its level codes, and the rest
#' came out missing with a coercion warning; then categories named otherwise
#' were all read as missing.
#'
#' @param values The fill's values
#' @param levels The legend's categories in its order, or NULL where it has
#'   none
#' @param labels What the legend shows for each of `levels`
#' @return `values`, its categories as their numbers or as their places in
#'   `levels`, with `labels` as the attribute `maidr_levels`; or, where any
#'   name is not a number and there are no levels, all missing
#' @keywords internal
heat_fill_numbers <- function(values, levels = NULL, labels = levels) {
  if (!is.factor(values) && !is.character(values)) {
    return(values)
  }
  shown <- as.character(values)
  numbers <- suppressWarnings(as.numeric(shown))
  # Numbers its legend shows as they are, unrelabelled -- a scale giving
  # them their own names again is no relabelling -- are read as numbers.
  if (identical(is.na(numbers), is.na(shown)) && identical(labels, levels)) {
    return(numbers)
  }
  if (length(levels) == 0L) {
    return(rep(NA, length(values)))
  }
  structure(as.numeric(match(shown, levels)), maidr_levels = labels)
}

#' What a heatmap's fill legend shows for each of its categories
#'
#' A discrete fill scale's `labels`, as `scale_fill_discrete(labels = )` or
#' `scale_fill_manual(labels = )` gives them, replace the categories' names
#' in the legend, and a function of them, as `labels = toupper`, or plotmath
#' does too. Each category is named by the label shown for it; one the
#' legend gives none, as a category its `breaks` leave out, keeps its name.
#'
#' @param scale The discrete fill scale, or NULL
#' @param levels The legend's categories in its order
#' @return A character vector as long as `levels`
#' @keywords internal
heat_legend_labels <- function(scale, levels) {
  if (is.null(scale) || length(levels) == 0L) {
    return(levels)
  }
  shown <- tryCatch(
    {
      breaks <- scale$get_breaks()
      labels <- scale$get_labels(breaks)
      if (length(labels) != length(breaks)) {
        stop("one label per break")
      }
      drawn <- !is.na(breaks)
      as.character(labels[drawn])[match(levels, as.character(breaks[drawn]))]
    },
    error = function(e) NULL
  )
  if (length(shown) != length(levels)) {
    return(levels)
  }
  ifelse(is.na(shown), levels, shown)
}

#' A z axis format that names the categories of a heatmap's fill
#'
#' A cell of categories holds its category's place in the legend
#' (`heat_fill_numbers()`); the frontend reads the z axis's `format`
#' function on each value it announces, so the cell is read by the name.
#' The names are a JSON array, which is a JavaScript one: `toJSON()` escapes
#' quotes and backslashes, and U+2028 and U+2029 are legal in a JavaScript
#' string since ES2019. A name like `</script>` reaches the page escaped,
#' in the chart's attribute.
#'
#' @param levels The names, in the legend's order
#' @return An AxisFormat holding a `function`
#' @keywords internal
heat_level_format <- function(levels) {
  names <- as.character(jsonlite::toJSON(as.character(levels)))
  list(`function` = paste0(
    "var names = ", names, "; var name = names[value - 1]; ",
    "return name === undefined ? String(value) : name;"
  ))
}

#' The values a stat computed a heatmap's fill from
#'
#' A grid a stat computes is coloured by what ggplot2 evaluates after the
#' stat, over what the stat computed: the layer's fill, or the plot's where
#' the layer inherits it, when ggplot2 evaluates it after the stat
#' ([heat_after_stat()]), and otherwise the stat's own, `after_stat(count)`
#' for `geom_bin_2d()` and `after_stat(value)` for `stat_summary_2d()`. The
#' built data holds what the stat computed, so it is evaluated there. The
#' bins' counts were read whatever the fill was, as `after_stat(density)`,
#' under the fill's title; and the cells of `stat_summary_2d()` and of a
#' density raster were read as missing.
#'
#' A fill the stat does not compute is read as missing: a constant, as
#' `stat_summary_2d(fill = "steelblue")` gives, or none, as on a density
#' raster that maps no fill, draws every tile in one colour; and ggplot2
#' drops a fill of the data's own columns from what such a stat draws.
#'
#' @param layer The heatmap's layer
#' @param plot The ggplot2 object
#' @param data The layer's built data, every panel's rows
#' @return A list: `values`, one number per row of `data`, `NA` where there
#'   is none; and `label`, the fill's name as ggplot2 names it, or NULL
#'   where the stat computes no fill
#' @keywords internal
heat_stat_fill <- function(layer, plot, data) {
  rows <- nrow(data)
  none <- list(values = rep(NA_real_, rows), label = NULL)
  if (is.null(layer) || !is.null(layer$aes_params$fill)) {
    return(none)
  }
  mapping <- as.list(layer$mapping)
  if (!isFALSE(layer$inherit.aes)) {
    inherited <- as.list(plot$mapping)
    mapping <- c(mapping, inherited[setdiff(names(inherited), names(mapping))])
  }
  fill <- mapping[["fill"]] %||% layer$stat$default_aes[["fill"]]
  if (!heat_after_stat(fill)) {
    return(none)
  }
  env <- if (rlang::is_quosure(fill)) rlang::quo_get_env(fill) else rlang::base_env()
  values <- tryCatch(
    heat_fill_numbers(rlang::eval_tidy(mapping_expr(fill), data, env)),
    error = function(e) NULL
  )
  if (!(is.numeric(values) || is.logical(values)) || !length(values) %in% c(1L, rows)) {
    values <- NA_real_
  }
  list(values = rep_len(as.numeric(values), rows), label = mapping_label(fill))
}

#' Whether ggplot2 evaluates a mapping after the stat
#'
#' As ggplot2 decides it: an `after_stat()`, a `stage()` given an
#' `after_stat` argument, or the older `stat()` and `..count..` spellings,
#' anywhere in the expression; not an `after_scale()`, which is evaluated on
#' the colours.
#'
#' @param mapping A quosure or expression from `aes()`, or NULL
#' @return `TRUE` or `FALSE`
#' @keywords internal
heat_after_stat <- function(mapping) {
  expr <- if (rlang::is_quosure(mapping)) rlang::quo_get_expr(mapping) else mapping
  if (is.symbol(expr)) {
    return(grepl("^\\.\\.([a-zA-Z._]+)\\.\\.$", as.character(expr)))
  }
  if (!is.call(expr) || rlang::is_call(expr, "after_scale")) {
    return(FALSE)
  }
  if (rlang::is_call(expr, c("after_stat", "stat"))) {
    return(TRUE)
  }
  if (rlang::is_call(expr, "stage")) {
    staged <- tryCatch(
      as.list(match.call(
        function(start = NULL, after_stat = NULL, after_scale = NULL) NULL,
        expr
      )),
      error = function(e) list()
    )
    return(!is.null(staged$after_stat))
  }
  any(vapply(as.list(expr)[-1], heat_after_stat, logical(1)))
}

#' Whether a heatmap source column can be coded by level
#'
#' Only where `match()` against the levels agrees with the `==` the cell
#' lookup is defined by: a factor, or a plain character, number or logical.
#' Any other class could give `==` a meaning of its own.
#'
#' @param values A source column
#' @return `TRUE` when [heat_level_codes()] may code it
#' @keywords internal
heat_codable <- function(values) {
  is.factor(values) ||
    (!is.object(values) && (is.character(values) || is.numeric(values) || is.logical(values)))
}

#' Each source row's level, for the heatmap cell lookup
#'
#' @param values A source column accepted by [heat_codable()]
#' @param levels The axis levels
#' @return Integer vector: the level each value equals, `0` for none and
#'   `NA` for a missing value, which compares `NA` against every level
#' @keywords internal
heat_level_codes <- function(values, levels) {
  if (is.factor(values)) {
    values <- as.character(values)
  }
  codes <- match(values, levels, nomatch = 0L)
  codes[is.na(values)] <- NA_integer_
  codes
}

#' Fill a heatmap's score matrix from the source rows
#'
#' Each drawn tile takes the fill of the first source row at its (x, y):
#' the row whose `x == x_level & y == y_level` is first not `FALSE`. A row
#' with a missing x or y compares `NA` against every level, so it wins the
#' cells it comes first for, with a missing value.
#'
#' Scanning the source for every tile made this quadratic -- a 300 x 300
#' grid took over a minute -- so each source row is coded by level once and the
#' cells are looked up in C++. A column [heat_codable()] cannot code is
#' still scanned.
#'
#' @param score_matrix The y-by-x matrix to fill, all `NA`
#' @param source This panel's source rows
#' @param x_col,y_col,fill_col Column names in `source`
#' @param x_values,y_values The axis levels
#' @param built_x,built_y Each drawn tile's position, a level index
#' @return `score_matrix`, filled. Read it through `as.numeric()`: where no
#'   cell takes a value its storage type is left as it was.
#' @keywords internal
heat_fill_scores <- function(score_matrix, source, x_col, y_col, fill_col,
                             x_values, y_values, built_x, built_y) {
  # Positions map back to levels by name: position i is the i-th level.
  x_mapping <- setNames(x_values, seq_along(x_values))
  y_mapping <- setNames(y_values, seq_along(y_values))
  source_x <- source[[x_col]]
  source_y <- source[[y_col]]
  fill <- source[[fill_col]]

  if (!(heat_codable(source_x) && heat_codable(source_y) && !is.null(fill))) {
    for (i in seq_along(built_x)) {
      x_val <- x_mapping[as.character(built_x[i])]
      y_val <- y_mapping[as.character(built_y[i])]
      score_val <- fill[source_x == x_val & source_y == y_val]
      if (length(score_val) > 0) {
        row_idx <- which(y_values == y_val)
        col_idx <- which(x_values == x_val)
        score_matrix[row_idx, col_idx] <- score_val[1]
      }
    }
    return(score_matrix)
  }

  # A tile at a missing level matches no cell.
  cell_x <- match(as.character(built_x), names(x_mapping))
  cell_y <- match(as.character(built_y), names(y_mapping))
  cell_x[is.na(x_values[cell_x])] <- NA_integer_
  cell_y[is.na(y_values[cell_y])] <- NA_integer_
  rows <- heat_cell_rows_cpp(
    heat_level_codes(source_x, x_values),
    heat_level_codes(source_y, y_values),
    length(x_values), length(y_values), cell_x, cell_y
  )
  hit <- rows != 0L
  if (any(hit)) {
    score_val <- fill[abs(rows[hit])]
    score_val[rows[hit] < 0L] <- NA
    score_matrix[cbind(cell_y[hit], cell_x[hit])] <- score_val
  }
  score_matrix
}

#' Where a heatmap layer takes its x and y from, in the plot's data
#'
#' A heatmap is reordered before it is drawn, so its tiles come out in the
#' order the reading pairs them with (`reorder_layer_data()`). That is done
#' to the plot's data, and only where the tiles draw it as it is: a layer
#' with data of its own, or a function of the plot's, leaves it alone.
#'
#' Each position follows the mapping, the layer's or else the plot's unless
#' `inherit.aes = FALSE`. A column it names, as a bare name, `.data$x`,
#' `.data[["x"]]` or `.data[[var]]` where `var` holds the name, is given as
#' that column. Any other expression is given as what it evaluates to over
#' the data, a symbol that is no column (a variable of the caller's) among
#' them. A constant, as `aes(x = 1)` stores it, and `.data[[f()]]`, which
#' names its column only by calling `f()` again, give none: the data is
#' then left as it is.
#'
#' @param layer The heatmap's layer, or NULL
#' @param plot The ggplot2 object
#' @param data The plot's data
#' @return `list(x = , y = )`, each `list(column = )` or `list(values = )`,
#'   or NULL
#' @keywords internal
heat_positions <- function(layer, plot, data) {
  if (is.null(layer) || !inherits(layer$data, "waiver")) {
    return(NULL)
  }
  mapping <- as.list(layer$mapping)
  if (!isFALSE(layer$inherit.aes)) {
    inherited <- as.list(plot$mapping)
    mapping <- c(mapping, inherited[setdiff(names(inherited), names(mapping))])
  }
  position <- function(aesthetic) {
    quo <- mapping[[aesthetic]]
    if (!rlang::is_quosure(quo)) {
      return(NULL)
    }
    expr <- rlang::quo_get_expr(quo)
    name <- if (is.symbol(expr)) {
      as.character(expr)
    } else if (is.call(expr) && length(expr) == 3L && identical(expr[[2]], quote(.data))) {
      index <- expr[[3]]
      if (identical(expr[[1]], quote(`$`))) {
        as.character(index)
      } else if (identical(expr[[1]], quote(`[[`))) {
        # A string, or a variable holding one, is looked up without running
        # anything: `.data[[f()]]` would call `f()` a second time.
        if (is.character(index)) {
          index
        } else if (is.symbol(index)) {
          get0(as.character(index), envir = rlang::quo_get_env(quo), inherits = TRUE)
        } else {
          return(NULL)
        }
      }
    }
    if (is.character(name) && length(name) == 1L && name %in% names(data)) {
      return(list(column = name))
    }
    values <- tryCatch(rlang::eval_tidy(quo, data), error = function(e) NULL)
    if (!is.atomic(values) || length(values) != nrow(data)) {
      return(NULL)
    }
    list(values = values)
  }
  x <- position("x")
  y <- position("y")
  if (is.null(x) || is.null(y)) {
    return(NULL)
  }
  list(x = x, y = y)
}
