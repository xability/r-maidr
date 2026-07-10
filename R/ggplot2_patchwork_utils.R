#' Patchwork Processing Utilities
#'
#' Utility functions for processing patchwork multipanel compositions.
#' These functions handle panel discovery, leaf extraction, and processing
#' for patchwork plots in a unified way.
#'
#' @keywords internal

#' Process a patchwork plot and return organized subplot data
#' @param plot The patchwork plot object
#' @param layout Layout information
#' @param gtable Gtable object
#' @return List with organized subplot data in 2D grid format
process_patchwork_plot_data <- function(plot, layout, gtable) {
  # Discover panels via gtable layout
  panel_df <- find_patchwork_panels(gtable)
  if (nrow(panel_df) == 0) {
    return(list())
  }

  max_row <- max(panel_df$row)
  max_col <- max(panel_df$col)

  # Prepare grid structure
  grid <- vector("list", max_row)
  for (r in seq_len(max_row)) {
    grid[[r]] <- vector("list", max_col)
  }

  # Extract leaf plots in visual order
  leaves <- extract_patchwork_leaves(plot)

  # For each panel in row-major order, process layers
  ordered <- panel_df[order(panel_df$row, panel_df$col), ]
  for (i in seq_len(nrow(ordered))) {
    panel_index <- ordered$panel_index[i]
    row <- ordered$row[i]
    col <- ordered$col[i]

    # Pick the matching leaf plot if available; else fall back to full plot
    leaf_plot <- if (i <= length(leaves)) leaves[[i]] else plot
    panel_name <- ordered$name[i]

    subplot_data <- process_patchwork_panel(
      leaf_plot,
      panel_name,
      panel_index,
      row,
      col,
      layout,
      gtable
    )
    grid[[row]][[col]] <- subplot_data
  }

  # Canonical financial-chart pattern: candlestick over a volume-only bar
  # panel (via patchwork) collapses to a single subplot with up to three
  # layers (candlestick, bar, line) so the JS frontend announces it as one
  # plot containing N layers, matching py-maidr.
  grid <- merge_candlestick_volume_panels(grid)

  grid
}

#' Discover panels via gtable layout rows named '^panel-<num>' or '^panel-<row>-<col>'
#' Returns a data.frame with panel_index, name, t, l, row, col
#' @param gtable Gtable object
#' @return Data frame with panel information
find_patchwork_panels <- function(gtable) {
  if (is.null(gtable)) {
    return(data.frame())
  }
  layout <- gtable$layout
  # Keep only true panel entries, exclude 'panel-area' and others
  is_panel <- grepl("^panel-\\d+(-\\d+)?$", layout$name)
  idx <- which(is_panel)
  if (length(idx) == 0) {
    return(data.frame())
  }
  t_vals <- layout$t[idx]
  l_vals <- layout$l[idx]

  # Try parsing explicit row/col from name 'panel-R-C'
  names_vec <- layout$name[idx]
  parse_rc <- function(nm) {
    m <- regexec("^panel-(\\d+)-(\\d+)$", nm)
    p <- regmatches(nm, m)[[1]]
    if (length(p) == 3) {
      return(c(as.integer(p[2]), as.integer(p[3])))
    }
    c(NA_integer_, NA_integer_)
  }
  rc_mat <- t(vapply(names_vec, parse_rc, integer(2)))
  parsed_row <- rc_mat[, 1]
  parsed_col <- rc_mat[, 2]

  # If not parsed, derive row/col by ranking unique t/l
  unique_t <- sort(unique(t_vals))
  unique_l <- sort(unique(l_vals))
  map_row <- setNames(seq_along(unique_t), unique_t)
  map_col <- setNames(seq_along(unique_l), unique_l)
  ranked_row <- as.integer(map_row[as.character(t_vals)])
  ranked_col <- as.integer(map_col[as.character(l_vals)])

  final_row <- ifelse(is.na(parsed_row), ranked_row, parsed_row)
  final_col <- ifelse(is.na(parsed_col), ranked_col, parsed_col)
  data.frame(
    panel_index = idx,
    name = layout$name[idx],
    t = t_vals,
    l = l_vals,
    row = as.integer(final_row),
    col = as.integer(final_col)
  )
}

