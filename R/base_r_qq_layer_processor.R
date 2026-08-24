#' Base R Q-Q Plot Layer Processor
#'
#' Reads `qqnorm()` and `qqplot()` as the scatter of quantile pairs they
#' draw.
#'
#' A Q-Q plot is a scatter, and `BaseRPointLayerProcessor` already knows how
#' to emit one -- the selector, the title and the grid all carry over
#' unchanged, and `qqnorm()` exports its marks under
#' `graphics-plot-N-points-1`, the same grob the point processor looks for.
#' What does not carry over is the **data**.
#'
#' The base R processors read a call's *recorded arguments*, not the drawn
#' grob, and a Q-Q plot's arguments are not its coordinates. `qqnorm(y)` is
#' handed one sample and draws it against theoretical quantiles it computes;
#' `qqplot(x, y)` is handed two samples of possibly different lengths and
#' draws one interpolated pair per point of the shorter. Read as an ordinary
#' scatter, both would announce numbers the chart does not draw -- for
#' `qqnorm` the raw sample on an axis of standard deviations, which is the
#' one reading a Q-Q plot most needs not to have, because the whole point of
#' the chart is the comparison between the two.
#'
#' So the coordinates are not re-derived here. `stats` computes them and
#' both functions will hand them over without drawing: `plot.it = FALSE`
#' returns exactly the pairs the plotted call would have drawn. Forwarding
#' the recorded arguments rather than picking them apart is what makes the
#' awkward cases free. Measured on eight values against five:
#'
#'     qqnorm(x, plot.it = FALSE)$x    theoretical quantiles, in the
#'                                     caller's order, not sorted
#'     qqnorm(x, datax = TRUE, ...)    the same pair, swapped
#'     qqplot(x, y, plot.it = FALSE)   both length 5; x interpolated to the
#'                                     shorter sample's quantiles
#'
#' `datax` is the clearest of them: it swaps which axis holds the sample,
#' and forwarding it means nothing here has to know that.
#'
#' The pairs come back in the order the call drew them, which is the order
#' the `points` grob lays its marks down in, so the selector list keeps
#' pairing positionally. Nothing is sorted.
#'
#' @keywords internal
BaseRQqLayerProcessor <- R6::R6Class(
  "BaseRQqLayerProcessor",
  inherit = BaseRPointLayerProcessor,
  public = list(
    #' @description Extract the quantile pairs the call drew
    #' @param layer_info Layer information with the recorded call
    #' @return List of points, each a list of x and y
    extract_data = function(layer_info) {
      pairs <- self$quantile_pairs(layer_info)
      if (is.null(pairs)) {
        return(list())
      }

      lapply(
        seq_along(pairs$x),
        function(i) list(x = pairs$x[[i]], y = pairs$y[[i]])
      )
    },

    #' @description Ask `stats` for the pairs the call drew
    #'
    #' Returns NULL when the computation raises or does not come back as a
    #' usable pair of equal-length numeric vectors, which leaves the layer
    #' empty and the chart on the fallback rather than shipping half of it.
    #'
    #' @param layer_info Layer information with the recorded call
    #' @return List with x and y, or NULL
    quantile_pairs = function(layer_info) {
      if (is.null(layer_info)) {
        return(NULL)
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args
      compute <- switch(layer_info$function_name,
        "qqnorm" = stats::qqnorm,
        "qqplot" = stats::qqplot,
        NULL
      )
      if (is.null(compute) || is.null(args)) {
        return(NULL)
      }
      # An unevaluated argument is not a sample. The point processor guards
      # the same way before handing anything to xy.coords().
      if (any(vapply(args, is.language, logical(1)))) {
        return(NULL)
      }

      # A caller who wrote `plot.it = TRUE` supplied the argument this is
      # about to supply, and `do.call` refuses a formal matched twice.
      if (!is.null(names(args))) {
        args <- args[!names(args) %in% "plot.it"]
      }
      pairs <- tryCatch(
        suppressWarnings(do.call(compute, c(args, list(plot.it = FALSE)))),
        error = function(e) NULL
      )
      if (!is.list(pairs) || is.null(pairs$x) || is.null(pairs$y)) {
        return(NULL)
      }
      x <- suppressWarnings(as.numeric(pairs$x))
      y <- suppressWarnings(as.numeric(pairs$y))
      if (length(x) == 0 || length(x) != length(y)) {
        return(NULL)
      }
      if (anyNA(x) || anyNA(y)) {
        return(NULL)
      }

      list(x = x, y = y)
    },

    #' @description Axis labels and grid for a Q-Q plot
    #'
    #' `qqnorm()` writes "Theoretical Quantiles" against "Sample Quantiles"
    #' whenever the caller does not, and `datax = TRUE` swaps them along with
    #' the axes -- both are constants in the function's own signature, so
    #' they are the labels the chart really carries rather than a guess.
    #'
    #' `qqplot()` has no such defaults: its are `deparse1(substitute(x))`,
    #' the caller's expression, which is gone by the time the wrapper has
    #' recorded evaluated values. So a `qqplot()` the caller did not label is
    #' left unlabelled for the renderer's generic, on the same reasoning the
    #' point processor already states -- a guessed noun is worse than none.
    #'
    #' The grid is computed from the drawn pairs, not from the recorded
    #' arguments: those are the samples, and on `qqnorm` one of the two axes
    #' is not a sample at all.
    #'
    #' @param layer_info Layer information with the recorded call
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes())
      }

      args <- layer_info$plot_call$args
      defaults <- self$default_axis_labels(layer_info)
      x_axis <- build_axis_config(
        label = recorded_axis_label(args, "xlab", defaults$x)
      )
      y_axis <- build_axis_config(
        label = recorded_axis_label(args, "ylab", defaults$y)
      )

      pairs <- self$quantile_pairs(layer_info)
      if (!is.null(pairs)) {
        x_grid <- self$extract_base_r_axis_grid_info(pairs$x, args[["xlim"]])
        y_grid <- self$extract_base_r_axis_grid_info(pairs$y, args[["ylim"]])
        if (!is.null(x_grid)) {
          x_axis$min <- x_grid$min
          x_axis$max <- x_grid$max
          x_axis$tickStep <- x_grid$tickStep
        }
        if (!is.null(y_grid)) {
          y_axis$min <- y_grid$min
          y_axis$max <- y_grid$max
          y_axis$tickStep <- y_grid$tickStep
        }
      }

      build_axes(x = x_axis, y = y_axis)
    },

    #' @description The labels the call writes when the caller does not
    #' @param layer_info Layer information with the recorded call
    #' @return List with x and y, either a string or NULL
    default_axis_labels = function(layer_info) {
      if (!identical(layer_info$function_name, "qqnorm")) {
        return(list(x = NULL, y = NULL))
      }
      theoretical <- "Theoretical Quantiles"
      sample <- "Sample Quantiles"
      if (isTRUE(layer_info$plot_call$args[["datax"]])) {
        return(list(x = sample, y = theoretical))
      }
      list(x = theoretical, y = sample)
    },

    #' @description The title the call writes when the caller does not
    #'
    #' `qqnorm()`'s `main` defaults to "Normal Q-Q Plot" and it is drawn, so
    #' announcing it is reporting the chart rather than inventing a name for
    #' it. `qqplot()` has no default title and gets none.
    #'
    #' @param layer_info Layer information with the recorded call
    #' @return The title string
    extract_main_title = function(layer_info) {
      title <- super$extract_main_title(layer_info)
      if (nzchar(title) || !identical(layer_info$function_name, "qqnorm")) {
        return(title)
      }
      "Normal Q-Q Plot"
    }
  )
)
