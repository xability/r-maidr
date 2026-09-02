#' Base R Spine Plot Layer Processor
#'
#' Reads `spineplot()` as the two-way contingency table it draws.
#'
#' A spine plot is a mosaic of one categorical axis against another: one
#' column per level of `x`, its **width** that level's share of all
#' observations, split vertically by `y`'s conditional proportions inside it.
#' That is the shape `BaseRMosaicLayerProcessor` was written for in #247 --
#' "the column widths encode data too" -- so a spine plot is read as a
#' `mosaic` layer, and this class changes only the two things that differ.
#'
#' **Where the table comes from.** `mosaicplot()` is handed its table, so the
#' recorded call carries it. `spineplot()` is handed the two variables and
#' builds the table itself, and it has **no `plot` argument** to be asked for
#' the table without drawing -- `cdplot()` has one, `spineplot()` does not.
#' But it *returns* what it drew:
#'
#' \preformatted{
#' spineplot(table(f, g))
#' #       g
#' # f      no yes
#' #   low  11  12
#' #   mid   7  14
#' #   high 12   4
#' }
#'
#' so the call is replayed on a throwaway device and the return value taken.
#' `graphics::spineplot` by the qualified name, not the bare one: maidr
#' patches the name on the search path, and the bare call would record the
#' replay as a second chart. Reproducing the binning by hand instead would be
#' a re-derivation -- `spineplot` cuts a numeric `x` by its own rule -- and
#' the point of every reading in this package is that the library is asked
#' rather than imitated.
#'
#' **Where the tiles are.** `mosaicplot()` writes one `polygon` grob per
#' cell. `spineplot()` writes **one `rect` grob for the whole panel**, and
#' gridSVG exports it as one `<rect>` element per tile. Measured on a 3x2
#' table:
#'
#' \preformatted{
#' graphics-plot-1-rect-1.1.1   x  59.04   w 152.86   h 118.71
#' graphics-plot-1-rect-1.1.2   x  59.04   w 152.86   h 108.81
#' graphics-plot-1-rect-1.1.3   x 219.88   w 139.57   h 151.68
#' graphics-plot-1-rect-1.1.4   x 219.88   w 139.57   h  75.84
#' graphics-plot-1-rect-1.1.5   x 367.42   w 106.34   h  56.88
#' graphics-plot-1-rect-1.1.6   x 367.42   w 106.34   h 170.64
#' }
#'
#' Six elements for six cells, sharing an x within a column, and the widths
#' 152.86 : 139.57 : 106.34 in the marginals' own ratio 23 : 21 : 16. The
#' order is column-major, and **within a column the last fill level is drawn
#' first**: the heights pair 118.71 : 108.81 with 12 : 11, which is `yes`
#' above `no`. That is the opposite of the mosaic's ascending order, which is
#' why the index is computed here rather than inherited.
#'
#' **A zero cell still draws.** The hazard this shape invites is the one
#' xability/maidr#1002 found elsewhere: a count of zero skipped rather than
#' drawn, shifting every later tile's index by one. Measured on a table with
#' a genuine zero in it, `spineplot` draws the tile anyway with `height="0"`,
#' so the positional pairing holds. There is a test for exactly that.
#'
#' @keywords internal
BaseRSpineplotLayerProcessor <- R6::R6Class(
  "BaseRSpineplotLayerProcessor",
  inherit = BaseRMosaicLayerProcessor,
  public = list(
    #' @description The table `spineplot()` drew, by replaying the call
    #'
    #'   Memoised, because `process()` asks for it three times -- once for
    #'   the data, once for the axis names and once for the selectors -- and
    #'   each ask would otherwise open a device and draw the chart again.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return A 2-D table, or NULL when the call cannot be replayed
    recorded_table = function(layer_info) {
      if (!is.null(private$drawn_table)) {
        return(private$drawn_table)
      }
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      args <- layer_info$plot_call$args
      if (!is.list(args) || !length(args)) {
        return(NULL)
      }
      args <- spineplot_written_axis_names(args, layer_info$call_expr)

      grDevices::pdf(NULL)
      on.exit(grDevices::dev.off(), add = TRUE)
      drawn <- tryCatch(
        suppressWarnings(do.call(graphics::spineplot, args)),
        error = function(e) NULL
      )

      # Only the names are checked. `spineplot` stops with "a 2-way table has
      # to be specified" on anything that is not one -- measured, on a 3-D
      # table and on a bare vector alike -- so a shape guard here would be a
      # branch no input can reach. An *unnamed* matrix does draw, and is
      # declined for the reason the mosaic declines one: categories with no
      # names have nothing to announce.
      if (is.null(drawn) || is.null(rownames(drawn)) || is.null(colnames(drawn))) {
        return(NULL)
      }
      private$drawn_table <- as.table(drawn)
      private$drawn_table
    },

    #' @description Address the tile each cell was drawn into
    #'
    #'   One `rect` grob holds the whole panel, so the tiles are its
    #'   sub-elements rather than grobs of their own and are addressed by
    #'   their exported ids. The grob is *found* rather than named by
    #'   formula, and a panel that does not hold exactly one is declined: a
    #'   guessed id resolves to nothing at best and to another panel's tiles
    #'   at worst, and a spine plot with no highlight still reads (#145).
    #'
    #'   The index runs column-major with the fill levels **descending**
    #'   inside a column, which is the order measured off the drawing and
    #'   recorded in the class note. The emitted list is in the payload's own
    #'   order -- all categories of the first fill, then the second -- so the
    #'   two line up.
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

      panels <- find_graphics_plot_grobs(gt, "rect", index)
      if (length(panels) != 1) {
        return(list())
      }
      panel <- panels[[1]]

      categories <- nrow(table)
      fills <- ncol(table)
      selectors <- list()
      for (fill_index in seq_len(fills)) {
        for (category_index in seq_len(categories)) {
          drawn_at <- (category_index - 1) * fills + (fills - fill_index + 1)
          selectors[[length(selectors) + 1]] <-
            rect_cell_selector(panel, drawn_at)
        }
      }
      selectors
    }
  ),
  private = list(
    drawn_table = NULL
  )
)

