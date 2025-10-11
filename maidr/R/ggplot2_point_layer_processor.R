#' Point Layer Processor
#'
#' Processes scatter plot layers (geom_point) to extract point data and generate selectors
#' for individual points in the SVG structure.
#'
#' @keywords internal
Ggplot2PointLayerProcessor <- R6::R6Class("Ggplot2PointLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' Process the point layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with data and selectors
    process = function(plot, layout, built = NULL, gt = NULL, scale_mapping = NULL, grob_id = NULL, panel_id = NULL, panel_ctx = NULL) {
      # Extract data from the point layer
      extracted_data <- self$extract_data(plot, built, scale_mapping, panel_id)

      # Generate selectors for the point elements
      selectors <- self$generate_selectors(plot, gt, grob_id, panel_ctx)

      # Create axes information
      axes <- list(
        x = if (!is.null(layout$axes$x)) layout$axes$x else "x",
        y = if (!is.null(layout$axes$y)) layout$axes$y else "y"
      )

      # For point plots, data is directly the array of points
      data <- extracted_data

      list(
        data = data,
        selectors = selectors,
        axes = axes
      )
    },

    #' Extract data from point layer
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List with points array and color information
    extract_data = function(plot, built = NULL, scale_mapping = NULL, panel_id = NULL) {
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]

      # Filter data for specific panel if panel_id is provided
      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        layer_data <- layer_data[layer_data$PANEL == panel_id, ]
      }

      # Apply scale mapping if provided (for faceted plots)
      if (!is.null(scale_mapping)) {
        layer_data$x <- self$apply_scale_mapping(layer_data$x, scale_mapping)
      }

      # Get the original data
      original_data <- plot$data

      # Get column names from plot mapping
      plot_mapping <- plot$mapping
      layer_mapping <- plot$layers[[layer_index]]$mapping

      # Determine x, y column names
      x_col <- if (!is.null(layer_mapping$x)) {
        rlang::as_name(layer_mapping$x)
      } else if (!is.null(plot_mapping$x)) {
        rlang::as_name(plot_mapping$x)
      } else {
        names(original_data)[1]
      }

      y_col <- if (!is.null(layer_mapping$y)) {
        rlang::as_name(layer_mapping$y)
      } else if (!is.null(plot_mapping$y)) {
        rlang::as_name(plot_mapping$y)
      } else {
        names(original_data)[2]
      }

      # Determine color column name
      color_col <- if (!is.null(layer_mapping$colour)) {
        rlang::as_name(layer_mapping$colour)
      } else if (!is.null(layer_mapping$color)) {
        rlang::as_name(layer_mapping$color)
      } else if (!is.null(plot_mapping$colour)) {
        rlang::as_name(plot_mapping$colour)
      } else if (!is.null(plot_mapping$color)) {
        rlang::as_name(plot_mapping$color)
      } else {
        NULL
      }

      # Extract points
      points <- list()
      for (i in seq_len(nrow(layer_data))) {
        point <- list(
          x = layer_data$x[i],
          y = layer_data$y[i]
        )

        # Add color information if available
        if (!is.null(color_col) && color_col %in% names(layer_data)) {
          point$color <- as.character(layer_data[[color_col]][i])
        }

        points[[i]] <- point
      }

      # For point plots, return the points array directly
      points
    },

    #' Generate selectors for point elements
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      if (!is.null(panel_ctx) && !is.null(gt)) {
        pn <- panel_ctx$panel_name
        idx <- which(grepl(paste0("^", pn, "\\b"), gt$layout$name))
        if (length(idx) == 0) {
          return(list())
        }
        panel_grob <- gt$grobs[[idx[1]]]
        if (!inherits(panel_grob, "gTree")) {
          return(list())
        }

        # Look for geom_point container(s) within this panel
        point_names <- c()
        find_points <- function(grob) {
          if (!is.null(grob$name) && grepl("geom_point\\.points", grob$name)) {
            point_names <<- c(point_names, grob$name)
          }
          if (inherits(grob, "gList")) {
            for (i in seq_along(grob)) find_points(grob[[i]])
          }
          if (inherits(grob, "gTree")) {
            for (i in seq_along(grob$children)) find_points(grob$children[[i]])
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

        # Find geom_point container
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

    #' Find the main panel grob
    #' @param gt The gtable to search
    #' @return The panel grob or NULL
    find_panel_grob = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        return(NULL)
      }

      panel_grob <- gt$grobs[[panel_index]]
      if (!inherits(panel_grob, "gTree")) {
        return(NULL)
      }

      panel_grob
    },

    #' Find children by type pattern
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
