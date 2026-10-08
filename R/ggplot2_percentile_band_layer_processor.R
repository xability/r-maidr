#' Percentile Band Layer Processor
#'
#' @description
#' Reads a fan of nested quantile intervals around a median -- the
#' `stat_lineribbon()` / `geom_lineribbon()` of ggdist -- as the
#' `percentile_band` trace: at each x, the distribution's quantiles, which a
#' reader enters on the median and walks up and down band by band, each
#' announced as the band it bounds ("Middle 80% is 1.2 to 3.4").
#'
#' Until this, a lineribbon matched no branch of the adapter, and an unread
#' layer drops the whole chart to a static image.
#'
#' **What is read.** ggdist draws one ribbon per interval width and the
#' median line over them. A ribbon of width `w` spans the quantiles
#' `(1 - w) / 2` and `(1 + w) / 2`, and the line is the quantile `0.5` --
#' which holds only for a median with quantile intervals (`median_qi()`,
#' `stat_lineribbon()`'s default). A mean, or a highest-density interval, is
#' not a quantile, and [lineribbon_quantile_rows()] declines the layer before
#' it reaches this processor.
#'
#' **Selectors.** One per band, outermost first, then the median line: the
#' shape the core reads as "one element per band". ggdist draws its ribbons
#' widest first, so the draw order of the band polygons is already the order
#' asked for; a count that disagrees with the widths emits no selectors
#' rather than mispaired ones.
#'
#' **A `median_hilow` ribbon.** `stat_summary(geom = "ribbon", fun.data =
#' median_hilow)` is a band of one width, `fun.args$conf.int`, around the
#' median the stat computed, and is read the same way from
#' [summary_band_rows()]. Its selectors are the ribbon's one polygon and,
#' when a `stat_summary()` median line sits on it, that line's polyline;
#' the line layer itself is skipped, its values being the band's median.
#'
#' Emitted with `type = "percentile_band"`, which the core has read since
#' maidr 4.14.0.
#'
#' @keywords internal
Ggplot2PercentileBandLayerProcessor <- R6::R6Class(
  "Ggplot2PercentileBandLayerProcessor",
  inherit = Ggplot2AreaLayerProcessor,
  public = list(
    #' @description Process the lineribbon layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes and type
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer <- self$get_layer(plot)
      from_summary <- !is.null(layer) &&
        identical(class(layer$geom)[1], "GeomRibbon")
      pairs <- if (from_summary) summary_band_pairs(plot) else NULL
      rows <- if (from_summary) {
        summary_band_rows(layer, plot, panel_id, pairs)
      } else {
        lineribbon_quantile_rows(
          layer, plot, self$get_layer_built_data(built, panel_id)
        )
      }
      if (!is.null(rows) && nrow(rows) == 0L) {
        rows <- NULL
      }
      points <- if (is.null(rows)) list() else self$quantile_points(rows, built, panel_id)
      widths <- if (is.null(rows)) numeric(0) else sort(unique(rows$.width))

      selectors <- if (from_summary) {
        median_line <- pairs$median_line[[as.character(self$get_layer_index())]]
        self$summary_band_selectors(plot, gt, panel_ctx, length(widths), median_line)
      } else {
        self$band_selectors(plot, gt, panel_ctx, length(widths))
      }

      list(
        data = points,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout),
        type = "percentile_band"
      )
    },

    #' @description The quantiles at each x
    #'
    #' @param rows The layer's rows: `x`, `y` (the median), `ymin`, `ymax`
    #'   and `.width`
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of `{x, quantiles: [{level, value}]}`, by x
    quantile_points = function(rows, built, panel_id = NULL) {
      recovered <- self$recover_x_values(rows, built, panel_id)
      if (!is.null(recovered) && length(recovered) == nrow(rows)) {
        rows$label <- recovered
      } else {
        rows$label <- rows$x
      }

      by_x <- split(rows, rows$x)
      by_x <- by_x[order(as.numeric(names(by_x)))]
      lapply(by_x, function(at) {
        quantiles <- list(list(level = 0.5, value = as.numeric(at$y[[1]])))
        for (i in seq_len(nrow(at))) {
          w <- at$.width[[i]]
          quantiles <- c(quantiles, list(
            list(level = (1 - w) / 2, value = as.numeric(at$ymin[[i]])),
            list(level = (1 + w) / 2, value = as.numeric(at$ymax[[i]]))
          ))
        }
        levels <- vapply(quantiles, function(q) q$level, numeric(1))
        list(
          x = self$format_x_value(at$label[[1]]),
          quantiles = quantiles[order(levels)]
        )
      }) |> unname()
    },

    #' @description One selector per band, outermost first, then the median
    #' line's
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @param n_bands How many interval widths the data holds
    #' @return A list of selectors, or an empty list
    band_selectors = function(plot, gt = NULL, panel_ctx = NULL, n_bands = 0L) {
      if (is.null(gt) || n_bands < 1L) {
        return(list())
      }
      tree <- tryCatch(
        self$find_layer_grob_tree(plot, gt, panel_ctx),
        error = function(e) NULL
      )
      if (is.null(tree) || !inherits(tree, "gTree")) {
        return(list())
      }

      polygons <- self$band_polygon_names(tree)
      if (length(polygons) != n_bands) {
        return(list())
      }
      selectors <- lapply(polygons, function(name) {
        paste0("#", gsub("\\.", "\\\\.", paste0(name, ".1")), " polygon")
      })

      # ggdist draws the median once per band, the same line each time; the
      # first is the one named. Without one the core outlines the innermost
      # band for the median, which is where the line sits.
      lines <- Filter(
        function(g) !is.null(g$name) && grepl("^GRID\\.polyline\\.\\d+$", g$name),
        tree$children
      )
      if (length(lines) > 0L) {
        selectors <- c(selectors, list(
          paste0("#", gsub("\\.", "\\\\.", paste0(lines[[1]]$name, ".1")), " polyline")
        ))
      }
      selectors
    },

    #' @description The selectors of a `median_hilow` ribbon: its one band,
    #' then the median line drawn on it, when there is one
    #'
    #' The ribbon is drawn as one polygon, and the median line as the bare
    #' polyline `geom_line()` draws, found the way the line processor finds
    #' its own. Without the line the core outlines the band for the median,
    #' the band it sits inside.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @param n_bands How many interval widths the data holds
    #' @param median_line Index of the median line's layer, or NA
    #' @return A list of selectors, or an empty list
    summary_band_selectors = function(plot, gt = NULL, panel_ctx = NULL,
                                      n_bands = 0L, median_line = NA_integer_) {
      if (is.null(gt) || n_bands != 1L) {
        return(list())
      }
      tree <- tryCatch(
        self$find_layer_grob_tree(plot, gt, panel_ctx),
        error = function(e) NULL
      )
      if (is.null(tree) || !inherits(tree, "gTree")) {
        return(list())
      }
      polygons <- self$band_polygon_names(tree)
      if (length(polygons) != 1L) {
        return(list())
      }
      selectors <- list(
        paste0("#", gsub("\\.", "\\\\.", paste0(polygons[[1]], ".1")), " polygon")
      )

      if (length(median_line) == 1L && !is.na(median_line)) {
        line <- tryCatch(
          {
            panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
            if (is.null(panel_grob)) {
              NULL
            } else {
              self$find_layer_polyline_grob(plot, panel_grob, target = median_line)
            }
          },
          error = function(e) NULL
        )
        if (!is.null(line) && identical(as.integer(self$polyline_curve_count(line)), 1L)) {
          base_id <- gsub("^GRID\\.polyline\\.", "", line$name)
          selectors <- c(selectors, self$generate_single_line_selector(base_id))
        }
      }
      selectors
    }
  )
)

