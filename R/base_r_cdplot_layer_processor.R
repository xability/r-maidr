#' Base R Conditional Density Plot Layer Processor
#'
#' Reads `cdplot()` as the 100% stacked area chart it draws.
#'
#' A conditional density plot shows, for each value of a numeric `x`, how the
#' levels of a factor `y` divide up: the bands are stacked, they fill the
#' whole height, and their shares sum to 1 at every x. That is a normalized
#' stacked area, which `Ggplot2AreaLayerProcessor` already emits for
#' `position = "fill"`, so a `cdplot()` is read as
#' `stacked_normalized_area` and the two adapters describe one chart the
#' same way -- each series a list of `{x, y, z}` where `y` is the band's own
#' share and `z` names the level, and one selector per band.
#'
#' Before this, `cdplot()` had no branch in `detect_layer_type()`, so the
#' switch fell through to `"unknown"` and the chart degraded to a static
#' image (#216, #251).
#'
#' ## Where the curves come from
#'
#' `cdplot()` has a `plot` argument, so it can be asked for what it drew
#' without drawing it again. It returns the **boundaries** between the bands:
#' `nlevels(y) - 1` functions, each `approxfun()` over the density grid,
#' named for the level *below* the boundary.
#'
#' \preformatted{
#' rval <- cdplot(x, y, plot = FALSE)
#' names(rval)          # "c" "b"   for a factor with levels a, b, c
#' rval[[1]](50)        # the cumulative share at x = 50
#' }
#'
#' Stacking them the way `cdplot()` does -- `rbind(0, boundaries, 1)`, band
#' `i` running from row `i` to row `i + 1` -- gives the shares back. Measured
#' over three hundred random charts, every column's shares sum to 1 and no
#' band comes out negative, so the boundaries do not cross in the drawn
#' range.
#'
#' `graphics::cdplot` by the qualified name, not the bare one: maidr patches
#' the name on the search path, and a bare call would record the replay as a
#' second chart. The same line `BaseRSpineplotLayerProcessor` draws.
#'
#' ## Which x values were drawn
#'
#' The returned functions interpolate over the density grid, which
#' `stats::density()` pads past the data by three bandwidths. `cdplot()`
#' throws that padding away before drawing:
#'
#' \preformatted{
#' y1 <- y1[, which(x1 >= min(x) & x1 <= max(x))]
#' x1 <- x1[x1 >= min(x) & x1 <= max(x)]
#' }
#'
#' so the announced grid is trimmed the same way -- 372 of the 512 points on
#' a measured chart. Announcing the untrimmed grid would put readings either
#' side of the data at x values the chart has no marks at.
#'
#' The grid itself is read off the first returned function rather than
#' recomputed: `approxfun()` keeps its knots, and `environment(f)$x` is the
#' grid `cdplot()` built. Recomputing `density()` here would have to guess
#' `bw`, `n`, `from`, `to` and `weights` back out of the recorded call, and
#' a guess that differed by one point would shift every reading.
#'
#' ## What the replay proves
#'
#' A `cdplot()` that returned rather than stopping has already established
#' most of what a reader here would otherwise have to check, because
#' `cdplot()` checks it first and stops. Each was measured:
#'
#' \itemize{
#'   \item `y` is a factor -- "dependent variable should be a factor";
#'   \item `x` is finite -- `stats::density()` stops on a missing or
#'     infinite value;
#'   \item a formula names exactly two variables -- "'formula' should
#'     specify exactly two variables";
#'   \item the grid overlaps the data -- a `from`/`to` that put it elsewhere
#'     stops with "need at least two non-NA values to interpolate";
#'   \item the factor has at least two levels -- one stops with "subscript
#'     out of bounds".
#' }
#'
#' The NULL checks that remain below are therefore not checking any of that.
#' They are there so that a shape none of the above rules out cannot *throw*
#' out of the pipeline, where declining to read leaves the static image the
#' figure produces today. Where a check would only repeat one another check
#' already makes, it is not written twice.
#'
#' @keywords internal
BaseRCdplotLayerProcessor <- R6::R6Class(
  "BaseRCdplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Build the layer
    #' @param plot,layout,built,gt,grob_id,panel_id,panel_ctx Pipeline arguments
    #' @param layer_info The recorded call
    #' @return List with data, selectors, type, title and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      series <- self$extract_data(layer_info)

      list(
        data = series,
        selectors = self$generate_selectors(layer_info, gt, length(series)),
        type = "stacked_normalized_area",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info)
      )
    },

    #' @description One series per band, bottom to top
    #'
    #'   Bottom to top because that is the order `cdplot()` draws its
    #'   polygons in, and the selector list is positional against those
    #'   polygons.
    #' @param layer_info The recorded call
    #' @return A list of series, each a list of `{x, y, z}` points
    extract_data = function(layer_info) {
      bands <- self$drawn_bands(layer_info)
      if (is.null(bands)) {
        return(list())
      }

      lapply(seq_along(bands$levels), function(i) {
        level <- bands$levels[[i]]
        share <- bands$shares[i, ]
        lapply(seq_along(bands$x), function(j) {
          list(
            x = as.numeric(bands$x[[j]]),
            # The band's own share, not the cumulative boundary above it:
            # the consumer sums the series itself to reach the running
            # total, and would otherwise accumulate an accumulation.
            y = as.numeric(share[[j]]),
            z = level
          )
        })
      })
    },

    #' @description The grid, the band names and their shares, or NULL
    #'
    #'   NULL rather than an empty list when the call cannot be read, so
    #'   every caller degrades the same way: no data, no selectors, and the
    #'   figure falls back to the static image it produces today.
    #' @param layer_info The recorded call
    #' @return A list of `x`, `levels` and `shares` (a bands-by-points
    #'   matrix), or NULL
    drawn_bands = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      args <- layer_info$plot_call$args
      if (!is.list(args) || !length(args)) {
        return(NULL)
      }

      boundaries <- self$replay(args)
      if (is.null(boundaries) || !length(boundaries)) {
        return(NULL)
      }

      grid <- self$drawn_grid(boundaries, args)
      if (is.null(grid)) {
        return(NULL)
      }

      levels <- self$band_levels(boundaries, args)
      if (is.null(levels)) {
        return(NULL)
      }

      cumulative <- tryCatch(
        t(vapply(
          boundaries,
          function(f) as.numeric(f(grid)),
          numeric(length(grid))
        )),
        error = function(e) NULL
      )
      if (is.null(cumulative)) {
        return(NULL)
      }

      # `cdplot()`'s own stacking: the baseline below the first band and the
      # ceiling above the last are not boundaries it computes, they are the
      # 0 and 1 the chart is drawn between.
      edges <- rbind(0, cumulative, 1)
      shares <- edges[-1L, , drop = FALSE] - edges[-nrow(edges), , drop = FALSE]

      list(x = grid, levels = levels, shares = shares)
    },

    #' @description Ask `cdplot()` what it drew, without drawing it
    #' @param args The recorded call's arguments
    #' @return The list of boundary functions, or NULL
    replay = function(args) {
      # A `plot` the caller wrote themselves would otherwise be matched
      # ahead of ours and the chart drawn a second time.
      args <- args[names(args) != "plot"]

      value <- tryCatch(
        suppressWarnings(
          do.call(graphics::cdplot, c(args, list(plot = FALSE)))
        ),
        error = function(e) NULL
      )
      if (!is.list(value) || !length(value)) {
        return(NULL)
      }
      value
    },

    #' @description The x values the bands were drawn over
    #' @param boundaries The replayed boundary functions
    #' @param args The recorded call's arguments
    #' @return A numeric vector, or NULL
    drawn_grid = function(boundaries, args) {
      grid <- tryCatch(
        get("x", envir = environment(boundaries[[1L]])),
        error = function(e) NULL
      )
      if (!is.numeric(grid)) {
        return(NULL)
      }

      predictor <- self$predictor(args)
      if (is.null(predictor)) {
        return(NULL)
      }

      kept <- grid >= min(predictor) & grid <= max(predictor)
      # Not reachable through a call `cdplot()` itself accepted: the grid is
      # the one it built from this same `x`, so it spans the data by
      # construction, and a `from`/`to` that put it elsewhere makes
      # `cdplot()` stop with "need at least two non-NA values to
      # interpolate" before the replay returns. Kept because what it stands
      # between is a layer announcing a series with no points in it.
      if (sum(kept) < 2L) {
        return(NULL)
      }
      grid[kept]
    },

    #' @description The band names, bottom to top
    #'
    #'   `cdplot()` names its boundaries for every level but the topmost, so
    #'   the one it does not name is the one level of the response that is
    #'   left. Derived that way rather than by reproducing the `ylevels`
    #'   argument's reordering, which is `cdplot()`'s to define.
    #'
    #'   Declines unless exactly one level is left over. That is the one
    #'   guard the step needs, and it does double duty: an `ylevels` naming a
    #'   strict subset of the factor's levels leaves two over -- measured,
    #'   `ylevels = c("a", "b")` on a three-level factor -- and unnamed
    #'   boundaries would leave every level over. Either way the reading
    #'   would be missing a band, and every selector after it would point at
    #'   its neighbour.
    #'
    #'   An empty level name is *not* declined. `factor(x, levels = c("b",
    #'   ""))` is a level like any other, `setdiff()` matches it like any
    #'   other, and the chart draws a band for it -- so it is announced with
    #'   the empty name the axis shows rather than dropped.
    #' @param boundaries The replayed boundary functions
    #' @param args The recorded call's arguments
    #' @return A character vector, or NULL
    band_levels = function(boundaries, args) {
      named <- names(boundaries)
      # `levels(NULL)` is NULL and `setdiff(NULL, named)` is empty, so a
      # response that could not be read leaves nothing over and is declined
      # by the count below rather than by a check of its own.
      top <- setdiff(levels(self$response(args)), named)
      if (length(top) != 1L) {
        return(NULL)
      }

      c(named, top)
    },

    #' @description The numeric variable on the x axis
    #' @param args The recorded call's arguments
    #' @return A numeric vector, or NULL
    predictor = function(args) {
      variables <- self$variables(args)
      if (is.null(variables) || !is.numeric(variables$x)) {
        return(NULL)
      }
      # Finite by the time this runs: `stats::density()` stops on a missing
      # or infinite value, so a call the replay returned from had none.
      variables$x
    },

    #' @description The factor whose levels the bands are
    #' @param args The recorded call's arguments
    #' @return A factor, or NULL
    response = function(args) {
      # A factor by the time this runs: `cdplot()` stops with "dependent
      # variable should be a factor" otherwise, so the replay would already
      # have failed.
      self$variables(args)$y
    },

    #' @description The two variables the call was given, whichever form it took
    #'
    #'   `cdplot()` has two methods and they name their variables
    #'   differently: `cdplot(x, y)` and `cdplot(y ~ x, data)`. The formula
    #'   method builds a model frame and takes the response from column one
    #'   and the predictor from column two, which is reproduced here because
    #'   the recorded call carries the formula rather than the frame.
    #'
    #'   Memoised. `process()` reaches this three times -- through
    #'   `response()`, through `predictor()` and again for the axis names --
    #'   and on the formula path each ask would rebuild a model frame and
    #'   re-apply the subset. The same call `BaseRSpineplotLayerProcessor`
    #'   makes about its replayed table, for the same reason. Nothing
    #'   observable changes, which is why this is written down rather than
    #'   left to be rediscovered.
    #' @param args The recorded call's arguments
    #' @return A list of `x`, `y` and `names`, or NULL
    variables = function(args) {
      if (!is.null(private$resolved)) {
        return(private$resolved)
      }

      formula <- Find(function(a) inherits(a, "formula"), args)
      private$resolved <- if (is.null(formula)) {
        self$default_variables(args)
      } else {
        self$formula_variables(formula, args[["data"]], args[["subset"]])
      }
      private$resolved
    },

    #' @description The variables of a `cdplot(x, y)` call
    #' @param args The recorded call's arguments
    #' @return A list of `x`, `y` and `names`, or NULL
    default_variables = function(args) {
      slots <- list(x = args[["x"]], y = args[["y"]])
      arg_names <- names(args)
      unnamed <- if (is.null(arg_names)) {
        seq_along(args)
      } else {
        which(!nzchar(arg_names))
      }
      unclaimed <- names(slots)[vapply(slots, is.null, logical(1))]
      for (i in seq_along(unnamed)) {
        if (i > length(unclaimed)) {
          break
        }
        slots[[unclaimed[[i]]]] <- args[[unnamed[[i]]]]
      }

      if (is.null(slots$x) || is.null(slots$y)) {
        return(NULL)
      }
      # No names to offer: `cdplot()` deparses the caller's expressions for
      # its axis labels, and the wrapper records evaluated values.
      list(x = as.numeric(slots$x), y = slots$y, names = NULL)
    },

    #' @description The variables of a `cdplot(y ~ x, data)` call
    #'
    #'   `subset` is carried through, because `cdplot.formula` builds its
    #'   model frame with it and everything downstream is the subset's:
    #'   measured on `cdplot(b ~ a, data = d, subset = a > 45)`, the chart
    #'   draws over 46.1 to 70.9 while the whole column runs from 25.5. Read
    #'   without the subset, the grid would be trimmed to the wider range and
    #'   a fifth of the announced points would sit left of the leftmost mark.
    #' @param formula The recorded formula
    #' @param data The recorded data, if any
    #' @param subset The recorded subset, if any
    #' @return A list of `x`, `y` and `names`, or NULL
    formula_variables = function(formula, data, subset = NULL) {
      frame <- tryCatch(
        {
          # `na.pass`, then subset, then drop the missing rows -- which is
          # the order `model.frame()` itself applies them in, and the order
          # `cdplot.formula` therefore gets. Letting the default `na.omit`
          # run first is what makes this wrong: it shrinks the frame, and a
          # `subset` recorded against the *unfiltered* data then indexes past
          # the end. Measured on 80 rows with three NAs and a subset of
          # length 80, the frame came back with 77 and `built[subset, ]`
          # padded the overrun with NA rows rather than erroring; the NA
          # reached `min()` in `drawn_grid()`, and `if (sum(kept) < 2L)`
          # raised "missing value where TRUE/FALSE needed" out of
          # `process()` -- which nothing above catches, so the whole render
          # went down instead of this one layer declining.
          built <- stats::model.frame(
            formula,
            data = if (is.null(data)) list() else data,
            na.action = stats::na.pass
          )
          # Indexed here rather than handed to `model.frame(subset =)`, which
          # substitutes its argument and evaluates the expression inside
          # `data` -- and the recorded call carries the already-evaluated
          # vector, which is not a name `data` knows. Measured: that route
          # returns an empty frame and every reading with it.
          selected <- if (is.null(subset)) built else built[subset, , drop = FALSE]
          stats::na.omit(selected)
        },
        error = function(e) NULL
      )
      # Only the NULL, which would otherwise throw on the column read. An
      # empty frame gives an empty predictor, which `drawn_grid()` declines.
      if (is.null(frame)) {
        return(NULL)
      }
      # Exactly two columns whenever the replay returned: `cdplot.formula`
      # stops with "'formula' should specify exactly two variables"
      # otherwise, and `weights` travels beside the frame rather than in it.
      list(
        x = as.numeric(frame[[2L]]),
        y = frame[[1L]],
        # `cdplot.formula` labels its axes with exactly these, so a formula
        # call has real names to offer where the default method does not.
        names = names(frame)
      )
    },

    #' @description Name the axes
    #'
    #'   The band's number is a share of the column, not a position on the
    #'   drawn y axis -- which carries the level names, and is the *fill*
    #'   dimension shown positionally. So `ylab` names `z` and `y` says what
    #'   its numbers are, the same split `BaseRMosaicLayerProcessor` makes
    #'   for the same reason.
    #' @param layer_info The recorded call
    #' @return An axes payload
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(build_axes(y = "Proportion"))
      }

      args <- layer_info$plot_call$args
      named <- if (is.list(args)) self$variables(args)$names else NULL
      column <- function(i) {
        if (length(named) >= i && nzchar(named[[i]])) named[[i]] else NULL
      }

      build_axes(
        x = recorded_axis_label(args, "xlab", column(2)),
        y = "Proportion",
        z = recorded_axis_label(args, "ylab", column(1))
      )
    },

    #' @description The chart's own title, where the call gave one
    #' @param layer_info The recorded call
    #' @return The title, or an empty string
    extract_main_title = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return("")
      }
      title <- recorded_axis_label(layer_info$plot_call$args, "main")
      if (is.null(title)) "" else title
    },

    #' @description Address each band by the polygon that drew it
    #'
    #'   `cdplot()` writes one `polygon` grob per band, in draw order, which
    #'   is the bottom-to-top order the series are in. The frame it draws
    #'   around the plot is a polygon too, but gridGraphics names it
    #'   `-box-1` rather than `-polygon-N`, so the anchored pattern does not
    #'   collect it.
    #'
    #'   Withheld entirely when the counts disagree, for the reason every
    #'   processor here gives: a partial list hands a band its neighbour's
    #'   element, and a user cannot tell that apart from a correct one.
    #' @param layer_info The recorded call
    #' @param gt The grob tree
    #' @param n_series How many bands the data reports
    #' @return A list of CSS selectors, one per band
    generate_selectors = function(layer_info, gt = NULL, n_series = 0L) {
      # No check for a missing grob tree: the search finds no grobs in one,
      # and a count of zero against a real series count is declined below.
      if (n_series < 1L) {
        return(list())
      }

      index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      bands <- find_graphics_plot_grobs(gt, "polygon", index)
      if (length(bands) != n_series) {
        return(list())
      }

      lapply(bands, polygon_cell_selector)
    }
  ),
  private = list(
    resolved = NULL
  )
)
