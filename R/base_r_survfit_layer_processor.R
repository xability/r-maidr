#' Base R Kaplan-Meier Layer Processor
#'
#' @description
#' Reads `plot()` of a `survival::survfit` object -- a Kaplan-Meier curve,
#' one per stratum -- from the object itself, as a `survival` layer.
#'
#' Why the object and not the drawing
#' ----------------------------------
#' `survival:::plot.survfit()` draws from inside the survival namespace: a
#' `plot(type = "n")` for the frame, then one `lines()` per curve of a
#' staircase it builds itself, `points()` for the censoring marks and two
#' more `lines()` for the confidence band (survival 3.5). Those resolve
#' through survival's imports of graphics, so maidr's wrappers see none of
#' them; what is recorded is the one `plot(fit)` call the reader wrote, which
#' typed by `type` alone was an empty scatter.
#'
#' The reading
#' -----------
#' One series per stratum, each point a time the object reports: the
#' survival estimate there, `censored` where a subject left the study at
#' that time without the event (`n.censor`), and the band's `yMin` and
#' `yMax` when the plot draws it. The curve starts where the plot starts it,
#' at `survival::survfit0()`'s added origin. Times are divided by `xscale`
#' and estimates multiplied by `yscale`, which is how the plot's axes label
#' them; a curve cut at `xmax` (or at the right end of `xlim`) is cut as the
#' plot cuts it.
#'
#' Censoring is read whether or not `mark.time` draws the marks: it is part
#' of the estimate the curve is drawn from, not of its decoration, and it is
#' what separates a flat tail many subjects support from one few do.
#'
#' Highlight: gridGraphics names each `lines()` polyline
#' `graphics-plot-N-lines-M` in drawing order -- the curve, then its lower
#' and upper bound when the band is drawn -- so each stratum's curve is the
#' first of its three, or every one without a band.
#'
#' See [survfit_layer_type()] for the drawings that are declined.
#'
#' @keywords internal
BaseRSurvfitLayerProcessor <- R6::R6Class(
  "BaseRSurvfitLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Process the layer: read its curves, selectors and titles
    #'   from the recorded `survfit` object
    #' @param plot Unused; present for the processor interface
    #' @param layout Unused; present for the processor interface
    #' @param built Unused; present for the processor interface
    #' @param gt Gtable of the replayed drawing, searched for selectors (optional)
    #' @param grob_id Unused; present for the processor interface
    #' @param panel_id Unused; present for the processor interface
    #' @param panel_ctx Unused; present for the processor interface
    #' @param layer_info Layer information with the recorded call
    #' @return List describing the layer for the MAIDR payload
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
        type = "survival",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info)
      )
    },

    #' @description One series per stratum of the recorded `survfit` object
    #' @param layer_info Layer information with the recorded call
    #' @return List of series
    extract_data = function(layer_info) {
      fit <- self$survfit(layer_info)
      if (is.null(fit)) {
        return(list())
      }
      survfit_curves(fit, layer_info$plot_call$args)
    },

    #' @description The axis titles: `xlab` and `ylab` when given, else
    #'   "Time" and "Survival probability", which is what the axes hold
    #'   (the plot itself titles neither)
    #' @param layer_info Layer information with the recorded call
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      args <- if (!is.null(layer_info$plot_call)) layer_info$plot_call$args
      fit <- self$survfit(layer_info)
      build_axes(
        x = recorded_axis_label(args, "xlab", "Time"),
        y = recorded_axis_label(args, "ylab", "Survival probability"),
        z = if (!is.null(fit) && !is.null(fit$strata)) "Stratum"
      )
    },

    #' @description One selector per stratum: the curve's own polyline,
    #'   skipping the two bound polylines drawn after it when the band is
    #'   drawn. None when the drawing has fewer polylines than that, rather
    #'   than outlines on the wrong lines.
    #' @param layer_info Layer information with the recorded call
    #' @param gt Gtable of the replayed drawing (optional)
    #' @return List of selectors
    generate_selectors = function(layer_info, gt = NULL) {
      fit <- self$survfit(layer_info)
      selectors <- super$generate_selectors(layer_info, gt)
      if (is.null(fit) || length(selectors) == 0L) {
        return(list())
      }
      curves <- survfit_stratum_count(fit)
      per_curve <- if (survfit_band_drawn(fit, layer_info$plot_call$args)) 3L else 1L
      if (length(selectors) < curves * per_curve) {
        return(list())
      }
      selectors[seq(1L, by = per_curve, length.out = curves)]
    },

    #' @description The recorded `survfit` object
    #' @param layer_info Layer information with the recorded call
    #' @return The object, or NULL when the call does not carry one
    survfit = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      fit <- resolve_xy_args(layer_info$plot_call$args)$x
      if (inherits(fit, "survfit")) fit else NULL
    }
  )
)

