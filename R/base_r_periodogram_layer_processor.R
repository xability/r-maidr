#' Base R Periodogram Processors
#'
#' Reads `spectrum()` and `cpgram()` as the curves they draw. Both take a time
#' series, compute a periodogram from it, and plot one curve against
#' frequency; they differ in what is plotted and in the mark it is drawn with.
#'
#' **Only the first curve is the chart.** Each call makes three `plot.xy()`
#' calls, and only the first is the data -- measured by tracing
#' `graphics::plot.xy` through a real call:
#'
#'     spectrum(v)   type="l" n=30  the spectral density
#'                   type="l" n=2   the confidence crosshair, two points
#'                   type="l" n=2   ditto
#'     cpgram(v)     type="s" n=31  the cumulative periodogram
#'                   type="l" n=2   a Kolmogorov-Smirnov bound
#'                   type="l" n=2   the other bound
#'
#' which matches the export: `spectrum` writes `lines-1` for the curve and
#' `lines-2`/`lines-3` for the crosshair, `cpgram` writes `step-1` for the
#' curve and `lines-1`/`lines-2` for the bounds. The two-point calls are
#' reference marks rather than readings, so they are not announced -- the
#' same choice `geom_smooth`'s band and `qqline` already get.
#'
#' **The values are recomputed, not read off the drawing.** A recorded call
#' keeps its arguments, not its results, so each series is computed again the
#' way the function computes it. Both were checked against the traced
#' `plot.xy` call and reproduce it exactly (`all.equal` on every value).
#'
#' @keywords internal
NULL

#' Base R Spectral Density Processor
#'
#' Reads `spectrum()` as the line it draws: the estimated spectral density
#' against frequency.
#'
#' **The values are the raw `spec`, not its logarithm.** `plot.spec` draws on
#' a log y axis by default, but it puts the log on the *axis* and hands
#' `plot.xy` the untransformed values -- traced, the first call's `y` equals
#' `spectrum(v, plot = FALSE)$spec` exactly. So the numbers a reader hears are
#' the numbers the chart is scaled from, and taking a logarithm here would
#' announce a series the caller never computed.
#'
#' **The caller's arguments are forwarded.** `spans`, `taper`, `detrend` and
#' the rest change the estimate, so recomputing with defaults would announce a
#' different curve from the one drawn. The recorded call's arguments are
#' passed through with `plot = FALSE` added.
#'
#' @keywords internal
BaseRSpectrumLayerProcessor <- R6::R6Class(
  "BaseRSpectrumLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Emit the spectral density as a line
    #' @param plot Unused; present for the processor interface.
    #' @param layout Unused; present for the processor interface.
    #' @param built Unused; present for the processor interface.
    #' @param gt Unused; the selector is built rather than searched for.
    #' @param grob_id Unused; present for the processor interface.
    #' @param panel_id Unused; present for the processor interface.
    #' @param panel_ctx Unused; present for the processor interface.
    #' @param layer_info Layer information with the recorded call.
    #' @return A line layer, or NULL when nothing was read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      curve <- private$estimate(info)
      if (is.null(curve)) {
        return(NULL)
      }

      list(
        data = periodogram_points(curve$x, curve$y),
        # `lines-1` is the density; `lines-2` and `lines-3` are the
        # confidence crosshair, which is not a reading.
        selectors = list(periodogram_selector(info, "lines")),
        type = "line",
        title = self$extract_main_title(info),
        axes = build_axes(x = "frequency", y = "spectrum")
      )
    }
  ),
  private = list(
    estimate = function(layer_info) {
      args <- periodogram_args(layer_info)
      if (is.null(args)) {
        return(NULL)
      }
      args$plot <- FALSE
      estimate <- tryCatch(
        do.call(stats::spectrum, args),
        error = function(e) NULL
      )
      if (is.null(estimate) || is.null(estimate$freq) || is.null(estimate$spec)) {
        return(NULL)
      }
      list(x = as.numeric(estimate$freq), y = as.numeric(estimate$spec))
    }
  )
)

