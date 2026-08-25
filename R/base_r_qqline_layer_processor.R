#' Base R Q-Q Reference Line Layer Processor
#'
#' Reads `qqline()` as the reference line it draws.
#'
#' `qqnorm()` and `qqplot()` became readable in #251, and `qqline()` -- how
#' nearly every Q-Q plot in the wild is finished -- was listed in `LOW` with
#' no reading at all, purely so a chart carrying one would decline rather
#' than come out as a scatter with a drawn mark silently missing from it.
#' That was the lower of the two claims; this is the reading (#252).
#'
#' Why it is recorded at all
#' -------------------------
#' `stats::qqline()` ends in `abline(int, slope, ...)`, and that call is
#' reached from *inside* the `stats` namespace, where maidr's search-path
#' wrapper never sees it. Measured: before `qqline` was listed, `qqnorm(x);
#' qqline(x)` recorded exactly one call and the reference line left no trace.
#'
#' Where the endpoints come from
#' -----------------------------
#' Not from the drawn grob and not re-derived. `stats::qqline`'s body is four
#' lines, and the line it draws is the one through two points:
#'
#'     y <- quantile(y, probs, names = FALSE, type = qtype, na.rm = TRUE)
#'     x <- distribution(probs)
#'
#' with `probs` defaulting to `c(0.25, 0.75)` and `distribution` to `qnorm`.
#' This class asks `stats` for the same two anchors, from the **call's own**
#' arguments, so a `qqline()` written with a non-default `probs`, `qtype` or
#' `distribution` is read from what it was given rather than from the
#' defaults. `datax = TRUE` swaps which of the two the slope is taken over,
#' and `qqline()` takes its own copy of that argument rather than inheriting
#' the plot's -- so a `qqline(datax = TRUE)` over a `qqnorm(datax = FALSE)`
#' is expressible, and is read from the `qqline` call.
#'
#' Why the x range is not the parent's
#' -----------------------------------
#' `BaseRLineLayerProcessor$extract_abline_data()` takes its x range from
#' `get_x_range_from_group()`, which reads the group's HIGH call's first
#' argument as the x data. On a `qqnorm` group that argument is the
#' **sample**, not the theoretical quantiles the chart puts on x -- so
#' inheriting it would stretch the line across the wrong interval, which is
#' the class of mistake the Q-Q reading exists to avoid. The range comes from
#' the drawn pairs instead, which {@code BaseRQqLayerProcessor} already
#' computes from `stats`' own output.
#'
#' Highlighting needs nothing new: `qqnorm(x); qqline(x)` and
#' `plot(x, y); abline(0, 1)` export the *same* grob,
#' `graphics-plot-1-abline-ab-1`, so the parent's abline selector reaches it
#' unchanged.
#'
#' @keywords internal
BaseRQqlineLayerProcessor <- R6::R6Class(
  "BaseRQqlineLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Extract the two endpoints the reference line is drawn between
    #' @param layer_info Layer information with the recorded call
    #' @return List of one series, each point a list of x and y
    extract_data = function(layer_info) {
      line <- self$reference_line(layer_info)
      if (is.null(line)) {
        return(list())
      }

      x_range <- self$qq_x_range(layer_info)
      if (is.null(x_range)) {
        return(list())
      }

      list(list(
        list(x = x_range[1], y = line$intercept + line$slope * x_range[1]),
        list(x = x_range[2], y = line$intercept + line$slope * x_range[2])
      ))
    },

    #' @description The intercept and slope `stats::qqline` computes
    #'
    #' Reproduces the four lines of `stats::qqline`'s own body against the
    #' recorded arguments, defaults included. Returns NULL when the call did
    #' not carry a sample this can read, or when the anchors come back
    #' degenerate -- two equal quantiles give a slope of `Inf` or `NaN`, and
    #' a line through them is not a line the chart drew.
    #'
    #' @param layer_info Layer information with the recorded call
    #' @return List with intercept and slope, or NULL
    reference_line = function(layer_info) {
      if (is.null(layer_info)) {
        return(NULL)
      }
      args <- layer_info$plot_call$args
      if (is.null(args) || length(args) == 0) {
        return(NULL)
      }
      # An unevaluated argument is not a sample. The Q-Q processor guards the
      # same way before handing anything to `stats`.
      if (any(vapply(args, is.language, logical(1)))) {
        return(NULL)
      }

      sample <- self$named_or_first(args, "y")
      if (is.null(sample) || !is.numeric(sample)) {
        return(NULL)
      }

      probs <- args[["probs"]]
      if (is.null(probs)) {
        probs <- c(0.25, 0.75)
      }
      if (!is.numeric(probs) || length(probs) != 2) {
        return(NULL)
      }

      distribution <- args[["distribution"]]
      if (is.null(distribution)) {
        distribution <- stats::qnorm
      }
      if (!is.function(distribution)) {
        return(NULL)
      }

      qtype <- args[["qtype"]]
      if (is.null(qtype)) {
        qtype <- 7
      }

      anchors <- tryCatch(
        {
          quantiles <- as.vector(stats::quantile(
            sample, probs,
            names = FALSE, type = qtype, na.rm = TRUE
          ))
          list(q = quantiles, d = as.numeric(distribution(probs)))
        },
        error = function(e) NULL
      )
      if (is.null(anchors) || length(anchors$q) != 2 || length(anchors$d) != 2) {
        return(NULL)
      }
      if (anyNA(anchors$q) || anyNA(anchors$d)) {
        return(NULL)
      }

      if (recorded_flag(args, "datax")) {
        slope <- diff(anchors$d) / diff(anchors$q)
        intercept <- anchors$d[[1]] - slope * anchors$q[[1]]
      } else {
        slope <- diff(anchors$q) / diff(anchors$d)
        intercept <- anchors$q[[1]] - slope * anchors$d[[1]]
      }
      if (!is.finite(slope) || !is.finite(intercept)) {
        return(NULL)
      }

      list(intercept = intercept, slope = slope)
    },

    #' @description The x interval the chart drew, taken from the Q-Q pairs
    #'
    #' The group's HIGH call is the `qqnorm()` or `qqplot()` this line sits
    #' on, and its recorded first argument is a *sample* rather than either
    #' drawn coordinate. So the range is read off the pairs `stats` computes,
    #' which is what the chart put on the x axis.
    #'
    #' @param layer_info Layer information carrying the group
    #' @return Numeric of length two, or NULL
    qq_x_range = function(layer_info) {
      high_call <- layer_info$group$high_call
      if (is.null(high_call)) {
        return(NULL)
      }
      pairs <- BaseRQqLayerProcessor$new(layer_info)$quantile_pairs(
        list(
          function_name = high_call$function_name,
          plot_call = high_call
        )
      )
      if (is.null(pairs) || length(pairs$x) == 0) {
        return(NULL)
      }
      range <- range(pairs$x)
      if (!all(is.finite(range)) || range[1] == range[2]) {
        return(NULL)
      }
      range
    },

    #' @description Which grob family this layer's selectors are drawn from
    #'
    #' `qqline()` ends in `abline()`, so the mark it leaves is an abline's:
    #' `qqnorm(x); qqline(x)` and `plot(x, y); abline(0, 1)` export the same
    #' `graphics-plot-1-abline-ab-1`. The parent keys this off the recorded
    #' function name, which here is `qqline` rather than `abline`, so without
    #' the override the selector would look under `lines` and find nothing --
    #' announcing the line correctly and highlighting nothing, which is the
    #' shape of defect #145 was about.
    #'
    #' @param layer_info Layer information with the recorded call
    #' @return The grob family name
    selector_grob_type = function(layer_info) {
      "abline"
    },

    #' @description A named argument, or the first positional one
    #' @param args The recorded arguments
    #' @param name The formal's name
    #' @return The value, or NULL
    named_or_first = function(args, name) {
      if (!is.null(args[[name]])) {
        return(args[[name]])
      }
      named <- names(args)
      positional <- if (is.null(named)) seq_along(args) else which(named == "")
      if (length(positional) == 0) {
        return(NULL)
      }
      args[[positional[1]]]
    }
  )
)
