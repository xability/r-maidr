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
    x_label <- rlang::as_name(leaf_plot$mapping$x)
  }
  if (is.null(x_label)) x_label <- ""

  # Extract y label: try labels$y first, fall back to mapping
  y_label <- leaf_plot$labels$y
  if (is.null(y_label) && !is.null(leaf_plot$mapping$y)) {
    y_label <- rlang::as_name(leaf_plot$mapping$y)
  }
  if (is.null(y_label)) y_label <- ""

  list(
    title = if (!is.null(leaf_plot$labels$title)) leaf_plot$labels$title else "",
    axes = list(x = x_label, y = y_label)
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
            list(
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

  list(
    id = subplot_id,
    layers = layers
  )
}