#' How many curves `plot()` of a `survfit` object draws: one per stratum
#'
#' @param fit A `survfit` object
#' @return Integer
#' @keywords internal
survfit_stratum_count <- function(fit) {
  if (is.null(fit$strata)) 1L else length(fit$strata)
}

#' Whether `plot()` of a `survfit` object draws the confidence band
#'
#' As `survival:::plot.survfit()` decides it: by `conf.int` when given, and
#' otherwise only for a single curve with standard errors.
#'
#' @param fit A `survfit` object
#' @param args The recorded arguments of the `plot()` call
#' @return TRUE or FALSE
#' @keywords internal
survfit_band_drawn <- function(fit, args) {
  conf <- args[["conf.int"]]
  if (is.null(conf)) {
    return(!is.null(fit$std.err) && survfit_stratum_count(fit) == 1L)
  }
  if (is.numeric(conf)) {
    return(isTRUE(conf[1] > 0))
  }
  if (is.character(conf)) {
    return(!identical(conf[1], "none"))
  }
  isTRUE(as.logical(conf)[1])
}

#' The curves `plot()` of a `survfit` object draws, as `survival` series
#'
#' @param fit A `survfit` object, already accepted by [survfit_layer_type()]
#' @param args The recorded arguments of the `plot()` call
#' @return List of series, one per stratum
#' @keywords internal
survfit_curves <- function(fit, args) {
  band <- survfit_band_drawn(fit, args)
  xscale <- survfit_scale(args[["xscale"]])
  yscale <- survfit_scale(args[["yscale"]])
  xmax <- survfit_xmax(args)

  # The origin the plot starts every curve at (survival >= 3.0).
  fit0 <- survival::survfit0(fit, fit$start.time)
  sizes <- if (is.null(fit0$strata)) length(fit0$time) else as.integer(fit0$strata)
  labels <- names(fit0$strata)
  ends <- cumsum(sizes)

  lapply(seq_along(sizes), function(s) {
    who <- seq_len(sizes[[s]]) + ends[[s]] - sizes[[s]]
    time <- as.numeric(fit0$time[who])
    surv <- as.numeric(fit0$surv[who])
    censor <- if (!is.null(fit0$n.censor)) {
      fit0$n.censor[who] > 0
    } else {
      fit0$n.event[who] == 0
    }
    lower <- if (band) as.numeric(fit0$lower[who])
    upper <- if (band) as.numeric(fit0$upper[who])

    cut <- survfit_cut(time, xmax)
    time <- cut$time
    surv <- survfit_hold(surv, cut$n)
    censor <- censor[seq_along(time)]
    if (!is.null(cut$n)) {
      censor[cut$n] <- FALSE
    }
    if (band) {
      lower <- survfit_hold(lower, cut$n)
      upper <- survfit_hold(upper, cut$n)
    }

    drawn <- which(is.finite(time) & is.finite(surv))
    lapply(drawn, function(i) {
      point <- list(x = time[[i]] / xscale, y = surv[[i]] * yscale)
      if (!is.null(labels)) {
        point$z <- labels[[s]]
      }
      if (isTRUE(censor[[i]])) {
        point$censored <- TRUE
      }
      if (band && is.finite(lower[[i]]) && is.finite(upper[[i]])) {
        point$yMin <- lower[[i]] * yscale
        point$yMax <- upper[[i]] * yscale
      }
      point
    })
  })
}

#' Where `plot()` of a `survfit` object cuts a curve that runs past `xmax`
#'
#' At the first time beyond it, which is moved back to it.
#'
#' @param time The curve's times
#' @param xmax Where the plot cuts, or NULL
#' @return List of the kept `time` and the index `n` of the cut, or NULL
#' @keywords internal
survfit_cut <- function(time, xmax) {
  if (is.null(xmax) || length(time) < 2L || !any(time > xmax, na.rm = TRUE)) {
    return(list(time = time, n = NULL))
  }
  n <- max(2L, min(which(time > xmax)))
  time <- time[seq_len(n)]
  time[n] <- xmax
  list(time = time, n = n)
}

