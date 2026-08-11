#' Abstract Layer Processor Interface
#'
#' This is the abstract base class for all layer processors. It defines the
#' interface that all layer processors must implement.
#'
#' @field layer_info Information about the layer
#' @keywords internal
LayerProcessor <- R6::R6Class(
  "LayerProcessor",
  private = list(
    .last_result = NULL
  ),
  public = list(
    #' @field layer_info Information about the layer
    layer_info = NULL,

    #' @description Initialize the layer processor
    #' @param layer_info Information about the layer
    initialize = function(layer_info) {
      self$layer_info <- layer_info
    },

    #' @description Process the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List with data and selectors
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_ctx = NULL) {
      stop("process() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Extract data from the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @return Extracted data
    extract_data = function(plot, built = NULL, scale_mapping = NULL) {
      stop("extract_data() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Generate selectors for the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      stop("generate_selectors() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Read this layer's rows out of the built plot.
    #'
    #' Scoped to one panel when asked. A faceted plot puts every panel's rows
    #' in one frame, so a layer that took all of them would describe the whole
    #' facet grid as one series.
    #'
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

      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        subset <- layer_data[as.character(layer_data$PANEL) ==
          as.character(panel_id), , drop = FALSE]
        if (nrow(subset) > 0) {
          return(subset)
        }
      }

      layer_data
    },

    #' @description Resolve the plot layer this processor was built for.
    #'
    #' Every processor knows its index and several need the layer itself --
    #' for its geom, its position or its own `data` -- so the lookup lives
    #' here rather than being copied into each. Answers NULL rather than
    #' erroring when the index does not resolve, since a caller that cannot
    #' find its layer has a reading to fall back on and no crash to justify.
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

    #' @description Check if this layer needs reordering (OPTIONAL - default: FALSE)
    #' @return Logical indicating if reordering is needed
    needs_reordering = function() {
      FALSE
    },

    #' @description Reorder layer data (OPTIONAL - default: no-op)
    #' @param data data.frame effective for this layer
    #' @param plot full ggplot object (for mappings)
    #' @return Reordered data
    reorder_layer_data = function(data, plot) {
      data
    },

    #' @description Augment the plot before building (OPTIONAL - default: no-op)
    #'
    #' Called by the orchestrator before ggplot_build/ggplotGrob. Allows a
    #' processor to inject additional geom layers (e.g., a boxplot inside a
    #' violin) so they appear in the SVG and can be targeted by selectors.
    #'
    #' @param plot The ggplot2 object to augment
    #' @return The (possibly augmented) ggplot2 object
    augment_plot = function(plot) {
      plot
    },

    #' @description Check if this processor needs to augment the plot
    #' @return Logical
    needs_augmentation = function() {
      FALSE
    },

    #' @description Get layer index
    #' @return Layer index
    get_layer_index = function() {
      self$layer_info$index
    },

    #' @description Store the last processed result (used by orchestrator)
    #' @param result The result to store
    set_last_result = function(result) {
      private$.last_result <- result
      invisible(result)
    },

    #' @description Get the last processed result
    #' @return The last result
    get_last_result = function() {
      private$.last_result
    },

    #' @description Extract axes labels for this specific layer
    #'
    #' Returns axes in the canonical per-axis object schema:
    #' \code{list(x = list(label = "..."), y = list(label = "..."))}.
    #'
    #' Bare strings, top-level \code{format}/\code{min}/\code{max}/\code{tickStep}/
    #' \code{fill}/\code{level}, and any non-\{x,y,z\} keys are NOT permitted.
    #'
    #' @param plot The ggplot object
    #' @param layout Global layout with fallback axes
    #' @return Named list with \code{x} and \code{y} AxisConfig objects
    extract_layer_axes = function(plot, layout) {
      layer_index <- self$get_layer_index()

      # Start with layout axes as fallback. Layout may already carry the new
      # AxisConfig shape, a legacy bare string, or be NULL.
      x_label <- extract_axis_label(layout$axes$x, default = "")
      y_label <- extract_axis_label(layout$axes$y, default = "")

      # Helper to extract variable name from potentially complex expressions
      extract_var_name <- function(mapping_expr) {
        tryCatch(
          {
            # Try simple conversion first
            rlang::as_label(mapping_expr)
          },
          error = function(e) {
            # If that fails, try to extract the first symbol from the expression
            expr <- rlang::quo_get_expr(mapping_expr)
            if (is.call(expr) && length(expr) > 1) {
              # For expressions like line_values * scale_factor, extract first symbol
              first_arg <- expr[[2]]
              if (is.symbol(first_arg)) {
                return(as.character(first_arg))
              }
            }
            # If all else fails, return NULL to use fallback
            NULL
          }
        )
      }

      # Try to get layer-specific mapping
      if (!is.null(plot$layers[[layer_index]]$mapping)) {
        layer_mapping <- plot$layers[[layer_index]]$mapping

        # Override with layer-specific x mapping if it exists
        if (!is.null(layer_mapping$x)) {
          extracted_x <- extract_var_name(layer_mapping$x)
          if (!is.null(extracted_x)) {
            x_label <- extracted_x
          }
        }

        # Override with layer-specific y mapping if it exists
        if (!is.null(layer_mapping$y)) {
          extracted_y <- extract_var_name(layer_mapping$y)
          if (!is.null(extracted_y)) {
            y_label <- extracted_y
          }
        }
      }

      list(
        x = list(label = x_label),
        y = list(label = y_label)
      )
    },

    #' @description Apply scale mapping to numeric values
    #' @param numeric_values Vector of numeric values
    #' @param scale_mapping Scale mapping vector
    #' @return Mapped values
    apply_scale_mapping = function(numeric_values, scale_mapping) {
      apply_scale_mapping(numeric_values, scale_mapping)
    }
  )
)