#' Whether the bundled maidr.js can build a `percentile_band` trace
#'
#' The `percentile_band` trace first shipped in maidr.js 4.14.0. Unlike the
#' ROC and PR curves there is no older reading to keep: a lineribbon was not
#' read at all before, so without the trace it stays unread.
#'
#' @return TRUE when the pinned bundle carries the trace
#' @keywords internal
percentile_band_trace_available <- function() {
  utils::compareVersion(MAIDR_VERSION, "4.14.0") >= 0
}

#' The quantile rows a lineribbon layer draws, or NULL when they are not
#' quantiles
#'
#' `stat_lineribbon()` leaves `.width`, `.point` and `.interval` in the
#' built data. `geom_lineribbon()` drawn from a `median_qi()` summary does
#' not -- they are columns of the layer's own data, which the built rows
#' follow one for one -- so they are read from there when the built data
#' lacks them.
#'
#' Declined -- NULL -- unless every row is a median with a quantile
#' interval, the layer draws one series (one row per x and width), the
#' widths are fractions of one, and the ribbon runs along x.
#'
#' @param layer A ggplot2 layer
#' @param plot_object The plot the layer belongs to
#' @param built_rows The layer's built data, or NULL to build it here
#' @return A data frame of `x`, `y`, `ymin`, `ymax`, `.width`, or NULL
#' @keywords internal
lineribbon_quantile_rows <- function(layer, plot_object, built_rows = NULL) {
  if (is.null(layer)) {
    return(NULL)
  }
  if (is.null(built_rows)) {
    index <- which(vapply(plot_object$layers, identical, logical(1), layer))
    if (length(index) != 1L) {
      return(NULL)
    }
    built_rows <- tryCatch(
      ggplot2::layer_data(plot_object, index),
      error = function(e) NULL
    )
  }
  if (!is.data.frame(built_rows) || nrow(built_rows) == 0L ||
    !all(c("x", "y", "ymin", "ymax") %in% names(built_rows))) {
    return(NULL)
  }
  if ("flipped_aes" %in% names(built_rows) && any(built_rows$flipped_aes %in% TRUE)) {
    return(NULL)
  }

  described <- c(".width", ".point", ".interval")
  if (!all(described %in% names(built_rows))) {
    own <- tryCatch(layer$data, error = function(e) NULL)
    if (!is.data.frame(own)) {
      own <- tryCatch(plot_object$data, error = function(e) NULL)
    }
    if (!is.data.frame(own) || nrow(own) != nrow(built_rows) ||
      !all(described %in% names(own))) {
      return(NULL)
    }
    for (column in described) {
      built_rows[[column]] <- own[[column]]
    }
  }

  if (!all(built_rows$.point %in% "median") ||
    !all(built_rows$.interval %in% "qi")) {
    return(NULL)
  }
  widths <- suppressWarnings(as.numeric(built_rows$.width))
  if (anyNA(widths) || any(widths <= 0 | widths >= 1)) {
    return(NULL)
  }
  built_rows$.width <- widths

  keys <- paste(built_rows$PANEL %||% 1L, built_rows$x, built_rows$.width)
  if (anyDuplicated(keys) > 0L) {
    # Two series in one layer (a lineribbon per model, say): one layer of
    # the trace holds one distribution, so the layer is not claimed.
    return(NULL)
  }

  built_rows
}