#' Name a replayed `spineplot(x, y)`'s axes the way the caller's call did
#'
#' `spineplot.default()` titles its axes `deparse1(substitute(x))` and
#' `deparse1(substitute(y))` when no `xlab`/`ylab` is given. Replayed through
#' `do.call()` on the recorded *values*, the substitute is the data itself,
#' and a reader was told the axis was called `c(1, 2, 3, ...)` for as many
#' characters as the vector took to write. The names the caller wrote are in
#' the recorded call text, so they are matched against the default method's
#' formals and passed as the titles. A table or a formula names its own
#' axes and is left alone.
#'
#' @param args Recorded argument list
#' @param call_expr The recorded call, deparsed
#' @return `args`, with `xlab`/`ylab` filled in where the call named them
#' @keywords internal
spineplot_written_axis_names <- function(args, call_expr) {
  if (!is.character(call_expr) || anyNA(call_expr)) {
    return(args)
  }
  written <- tryCatch(
    parse(text = call_expr, keep.source = FALSE)[[1]],
    error = function(e) NULL
  )
  if (!is.call(written)) {
    return(args)
  }
  method <- utils::getS3method("spineplot", "default", envir = asNamespace("graphics"))
  written <- tryCatch(match.call(method, written), error = function(e) NULL)
  if (is.null(written) || is.null(written$y)) {
    return(args)
  }
  if (is.null(args$xlab)) {
    args$xlab <- deparse1(written$x)
  }
  if (is.null(args$ylab)) {
    args$ylab <- deparse1(written$y)
  }
  args
}

#' Address one tile of a grob that draws a whole panel of them
#'
#' gridSVG exports a `rect` grob holding several rectangles as one group of
#' `<rect>` elements, each with its own id: `<grob>.1.<n>`, counted from one
#' in draw order. A spine plot's panel is the case that needs it.
#'
#' @param grob_name The grob holding the tiles
#' @param drawn_at Which tile, counted in draw order from one
#' @return A CSS selector matching exactly that tile
#' @keywords internal
rect_cell_selector <- function(grob_name, drawn_at) {
  escaped <- gsub("\\.", "\\\\.", paste0(grob_name, ".1.", drawn_at))
  paste0("#", escaped)
}