#' Recursively extract leaf ggplots in visual order
#' @param node Patchwork node or ggplot object
#' @return List of leaf ggplot objects
extract_patchwork_leaves <- function(node) {
  if (inherits(node, "patchwork")) {
    plots <- try(node$patches$plots, silent = TRUE)
    if (!inherits(plots, "try-error") && !is.null(plots)) {
      out <- list()
      for (p in plots) {
        out <- c(out, extract_patchwork_leaves(p))
      }
      return(out)
    }
    return(list())
  }
  if (inherits(node, "ggplot")) {
    return(list(node))
  }
  list()
}

#' Extract layout from a single leaf ggplot
#' @param leaf_plot The ggplot object
#' @return Layout with title and axes
extract_leaf_plot_layout <- function(leaf_plot) {
  # Extract x label: try labels$x first, fall back to mapping
  x_label <- leaf_plot$labels$x
  if (is.null(x_label) && !is.null(leaf_plot$mapping$x)) {
    x_label <- rlang::as_label(leaf_plot$mapping$x)
  }
  if (is.null(x_label)) x_label <- ""

  # Extract y label: try labels$y first, fall back to mapping
  y_label <- leaf_plot$labels$y
  if (is.null(y_label) && !is.null(leaf_plot$mapping$y)) {
    y_label <- rlang::as_label(leaf_plot$mapping$y)
  }
  if (is.null(y_label)) y_label <- ""

  list(
    title = if (!is.null(leaf_plot$labels$title)) leaf_plot$labels$title else "",
    axes = build_axes(x = x_label, y = y_label)
  )
}

#' Process a single patchwork panel
#' @param leaf_plot The leaf ggplot object
#' @param panel_name Panel name from gtable
#' @param panel_index Panel index
#' @param row Panel row
#' @param col Panel column
#' @param layout Layout information
#' @param gtable Gtable object
#' @return Processed panel data
process_patchwork_panel <- function(leaf_plot, panel_name, panel_index, row, col, layout, gtable) {
  subplot_id <- paste0("maidr-subplot-", as.integer(Sys.time()), "-", row, "-", col)

  # Extract layout from leaf plot (has its own title and axes)
  leaf_layout <- extract_leaf_plot_layout(leaf_plot)

  layers <- list()
  for (layer_idx in seq_along(leaf_plot$layers)) {
    layer <- leaf_plot$layers[[layer_idx]]

    # Use unified layer processor creation logic
    layer_info <- list(index = layer_idx, type = class(layer$geom)[1])

    registry <- get_global_registry()
    system_name <- "ggplot2"
    factory <- registry$get_processor_factory(system_name)
    adapter <- registry$get_adapter(system_name)

    layer_type <- adapter$detect_layer_type(layer, leaf_plot)

    # Layers tagged "skip" (e.g. tidyquant's wick layer, which is folded
    # into the candlestick body layer) must not produce a maidr layer.
    if (identical(layer_type, "skip")) {
      next
    }

    processor <- factory$create_processor(layer_type, layer_info)

    if (!is.null(processor)) {
      # New panel context API
      panel_ctx <- list(
        panel_name = panel_name,
        panel_index = panel_index,
        row = row,
        col = col,
        layer_index = layer_idx
      )

      result <- processor$process(
        leaf_plot,
        leaf_layout,
        built = ggplot2::ggplot_build(leaf_plot),
        gt = gtable,
        scale_mapping = NULL,
        panel_ctx = panel_ctx,
        panel_id = NULL
      )

      if (!is.null(result)) {
        layer_entry <- list(
          id = paste0("maidr-layer-", layer_idx),
          type = if (!is.null(result$type)) {
            result$type
          } else {
            registry <- get_global_registry()
            system_name <- "ggplot2"
            adapter <- registry$get_adapter(system_name)
            adapter$detect_layer_type(layer, leaf_plot)
          },
          title = if (!is.null(leaf_plot$labels$title)) leaf_plot$labels$title else "",
          axes = if (!is.null(result$axes)) {
            result$axes
          } else {
            build_axes(
              x = if (!is.null(leaf_plot$labels$x)) leaf_plot$labels$x else "",
              y = if (!is.null(leaf_plot$labels$y)) leaf_plot$labels$y else ""
            )
          },
          data = result$data,
          selectors = result$selectors
        )
        layers[[length(layers) + 1]] <- layer_entry
      }
    }
  }

  panel <- list(
    id = subplot_id,
    layers = layers
  )

  # Multiple line layers in one panel (e.g. several geom_ma overlays on a
  # candlestick) should be merged into a single multi-series line layer so
  # the JS frontend announces them as one "multiline" layer (matching
  # py-maidr's behaviour) rather than N separate layers.
  collapse_lines_to_multiseries(panel)
}