#' The interval width a `median_hilow` summary layer draws, or NULL
#'
#' `stat_summary(fun.data = median_hilow)` computes, at each x, the median
#' and the quantiles `(1 - w) / 2` and `(1 + w) / 2` of the y values there,
#' `w` being `fun.args$conf.int` (0.95 when unset): `Hmisc::smedian.hilow()`
#' takes them with `stats::quantile()`. The width is all a percentile band
#' needs to know, and it is read off the layer rather than inferred from
#' the drawn values.
#'
#' Read only where it is unambiguous: `fun.data` is ggplot2's own
#' `median_hilow` (the function or its name), no `fun`, `fun.min` or
#' `fun.max` is set beside it, and `fun.args` names nothing but `conf.int`
#' and `na.rm`. An unnamed argument would reach `conf.int` by position, and
#' any other summary -- `mean_cl_normal()`, `mean_se()` -- is not a
#' quantile interval at all.
#'
#' @param layer A ggplot2 layer
#' @return The width, in (0, 1], or NULL
#' @keywords internal
summary_hilow_width <- function(layer) {
  if (is.null(layer) || !identical(class(layer$stat)[1], "StatSummary")) {
    return(NULL)
  }
  params <- layer$stat_params
  fun_data <- params$fun.data
  is_hilow <- identical(fun_data, "median_hilow") ||
    identical(fun_data, ggplot2::median_hilow)
  if (!is_hilow || !is.null(params$fun) || !is.null(params$fun.min) ||
    !is.null(params$fun.max)) {
    return(NULL)
  }

  args <- params$fun.args
  if (is.null(args)) {
    args <- list()
  }
  arg_names <- names(args)
  if (length(args) > 0L && (is.null(arg_names) || any(arg_names == "") ||
    !all(arg_names %in% c("conf.int", "na.rm")))) {
    return(NULL)
  }
  width <- if (is.null(args$conf.int)) 0.95 else args$conf.int
  if (!is.numeric(width) || length(width) != 1L || !is.finite(width) ||
    width <= 0 || width > 1) {
    return(NULL)
  }
  as.numeric(width)
}

