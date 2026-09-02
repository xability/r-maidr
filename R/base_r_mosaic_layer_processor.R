#' Base R Mosaic Plot Layer Processor
#'
#' Processes Base R `mosaicplot()` layers -- a two-way contingency table
#' drawn as tiles, where a column's **width** encodes that category's share
#' of all observations and a tile's height its conditional proportion within
#' the column.
#'
#' Read as a `mosaic` layer, which exists for exactly this shape. Read as a
#' `stacked_bar` it would lose the width entirely, and the width is half the
#' table: the conditional proportions would arrive without the group sizes
#' they were computed from, so a category of six observations and one of six
#' hundred would read identically.
#'
#' Nothing here is inferred from the drawing. `mosaicplot()` is handed the
#' table itself, so the recorded call carries every number the trace wants --
#' the counts, the margins they imply, and the level names from `dimnames()`.
#'
#' @keywords internal
BaseRMosaicLayerProcessor <- R6::R6Class(
  "BaseRMosaicLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the mosaic layer.
    #' @param plot Unused for Base R (kept for interface compatibility)
    #' @param layout Unused for Base R (kept for interface compatibility)
    #' @param built Unused for Base R (kept for interface compatibility)
    #' @param gt Gtable object used for selector generation (optional)
    #' @param grob_id Unused for Base R
    #' @param panel_id Unused for Base R
    #' @param panel_ctx Unused for Base R
    #' @param layer_info Information about the recorded plot call
    #' @return List with data, selectors, type, title and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      list(
        data = self$extract_data(layer_info),
        selectors = self$generate_selectors(layer_info, gt),
        type = "mosaic",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info)
      )
    },
    needs_reordering = function() {
      FALSE
    },

    #' @description Read the table out of the recorded `mosaicplot()` call.
    #'
    #' The emitted shape is the segmented one the stacked bar processor
    #' already produces -- `data[[fill]][[category]]` -- because the core
    #' builds `MosaicTrace` on `SegmentedTrace` and navigates it
    #' category-then-series exactly as a stack. `mosaicplot()` splits along
    #' the first dimension into columns and each column along the second, so
    #' the first dimension is the category and the second the fill.
    #'
    #' Each cell carries four numbers rather than one:
    #'
    #' * `y`, the cell's conditional proportion within its column -- the
    #'   tile's height, and what a stack's value would be;
    #' * `width`, the column's share of all observations -- carried on every
    #'   cell of the column, because the grammar's unit is the point and a
    #'   flat list has nowhere else to put it;
    #' * `count`, the cell's own count. A mosaic is drawn *from* counts and
    #'   they are the numbers a reader would quote back;
    #' * `z`, the fill level's name.
    #'
    #' A column that observed nothing has no conditional proportions to
    #' report -- dividing would give `NaN` for every cell -- so its cells
    #' carry a proportion of 0 alongside their true count of 0. That is what
    #' the chart draws: a column of zero width and no tiles.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return Nested list of points, empty when there is no table to read
    extract_data = function(layer_info) {
      table <- self$recorded_table(layer_info)
      if (is.null(table)) {
        return(list())
      }

      categories <- rownames(table)
      fills <- colnames(table)
      total <- sum(table)
      column_totals <- rowSums(table)

      lapply(seq_along(fills), function(fill_index) {
        lapply(seq_along(categories), function(category_index) {
          count <- table[category_index, fill_index]
          column_total <- column_totals[[category_index]]
          list(
            x = as.character(categories[category_index]),
            y = if (column_total > 0) as.numeric(count / column_total) else 0,
            z = as.character(fills[fill_index]),
            width = if (total > 0) as.numeric(column_total / total) else 0,
            count = as.numeric(count)
          )
        })
      })
    },

    #' @description The two-way table the call was handed, when it is one.
    #'
    #' Only a two-dimensional table is read. `mosaicplot()` accepts three and
    #' more, splitting recursively, and a `mosaic` layer has one category
    #' axis and one fill -- so a deeper table has nowhere to put its later
    #' dimensions and is declined rather than flattened into a
    #' cross-classification the chart does not claim.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return A 2-D table, or NULL
    recorded_table = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      recorded_two_way_table(layer_info$plot_call$args)
    },

    #' @description Name the axes from the table's own dimension names.
    #'
    #' `mosaicplot()` labels its axes with `names(dimnames(x))` unless the
    #' author overrides them -- "Hair" and "Eye" for `HairEyeColor[, , 1]` --
    #' so those are the two words a reader should be given for the two
    #' dimensions.
    #'
    #' Which grammar axis each lands on is not the chart's own arrangement.
    #' The second dimension is what `mosaicplot()` draws up the y axis, but a
    #' segmented layer's `y` holds the *magnitude* and its `z` the fill, so
    #' the second dimension is named on `z` and `y` says what its numbers
    #' are. `ylab` follows the dimension it names rather than the axis it
    #' shares a letter with, for the same reason.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      args <- if (is.null(layer_info)) NULL else layer_info$plot_call$args
      named <- names(dimnames(self$recorded_table(layer_info)))
      dimension <- function(i) {
        if (length(named) >= i && !is.na(named[[i]]) && nzchar(named[[i]])) {
          named[[i]]
        } else {
          NULL
        }
      }

      build_axes(
        x = recorded_axis_label(args, "xlab", dimension(1)),
        # Not a dimension of the table: the number every cell carries.
        y = "Proportion",
        z = recorded_axis_label(args, "ylab", dimension(2))
      )
    },

    #' @description The title the call was given, if any.
    #'
    #' `mosaicplot()` writes a default `main` of its own from the deparsed
    #' data expression, but the recorded call carries only what the author
    #' passed, and a title invented from a variable name is not something a
    #' reader can act on.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return Character scalar, empty when the author wrote no title
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      recorded_main_title(layer_info$plot_call$args)
    },

    #' @description Address the tiles the chart drew.
    #'
    #' Measured on a rendered `mosaicplot(HairEyeColor[, , 1])`: gridGraphics
    #' draws one `-polygon-N` grob per cell and nothing else as a polygon --
    #' 16 grobs for a 4x4 table, with no frame among them. Their geometry
    #' says the order: `polygon-1` to `-4` share the leftmost column's x
    #' extent, `-5` to `-8` the next one's, and within a column the grob
    #' number runs down the fill levels in the table's own order. So the tile
    #' for row `f` of column `c` is the `(c - 1) * fills + f`th grob.
    #'
    #' The grobs are *found* rather than named by formula, and a short list
    #' is declined: a guessed id resolves to nothing at best and to another
    #' panel's tiles at worst, and a mosaic with no highlight still reads --
    #' the outcome #145 established for a layer with nothing to point at.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @param gt Gtable object to search
    #' @return List of selectors, one per cell, or empty when unresolvable
    generate_selectors = function(layer_info, gt = NULL) {
      table <- self$recorded_table(layer_info)
      if (is.null(table) || is.null(gt)) {
        return(list())
      }
      index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      categories <- nrow(table)
      fills <- ncol(table)
      tiles <- find_graphics_plot_grobs(gt, "polygon", index)
      if (length(tiles) < categories * fills) {
        return(list())
      }

      selectors <- list()
      for (fill_index in seq_len(fills)) {
        for (category_index in seq_len(categories)) {
          name <- tiles[[(category_index - 1) * fills + fill_index]]
          selectors[[length(selectors) + 1]] <- polygon_cell_selector(name)
        }
      }
      selectors
    }
  )
)
