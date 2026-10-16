#' Volcano and Manhattan Layer Processor
#'
#' @description
#' Reads a [maidr_volcano()] or [maidr_manhattan()] layer as the `volcano` or
#' `manhattan` trace. Both are scatters, so the point processor does the
#' work: the drawn rows, the positions read back through the scales, the
#' selector for the panel's points. What this adds is what the trace reads
#' that a scatter does not.
#'
#' - **Each point's identity.** The geom's `label` and `region` aesthetics
#'   survive the build as columns, and are emitted as the point's `label`
#'   and `group` (the grammar's name for the region a point belongs to).
#' - **The threshold.** The layer's declared `thresholdOptions`, which the
#'   core reads beside `data`, in the units the points are announced in.
#'
#' @keywords internal
Ggplot2VolcanoLayerProcessor <- R6::R6Class(
  "Ggplot2VolcanoLayerProcessor",
  inherit = Ggplot2PointLayerProcessor,
  public = list(
    #' @description Process the volcano or Manhattan layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, axes, type and thresholdOptions
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

      result <- super$process(
        plot, layout, built, gt, grob_id, panel_id, panel_ctx
      )

      layer <- plot$layers[[self$get_layer_index()]]
      result$type <- if (identical(class(layer$geom)[1], "GeomManhattan")) {
        "manhattan"
      } else {
        "volcano"
      }
      result$data <- self$attach_identities(result$data, plot, built, panel_id)

      thresholds <- tryCatch(
        layer$maidr_threshold_options,
        error = function(e) NULL
      )
      if (is.list(thresholds) && length(thresholds) > 0L) {
        result$thresholdOptions <- thresholds
      }

      result
    },

    #' @description Attach each point's `label` and `group`
    #'
    #' The point processor emits one point per drawn row: the panel's rows,
    #' less those whose x or y is missing. The same filter over the same
    #' built rows puts each label and region back beside its point. Should
    #' the counts ever disagree, no identity is attached rather than the
    #' wrong one.
    #'
    #' @param data The points the point processor emitted
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return The points, with `label` and `group` where the layer has them
    attach_identities = function(data, plot, built, panel_id = NULL) {
      index <- self$get_layer_index()
      if (is.null(built) || is.null(index) || index < 1L ||
        index > length(built$data)) {
        return(data)
      }
      frame <- undisplace_layer(plot, built$data[[index]], index)
      if (!is.data.frame(frame) ||
        !any(c("label", "region") %in% names(frame))) {
        return(data)
      }
      if (!is.null(panel_id) && "PANEL" %in% names(frame)) {
        frame <- frame[frame$PANEL == panel_id, , drop = FALSE]
      }
      drawn <- rep(TRUE, nrow(frame))
      for (aesthetic in c("x", "y")) {
        if (aesthetic %in% names(frame) && is.numeric(frame[[aesthetic]])) {
          drawn <- drawn & is.finite(frame[[aesthetic]])
        }
      }
      frame <- frame[drawn, , drop = FALSE]
      if (nrow(frame) != length(data)) {
        return(data)
      }

      as_names <- function(values) {
        if (is.null(values)) {
          return(NULL)
        }
        values <- as.character(values)
        values[is.na(values)] <- ""
        values
      }
      labels <- as_names(frame$label)
      regions <- as_names(frame$region)

      for (i in seq_along(data)) {
        # An empty name is absent to the core, so it is left out rather
        # than announced as a blank.
        if (!is.null(labels) && nzchar(labels[[i]])) {
          data[[i]]$label <- labels[[i]]
        }
        if (!is.null(regions) && nzchar(regions[[i]])) {
          data[[i]]$group <- regions[[i]]
        }
      }
      data
    }
  )
)
