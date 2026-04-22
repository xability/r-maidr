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