#' Values up to a cut, the last holding the level before it, as the plot draws
#' @param values The curve's values at each time
#' @param n The index of the cut, or NULL
#' @return Numeric vector
#' @keywords internal
survfit_hold <- function(values, n) {
  if (is.null(n)) {
    return(values)
  }
  values <- values[seq_len(n)]
  values[n] <- values[n - 1L]
  values
}

#' A recorded `xscale` or `yscale`, or 1
#' @param value The recorded argument
#' @return A positive number
#' @keywords internal
survfit_scale <- function(value) {
  value <- suppressWarnings(as.numeric(value)[1])
  if (length(value) == 1L && is.finite(value) && value != 0) value else 1
}

#' Where `plot()` of a `survfit` object cuts its curves
#'
#' The right end of `xlim` when given, which overrides `xmax`; else `xmax`.
#'
#' @param args The recorded arguments of the `plot()` call
#' @return A number, or NULL when the curves run to their end
#' @keywords internal
survfit_xmax <- function(args) {
  xlim <- args[["xlim"]]
  if (is.numeric(xlim) && length(xlim) >= 2L && is.finite(xlim[2])) {
    return(as.numeric(xlim[2]))
  }
  xmax <- args[["xmax"]]
  if (is.numeric(xmax) && length(xmax) >= 1L && is.finite(xmax[1])) {
    return(as.numeric(xmax[1]))
  }
  NULL
}

#' The layer type of `plot()` of a `survfit` object
#'
#' Read (`"survival"`) when the plot draws Kaplan-Meier survival curves from
#' the object's own estimates. Declined (`"unknown"`, so the chart is shown
#' as a picture) when it draws something else:
#'
#' * `fun` or `cumhaz` transforms the estimate (cumulative hazard, events,
#'   log-log), so the curve is no longer a survival probability;
#' * a multi-state (`survfitms`) or multi-column fit -- several curves per
#'   stratum, as `survfit()` of a Cox model over several new subjects is;
#' * `conf.int = "only"` draws the band without the curve, and a numeric
#'   `conf.int` other than the fit's own level draws bounds the object does
#'   not hold;
#' * `conf.times` draws the band as error bars at chosen times;
#' * a band asked for of a fit that kept no bounds (`conf.type = "none"`).
#'
#' @param args The recorded arguments of the `plot()` call
#' @return `"survival"` or `"unknown"`
#' @keywords internal
survfit_layer_type <- function(args) {
  fit <- resolve_xy_args(args)$x
  if (survfit_readable(fit) && !survfit_transformed(args) &&
        survfit_band_readable(fit, args)) {
    "survival"
  } else {
    "unknown"
  }
}

#' Whether a `survfit` object holds one survival curve per stratum
#' @param fit The object `plot()` was given
#' @return TRUE or FALSE
#' @keywords internal
survfit_readable <- function(fit) {
  inherits(fit, "survfit") && !inherits(fit, "survfitms") &&
    requireNamespace("survival", quietly = TRUE) &&
    is.numeric(fit$time) && is.numeric(fit$surv) &&
    (!is.matrix(fit$surv) || ncol(fit$surv) == 1L)
}

#' Whether `plot()` of a `survfit` object draws something other than the
#' survival estimate: a `fun` or `cumhaz` transform, or `conf.times` bars
#' @param args The recorded arguments of the `plot()` call
#' @return TRUE or FALSE
#' @keywords internal
survfit_transformed <- function(args) {
  cumhaz <- args[["cumhaz"]]
  !is.null(args[["fun"]]) || !is.null(args[["conf.times"]]) ||
    (!is.null(cumhaz) && !isFALSE(as.logical(cumhaz)[1]))
}

#' Whether the band `plot()` of a `survfit` object draws, if any, is the
#' object's own: not `conf.int = "only"`, not another level, not of a fit
#' that kept no bounds
#' @param fit A `survfit` object
#' @param args The recorded arguments of the `plot()` call
#' @return TRUE or FALSE
#' @keywords internal
survfit_band_readable <- function(fit, args) {
  conf <- args[["conf.int"]]
  if (is.character(conf) && identical(conf[1], "only")) {
    return(FALSE)
  }
  if (is.numeric(conf) && isTRUE(conf[1] > 0) &&
        !isTRUE(all.equal(as.numeric(conf[1]), as.numeric(fit$conf.int)))) {
    return(FALSE)
  }
  !survfit_band_drawn(fit, args) || (!is.null(fit$lower) && !is.null(fit$upper))
}
