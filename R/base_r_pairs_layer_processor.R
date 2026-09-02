#' Base R Scatterplot Matrix Processor
#'
#' Reads `pairs()` as the grid of scatters it draws: one panel per ordered
#' pair of columns, the column across plotted against the column down.
#'
#' **A grid, not a layer.** Every other base R processor answers with one
#' layer, or several layers in one cell. A scatterplot matrix is `n x n`
#' *panels*, which is the figure's shape rather than a layer's, so this one
#' answers with `multi_panel = TRUE` and places each layer at its own cell.
#' That is the shape the same chart already gets elsewhere: `sns.pairplot` in
#' py-maidr, and a plotly `splom` since xability/py-maidr#667.
#'
#' **The grid cannot come from the recording.** Measured, `pairs()` sets its
#' own `par(mfrow)` internally and restores it, so nothing lands in the
#' device's layout calls -- `get_layout_calls()` answers zero -- and
#' `detect_panel_configuration()` sees a single panel (#272). The grid is the
#' reading's own, derived from the number of columns.
#'
#' **The panels are numbered column-major.** Measured against a real
#' `grid.echo()` export of a three-column matrix, gridGraphics writes nine
#' `graphics-plot-N` groups -- one per cell, diagonal included -- and pairing
#' them with a `panel` that recorded what it was handed gives
#'
#'     k    cell     drawn
#'     1    (1,1)    text        the variable's name
#'     2    (2,1)    points      x = column 1, y = column 2
#'     3    (3,1)    points      x = column 1, y = column 3
#'     4    (1,2)    points      x = column 2, y = column 1
#'     5    (2,2)    text
#'     6    (3,2)    points      x = column 2, y = column 3
#'     7    (1,3)    points      x = column 3, y = column 1
#'     8    (2,3)    points      x = column 3, y = column 2
#'     9    (3,3)    text
#'
#' -- that is `k = (col - 1) * n + row`, and the panel at `(row, col)` plots
#' **column `col` horizontally against column `row` vertically**.
#'
#' **The diagonal has no layer.** A diagonal cell draws the variable's name
#' and nothing else, which the orchestrator already has an answer for: a cell
#' with no layers becomes a valid empty subplot. Giving it a histogram instead
#' would announce a chart `pairs()` does not draw -- its default `diag.panel`
#' draws nothing at all.
#'
#' @keywords internal
BaseRPairsLayerProcessor <- R6::R6Class(
  "BaseRPairsLayerProcessor",
  inherit = BaseRPointLayerProcessor,
  public = list(
    #' @description Emit one point layer per off-diagonal panel
    #' @param plot Unused; present for the processor interface.
    #' @param layout Unused; present for the processor interface.
    #' @param built Unused; present for the processor interface.
    #' @param gt Unused; the selectors are built rather than searched for.
    #' @param grob_id Unused; present for the processor interface.
    #' @param panel_id Unused; present for the processor interface.
    #' @param panel_ctx Unused; present for the processor interface.
    #' @param layer_info Layer information with the recorded call.
    #' @return A multi-panel result, or NULL when nothing was read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      columns <- self$extract_columns(info)
      if (length(columns) < 2) {
        return(NULL)
      }

      title <- self$extract_main_title(info)
      panels <- list()
      for (col in seq_along(columns)) {
        for (row in seq_along(columns)) {
          if (row == col) {
            next
          }
          layer <- self$panel_layer(columns, row, col, title)
          if (is.null(layer)) {
            next
          }
          panels[[length(panels) + 1]] <- list(
            row = row, col = col, layers = list(layer)
          )
        }
      }
      if (!length(panels)) {
        return(NULL)
      }

      list(
        multi_panel = TRUE,
        nrows = length(columns),
        ncols = length(columns),
        panels = panels
      )
    },

    #' @description The columns `pairs()` drew, with the names it wrote
    #'
    #' Read from the recorded call rather than re-derived. A formula call is
    #' resolved from the frame the recording kept (#254) rather than from the
    #' formula, whose variables may since have been rebound; the ordinary
    #' spelling hands over a data frame or a matrix, which is recorded by
    #' value and needs nothing.
    #'
    #' An unnamed matrix is labelled the way `pairs.default` labels it --
    #' measured against a real export, the diagonals of a two-column unnamed
    #' matrix read "var 1" and "var 2".
    #'
    #' A column that is not numeric is not a case to handle: `pairs()` itself
    #' stops with "non-numeric argument to 'pairs'" before anything is
    #' recorded.
    #'
    #' @param layer_info Layer information with the recorded call.
    #' @return A named list of numeric vectors, empty when nothing resolves
    extract_columns = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(list())
      }
      frame <- layer_info$plot_call$formula_frame
      handed <- if (!is.null(frame)) {
        frame
      } else {
        resolve_xy_args(layer_info$plot_call$args)$x
      }
      if (is.null(handed) || !length(dim(handed)) || length(dim(handed)) != 2) {
        return(list())
      }

      count <- ncol(handed)
      if (is.null(count) || count < 2) {
        return(list())
      }
      values <- lapply(seq_len(count), function(i) as.numeric(handed[, i]))
      if (!all(vapply(values, function(v) all(is.finite(v) | is.na(v)), logical(1)))) {
        return(list())
      }

      names(values) <- self$column_names(handed, count)
      values
    },

    #' @description The names `pairs()` writes down its diagonal
    #'
    #' @param handed The recorded data frame or matrix.
    #' @param count How many columns it has.
    #' @return One name per column
    column_names = function(handed, count) {
      declared <- colnames(handed)
      if (!is.null(declared) && length(declared) == count && all(nzchar(declared))) {
        return(as.character(declared))
      }
      paste("var", seq_len(count))
    },

    #' @description One panel's points, axes and selector
    #'
    #' A pair with a missing coordinate is dropped rather than announced.
    #' Measured, `pairs()` hands its panel the raw columns including `NA`,
    #' and `points()` then draws nothing for that pair -- so announcing it
    #' would offer a sample the chart does not draw (#170).
    #'
    #' @param columns The named columns.
    #' @param row Which column runs up the panel.
    #' @param col Which column runs across it.
    #' @param title The figure's own title.
    #' @return A layer, or NULL when the panel drew no points
    panel_layer = function(columns, row, col, title) {
      x <- columns[[col]]
      y <- columns[[row]]
      keep <- !is.na(x) & !is.na(y)
      if (!any(keep)) {
        return(NULL)
      }
      x <- x[keep]
      y <- y[keep]

      list(
        data = lapply(seq_along(x), function(i) list(x = x[i], y = y[i])),
        selectors = self$panel_selectors(row, col, length(columns)),
        axes = build_axes(x = names(columns)[col], y = names(columns)[row]),
        title = title,
        type = "point"
      )
    },

    #' @description The marks one panel was drawn into
    #'
    #' Built rather than searched for, from the column-major numbering in the
    #' class docs. `find_graphics_plot_grob()` answers with the first `points`
    #' grob of the plot, and a scatterplot matrix draws one per cell, so a
    #' search would give every panel the first cell's marks.
    #'
    #' Numbered from one because a call that declares its own grid is the only
    #' thing on the page: `pairs()` takes over the device's layout, and the
    #' orchestrator reads a grid from a single call only.
    #'
    #' @param row Which column runs up the panel.
    #' @param col Which column runs across it.
    #' @param count How many columns there are.
    #' @return A one-element list of selectors
    panel_selectors = function(row, col, count) {
      index <- (col - 1) * count + row
      list(paste0("g#graphics-plot-", index, "-points-1\\.1 > use"))
    }
  )
)