# ==============================================================================
# Panel-merging helpers (candlestick + volume + MA multilines)
# ==============================================================================
#
# These helpers post-process the patchwork subplot grid so that the canonical
# financial-chart pattern produces a single accessible subplot with up to
# three layers (candlestick, bar, line) instead of two separate subplots.
# Volume y-values are also embedded into candlestick data points so the
# description table mirrors py-maidr's CandlestickPoint.volume field.

#' Does a panel contain a layer of the given type?
#' @param panel A processed patchwork panel (with `$layers`)
#' @param type Layer type string ("candlestick", "bar", "line", ...)
#' @return Logical
#' @keywords internal
panel_has_layer_of_type <- function(panel, type) {
  if (is.null(panel) || is.null(panel$layers) || length(panel$layers) == 0) {
    return(FALSE)
  }
  types <- vapply(panel$layers, function(l) {
    if (!is.null(l$type)) l$type else NA_character_
  }, character(1))
  any(types == type, na.rm = TRUE)
}

#' Return the (first) layer in `panel` whose type matches `type`
#' @keywords internal
panel_layer_of_type <- function(panel, type) {
  if (is.null(panel) || is.null(panel$layers)) {
    return(NULL)
  }
  for (l in panel$layers) {
    if (!is.null(l$type) && identical(l$type, type)) {
      return(l)
    }
  }
  NULL
}

#' Is this panel a volume-only bar panel (single bar layer, no other layers)?
#' @keywords internal
is_volume_only_bar_panel <- function(panel) {
  if (is.null(panel) || is.null(panel$layers) || length(panel$layers) != 1L) {
    return(FALSE)
  }
  identical(panel$layers[[1]]$type, "bar")
}

#' Collapse multiple "line" layer entries in a single panel into one
#' multi-series line layer entry. Other layers are left untouched.
#'
#' The first line layer's id, title, and axes are preserved; data and
#' selectors are concatenated across all line layers.
#'
#' @param panel A processed panel list with $id and $layers
#' @return Panel with line layers merged
#' @keywords internal
collapse_lines_to_multiseries <- function(panel) {
  if (is.null(panel) || is.null(panel$layers) || length(panel$layers) < 2) {
    return(panel)
  }

  layers <- panel$layers
  is_line <- vapply(layers, function(l) {
    isTRUE(identical(l$type, "line"))
  }, logical(1))

  if (sum(is_line) < 2L) {
    return(panel)
  }

  line_layers <- layers[is_line]
  merged_line <- merge_line_layers(line_layers)

  # Rebuild layers list: keep non-line layers in their original order,
  # insert the merged line layer at the position of the first line layer.
  out <- list()
  inserted <- FALSE
  for (i in seq_along(layers)) {
    if (is_line[i]) {
      if (!inserted) {
        out[[length(out) + 1L]] <- merged_line
        inserted <- TRUE
      }
      # Skip subsequent line layers (they've been merged in).
      next
    }
    out[[length(out) + 1L]] <- layers[[i]]
  }

  panel$layers <- out
  panel
}

#' Combine a list of single-line layer entries into one multi-series line entry.
#'
#' Each input line layer's `data` is a list-of-series (typically length-1 for
#' a single GeomLine/GeomMA). We concatenate all series across all layers.
#'
#' Selector handling: the line layer's selector generator (panel_ctx path in
#' `Ggplot2LineLayerProcessor$generate_selectors`) discovers *all* polyline
#' grobs in the panel, so when there are N line layers in the same panel
#' each input layer's `selectors` list is the same length-N set. After
#' merging we want exactly one selector per series (so the JS frontend
#' precondition `selectors.length === data.length` holds). We therefore
#' deduplicate selectors across input layers and trim/pad to the merged
#' series count.
#' @keywords internal
merge_line_layers <- function(line_layers) {
  first <- line_layers[[1]]

  combined_data <- list()
  all_selectors <- list()

  for (l in line_layers) {
    # `data` should already be a list of series. Be defensive: if it's a flat
    # list of points (unwrapped single series), wrap it.
    if (!is.null(l$data)) {
      d <- l$data
      if (length(d) > 0 && !is.null(d[[1]]) && !is.list(d[[1]][[1]])) {
        # Looks like flat points -> wrap as single series
        d <- list(d)
      }
      for (series in d) {
        combined_data[[length(combined_data) + 1L]] <- series
      }
    }
    if (!is.null(l$selectors)) {
      sels <- l$selectors
      if (!is.list(sels)) {
        sels <- list(sels)
      }
      for (s in sels) {
        all_selectors[[length(all_selectors) + 1L]] <- s
      }
    }
  }

  # Dedupe selectors (panel_ctx path returns the same set for each line layer
  # in the panel), preserving discovery order.
  seen <- character(0)
  unique_selectors <- list()
  for (s in all_selectors) {
    key <- if (is.character(s)) s else paste0(unlist(s), collapse = "\u0001")
    if (!(key %in% seen)) {
      seen <- c(seen, key)
      unique_selectors[[length(unique_selectors) + 1L]] <- s
    }
  }

  # Trim to series count so selectors.length === data.length.
  n_series <- length(combined_data)
  if (length(unique_selectors) > n_series) {
    unique_selectors <- unique_selectors[seq_len(n_series)]
  }

  list(
    id = first$id,
    type = "line",
    title = first$title,
    axes = first$axes,
    data = combined_data,
    selectors = unique_selectors
  )
}

