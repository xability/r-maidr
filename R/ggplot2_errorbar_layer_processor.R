#' ggplot2 Error Bar Layer Processor
#'
#' Processes ggplot2's uncertainty geoms -- `geom_errorbar()`,
#' `geom_errorbarh()`, `geom_linerange()`, `geom_pointrange()` and
#' `geom_crossbar()` -- into MAIDR's `error_bar` layer.
#'
#' Uncertainty is usually the finding rather than the decoration: whether two
#' group means differ is answered by whether their intervals overlap. Until
#' this processor existed every one of these geoms fell through to
#' `Ggplot2UnknownLayerProcessor`, so the interval was dropped and that
#' comparison was unavailable to a MAIDR reader.
#'
#' ## Reading the right pair of bounds
#'
#' The trap this class exists to avoid is that ggplot2's built data carries
#' **both** pairs for most of these geoms, and only one of them is the
#' interval. A vertical `geom_errorbar()` computes:
#'
#' ```
#'   x  y  ymin ymax  xmin  xmax  flipped_aes
#'   1 4.2  3.8  4.6  0.55  1.45  FALSE
#' ```
#'
#' `ymin`/`ymax` are the interval; `xmin`/`xmax` are the *cap width* -- how
#' wide the little crossbars are drawn, which is a styling parameter and not
#' data at all. Reading the wrong pair yields a chart describing the cap
#' geometry, which is both wrong and plausible-looking.
#'
#' Which pair is the interval is decided by the layer's orientation, and
#' ggplot2 records that in two different ways depending on the geom:
#'
#' \itemize{
#'   \item `geom_errorbar(orientation = "y")` and friends set a `flipped_aes`
#'     column to `TRUE` in the built data.
#'   \item `geom_errorbarh()` has no `flipped_aes` column at all -- it is
#'     horizontal by construction.
#' }
#'
#' Both are handled, because a layer that read only `flipped_aes` would treat
#' every `geom_errorbarh()` as vertical and emit the cap heights as the
#' interval.
#'
#' @keywords internal
Ggplot2ErrorbarLayerProcessor <- R6::R6Class(
  "Ggplot2ErrorbarLayerProcessor",
  inherit = Ggplot2PointLayerProcessor,
  public = list(
    #' @description Process the error bar layer.
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, axes, type and orientation
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_data <- self$get_layer_built_data(built, panel_id)
      is_horizontal <- self$is_horizontal_layer(plot, layer_data)

      list(
        data = self$extract_interval_data(
          built, layer_data, is_horizontal, panel_id
        ),
        axes = self$extract_axes_labels(plot, built, panel_id),
        type = "error_bar",
        orientation = if (isTRUE(is_horizontal)) "horz" else "vert"
      )
    },

    #' @description Read this layer's rows out of the built plot.
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A data frame of computed aesthetics, or NULL
    get_layer_built_data = function(built, panel_id = NULL) {
      index <- self$layer_info$layer_index
      if (is.null(index) || index > length(built$data)) {
        return(NULL)
      }

      layer_data <- built$data[[index]]
      if (is.null(layer_data) || nrow(layer_data) == 0) {
        return(NULL)
      }

      # A faceted plot puts every panel's rows in one frame, so a layer that
      # took all of them would describe the whole facet grid as one series.
      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        subset <- layer_data[as.character(layer_data$PANEL) ==
          as.character(panel_id), , drop = FALSE]
        if (nrow(subset) > 0) {
          return(subset)
        }
      }

      layer_data
    },

    #' @description Decide whether the interval runs along x rather than y.
    #'
    #' Reads `flipped_aes` when the built data carries it, and falls back to
    #' the geom class for `geom_errorbarh()`, which is horizontal by
    #' construction and therefore has no such column to read.
    #'
    #' @param plot The ggplot2 object
    #' @param layer_data This layer's computed rows
    #' @return TRUE when the interval spans the x axis
    is_horizontal_layer = function(plot, layer_data) {
      if (!is.null(layer_data) && "flipped_aes" %in% names(layer_data)) {
        flipped <- layer_data$flipped_aes
        if (length(flipped) > 0 && !is.na(flipped[1])) {
          return(isTRUE(as.logical(flipped[1])))
        }
      }

      layer <- self$get_own_layer(plot)
      if (is.null(layer)) {
        return(FALSE)
      }
      identical(class(layer$geom)[1], "GeomErrorbarh")
    },

    #' @description Build the MAIDR points for this layer.
    #'
    #' The emitted shape names the category `x` and the magnitude `y` in both
    #' orientations, with the bounds in `yMin`/`yMax`, and lets `orientation`
    #' say which is on screen where. That is the shape MAIDR's `ErrorBarTrace`
    #' consumes: it reads the magnitude as `y`/`yMin`/`yMax` with no
    #' orientation branch, so emitting screen-aligned keys would leave a
    #' horizontal chart with no interval at all.
    #'
    #' A row missing its bounds still emits its estimate. A one-sided interval
    #' is a real chart, and dropping the point for want of its other half
    #' would lose the estimate too.
    #'
    #' @param built Built plot data
    #' @param layer_data This layer's computed rows
    #' @param is_horizontal Whether the interval spans the x axis
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of MAIDR interval points
    extract_interval_data = function(built,
                                     layer_data,
                                     is_horizontal,
                                     panel_id = NULL) {
      if (is.null(layer_data)) {
        return(list())
      }

      # The interval runs along one axis and the categories along the other.
      # For a horizontal layer the roles swap, and reading the y pair there
      # would emit the cap heights -- a styling parameter -- as the data.
      value_col <- if (isTRUE(is_horizontal)) "x" else "y"
      category_col <- if (isTRUE(is_horizontal)) "y" else "x"
      min_col <- if (isTRUE(is_horizontal)) "xmin" else "ymin"
      max_col <- if (isTRUE(is_horizontal)) "xmax" else "ymax"

      if (!all(c(value_col, category_col) %in% names(layer_data))) {
        return(list())
      }

      categories <- self$resolve_category_labels(
        built, layer_data, category_col, panel_id
      )
      values <- layer_data[[value_col]]
      lower <- if (min_col %in% names(layer_data)) layer_data[[min_col]] else NULL
      upper <- if (max_col %in% names(layer_data)) layer_data[[max_col]] else NULL

      points <- vector("list", nrow(layer_data))
      for (i in seq_len(nrow(layer_data))) {
        point <- list(x = categories[[i]], y = as.numeric(values[i]))

        if (!is.null(lower) && is.finite(lower[i])) {
          point$yMin <- as.numeric(lower[i])
        }
        if (!is.null(upper) && is.finite(upper[i])) {
          point$yMax <- as.numeric(upper[i])
        }

        points[[i]] <- point
      }

      points
    },

    #' @description Resolve this processor's own ggplot2 layer.
    #'
    #' `Ggplot2LineLayerProcessor` has a `get_layer()`, but this class inherits
    #' the point processor, which does not -- so it resolves its own rather
    #' than inheriting from a sibling for one method.
    #'
    #' @param plot The ggplot2 object
    #' @return The layer, or NULL when the index does not resolve
    get_own_layer = function(plot) {
      if (is.null(plot) || is.null(plot$layers)) {
        return(NULL)
      }
      index <- self$layer_info$layer_index
      if (is.null(index) || index > length(plot$layers)) {
        return(NULL)
      }
      plot$layers[[index]]
    },

    #' @description Recover the names behind a discrete category axis.
    #'
    #' ggplot2 maps a discrete axis onto integer positions before it computes
    #' the layer, so the built data carries `1, 2, 3` where the chart draws
    #' `control, high dose, low dose`. Announcing the positions would name
    #' something the reader cannot find anywhere on the chart -- and the
    #' positions are assigned in the scale's order, not the data's, so they do
    #' not even read as row numbers.
    #'
    #' The labels come from the panel's scale rather than from the data frame,
    #' which is what makes the position an index into them.
    #'
    #' @param built Built plot data
    #' @param layer_data This layer's computed rows
    #' @param category_col Which built column carries the category
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of labels -- strings for a discrete axis, numbers for a
    #'   continuous one
    resolve_category_labels = function(built,
                                       layer_data,
                                       category_col,
                                       panel_id = NULL) {
      raw <- layer_data[[category_col]]

      if (is.factor(raw)) {
        return(as.list(as.character(raw)))
      }

      labels <- self$category_axis_labels(built, category_col, panel_id)
      if (is.null(labels)) {
        return(lapply(raw, as.numeric))
      }

      lapply(raw, function(position) {
        index <- suppressWarnings(as.integer(round(as.numeric(position))))
        if (!is.na(index) && index >= 1 && index <= length(labels)) {
          labels[[index]]
        } else {
          as.numeric(position)
        }
      })
    },

    #' @description Read the break labels of the category axis, when discrete.
    #'
    #' @param built Built plot data
    #' @param category_col Which built column carries the category
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A character vector of labels, or NULL on a continuous axis
    category_axis_labels = function(built, category_col, panel_id = NULL) {
      panel_params <- built$layout$panel_params
      if (is.null(panel_params) || length(panel_params) == 0) {
        return(NULL)
      }

      # An unfaceted plot passes no panel id at all, so this has to survive
      # NULL and a non-numeric id, not just an out-of-range one.
      index <- suppressWarnings(as.integer(panel_id))
      params <- if (length(index) == 1 && !is.na(index) &&
        index >= 1 && index <= length(panel_params)) {
        panel_params[[index]]
      } else {
        panel_params[[1]]
      }

      scale <- params[[category_col]]
      if (is.null(scale) || is.null(scale$get_labels)) {
        return(NULL)
      }

      # A continuous axis has break labels too ("0", "25", ...), and those are
      # NOT an index into anything -- treating them as one would rename every
      # point. Only a discrete scale maps positions onto labels this way.
      if (!isTRUE(scale$is_discrete())) {
        return(NULL)
      }

      labels <- suppressWarnings(scale$get_labels())
      if (is.null(labels) || length(labels) == 0) {
        return(NULL)
      }
      as.character(labels)
    }
  )
)
