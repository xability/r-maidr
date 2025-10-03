#' Patchwork Processor
#'
#' Handles multipanel compositions created with the patchwork package.
#' Responsibilities:
#'  - Extract leaf ggplots in visual order
#'  - Discover panels from composed gtable layout (robust; no areas() needed)
#'  - Compute visual row/col by ranking t/l layout positions
#'  - For each panel, reuse existing layer processors and facet-style selector
#'    generation by passing composed gtable and panel-local grob IDs
#'
#' @keywords internal
PatchworkProcessor <- R6::R6Class("PatchworkProcessor",
  public = list(
    plot = NULL,
    layout = NULL,
    gt = NULL,
    initialize = function(plot, layout, gt = NULL) {
      self$plot <- plot
      self$layout <- layout
      self$gt <- gt
    },

    #' Recursively extract leaf ggplots in visual order
    extract_leaf_plots = function(node) {
      if (inherits(node, "patchwork")) {
        plots <- try(node$patches$plots, silent = TRUE)
        if (!inherits(plots, "try-error") && !is.null(plots)) {
          out <- list()
          for (p in plots) out <- c(out, self$extract_leaf_plots(p))
          return(out)
        }
        return(list())
      }
      if (inherits(node, "ggplot")) {
        # Do NOT follow patchwork_link; treat this ggplot as a leaf
        return(list(node))
      }
      list()
    },

    #' Derive grid dimensions from patchwork layout
    derive_grid_dims = function(pw, leaves_n) {
      ncol <- try(pw$patches$layout$ncol, silent = TRUE)
      if (inherits(ncol, "try-error") || is.null(ncol)) ncol <- 1L
      nrow <- try(pw$patches$layout$nrow, silent = TRUE)
      if (inherits(nrow, "try-error") || is.null(nrow)) {
        nrow <- ceiling(leaves_n / max(1L, as.integer(ncol)))
      }
      list(nrow = as.integer(nrow), ncol = as.integer(ncol))
    },

    #' Discover panels via gtable layout rows named '^panel-<num>' or '^panel-<row>-<col>'
    #' Returns a data.frame with panel_index, name, t, l, row, col
    find_panels_from_layout = function() {
      if (is.null(self$gt)) {
        return(data.frame())
      }
      layout <- self$gt$layout
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
    },

    # Deprecated: child id finder now handled in processors via panel_ctx (none retained here)

    #' Process the patchwork plot: build 2D subplots using gtable panels
    process = function() {
      # Discover panels and compute grid positions
      panel_df <- self$find_panels_from_layout()
      if (nrow(panel_df) == 0) {
        return(list(subplots = list()))
      }

      max_row <- max(panel_df$row)
      max_col <- max(panel_df$col)

      # Prepare grid structure
      grid <- vector("list", max_row)
      for (r in seq_len(max_row)) grid[[r]] <- vector("list", max_col)

      # Extract leaf plots in visual order
      leaves <- self$extract_leaf_plots(self$plot)

      # For each panel in row-major order, process layers using existing processors
      ordered <- panel_df[order(panel_df$row, panel_df$col), ]
      for (i in seq_len(nrow(ordered))) {
        panel_index <- ordered$panel_index[i]
        row <- ordered$row[i]
        col <- ordered$col[i]

        # Pick the matching leaf plot if available; else fall back to full plot
        leaf_plot <- if (i <= length(leaves)) leaves[[i]] else self$plot
        leaf_title <- if (!is.null(leaf_plot$labels$title)) leaf_plot$labels$title else ""
        panel_name <- ordered$name[i]

        # Create a simple subplot id
        subplot_id <- paste0("maidr-subplot-", as.integer(Sys.time()), "-", row, "-", col)

        layers <- list()
        for (layer_idx in seq_along(leaf_plot$layers)) {
          layer <- leaf_plot$layers[[layer_idx]]

          # Map geom to processor (reuse facet logic)
          geom_type <- class(layer$geom)[1]
          layer_info <- list(index = layer_idx, type = geom_type)
          processor <- switch(geom_type,
            "GeomBar" = BarLayerProcessor$new(layer_info),
            "GeomCol" = BarLayerProcessor$new(layer_info),
            "GeomPoint" = PointLayerProcessor$new(layer_info),
            "GeomLine" = LineLayerProcessor$new(layer_info),
            "GeomPath" = LineLayerProcessor$new(layer_info),
            NULL
          )

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
              self$layout,
              built = ggplot2::ggplot_build(leaf_plot),
              gt = self$gt,
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
                  switch(geom_type,
                    "GeomBar" = "bar",
                    "GeomCol" = "bar",
                    "GeomPoint" = "point",
                    "GeomLine" = "line",
                    "GeomPath" = "line",
                    "unknown"
                  )
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

        grid[[row]][[col]] <- list(
          id = subplot_id,
          layers = layers
        )
      }

      list(subplots = grid)
    }
  )
)
