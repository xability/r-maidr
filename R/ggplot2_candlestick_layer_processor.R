#' Candlestick Layer Processor
#'
#' Processes candlestick chart layers produced by `tidyquant::geom_candlestick()`.
#'
#' tidyquant's `geom_candlestick()` expands into TWO ggplot layers:
#'   1. A `GeomLinerangeBC` (BC = barchart) layer drawing the high-low wicks.
#'   2. A `GeomRectCS` (CS = candlestick) layer drawing the open-close bodies.
#'
#' The adapter tags the wick layer as `"skip"` so the orchestrator does not
#' create a separate maidr layer for it. This processor handles only the
#' second (body) layer, but reads back into the wick layer's grobs to
#' produce wick CSS selectors.
#'
#' Output type: `"candlestick"`. Each data point is a `CandlestickPoint`
#' with `value`, `open`, `high`, `low`, `close`, optional `volume`,
#' computed `trend` (Bull / Bear / Neutral) and `volatility` (high - low).
#'
#' Selectors are emitted as a single `CandlestickSelector` object whose
#' `body` and `wick` fields are arrays of per-candle CSS selectors using
#' `:nth-of-type` against the rect/line elements of the gridSVG-exported
#' tidyquant grobs.
#'
#' @keywords internal
Ggplot2CandlestickProcessor <- R6::R6Class(
  "Ggplot2CandlestickProcessor",
  inherit = LayerProcessor,
  public = list(

    #' @description Process the candlestick layer
    #' @param plot ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data
    #' @param gt Gtable object
    #' @param scale_mapping Scale mapping (unused for candlestick)
    #' @param grob_id Grob ID (faceting; not yet supported for candlestick)
    #' @param panel_id Panel id (patchwork; accepted for signature parity)
    #' @param panel_ctx Panel context (faceting; not yet supported)
    #' @return Maidr candlestick layer list
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      data <- self$extract_data(plot, built, scale_mapping)
      selectors <- self$generate_selectors(plot, gt, grob_id, panel_ctx)

      list(
        type = "candlestick",
        data = data,
        selectors = selectors,
        orientation = "vert",
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout)
      )
    },

    # ------------------------------------------------------------------
    # Data extraction
    # ------------------------------------------------------------------

    #' @description Extract OHLC data points from the plot
    #' @param plot ggplot2 object
    #' @param built Built plot data
    #' @param scale_mapping Unused
    #' @return List of CandlestickPoint dicts
    extract_data = function(plot, built = NULL, scale_mapping = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      mapping <- self$get_effective_mapping(plot)
      original <- self$get_original_data(plot)

      x_col     <- self$resolve_col(mapping$x, original)
      open_col  <- self$resolve_col(mapping$open, original)
      high_col  <- self$resolve_col(mapping$high, original)
      low_col   <- self$resolve_col(mapping$low, original)
      close_col <- self$resolve_col(mapping$close, original)
      vol_col   <- self$resolve_col(mapping$volume, original)

      # Validate required OHLC columns are present
      required <- list(open = open_col, high = high_col,
                       low = low_col, close = close_col)
      missing_cols <- names(required)[vapply(required, is.null, logical(1))]
      if (length(missing_cols) > 0) {
        warning(
          "Candlestick layer is missing required mapping(s): ",
          paste(missing_cols, collapse = ", "),
          ". Falling back to empty data.",
          call. = FALSE
        )
        return(list())
      }
      if (is.null(original) || nrow(original) == 0) {
        return(list())
      }

      n <- nrow(original)
      data_points <- vector("list", n)

      for (i in seq_len(n)) {
        x_raw <- if (!is.null(x_col)) original[[x_col]][i] else i
        open_v  <- as.numeric(original[[open_col]][i])
        high_v  <- as.numeric(original[[high_col]][i])
        low_v   <- as.numeric(original[[low_col]][i])
        close_v <- as.numeric(original[[close_col]][i])

        trend <- if (isTRUE(close_v > open_v)) {
          "Bull"
        } else if (isTRUE(close_v < open_v)) {
          "Bear"
        } else {
          "Neutral"
        }

        volatility <- round((high_v - low_v) * 100) / 100

        point <- list(
          value = self$format_x_value(x_raw),
          open = open_v,
          high = high_v,
          low = low_v,
          close = close_v,
          trend = trend,
          volatility = volatility
        )

        if (!is.null(vol_col) && vol_col %in% names(original)) {
          vol_v <- suppressWarnings(as.numeric(original[[vol_col]][i]))
          if (!is.na(vol_v)) {
            point$volume <- vol_v
          }
        }

        data_points[[i]] <- point
      }

      data_points
    },

    # ------------------------------------------------------------------
    # Selectors
    # ------------------------------------------------------------------

    #' @description Generate candlestick CSS selectors
    #'
    #' Returns a single `CandlestickSelector` object with `body` and `wick`
    #' as single CSS group selectors (one per element kind, not per candle).
    #' The maidr JS layer uses these to grab all candle elements at once and
    #' then auto-derives `open`/`close` from body rect edges based on trend.
    #'
    #' @param plot ggplot2 object
    #' @param gt Gtable object
    #' @param grob_id Grob ID (faceting)
    #' @param panel_ctx Panel context (faceting)
    #' @return Named list with `body` and (optionally) `wick` single-string
    #'   selectors, or empty list if grobs cannot be located.
    generate_selectors = function(plot, gt = NULL, grob_id = NULL,
                                  panel_ctx = NULL) {
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      panel_grob <- self$find_panel_grob(gt, panel_ctx)
      if (is.null(panel_grob)) {
        return(list())
      }

      # tidyquant emits a single rect grob (body) and a single segments grob
      # (wick) directly under the panel. Find them by name pattern.
      rect_name <- self$find_first_child_name(
        panel_grob, "^geom_rect\\.rect"
      )
      seg_name <- self$find_first_child_name(
        panel_grob, "^geom_linerange\\.segments|^geom_segment\\.segments"
      )

      esc <- function(id) gsub("\\.", "\\\\.", id)
      with_suffix <- function(id) {
        if (is.null(id)) return(NULL)
        if (grepl("\\.\\d+\\.\\d+$", id)) id else paste0(id, ".1")
      }

      n_candles <- self$count_candles(plot)
      if (n_candles <= 0) {
        return(list())
      }

      sel <- list()

      # Extract the body grob's numeric index (e.g. "57" from
      # "geom_rect.rect.57") so we can scope the injected open/close
      # element group ids per layer.
      rect_index <- NULL
      if (!is.null(rect_name)) {
        rid <- esc(with_suffix(rect_name))
        # Single group selector targeting all body rects under the grob.
        sel$body <- paste0("#", rid, " rect")

        m <- regmatches(rect_name, regexpr("\\d+$", rect_name))
        if (length(m) > 0 && nzchar(m)) {
          rect_index <- m
        }
      }

      if (!is.null(seg_name)) {
        sid <- esc(with_suffix(seg_name))
        # tidyquant's GeomLinerangeBC is exported by gridSVG as <polyline>
        # elements (one per candle).
        sel$wick <- paste0("#", sid, " polyline")
      }

      # Open/close virtual line groups are injected post grid.export() by
      # `inject_candlestick_open_close()` in svg_utils.R. We emit explicit
      # selectors here so the upstream maidr JS skips its (Y-flip-unaware)
      # auto-derivation heuristic and uses the exact lines we placed.
      if (!is.null(rect_index)) {
        sel$open  <- paste0("#maidr-cs-opens-",  rect_index, " line")
        sel$close <- paste0("#maidr-cs-closes-", rect_index, " line")
      }

      if (length(sel) == 0) {
        return(list())
      }

      sel
    },

    # ------------------------------------------------------------------
    # Axes (override base extract_layer_axes for candlestick semantics)
    # ------------------------------------------------------------------

    #' @description Extract axes labels for candlestick layer
    #'
    #' Candlestick layer mappings are typically NULL (top-level mapping
    #' carries x/open/high/low/close). The base implementation only inspects
    #' `layer_mapping$x` and `layer_mapping$y`, which yields blank labels.
    #' Here we additionally fall back to `plot$mapping$x` and synthesize a
    #' "Price" y-label since OHLC has no single y mapping.
    #'
    #' @param plot ggplot2 object
    #' @param layout Layout information
    #' @return list(x = list(label = ...), y = list(label = ...))
    extract_layer_axes = function(plot, layout) {
      x_label <- extract_axis_label(layout$axes$x, default = "")
      y_label <- extract_axis_label(layout$axes$y, default = "")

      mapping <- self$get_effective_mapping(plot)

      if (is.null(x_label) || !nzchar(x_label)) {
        x_label <- tryCatch(
          if (!is.null(mapping$x)) rlang::as_label(mapping$x) else "",
          error = function(e) ""
        )
      }
      if (is.null(y_label) || !nzchar(y_label)) {
        y_label <- "Price"
      }

      list(
        x = list(label = x_label),
        y = list(label = y_label)
      )
    },

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    #' @description Resolve a mapping quosure to a column name in `data`
    resolve_col = function(mapping_expr, data) {
      if (is.null(mapping_expr)) return(NULL)
      nm <- tryCatch(rlang::as_label(mapping_expr), error = function(e) NULL)
      if (is.null(nm)) return(NULL)
      if (!is.null(data) && nm %in% names(data)) nm else NULL
    },

    #' @description Format an x-axis value as character
    format_x_value = function(x) {
      if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) {
        return(format(x))
      }
      as.character(x)
    },

    #' @description Get the effective mapping (layer mapping merged on top)
    get_effective_mapping = function(plot) {
      layer_index <- self$get_layer_index()
      layer_mapping <- plot$layers[[layer_index]]$mapping
      plot_mapping <- plot$mapping
      utils::modifyList(
        if (is.null(plot_mapping)) list() else as.list(plot_mapping),
        if (is.null(layer_mapping)) list() else as.list(layer_mapping)
      )
    },

    #' @description Get original data for the layer (falls back to plot$data)
    get_original_data = function(plot) {
      layer_index <- self$get_layer_index()
      layer <- plot$layers[[layer_index]]
      if (!is.null(layer$data) && is.data.frame(layer$data) &&
            nrow(layer$data) > 0) {
        return(layer$data)
      }
      if (is.data.frame(plot$data)) {
        return(plot$data)
      }
      data.frame()
    },

    #' @description Count candles from the original data
    count_candles = function(plot) {
      d <- self$get_original_data(plot)
      if (is.data.frame(d)) nrow(d) else 0L
    },

    #' @description Find the panel grob (panel_ctx-aware)
    find_panel_grob = function(gt, panel_ctx = NULL) {
      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        idx <- which(grepl(paste0("^", panel_ctx$panel_name, "\\b"),
                           gt$layout$name))
      } else {
        idx <- which(gt$layout$name == "panel")
      }
      if (length(idx) == 0) return(NULL)
      pg <- gt$grobs[[idx[1]]]
      if (!inherits(pg, "gTree")) return(NULL)
      pg
    },

    #' @description Find the first descendant whose name matches `pattern`
    find_first_child_name = function(grob, pattern) {
      if (!inherits(grob, "gTree") || is.null(grob$children)) {
        return(NULL)
      }
      for (nm in names(grob$children)) {
        ch <- grob$children[[nm]]
        if (!is.null(ch$name) && grepl(pattern, ch$name)) {
          return(ch$name)
        }
      }
      # Recurse one level deeper if not found at top
      for (nm in names(grob$children)) {
        ch <- grob$children[[nm]]
        if (inherits(ch, "gTree")) {
          found <- self$find_first_child_name(ch, pattern)
          if (!is.null(found)) return(found)
        }
      }
      NULL
    }
  )
)
