#' ggplot2 Step Layer Processor
#'
#' Processes `geom_step()` layers. A step chart is piecewise constant: the
#' value is held across an interval and then jumps, rather than being
#' interpolated between samples the way a line implies. The canonical case is
#' a hypnogram -- an ordinal sleep stage (Awake / REM / N1 / N2 / N3) against
#' time.
#'
#' Everything about extracting x/y and locating the rendered polyline is the
#' same as for a line, so this class inherits `Ggplot2LineLayerProcessor` and
#' adds only what a step layer has that a line layer does not:
#'
#' \itemize{
#'   \item `stepDirection` -- the `hv` / `vh` / `mid` convention the layer was
#'     drawn with, emitted as a sibling of `axes` and `data` on the layer.
#'   \item a per-point `label` -- the *name* of the ordinal level, so the
#'     frontend announces "REM" rather than the numeric level code that
#'     encodes it. `y` stays numeric because it drives sonification, braille
#'     and the min/max range.
#' }
#'
#' One data point is emitted per data *sample*, never one per stairstep
#' vertex. `ggplot2` expands the stairsteps inside `GeomStep$draw_panel()`, so
#' the rendered polyline carries `2n - 1` vertices (`hv` / `vh`) or `2n`
#' (`mid`) for `n` samples; the MAIDR frontend's `StepTrace` maps those
#' vertices back onto the samples. Emitting vertex-level data to "match" the
#' polyline would double every level and misreport transitions and run
#' lengths.
#'
#' @keywords internal
Ggplot2StepLayerProcessor <- R6::R6Class(
  "Ggplot2StepLayerProcessor",
  inherit = Ggplot2LineLayerProcessor,
  public = list(
    #' @description Process the step layer.
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes, type and stepDirection
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      result <- super$process(
        plot, layout, built, gt, scale_mapping, grob_id, panel_id, panel_ctx
      )
      result$type <- "step"

      direction <- self$extract_step_direction(plot)
      if (!is.null(direction)) {
        result$stepDirection <- direction
      }

      result
    },

    #' @description Read the step convention this layer was drawn with.
    #'
    #' `geom_step(direction = )` is a formal of `GeomStep$draw_panel()`, so
    #' ggplot2 files it under `layer$geom_params$direction` rather than
    #' `layer$aes_params` or the layer's mapping. The three accepted values
    #' (`"hv"`, `"vh"`, `"mid"`) are exactly MAIDR's, so they pass through
    #' unchanged. `"hv"` is both ggplot2's and MAIDR's default.
    #'
    #' @param plot The ggplot2 object
    #' @return One of "hv", "vh", "mid" (defaulting to "hv"), or NULL when the
    #'   layer cannot be located at all.
    extract_step_direction = function(plot) {
      layer <- self$get_layer(plot)
      if (is.null(layer)) {
        return(NULL)
      }

      direction <- layer$geom_params$direction
      if (is.null(direction) || length(direction) == 0) {
        return("hv")
      }

      direction <- as.character(direction)[1]
      if (!direction %in% c("hv", "vh", "mid")) {
        return("hv")
      }
      direction
    },

    #' @description Extract step data, one point per data sample.
    #'
    #' Delegates to the line processor for x/y extraction -- including the
    #' recovery of Date / POSIXct x columns and the dropping of NA-y rows,
    #' which exists so the emitted data length stays aligned with the rendered
    #' geometry -- then attaches the ordinal level name to each point.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List of series, each a list of points with x, y and optionally
    #'   z and label
    extract_data = function(plot, built = NULL, scale_mapping = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      series_data <- super$extract_data(plot, built, scale_mapping, panel_id)
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
          if (!is.null(point$y)) {
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
      names <- as.character(original_y)
      keep <- !is.na(layer_data$y) & !is.na(original_y)
      if (!any(keep)) {
        return(NULL)
      }

      lookup <- names[keep]
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
    }
  )
)
