#' Bar Layer Processor
#'
#' Processes bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2BarLayerProcessor <- R6::R6Class(
  "Ggplot2BarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the layer: read its bars, selectors and orientation from the built plot
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List describing the layer for the MAIDR payload
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      data <- self$extract_data(plot, built, panel_id)
      selectors <- self$generate_selectors(plot, gt, grob_id, panel_ctx)
      # Asked once, and both the key and the layout it decides are set from
      # the one answer -- they describe the same fact and could not be allowed
      # to disagree.
      horizontal <- self$is_flipped(plot, built)
      result <- list(
        data = if (horizontal) self$swap_point_axes(data) else data,
        selectors = selectors,
        orientation = if (horizontal) "horz" else "vert",
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_layer_axes(plot, layout)
      )

      # A bar drawn as a stack of rects is one bar to read, so its highlight
      # has to cover the stack: the rects are named by a selector matching
      # one rect per segment, which is more elements than bars and leaves
      # maidr.js nothing to highlight. The export draws an invisible rect over
      # each stack (`outline_bar_stacks()`), and the selector names those.
      stacks <- self$stack_rows(plot, built, panel_id)
      if (!is.null(stacks)) {
        names <- self$rect_grob_names(plot, gt, panel_ctx)
        if (length(names) == 1L) {
          result$selectors <- list(bar_stack_selector(names))
          result$.bar_stacks <- list(grob = names, bars = stacks)
        }
      }
      result
    },
    #' @description Is this layer's category axis `y` rather than `x`?
    #'
    #' `ggplot(df, aes(y = g, x = n)) + geom_col()` is the ordinary spelling of
    #' a horizontal bar chart, and `ggplot_build()` marks it `flipped_aes` and
    #' swaps which computed column holds what. Everything below reads `x` as
    #' the category and `y` as the measure, so on a flipped layer it picked up
    #' exactly the wrong pair: `apple/banana/cherry` at `30/70/50` came out as
    #' category `"30"` with value `1`, category `"50"` with value `3` and
    #' category `"70"` with value `2` -- the labels gone, the values replaced
    #' by factor codes, and the rows resorted by the measure (#162).
    #'
    #' `coord_flip()` is not this. It rotates the coordinate system and leaves
    #' `flipped_aes` alone, so its data layout is genuinely unflipped, and it
    #' is reported `vert` today. That question spans every processor.
    #'
    #' Should it ever be answered here, the key and the point layout have to
    #' move together: `"horz"` and the vertical `x = category, y = measure`
    #' pairing is precisely the combination #184 was about, and a
    #' `coord_flip()` chart currently reads correctly only because both halves
    #' are left in their vertical form. That is what `swap_point_axes()`
    #' being driven from this same answer is for.
    #'
    #' @param plot The ggplot2 object.
    #' @param built Its `ggplot_build()` result, when the caller has one.
    #' @return `TRUE` when the category runs up the y axis.
    is_flipped = function(plot, built = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      self$is_flipped_layer(built)
    },
    #' @description Exchange a plot's x and y aesthetics
    #'
    #' Returns a copy: the mapping is only read to recover the category's
    #' column name, and the caller's plot is still wanted unswapped for
    #' selectors and axis labels.
    #'
    #' The layer is copied too. A ggplot2 layer is a ggproto object, which
    #' is an environment, so assigning into `plot$layers[[i]]$mapping`
    #' wrote through to the caller's plot: after one read a horizontal
    #' `geom_col(aes(y = g, x = n))` was a vertical chart, for the render
    #' and for the user. The swapped mapping goes on a child object that
    #' inherits everything else from the layer, so the layer itself is
    #' never written.
    #'
    #' @param plot The ggplot2 object.
    #' @return A copy whose plot-level and layer-level x/y mappings are swapped.
    unflip_mapping = function(plot) {
      swap <- function(mapping) {
        if (is.null(mapping)) {
          return(mapping)
        }
        held_x <- mapping$x
        mapping$x <- mapping$y
        mapping$y <- held_x
        mapping
      }
      plot$mapping <- swap(plot$mapping)
      layer_index <- self$get_layer_index()
      if (layer_index <= length(plot$layers)) {
        layer <- plot$layers[[layer_index]]
        plot$layers[[layer_index]] <- ggplot2::ggproto(
          NULL, layer,
          mapping = swap(layer$mapping)
        )
      }
      plot
    },
    #' @description Whether the plot data must be reordered before drawing, so the emitted order
    #'   matches the drawn rects
    #' @return TRUE
    needs_reordering = function() {
      TRUE
    },
    #' @description Reorder the plot data by category so the emitted rows match the drawn rects
    #' @param data The data frame ggplot2 will draw from
    #' @param plot The ggplot2 object
    #' @return The reordered data frame
    reorder_layer_data = function(data, plot) {
      # Sorted by the *category*, which is the y mapping on a flipped layer.
      # Sorting by x there ordered the rows by the measure, so the emitted
      # order stopped matching the drawn rects as well.
      plot <- if (self$is_flipped(plot)) self$unflip_mapping(plot) else plot
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[self$get_layer_index()]]$mapping
      x_col <- NULL
      # Use as_label to handle complex expressions like factor(cyl)
      if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
        x_col <- rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot_mapping) && !is.null(plot_mapping$x)) {
        x_col <- rlang::as_label(plot_mapping$x)
      }
      # Only reorder if x_col is a simple column name that exists in data
      if (!is.null(x_col) && x_col %in% names(data)) {
        data[order(data[[x_col]]), , drop = FALSE]
      } else {
        data
      }
    },
    #' @description One point per bar, read from the built plot
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List of points
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_index <- self$get_layer_index()
      built_data <- built$data[[layer_index]]

      # Everything below reads `x` as the category and `y` as the measure.
      # A flipped layer holds them the other way round, so the columns, the
      # mapping the category's name is recovered from, and the panel scale its
      # labels come from are all exchanged here rather than each reader being
      # taught to ask (#162).
      flipped <- isTRUE(built_data$flipped_aes[1])
      if (flipped) {
        built_data <- self$unflip_columns(built_data)
        plot <- self$unflip_mapping(plot)
      }

      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, ]
      }

      # One row per bar from here on. A layer whose rows share a category is
      # drawn as one bar per category, each a stack of segments, and is read
      # as those bars (see `stack_rows()`).
      stacks <- self$stack_rows_of(plot, self$drawn_rows(built_data))
      if (!is.null(stacks)) {
        built_data <- self$collapse_stacks(self$drawn_rows(built_data), stacks)
      }

      # For faceted plots, get x values from built data or scale mapping
      if (!is.null(panel_id)) {
        # Use x values from built_data (contains actual axis values)
        # built_data$x contains the position indices, we need the actual axis values
        # Map this panel's built x positions through the panel's OWN
        # x-scale labels. Reading categories from the whole dataset
        # mislabels panels whose category set differs (free scales,
        # missing levels), since plot$data has no PANEL column.
        panel_number <- suppressWarnings(as.integer(as.character(panel_id)))
        panel_params_list <- built$layout$panel_params
        panel_params <- if (
          !is.na(panel_number) &&
            panel_number >= 1 &&
            panel_number <= length(panel_params_list)
        ) {
          panel_params_list[[panel_number]]
        } else {
          panel_params_list[[1]]
        }
        if (flipped) {
          panel_params <- self$unflip_panel_params(panel_params)
        }

        panel_labels <- NULL
        if (!is.null(panel_params$x) && !is.null(panel_params$x$get_labels)) {
          panel_labels <- panel_params$x$get_labels()
        } else if (!is.null(panel_params$x.labels)) {
          panel_labels <- panel_params$x.labels
        }

        # Break labels may only be INDEXED by the built positions on a
        # discrete scale, where those positions are 1..n category
        # numbers. On a continuous, Date or datetime scale the positions
        # ARE the values, so indexing invents labels (x = 4 picking up
        # the 4th break's label) or emits raw day counts for dates.
        if (self$panel_x_is_discrete(panel_params, built_data$x, panel_labels)) {
          x_values <- self$map_discrete_x(built_data$x, panel_labels)
        } else {
          x_values <- self$map_continuous_x(built_data$x, plot, layer_index)
        }
      } else {
        # Original logic for non-faceted plots
        plot_mapping <- plot$mapping
        layer_mapping <- plot$layers[[layer_index]]$mapping

        x_col <- NULL
        x_expr <- NULL
        if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
          x_expr <- layer_mapping$x
          x_col <- rlang::as_label(layer_mapping$x)
        } else if (!is.null(plot_mapping) && !is.null(plot_mapping$x)) {
          x_expr <- plot_mapping$x
          x_col <- rlang::as_label(plot_mapping$x)
        }

        original_data <- plot$data

        # For bar plots, the built_data has one row per bar (after stat computation).
        # We need per-row x values that match built_data rows.
        #
        # Strategy (in priority order):
        #   1. Read the original data column directly (preserves Date/POSIXct
        #      typing, formatted to ISO strings by `format_x_value()`).
        #   2. Extract the underlying column for wrapped expressions like
        #      `factor(cyl)`.
        #   3. Fall back to the x-scale's break labels from `panel_params`
        #      (covers stat="count" with non-column x mappings).
        #   4. Last resort: row indices.
        #
        # Note: `panel_params$x$get_labels()` returns formatted axis-tick
        # labels (e.g. "Dec 25", "Jan 01" for Date axes). It must NOT be the
        # primary path or per-row dates degrade to sparse axis-break labels.
        x_values <- NULL

        # 1. Primary: per-row x values from the original data column.
        if (!is.null(x_col) && x_col %in% names(original_data)) {
          x_values <- sort(unique(original_data[[x_col]]))
        }

        # 2. Extract column from expression like factor(cyl).
        if (is.null(x_values) && !is.null(x_expr)) {
          expr_str <- rlang::as_label(x_expr)
          match <- regmatches(expr_str, regexec("^(?:factor|as\\.factor|as\\.character)\\(([^)]+)\\)$", expr_str, perl = TRUE))
          if (length(match[[1]]) > 1) {
            base_col <- match[[1]][2]
            if (base_col %in% names(original_data)) {
              x_values <- sort(unique(original_data[[base_col]]))
            }
          }
        }

        # 3. Fall back to x-scale break labels.
        if (is.null(x_values) && !is.null(built)) {
          panel_params <- built$layout$panel_params[[1]]
          if (flipped) {
            panel_params <- self$unflip_panel_params(panel_params)
          }
          if (!is.null(panel_params$x) && !is.null(panel_params$x$get_labels)) {
            scale_labels <- panel_params$x$get_labels()
            scale_labels <- scale_labels[!is.na(scale_labels)]
            if (length(scale_labels) > 0) {
              x_values <- scale_labels
            }
          } else if (!is.null(panel_params$x.labels)) {
            x_values <- panel_params$x.labels
          }
        }

        # 4. Last resort: row indices.
        if (is.null(x_values)) {
          x_values <- seq_len(nrow(built_data))
        }

        # Bars read from stacks are in the order they are drawn along the
        # axis, which on a discrete scale is the order of its limits rather
        # than of the column's sorted values: under
        # `scale_x_discrete(limits = c("8", "6", "4"))` the stack drawn
        # first, 8's, was read as "4". Each is named by the limit at its
        # position.
        if (!is.null(stacks)) {
          named <- self$discrete_limits_at(built, built_data$x, flipped)
          if (!is.null(named)) {
            x_values <- named
          }
        }
      }

      data_points <- list()
      n <- min(nrow(built_data), length(x_values))

      for (i in seq_len(n)) {
        point <- list(
          x = self$format_x_value(x_values[i]),
          y = built_data$y[i]
        )
        data_points[[i]] <- point
      }

      # If built_data has more rows than x labels, append with NA x labels
      if (nrow(built_data) > n) {
        for (i in seq.int(n + 1, nrow(built_data))) {
          data_points[[i]] <- list(
            x = NA_character_,
            y = built_data$y[i]
          )
        }
      }

      data_points
    },

    #' @description The rows each bar is drawn from, when bars are stacks
    #'
    #' `ggplot(mtcars, aes(factor(cyl), mpg)) + geom_bar(stat = "identity")`
    #' draws three bars, each a stack of one rect per car: `geom_bar()` and
    #' `geom_col()` stack the rows that share a category by default, and with
    #' nothing mapped to `fill` the segments are drawn alike, so the page shows
    #' one bar per category, as tall as its segments together. ggplot2 keeps
    #' one built row per segment, which the reading took for one bar each:
    #' 32 bars, the first three labelled with categories that belonged to
    #' other rows, the rest with none, every value the running total of its
    #' stack.
    #'
    #' A layer mapping `fill` is a stacked bar chart and never reaches this
    #' processor; a layer drawn with `position = "identity"` overlaps its rows
    #' rather than stacking them, and is left as it was.
    #'
    #' @param plot The ggplot2 object.
    #' @param built Its `ggplot_build()` result.
    #' @param panel_id Panel ID for faceted plots (optional).
    #' @return `NULL` when every bar is one row; otherwise a list with one
    #'   integer vector per bar, in the order the bars are read (along the
    #'   category axis), holding the positions of its rows among the panel's
    #'   drawn rows (`drawn_rows()`) -- which are also the positions of its
    #'   rects in the panel's rect grob, drawn in row order.
    stack_rows = function(plot, built, panel_id = NULL) {
      rows <- self$get_layer_built_data(built, panel_id)
      if (is.null(rows)) {
        return(NULL)
      }
      if (isTRUE(rows$flipped_aes[1])) {
        rows <- self$unflip_columns(rows)
      }
      self$stack_rows_of(plot, self$drawn_rows(rows))
    },

    #' @description The rows of a panel that ggplot2 draws a rect for
    #'
    #' A row missing its position or extent is drawn as no rect. ggplot2
    #' 3.4.4 drops such a row while stacking ("Removed 1 rows containing
    #' missing values (`position_stack()`)"); left among the rows by a
    #' release that drops it only as it draws, it would put every later rect
    #' of the panel one place out from the row it was read from.
    #'
    #' @param rows The layer's built rows for one panel, the category in `x`.
    #' @return The rows with a finite `x`, `ymin` and `ymax`.
    drawn_rows = function(rows) {
      finite <- function(column) {
        if (is.null(column)) rep(TRUE, nrow(rows)) else is.finite(column)
      }
      rows[finite(rows$x) & finite(rows$ymin) & finite(rows$ymax), , drop = FALSE]
    },

    #' @description `stack_rows()` on rows already read
    #' @param plot The ggplot2 object.
    #' @param rows The layer's built rows for one panel, the category in `x`.
    #' @return As `stack_rows()`.
    stack_rows_of = function(plot, rows) {
      layer <- self$get_own_layer(plot)
      if (is.null(layer) || !inherits(layer$position, "PositionStack")) {
        return(NULL)
      }
      if (is.null(rows) || nrow(rows) < 2L || !anyDuplicated(rows$x)) {
        return(NULL)
      }
      positions <- sort(unique(rows$x))
      lapply(positions, function(at) which(rows$x == at))
    },

    #' @description One row per bar, from rows that stack
    #'
    #' A bar's value is the sum of its segments, which is where the top of an
    #' all-positive stack is drawn. ggplot2 stacks negative values down from
    #' zero, keeping each segment's `ymin` below its `ymax`, so a segment below
    #' zero counts negatively.
    #'
    #' @param rows The layer's built rows for one panel, the category in `x`.
    #' @param stacks The rows of each bar, from `stack_rows()`.
    #' @return A data frame with one row per bar, in the order of `stacks`.
    collapse_stacks = function(rows, stacks) {
      bars <- rows[vapply(stacks, function(at) at[1], integer(1)), , drop = FALSE]
      bars$y <- vapply(stacks, function(at) {
        segment <- rows[at, , drop = FALSE]
        if (!all(c("ymin", "ymax") %in% names(segment))) {
          return(as.numeric(segment$y[nrow(segment)]))
        }
        height <- segment$ymax - segment$ymin
        sum(ifelse(segment$ymin < 0, -height, height), na.rm = TRUE)
      }, numeric(1))
      bars
    },

    #' @description The limits of a discrete category scale at bar positions
    #'
    #' Read from the scale the layout trained (`panel_scales_x`), as the
    #' plot's own copy of a position scale is never trained and answers
    #' `c(0, 1)` for its limits.
    #'
    #' @param built The plot's `ggplot_build()` result.
    #' @param positions The bars' built positions along the category axis.
    #' @param flipped Whether the bars are horizontal, their categories on y.
    #' @return The limit at each position, or `NULL` when the category scale
    #'   is not discrete or a position names no limit.
    discrete_limits_at = function(built, positions, flipped = FALSE) {
      scale <- tryCatch(
        if (isTRUE(flipped)) built$layout$panel_scales_y[[1]] else built$layout$panel_scales_x[[1]],
        error = function(e) NULL
      )
      if (is.null(scale) || !isTRUE(tryCatch(scale$is_discrete(), error = function(e) FALSE))) {
        return(NULL)
      }
      limits <- tryCatch(as.character(scale$get_limits()), error = function(e) NULL)
      at <- suppressWarnings(as.integer(round(as.numeric(positions))))
      if (length(limits) == 0L || length(at) == 0L || anyNA(at) ||
            any(at < 1L | at > length(limits))) {
        return(NULL)
      }
      limits[at]
    },

    #' @description Format an x-axis value as character.
    #'
    #' Date / POSIXct / POSIXlt values are formatted via `format()` so that a
    #' `Date` column emits ISO date strings ("2024-01-02") rather than the
    #' default scale-tick labels ("Jan 02"). All other types use
    #' `as.character()`. Mirrors `Ggplot2CandlestickProcessor$format_x_value()`
    #' so candle and bar layers from the same Date column align string-wise.
    #' @param x The value to format
    #' @return Character vector
    format_x_value = function(x) {
      if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) {
        return(format(x))
      }
      as.character(x)
    },

    #' @description Does this panel draw x on a discrete scale?
    #'
    #' Only a discrete scale numbers its built positions 1..n, which is what
    #' makes indexing the break labels with them legitimate.
    #'
    #' @param panel_params This panel's entry from `built$layout$panel_params`
    #' @param x_pos Built x positions for this panel
    #' @param panel_labels This panel's x break labels, or NULL
    #' @return TRUE for a discrete x scale
    panel_x_is_discrete = function(panel_params, x_pos, panel_labels) {
      if (!is.numeric(x_pos) || length(x_pos) == 0) {
        return(FALSE)
      }
      if (!is.null(panel_params$x) && is.function(panel_params$x$is_discrete)) {
        discrete <- tryCatch(
          isTRUE(panel_params$x$is_discrete()),
          error = function(e) NULL
        )
        if (!is.null(discrete)) {
          return(discrete)
        }
      }
      # Flattened panel_params (older ggplot2) expose no scale object, so
      # fall back to the shape of the positions: whole numbers covered by
      # the break labels.
      !is.null(panel_labels) &&
        !anyNA(x_pos) &&
        all(abs(x_pos - round(x_pos)) < 1e-6) &&
        all(x_pos >= 1 & x_pos <= length(panel_labels))
    },

    #' @description Label discrete built positions with this panel's breaks.
    #'
    #' @param x_pos Built x positions for this panel
    #' @param panel_labels This panel's x break labels, or NULL
    #' @return Character vector of x labels
    map_discrete_x = function(x_pos, panel_labels) {
      x_values <- as.character(x_pos)
      if (is.null(panel_labels) || !is.numeric(x_pos)) {
        return(x_values)
      }
      idx <- as.integer(round(x_pos))
      idx[is.na(idx) | idx < 1 | idx > length(panel_labels)] <- NA_integer_
      labelled <- as.character(panel_labels[idx])
      hit <- !is.na(labelled)
      x_values[hit] <- labelled[hit]
      x_values
    },

    #' @description Recover user-facing x values for a non-discrete scale.
    #'
    #' Built positions on a continuous, Date or datetime scale already are
    #' the values, but a Date arrives as a day count. Matching them back to
    #' the mapped column restores the original typing so `format_x_value()`
    #' can emit "2024-01-02" rather than "19724". Mirrors the same recovery
    #' in `Ggplot2LineLayerProcessor`.
    #'
    #' @param x_pos Built x positions for this panel
    #' @param plot The ggplot object
    #' @param layer_index Index of this layer within the plot
    #' @return Character vector of x labels
    map_continuous_x = function(x_pos, plot, layer_index) {
      x_values <- as.character(x_pos)
      if (!is.numeric(x_pos)) {
        return(x_values)
      }

      layer_mapping <- plot$layers[[layer_index]]$mapping
      x_col <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
        x_col <- rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot$mapping) && !is.null(plot$mapping$x)) {
        x_col <- rlang::as_label(plot$mapping$x)
      }
      has_column <- !is.null(x_col) &&
        is.data.frame(plot$data) &&
        x_col %in% names(plot$data)
      if (!has_column) {
        return(x_values)
      }

      original <- sort(unique(plot$data[[x_col]]))
      numeric_repr <- suppressWarnings(as.numeric(original))
      if (length(numeric_repr) == 0 || anyNA(numeric_repr)) {
        return(x_values)
      }

      match_idx <- match(round(as.numeric(x_pos), 6), round(numeric_repr, 6))
      hit <- !is.na(match_idx)
      if (any(hit)) {
        x_values[hit] <- self$format_x_value(original[match_idx[hit]])
      }
      x_values
    },

    #' @description Selectors for the layer's rects
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      if (!is.null(grob_id) && (is.null(panel_ctx) || is.null(gt))) {
        # For faceted plots: use provided grob ID with .1 suffix (gridSVG adds this)
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        return(list(paste0("#", escaped_grob_id, " rect")))
      }

      lapply(self$rect_grob_names(plot, gt, panel_ctx), function(name) {
        svg_id <- paste0(name, ".1")
        escaped <- gsub("\\.", "\\\\.", svg_id)
        paste0("#", escaped, " rect")
      })
    },

    #' @description The names of the rect grobs this layer drew
    #'
    #' Searched in the panel the context names when there is one, and in the
    #' plot's only panel otherwise.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional; built from `plot` when absent)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return Character vector of rect grob names, empty when none is found
    rect_grob_names = function(plot, gt = NULL, panel_ctx = NULL) {
      if (!is.null(panel_ctx) && !is.null(gt)) {
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
      } else {
        if (is.null(gt)) {
          gt <- ggplot2::ggplotGrob(plot)
        }
        panel_index <- which(gt$layout$name == "panel")
        panel_grob <- if (length(panel_index) == 0) NULL else gt$grobs[[panel_index[1]]]
      }
      if (is.null(panel_grob) || !inherits(panel_grob, "gTree")) {
        return(character(0))
      }

      find_rect_names <- function(grob) {
        names <- character(0)
        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          names <- c(names, grob$name)
        }
        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            names <- c(names, find_rect_names(grob[[i]]))
          }
        }
        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            names <- c(names, find_rect_names(grob$children[[i]]))
          }
        }
        names
      }

      self$own_rect_names(panel_grob, find_rect_names)
    },

    #' @description The rect grob names under this layer's own slot, or under the whole panel
    #'
    #' A panel holds one \code{geom_rect.rect} grob per bar layer, so a plot
    #' that overlays two \code{geom_col()}s -- a total behind a highlighted
    #' part is the usual reason -- has two, and a search over the panel
    #' returns both to each layer. Its selectors then address every bar in
    #' the panel: the frontend finds twice the marks it has points for and
    #' highlights nothing, on both layers. So the search is scoped to the
    #' layer's own slot (see \code{find_layer_slot_grob()}): whatever the
    #' geom drew there, a bare rect grob or a tree wrapping one, and nothing
    #' when it drew no rects here at all. The panel-wide search remains only
    #' for a panel whose layout the slot cannot be read from.
    #'
    #' @param panel_grob The panel grob
    #' @param find_rect_names Function collecting every rect grob name under a grob
    #' @return Character vector of rect grob names
    own_rect_names = function(panel_grob, find_rect_names) {
      slot <- find_layer_slot_grob(panel_grob, self$get_layer_index())
      if (!is.null(slot)) {
        return(find_rect_names(slot))
      }
      find_rect_names(panel_grob)
    }
  )
)
