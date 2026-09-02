#' Base R Boxplot Layer Processor
#'
#' Processes Base R boxplot layers by extracting statistical summaries
#' and generating selectors for boxplot components.
#'
#' @keywords internal
BaseRBoxplotLayerProcessor <- R6::R6Class(
  "BaseRBoxplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt, data)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)
      orientation <- self$determine_orientation(layer_info)

      # Determine if IQR direction should be reversed
      # For vertical Base R boxplots, Q1/Q3 edges are inverted from frontend default
      iqr_direction <- if (orientation == "vert") "reverse" else "forward"

      list(
        data = data,
        selectors = selectors,
        type = "box",
        title = title,
        axes = axes,
        orientation = orientation,
        domMapping = list(iqrDirection = iqr_direction)
      )
    },
    # The five-number summaries the drawn boxes came from
    #
    # A `boxplot()` call carries the *observations*, so the summaries have to
    # be recomputed from them -- which `boxplot(plot = FALSE)` does, using
    # the same code path the drawing did, rather than a reimplementation of
    # it here. `graphics::boxplot` is named directly so the replay does not
    # go back through maidr's own wrapper and record a second call.
    #
    # Overridable because `bxp()` is handed the summaries already computed
    # and draws exactly the same marks from them: everything below this
    # method -- the outlier grouping, the polygon and segment indices, the
    # shift each box with no outliers puts on the ones after it -- is the
    # same reading either way, and only where the summaries come from
    # differs (#262).
    #
    # @param args Recorded argument list
    # @return The `boxplot.stats`-shaped list, or NULL when it cannot be had
    read_stats = function(args) {
      args$plot <- FALSE
      tryCatch(do.call(graphics::boxplot, args), error = function(e) NULL)
    },
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      stats_obj <- self$read_stats(args)
      if (is.null(stats_obj) || is.null(stats_obj$stats)) {
        return(list())
      }

      stats_mat <- stats_obj$stats # 5 x N: [1]=min, [2]=Q1, [3]=median, [4]=Q3, [5]=max
      group_names <- if (!is.null(stats_obj$names)) {
        stats_obj$names
      } else {
        as.character(seq_len(ncol(stats_mat)))
      }

      # Outliers grouped by $group indices
      out_vals <- if (!is.null(stats_obj$out)) stats_obj$out else numeric(0)
      out_groups <- if (!is.null(stats_obj$group)) stats_obj$group else integer(0)

      results <- vector("list", length = ncol(stats_mat))
      for (i in seq_len(ncol(stats_mat))) {
        min_w <- as.numeric(stats_mat[1, i])
        q1_v <- as.numeric(stats_mat[2, i])
        med_v <- as.numeric(stats_mat[3, i])
        q3_v <- as.numeric(stats_mat[4, i])
        max_w <- as.numeric(stats_mat[5, i])

        # Outliers for this group index i (boxplot() groups are 1..N)
        idx <- which(out_groups == i)
        group_outliers <- if (length(idx) > 0) out_vals[idx] else numeric(0)
        lower_outliers <- as.list(group_outliers[group_outliers < min_w])
        upper_outliers <- as.list(group_outliers[group_outliers > max_w])

        results[[i]] <- list(
          min = min_w,
          q1 = q1_v,
          q2 = med_v,
          q3 = q3_v,
          max = max_w,
          z = group_names[[i]],
          lowerOutliers = lower_outliers,
          upperOutliers = upper_outliers
        )
      }

      # For horizontal boxplots, reverse data to match visual order (bottom-to-top)
      if (recorded_flag(args, "horizontal")) {
        results <- rev(results)
      }

      results
    },
    generate_selectors = function(layer_info, gt = NULL, extracted_data = NULL) {
      # Simplified selector mapping: use the IQ polygon selector for all parts
      data_len <- 0
      data_to_use <- extracted_data

      plot_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        1
      }

      stats_obj <- NULL
      if (!is.null(self$layer_info) && !is.null(self$layer_info$plot_call)) {
        plot_call <- self$layer_info$plot_call
        stats_obj <- self$read_stats(plot_call$args)
        if (!is.null(stats_obj) && !is.null(stats_obj$stats)) data_len <- ncol(stats_obj$stats)
      }
      if (data_len <= 0) {
        return(list())
      }

      # Per-group outlier values in DRAWING order: bxp() draws each
      # group's outliers in their original data order, so nth-child
      # positions must come from that order, not from a lower-then-upper
      # assumption.
      stats_out_vals <- if (!is.null(stats_obj$out)) stats_obj$out else numeric(0)
      stats_out_groups <- if (!is.null(stats_obj$group)) stats_obj$group else integer(0)

      # If extracted_data is provided, use it for outlier counts
      if (is.null(data_to_use) && !is.null(self$layer_info$data)) {
        data_to_use <- self$layer_info$data
      }

      # Gather per-box polygon ids and build per-group selectors
      collect_names <- function(g) {
        names <- character(0)
        if (!is.null(g$name)) {
          names <- c(names, as.character(g$name))
        }
        if (inherits(g, "gList")) {
          for (i in seq_along(g)) {
            names <- c(names, collect_names(g[[i]]))
          }
        }
        if (inherits(g, "gTree") && !is.null(g$children)) {
          for (i in seq_along(g$children)) {
            names <- c(names, collect_names(g$children[[i]]))
          }
        }
        if (!is.null(g$grobs)) {
          for (i in seq_along(g$grobs)) {
            names <- c(names, collect_names(g$grobs[[i]]))
          }
        }
        names
      }
      sort_ids <- function(ids) {
        if (length(ids) == 0) {
          return(ids)
        }
        ord <- order(suppressWarnings(as.integer(sub(".*-([0-9]+)$", "\\1", ids))))
        ids[ord]
      }
      all_names <- if (!is.null(gt)) collect_names(gt) else character(0)
      poly_pattern <- paste0("^graphics-plot-", plot_index, "-polygon-[0-9]+$")
      poly_ids <- sort_ids(grep(poly_pattern, all_names, value = TRUE))

      # Heuristic: polygons often come as pairs per box (filled, outline)
      per_box_ids <- character(0)
      if (length(poly_ids) >= data_len * 2) {
        per_box_ids <- poly_ids[seq(1, by = 2, length.out = data_len)]
      } else if (length(poly_ids) >= data_len) {
        per_box_ids <- poly_ids[seq_len(data_len)]
      } else {
        # Fallback: reuse last id if fewer found
        if (length(poly_ids) > 0) {
          per_box_ids <- rep(poly_ids[length(poly_ids)], data_len)
        } else {
          per_box_ids <- rep(paste0("graphics-plot-", plot_index, "-polygon-1"), data_len)
        }
      }

      make_poly_sel <- function(id) paste0("polygon[id^='", id, ".1']")
      make_group_sel <- function(group_idx) {
        paste0("g#graphics-plot-", plot_index, "-segments-", group_idx, "\\.1 > polyline")
      }
      make_whisker_sel <- function(group_idx, which_child) {
        paste0(
          "g#graphics-plot-",
          plot_index,
          "-segments-",
          group_idx,
          "\\.1 > polyline:nth-child(",
          which_child,
          ")"
        )
      }

      plot_call <- if (!is.null(self$layer_info)) self$layer_info$plot_call else NULL
      args <- if (!is.null(plot_call)) plot_call$args else list()
      is_horizontal <- recorded_flag(args, "horizontal")

      # Pre-compute which boxes have outliers (for formula adjustment)
      # Boxes with no outliers cause subsequent boxes to shift their segment indices
      # Map to original SVG order (data_to_use may be reversed for horizontal plots)
      boxes_with_no_outliers <- logical(data_len)
      for (idx in seq_len(data_len)) {
        if (!is.null(data_to_use) && length(data_to_use) >= idx) {
          box_data <- data_to_use[[idx]]
          lower_count <- length(
            if (!is.null(box_data$lowerOutliers)) box_data$lowerOutliers else list()
          )
          upper_count <- length(
            if (!is.null(box_data$upperOutliers)) box_data$upperOutliers else list()
          )
          # Map idx (which is in data_to_use order) to original SVG order
          svg_order_idx <- if (is_horizontal) (data_len - idx + 1) else idx
          boxes_with_no_outliers[svg_order_idx] <- (lower_count == 0 && upper_count == 0)
        }
      }

      selectors <- vector("list", data_len)
      for (i in seq_len(data_len)) {
        # For horizontal plots, data_to_use is already reversed, but SVG elements
        # (per_box_ids, segments, points) are in original order.
        # Map loop index i (which accesses reversed data) to original SVG index.
        svg_idx <- if (is_horizontal) (data_len - i + 1) else i

        # Count how many boxes BEFORE current box (in original SVG order) have no outliers
        # Each box with no outliers causes a shift of -1 in the segment indices
        no_outlier_count_before <- sum(boxes_with_no_outliers[seq_len(svg_idx - 1)])

        iq_sel <- make_poly_sel(per_box_ids[[svg_idx]])
        # Median group index (adjusted for boxes with no outliers)
        y_idx <- 4 * svg_idx - 3 - no_outlier_count_before
        # Whisker caps group index (adjusted for boxes with no outliers)
        w_idx <- 4 * svg_idx - 1 - no_outlier_count_before

        q2_sel <- make_group_sel(y_idx)
        # For whisker caps: the order of nth-child depends on orientation
        # Vertical plots: nth-child(1) is MIN, nth-child(2) is MAX
        # Horizontal plots: nth-child(1) is left (MIN), nth-child(2) is right (MAX)
        if (is_horizontal) {
          min_sel <- make_whisker_sel(w_idx, 1)
          max_sel <- make_whisker_sel(w_idx, 2)
        } else {
          min_sel <- make_whisker_sel(w_idx, 1)
          max_sel <- make_whisker_sel(w_idx, 2)
        }

        # Points group index. `bxp()` draws each box's outliers as one
        # `points()` call and skips it for a box that has none, so the
        # index shifts by the number of earlier boxes without outliers --
        # the same shift the segment indices above already apply. Without
        # it a box after an outlier-free one was outlined on the next
        # box's outliers.
        points_idx <- 2 * svg_idx - no_outlier_count_before

        # Outliers for this box in DRAWING (data) order. bxp() draws them
        # unsorted, so the k-th <use> child is the k-th value of the
        # group's outlier vector - which can interleave lower and upper
        # outliers arbitrarily.
        group_vals <- if (length(stats_out_groups) > 0) {
          stats_out_vals[stats_out_groups == svg_idx]
        } else {
          numeric(0)
        }
        box_min <- as.numeric(stats_obj$stats[1, svg_idx])
        box_max <- as.numeric(stats_obj$stats[5, svg_idx])
        lower_positions <- which(group_vals < box_min)
        upper_positions <- which(group_vals > box_max)

        lower_sel <- list()
        upper_sel <- list()

        if (length(lower_positions) > 0 || length(upper_positions) > 0) {
          points_group <- paste0(
            "g#graphics-plot-",
            plot_index,
            "-points-",
            points_idx,
            "\\.1 > use"
          )

          # One selector per outlier, in the same order as the extracted
          # data values, so the frontend pairs element k with value k.
          lower_sel <- lapply(lower_positions, function(pos) {
            paste0(points_group, ":nth-child(", pos, ")")
          })
          upper_sel <- lapply(upper_positions, function(pos) {
            paste0(points_group, ":nth-child(", pos, ")")
          })
        }

        selectors[[i]] <- list(
          lowerOutliers = lower_sel,
          min = min_sel,
          iq = iq_sel,
          q2 = q2_sel,
          max = max_sel,
          upperOutliers = upper_sel
        )
      }

      # Note: For horizontal boxplots, selectors are already built in the correct
      # order to match the reversed data (we use reversed indices during generation)
      # so no need to reverse the selectors array here.

      selectors
    },
    # Extract the axis titles for this layer
    #
    # `boxplot()` records no title unless the author wrote one, but the
    # formula method derives both from the formula itself and draws them, so
    # a `y ~ g` call already names its axes: the response on the value axis
    # and the grouping terms on the category axis. Everything else falls back
    # to what a box plot always shows -- groups against their distributions.
    # `horizontal = TRUE` swaps which visual axis is which, exactly as
    # boxplot.formula()'s own defaults do.
    #
    # @param layer_info Layer information
    # @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      args <- layer_info$plot_call$args
      horizontal <- self$determine_orientation(layer_info) == "horz"

      formula_labels <- self$extract_formula_labels(
        args, layer_info$plot_call$formula_frame
      )
      if (is.null(formula_labels)) {
        return(base_r_categorical_axes(args, horizontal = horizontal))
      }

      build_axes(
        x = recorded_axis_label(
          args, "xlab",
          if (horizontal) formula_labels$response else formula_labels$groups
        ),
        y = recorded_axis_label(
          args, "ylab",
          if (horizontal) formula_labels$groups else formula_labels$response
        )
      )
    },

    # Read the axis titles boxplot.formula() derives from its formula
    #
    # `boxplot.formula()` builds them out of the model frame's column names:
    # the response column names the value axis and the remaining columns,
    # joined with " : ", name the category axis. Building the same model
    # frame reproduces the drawn titles for expressions (`log(mpg) ~ cyl`)
    # and for `.` alike, where deparsing the formula's terms would not.
    #
    # @param args Recorded argument list
    # @return List with `response` and `groups`, or NULL when this call is
    #   not the formula method or the model frame cannot be rebuilt
    extract_formula_labels = function(args, frame = NULL) {
      # boxplot()'s formula method names its first formal `formula`, and
      # match_recorded_args() leaves the dispatch argument as the author
      # wrote it, so a positional call records it unnamed.
      formula <- args[["formula"]]
      if (is.null(formula) && length(args) > 0) {
        formula <- args[[1]]
      }
      if (!inherits(formula, "formula") || length(formula) != 3L) {
        return(NULL)
      }

      # The frame the chart was drawn from, when the recording kept one.
      # Rebuilding it here would resolve the formula's variables against
      # whatever they are bound to *now* -- a staler axis title than the
      # stripchart's stale values, but the same defect (#254).
      model_frame <- if (!is.null(frame)) {
        frame
      } else {
        tryCatch(
          stats::model.frame(formula, data = args[["data"]]),
          error = function(e) NULL
        )
      }
      if (is.null(model_frame)) {
        return(NULL)
      }

      response <- attr(attr(model_frame, "terms"), "response")
      if (is.null(response) || response < 1) {
        return(NULL)
      }

      labels <- list(
        response = names(model_frame)[response],
        groups = paste(names(model_frame)[-response], collapse = " : ")
      )
      # A formula with no grouping term (`y ~ 1`) names only one axis, which
      # is no better than the generic pair.
      if (!nzchar(labels$response) || !nzchar(labels$groups)) {
        return(NULL)
      }

      labels
    },
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      args <- layer_info$plot_call$args
      recorded_main_title(args)
    },
    determine_orientation = function(layer_info) {
      if (is.null(layer_info)) {
        return("vert")
      }
      args <- layer_info$plot_call$args
      horizontal <- recorded_flag(args, "horizontal")
      if (horizontal) "horz" else "vert"
    }
  )
)
