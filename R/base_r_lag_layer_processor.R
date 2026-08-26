#' Base R Lag Plot Processor
#'
#' Reads `lag.plot()` as the grid of scatters it draws: one panel per series
#' and lag, the series plotted against a shifted copy of itself.
#'
#' **A grid, not a layer.** Like `pairs()`, this call lays out its own panels
#' and hands nothing to the device's layout calls, so the grid has to come
#' from the reading. It answers `multi_panel = TRUE` and places each layer at
#' its own cell.
#'
#' **What a panel pairs.** Measured by tracing `graphics::plot.xy` through a
#' real call -- the panel is `plot(lag(X, k), X)`, and `lag()` shifts the time
#' base *back*, so the pair at time `t` is
#'
#'     x = X[t + k]      the later reading, across
#'     y = X[t]          the earlier one, up
#'
#' over every `t` where both indices land inside the series. A negative lag
#' works out of the same expression and was measured too: `set.lags = -1`
#' gives `x = X[1..n-1]` against `y = X[2..n]`, and `set.lags = 0` gives the
#' series against itself.
#'
#' **The panels are numbered in draw order.** The nested loop runs series
#' outermost and lag innermost, and `par(mfrow)` fills row by row -- measured
#' against a `grid.echo()` export, a two-column matrix at `lags = 2` writes
#' `graphics-plot-1` through `graphics-plot-4` for `(a,1) (a,2) (b,1) (b,2)`.
#' So panel `k` sits at row `(k - 1) %/% ncols + 1`, column
#' `(k - 1) %% ncols + 1`.
#'
#' **A panel's marks are symbols or labels, and `labels` decides which.**
#' `lag.plot()` writes the time index at each pair rather than a symbol when
#' `labels` is true, and `labels` defaults to `do.lines`, which defaults to
#' `n <= 150` -- so the *default* chart is the labelled one. Measured, the
#' four combinations give:
#'
#'     labels  do.lines   grobs in a panel
#'     FALSE   FALSE      points
#'     FALSE   TRUE       points, lines
#'     TRUE    FALSE      text
#'     TRUE    TRUE       text, brokenline
#'
#' So `do.lines` only adds the joining line and `labels` alone decides the
#' mark, which is why the two are read separately rather than through the
#' default that ties them together.
#'
#' Both marks can be outlined, and the export is what says so. Measured on a
#' real `save_html()` of a labelled call, the text grob comes out as one
#' group per pair, in data order:
#'
#'     <g id="graphics-plot-1-text-1.1">
#'       <g id="graphics-plot-1-text-1.1.1" transform="translate(254.32, …)">
#'       <g id="graphics-plot-1-text-1.1.2" transform="translate(221.70, …)">
#'
#' which is the same shape a `points` grob has, with `use` elements replaced
#' by nested `g`s. So the selector differs only in the grob name and the
#' child it reaches for.
#'
#' @keywords internal
BaseRLagLayerProcessor <- R6::R6Class(
  "BaseRLagLayerProcessor",
  inherit = BaseRPointLayerProcessor,
  public = list(
    #' @description Emit one point layer per drawn panel
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
      series <- private$series(info)
      lags <- private$set_lags(info)
      if (!length(series) || !length(lags)) {
        return(NULL)
      }

      shape <- private$shape(info, length(series))
      labelled <- private$labelled(info, series)
      title <- self$extract_main_title(info)

      panels <- list()
      index <- 0
      for (i in seq_along(series)) {
        for (lag in lags) {
          index <- index + 1
          layer <- private$panel_layer(series, i, lag, index, labelled, title)
          if (is.null(layer)) {
            next
          }
          panels[[length(panels) + 1]] <- list(
            row = (index - 1) %/% shape$ncols + 1,
            col = (index - 1) %% shape$ncols + 1,
            layers = list(layer)
          )
        }
      }
      if (!length(panels)) {
        return(NULL)
      }

      list(
        multi_panel = TRUE,
        nrows = shape$nrows,
        ncols = shape$ncols,
        panels = panels
      )
    }
  ),
  private = list(
    # The series the call was handed, with the names it wrote down each panel.
    #
    # `lag.plot()` reads `nser` off `as.ts(as.matrix(x))`, so a plain vector
    # is one series and a matrix or data frame is one per column. The name is
    # the column's when the caller handed a matrix and the deparsed argument
    # when they handed a vector -- which is what `deparse1(substitute(x))`
    # takes, and the recorded call keeps the source text it needs.
    series = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(list())
      }
      handed <- resolve_xy_args(layer_info$plot_call$args)$x
      if (is.null(handed) || is.language(handed) || !length(handed)) {
        return(list())
      }
      # A series of something other than numbers is declined rather than
      # coerced. `lag.plot()` does not get this far -- measured, a character
      # series warns "NAs introduced by coercion" twice and then stops in
      # `plot.window()` with "invalid 'xlim' value", so no chart is drawn --
      # but the arguments of a call that stopped are recorded all the same,
      # and `as.numeric()` on them would invent a grid of `NA`s to announce.
      matrix_form <- tryCatch(as.matrix(handed), error = function(e) NULL)
      if (is.null(matrix_form) || !is.numeric(matrix_form)) {
        return(list())
      }
      # No check that the coercion left a column: measured, the only argument
      # `as.matrix()` turns into a column-less matrix is a data frame that has
      # none, and that is rejected twice already -- it has length zero, and it
      # is not numeric.
      count <- ncol(matrix_form)

      values <- lapply(
        seq_len(count),
        function(i) as.numeric(matrix_form[, i])
      )
      names(values) <- private$series_names(
        handed, matrix_form, count, layer_info
      )
      values
    },
    # One name per series, empty where the drawing wrote none.
    series_names = function(handed, matrix_form, count, layer_info) {
      # `is.mat <- !is.null(ncol(x))` on the *caller's* argument, before the
      # coercion -- so a plain vector takes the deparsed name even though it
      # becomes a one-column matrix a line later.
      if (is.null(ncol(handed))) {
        return(private$written_name(count, layer_info))
      }
      declared <- colnames(matrix_form)
      if (is.null(declared) || length(declared) != count) {
        return(rep("", count))
      }
      ifelse(is.na(declared), "", as.character(declared))
    },
    # The deparsed first argument, which is the label a vector call carries.
    #
    # Recorded calls hold evaluated values, so the expression the caller wrote
    # survives only in `call_expr`. `x` is `lag.plot()`'s first formal with
    # nothing ahead of it, so the two spellings a caller can use are the whole
    # story: a named `x` wins, and otherwise it is the first argument written
    # without a name.
    written_name = function(count, layer_info) {
      name <- private$written_x(layer_info)
      rep(if (is.null(name)) "" else name, count)
    },
    written_x = function(layer_info) {
      text <- if (is.null(layer_info)) NULL else layer_info$call_expr
      if (!is.character(text) || !length(text) || !nzchar(text[[1]])) {
        return(NULL)
      }
      parsed <- tryCatch(str2lang(text[[1]]), error = function(e) NULL)
      if (is.null(parsed) || !is.call(parsed)) {
        return(NULL)
      }
      written <- as.list(parsed)[-1L]
      if (!length(written)) {
        return(NULL)
      }

      labels <- names(written)
      at <- if (!is.null(labels) && any(labels == "x")) {
        which(labels == "x")[[1L]]
      } else if (is.null(labels)) {
        1L
      } else {
        unnamed <- which(!nzchar(labels))
        if (!length(unnamed)) {
          return(NULL)
        }
        unnamed[[1L]]
      }

      deparsed <- tryCatch(paste(deparse(written[[at]]), collapse = ""),
        error = function(e) NULL
      )
      if (is.null(deparsed) || !nzchar(deparsed)) {
        return(NULL)
      }
      deparsed
    },
    # The lags a panel was drawn for, in the order they were drawn.
    #
    # `set.lags` defaults to `1:lags` and wins outright when the caller wrote
    # it. Only what the caller passed is recorded, so an absent argument is an
    # argument left at its default and needs no separate check.
    set_lags = function(layer_info) {
      args <- if (is.null(layer_info)) NULL else layer_info$plot_call$args
      written <- private$whole_numbers(args[["set.lags"]])
      if (!is.null(written)) {
        return(written)
      }
      count <- private$whole_numbers(args[["lags"]])
      if (is.null(count) || length(count) != 1 || count[[1]] < 1) {
        return(1L)
      }
      seq_len(count[[1]])
    },
    whole_numbers = function(value) {
      if (is.null(value) || !is.numeric(value) || !length(value)) {
        return(NULL)
      }
      whole <- suppressWarnings(as.integer(value))
      if (anyNA(whole)) {
        return(NULL)
      }
      whole
    },
    # The grid the panels were laid out in.
    #
    # `lag.plot()` takes the caller's `layout` when they wrote one and
    # `n2mfrow(nser * lags)` otherwise. It also keeps `par("mfrow")` when the
    # caller had already set one big enough, which this does not recover: the
    # panels' contents and their order are unaffected, only which cell each
    # lands in, and the recording carries no `par()` state to read it from.
    shape = function(layer_info, count) {
      args <- if (is.null(layer_info)) NULL else layer_info$plot_call$args
      written <- private$whole_numbers(args[["layout"]])
      if (!is.null(written) && length(written) == 2 && all(written >= 1)) {
        return(list(nrows = written[[1]], ncols = written[[2]]))
      }
      # `lags` rather than `length(set.lags)`: the function sizes the grid
      # from `lags` and only falls back to the length when `lags` was left
      # out, so a caller who wrote both gets the grid they asked for.
      declared <- private$whole_numbers(args[["lags"]])
      per_series <- if (!is.null(declared) && length(declared) == 1 &&
        declared[[1]] >= 1) {
        declared[[1]]
      } else {
        length(private$set_lags(layer_info))
      }
      shape <- grDevices::n2mfrow(count * per_series)
      list(nrows = shape[[1]], ncols = shape[[2]])
    },
    # Whether the panels carry the time index instead of a symbol.
    labelled = function(layer_info, series) {
      args <- if (is.null(layer_info)) NULL else layer_info$plot_call$args
      joined <- length(series[[1]]) <= 150
      if (!is.null(args[["do.lines"]])) {
        joined <- recorded_flag(args, "do.lines", joined)
      }
      if (is.null(args[["labels"]])) {
        return(joined)
      }
      recorded_flag(args, "labels", joined)
    },
    # One panel's pairs, axes and selector.
    #
    # A panel with no pair to make is left out of the grid rather than given
    # an empty layer, which would be a chart a reader can enter and find
    # nothing in. That is what the drawing does too: measured, a lag as long
    # as the series makes `ts.intersect()` warn "non-intersecting series" and
    # the panel comes out with its axes and no marks on it.
    #
    # A missing reading is why nothing here filters for `NA`: the panel takes
    # `xlim` from `range(X)`, so one `NA` anywhere makes the limits `NA` and
    # `plot.window()` stops before a mark is drawn. Both were measured.
    panel_layer = function(series, index, lag, panel, labelled, title) {
      values <- series[[index]]
      count <- length(values)
      at <- seq_len(count)
      at <- at[at + lag >= 1 & at + lag <= count]
      if (!length(at)) {
        return(NULL)
      }

      across <- values[at + lag]
      up <- values[at]
      name <- names(series)[[index]]
      list(
        data = lapply(
          seq_along(across),
          function(i) list(x = across[[i]], y = up[[i]])
        ),
        selectors = private$panel_selectors(panel, labelled),
        axes = build_axes(
          x = paste("lag", lag),
          y = if (nzchar(name)) name else NULL
        ),
        title = title,
        type = "point"
      )
    },
    # The marks one panel was drawn into.
    #
    # Built rather than searched for, as in `pairs()`: every panel writes its
    # own mark grob, and `find_graphics_plot_grob()` answers with the first,
    # so a search would give every panel the first panel's marks.
    #
    # A labelled panel's marks are `text` groups rather than `points` uses --
    # same one-per-pair shape, different element, measured off a real export.
    panel_selectors = function(panel, labelled) {
      grob <- if (labelled) "text" else "points"
      child <- if (labelled) "g" else "use"
      list(paste0(
        "g#graphics-plot-", panel, "-", grob, "-1\\.1 > ", child
      ))
    }
  )
)