#' Base R Cumulative Periodogram Processor
#'
#' Reads `cpgram()` as the staircase it draws: the cumulative periodogram
#' against frequency, held across each interval and then jumping.
#'
#' **It is a step, not a line.** `cpgram()` plots with `type = "s"`, which
#' draws the horizontal segment first -- MAIDR's `"hv"`. A line would imply
#' the value slides between frequencies, which is not what a cumulative sum
#' does, and the export agrees: the grob is `step-1`, not `lines-1`.
#'
#' **It does NOT use `spectrum()`'s estimate.** This is the trap the reading
#' exists to avoid. `spectrum()` defaults to `taper = 0.1, detrend = TRUE,
#' demean = FALSE` and smooths; `cpgram()` computes its own periodogram --
#' taper, FFT, zero the first ordinate, then normalise the cumulative sum --
#' and the two disagree. Measured, the second step of the drawn curve is
#' 0.0801 while `spectrum()`'s estimate gives 0.0817: close enough to look
#' right and wrong enough to announce wrong numbers. So the computation below
#' is `cpgram()`'s own, and it reproduces the traced `plot.xy` call exactly.
#'
#' @keywords internal
BaseRCpgramLayerProcessor <- R6::R6Class(
  "BaseRCpgramLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Emit the cumulative periodogram as a step
    #' @param plot Unused; present for the processor interface.
    #' @param layout Unused; present for the processor interface.
    #' @param built Unused; present for the processor interface.
    #' @param gt Unused; the selector is built rather than searched for.
    #' @param grob_id Unused; present for the processor interface.
    #' @param panel_id Unused; present for the processor interface.
    #' @param panel_ctx Unused; present for the processor interface.
    #' @param layer_info Layer information with the recorded call.
    #' @return A step layer, or NULL when nothing was read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      curve <- private$cumulative(info)
      if (is.null(curve)) {
        return(NULL)
      }

      list(
        data = periodogram_points(curve$x, curve$y),
        # `step-1` is the curve; `lines-1` and `lines-2` are the KS bounds.
        selectors = list(periodogram_selector(info, "step")),
        type = "step",
        # `type = "s"` draws the horizontal segment first.
        stepDirection = "hv",
        title = self$extract_main_title(info),
        # `cpgram()` writes an empty `ylab` -- there is no name for a
        # cumulative share of the total, and inventing one would be a claim
        # the chart does not make.
        axes = build_axes(x = "frequency")
      )
    }
  ),
  private = list(
    # `cpgram()`'s own computation, transcribed from it.
    cumulative = function(layer_info) {
      args <- periodogram_args(layer_info)
      if (is.null(args)) {
        return(NULL)
      }
      series <- args[[1]]
      taper <- if (is.null(args$taper)) 0.1 else args$taper
      if (!is.numeric(taper) || length(taper) != 1 || is.na(taper)) {
        taper <- 0.1
      }

      tryCatch(
        {
          values <- as.vector(series)
          values <- values[!is.na(values)]
          if (length(values) < 2) {
            return(NULL)
          }
          tapered <- stats::spec.taper(scale(values, TRUE, FALSE), p = taper)
          y <- Mod(stats::fft(tapered))^2 / length(tapered)
          y[1L] <- 0
          n <- length(tapered)
          x <- (0:(n / 2)) * stats::frequency(series) / n
          if (length(x) %% 2 == 0) {
            n <- length(x) - 1
            y <- y[1L:n]
            x <- x[1L:n]
          } else {
            y <- y[seq_along(x)]
          }
          total <- sum(y)
          if (!is.finite(total) || total == 0) {
            return(NULL)
          }
          list(x = as.numeric(x), y = as.numeric(cumsum(y) / total))
        },
        error = function(e) NULL
      )
    }
  )
)

#' The arguments a periodogram call was made with
#'
#' Both entry points take the series as their first formal with nothing ahead
#' of it, and a recorded call keeps evaluated arguments, so the series is the
#' value itself. A call whose series is not numeric is declined rather than
#' coerced: the arguments of a call that stopped are recorded all the same,
#' and coercing would announce a curve computed from `NA`s.
#'
#' @param layer_info Layer information with the recorded call.
#' @return The recorded arguments, or NULL when there is no series to read
#' @keywords internal
periodogram_args <- function(layer_info) {
  if (is.null(layer_info) || is.null(layer_info$plot_call)) {
    return(NULL)
  }
  args <- layer_info$plot_call$args
  if (!length(args)) {
    return(NULL)
  }
  series <- args[[1]]
  if (is.null(series) || is.language(series) || !length(series)) {
    return(NULL)
  }
  if (!is.numeric(series) && !stats::is.ts(series)) {
    return(NULL)
  }
  args
}

#' One point per frequency
#'
#' @param x Frequencies, in the order they were drawn.
#' @param y The value at each.
#' @return A list of `list(x =, y =)` points, empty when nothing lines up
#' @keywords internal
periodogram_points <- function(x, y) {
  keep <- seq_len(min(length(x), length(y)))
  keep <- keep[is.finite(x[keep]) & is.finite(y[keep])]
  lapply(keep, function(i) list(x = x[[i]], y = y[[i]]))
}

#' The grob a periodogram's curve was drawn as, in its own panel
#'
#' gridGraphics numbers panels in draw order, so under `par(mfrow = )` the
#' second chart's curve is `graphics-plot-2-lines-1`. The panel index is the
#' one the orchestrator assigned the layer; a layer without one is the first
#' panel.
#'
#' @param layer_info Layer information carrying `group_index` or `index`
#' @param grob The grob name gridGraphics wrote: `"lines"` or `"step"`
#' @return A CSS selector for the curve's `g` element
#' @keywords internal
periodogram_selector <- function(layer_info, grob) {
  index <- layer_info$group_index %||% layer_info$index %||% 1L
  paste0("g#graphics-plot-", index, "-", grob, "-1\\.1")
}