#' Whether a layer is a `stat_summary()` line of the median
#'
#' `stat_summary(geom = "line", fun = median)`, or a `median_hilow` summary
#' drawn as a line, whose `y` is the median whatever its width.
#'
#' @param layer A ggplot2 layer
#' @return TRUE or FALSE
#' @keywords internal
is_summary_median_line <- function(layer) {
  if (is.null(layer) || !class(layer$geom)[1] %in% c("GeomLine", "GeomPath") ||
    !identical(class(layer$stat)[1], "StatSummary")) {
    return(FALSE)
  }
  if (!is.null(summary_hilow_width(layer))) {
    return(TRUE)
  }
  params <- layer$stat_params
  fun <- params$fun
  is_median <- identical(fun, "median") || identical(fun, stats::median)
  is_median && is.null(params$fun.data) && is.null(params$fun.min) &&
    is.null(params$fun.max) && length(params$fun.args) == 0L
}

#' The `median_hilow` ribbons of a plot and the median lines drawn on them
#'
#' A `stat_summary(geom = "ribbon", fun.data = median_hilow)` layer is a
#' percentile band of one interval. Its median is computed by the stat but
#' not kept: `GeomRibbon` overwrites the built `y` with `ymin` when it sets
#' its data up. So the plot is built once more with each such ribbon drawn
#' as `geom_blank()`, which leaves the stat's rows as they were computed --
#' after the scales' transformations, as the drawn ribbon's are.
#'
#' A ribbon is kept only where it draws one series a panel along x (no
#' flipped orientation, no position adjustment, one row per panel and x).
#' Its median line is the one `stat_summary()` median line whose built
#' rows sit on the ribbon's medians at every x of every panel, when exactly
#' one does and that line sits on no other ribbon; a line the two readings
#' do not pin down stays a line of its own.
#'
#' @param plot_object A ggplot object
#' @return A list of `rows` (a list, by layer index, of data frames of
#'   `x`, `y` (the median), `ymin`, `ymax`, `.width` and `PANEL`) and
#'   `median_line` (an integer vector naming each ribbon's line, NA for
#'   none), or NULL when the plot has no such ribbon
#' @keywords internal
summary_band_pairs <- function(plot_object) {
  layers <- plot_object$layers
  if (length(layers) == 0L) {
    return(NULL)
  }
  ribbons <- which(vapply(layers, function(layer) {
    identical(class(layer$geom)[1], "GeomRibbon") &&
      identical(class(layer$position)[1], "PositionIdentity") &&
      !is.null(summary_hilow_width(layer))
  }, logical(1)))
  if (length(ribbons) == 0L) {
    return(NULL)
  }
  lines <- which(vapply(layers, is_summary_median_line, logical(1)))

  blanked <- plot_object
  for (i in ribbons) {
    layer <- ggplot2::ggproto(NULL, layers[[i]])
    layer$geom <- ggplot2::GeomBlank
    blanked$layers[[i]] <- layer
  }
  built <- tryCatch(
    suppressMessages(suppressWarnings(ggplot2::ggplot_build(blanked))),
    error = function(e) NULL
  )
  if (is.null(built)) {
    return(NULL)
  }

  one_series <- function(rows, columns) {
    is.data.frame(rows) && nrow(rows) > 0L && all(columns %in% names(rows)) &&
      !("flipped_aes" %in% names(rows) && any(rows$flipped_aes %in% TRUE)) &&
      anyDuplicated(paste(rows$PANEL %||% 1L, rows$x)) == 0L
  }

  rows <- list()
  for (i in ribbons) {
    at <- built$data[[i]]
    if (!one_series(at, c("x", "y", "ymin", "ymax"))) {
      next
    }
    at$.width <- summary_hilow_width(layers[[i]])
    if (is.null(at$PANEL)) {
      at$PANEL <- factor(1L)
    }
    rows[[as.character(i)]] <- at
  }
  if (length(rows) == 0L) {
    return(NULL)
  }

  sits_on <- function(line_rows, band_rows) {
    if (!one_series(line_rows, c("x", "y")) || nrow(line_rows) != nrow(band_rows)) {
      return(FALSE)
    }
    key <- function(r) paste(r$PANEL %||% 1L, r$x)
    at <- match(key(band_rows), key(line_rows))
    !anyNA(at) && isTRUE(all.equal(
      as.numeric(line_rows$y[at]), as.numeric(band_rows$y),
      tolerance = 1e-8, check.attributes = FALSE
    ))
  }
  matches <- matrix(
    FALSE,
    nrow = length(rows), ncol = length(lines),
    dimnames = list(names(rows), as.character(lines))
  )
  for (r in names(rows)) {
    for (l in as.character(lines)) {
      matches[r, l] <- sits_on(built$data[[as.integer(l)]], rows[[r]])
    }
  }
  median_line <- vapply(names(rows), function(r) {
    hit <- which(matches[r, ])
    if (length(hit) == 1L && sum(matches[, hit]) == 1L) {
      as.integer(lines[[hit]])
    } else {
      NA_integer_
    }
  }, integer(1))

  list(rows = rows, median_line = median_line)
}

