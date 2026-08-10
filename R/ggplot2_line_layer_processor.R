#' Final Line Layer Processor - Uses Actual SVG Structure
#'
#' @description
#' Processes line plot layers using the actual gridSVG structure discovered:
#' - Lines: GRID.polyline.61.1.1, GRID.polyline.61.1.2, GRID.polyline.61.1.3
#' - Points: geom_point.points.63.1.1 through geom_point.points.63.1.24 (grouped by series)
#'
#' @field layer_info Information about the layer being processed
#' @field last_result The last processing result
#'
#' @keywords internal
Ggplot2LineLayerProcessor <- R6::R6Class(
  "Ggplot2LineLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the line layer with actual SVG structure
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with data and selectors
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      data <- self$extract_data(plot, built, scale_mapping, panel_id)

      # Size the selectors to the series actually emitted: the frontend's
      # multiline trace drops the whole layer's highlight unless
      # selectors.length === data.length.
      selectors <- self$generate_selectors(
        plot, gt, grob_id, panel_ctx,
        built = built, n_series = length(data)
      )

      axes <- self$extract_layer_axes(plot, layout)
      axes <- self$attach_group_axis(plot, built, data, axes)

      list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = axes
      )
    },

    #' @description Add the legend title as the z axis label for a
    #' multi-series line layer.
    #'
    #' Shared with the smooth layer processor via
    #' \code{attach_series_group_axis()}; see \code{R/series_group_utils.R}.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param data The extracted layer data
    #' @param axes Axes built so far
    #' @return The axes list, with z added when the layer is grouped
    attach_group_axis = function(plot, built, data, axes) {
      attach_series_group_axis(
        axes, plot, built, data,
        layer_index = self$get_layer_index()
      )
    },

    #' @description Report whether extracted data is split into named series.
    #' @param data The extracted layer data
    #' @return TRUE when there is more than one series and points carry z
    has_series_groups = function(data) {
      data_has_series_groups(data)
    },

    #' @description Resolve the aesthetic that splits this layer into series.
    #'
    #' A line has no fill, so only the colour aesthetic is probed.
    #'
    #' @param plot The ggplot2 object
    #' @return list with \code{aes} (aesthetic spelling variants, or NULL when
    #'   nothing is mapped) and \code{column} (the mapped column name, or
    #'   "group" as a fallback)
    resolve_group_mapping = function(plot) {
      resolve_series_group_mapping(plot, self$layer_info$index)
    },

    #' @description Extract axes labels for line layers, with a special case for
    #' moving-average geoms (e.g. `tidyquant::geom_ma`).
    #'
    #' By default the parent `LayerProcessor$extract_layer_axes()` reads the
    #' y-label from the layer's aesthetic mapping. For a moving-average
    #' overlay typically written as `geom_ma(aes(y = close), ma_fun = SMA, ...)`,
    #' this yields the literal input-column name `"close"`, which is misleading:
    #' the value being plotted (and announced during navigation) is the moving
    #' average of `close`, not `close` itself. We detect `GeomMA` (the class of
    #' tidyquant's geom_ma layer) and override the y-label accordingly. Plain
    #' `geom_line` / `geom_smooth` overlays are untouched.
    #'
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @return list(x = list(label = ...), y = list(label = ...))
    extract_layer_axes = function(plot, layout) {
      axes <- super$extract_layer_axes(plot, layout)

      layer_index <- self$get_layer_index()
      layer <- plot$layers[[layer_index]]
      if (!is.null(layer) && inherits(layer$geom, "GeomMA")) {
        axes$y$label <- "Moving Average"
      }

      axes
    },

    #' @description Extract data from line layer (single or multiline)
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List of arrays, each containing series data points
    extract_data = function(plot, built = NULL, scale_mapping = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_data <- built$data[[self$layer_info$index]]

      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        layer_data <- layer_data[layer_data$PANEL == panel_id, ]
      }

      # Every scale lookup below has to read THIS panel's scale: with
      # scales = "free_x" each panel carries its own breaks and labels.
      panel_index <- self$resolve_panel_index(built, panel_id)

      # For faceted plots, get x values from original data or scale mapping
      if (!is.null(panel_id)) {
        # For faceted plots, we need to get the actual x values from the original data
        if (!is.null(scale_mapping)) {
          layer_data$x <- self$apply_scale_mapping(layer_data$x, scale_mapping)
        } else {
          plot_mapping <- plot$mapping
          layer_mapping <- plot$layers[[self$layer_info$index]]$mapping

          x_col <- NULL
          if (!is.null(layer_mapping$x)) {
            x_col <- rlang::as_label(layer_mapping$x)
          } else if (!is.null(plot_mapping$x)) {
            x_col <- rlang::as_label(plot_mapping$x)
          }

          # Map this panel's built x positions back to user-facing values.
          # Built positions are only INDICES for discrete scales; for
          # continuous/Date scales they are the numeric values themselves,
          # so blind indexing (x_values[layer_data$x]) yields NA for every
          # point.
          original_values <- if (!is.null(x_col) && x_col %in% names(plot$data)) {
            sort(unique(plot$data[[x_col]]))
          } else {
            NULL
          }

          x_pos <- layer_data$x
          n_values <- length(original_values)
          looks_like_positions <- !is.null(original_values) &&
            !is.numeric(original_values) &&
            is.numeric(x_pos) &&
            all(!is.na(x_pos)) &&
            all(abs(x_pos - round(x_pos)) < 1e-6) &&
            all(round(x_pos) >= 1 & round(x_pos) <= n_values)

          # Whatever is not resolved here stays numeric: the break/label
          # mapping further down needs a numeric vector, and
          # extract_*_line_data() stringifies anything that survives it.
          if (looks_like_positions) {
            # Discrete scale: positions index the (sorted) categories
            layer_data$x <- as.character(original_values[round(x_pos)])
          } else if (
            !is.null(original_values) &&
              is.numeric(x_pos) &&
              !anyNA(suppressWarnings(as.numeric(original_values)))
          ) {
            # Continuous/Date scale: match numeric representations back to
            # the original values so Dates format as dates, not day counts.
            #
            # `x_pos` is in the scale's TRANSFORMED space -- under
            # scale_x_log10() the value 100 is stored as 2, under
            # scale_x_reverse() 1 is stored as -1 -- so the raw values have
            # to travel through the same transformation before they can be
            # compared, or nothing ever matches and the transformed number
            # is announced instead of the value the axis shows.
            transformation <- self$get_x_transformation(built, panel_index)
            numeric_repr <- round(
              self$transform_x_values(original_values, transformation), 6
            )
            match_idx <- match(round(as.numeric(x_pos), 6), numeric_repr)
            hit <- !is.na(match_idx)
            if (any(hit)) {
              mapped <- as.character(x_pos)
              matched_vals <- original_values[match_idx[hit]]
              mapped[hit] <- if (
                inherits(original_values, c("Date", "POSIXct", "POSIXlt"))
              ) {
                format(matched_vals)
              } else {
                as.character(matched_vals)
              }
              layer_data$x <- mapped
            }
          }
        }
      } else {
        if (!is.null(scale_mapping)) {
          layer_data$x <- self$apply_scale_mapping(layer_data$x, scale_mapping)
        }
      }

      # Map numeric x positions to axis labels for categorical x-axis
      panel_params <- built$layout$panel_params[[panel_index]]
      if (!is.null(panel_params$x)) {
        x_labels <- NULL
        x_breaks <- NULL

        # Try to get labels via get_labels() method (works for both discrete and continuous scales)
        tryCatch(
          {
            if (!is.null(panel_params$x$get_labels)) {
              x_labels <- as.character(panel_params$x$get_labels())
            }
            if (!is.null(panel_params$x$breaks)) {
              x_breaks <- panel_params$x$breaks
            }
          },
          error = function(e) NULL
        )

        # Only map if we have both labels and breaks, and labels are different from breaks
        if (!is.null(x_labels) && length(x_labels) > 0 &&
          !is.null(x_breaks) && length(x_breaks) == length(x_labels)) {
          # Create a mapping from break values to labels
          x_positions <- layer_data$x
          # Only do numeric matching if both x_breaks and positions are numeric
          if (is.numeric(x_breaks) && is.numeric(x_positions)) {
            # Vectorized break matching: iterating over breaks (few) is
            # O(breaks) vector operations instead of a per-point closure
            match_idx <- rep(NA_integer_, length(x_positions))
            for (break_i in seq_along(x_breaks)) {
              hit <- is.na(match_idx) &
                abs(x_positions - x_breaks[break_i]) < 0.001
              match_idx[hit] <- break_i
            }
            mapped_x <- as.character(x_positions)
            matched <- !is.na(match_idx)
            mapped_x[matched] <- x_labels[match_idx[matched]]
            layer_data$x <- mapped_x
          } else if (is.numeric(x_positions) && length(x_labels) > 0) {
            # For categorical scales, use integer position to index labels
            idx <- as.integer(round(x_positions))
            valid <- !is.na(idx) & idx >= 1 & idx <= length(x_labels)
            mapped_x <- as.character(x_positions)
            mapped_x[valid] <- x_labels[idx[valid]]
            layer_data$x <- mapped_x
          }
        }
      }

      series_data <- NULL
      if ("group" %in% names(layer_data)) {
        unique_groups <- unique(layer_data$group)
        # Only treat as multiline if we have more than one group
        if (length(unique_groups) > 1) {
          # Multiline plot - group by series
          series_data <- self$extract_multiline_data(layer_data, plot)
        }
      }
      if (is.null(series_data)) {
        # Single line plot - maintain backward compatibility
        series_data <- self$extract_single_line_data(layer_data, plot)
      }

      self$attach_discrete_y_names(series_data, plot, built)
    },

    #' @description Give every point the *name* of its discrete y level.
    #'
    #' A factor y aesthetic reaches the payload as ggplot2's internal level
    #' code, so without this a reader hears "5" where the axis says "Awake".
    #' `y` deliberately stays numeric -- it drives sonification, braille and
    #' the min/max range -- and the name rides alongside as `label`.
    #'
    #' A continuous y is returned untouched, so no `label` is emitted and the
    #' frontend announces the number, which is the right reading there.
    #'
    #' @param series_data List of series produced by the extractors above
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @return The series list, labelled when y is discrete
    attach_discrete_y_names = function(series_data, plot, built) {
      series_data <- self$normalize_point_values(series_data)

      lookup <- self$build_level_lookup(plot, built)
      if (is.null(lookup)) {
        return(series_data)
      }
      self$attach_level_labels(series_data, lookup)
    },

    #' @description Coerce every point's y to a plain number.
    #'
    #' A discrete y aesthetic -- the ordinal level of a hypnogram, and the
    #' reason this processor exists -- makes `ggplot_build()` return y as a
    #' `mapped_discrete` vector. That class carries no `asJSON` method, so
    #' emitting it verbatim aborts payload serialisation with
    #' "No method asJSON S3 class: mapped_discrete". Stripping the class here
    #' keeps y a bare number, which is what the wire contract asks for and
    #' what drives sonification, braille and the min/max range.
    #'
    #' @param series_data List of series produced by the line extractor
    #' @return The series list with numeric y values
    normalize_point_values = function(series_data) {
      for (s in seq_along(series_data)) {
        series <- series_data[[s]]
        for (i in seq_along(series)) {
          point <- series[[i]]
          # `is.numeric()` is TRUE for mapped_discrete, which inherits
          # numeric, and FALSE for a y the extractors stringified -- so this
          # strips the class without turning a character y into NA.
          if (!is.null(point$y) && is.numeric(point$y)) {
            point$y <- as.numeric(point$y)
            series[[i]] <- point
          }
        }
        series_data[[s]] <- series
      }
      series_data
    },

    #' @description Build a numeric-level to level-name lookup for the y
    #' aesthetic.
    #'
    #' For a factor (or character) y aesthetic, `ggplot_build()` replaces the
    #' level with its numeric position, so `built$data$y` is a level *code*
    #' and the name only survives in the original column. The lookup is keyed
    #' by the built y value and built from the full, unfiltered pair of
    #' columns, so it stays correct no matter which rows survive NA-dropping
    #' or panel filtering downstream.
    #'
    #' Returns NULL for a plain continuous y, in which case no `label` is
    #' emitted and the frontend announces the numeric value.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @return Named character vector keyed by the built y value, or NULL
    build_level_lookup = function(plot, built) {
      layer_data <- built$data[[self$layer_info$index]]
      if (is.null(layer_data) || !"y" %in% names(layer_data)) {
        return(NULL)
      }

      original_y <- self$get_original_y_column(plot, layer_data)
      if (is.null(original_y)) {
        return(NULL)
      }
      if (!is.factor(original_y) && !is.character(original_y)) {
        return(NULL)
      }

      keys <- as.character(layer_data$y)
      # Not `names`: R would still resolve names()/`names<-`() correctly, since
      # a call looks past non-function bindings, but shadowing a base function
      # here reads as a bug even though it is not one.
      level_names <- as.character(original_y)
      keep <- !is.na(layer_data$y) & !is.na(original_y)
      if (!any(keep)) {
        return(NULL)
      }

      lookup <- level_names[keep]
      names(lookup) <- keys[keep]
      lookup[!duplicated(names(lookup))]
    },

    #' @description Recover the original (untransformed) y column for a layer.
    #'
    #' Mirrors `get_original_x_column()`: looks up the y mapping on the layer
    #' first and then on the plot, and searches the layer's own `data` before
    #' the plot's. Returns the per-row vector aligned to `built_data` when a
    #' simple column reference is found and the lengths match, otherwise NULL.
    #'
    #' @param plot The ggplot2 object
    #' @param built_data The built data frame for this layer
    #' @return The original y column, or NULL
    get_original_y_column = function(plot, built_data) {
      layer <- self$get_layer(plot)
      if (is.null(layer)) {
        return(NULL)
      }

      y_expr <- NULL
      if (!is.null(layer$mapping) && !is.null(layer$mapping$y)) {
        y_expr <- layer$mapping$y
      } else if (!is.null(plot$mapping) && !is.null(plot$mapping$y)) {
        y_expr <- plot$mapping$y
      }
      if (is.null(y_expr)) {
        return(NULL)
      }
      y_col <- rlang::as_label(y_expr)

      candidates <- list()
      if (!is.null(layer$data) && is.data.frame(layer$data) &&
        y_col %in% names(layer$data)) {
        candidates[[length(candidates) + 1L]] <- layer$data
      }
      if (!is.null(plot$data) && is.data.frame(plot$data) &&
        y_col %in% names(plot$data)) {
        candidates[[length(candidates) + 1L]] <- plot$data
      }

      for (src in candidates) {
        col <- src[[y_col]]
        if (length(col) == nrow(built_data)) {
          return(col)
        }
      }
      NULL
    },

    #' @description Attach the ordinal level name to every point of every
    #' series. Points whose y has no entry in the lookup are left untouched,
    #' so the frontend falls back to the numeric announcement for them.
    #'
    #' @param series_data List of series produced by the line extractor
    #' @param lookup Named character vector keyed by the built y value
    #' @return The series list with `label` attached where known
    attach_level_labels = function(series_data, lookup) {
      for (s in seq_along(series_data)) {
        series <- series_data[[s]]
        for (i in seq_along(series)) {
          point <- series[[i]]
          if (is.null(point$y) || is.na(point$y)) {
            next
          }
          key <- as.character(point$y)
          if (!key %in% names(lookup)) {
            next
          }
          point$label <- unname(lookup[[key]])
          series[[i]] <- point
        }
        series_data[[s]] <- series
      }
      series_data
    },

    #' @description The ggplot2 layer this processor is responsible for.
    #' @param plot The ggplot2 object
    #' @return The layer, or NULL when the index does not resolve
    get_layer = function(plot) {
      if (is.null(plot) || is.null(plot$layers)) {
        return(NULL)
      }
      layer_index <- self$get_layer_index()
      if (is.null(layer_index) || layer_index > length(plot$layers)) {
        return(NULL)
      }
      plot$layers[[layer_index]]
    },

    #' @description Resolve which entry of \code{built$layout$panel_params}
    #' describes a facet panel.
    #'
    #' Panel parameters are stored in the row order of
    #' \code{built$layout$layout}, so panel \code{n} is entry \code{n}. An
    #' unfaceted plot (or an unusable id) resolves to the only panel there is.
    #'
    #' @param built Built plot data
    #' @param panel_id Panel id for faceted plots (optional)
    #' @return Integer index guaranteed to be in range
    resolve_panel_index = function(built, panel_id = NULL) {
      n_panels <- length(built$layout$panel_params)
      if (is.null(panel_id) || n_panels == 0) {
        return(1L)
      }
      candidate <- suppressWarnings(as.integer(as.character(panel_id)))
      if (is.na(candidate) || candidate < 1 || candidate > n_panels) {
        return(1L)
      }
      candidate
    },

    #' @description The transformation a panel's x scale applies to positions.
    #'
    #' \code{ggplot_build()} stores x positions in transformed space, so under
    #' \code{scale_x_log10()} the data value 100 is recorded as 2. Recovering
    #' the value the axis actually shows needs the scale's own transformation.
    #' ggplot2 >= 3.5 exposes it through \code{get_transformation()}; earlier
    #' versions keep it in the scale's \code{trans} field.
    #'
    #' @param built Built plot data
    #' @param panel_index Index into \code{built$layout$panel_params}
    #' @return A \pkg{scales} transform object, or NULL when none is available
    get_x_transformation = function(built, panel_index) {
      tryCatch(
        {
          scale <- built$layout$panel_params[[panel_index]]$x$scale
          if (is.null(scale)) {
            return(NULL)
          }
          transformation <- if (is.function(scale$get_transformation)) {
            scale$get_transformation()
          } else {
            scale$trans
          }
          if (is.null(transformation) || !is.function(transformation$transform)) {
            return(NULL)
          }
          transformation
        },
        error = function(e) NULL
      )
    },

    #' @description Project raw x values into the space \code{ggplot_build()}
    #' stores positions in.
    #'
    #' Going forwards (raw -> transformed) rather than inverting the built
    #' positions keeps the comparison exact: it repeats the very computation
    #' ggplot2 performed, so no floating-point drift is introduced. Values the
    #' transformation cannot represent (a non-positive number under a log
    #' scale, say) become NA and simply fail to match.
    #'
    #' @param values Raw values taken from the plot's data
    #' @param transformation Transform object from \code{get_x_transformation()},
    #'   or NULL
    #' @return Numeric vector the same length as \code{values}
    transform_x_values = function(values, transformation) {
      numeric_values <- suppressWarnings(as.numeric(values))
      if (is.null(transformation) || identical(transformation$name, "identity")) {
        return(numeric_values)
      }
      transformed <- tryCatch(
        suppressWarnings(as.numeric(transformation$transform(numeric_values))),
        error = function(e) NULL
      )
      if (is.null(transformed) || length(transformed) != length(numeric_values)) {
        return(numeric_values)
      }
      transformed
    },

    #' @description Format an x-axis value as character.
    #'
    #' Date / POSIXct / POSIXlt values are formatted via `format()` so that a
    #' `Date` column emits ISO date strings (e.g. "2024-01-02") rather than
    #' the underlying numeric days-since-epoch representation produced by
    #' `ggplot_build()`. All other types use `as.character()`. Mirrors
    #' `Ggplot2BarLayerProcessor$format_x_value()` so bar and line layers
    #' from the same Date column align string-wise.
    format_x_value = function(x) {
      if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) {
        return(format(x))
      }
      as.character(x)
    },

    #' @description Recover the original (untransformed) x column for a layer.
    #'
    #' `ggplot_build()` transforms Date / POSIXct columns into numeric
    #' days-since-epoch on `built$data[[i]]$x`. To emit ISO strings we need
    #' the original column from `plot$data` (or the layer's own `data`).
    #'
    #' Returns the per-row vector of x values aligned to `built_data` if a
    #' simple column reference is found and the lengths match, otherwise
    #' NULL.
    get_original_x_column = function(plot, built_data) {
      layer_index <- self$layer_info$index
      layer <- plot$layers[[layer_index]]

      x_expr <- NULL
      if (!is.null(layer$mapping) && !is.null(layer$mapping$x)) {
        x_expr <- layer$mapping$x
      } else if (!is.null(plot$mapping) && !is.null(plot$mapping$x)) {
        x_expr <- plot$mapping$x
      }
      if (is.null(x_expr)) {
        return(NULL)
      }
      x_col <- rlang::as_label(x_expr)

      candidates <- list()
      if (!is.null(layer$data) && is.data.frame(layer$data) &&
        x_col %in% names(layer$data)) {
        candidates[[length(candidates) + 1L]] <- layer$data
      }
      if (!is.null(plot$data) && is.data.frame(plot$data) &&
        x_col %in% names(plot$data)) {
        candidates[[length(candidates) + 1L]] <- plot$data
      }

      for (src in candidates) {
        col <- src[[x_col]]
        if (length(col) == nrow(built_data)) {
          return(col)
        }
      }
      NULL
    },

    #' @description Extract data for multiple line series
    #' @param layer_data The built layer data
    #' @param plot The original ggplot2 object
    #' @return List of arrays, each containing series data
    extract_multiline_data = function(layer_data, plot) {
      unique_groups <- sort(unique(layer_data$group))
      unique_categories <- resolve_series_group_names(
        plot, layer_data$group, self$get_group_column(plot)
      )

      # Recover original (Date/POSIXct-typed) x column when available so we
      # emit ISO date strings rather than numeric days-since-epoch.
      orig_x <- self$get_original_x_column(plot, layer_data)

      # Split built data by group, preserving row indices for orig_x lookup.
      layer_data$.row_idx <- seq_len(nrow(layer_data))
      series_groups <- split(layer_data, layer_data$group)

      series_data <- list()
      for (group_num in names(series_groups)) {
        series_points <- series_groups[[group_num]]

        # Drop rows whose y is NA. The corresponding gridSVG polyline only
        # contains coordinates for non-NA points (e.g. the warm-up period of
        # a moving-average overlay is omitted from the rendered polyline),
        # so emitting placeholder null rows here would make
        # `data.length > polyline.points.length` and shift the MAIDR JS
        # highlight-to-point index mapping by the number of leading NAs.
        if ("y" %in% names(series_points)) {
          series_points <- series_points[!is.na(series_points$y), , drop = FALSE]
        }
        if (nrow(series_points) == 0) {
          next
        }

        # Map group number to category name (following BarLayerProcessor pattern)
        group_idx <- as.numeric(group_num)
        category_idx <- which(unique_groups == group_idx)
        series_name <- if (length(category_idx) > 0 && category_idx <= length(unique_categories)) {
          as.character(unique_categories[category_idx])
        } else {
          paste0("Series ", group_num)
        }

        points <- list()
        for (i in seq_len(nrow(series_points))) {
          if (!is.null(orig_x)) {
            row_i <- series_points$.row_idx[i]
            x_val <- self$format_x_value(orig_x[row_i])
          } else {
            x_val <- self$format_x_value(series_points$x[i])
          }
          y_val <- series_points$y[i]
          point <- list(
            x = x_val,
            y = y_val,
            z = series_name
          )
          points[[i]] <- point
        }

        series_data[[length(series_data) + 1]] <- points
      }

      series_data
    },

    #' @description Extract data for single line (backward compatibility)
    #' @param layer_data The built layer data
    #' @return List containing single series data
    extract_single_line_data = function(layer_data, plot = NULL) {
      # Recover original (Date/POSIXct-typed) x column when available.
      orig_x <- NULL
      if (!is.null(plot)) {
        orig_x <- self$get_original_x_column(plot, layer_data)
      }

      # Determine which rows have a non-NA y. The rendered polyline only
      # contains coordinates for non-NA y points; emitting NA-y rows would
      # break the MAIDR JS index alignment between polyline.points and
      # data[] (see `extract_multiline_data()` for the same rationale).
      if ("y" %in% names(layer_data)) {
        keep <- !is.na(layer_data$y)
      } else {
        keep <- rep(TRUE, nrow(layer_data))
      }

      points <- list()
      for (i in seq_len(nrow(layer_data))) {
        if (!keep[i]) {
          next
        }
        x_val <- if (!is.null(orig_x)) {
          self$format_x_value(orig_x[i])
        } else {
          self$format_x_value(layer_data$x[i])
        }
        y_val <- layer_data$y[i]
        point <- list(
          x = x_val,
          y = y_val
        )
        points[[length(points) + 1L]] <- point
      }

      list(points)
    },

    #' @description Get the grouping column name from plot mappings
    #' @param plot The ggplot2 object
    #' @return Name of the grouping column
    get_group_column = function(plot) {
      self$resolve_group_mapping(plot)$column
    },

    #' @description One selector per series this line layer draws.
    #'
    #' The panel-wide polyline list conflates two different things: a
    #' grouped \code{geom_line()} draws ALL of its curves as ONE
    #' \code{polylineGrob} whose \code{id} splits it (gridSVG then emits
    #' \code{GRID.polyline.N.1.1}, \code{.1.2}, ... per curve), while a
    #' second polyline-producing layer such as \code{geom_smooth()} adds
    #' further grobs of its own. Indexing that flat list by this layer's
    #' position among line layers therefore returned one selector for a
    #' three-curve layer as soon as a smooth sat beside it, and the
    #' frontend's multiline trace refuses a selector list whose length does
    #' not equal the series count -- so the layer lost highlighting
    #' entirely rather than mis-aiming it.
    #'
    #' This resolves THIS layer's own grob first and then enumerates the
    #' curves inside it, emitting one selector per curve. When the curves
    #' cannot be lined up with the series, no selector is emitted: a caller
    #' can tell an absent selector apart from a wrong one, a user cannot.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @param built Built plot data (optional)
    #' @param n_series Number of series \code{extract_data()} produced, or
    #'   NULL to derive it from the built layer data
    #' @return List of selectors for each series
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL,
                                  built = NULL, n_series = NULL) {
      if (is.null(panel_ctx) || is.null(gt)) {
        if (!is.null(grob_id)) {
          # For faceted plots: use provided grob ID with .1.1 suffix
          # (gridSVG adds this)
          full_grob_id <- paste0(grob_id, ".1.1")
          escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
          return(list(paste0("#", escaped_grob_id)))
        }
        if (is.null(gt)) {
          gt <- ggplot2::ggplotGrob(plot)
        }
        # Without a gtable to scope it to, a panel context cannot be resolved.
        panel_ctx <- NULL
      }

      panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
      if (is.null(panel_grob)) {
        return(list())
      }

      if (is.null(n_series)) {
        n_series <- self$series_count(plot, built, panel_ctx)
      }

      selectors <- self$curve_selectors(plot, panel_grob, n_series)
      if (is.null(selectors)) {
        return(list())
      }
      selectors
    },

    #' @description Number of series this layer draws in the given panel.
    #'
    #' Never throws: selector generation has to degrade gracefully for
    #' inputs \code{extract_data()} would reject.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @return Number of series, at least 1
    series_count = function(plot, built = NULL, panel_ctx = NULL) {
      tryCatch(
        {
          if (is.null(built)) {
            built <- ggplot2::ggplot_build(plot)
          }
          layer_data <- built$data[[self$layer_info$index]]
          panel_id <- if (!is.null(panel_ctx)) panel_ctx$panel_id else NULL
          if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
            layer_data <- layer_data[layer_data$PANEL == panel_id, , drop = FALSE]
          }
          if (!("group" %in% names(layer_data))) {
            return(1L)
          }
          max(1L, length(unique(layer_data$group)))
        },
        error = function(e) 1L
      )
    },

    #' @description Selectors for the curves inside this layer's own grob.
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @param n_series Number of series the layer produced
    #' @return List of selectors, or NULL when the grob does not line up
    #'   with the series
    curve_selectors = function(plot, panel_grob, n_series) {
      grob <- self$find_layer_polyline_grob(plot, panel_grob)
      if (is.null(grob)) {
        return(NULL)
      }
      if (!identical(as.integer(self$polyline_curve_count(grob)), as.integer(n_series))) {
        return(NULL)
      }
      base_id <- gsub("^GRID\\.polyline\\.", "", grob$name)
      self$generate_multiline_selectors(base_id, n_series)
    },

    #' @description The polyline grob ggplot2 drew for THIS line layer.
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @return The matching grob, or NULL
    find_layer_polyline_grob = function(plot, panel_grob) {
      candidates <- self$layer_polyline_grobs(plot, panel_grob)
      if (length(candidates) == 0L) {
        return(NULL)
      }
      position <- self$line_layer_position(plot)
      if (!is.null(position)) {
        if (position > length(candidates)) {
          return(NULL)
        }
        return(candidates[[position]])
      }
      if (length(candidates) == 1L) candidates[[1]] else NULL
    },

    #' @description Panel polylines that a line layer could have drawn.
    #'
    #' \code{GeomPath$draw_panel()} returns a bare \code{polylineGrob}, so a
    #' line layer's grob carries grid's auto-generated
    #' \code{GRID.polyline.N} name with no geom prefix to match on -- only
    #' its draw-order position identifies it. Layers that DO name their grob
    #' tree after their geom (\code{geom_smooth.gTree.N}) are skipped whole
    #' via \code{geom_grob_prefix()}, the same helper the smooth processor
    #' uses to scope itself to its own tree; without that, the smooth's
    #' three curves are counted as line-layer polylines and shift every
    #' position by three. Panel grid lines are named after the theme element
    #' (\code{panel.grid.major.x..polyline.N}) and so never match.
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @return List of grobs in draw order
    layer_polyline_grobs = function(plot, panel_grob) {
      skip <- self$other_geom_grob_prefixes(plot)
      out <- list()
      collect <- function(grob) {
        name <- grob$name
        belongs_to_other_layer <- !is.null(name) && length(skip) > 0L &&
          any(startsWith(name, paste0(skip, ".")))
        if (belongs_to_other_layer) {
          # Another layer's tree: a match is the whole layer, do not descend.
          return(invisible(NULL))
        }
        if (!is.null(name) && grepl("^GRID\\.polyline\\.\\d+$", name)) {
          out[[length(out) + 1L]] <<- grob
        }
        if (inherits(grob, "gTree")) {
          for (child in grob$children) collect(child)
        }
        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) collect(grob[[i]])
        }
        invisible(NULL)
      }
      collect(panel_grob)
      out
    },

    #' @description Grob-name prefixes belonging to the plot's OTHER geoms.
    #'
    #' This layer's own prefix is excluded so that a second layer sharing
    #' the geom (two \code{geom_line()} calls) is still walked.
    #'
    #' @param plot The ggplot2 object
    #' @return Character vector of prefixes, possibly empty
    other_geom_grob_prefixes = function(plot) {
      prefix_of <- function(layer) {
        tryCatch(geom_grob_prefix(layer$geom), error = function(e) NA_character_)
      }
      own <- prefix_of(plot$layers[[self$get_layer_index()]])
      prefixes <- vapply(plot$layers, prefix_of, character(1))
      prefixes <- unique(prefixes[!is.na(prefixes)])
      if (!is.na(own)) {
        prefixes <- setdiff(prefixes, own)
      }
      prefixes
    },

    #' @description Number of separate curves a polyline grob draws.
    #'
    #' \code{polylineGrob()} splits one grob into several drawn lines via
    #' \code{id} / \code{id.lengths}; gridSVG renders each as its own SVG
    #' element suffixed \code{.1.<k>}.
    #'
    #' @param grob A polyline grob
    #' @return Integer count, at least 1
    polyline_curve_count = function(grob) {
      if (!is.null(grob$id.lengths)) {
        return(length(grob$id.lengths))
      }
      if (!is.null(grob$id)) {
        return(length(unique(grob$id)))
      }
      1L
    },

    #' @description Generate selectors for multiline plots using actual structure
    #' @param base_id The base ID from the grob (e.g., "61")
    #' @param num_series Number of series
    #' @return List of selectors
    generate_multiline_selectors = function(base_id, num_series) {
      selectors <- list()

      # Use the actual structure discovered: GRID.polyline.{base_id}.1.{series_index}
      for (i in 1:num_series) {
        # Format: #GRID\.polyline\.{base_id}\.1\.{series_index}
        escaped_id <- gsub("\\.", "\\\\.", paste0("GRID.polyline.", base_id, ".1.", i))
        selector <- paste0("#", escaped_id)
        selectors[[i]] <- selector
      }

      selectors
    },

    #' @description Generate selector for single line plot
    #' @param base_id The base ID from the grob
    #' @return List with single selector
    generate_single_line_selector = function(base_id) {
      escaped_id <- gsub("\\.", "\\\\.", paste0("GRID.polyline.", base_id, ".1.1"))
      selector <- paste0("#", escaped_id)
      list(selector)
    },

    #' @description Position of this layer among the polyline-producing layers.
    #'
    #' Delegates to `polyline_layer_position()`, which counts both "line" and
    #' "step" layers. `layer_polyline_grobs()` skips only the layers that name
    #' their grob tree after their geom, and `GeomStep` draws through
    #' `GeomPath$draw_panel()` — a bare `polylineGrob` — so a `geom_step()`
    #' sits in that candidate list exactly as a `geom_line()` does. Counting
    #' only "line" layers would therefore index the wrong polyline for *both*
    #' layers of a plot that combines the two.
    #'
    #' @param plot The ggplot2 object
    #' @return The 1-based position, or NULL if registry-based detection fails
    #' @keywords internal
    line_layer_position = function(plot) {
      polyline_layer_position(plot, self$layer_info$index)
    },

    #' @description Find the main polyline grob (GRID.polyline.XX)
    #' @param gt The gtable to search
    #' @return The main polyline grob or NULL
    find_main_polyline_grob = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        return(NULL)
      }

      panel_grob <- gt$grobs[[panel_index]]

      if (!inherits(panel_grob, "gTree")) {
        return(NULL)
      }

      # Search for the main GRID.polyline grob
      find_main_polyline_recursive <- function(grob) {
        if (!is.null(grob$name) && grepl("^GRID\\.polyline\\.\\d+$", grob$name)) {
          return(grob)
        }

        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            result <- find_main_polyline_recursive(grob[[i]])
            if (!is.null(result)) {
              return(result)
            }
          }
        }

        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            result <- find_main_polyline_recursive(grob$children[[i]])
            if (!is.null(result)) {
              return(result)
            }
          }
        }

        NULL
      }

      find_main_polyline_recursive(panel_grob)
    },

    #' @description Check if layer needs reordering
    #' @return FALSE (line plots typically don't need reordering)
    needs_reordering = function() {
      FALSE
    }
  ),
  private = list(
    last_result = NULL
  )
)
