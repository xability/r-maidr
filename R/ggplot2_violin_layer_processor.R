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
        plot <- plot + ggplot2::geom_boxplot(
          width = 0.1,
          fill = "white",
          color = "black",
          alpha = 0.9,
          outlier.shape = 16,
          outlier.size = 1.5
        )
      }
      plot
    },

    # ------------------------------------------------------------------
    # Main process
    # ------------------------------------------------------------------

    #' Process the violin layer
    #'
    #' Returns a list with `multi_layer = TRUE` and two maidr layers:
    #' violin_box (with BoxSelector objects) and violin_kde.
    #'
    #' @param plot The ggplot2 object (already augmented with boxplot)
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @return List with multi_layer flag and layers
    process = function(plot, layout, built = NULL, gt = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      orientation <- self$determine_orientation(built)

      axes <- list(
        x = if (!is.null(layout$axes$x)) layout$axes$x else "x",
        y = if (!is.null(layout$axes$y)) layout$axes$y else "y"
      )

      # --- violin_box layer ---
      box_data <- self$extract_box_data(plot, built)
      box_selectors <- self$generate_box_selectors(plot, gt, built)

      # gridSVG applies scale(1,-1) Y-flip for vertical plots, which
      # inverts 'top'/'bottom' edges of the IQ polygon.  Signal this via
      # domMapping.iqrDirection so the JS frontend (ViolinBoxTrace) can
      # swap Q1/Q3 edge selection — same pattern used by BoxTrace.
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
      kde_selectors <- self$generate_selectors(plot, gt)

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
        .is_horizontal = is_horizontal
      )

      # Return multi-layer result; the orchestrator will expand this
      list(
        multi_layer = TRUE,
        layers = list(box_layer, kde_layer)
      )
    },

    # ------------------------------------------------------------------
    # Data extraction
    # ------------------------------------------------------------------

    #' Extract box-summary statistics per violin group
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
      original_data <- self$get_original_data(plot)
      mapping <- self$get_effective_mapping(plot)

      # Resolve the grouping (x) and value (y) variables
      x_var <- tryCatch(rlang::as_label(mapping$x), error = function(e) NULL)
      y_var <- tryCatch(rlang::as_label(mapping$y), error = function(e) NULL)

      if (is_horizontal) {
        cat_var <- y_var
        val_var <- x_var
      } else {
        cat_var <- x_var
        val_var <- y_var
      }

      # Map numeric positions to category labels
      panel_params <- built$layout$panel_params[[1]]
      category_labels <- self$get_category_labels(
        panel_params, is_horizontal
      )

      groups <- unique(layer_data$group)
      cat_col <- if (is_horizontal) "y" else "x"
      val_col <- if (is_horizontal) "x" else "y"
      group_cat_positions <- vapply(groups, function(g) {
        rows <- layer_data[layer_data$group == g, ]
        rows[[cat_col]][1]
      }, numeric(1))

      box_data <- vector("list", length(groups))

      for (i in seq_along(groups)) {
        g <- groups[i]
        cat_pos <- group_cat_positions[i]

        idx <- suppressWarnings(as.integer(round(cat_pos)))
        fill_label <- if (!is.na(idx) && idx >= 1 &&
              idx <= length(category_labels)) {
          as.character(category_labels[idx])
        } else {
          as.character(cat_pos)
        }

        # Get values for this group from original data
        if (!is.null(cat_var) && !is.null(val_var) &&
              cat_var %in% names(original_data) &&
              val_var %in% names(original_data)) {
          group_vals <- original_data[
            as.character(original_data[[cat_var]]) == fill_label,
            val_var
          ]
          group_vals <- as.numeric(group_vals)
          group_vals <- group_vals[!is.na(group_vals)]
        } else {
          rows <- layer_data[layer_data$group == g, ]
          group_vals <- rows[[val_col]]
        }

        if (length(group_vals) == 0) {
          group_vals <- 0
        }

        qs <- stats::quantile(group_vals, probs = c(0, 0.25, 0.5, 0.75, 1))

        # Compute IQR-based whiskers (Tukey fences)
        iqr <- qs[[4]] - qs[[2]]
        lower_fence <- qs[[2]] - 1.5 * iqr
        upper_fence <- qs[[4]] + 1.5 * iqr
        whisker_min <- min(group_vals[group_vals >= lower_fence])
        whisker_max <- max(group_vals[group_vals <= upper_fence])

        lower_outliers <- as.list(sort(group_vals[group_vals < lower_fence]))
        upper_outliers <- as.list(sort(group_vals[group_vals > upper_fence]))

        box_data[[i]] <- list(
          fill = fill_label,
          lowerOutliers = lower_outliers,
          min = unname(whisker_min),
          q1 = unname(qs[[2]]),
          q2 = unname(qs[[3]]),
          q3 = unname(qs[[4]]),
          max = unname(whisker_max),
          upperOutliers = upper_outliers
        )
      }

      box_data
    },

    #' Extract KDE density-curve data per violin group
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

      panel_params <- built$layout$panel_params[[1]]
      category_labels <- self$get_category_labels(
        panel_params, is_horizontal
      )

      cat_col <- if (is_horizontal) "y" else "x"
      val_col <- if (is_horizontal) "x" else "y"

      groups <- unique(layer_data$group)
      group_cat_positions <- vapply(groups, function(g) {
        rows <- layer_data[layer_data$group == g, ]
        rows[[cat_col]][1]
      }, numeric(1))

      kde_data <- vector("list", length(groups))

      for (i in seq_along(groups)) {
        g <- groups[i]
        rows <- layer_data[layer_data$group == g, ]
        cat_pos <- group_cat_positions[i]

        idx <- suppressWarnings(as.integer(round(cat_pos)))
        cat_label <- if (!is.na(idx) && idx >= 1 &&
              idx <= length(category_labels)) {
          as.character(category_labels[idx])
        } else {
          as.character(cat_pos)
        }

        kde_data[[i]] <- self$simplify_violin_kde(
          rows, cat_label, is_horizontal, max_kde_points
        )
      }

      kde_data
    },

    #' Simplify a single violin's KDE curve using RDP
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
      # Give zero-width tips a tiny positive width so they survive
      if (any(widths_data <= 0)) {
        min_w <- min(widths_data[widths_data > 0], na.rm = TRUE)
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

    #' Not used directly - required by base class interface
    extract_data = function(plot, built = NULL, scale_mapping = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      self$extract_kde_data(plot, built)
    },

    # ------------------------------------------------------------------
    # Selectors
    # ------------------------------------------------------------------

    #' Generate CSS selectors for violin polygons (for violin_kde layer)
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

      panel_grob <- self$find_panel_grob(gt)
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

    #' Generate BoxSelector objects for the injected boxplot grobs
    #'
    #' Walks the gtable to find geom_boxplot grobs and produces a
    #' BoxSelector list (one per violin) with CSS selectors for min,
    #' iq, q2, max, lowerOutliers, upperOutliers.
    #'
    #' @param plot The ggplot2 object (augmented with boxplot)
    #' @param gt Gtable object
    #' @param built Built plot data
    #' @return List of BoxSelector objects
    generate_box_selectors = function(plot, gt, built) {
      panel_grob <- self$find_panel_grob(gt)
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
          # ggplot2 draws the upper whisker (Q3→ymax) first and the lower
          # whisker (Q1→ymin) second, so in gridSVG DOM:
          #   nth-child(1) = upper whisker → max
          #   nth-child(2) = lower whisker → min
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

    #' Determine orientation from built data
    determine_orientation = function(built) {
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      if ("flipped_aes" %in% names(layer_data) &&
            isTRUE(layer_data$flipped_aes[1])) {
        return("horz")
      }
      "vert"
    },

    #' Get the effective mapping (layer mapping merged with plot mapping)
    get_effective_mapping = function(plot) {
      layer_index <- self$get_layer_index()
      layer_mapping <- plot$layers[[layer_index]]$mapping
      plot_mapping <- plot$mapping
      modifyList(
        if (is.null(plot_mapping)) list() else as.list(plot_mapping),
        if (is.null(layer_mapping)) list() else as.list(layer_mapping)
      )
    },

    #' Get original data used by this layer
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

    #' Get category labels from panel params
    get_category_labels = function(panel_params, is_horizontal) {
      pp_axis <- if (is_horizontal) panel_params$y else panel_params$x
      if (!is.null(pp_axis$labels) && length(pp_axis$labels) > 0) {
        return(as.character(pp_axis$labels))
      }
      if (!is.null(pp_axis$breaks) && length(pp_axis$breaks) > 0) {
        return(as.character(pp_axis$breaks))
      }
      character(0)
    },

    #' Find the boxplot layer index in the augmented plot
    find_boxplot_layer_index = function(plot) {
      for (i in seq_along(plot$layers)) {
        if (inherits(plot$layers[[i]]$geom, "GeomBoxplot")) {
          return(i)
        }
      }
      NULL
    },

    #' Find the main panel grob
    find_panel_grob = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) return(NULL)
      panel_grob <- gt$grobs[[panel_index]]
      if (!inherits(panel_grob, "gTree")) return(NULL)
      panel_grob
    },

    #' Recursively find all grob IDs matching a pattern
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

    #' Find direct children of a named parent matching a pattern
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

    #' Find a grob by its name (recursive)
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

    #' Find the first descendant matching a pattern under a named parent
    find_desc_by_pattern = function(grob, parent_id, pattern) {
      parent <- self$find_grob_by_id(grob, parent_id)
      if (is.null(parent)) return(NULL)
      ids <- self$find_grob_ids(parent, pattern)
      if (length(ids) > 0) ids[1] else NULL
    },

    #' Find all descendants matching a pattern under a named parent
    find_all_desc_by_pattern = function(grob, parent_id, pattern) {
      parent <- self$find_grob_by_id(grob, parent_id)
      if (is.null(parent)) return(character(0))
      self$find_grob_ids(parent, pattern)
    }
  )
)
