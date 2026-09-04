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
      data <- extracted_data[names(extracted_data) != "fill_label"]

      # The names ggplot2 prints, not the letters. These were two string
      # literals, so a heatmap announced "x: y, y: a, score: 3" -- where the
      # first `y` is a category value and the second is the axis name that
      # should have been "Model". A `labs()` override and the mapped column
      # name were both discarded, and nothing a caller could write reached
      # the reader. The base R adapter had always read real labels; only
      # this side did not (#156).
      layer_index <- self$get_layer_index()
      axes <- build_axes(
        x = positional_axis_label(plot, built, "x", layer_index),
        y = positional_axis_label(plot, built, "y", layer_index),
        z = fill_label
      )

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

      # Not for a computed bin grid. Below, the first two columns are made
      # into factors so the tiles sort into DOM order -- correct when they
      # are the heatmap's categories, and destructive when they are raw
      # continuous observations: ggplot2 then maps 200 data points to 200
      # *discrete* positions, and `StatBin2d` bins those integers instead
      # of the numbers, producing one bin per observation. That is what
      # made a four-by-four binned scatter come out as a 200x200 grid
      # labelled "0.5 to 1.5", "1.5 to 2.5", and so on (#136).
      if (self$is_binned_layer(plot)) {
        return(data)
      }

      x_col <- names(data)[1]
      y_col <- names(data)[2]

      x_scale <- plot$scales$get_scales("x")
      y_scale <- plot$scales$get_scales("y")

      # Determine x-axis order
      if (!is.null(x_scale) && !is.null(x_scale$limits)) {
        x_order <- x_scale$limits
      } else {
        x_order <- sort(unique(data[[x_col]]))
      }

      # Determine y-axis order
      if (!is.null(y_scale) && !is.null(y_scale$limits)) {
        y_order <- y_scale$limits
      } else {
        y_order <- sort(unique(data[[y_col]]))
      }

      data[[x_col]] <- factor(data[[x_col]], levels = x_order)
      data[[y_col]] <- factor(data[[y_col]], levels = y_order)

      # Reorder data column-wise (x first, then y) for column-major DOM order
      # Keep y order as-is so bottom row comes first (for navigation starting from bottom-left)
      reordered_data <- data[order(data[[x_col]], data[[y_col]]), , drop = FALSE]
      rownames(reordered_data) <- NULL

      reordered_data
    },
    #' @description Report whether this layer's grid was computed by a stat.
    #'
    #'   `geom_bin_2d()` is `GeomTile` + `StatBin2d`, so it arrives here
    #'   classified as a heatmap -- correctly, since a rectangular bin grid
    #'   is one. What differs is where the grid comes from: a `geom_tile()`
    #'   heatmap is handed one in `plot$data`, and a binned one has its
    #'   computed for it.
    #'
    #'   Matched on the stat rather than on the presence of a `count`
    #'   column, because a tidy heatmap whose value column happens to be
    #'   named `count` is not a binned layer and must not take that path.
    #'   Reached through `get_own_layer()`, which already answers "is there
    #'   a layer at my index?" -- a second bounds check here would be a
    #'   second place for the answer to change.
    #' @param plot The ggplot object
    #' @return `TRUE` when the layer's stat computes a 2D bin grid
    is_binned_layer = function(plot) {
      layer <- self$get_own_layer(plot)
      if (is.null(layer)) {
        return(FALSE)
      }
      identical(class(layer$stat)[1], "StatBin2d")
    },
    #' @description Read a computed 2D bin grid out of the built data.
    #'
    #'   The built data *is* the grid: one row per drawn tile, carrying the
    #'   bin's count and its edges. Only the bins that hold something are
    #'   present, so the full rectangle is rebuilt from the distinct
    #'   positions and the empty cells left missing rather than scored zero
    #'   -- an empty bin genuinely counted nothing, but the frontend reads a
    #'   zero as "no rect here" for highlighting, and every cell of a
    #'   heatmap has one.
    #'
    #'   Axis labels are the bin's coordinate *range*, not its index: "a
    #'   count of 4" means nothing without "between -2.2 and -1.1", and the
    #'   range is what a sighted reader gets from the axis (#136).
    #' @param built_data This layer's computed data, already panel-filtered
    #' @return The same shape `extract_data` returns for a tidy heatmap
    extract_binned_data = function(built_data) {
      if (nrow(built_data) == 0 || !all(c("x", "y") %in% names(built_data))) {
        return(list(points = list(), x = character(0), y = character(0),
                    fill_label = "count"))
      }

      # `count` is what `stat_bin_2d()` computes, and `value` is the same
      # number under ggplot2 3.x's spelling -- checked rather than assumed:
      # on 3.4.4 both columns are present and identical row for row. So the
      # label below is "count" either way, and reading `value` is a
      # fallback for a build that stops emitting `count` rather than a
      # different quantity.
      #
      # `fill` is never it: that is the mapped colour, not a number.
      value_col <- if ("count" %in% names(built_data)) {
        "count"
      } else if ("value" %in% names(built_data)) {
        "value"
      } else {
        NULL
      }
      if (is.null(value_col)) {
        return(list(points = list(), x = character(0), y = character(0),
                    fill_label = "count"))
      }

      x_positions <- sort(unique(built_data$x))
      y_positions <- sort(unique(built_data$y))

      scores <- matrix(
        NA_real_,
        nrow = length(y_positions),
        ncol = length(x_positions)
      )
      for (i in seq_len(nrow(built_data))) {
        row <- match(built_data$y[i], y_positions)
        col <- match(built_data$x[i], x_positions)
        scores[row, col] <- as.numeric(built_data[[value_col]][i])
      }

      # Bottom row first, matching the DOM order the tidy path also emits.
      y_labels <- rev(self$bin_labels(built_data, y_positions, "y"))
      points <- rev(lapply(seq_len(nrow(scores)), function(i) as.numeric(scores[i, ])))

      list(
        points = points,
        x = self$bin_labels(built_data, x_positions, "x"),
        y = y_labels,
        fill_label = "count"
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

      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, , drop = FALSE]
      }

      # A computed 2D bin layer is already a grid, and reconstructing one
      # from the source columns cannot work: everything below assumes a
      # `geom_tile()` heatmap built from tidy data, one row per cell. On a
      # binned scatter the source columns are the raw observations, so the
      # axis levels come out as one per data point and the built x is a bin
      # *centre* that matches none of them -- a complete, well-formed and
      # entirely empty grid, 200x200 of missing against 18 drawn tiles
      # (#136).
      if (self$is_binned_layer(plot)) {
        return(self$extract_binned_data(built_data))
      }

      original_data <- plot$data

      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[layer_index]]$mapping

      # Determine x, y, and fill column names
      x_col <- if (!is.null(layer_mapping$x)) {
        rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot_mapping$x)) {
        rlang::as_label(plot_mapping$x)
      } else {
        names(original_data)[1]
      }

      y_col <- if (!is.null(layer_mapping$y)) {
        rlang::as_label(layer_mapping$y)
      } else if (!is.null(plot_mapping$y)) {
        rlang::as_label(plot_mapping$y)
      } else {
        names(original_data)[2]
      }

      fill_col <- if (!is.null(layer_mapping$fill)) {
        rlang::as_label(layer_mapping$fill)
      } else if (!is.null(plot_mapping$fill)) {
        rlang::as_label(plot_mapping$fill)
      } else {
        names(original_data)[3]
      }

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

      x_mapping <- setNames(x_values, seq_along(x_values))
      y_mapping <- setNames(y_values, seq_along(y_values))

      score_matrix <- matrix(NA, nrow = length(y_values), ncol = length(x_values))
      rownames(score_matrix) <- y_values
      colnames(score_matrix) <- x_values

      # Fill the matrix with scores using built data
      for (i in seq_len(nrow(built_data))) {
        x_pos <- built_data$x[i]
        y_pos <- built_data$y[i]

        # Map positions back to original values
        x_val <- x_mapping[as.character(x_pos)]
        y_val <- y_mapping[as.character(y_pos)]

        score_val <- panel_source[[fill_col]][
          panel_source[[x_col]] == x_val & panel_source[[y_col]] == y_val
        ]

        if (length(score_val) > 0) {
          row_idx <- which(y_values == y_val)
          col_idx <- which(x_values == x_val)
          score_matrix[row_idx, col_idx] <- score_val[1]
        }
      }

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
        fill_label = fill_col
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
