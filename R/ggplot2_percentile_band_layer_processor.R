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

      rows <- lineribbon_quantile_rows(
        self$get_layer(plot), plot, self$get_layer_built_data(built, panel_id)
      )
      points <- if (is.null(rows)) list() else self$quantile_points(rows, built, panel_id)
      widths <- if (is.null(rows)) numeric(0) else sort(unique(rows$.width))

      list(
        data = points,
        selectors = self$band_selectors(plot, gt, panel_ctx, length(widths)),
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