#' Embed volume y-values from a bar layer into the candlestick layer's data.
#'
#' Strategy:
#'   1. If both layers have the same number of points, embed positionally.
#'      This is the canonical case: patchwork stacks two panels driven by
#'      the same date column, so the i-th candle and the i-th bar refer to
#'      the same trading day even if the bar layer's x is formatted
#'      differently from the candle's `value`.
#'   2. Otherwise, fall back to string-matching the candle's `value` field
#'      against the bar layer's `x` field.
#' @keywords internal
embed_volume_into_candle_data <- function(candle_layer, bar_layer) {
  if (is.null(candle_layer$data) || length(candle_layer$data) == 0) {
    return(candle_layer)
  }
  if (is.null(bar_layer$data) || length(bar_layer$data) == 0) {
    return(candle_layer)
  }

  n_c <- length(candle_layer$data)
  n_b <- length(bar_layer$data)

  if (n_c == n_b) {
    for (i in seq_len(n_c)) {
      bar_pt <- bar_layer$data[[i]]
      if (!is.null(bar_pt$y)) {
        pt <- candle_layer$data[[i]]
        pt$volume <- bar_pt$y
        candle_layer$data[[i]] <- pt
      }
    }
    return(candle_layer)
  }

  # Fallback: string-match by candle$value vs bar$x
  bar_lookup <- new.env(hash = TRUE, parent = emptyenv())
  for (pt in bar_layer$data) {
    if (!is.null(pt$x) && !is.null(pt$y)) {
      assign(as.character(pt$x), pt$y, envir = bar_lookup)
    }
  }

  for (i in seq_along(candle_layer$data)) {
    pt <- candle_layer$data[[i]]
    if (!is.null(pt$value)) {
      key <- as.character(pt$value)
      if (exists(key, envir = bar_lookup, inherits = FALSE)) {
        pt$volume <- get(key, envir = bar_lookup, inherits = FALSE)
        candle_layer$data[[i]] <- pt
      }
    }
  }

  candle_layer
}

#' Post-process a 2D subplot grid: if the layout is candlestick over
#' volume-only bar (2 rows x 1 col, sharing an x-axis), collapse to a single
#' 1x1 subplot whose layers are candlestick (+ embedded volume), bar, and
#' optional line (multi-series MAs).
#' @keywords internal
merge_candlestick_volume_panels <- function(grid) {
  if (!is.list(grid) || length(grid) != 2L) {
    return(grid)
  }
  if (!is.list(grid[[1]]) || !is.list(grid[[2]])) {
    return(grid)
  }
  if (length(grid[[1]]) != 1L || length(grid[[2]]) != 1L) {
    return(grid)
  }

  top <- grid[[1]][[1]]
  bottom <- grid[[2]][[1]]

  if (is.null(top) || is.null(bottom)) {
    return(grid)
  }
  if (!panel_has_layer_of_type(top, "candlestick")) {
    return(grid)
  }
  if (!is_volume_only_bar_panel(bottom)) {
    return(grid)
  }

  candle <- panel_layer_of_type(top, "candlestick")
  bar    <- bottom$layers[[1]]
  line   <- panel_layer_of_type(top, "line")  # may be NULL

  # Embed volume y-values into candlestick data points
  candle <- embed_volume_into_candle_data(candle, bar)

  merged_layers <- list(candle, bar)
  if (!is.null(line)) {
    merged_layers[[length(merged_layers) + 1L]] <- line
  }

  merged_panel <- list(
    id = top$id,
    layers = merged_layers
  )

  # Return a 1x1 grid
  list(list(merged_panel))
}
