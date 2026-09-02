#' Base R Association Plot Layer Processor
#'
#' Processes Base R `assocplot()` layers -- a Cohen--Friendly association
#' plot, which draws one tile per cell of a two-way table whose signed height
#' is that cell's Pearson residual, `(observed - expected) / sqrt(expected)`.
#'
#' Read as a `heat` layer, because a named grid of one number per cell is what
#' the chart states and row-then-column is how a reader navigates a
#' contingency table. Measured on `assocplot(HairEyeColor[, , 1])`, the rects
#' the drawing produces carry the residuals exactly:
#'
#' \preformatted{
#'        Brown    Blue   Hazel   Green
#' Black  2.780  -2.059   0.184  -1.408
#' Brown  0.391  -0.246   0.185  -0.465
#' Red   -0.562  -0.658   0.532   1.485
#' Blond -3.273   3.271  -0.988   1.097
#' }
#'
#' Nothing is inferred from the drawing: `assocplot()` is handed the table, so
#' the recorded call carries every number the trace wants. It returns `NULL`,
#' which is why the reading comes from the argument -- the shape `bxp()`'s
#' reading took in #265.
#'
#' ## Two things this deliberately does not do
#'
#' **The tile width is dropped.** Each tile is drawn `sqrt(expected)` wide, so
#' the marginals are on the chart as a second encoding. A `heat` layer has no
#' width, and the residual is what an association plot exists to show -- the
#' eye reads height and sign, and the width is why a cell's box is wider
#' rather than a value the reader is asked to compare. Announcing it in `z`
#' instead would replace the number the chart is about.
#'
#' **It is not a `mosaic`.** `mosaicplot()` is read as one and the two look
#' alike, but a mosaic's tiles tile the space and carry proportions of a
#' whole. These float above and below a baseline and carry residuals, which
#' are signed and sum to nothing. Calling it a mosaic would tell a reader the
#' areas are shares of a total when they are a departure from an expectation.
#'
#' @keywords internal
BaseRAssocplotLayerProcessor <- R6::R6Class(
  "BaseRAssocplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the association plot layer.
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
      data <- self$extract_data(layer_info)
      list(
        data = data,
        selectors = self$generate_selectors(layer_info, gt, data),
        type = "heat",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info),
        domMapping = list(order = "row")
      )
    },
    needs_reordering = function() {
      FALSE
    },

    #' @description Read the residual grid out of the recorded call.
    #'
    #' The grid is the table **transposed**, and its rows reversed. That is
    #' not a convention chosen here but the relation `assocplot()` has to its
    #' argument, measured from the drawn rects: the first dimension runs
    #' across the x axis and the second up the y axis, bottom to top. It is
    #' the same relation `image()` has to its matrix, and the heatmap
    #' processor transposes for the same reason.
    #'
    #' A table with a zero margin has cells whose expected count is zero, and
    #' a residual there is `0/0`. `assocplot()` draws nothing for such a cell;
    #' the grid has to keep a place for it, so it carries 0 -- the departure
    #' from an expectation of nothing being nothing.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return List with points, x and y, empty when there is no table
    extract_data = function(layer_info) {
      table <- self$recorded_table(layer_info)
      if (is.null(table)) {
        return(list(points = list(), x = list(), y = list()))
      }

      residuals <- self$pearson_residuals(table)
      # Rows of the emitted grid are the SECOND dimension, and they are NOT
      # reversed: measured, the band at the top of the drawing is the table's
      # FIRST column, and the grid reads top-down. What the drawing reverses
      # is the order the rects arrive in, which the selectors undo.
      row_names <- colnames(table)
      col_names <- rownames(table)

      points <- lapply(seq_along(row_names), function(r) {
        lapply(seq_along(col_names), function(c) {
          as.numeric(residuals[c, r])
        })
      })

      list(
        points = points,
        x = as.list(as.character(col_names)),
        y = as.list(as.character(row_names))
      )
    },

    #' @description The Pearson residual of every cell.
    #'
    #' `(observed - expected) / sqrt(expected)`, with the expected counts
    #' taken from the margins the same way `assocplot()` takes them.
    #'
    #' @param table A two-way table
    #' @return A numeric matrix of the same shape
    pearson_residuals = function(table) {
      counts <- matrix(
        as.numeric(table),
        nrow = nrow(table),
        ncol = ncol(table)
      )
      total <- sum(counts)
      if (!is.finite(total) || total <= 0) {
        return(matrix(0, nrow = nrow(counts), ncol = ncol(counts)))
      }
      expected <- outer(rowSums(counts), colSums(counts)) / total
      residuals <- (counts - expected) / sqrt(expected)
      # A zero margin makes `expected` zero and the residual `0/0`. The chart
      # draws no tile there; the grid keeps the cell and calls it 0.
      residuals[!is.finite(residuals)] <- 0
      residuals
    },

    #' @description The two-way table the call was handed, when it is one.
    #'
    #' Only a two-dimensional table is read. `assocplot()` itself accepts no
    #' more -- it stops on anything else -- so this declines the same inputs
    #' the function does.
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
    #' `assocplot()` labels its axes with `names(dimnames(x))` unless the
    #' author overrides them, so those are the words a reader should be given.
    #' `z` names what the numbers are rather than a dimension of the table:
    #' the grid holds residuals, and a reader told "Eye" for the value would
    #' be told a level name where a number is.
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
        y = recorded_axis_label(args, "ylab", dimension(2)),
        z = "Pearson residual"
      )
    },

    #' @description The title the call was given, if any.
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
    #' `assocplot()` draws every cell into ONE rect grob -- measured, a 4x4
    #' table gives `graphics-plot-N-rect-1` holding sixteen rects -- so the
    #' cells need no picking out of the drawing the way a gantt's bars do.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @param gt Gtable object (optional)
    #' @param extracted_data The grid this layer emitted
    #' @return List of selectors, one per cell
    generate_selectors = function(layer_info, gt = NULL, extracted_data = NULL) {
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }
      container <- paste0("g#graphics-plot-", group_index, "-rect-1")

      n_rows <- length(extracted_data$points)
      if (n_rows == 0) {
        return(list())
      }
      n_cols <- length(extracted_data$points[[1]])

      # The rects arrive bottom band first, left to right within a band --
      # measured from their coordinates. Row 0 of the emitted grid is the TOP
      # band, so the nth-of-type runs up from the bottom.
      lapply(seq_len(n_rows), function(r) {
        lapply(seq_len(n_cols), function(c) {
          nth <- (n_rows - r) * n_cols + c
          paste0(container, " > rect:nth-of-type(", nth, ")")
        })
      })
    }
  )
)
