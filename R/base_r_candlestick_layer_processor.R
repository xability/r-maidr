#' Base R Candlestick Layer Processor
#'
#' Processes Base R candlestick chart layers produced by
#' `quantmod::chartSeries(x, type = "candlesticks")`.
#'
#' Each xts row becomes a single navigable `CandlestickPoint` with
#' `value`, `open`, `high`, `low`, `close`, computed `trend`
#' (Bull / Bear / Neutral), `volatility` (high - low) and optional
#' `volume` (when `quantmod::has.Vo()` is `TRUE`).
#'
#' Selectors are derived from the gridSVG export of the chartSeries
#' grob (captured via `ggplotify::as.grob()`). chartSeries draws candle
#' bodies via a single vectorized `rect()` call (each candle body is one
#' SVG `<rect>` child of `graphics-plot-<N>-rect-*`) and upper/lower
#' wicks via `segments()` calls (one SVG `<polyline>` per wick under
#' `graphics-plot-<N>-segments-*`).
#'
#' @keywords internal
BaseRCandlestickLayerProcessor <- R6::R6Class(
  "BaseRCandlestickLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL,
                       layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt, data)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      candle_layer <- list(
        type = "candlestick",
        data = data,
        selectors = selectors,
        orientation = "vert",
        title = title,
        axes = axes
      )

      # If chartSeries(TA = "addVo()") is in effect, emit an additional
      # volume bar layer so users can navigate volume independently.
      if (self$has_add_vo(layer_info)) {
        vol_layer <- self$build_volume_layer(layer_info, gt, data)
        if (!is.null(vol_layer)) {
          return(list(
            multi_layer = TRUE,
            type = "candlestick",
            layers = list(candle_layer, vol_layer),
            # Top-level convenience copies (for combined_selectors collection)
            selectors = selectors,
            title = title,
            axes = axes
          ))
        }
      }

      candle_layer
    },

    #' @description Detect whether the chartSeries call requests addVo()
    has_add_vo = function(layer_info) {
      if (is.null(layer_info)) {
        return(FALSE)
      }
      args <- layer_info$plot_call$args
      ta <- args$TA
      if (is.null(ta)) {
        return(FALSE)
      }
      # TA can be a character string ("addVo()") or a list/character
      # vector of TA expressions.
      ta_chr <- tryCatch(
        vapply(as.list(ta), function(x) {
          tryCatch(as.character(x)[[1L]], error = function(e) "")
        }, character(1)),
        error = function(e) as.character(ta)
      )
      any(grepl("addVo\\s*\\(", ta_chr))
    },

    #' @description Build a "bar" layer carrying volume data
    build_volume_layer = function(layer_info, gt, candle_data) {
      if (is.null(layer_info)) {
        return(NULL)
      }
      args <- layer_info$plot_call$args
      x <- args$x
      if (is.null(x) && length(args) > 0) {
        x <- args[[1]]
      }
      if (is.null(x)) {
        return(NULL)
      }
      if (!requireNamespace("quantmod", quietly = TRUE)) {
        return(NULL)
      }
      has_vol <- isTRUE(all(
        tryCatch(quantmod::has.Vo(x), error = function(e) FALSE)
      ))
      if (!has_vol) {
        return(NULL)
      }

      vol_vec <- suppressWarnings(as.numeric(quantmod::Vo(x)))
      idx <- tryCatch(zoo::index(x), error = function(e) seq_along(vol_vec))
      labels <- self$format_x_values(idx)

      n <- min(length(vol_vec), length(labels))
      if (n == 0L) {
        return(NULL)
      }

      points <- vector("list", n)
      for (i in seq_len(n)) {
        points[[i]] <- list(x = labels[[i]], y = vol_vec[[i]])
      }

      vol_selectors <- self$generate_volume_selectors(layer_info, gt, n)

      list(
        type = "bar",
        data = points,
        selectors = vol_selectors,
        title = "Volume",
        axes = build_axes(x = "Date", y = "Volume")
      )
    },

    #' @description Generate selectors for the addVo() volume bar panel
    #'
    #' chartSeries(TA = "addVo()") creates a second plotting window. In
    #' the gridSVG export that maps to a second `graphics-plot-<N>` group
    #' (typically N = 2). Returns a per-bar selector list so each volume
    #' bar can be individually highlighted on navigation; matches the
    #' bar layer contract used by the Base R barplot processor.
    generate_volume_selectors = function(layer_info, gt, n_bars) {
      if (is.null(gt) || is.null(n_bars) || n_bars <= 0L) {
        return(list())
      }
      all_names <- self$collect_grob_names(gt)
      if (length(all_names) == 0L) {
        return(list())
      }
      # Find all graphics-plot-<N>-rect-* groups; the volume panel is
      # the second-plot rect group with vectorized children.
      plot_groups <- unique(sub(
        "^(graphics-plot-[0-9]+)-rect-[0-9]+$", "\\1",
        grep("^graphics-plot-[0-9]+-rect-[0-9]+$", all_names, value = TRUE)
      ))
      if (length(plot_groups) < 2L) {
        return(list())
      }
      # Take the second plot's rect group with the most vectorized children
      vol_plot <- plot_groups[[2L]]
      vol_rect_ids <- grep(
        paste0("^", vol_plot, "-rect-[0-9]+$"), all_names, value = TRUE
      )
      vol_rect_ids <- self$sort_ids(vol_rect_ids)
      if (length(vol_rect_ids) == 0L) {
        return(list())
      }
      body_id <- self$pick_largest_child_group(gt, vol_rect_ids)
      if (is.null(body_id)) {
        body_id <- vol_rect_ids[[1L]]
      }
      # Per-bar id: gridSVG names each rect child `<body_id>.1.<i>`.
      vapply(
        seq_len(n_bars),
        function(i) sprintf("#%s\\.1\\.%d", body_id, i),
        character(1)
      )
    },

    # ------------------------------------------------------------------
    # Data extraction
    # ------------------------------------------------------------------

    #' @description Extract OHLC data points from the chartSeries call
    #' @param layer_info Layer info containing the recorded plot call
    #' @return List of CandlestickPoint dicts
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }
      args <- layer_info$plot_call$args
      x <- args$x
      if (is.null(x) && length(args) > 0) {
        # chartSeries first positional argument is x
        x <- args[[1]]
      }
      if (is.null(x)) {
        return(list())
      }

      # quantmod is in Suggests; bail gracefully if missing
      if (!requireNamespace("quantmod", quietly = TRUE)) {
        warning(
          "Package 'quantmod' is required to extract candlestick data.",
          call. = FALSE
        )
        return(list())
      }
      has_ohlc <- tryCatch(
        quantmod::has.OHLC(x), error = function(e) FALSE
      )
      if (!isTRUE(all(has_ohlc))) {
        warning(
          "chartSeries input does not contain OHLC columns; ",
          "skipping candlestick data extraction.",
          call. = FALSE
        )
        return(list())
      }

      ohlc <- quantmod::OHLC(x)
      ohlc_mat <- as.matrix(ohlc)
      n <- nrow(ohlc_mat)
      if (is.null(n) || n == 0L) {
        return(list())
      }

      # Index (dates) for the value field
      idx <- tryCatch(zoo::index(x), error = function(e) seq_len(n))
      values <- self$format_x_values(idx)

      has_vol <- isTRUE(all(
        tryCatch(quantmod::has.Vo(x), error = function(e) FALSE)
      ))
      vol_vec <- if (has_vol) {
        suppressWarnings(as.numeric(quantmod::Vo(x)))
      } else {
        NULL
      }

      open_v <- as.numeric(ohlc_mat[, 1])
      high_v <- as.numeric(ohlc_mat[, 2])
      low_v <- as.numeric(ohlc_mat[, 3])
      close_v <- as.numeric(ohlc_mat[, 4])

      points <- vector("list", n)
      for (i in seq_len(n)) {
        o <- open_v[i]
        h <- high_v[i]
        l <- low_v[i]
        c_ <- close_v[i]

        trend <- if (isTRUE(c_ > o)) {
          "Bull"
        } else if (isTRUE(c_ < o)) {
          "Bear"
        } else {
          "Neutral"
        }

        volatility <- round((h - l) * 100) / 100

        pt <- list(
          value = values[i],
          open = o,
          high = h,
          low = l,
          close = c_,
          trend = trend,
          volatility = volatility
        )
        if (!is.null(vol_vec) && !is.na(vol_vec[i])) {
          pt$volume <- vol_vec[i]
        }
        points[[i]] <- pt
      }

      points
    },

    # ------------------------------------------------------------------
    # Selectors
    # ------------------------------------------------------------------

    #' @description Generate CSS selectors for the candlestick layer
    #'
    #' Returns ONE `CandlestickSelector` object (matching the maidr JS
    #' frontend contract in `src/model/candlestick.ts::mapToSvgElements`).
    #' The returned object has these named character-vector keys:
    #'   - `body`     length-N vector, one per-candle body-rect selector
    #'   - `wickHigh` length-N vector, one per-candle upper-wick selector
    #'                (omitted if only one segments group is present)
    #'   - `wickLow`  length-N vector, one per-candle lower-wick selector
    #'                (omitted if only one segments group is present)
    #'   - `wick`     length-N vector, used as fallback when there is only
    #'                one segments group (the frontend falls back to
    #'                `wick` when `wickHigh` / `wickLow` are absent).
    #'
    #' gridSVG emits a child id `<group-id>.1.<i>` for each primitive in
    #' a vectorized draw call. The frontend iterates each string array
    #' (`collectElements(arr)`) and picks the i-th element via
    #' `getElementAt(*, i)`, so per-candle selectors are required for
    #' single-candle highlighting on arrow-key navigation.
    #'
    #' IMPORTANT: do NOT return an array of objects (e.g.
    #' `[[body, wick], ...]`). The frontend's `Array.isArray()` branch
    #' would then take `selectors[0]` (the first dict) and pass it to
    #' `querySelectorAll`, yielding a JS `SyntaxError: '[object Object]'
    #' is not a valid selector`. The boxplot pattern of per-item dicts
    #' does NOT apply here because each chart model has its own contract.
    #'
    #' @param layer_info Layer info (used for fallback plot index)
    #' @param gt The captured chartSeries grob (from ggplotify::as.grob)
    #' @param extracted_data Previously extracted data (used for count)
    #' @return Named list (single CandlestickSelector) or `list()` when
    #'   grobs cannot be located.
    generate_selectors = function(layer_info, gt = NULL,
                                  extracted_data = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      n_candles <- if (is.list(extracted_data)) length(extracted_data) else 0L
      if (n_candles == 0L) {
        return(list())
      }

      plot_index <- if (!is.null(layer_info) &&
                       !is.null(layer_info$group_index)) {
        layer_info$group_index
      } else if (!is.null(layer_info) && !is.null(layer_info$index)) {
        layer_info$index
      } else {
        1L
      }

      all_names <- self$collect_grob_names(gt)
      if (length(all_names) == 0L) {
        return(list())
      }

      # chartSeries draws candle bodies via one vectorized rect() call;
      # gridSVG exports a single <g id="graphics-plot-N-rect-K"> with one
      # <rect> child per candle, named `graphics-plot-N-rect-K.1.<i>`.
      rect_pat <- paste0("^graphics-plot-", plot_index, "-rect-[0-9]+$")
      rect_ids <- self$sort_ids(grep(rect_pat, all_names, value = TRUE))

      # Wicks are drawn via segments(); gridSVG exports each segments()
      # call as one <g> whose <polyline> children are named
      # `graphics-plot-N-segments-K.1.<i>`.
      seg_pat <- paste0("^graphics-plot-", plot_index, "-segments-[0-9]+$")
      seg_ids <- self$sort_ids(grep(seg_pat, all_names, value = TRUE))

      if (length(rect_ids) == 0L) {
        return(list())
      }

      # Pick the rect group with the largest number of children (the
      # vectorized candle bodies). When we cannot inspect children
      # counts directly, fall back to the first rect group.
      body_id <- self$pick_largest_child_group(gt, rect_ids)
      if (is.null(body_id)) {
        body_id <- rect_ids[[1L]]
      }

      per_item <- function(id) {
        vapply(
          seq_len(n_candles),
          function(i) sprintf("#%s\\.1\\.%d", id, i),
          character(1)
        )
      }

      selectors <- list(body = per_item(body_id))

      if (length(seg_ids) >= 2L) {
        # Two segments groups in chartSeries.
        # Per quantmod source `R/chartSeries.chob.R` (L169-173):
        #   FIRST  segments(x, Lows,  x, min(O,C))  -> LOWER wick
        #   SECOND segments(x, Highs, x, max(O,C))  -> UPPER wick
        # gridSVG names them in call order, so `seg_ids` sorted by
        # trailing integer gives:
        #   seg_ids[[1L]] = "graphics-plot-N-segments-1" = LOWER wick
        #   seg_ids[[2L]] = "graphics-plot-N-segments-2" = UPPER wick
        # (Verified empirically against the exported SVG: segments-1
        # connects body-bottom DOWN to low, segments-2 connects
        # body-top UP to high, accounting for gridSVG's
        # `translate(0,h) scale(1,-1)` y-flip on the local coords.)
        selectors$wickLow  <- per_item(seg_ids[[1L]])
        selectors$wickHigh <- per_item(seg_ids[[2L]])
      } else if (length(seg_ids) == 1L) {
        # Single segments group: emit `wick`; frontend falls back when
        # `wickHigh` / `wickLow` are absent.
        selectors$wick <- per_item(seg_ids[[1L]])
      }

      selectors
    },

    # ------------------------------------------------------------------
    # Axes / title
    # ------------------------------------------------------------------

    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes(x = "Date", y = "Price"))
      }
      args <- layer_info$plot_call$args
      x_title <- if (!is.null(args$xlab) && nzchar(args$xlab)) {
        args$xlab
      } else {
        "Date"
      }
      y_title <- if (!is.null(args$ylab) && nzchar(args$ylab)) {
        args$ylab
      } else {
        "Price"
      }
      build_axes(x = x_title, y = y_title)
    },

    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      args <- layer_info$plot_call$args
      # chartSeries accepts `name` (preferred) and `main`
      if (!is.null(args$name) && nzchar(as.character(args$name))) {
        return(as.character(args$name))
      }
      if (!is.null(args$main) && nzchar(as.character(args$main))) {
        return(as.character(args$main))
      }
      # Fall back to series name from xts colnames if available
      x <- args$x
      if (is.null(x) && length(args) > 0) {
        x <- args[[1]]
      }
      if (!is.null(x)) {
        cn <- tryCatch(colnames(x), error = function(e) NULL)
        if (!is.null(cn) && length(cn) > 0) {
          stub <- sub("\\..*$", "", cn[[1]])
          if (nzchar(stub)) {
            return(stub)
          }
        }
      }
      ""
    },

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    #' @description Format a vector of x-axis index values to character
    format_x_values = function(idx) {
      if (inherits(idx, c("Date", "POSIXct", "POSIXlt"))) {
        format(idx)
      } else {
        as.character(idx)
      }
    },

    #' @description Recursively collect all grob names in a grob tree
    collect_grob_names = function(g) {
      names <- character(0)
      if (is.null(g)) {
        return(names)
      }
      if (!is.null(g$name)) {
        names <- c(names, as.character(g$name))
      }
      if (inherits(g, "gList")) {
        for (i in seq_along(g)) {
          names <- c(names, self$collect_grob_names(g[[i]]))
        }
      }
      if (inherits(g, "gTree") && !is.null(g$children)) {
        for (i in seq_along(g$children)) {
          names <- c(names, self$collect_grob_names(g$children[[i]]))
        }
      }
      if (!is.null(g$grobs)) {
        for (i in seq_along(g$grobs)) {
          names <- c(names, self$collect_grob_names(g$grobs[[i]]))
        }
      }
      names
    },

    #' @description Sort grob ids by trailing integer suffix
    sort_ids = function(ids) {
      if (length(ids) == 0L) {
        return(ids)
      }
      ord <- order(suppressWarnings(
        as.integer(sub(".*-([0-9]+)$", "\\1", ids))
      ))
      ids[ord]
    },

    #' @description Find the grob node whose name matches `id`
    find_grob_by_name = function(g, id) {
      if (is.null(g)) {
        return(NULL)
      }
      if (!is.null(g$name) && identical(as.character(g$name), id)) {
        return(g)
      }
      if (inherits(g, "gList")) {
        for (i in seq_along(g)) {
          found <- self$find_grob_by_name(g[[i]], id)
          if (!is.null(found)) {
            return(found)
          }
        }
      }
      if (inherits(g, "gTree") && !is.null(g$children)) {
        for (i in seq_along(g$children)) {
          found <- self$find_grob_by_name(g$children[[i]], id)
          if (!is.null(found)) {
            return(found)
          }
        }
      }
      if (!is.null(g$grobs)) {
        for (i in seq_along(g$grobs)) {
          found <- self$find_grob_by_name(g$grobs[[i]], id)
          if (!is.null(found)) {
            return(found)
          }
        }
      }
      NULL
    },

    #' @description Count the number of primitive coordinates a grob carries
    grob_coord_count = function(g) {
      if (is.null(g)) {
        return(0L)
      }
      # rect grobs carry x/y/width/height; pick the longest
      lengths <- c(
        if (!is.null(g$x)) length(g$x) else 0L,
        if (!is.null(g$y)) length(g$y) else 0L,
        if (!is.null(g$width)) length(g$width) else 0L,
        if (!is.null(g$height)) length(g$height) else 0L
      )
      if (length(lengths) == 0L) {
        return(0L)
      }
      max(lengths)
    },

    #' @description Pick the rect-id whose grob has the most coordinates
    pick_largest_child_group = function(gt, ids) {
      if (length(ids) == 0L) {
        return(NULL)
      }
      counts <- vapply(ids, function(id) {
        node <- self$find_grob_by_name(gt, id)
        self$grob_coord_count(node)
      }, integer(1))
      if (all(counts == 0L)) {
        return(ids[[1L]])
      }
      ids[[which.max(counts)]]
    }
  )
)
