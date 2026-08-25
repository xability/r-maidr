#' Base R Correlogram Layer Processor
#'
#' Processes the three correlogram entry points -- `acf()`, `pacf()` and
#' `ccf()`. Each draws one vertical spike per lag, from the zero line to the
#' correlation at that lag, and joins nothing to anything.
#'
#' Read as a `lollipop` layer, for the reason `BaseRSpikeLayerProcessor`
#' gives: a line would say the samples are joined and that the space between
#' two lags can be interpolated, which is the one relationship a correlogram
#' is drawn to deny. The spikes even export under the same grob name --
#' measured, `plot(acf(v))` names them `graphics-plot-1-spike-1` -- so the
#' inherited selector search needs no override.
#'
#' What this adds is where the numbers come from. The recorded call holds the
#' **series**, not the correlogram: measured, `acf(v, lag.max = 5)` records
#' one HIGH call whose args are the 60 observations and `lag.max`. So the
#' reading replays the call with `plot = FALSE` and takes `$lag` and `$acf`
#' off the result, which is the same shape `BaseRSpineplotLayerProcessor`
#' takes for a table it cannot read off the drawing either.
#'
#' All three differ in what the lags are, and the replay answers that
#' too rather than the reading assuming it. Measured on one 60-point series:
#'
#'     acf(v,  lag.max = 5)   lags  0  1  2  3  4  5
#'     pacf(v, lag.max = 5)   lags     1  2  3  4  5
#'     ccf(v, w, lag.max = 3) lags -3 -2 -1  0  1  2  3
#'
#' `acf` starts at lag 0, whose correlation is 1 by construction and which
#' the chart draws; `pacf` has no lag 0 at all; and a cross-correlation's
#' lags are signed, because "x leads y" and "y leads x" are different
#' statements. Announcing any of the three as another would misname every
#' spike on the chart.
#'
#' @keywords internal
BaseRCorrelogramLayerProcessor <- R6::R6Class(
  "BaseRCorrelogramLayerProcessor",
  inherit = BaseRSpikeLayerProcessor,
  public = list(
    #' @description Process the correlogram layer.
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
        type = "lollipop",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info)
      )
    },

    #' @description Read one point per lag the correlogram draws.
    #'
    #' The lag on the category axis and the correlation as the magnitude,
    #' in the order they are drawn -- which for `ccf` runs from the most
    #' negative lag rightwards, so the announced order is the drawn one.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return List of `x`/`y` points, empty when the replay states nothing
    extract_data = function(layer_info) {
      computed <- private$replay(layer_info)
      if (is.null(computed)) {
        return(list())
      }

      lags <- as.numeric(drop(computed$lag))
      values <- as.numeric(drop(computed$acf))
      # Defensive rather than reachable, and recorded as such. A correlogram
      # of a constant series is all `NaN` -- measured, `acf(rep(1, 20))`
      # computes `NaN, NaN, NaN, NaN` -- but base R will not *draw* one:
      # `plot.acf` raises "need finite 'ylim' values", so no such chart ever
      # reaches a reading. The guard stays because one `NaN` in the payload
      # stops the chart initialising at all (#427), which is a worse failure
      # than a dropped spike; `test-base-r-correlogram.R` pins the
      # matplotlib-side premise so a release that starts drawing them
      # surfaces here rather than in a browser.
      keep <- is.finite(lags) & is.finite(values)
      lags <- lags[keep]
      values <- values[keep]
      if (!length(lags)) {
        return(list())
      }

      lapply(seq_along(lags), function(i) {
        list(x = lags[[i]], y = values[[i]])
      })
    },

    #' @description Name the lag axis and the quantity drawn against it.
    #'
    #' A correlogram writes its own axis labels, so there is nothing the
    #' caller titled to read -- and the inherited `X`/`Y` fallback would
    #' name a lag after a coordinate. The value axis follows what the replay
    #' says it computed: `acf(type = "covariance")` draws covariances, not
    #' correlations, and calling them correlations would announce a
    #' normalisation the chart never applied.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return Named list with `x` and `y`
    extract_axis_titles = function(layer_info) {
      computed <- private$replay(layer_info)
      build_axes(x = "Lag", y = private$value_axis(layer_info, computed))
    },

    #' @description Title the chart the way the drawing does.
    #'
    #' `plot.acf()` writes "Series v" above an `acf` and "v & w" above a
    #' `ccf`, and the replayed object carries those as `$series` and
    #' `$snames` -- but not usefully. Both are `deparse(substitute(x))`, and
    #' the replay hands `stats` the recorded *values* rather than the name
    #' the caller wrote, so measured they come back as the whole series
    #' pasted in: `Series c(-2.0715334064552, -0.117989125730012, ...)`.
    #' That is worse than no title at all.
    #'
    #' The name is in the recorded call expression instead, which is kept as
    #' the source text of the call -- measured, `"acf(v, lag.max = 3)"`. It
    #' is used only when the argument is a bare symbol: a caller who wrote
    #' `acf(rnorm(60))` named nothing, and titling the chart with the
    #' expression that produced it would announce a call rather than a
    #' series.
    #'
    #' A caller's own `main =` wins, which is what the inherited reading
    #' already answers.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return The title, or NULL when the caller named nothing
    extract_main_title = function(layer_info) {
      given <- super$extract_main_title(layer_info)
      if (!is.null(given) && nzchar(given)) {
        return(given)
      }

      named <- private$series_names(layer_info)
      if (!length(named)) {
        return(NULL)
      }
      if (length(named) >= 2) {
        return(paste(named[[1]], "&", named[[2]]))
      }
      paste("Series", named[[1]])
    }
  ),
  private = list(
    # The correlogram the recorded call would have drawn.
    #
    # Replayed rather than read off the drawing, because the drawing is what
    # the reading is trying to describe: the spikes are a polyline each, and
    # inverting pixels back into correlations would be a worse answer than
    # asking `stats` the question the call already asked it. `plot = FALSE`
    # is forced so the replay draws nothing onto the device being recorded.
    #
    # Cached on the processor, because `extract_data`, `extract_axis_titles`
    # and `extract_main_title` each need it and the replay is not free on a
    # long series.
    #
    # `plot = FALSE` leaves no trace the test suite can observe -- measured,
    # the reading records one call either way, because it runs inside the
    # internal guard that stops a patched call from recording itself. What
    # it stops is the replay *drawing*: on a live device a reader would get
    # a second correlogram painted over the first when the figure was saved.
    # Kept for that, not for the recording.
    .computed = NULL,
    .replayed = FALSE,
    replay = function(layer_info) {
      if (private$.replayed) {
        return(private$.computed)
      }
      private$.replayed <- TRUE

      fn <- tryCatch(
        switch(as.character(layer_info$function_name),
          "acf" = stats::acf,
          "pacf" = stats::pacf,
          "ccf" = stats::ccf,
          NULL
        ),
        error = function(e) NULL
      )
      if (is.null(fn)) {
        return(NULL)
      }

      args <- layer_info$args
      if (!length(args)) {
        return(NULL)
      }
      args$plot <- FALSE

      # A call this cannot replay leaves the layer with nothing to announce,
      # and an empty layer is dropped rather than emitted -- the same answer
      # every other processor gives a call it cannot read.
      private$.computed <- tryCatch(do.call(fn, args), error = function(e) NULL)
      private$.computed
    },
    # The series names the caller wrote, when they wrote names.
    #
    # Read off the recorded call text rather than off the replayed object,
    # for the reason `extract_main_title` gives. Only bare symbols count:
    # `acf(v)` names `v`, while `acf(rnorm(60))` names nothing, and a
    # `data =`-style named argument is not the series either.
    series_names = function(layer_info) {
      text <- layer_info$call_expr
      if (!is.character(text) || !length(text) || !nzchar(text[[1]])) {
        return(character(0))
      }
      parsed <- tryCatch(str2lang(text[[1]]), error = function(e) NULL)
      if (is.null(parsed) || !is.call(parsed)) {
        return(character(0))
      }

      parts <- as.list(parsed)[-1]
      labels <- names(parts)
      positional <- if (is.null(labels)) parts else parts[!nzchar(labels)]
      symbols <- Filter(is.symbol, positional)
      vapply(symbols, function(sym) as.character(sym), character(1))
    },
    # What the spikes measure, in the words the drawing uses.
    value_axis = function(layer_info, computed) {
      kind <- if (is.null(computed)) NULL else computed$type
      if (identical(kind, "covariance")) {
        return("Autocovariance")
      }
      if (identical(kind, "partial")) {
        return("Partial ACF")
      }
      if (identical(as.character(layer_info$function_name), "ccf")) {
        return("CCF")
      }
      "ACF"
    }
  )
)
