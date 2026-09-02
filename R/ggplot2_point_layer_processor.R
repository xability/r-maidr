#' Point Layer Processor
#'
#' @description
#' Processes scatter plot layers (geom_point) to extract point data and generate selectors
#' for individual points in the SVG structure.
#'
#' @keywords internal
Ggplot2PointLayerProcessor <- R6::R6Class(
  "Ggplot2PointLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the point layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with data and selectors
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      extracted_data <- self$extract_data(plot, built, panel_id)

      selectors <- self$generate_selectors(plot, gt, grob_id, panel_ctx)

      axes <- self$extract_axes_labels(plot, built, panel_id)

      # For point plots, data is directly the array of points
      data <- extracted_data

      list(
        data = data,
        selectors = selectors,
        axes = axes
      )
    },

    #' @description Extract axis information from the plot
    #'
    #' Returns per-axis objects with label and optional grid navigation fields
    #' (min, max, tickStep). Grid fields are only included when they can be
    #' successfully extracted from the built plot scales.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with x and y per-axis objects
    extract_axes_labels = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      # --- Extract labels ---
      x_label <- ""
      y_label <- ""

      if (!is.null(built$plot$labels$x)) {
        x_label <- built$plot$labels$x
      } else if (!is.null(plot$labels$x)) {
        x_label <- plot$labels$x
      } else {
        if (!is.null(plot$mapping$x)) {
          x_label <- rlang::as_label(plot$mapping$x)
        }
      }

      if (!is.null(built$plot$labels$y)) {
        y_label <- built$plot$labels$y
      } else if (!is.null(plot$labels$y)) {
        y_label <- plot$labels$y
      } else {
        if (!is.null(plot$mapping$y)) {
          y_label <- rlang::as_label(plot$mapping$y)
        }
      }

      # Build per-axis objects (always include label)
      x_axis <- list(label = x_label)
      y_axis <- list(label = y_label)

      # --- Optionally extract grid navigation fields (min, max, tickStep) ---
      x_grid <- self$extract_axis_grid_info(built, "x", panel_id)
      y_grid <- self$extract_axis_grid_info(built, "y", panel_id)

      if (!is.null(x_grid)) {
        x_axis$min <- x_grid$min
        x_axis$max <- x_grid$max
        x_axis$tickStep <- x_grid$tickStep
      }

      if (!is.null(y_grid)) {
        y_axis$min <- y_grid$min
        y_axis$max <- y_grid$max
        y_axis$tickStep <- y_grid$tickStep
      }

      list(x = x_axis, y = y_axis)
    },

    #' @description Extract grid navigation info (min, max, tickStep) for a single axis
    #'
    #' Delegates to \code{axis_grid_info()}, which is where the reading now
    #' lives: the rug processor needs the same answer for the axis its ticks
    #' stand on, and one grid rule read two ways is how the two would drift.
    #' Kept as a method so this class's own callers are unchanged.
    #'
    #' @param built Built plot data
    #' @param axis Character, either "x" or "y"
    #' @param panel_id Panel index for faceted plots (optional, defaults to 1)
    #' @return List with min, max, tickStep or NULL if extraction fails
    extract_axis_grid_info = function(built, axis = "x", panel_id = NULL) {
      axis_grid_info(built, axis, panel_id)
    },

    #' @description Extract data from point layer
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with points array and color information
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_index <- self$get_layer_index()

      # Put the points back where the data puts them. `geom_jitter()` and
      # `position_jitter()` displace every point at random so overlapping
      # observations stay separable, and the displaced position is what the
      # built frame carries -- on both axes, so the number announced as the
      # measurement is not the measurement (#174). A no-op for every other
      # layer; see `undisplace_layer()` for why it is a rebuild rather than an
      # attempt to subtract the offset back out.
      full_layer_data <- undisplace_layer(plot, built$data[[layer_index]], layer_index)
      layer_data <- full_layer_data

      # Remember which rows this panel kept. The built rows correspond 1:1
      # to the original data rows, so the same indices resolve mapped
      # aesthetics (colour, group) back to their source values below.
      panel_rows <- seq_len(nrow(full_layer_data))

      if (!is.null(panel_id) && "PANEL" %in% names(full_layer_data)) {
        panel_rows <- which(full_layer_data$PANEL == panel_id)
        layer_data <- full_layer_data[panel_rows, , drop = FALSE]
      }

      # Keep only the samples ggplot2 actually drew. It discards one whose
      # position or value is missing before rendering, and says so --
      # "Removed 1 rows containing missing values (`geom_point()`)" -- so
      # emitting it leaves `data` longer than the marks the selector resolves
      # to. Measured on four rows with one NA: 4 points emitted against 3
      # `<use>` elements, which pairs every sample from the gap onward with
      # the *next* observation's mark and leaves the last with none.
      #
      # A wrong highlight is worse than an absent point: it shows a reader a
      # mark that does not correspond to the value being announced, and
      # nothing in the output says so. `Ggplot2LineLayerProcessor` already
      # follows this rule, for the same reason, on the polyline's vertices
      # (#170).
      #
      # `panel_rows` is filtered in step because the aesthetic lookups below
      # index the original frame through it.
      drawn <- rep(TRUE, nrow(layer_data))
      for (aesthetic in c("x", "y")) {
        if (aesthetic %in% names(layer_data) &&
          is.numeric(layer_data[[aesthetic]])) {
          drawn <- drawn & is.finite(layer_data[[aesthetic]])
        }
      }
      if (any(!drawn)) {
        layer_data <- layer_data[drawn, , drop = FALSE]
        panel_rows <- panel_rows[drawn]
      }

      # The position stays a number, and the name it stands for travels
      # beside it in `xLabel`.
      #
      # It did not always. The faceted path relabelled the position, so the
      # same chart emitted two different shapes depending on whether it was
      # facetted::
      #
      #     ggplot(df, aes(g, v)) + geom_jitter()                   x = 1
      #     ggplot(df, aes(g, v)) + geom_jitter() + facet_wrap(~f)   x = "a"
      #
      # By `layer_data$x <- x_values[layer_data$x]`, which indexed the panel's
      # sorted category values by the drawn position. #178 names a different
      # cause -- a scale-mapping helper that in fact never ran, because no
      # caller ever passed a mapping. That plumbing has since been removed
      # (#181); this is the code that did it.
      #
      # `ScatterPoint.x` is typed `number` in the grammar, and `ScatterTrace`
      # does arithmetic on it: it sorts with `a.x - b.x`, indexes columns by
      # the value, and resolves the nearest point with `Math.hypot`. A string
      # makes the subtraction `NaN`, and a comparator returning `NaN` leaves
      # `Array.prototype.sort` with no ordering to apply -- so the points stay
      # in input order rather than the x order every downstream index assumes,
      # and `findNearestPoint` has no nearest point to find. The faceted chart
      # announced the right name while handing the core a payload it could not
      # sort, index or highlight against (#178).
      #
      # Removing the relabelling rather than converting it back is what makes
      # this a fix: `ScatterPoint.xLabel` exists as of xability/maidr#927 and
      # the emission below already fills it from `discrete_axis_labels()`, so
      # the name was never the half that had to displace the position.
      #
      # Scoped to this processor. `Ggplot2BarLayerProcessor` calls the same
      # helper and is right to: a bar's `x` is `string | number` in the
      # grammar, and a bar chart is navigated by category rather than by
      # distance, so nothing there subtracts one x from another.

      original_data <- plot$data

      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[layer_index]]$mapping

      # Determine x, y column names
      x_col <- if (!is.null(layer_mapping$x)) {
        rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot_mapping$x)) {
        rlang::as_label(plot_mapping$x)
      } else {
        names(original_data)[1]
      }

      y_col <- if (!is.null(layer_mapping$y)) {
        rlang::as_label(layer_mapping$y)
      } else if (!is.null(plot_mapping$y)) {
        rlang::as_label(plot_mapping$y)
      } else {
        names(original_data)[2]
      }

      # Determine the colour aesthetic and the name it prints as
      color_quo <- layer_mapping$colour %||% layer_mapping$color %||%
        plot_mapping$colour %||% plot_mapping$color
      color_col <- if (!is.null(color_quo)) rlang::as_label(color_quo) else NULL

      # The mapped grouping variable (e.g. "Species") only exists in the
      # ORIGINAL data; built data carries the mapped hex codes in
      # `colour`. Compare against the UNFILTERED built rows: under faceting
      # `layer_data` holds one panel while `original_data` holds every row,
      # so comparing the two counts never matched and every faceted scatter
      # announced raw hex codes instead of category names.
      #
      # `colour = factor(cyl)` names no column, so the expression is
      # evaluated over the data the way ggplot2 evaluates it, and the level
      # each row was drawn with is announced rather than its hex code.
      color_values <- NULL
      if (!is.null(color_col)) {
        mapped <- if (color_col %in% names(original_data)) {
          original_data[[color_col]]
        } else {
          tryCatch(
            rlang::eval_tidy(color_quo, data = original_data),
            error = function(e) NULL
          )
        }
        if (
          length(mapped) == nrow(original_data) &&
            nrow(original_data) == nrow(full_layer_data)
        ) {
          color_values <- as.character(mapped)[panel_rows]
        } else if ("colour" %in% names(layer_data)) {
          color_values <- as.character(layer_data$colour)
        }
      }

      # Back into the space the reader sees. ggplot2 transforms before the
      # stat runs, so a `scale_x_log10()` chart's built x is log10 of the
      # value the axis prints -- announced straight through, a point at
      # $6,000 reads as 3.78 under the label "Price (USD)" (#158).
      #
      # Done here, at the emission, rather than to `layer_data` as a whole:
      # `scale_*_reverse()` negates, so a frame inverted earlier would order
      # rows opposite to the way they were drawn.
      announced_x <- untransform_positions(layer_data$x, built, "x", panel_id)
      announced_y <- untransform_positions(layer_data$y, built, "y", panel_id)

      # The name each position stands for, on whichever axis is discrete.
      # ggplot2 maps a discrete scale onto consecutive integers, so a point in
      # category "a" arrives as `x = 1` and was announced as the number -- "g
      # is 1" where the chart says "a". Both axes are asked, since a chart
      # turned on its side puts the categories on y.
      x_names <- discrete_axis_labels(built, "x", panel_id)
      y_names <- discrete_axis_labels(built, "y", panel_id)

      points <- list()
      for (i in seq_len(nrow(layer_data))) {
        point <- list(
          x = announced_x[i],
          y = announced_y[i]
        )

        x_label <- category_at(announced_x[i], x_names)
        if (!is.null(x_label)) {
          point$xLabel <- x_label
        }
        y_label <- category_at(announced_y[i], y_names)
        if (!is.null(y_label)) {
          point$yLabel <- y_label
        }

        if (!is.null(color_values)) {
          point$color <- color_values[i]
        }

        points[[i]] <- point
      }

      # For point plots, return the points array directly
      points
    },

    #' @description Generate selectors for point elements
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      if (!is.null(panel_ctx) && !is.null(gt)) {
        panel_grob <- self$find_panel_grob(gt, panel_ctx)
        if (is.null(panel_grob)) {
          return(list())
        }

        # Look for geom_point container(s) within this panel
        point_names <- c()
        find_points <- function(grob) {
          if (!is.null(grob$name) && grepl("geom_point\\.points", grob$name)) {
            point_names <<- c(point_names, grob$name)
          }
          if (inherits(grob, "gList")) {
            for (i in seq_along(grob)) {
              find_points(grob[[i]])
            }
          }
          if (inherits(grob, "gTree")) {
            for (i in seq_along(grob$children)) {
              find_points(grob$children[[i]])
            }
          }
        }
        find_points(panel_grob)
        if (length(point_names) == 0) {
          return(list())
        }
        selectors <- lapply(point_names, function(nm) {
          svg_id <- paste0(nm, ".1")
          escaped <- gsub("\\.", "\\\\.", svg_id)
          paste0("g#", escaped, " > use")
        })
        return(selectors)
      }

      if (!is.null(grob_id)) {
        # For faceted plots: use provided grob ID with .1 suffix (gridSVG adds this)
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        return(list(paste0("g#", escaped_grob_id, " > use")))
      } else {
        # For single plots: use existing logic
        if (is.null(gt)) {
          gt <- ggplot2::ggplotGrob(plot)
        }

        panel_grob <- self$find_panel_grob(gt)
        if (is.null(panel_grob)) {
          return(list())
        }

        # Look for geom_point elements
        point_children <- self$find_children_by_type(panel_grob, "geom_point")
        if (length(point_children) == 0) {
          return(list())
        }

        # Use the first geom_point container
        master_container <- point_children[1]
        svg_id <- paste0(master_container, ".1")
        escaped_id <- gsub("\\.", "\\\\.", svg_id)
        css_selector <- paste0("g#", escaped_id, " > use")

        list(css_selector)
      }
    },

    #' @description Find the panel grob this layer draws into
    #' @param gt The gtable to search
    #' @param panel_ctx Panel context for patchwork leaves and facets; NULL
    #'   for a single plot, where the panel is the cell literally named "panel"
    #' @return The panel grob or NULL
    find_panel_grob = function(gt, panel_ctx = NULL) {
      find_gtable_panel_grob(gt, panel_ctx)
    },

    #' @description Find children by type pattern
    #' @param grob The grob to search
    #' @param type_pattern Pattern to match
    #' @return List of matching children
    find_children_by_type = function(grob, type_pattern) {
      children <- list()

      if (inherits(grob, "gTree")) {
        for (i in seq_along(grob$children)) {
          child <- grob$children[[i]]
          if (!is.null(child$name) && grepl(type_pattern, child$name)) {
            children[[length(children) + 1]] <- child$name
          }
        }
      }

      children
    }
  )
)
