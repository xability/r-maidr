#' Base R Boxplot Layer Processor
#'
#' Processes Base R boxplot layers by extracting statistical summaries
#' and generating selectors for boxplot components.
#'
#' @keywords internal
BaseRBoxplotLayerProcessor <- R6::R6Class("BaseRBoxplotLayerProcessor",
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
        dom_mapping = list(iqrDirection = iqr_direction)
      )
    },
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Recreate boxplot stats using original args with plot=FALSE
      args_no_plot <- args
      args_no_plot$plot <- FALSE

      # Safely call boxplot() to get stats structure
      stats_obj <- tryCatch(
        {
          do.call(boxplot, args_no_plot)
        },
        error = function(e) {
          return(NULL)
        }
      )
      if (is.null(stats_obj) || is.null(stats_obj$stats)) {
        return(list())
      }

      stats_mat <- stats_obj$stats # 5 x N: [1]=min, [2]=Q1, [3]=median, [4]=Q3, [5]=max
      group_names <- if (!is.null(stats_obj$names)) stats_obj$names else as.character(seq_len(ncol(stats_mat)))

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
          fill = group_names[[i]],
          lowerOutliers = lower_outliers,
          upperOutliers = upper_outliers
        )
      }

      # For horizontal boxplots, reverse data to match visual order (bottom-to-top)
      if (!is.null(args$horizontal) && isTRUE(args$horizontal)) {
        results <- rev(results)
      }

      results
    },
    generate_selectors = function(layer_info, gt = NULL, extracted_data = NULL) {
      # Simplified selector mapping: use the IQ polygon selector for all parts
      data_len <- 0
      data_to_use <- extracted_data

      # Get panel/group index for multipanel support
      plot_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        1
      }

      if (!is.null(self$layer_info) && !is.null(self$layer_info$plot_call)) {
        plot_call <- self$layer_info$plot_call
        args <- plot_call$args
        args$plot <- FALSE
        stats_obj <- tryCatch(
          {
            do.call(boxplot, args)
          },
          error = function(e) NULL
        )
        if (!is.null(stats_obj) && !is.null(stats_obj$stats)) data_len <- ncol(stats_obj$stats)
      }
      if (data_len <= 0) {
        return(list())
      }

      # If extracted_data is provided, use it for outlier counts
      if (is.null(data_to_use) && !is.null(self$layer_info$data)) {
        data_to_use <- self$layer_info$data
      }

      # Gather per-box polygon ids and build per-group selectors
      collect_names <- function(g) {
        names <- character(0)
        if (!is.null(g$name)) names <- c(names, as.character(g$name))
        if (inherits(g, "gList")) {
          for (i in seq_along(g)) names <- c(names, collect_names(g[[i]]))
        }
        if (inherits(g, "gTree") && !is.null(g$children)) {
          for (i in seq_along(g$children)) names <- c(names, collect_names(g$children[[i]]))
        }
        if (!is.null(g$grobs)) {
          for (i in seq_along(g$grobs)) names <- c(names, collect_names(g$grobs[[i]]))
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
      make_group_sel <- function(group_idx) paste0("g#graphics-plot-", plot_index, "-segments-", group_idx, "\\.1 > polyline")
      make_whisker_sel <- function(group_idx, which_child) {
        paste0("g#graphics-plot-", plot_index, "-segments-", group_idx, "\\.1 > polyline:nth-child(", which_child, ")")
      }

      # Check if data will be reversed (horizontal plot)
      plot_call <- if (!is.null(self$layer_info)) self$layer_info$plot_call else NULL
      args <- if (!is.null(plot_call)) plot_call$args else list()
      is_horizontal <- !is.null(args$horizontal) && isTRUE(args$horizontal)

      # Pre-compute which boxes have outliers (for formula adjustment)
      # Boxes with no outliers cause subsequent boxes to shift their segment indices
      # Map to original SVG order (data_to_use may be reversed for horizontal plots)
      boxes_with_no_outliers <- logical(data_len)
      for (idx in seq_len(data_len)) {
        if (!is.null(data_to_use) && length(data_to_use) >= idx) {
          box_data <- data_to_use[[idx]]
          lower_count <- length(if (!is.null(box_data$lowerOutliers)) box_data$lowerOutliers else list())
          upper_count <- length(if (!is.null(box_data$upperOutliers)) box_data$upperOutliers else list())
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
        y_idx <- 4 * svg_idx - 3 - no_outlier_count_before # median group index (adjusted for boxes with no outliers)
        w_idx <- 4 * svg_idx - 1 - no_outlier_count_before # whisker caps group index (adjusted for boxes with no outliers)

        q2_sel <- make_group_sel(y_idx)
        # For whisker caps: the order of nth-child depends on orientation
        # Vertical plots: nth-child(1) is MIN, nth-child(2) is MAX
        # Horizontal plots: nth-child(1) is visually left (MIN), nth-child(2) is visually right (MAX)
        if (is_horizontal) {
          min_sel <- make_whisker_sel(w_idx, 1)
          max_sel <- make_whisker_sel(w_idx, 2)
        } else {
          min_sel <- make_whisker_sel(w_idx, 1)
          max_sel <- make_whisker_sel(w_idx, 2)
        }

        # Generate outlier selectors
        # Points group index follows pattern: 2 * svg_idx
        points_idx <- 2 * svg_idx

        # Access the data that was extracted
        lower_count <- 0
        upper_count <- 0
        if (!is.null(data_to_use) && length(data_to_use) >= i) {
          box_data <- data_to_use[[i]]
          lower_outliers_data <- if (!is.null(box_data$lowerOutliers)) box_data$lowerOutliers else list()
          upper_outliers_data <- if (!is.null(box_data$upperOutliers)) box_data$upperOutliers else list()
          lower_count <- length(lower_outliers_data)
          upper_count <- length(upper_outliers_data)
        }

        lower_sel <- character(0)
        upper_sel <- character(0)

        if (lower_count > 0 || upper_count > 0) {
          points_group <- paste0("g#graphics-plot-", plot_index, "-points-", points_idx, "\\.1 > use")

          if (lower_count > 0) {
            # Select first N children for lower outliers
            lower_sel <- paste0(points_group, ":nth-child(-n+", lower_count, ")")
          }

          if (upper_count > 0) {
            # Select from (lower_count + 1)th child onward for upper outliers
            start_idx <- lower_count + 1
            upper_sel <- paste0(points_group, ":nth-child(n+", start_idx, ")")
          }
        }

        selectors[[i]] <- list(
          lowerOutliers = if (length(lower_sel) > 0) list(lower_sel) else list(),
          min = min_sel,
          iq = iq_sel,
          q2 = q2_sel,
          max = max_sel,
          upperOutliers = if (length(upper_sel) > 0) list(upper_sel) else list()
        )
      }

      # Note: For horizontal boxplots, selectors are already built in the correct
      # order to match the reversed data (we use reversed indices during generation)
      # so no need to reverse the selectors array here.

      selectors
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }
      args <- layer_info$plot_call$args
      list(
        x = if (!is.null(args$xlab)) args$xlab else "",
        y = if (!is.null(args$ylab)) args$ylab else ""
      )
    },
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      args <- layer_info$plot_call$args
      if (!is.null(args$main)) args$main else ""
    },
    determine_orientation = function(layer_info) {
      if (is.null(layer_info)) {
        return("vert")
      }
      args <- layer_info$plot_call$args
      horizontal <- if (!is.null(args$horizontal)) isTRUE(args$horizontal) else FALSE
      if (horizontal) "horz" else "vert"
    }
  )
)