#' The quantile rows of a `median_hilow` ribbon, or NULL when it is not one
#'
#' @param layer A ggplot2 layer
#' @param plot_object The plot the layer belongs to
#' @param panel_id Panel ID to scope the rows to (optional)
#' @param pairs The plot's [summary_band_pairs()], or NULL to read them here
#' @return A data frame of `x`, `y`, `ymin`, `ymax`, `.width`, or NULL
#' @keywords internal
summary_band_rows <- function(layer, plot_object, panel_id = NULL, pairs = NULL) {
  index <- which(vapply(plot_object$layers, identical, logical(1), layer))
  if (length(index) != 1L) {
    return(NULL)
  }
  if (is.null(pairs)) {
    pairs <- summary_band_pairs(plot_object)
  }
  rows <- pairs$rows[[as.character(index)]]
  if (is.null(rows)) {
    return(NULL)
  }
  if (!is.null(panel_id)) {
    rows <- rows[as.character(rows$PANEL) == as.character(panel_id), , drop = FALSE]
  }
  rows
}

#' Whether a layer is the median line of a `median_hilow` ribbon
#'
#' Such a line is read as the band's median, so it is not read again as a
#' line of its own.
#'
#' @param layer_index Index of the layer in `plot_object$layers`
#' @param plot_object A ggplot object
#' @return TRUE or FALSE
#' @keywords internal
summary_band_folds_line <- function(layer_index, plot_object) {
  if (!is_summary_median_line(plot_object$layers[[layer_index]])) {
    return(FALSE)
  }
  pairs <- summary_band_pairs(plot_object)
  !is.null(pairs) && layer_index %in% pairs$median_line
}
