#' Violin Layer Processor
#'
#' Processes violin layers (geom_violin) to extract density curve (KDE) data
#' and box-summary statistics, producing two maidr layers: `violin_kde` and
#' `violin_box`.
#'
#' The processor injects a thin `geom_boxplot(width = 0.1)` into the plot
#' before rendering so that the SVG contains visible box elements whose
#' CSS selectors can drive the violin_box highlight in the maidr frontend.
#'
#' @keywords internal
Ggplot2ViolinLayerProcessor <- R6::R6Class(
  "Ggplot2ViolinLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    # ------------------------------------------------------------------
    # Plot augmentation
    # ------------------------------------------------------------------

    #' @description Violin needs to inject a boxplot layer
    needs_augmentation = function() {
      TRUE
    },

    #' @description Inject geom_boxplot into the plot for visual box + selectors
    #' @param plot ggplot2 object
    #' @return Augmented ggplot2 object with boxplot layer added
    augment_plot = function(plot) {
      # Only inject if the plot does not already contain a geom_boxplot
      has_boxplot <- any(vapply(plot$layers, function(l) {
        inherits(l$geom, "GeomBoxplot")
      }, logical(1)))

      if (!has_boxplot) {
        # The box has to group exactly like the violin. ggplot2 derives
        # `group` from the discrete aesthetics a layer carries, so a violin
        # dodged into 12 groups whose box only sees 7 pairs statistics and
        # selectors with the wrong violins.
        #
        # Two ways to lose that. Pinning `fill = "white"` over an
        # `aes(fill = ...)` drops fill from the box's grouping, so only set a
        # default the violin does not map. And `inherit.aes` carries the PLOT
        # mapping only, never another layer's own `aes()` -- so a violin that
        # maps fill on itself, `geom_violin(aes(fill = drv))`, leaves the box
        # with nothing to dodge by. Pass the merged mapping explicitly.
        mapping <- tryCatch(
          self$get_effective_mapping(plot),
          error = function(e) list()
        )
        mapped <- names(mapping)

        args <- list(
          width = 0.1,
          alpha = 0.9,
          outlier.shape = 16,
          outlier.size = 1.5,
          # The box is far narrower than the violin, so it only lands inside
          # its own violin if it dodges across the violin's width.
          position = ggplot2::position_dodge(width = 0.9)
        )
        if (length(mapped) > 0) {
          # Carry whatever class this ggplot2 gives an aes() object; the
          # merged list is otherwise just a list of quosures.
          args$mapping <- structure(mapping, class = class(ggplot2::aes()))
        }
        if (!"fill" %in% mapped) {
          args$fill <- "white"
        }
        if (!any(c("colour", "color") %in% mapped)) {
          args$colour <- "black"
        }

        plot <- plot + do.call(ggplot2::geom_boxplot, args)
      }
      plot
    },

    # ------------------------------------------------------------------
    # Main process
    # ------------------------------------------------------------------

    #' @description Process the violin layer
    #'
    #' Returns a list with `multi_layer = TRUE` and two maidr layers:
    #' violin_box (with BoxSelector objects) and violin_kde.
    #'
    #' @param plot The ggplot2 object (already augmented with boxplot)
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for faceted plots (optional)
    #' @return List with multi_layer flag and layers, or NULL for facet panels
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      # Faceted violins are still not supported interactively: the facet
      # combiner reads only `result$data` and `result$selectors` and emits
      # at most one layer per panel, so it cannot represent this
      # processor's multi-layer (violin_box + violin_kde) result. Skip
      # cleanly so the plot still renders visually instead of crashing.
      #
      # Patchwork leaves are supported. They arrive with a `panel_ctx` but
      # `panel_id = NULL` and no `facet_groups`; the third clause catches a
      # faceted leaf nested inside a patchwork, which is still a facet.
      if (
        !is.null(panel_id) ||
          length(panel_ctx$facet_groups) > 0 ||
          (!is.null(plot$facet) && !inherits(plot$facet, "FacetNull"))
      ) {
        return(NULL)
      }

      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      orientation <- self$determine_orientation(built)

      axes <- build_axes(
        x = extract_axis_label(layout$axes$x, default = "x"),
        y = extract_axis_label(layout$axes$y, default = "y")
      )

      # --- violin_box layer ---
      box_data <- self$extract_box_data(plot, built)
      box_selectors <- self$generate_box_selectors(plot, gt, built, panel_ctx)

      # gridSVG applies scale(1,-1) Y-flip for vertical plots, which
      # inverts 'top'/'bottom' edges of the IQ polygon.  Signal this via
      # domMapping.iqrDirection so the JS frontend (ViolinBoxTrace) can
      # swap Q1/Q3 edge selection - same pattern used by BoxTrace.
      iqr_direction <- if (orientation == "vert") "reverse" else "forward"

      box_layer <- list(
        data = box_data,
        selectors = box_selectors,
        axes = axes,
        orientation = orientation,
        type = "violin_box",
        violinOptions = list(
          showMedian = TRUE,
          showMean = FALSE,
          showExtrema = TRUE
        ),
        domMapping = list(iqrDirection = iqr_direction)
      )

      # --- violin_kde layer ---
      kde_data <- self$extract_kde_data(plot, built)
      kde_selectors <- self$generate_selectors(plot, gt, NULL, panel_ctx)

      # A composition can hand a leaf a panel that leaf does not draw into,
      # and announcing a violin the user cannot reach is worse than
      # announcing nothing. Both selector sets have to come up empty before
      # concluding that: either one finding grobs means this really is the
      # violin's panel, and the payload should then match what the same plot
      # produces standalone, warts included.
      if (
        !is.null(panel_ctx) &&
          length(kde_selectors) == 0 && length(box_selectors) == 0
      ) {
        return(NULL)
      }

      # Store panel_params ranges as metadata for SVG coordinate injection
      # These will be used by create_enhanced_svg() and stripped from final output
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      is_horizontal <- isTRUE(layer_data$flipped_aes[1])
      panel_params <- built$layout$panel_params[[1]]

      kde_layer <- list(
        data = kde_data,
        selectors = kde_selectors,
        axes = axes,
        orientation = orientation,
        type = "violin_kde",
        .panel_x_range = panel_params$x$continuous_range,
        .panel_y_range = panel_params$y$continuous_range,
        .is_horizontal = is_horizontal,
        # Which panel of the rendered composition these ranges belong to.
        # The injector walks subplots in grid order, which is not panel
        # discovery order, so it cannot recover this on its own.
        .panel_index = if (!is.null(panel_ctx)) panel_ctx$panel_index else NULL,
        .panel_name = if (!is.null(panel_ctx)) panel_ctx$panel_name else NULL
      )

      # Return multi-layer result; the orchestrator will expand this. Both
      # layers are turned round when the chart is horizontal, for the reason
      # `reverse_horizontal_box_layer()` documents (#187): `ViolinBoxTrace`
      # and `ViolinTrace` each reverse one unconditionally.
      list(
        multi_layer = TRUE,
        layers = list(
          reverse_horizontal_box_layer(box_layer),
          reverse_horizontal_box_layer(kde_layer)
        )
      )
    },

    # ------------------------------------------------------------------
    # Data extraction
    # ------------------------------------------------------------------

    #' @description Extract box-summary statistics per violin group
    #'
    #' Computes min, Q1, median, Q3, max from the original data (since
    #' geom_violin only stores the KDE curve, not quartiles).
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @return List of BoxPoint objects (one per violin)
    extract_box_data = function(plot, built) {
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      is_horizontal <- isTRUE(layer_data$flipped_aes[1])

      # Get original data and mapping to compute real quartiles
      groups <- unique(layer_data$group)
      val_col <- if (is_horizontal) "x" else "y"
      labels <- self$group_labels(built, layer_data, groups, is_horizontal)

      # ggplot2's own stat_boxplot output, keyed by the same group ids the
      # violin layer uses. The columns are named for the value axis, which
      # flips with the plot.
      stats_data <- self$boxplot_stats(plot, built)
      if (is.null(stats_data)) {
        # Caller handed us a plot that was never augmented. Build the boxplot
        # ourselves rather than approximating: the KDE grid is the density's
        # support, so quantiles of it describe the sampling grid, not the data.
        stats_data <- tryCatch(
          {
            augmented <- self$augment_plot(plot)
            self$boxplot_stats(augmented, ggplot2::ggplot_build(augmented))
          },
          error = function(e) NULL
        )
      }
      stat_cols <- if (is_horizontal) {
        c(min = "xmin", q1 = "xlower", q2 = "xmiddle", q3 = "xupper", max = "xmax")
      } else {
        c(min = "ymin", q1 = "lower", q2 = "middle", q3 = "upper", max = "ymax")
      }
      has_stats <- !is.null(stats_data) &&
        all(stat_cols %in% names(stats_data))

      box_data <- vector("list", length(groups))

      for (i in seq_along(groups)) {
        g <- groups[i]
        summary <- if (has_stats) {
          row <- stats_data[stats_data$group == g, , drop = FALSE]
          if (nrow(row) > 0) {
            outliers <- if ("outliers" %in% names(row)) {
              as.numeric(unlist(row$outliers[1]))
            } else {
              numeric(0)
            }
            outliers <- outliers[!is.na(outliers)]
            lo <- row[[stat_cols[["min"]]]][1]
            hi <- row[[stat_cols[["max"]]]][1]
            list(
              min = lo,
              q1 = row[[stat_cols[["q1"]]]][1],
              q2 = row[[stat_cols[["q2"]]]][1],
              q3 = row[[stat_cols[["q3"]]]][1],
              max = hi,
              lower_outliers = sort(outliers[outliers < lo]),
              upper_outliers = sort(outliers[outliers > hi])
            )
          } else {
            NULL
          }
        } else {
          NULL
        }

        if (is.null(summary)) {
          # Nothing authoritative for this group. Report the violin's own
          # drawn extent and leave the quartiles at its midpoint rather than
          # inventing numbers that look like quartiles but are not.
          rows <- layer_data[layer_data$group == g, ]
          vals <- suppressWarnings(as.numeric(rows[[val_col]]))
          vals <- vals[!is.na(vals)]
          if (length(vals) == 0) {
            vals <- 0
          }
          mid <- stats::median(vals)
          summary <- list(
            min = min(vals), q1 = mid, q2 = mid, q3 = mid, max = max(vals),
            lower_outliers = numeric(0), upper_outliers = numeric(0)
          )
        }

        box_data[[i]] <- list(
          z = labels[i],
          lowerOutliers = as.list(unname(summary$lower_outliers)),
          min = unname(summary$min),
          q1 = unname(summary$q1),
          q2 = unname(summary$q2),
          q3 = unname(summary$q3),
          max = unname(summary$max),
          upperOutliers = as.list(unname(summary$upper_outliers))
        )
      }

      box_data
    },

    #' @description Extract KDE density-curve data per violin group
    #'
    #' Uses ggplot2's built violin data (violinwidth, x, y, width columns)
    #' to compute left/right violin edges, applies RDP simplification to
    #' ~30 points per violin, and includes the `width` field needed by the
    #' maidr frontend.  The `svg_x`/`svg_y` coordinates are injected later
    #' by `create_enhanced_svg()` after the grid device is drawn.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @param max_kde_points Maximum number of output points per violin (default 30)
    #' @return List of lists (ViolinKdePoint[][])
    extract_kde_data = function(plot, built, max_kde_points = 30L) {
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      is_horizontal <- isTRUE(layer_data$flipped_aes[1])

      groups <- unique(layer_data$group)
      # Same labelling as the box layer: the two describe the same violins and
      # must announce them under the same names.
      labels <- self$group_labels(built, layer_data, groups, is_horizontal)

      kde_data <- vector("list", length(groups))

      for (i in seq_along(groups)) {
        g <- groups[i]
        rows <- layer_data[layer_data$group == g, ]

        kde_data[[i]] <- self$simplify_violin_kde(
          rows, labels[i], is_horizontal, max_kde_points
        )
      }

      kde_data
    },

    #' @description Simplify a single violin's KDE curve using RDP
    #'
    #' Uses ggplot2's built violin data columns (y, violinwidth, x, width)
    #' to compute the left/right edges, then applies RDP simplification.
    #'
    #' @param rows data.frame of built violin data for one group
    #' @param cat_label Character label for this violin category
    #' @param is_horizontal Logical, TRUE for horizontal violins
    #' @param max_points Maximum number of output points
    #' @return List of ViolinKdePoint dicts with data_left_x/data_right_x/data_y
    simplify_violin_kde = function(rows, cat_label, is_horizontal,
                                   max_points = 30L) {
      val_col <- if (is_horizontal) "x" else "y"
      cat_col <- if (is_horizontal) "y" else "x"

      y_vals <- rows[[val_col]]        # value axis (the KDE evaluation points)
      vw <- rows$violinwidth            # normalized density (0-1 within group)
      cat_pos <- rows[[cat_col]][1]     # category position (e.g. 1, 2, 3)
      envelope_w <- rows$width[1]       # constant envelope width

      # Compute actual left/right edges in data coordinates
      # ggplot2 draws: right = cat_pos + envelope_w * violinwidth / 2
      #                left  = cat_pos - envelope_w * violinwidth / 2
      half_widths <- envelope_w * vw / 2
      left_x <- cat_pos - half_widths
      right_x <- cat_pos + half_widths
      widths_data <- envelope_w * vw   # full width at each y

      # Preserve extrema (violin tips) even if violinwidth = 0, then filter
      y_min_idx <- which.min(y_vals)
      y_max_idx <- which.max(y_vals)
      valid <- !is.na(y_vals) & !is.na(vw) & vw > 0
      valid[y_min_idx] <- TRUE
      valid[y_max_idx] <- TRUE
      y_vals <- y_vals[valid]
      left_x <- left_x[valid]
      right_x <- right_x[valid]
      widths_data <- widths_data[valid]
      # Widen the zero-width tips of an otherwise normal violin, scaling the
      # nudge from the narrowest real width so it stays proportionate.
      #
      # `geom_violin(width = 0)` has no real width to scale from: every width
      # is zero, so this vector is empty, min() returns Inf with a warning and
      # the comparison below is NA, which aborts the render. Skip widening
      # entirely in that case -- a violin with no envelope has nothing to
      # widen, and the extrema kept above are exactly what ggplot2 draws.
      positive_widths <- widths_data[widths_data > 0]
      if (any(widths_data <= 0) && length(positive_widths) > 0) {
        min_w <- min(positive_widths, na.rm = TRUE)
        widths_data[widths_data <= 0] <- min_w * 0.01
        # Also adjust left/right edges for the tip points
        tiny_hw <- min_w * 0.01 / 2
        left_x[widths_data <= min_w * 0.01 + 1e-12] <-
          cat_pos - tiny_hw
        right_x[widths_data <= min_w * 0.01 + 1e-12] <-
          cat_pos + tiny_hw
      }

      if (length(y_vals) < 2) {
        return(list(list(x = cat_label, y = y_vals[1])))
      }

      # Each Y-level produces 2 output points, so target Y-levels = max/2
      target_levels <- max(max_points %/% 2L, 3L)

      if (length(y_vals) > target_levels) {
        # Build (y, width) shape curve and apply RDP
        shape_curve <- cbind(y_vals, widths_data)
        mask <- simplify_curve(shape_curve, target = target_levels)
        indices <- which(mask)
      } else {
        indices <- seq_along(y_vals)
      }

      # Build output points for retained Y-levels (left + right)
      # Store data_left_x/data_right_x/data_y for SVG coordinate injection later
      points <- vector("list", length(indices) * 2L)
      k <- 0L
      for (j in indices) {
        base <- list(
          x = cat_label,
          y = y_vals[j],
          width = widths_data[j]
        )
        k <- k + 1L
        # Left point
        points[[k]] <- c(base, list(
          data_left_x = left_x[j],
          data_right_x = right_x[j],
          data_y = y_vals[j]
        ))
        k <- k + 1L
        # Right point (same y/width but different svg_x later)
        points[[k]] <- c(base, list(
          data_left_x = left_x[j],
          data_right_x = right_x[j],
          data_y = y_vals[j]
        ))
      }

      points
    },

    #' @description Not used directly - required by base class interface
    extract_data = function(plot, built = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      self$extract_kde_data(plot, built)
    },

    # ------------------------------------------------------------------
    # Selectors
    # ------------------------------------------------------------------

    #' @description Generate CSS selectors for violin polygons (for violin_kde layer)
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param grob_id Grob ID (for faceted plots)
    #' @param panel_ctx Panel context (for faceted plots)
    #' @return List of CSS selector strings (one per violin)
    generate_selectors = function(plot, gt = NULL, grob_id = NULL,
                                  panel_ctx = NULL) {
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      panel_grob <- self$find_panel_grob(gt, panel_ctx)
      if (is.null(panel_grob)) {
        return(list())
      }

      # Find the master geom_violin gTree
      violin_ids <- self$find_grob_ids(panel_grob, "geom_violin\\.gTree")
      if (length(violin_ids) == 0) {
        return(list())
      }
      master_id <- violin_ids[1]

      # Find per-violin polygon children
      polygon_ids <- self$find_direct_children(
        panel_grob, master_id, "geom_violin\\.polygon"
      )

      if (length(polygon_ids) == 0) {
        polygon_ids <- self$find_grob_ids(
          panel_grob, "geom_violin\\.polygon"
        )
      }

      esc <- function(id) gsub("\\.", "\\\\.", id)

      selectors <- lapply(polygon_ids, function(pid) {
        sid <- if (!grepl("\\.\\d+\\.\\d+$", pid)) paste0(pid, ".1") else pid
        paste0("g#", esc(sid), " > polygon")
      })

      selectors
    },

    #' @description Generate BoxSelector objects for the injected boxplot grobs
    #'
    #' Walks the gtable to find geom_boxplot grobs and produces a
    #' BoxSelector list (one per violin) with CSS selectors for min,
    #' iq, q2, max, lowerOutliers, upperOutliers.
    #'
    #' @param plot The ggplot2 object (augmented with boxplot)
    #' @param gt Gtable object
    #' @param built Built plot data
    #' @param panel_ctx Panel context (for patchwork leaves)
    #' @return List of BoxSelector objects
    generate_box_selectors = function(plot, gt, built, panel_ctx = NULL) {
      panel_grob <- self$find_panel_grob(gt, panel_ctx)
      if (is.null(panel_grob)) {
        return(list())
      }

      # Find the injected boxplot grobs
      all_box <- self$find_grob_ids(panel_grob, "geom_boxplot\\.gTree")
      if (length(all_box) == 0) {
        return(list())
      }

      master_id <- all_box[1]
      per_box_ids <- self$find_direct_children(
        panel_grob, master_id, "geom_boxplot\\.gTree"
      )
      if (length(per_box_ids) == 0) {
        per_box_ids <- setdiff(all_box, master_id)
      }
      if (length(per_box_ids) == 0) {
        return(list())
      }

      # Find the boxplot layer index in the built data
      box_layer_idx <- self$find_boxplot_layer_index(plot)

      # Get boxplot built data for outlier counts
      box_layer_data <- NULL
      is_horizontal <- FALSE
      if (!is.null(box_layer_idx) && box_layer_idx <= length(built$data)) {
        box_layer_data <- built$data[[box_layer_idx]]
        is_horizontal <- isTRUE(box_layer_data$flipped_aes[1])
      }

      esc <- function(id) gsub("\\.", "\\\\.", id)
      with_suffix <- function(id) {
        if (is.null(id)) return(NULL)
        if (grepl("\\.\\d+\\.\\d+$", id)) return(id)
        paste0(id, ".1")
      }

      selectors <- vector("list", length(per_box_ids))
      for (i in seq_along(per_box_ids)) {
        box_id <- per_box_ids[i]
        box_sel <- list()

        # Outliers
        outlier_container <- self$find_desc_by_pattern(
          panel_grob, box_id, "geom_point\\.points"
        )
        lower_n <- 0
        upper_n <- 0
        if (!is.null(box_layer_data) && nrow(box_layer_data) >= i) {
          row <- box_layer_data[i, ]
          outliers_str <- as.character(row$outliers)
          if (!is.na(outliers_str) && outliers_str != "" &&
                outliers_str != "NA" &&
                outliers_str != " numeric(0) ") {
            txt <- gsub("^c\\(|\\)$", "", outliers_str)
            if (nzchar(txt)) {
              vals <- suppressWarnings(
                as.numeric(strsplit(txt, ", ")[[1]])
              )
              vals <- vals[!is.na(vals)]
              if (length(vals) > 0) {
                if (is_horizontal) {
                  lower_n <- sum(vals < row$xmin)
                  upper_n <- sum(vals > row$xmax)
                } else {
                  lower_n <- sum(vals < row$ymin)
                  upper_n <- sum(vals > row$ymax)
                }
              }
            }
          }
        }

        if (!is.null(outlier_container) && lower_n > 0) {
          oc <- with_suffix(outlier_container)
          box_sel$lowerOutliers <- list(
            paste0("g#", esc(oc), " > use:nth-child(-n+", lower_n, ")")
          )
        } else {
          box_sel$lowerOutliers <- list()
        }
        if (!is.null(outlier_container) && upper_n > 0) {
          oc <- with_suffix(outlier_container)
          box_sel$upperOutliers <- list(
            paste0(
              "g#", esc(oc),
              " > use:nth-child(n+", lower_n + 1, ")"
            )
          )
        } else {
          box_sel$upperOutliers <- list()
        }

        # IQR box and median inside crossbar
        crossbar_id <- self$find_desc_by_pattern(
          panel_grob, box_id, "geom_crossbar\\.gTree"
        )
        iq_id <- if (!is.null(crossbar_id)) {
          self$find_desc_by_pattern(
            panel_grob, crossbar_id, "geom_polygon\\.polygon"
          )
        }
        med_id <- if (!is.null(crossbar_id)) {
          self$find_desc_by_pattern(
            panel_grob, crossbar_id, "GRID\\.segments"
          )
        }

        if (!is.null(iq_id)) {
          box_sel$iq <- paste0(
            "g#", esc(with_suffix(iq_id)), " > polygon"
          )
        } else {
          box_sel$iq <- ""
        }
        if (!is.null(med_id)) {
          box_sel$q2 <- paste0(
            "g#", esc(with_suffix(med_id)), " > polyline"
          )
        } else {
          box_sel$q2 <- ""
        }

        # Whiskers
        whisker_id <- self$find_desc_by_pattern(
          panel_grob, box_id, "GRID\\.segments"
        )
        if (!is.null(whisker_id) && !is.null(med_id) &&
              whisker_id == med_id) {
          direct_segs <- self$find_direct_children(
            panel_grob,
            self$find_grob_by_id(panel_grob, box_id)$name,
            "GRID\\.segments"
          )
          # find_direct_children returns character IDs, try finding
          # a different one from the crossbar's median
          all_segs <- self$find_all_desc_by_pattern(
            panel_grob, box_id, "GRID\\.segments"
          )
          alt <- setdiff(all_segs, med_id)
          if (length(alt) > 0) {
            whisker_id <- alt[1]
          }
        }

        if (!is.null(whisker_id)) {
          wid <- with_suffix(whisker_id)
          # ggplot2 draws the upper whisker (Q3->ymax) first and the lower
          # whisker (Q1->ymin) second, so in gridSVG DOM:
          #   nth-child(1) = upper whisker -> max
          #   nth-child(2) = lower whisker -> min
          box_sel$max <- paste0(
            "g#", esc(wid), " > polyline:nth-child(1)"
          )
          box_sel$min <- paste0(
            "g#", esc(wid), " > polyline:nth-child(2)"
          )
        } else {
          box_sel$min <- ""
          box_sel$max <- ""
        }

        selectors[[i]] <- box_sel
      }

      selectors
    },

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    #' @description Determine orientation from built data
    determine_orientation = function(built) {
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      if ("flipped_aes" %in% names(layer_data) &&
            isTRUE(layer_data$flipped_aes[1])) {
        return("horz")
      }
      "vert"
    },

    #' @description The violin layer's mapping merged with the plot's
    #'
    #' Built in ggplot2's own order -- the layer's own aesthetics first, then
    #' whatever only the plot maps -- because the order is not cosmetic.
    #' ggplot2 numbers `group` from the interaction of a layer's discrete
    #' columns taken in the order the mapping produced them, so a mapping
    #' assembled the other way round gives the injected box different group
    #' ids than the violin, and every lookup keyed on `group` then crosses
    #' the two layers.
    #'
    #' @param plot The ggplot2 object
    #' @return Named list of quosures, one per mapped aesthetic
    get_effective_mapping = function(plot) {
      layer_index <- self$get_layer_index()
      layer_mapping <- plot$layers[[layer_index]]$mapping
      plot_mapping <- plot$mapping
      layer_mapping <- if (is.null(layer_mapping)) {
        list()
      } else {
        as.list(layer_mapping)
      }
      plot_mapping <- if (is.null(plot_mapping)) {
        list()
      } else {
        as.list(plot_mapping)
      }
      c(
        layer_mapping,
        plot_mapping[setdiff(names(plot_mapping), names(layer_mapping))]
      )
    },

    #' @description Break labels of whichever panel axis holds the categories
    #'
    #' The categorical axis is the discrete one, which is not always the axis
    #' the data is keyed on: `coord_flip()` leaves the data x-major while
    #' moving the category labels to the y axis, so reading the axis off
    #' `flipped_aes` alone returns the value axis' breaks and every violin is
    #' labelled with a number.
    #'
    #' @param built Built plot data
    #' @return Character vector of labels, or NULL when neither axis is
    #'   discrete (a continuous category axis carries its value directly)
    discrete_axis_labels = function(built) {
      panel_params <- built$layout$panel_params[[1]]
      for (axis_name in c("x", "y")) {
        pp_axis <- panel_params[[axis_name]]
        if (is.null(pp_axis)) {
          next
        }
        is_discrete <- tryCatch(
          isTRUE(pp_axis$is_discrete()),
          error = function(e) FALSE
        )
        if (!is_discrete) {
          next
        }
        labels <- tryCatch(pp_axis$get_labels(), error = function(e) NULL)
        if (is.null(labels) || length(labels) == 0) {
          labels <- pp_axis$labels
        }
        if (!is.null(labels) && length(labels) > 0) {
          return(as.character(labels))
        }
      }
      NULL
    },

    #' @description Map each mapped fill colour back to the level it came from
    #'
    #' Dodging splits one category into several violins that differ only by
    #' fill, and they all round to the same category position. Without the
    #' level, they are announced under one repeated name and cannot be told
    #' apart.
    #'
    #' @param built Built plot data
    #' @return Named character vector (colour -> level), or NULL when the plot
    #'   has no fill scale
    fill_levels_by_colour = function(built) {
      scale <- tryCatch(
        built$plot$scales$get_scales("fill"),
        error = function(e) NULL
      )
      if (is.null(scale)) {
        return(NULL)
      }
      levels <- tryCatch(scale$get_limits(), error = function(e) NULL)
      if (is.null(levels) || length(levels) == 0) {
        return(NULL)
      }
      colours <- tryCatch(scale$map(levels), error = function(e) NULL)
      if (is.null(colours) || length(colours) != length(levels)) {
        return(NULL)
      }
      stats::setNames(as.character(levels), as.character(colours))
    },

    #' @description Announceable label for each drawn violin
    #'
    #' @param built Built plot data
    #' @param layer_data Built data for the violin layer
    #' @param groups The layer's group ids, in emission order
    #' @param is_horizontal Whether the value axis is x
    #' @return Character vector of labels, one per group
    group_labels = function(built, layer_data, groups, is_horizontal) {
      category_labels <- self$discrete_axis_labels(built)
      fill_levels <- self$fill_levels_by_colour(built)
      cat_col <- if (is_horizontal) "y" else "x"

      vapply(groups, function(g) {
        rows <- layer_data[layer_data$group == g, ]
        position <- rows[[cat_col]][1]

        label <- if (!is.null(category_labels)) {
          idx <- suppressWarnings(as.integer(round(position)))
          if (!is.na(idx) && idx >= 1 && idx <= length(category_labels)) {
            as.character(category_labels[idx])
          } else {
            as.character(position)
          }
        } else {
          # Continuous category axis: the position IS the value, so indexing
          # break labels with it would read off an unrelated tick.
          format(position, trim = TRUE)
        }

        # Only qualify when dodging actually put more than one level on the
        # axis, so an undodged violin keeps its plain category name.
        if (!is.null(fill_levels) && length(fill_levels) > 1) {
          colour <- as.character(rows$fill[1])
          if (!is.na(colour) && colour %in% names(fill_levels)) {
            label <- paste0(label, " - ", fill_levels[[colour]])
          }
        }
        label
      }, character(1), USE.NAMES = FALSE)
    },

    #' @description Box statistics ggplot2 itself computed for each group
    #'
    #' The processor injects a `geom_boxplot()` so the SVG has box elements to
    #' highlight; that layer's `stat_boxplot` output is also the authoritative
    #' source for the numbers to announce. Reading it keyed by `group` avoids
    #' re-deriving quartiles from the original data via a rounded axis
    #' position and a string match on the break label -- a round trip that
    #' silently mislabels dodged violins and finds nothing at all under
    #' `coord_flip()`.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @return data.frame of the boxplot layer's built data, or NULL
    boxplot_stats = function(plot, built) {
      idx <- self$find_boxplot_layer_index(plot)
      if (is.null(idx) || idx > length(built$data)) {
        return(NULL)
      }
      stats <- built$data[[idx]]
      if (!is.data.frame(stats) || nrow(stats) == 0) {
        return(NULL)
      }
      if (!"group" %in% names(stats)) {
        return(NULL)
      }
      stats
    },

    #' @description Find the boxplot layer index in the augmented plot
    #' @param plot The ggplot2 object
    #' @return Integer index of the boxplot layer, or NULL
    find_boxplot_layer_index = function(plot) {
      for (i in seq_along(plot$layers)) {
        if (inherits(plot$layers[[i]]$geom, "GeomBoxplot")) {
          return(i)
        }
      }
      NULL
    },

    #' @description Find the panel grob this layer draws into
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for patchwork leaves; NULL for a
    #'   single plot, where the panel is the cell literally named "panel"
    #' @return The panel gTree, or NULL when it cannot be resolved
    find_panel_grob = function(gt, panel_ctx = NULL) {
      find_gtable_panel_grob(gt, panel_ctx)
    },

    #' @description Recursively find all grob IDs matching a pattern
    #' @param grob Grob tree to search
    #' @param pattern Regular expression matched against grob names
    #' @return Character vector of unique matching grob names
    find_grob_ids = function(grob, pattern) {
      ids <- character(0)
      if (!inherits(grob, "gTree") || is.null(grob$children)) {
        return(ids)
      }
      for (nm in names(grob$children)) {
        child <- grob$children[[nm]]
        if (!is.null(child$name) && grepl(pattern, child$name)) {
          ids <- c(ids, child$name)
        }
        if (inherits(child, "gTree")) {
          ids <- c(ids, self$find_grob_ids(child, pattern))
        }
      }
      unique(ids)
    },

    #' @description Find direct children of a named parent matching a pattern
    #' @param grob Grob tree to search
    #' @param parent_id Name of the parent grob
    #' @param pattern Regular expression matched against child names
    #' @return Character vector of matching child names
    find_direct_children = function(grob, parent_id, pattern) {
      parent <- self$find_grob_by_id(grob, parent_id)
      if (is.null(parent) || !inherits(parent, "gTree")) {
        return(character(0))
      }
      ids <- character(0)
      for (nm in names(parent$children)) {
        child <- parent$children[[nm]]
        if (!is.null(child$name) && grepl(pattern, child$name)) {
          ids <- c(ids, child$name)
        }
      }
      ids
    },

    #' @description Find a grob by its name (recursive)
    #' @param grob Grob tree to search
    #' @param target_id Name of the grob to find
    #' @return The matching grob, or NULL
    find_grob_by_id = function(grob, target_id) {
      if (!is.null(grob$name) && grob$name == target_id) {
        return(grob)
      }
      if (inherits(grob, "gTree") && !is.null(grob$children)) {
        for (nm in names(grob$children)) {
          found <- self$find_grob_by_id(grob$children[[nm]], target_id)
          if (!is.null(found)) return(found)
        }
      }
      NULL
    },

    #' @description Find the first descendant matching a pattern under a named parent
    #' @param grob Grob tree to search
    #' @param parent_id Name of the parent grob
    #' @param pattern Regular expression matched against descendant names
    #' @return The first matching name, or NULL
    find_desc_by_pattern = function(grob, parent_id, pattern) {
      parent <- self$find_grob_by_id(grob, parent_id)
      if (is.null(parent)) return(NULL)
      ids <- self$find_grob_ids(parent, pattern)
      if (length(ids) > 0) ids[1] else NULL
    },

    #' @description Find all descendants matching a pattern under a named parent
    #' @param grob Grob tree to search
    #' @param parent_id Name of the parent grob
    #' @param pattern Regular expression matched against descendant names
    #' @return Character vector of matching descendant names
    find_all_desc_by_pattern = function(grob, parent_id, pattern) {
      parent <- self$find_grob_by_id(grob, parent_id)
      if (is.null(parent)) return(character(0))
      self$find_grob_ids(parent, pattern)
    }
  )
)
