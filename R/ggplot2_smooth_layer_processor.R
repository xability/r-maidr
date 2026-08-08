#' Smooth Layer Processor
#'
#' Processes smooth plot layers with complete logic included
#'
#' @keywords internal
Ggplot2SmoothLayerProcessor <- R6::R6Class(
  "Ggplot2SmoothLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      data <- self$extract_data(plot, built, panel_id = panel_id)
      selectors <- self$generate_selectors(plot, gt, panel_ctx = panel_ctx)

      list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout)
      )
    },
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      # Prefer this processor's OWN layer: picking the first line-like
      # layer would extract another layer's data in multi-layer plots
      # (e.g. geom_line + geom_smooth).
      layer_index <- self$get_layer_index()
      own_layer <- plot$layers[[layer_index]]
      is_smooth_like <- inherits(own_layer$geom, "GeomSmooth") ||
        inherits(own_layer$geom, "GeomLine") ||
        inherits(own_layer$geom, "GeomDensity") ||
        inherits(own_layer$geom, "GeomArea")

      if (is_smooth_like) {
        target_layer <- layer_index
      } else {
        smooth_layers <- which(sapply(plot$layers, function(layer) {
          inherits(layer$geom, "GeomSmooth") ||
            inherits(layer$geom, "GeomLine") ||
            inherits(layer$geom, "GeomDensity")
        }))

        if (length(smooth_layers) == 0) {
          stop("No smooth curve layers found in plot")
        }
        target_layer <- smooth_layers[1]
      }

      built_data <- built$data[[target_layer]]

      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, , drop = FALSE]
      }

      data_points <- lapply(seq_len(nrow(built_data)), function(i) {
        list(
          x = built_data$x[i],
          y = built_data$y[i]
        )
      })

      list(data_points)
    },
    # `GRID.polyline.N` is grid's auto-name for an unnamed grob: N is a
    # session-wide counter, not a per-plot index. Two renders of the same
    # plot in one session produced `GRID.polyline.1` then
    # `GRID.polyline.54`, and the gtable this processor inspects is the one
    # `create_enhanced_svg()` later draws, so the only way to learn N is to
    # read it off that gtable. Rebuilding one with `ggplotGrob()` does not
    # help - it allocates a fresh round of names that the exported SVG will
    # never carry.
    #
    # So when the lookup finds no polyline there is nothing to guess from,
    # and the id this used to fall back to - `GRID.polyline.1.1.1` - is not
    # a harmless miss. In a `facet_wrap(~g, drop = FALSE)` whose third
    # level is empty, panel 3's fabricated selector came out byte-identical
    # to panel 1's real one, so the empty panel highlighted panel 1's
    # fitted line. The one plot shape where that id IS this layer's line (a
    # lone `geom_smooth()` drawn as the session's first auto-named grob)
    # is a shape where the lookup SUCCEEDS, so it never reached the
    # fallback. Emit nothing instead: the caller can tell an empty selector
    # list apart from a wrong one, a user cannot.
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      collect_all_polyline_grobs <- function(grob) {
        polyline_grobs <- list()

        if (!is.null(grob$name) && grepl("GRID\\.polyline", grob$name)) {
          polyline_grobs <- append(polyline_grobs, grob$name)
        }

        if ("children" %in% names(grob)) {
          for (child in grob$children) {
            child_grobs <- collect_all_polyline_grobs(child)
            polyline_grobs <- append(polyline_grobs, child_grobs)
          }
        }

        polyline_grobs
      }

      all_polyline_grobs <- list()

      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        # Facet / patchwork path: scope the search to this panel's grob
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (!is.null(panel_grob)) {
          all_polyline_grobs <- collect_all_polyline_grobs(panel_grob)
        }
      } else if ("grobs" %in% names(gt)) {
        for (grob in gt$grobs) {
          grob_results <- collect_all_polyline_grobs(grob)
          all_polyline_grobs <- append(all_polyline_grobs, grob_results)
        }
      }

      if (length(all_polyline_grobs) == 0) {
        return(list())
      }

      numeric_ids <- sapply(all_polyline_grobs, function(grob_name) {
        match_result <- regmatches(grob_name, regexpr("GRID\\.polyline\\.(\\d+)", grob_name))
        if (length(match_result) > 0) {
          as.numeric(gsub("GRID\\.polyline\\.", "", match_result))
        } else {
          0
        }
      })

      numeric_ids <- numeric_ids[numeric_ids > 0]

      if (length(numeric_ids) > 0) {
        # Fitted line is the LAST polyline (confidence interval rendered first)
        # ggplot2 renders confidence interval first, then the fitted line
        target_id <- max(numeric_ids)
        grob_id <- paste0("GRID.polyline.", target_id, ".1.1")
      } else {
        # Fallback to first found grob
        grob_id <- paste0(all_polyline_grobs[[1]], ".1")
      }
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)

      list(paste0("#", escaped_grob_id))
    }
  )
)
