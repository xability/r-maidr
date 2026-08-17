#' ggplot2 Area Layer Processor
#'
#' Processes `geom_area()` into MAIDR's `area`, `stacked_area` and
#' `stacked_normalized_area` layers.
#'
#' Before this processor existed these layers fell through to
#' `Ggplot2UnknownLayerProcessor`, so an area chart carried no data at all.
#'
#' ## Why not read it as a line
#'
#' In a stacked area chart the band's **top edge** is a cumulative total while
#' the band's **height** is the series' own value. A line layer announces one
#' number per point with nothing to say which of those two it is, so the type
#' exists to keep them apart: MAIDR's area trace announces the series' value
#' and reports the running total beside it.
#'
#' ## The two traps in ggplot2's built data
#'
#' **`y` is not the value.** ggplot2 stacks by computing absolute band edges,
#' so `ymin`/`ymax` are the cumulative positions and `y` is the top edge. The
#' series' own value is `ymax - ymin`, and MAIDR sums the series itself to
#' reach the total. Emitting `y` would hand it a cumulative number to
#' accumulate again, announcing totals that grow with the number of series
#' rather than with the data.
#'
#' **Most of the rows are not data.** `geom_area()` defaults to
#' `stat = "align"`, which inserts interpolation vertices so the bands stack
#' cleanly and closes each polygon on the baseline. A four-point, two-series
#' chart produces twenty-four rows:
#'
#' ```
#'        x      y  ymin   ymax group align_padding
#'  1999.997  0.000 0.000  0.000     1          TRUE
#'  2000.000  5.000 2.000  5.000     1         FALSE
#'  2000.003  5.009 2.003  5.009     1         FALSE   <- not a data point
#'  2000.997  7.991 2.997  7.991     1         FALSE   <- not a data point
#' ```
#'
#' Read whole, a chart of four years announces twelve points per series,
#' including a reading of `5.009` at "year 2000.003" -- a value the data does
#' not hold at an x the chart does not have. `align_padding` does **not**
#' identify them: it marks only the two baseline-closing vertices.
#'
#' The rows that are data are those whose `x` the layer's own data carries,
#' which is verified to give the same answer as `stat = "identity"`.
#'
#' @keywords internal
Ggplot2AreaLayerProcessor <- R6::R6Class(
  "Ggplot2AreaLayerProcessor",
  inherit = Ggplot2LineLayerProcessor,
  public = list(
    #' @description Process the area layer.
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, axes and type
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

      layer_data <- self$get_layer_built_data(built, panel_id)
      series <- self$extract_series(built, layer_data, panel_id)

      axes <- self$extract_layer_axes(plot, layout)
      axes <- self$attach_fill_axis(plot, built, axes, panel_id)

      list(
        data = series,
        selectors = self$generate_selectors(plot, gt, panel_ctx, length(series)),
        title = if (!is.null(layout$title)) layout$title else "",
        axes = axes,
        type = self$resolve_area_type(plot, series)
      )
    },

    #' @description One selector per band, so navigation highlights a band.
    #'
    #' `geom_area` draws each series as its own `geom_ribbon.gTree` holding a
    #' filled `GRID.polygon`, which is the granularity the consumer wants:
    #' `AreaTrace` extends the line trace, whose multi-series highlight needs
    #' one selector per series and discards a list whose length disagrees.
    #'
    #' The polygon rather than the outline polyline each ribbon also draws:
    #' the band is the mark a reader is being pointed at, and outlining it
    #' would highlight a hairline around the shape instead of the shape.
    #'
    #' The existing curve machinery does not transfer.
    #' `Ggplot2LineLayerProcessor$curve_selectors()` counts curves inside one
    #' auto-named polyline grob, and `layer_polyline_grobs()` deliberately
    #' skips geom-named gTrees to avoid miscounting -- an area layer being
    #' exactly the shape that helper excludes.
    #'
    #' Emits nothing rather than a short or mispaired list, for the reason
    #' every processor here gives: the caller can tell an empty selector list
    #' apart from a wrong one, and a user cannot.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @param n_series How many bands the data reports
    #' @return A list of selectors, one per band, or an empty list
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL,
                                  n_series = 0L) {
      if (is.null(gt) || n_series < 1L) {
        return(list())
      }

      tree <- tryCatch(
        self$find_layer_grob_tree(plot, gt, panel_ctx),
        error = function(e) NULL
      )
      if (is.null(tree) || !inherits(tree, "gTree")) {
        return(list())
      }

      polygons <- self$band_polygon_names(tree)
      if (length(polygons) != n_series) {
        # A band the geom did not draw, or one it drew twice. Either way the
        # pairing between series and mark is no longer positional, and a
        # highlight that lands on the neighbouring band is worse than none.
        return(list())
      }

      lapply(polygons, function(name) {
        # gridSVG suffixes the grob's group with ".1" and puts the drawn
        # element inside it.
        paste0("#", gsub("\\.", "\\\\.", paste0(name, ".1")), " polygon")
      })
    },

    #' @description Names of the band polygon grobs inside a grob, in draw
    #' order, which is series order.
    #'
    #' Matches the auto-generated `GRID.polygon.N` name exactly rather than by
    #' prefix, so a theme element's own polygon -- named after the element,
    #' not after grid's counter -- cannot be collected as a band. Anchoring
    #' both ends is what keeps this from widening the way a `grepl` on a bare
    #' prefix would.
    #'
    #' @param grob A grob to walk
    #' @return Character vector of grob names
    band_polygon_names = function(grob) {
      out <- character(0)
      if (!is.null(grob$name) && grepl("^GRID\\.polygon\\.\\d+$", grob$name)) {
        out <- c(out, grob$name)
      }
      if (inherits(grob, "gTree")) {
        for (child in grob$children) {
          out <- c(out, self$band_polygon_names(child))
        }
      }
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          out <- c(out, self$band_polygon_names(grob[[i]]))
        }
      }
      out
    },

    #' @description Decide which of the three area types this layer is.
    #'
    #' `position = "fill"` rescales every column to a common height, so a
    #' band's height is its share of that column and every column totals 1 by
    #' construction. Reading that as a plain stacked area would announce the
    #' shares as if they were values and imply the columns have equal totals,
    #' which is the one thing a filled chart is drawn to deny -- the same
    #' distinction `stacked_normalized_bar` draws for bars.
    #'
    #' A single series has nothing stacked on it whatever its position, so it
    #' is a plain area: announcing a running total equal to the value at every
    #' point would be noise.
    #'
    #' @param plot The ggplot2 object
    #' @param series The emitted series
    #' @return One of "area", "stacked_area", "stacked_normalized_area"
    resolve_area_type = function(plot, series) {
      layer <- self$get_own_layer(plot)
      position <- if (is.null(layer)) NULL else class(layer$position)[1]

      if (identical(position, "PositionFill")) {
        return("stacked_normalized_area")
      }
      if (length(series) > 1) {
        return("stacked_area")
      }
      "area"
    },

    #' @description Build the MAIDR series for this layer.
    #'
    #' Emits each series' **own** value rather than the cumulative band top,
    #' because MAIDR's area trace sums the series to reach the running total
    #' and announces the two separately.
    #'
    #' @param built Built plot data
    #' @param layer_data This layer's computed rows
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of series, each a list of MAIDR points
    extract_series = function(built, layer_data, panel_id = NULL) {
      rows <- self$drop_alignment_vertices(built, layer_data)
      if (is.null(rows) || nrow(rows) == 0) {
        return(list())
      }

      group_col <- if ("group" %in% names(rows)) "group" else NULL
      groups <- if (is.null(group_col)) rep(1L, nrow(rows)) else rows[[group_col]]
      labels <- self$resolve_series_labels(built, rows, panel_id)

      series <- list()
      for (key in unique(groups)) {
        subset <- rows[groups == key, , drop = FALSE]
        subset <- subset[order(subset$x), , drop = FALSE]
        label <- labels[[as.character(key)]]

        points <- vector("list", nrow(subset))
        for (i in seq_len(nrow(subset))) {
          point <- list(
            x = self$scalar(subset$x[i]),
            # The band's height, not its top edge.
            y = self$band_height(subset, i)
          )
          if (!is.null(label) && nzchar(label)) {
            point$z <- label
          }
          points[[i]] <- point
        }
        series[[length(series) + 1L]] <- points
      }

      series
    },

    #' @description Keep only the rows the chart was given.
    #'
    #' `StatAlign` inserts interpolation vertices and baseline-closing
    #' vertices, neither of which is an observation. The rows that are data are
    #' those whose `x` appears in the layer's own data; that filter is verified
    #' to give the same rows `stat = "identity"` produces.
    #'
    #' A layer whose x values cannot be recovered keeps every row rather than
    #' losing the chart -- a noisy reading being better than none -- which is
    #' why this returns the input unchanged rather than empty when the lookup
    #' fails.
    #'
    #' @param built Built plot data
    #' @param layer_data This layer's computed rows
    #' @return The data-bearing rows
    drop_alignment_vertices = function(built, layer_data) {
      if (is.null(layer_data) || !"x" %in% names(layer_data)) {
        return(layer_data)
      }

      source_x <- self$source_x_values(built)
      if (is.null(source_x)) {
        # The lookup failed and the axis could be anything. Filtering on a
        # rule chosen for one kind of axis would drop real rows from the
        # other, so keep the layer whole -- a noisy reading, but not a wrong
        # one.
        return(layer_data)
      }

      keep <- if (identical(source_x$kind, "discrete")) {
        # A discrete axis sits on whole-numbered positions assigned by the
        # scale, and `StatAlign`'s inserted vertices do not, so the integers
        # are the rows the chart was given.
        layer_data$x == round(layer_data$x)
      } else if (length(source_x$values) == 0) {
        return(layer_data)
      } else {
        layer_data$x %in% source_x$values
      }

      if (!any(keep, na.rm = TRUE)) {
        return(layer_data)
      }
      layer_data[which(keep), , drop = FALSE]
    },

    #' @description Read the x values the layer was given, before any stat.
    #'
    #' Reports a discrete axis as such rather than guessing its positions:
    #' those are assigned by the scale, and reconstructing them from the data
    #' column would drift the moment a factor level appeared in one and not
    #' the other. The caller has an exact rule for that case.
    #'
    #' "Discrete" and "could not be read" are answered differently, because
    #' the caller must do different things with them. The integer rule that is
    #' exact for a discrete axis would silently drop the fractional rows of a
    #' continuous one, and an x mapped through an expression -- `aes(x = year
    #' / 2)`, say -- resolves to no column and lands here while still being
    #' continuous. Collapsing the two into one NULL is how that axis loses
    #' half its data to a rule that was never about it.
    #'
    #' @param built Built plot data
    #' @return `list(kind = "discrete")`, `list(kind = "numeric", values =)`,
    #'   or NULL when the axis could not be read at all
    source_x_values = function(built) {
      plot <- built$plot
      if (is.null(plot)) {
        return(NULL)
      }

      index <- self$get_layer_index()
      layer <- if (!is.null(index) && index >= 1L &&
        index <= length(plot$layers)) {
        plot$layers[[index]]
      } else {
        NULL
      }

      data <- if (!is.null(layer) && is.data.frame(layer$data) &&
        nrow(layer$data) > 0) {
        layer$data
      } else {
        plot$data
      }
      if (!is.data.frame(data) || nrow(data) == 0) {
        return(NULL)
      }

      mapping <- if (!is.null(layer)) layer$mapping else NULL
      column <- self$mapped_column(if (!is.null(mapping) && !is.null(mapping$x)) {
        mapping$x
      } else {
        plot$mapping$x
      })
      if (is.null(column) || !column %in% names(data)) {
        return(NULL)
      }

      values <- data[[column]]
      if (is.numeric(values)) {
        return(list(kind = "numeric", values = unique(values)))
      }

      # A discrete x is drawn at integer positions assigned by the *scale*,
      # not by the data, so reconstructing them from the column would go wrong
      # the moment a factor level is present in one and absent from the other.
      # Naming the kind lets the caller apply the rule that needs no
      # reconstruction: whatever positions the scale chose, they are whole
      # numbers, and `StatAlign`'s inserted vertices are not.
      list(kind = "discrete")
    },

    #' @description The band's own height at one row.
    #'
    #' Falls back to `y` when the edges are absent, since an unstacked layer
    #' whose baseline is the axis draws a band of exactly that height.
    #'
    #' @param rows The rows of one series
    #' @param i Which row
    #' @return The series' value at that row
    band_height = function(rows, i) {
      has_edges <- all(c("ymin", "ymax") %in% names(rows))
      if (has_edges && is.finite(rows$ymin[i]) && is.finite(rows$ymax[i])) {
        return(as.numeric(rows$ymax[i] - rows$ymin[i]))
      }
      if ("y" %in% names(rows)) {
        return(as.numeric(rows$y[i]))
      }
      NA_real_
    },

    #' @description Name each series after its fill level.
    #' @param built Built plot data
    #' @param rows This layer's data-bearing rows
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A named list of group key to label
    resolve_series_labels = function(built, rows, panel_id = NULL) {
      labels <- list()
      if (!"group" %in% names(rows)) {
        return(labels)
      }

      levels <- self$fill_levels(built)
      for (key in unique(rows$group)) {
        index <- suppressWarnings(as.integer(key))
        if (!is.na(index) && index >= 1 && index <= length(levels)) {
          labels[[as.character(key)]] <- as.character(levels[index])
        }
      }
      labels
    },

    #' @description The fill levels, in the order ggplot2 numbered the groups.
    #' @param built Built plot data
    #' @return A character vector of levels, possibly empty
    fill_levels = function(built) {
      plot <- built$plot
      if (is.null(plot) || !is.data.frame(plot$data) || nrow(plot$data) == 0) {
        return(character(0))
      }

      column <- self$mapped_column(plot$mapping$fill)
      if (is.null(column) || !column %in% names(plot$data)) {
        return(character(0))
      }

      values <- plot$data[[column]]
      if (is.factor(values)) levels(values) else sort(unique(as.character(values)))
    },

    #' @description Add the legend title as the z axis, when there is one.
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @param axes The axes assembled so far
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return The axes, with `z` added when a fill legend exists
    attach_fill_axis = function(plot, built, axes, panel_id = NULL) {
      label <- resolve_legend_label(
        plot = plot,
        built = built,
        aes_names = "fill"
      )
      if (!is.null(label) && nzchar(label)) {
        axes$z <- list(label = label)
      }
      axes
    },

    #' @description Name the source column an aesthetic is mapped to.
    #'
    #' `aes(x = factor(year))` maps a call rather than a bare name, and the
    #' column the data actually holds is its argument -- so the call is
    #' unwrapped rather than labelled, which would give `"factor(year)"` and
    #' match nothing.
    #'
    #' @param quo The mapped quosure, or NULL
    #' @return The column name, or NULL when there is no mapping
    mapped_column = function(quo) {
      if (is.null(quo)) {
        return(NULL)
      }
      expr <- rlang::quo_get_expr(quo)
      if (is.call(expr) && expr[[1]] == "factor") {
        as.character(expr[[2]])
      } else {
        rlang::as_label(expr)
      }
    },

    #' @description Convert one coordinate to a JSON-safe scalar.
    #' @param value A coordinate read off the built data
    #' @return A number, or a string when the coordinate is not numeric
    scalar = function(value) {
      if (is.factor(value)) {
        return(as.character(value))
      }
      if (is.numeric(value)) {
        return(as.numeric(value))
      }
      as.character(value)
    }
  )
)
