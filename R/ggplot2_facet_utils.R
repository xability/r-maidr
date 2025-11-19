#' Facet Processing Utilities
#'
#' Utility functions for processing faceted ggplot2 plots.
#' These functions handle panel extraction, processing, and grid organization
#' for faceted plots in a unified way.
#'
#' @keywords internal

#' Process a faceted plot and return organized subplot data
#' @param plot The faceted ggplot2 object
#' @param layout Layout information
#' @param built Built plot data
#' @param gtable Gtable object
#' @return List with organized subplot data in 2D grid format
process_faceted_plot_data <- function(plot, layout, built, gtable) {
  # Extract panel information
  panel_layout <- built$layout$layout

  # Process each panel
  subplots <- list()
  for (i in seq_len(nrow(panel_layout))) {
    panel_info <- panel_layout[i, ]

    # Extract panel data
    panel_data <- built$data[[1]][built$data[[1]]$PANEL == panel_info$PANEL, ]

    # Get facet group information
    facet_groups <- get_facet_groups(panel_info, built)

    # Map based on visual position (ROW/COL) with DOM order correction
    # The DOM elements are generated in column-major order, but our data is in row-major order
    # We need to map the visual position to the correct DOM panel
    gtable_panel_name <- map_visual_to_dom_panel(panel_info, gtable)

    # Process this panel
    subplot_data <- process_facet_panel(
      plot, panel_info, panel_data, facet_groups, gtable_panel_name,
      built, layout, gtable
    )
    subplots[[i]] <- subplot_data
  }

  # Organize into 2D grid structure
  organize_facet_grid(subplots, panel_layout)
}

#' Get facet group information for a panel
#' @param panel_info Panel information from layout
#' @param built Built plot data
#' @return List of facet group information
get_facet_groups <- function(panel_info, built) {
  facet_groups <- list()

  # Extract facet variable information
  if (!is.null(built$layout$facet)) {
    facet_vars <- names(built$layout$facet$params$facets)
    if (length(facet_vars) == 0) {
      facet_vars <- names(built$layout$facet$params$rows)
    }

    for (var in facet_vars) {
      if (var %in% names(panel_info)) {
        facet_groups[[var]] <- as.character(panel_info[[var]])
      }
    }
  }

  facet_groups
}

#' Process a single facet panel
#' @param plot The original plot
#' @param panel_info Panel information
#' @param panel_data Panel-specific data
#' @param facet_groups Facet group information
#' @param gtable_panel_name Gtable panel name
#' @param built Built plot data
#' @param layout Layout information
#' @param gtable Gtable object
#' @return Processed panel data
process_facet_panel <- function(plot, panel_info, panel_data, facet_groups,
                                gtable_panel_name, built, layout, gtable) {
  # Process layers using existing processors with panel-specific data
  layer_results <- list()

  for (layer_idx in seq_along(plot$layers)) {
    layer <- plot$layers[[layer_idx]]
    layer_info <- list(index = layer_idx, type = class(layer$geom)[1])

    # Get the processor factory and adapter from the registry
    registry <- get_global_registry()
    system_name <- "ggplot2"
    factory <- registry$get_processor_factory(system_name)
    adapter <- registry$get_adapter(system_name)

    # Create processor using the factory with adapter's layer type detection
    layer_type <- adapter$detect_layer_type(layer, plot)
    processor <- factory$create_processor(layer_type, layer_info)

    if (!is.null(processor)) {
      # Build panel context for panel-scoped selector generation
      panel_name <- if (!is.null(gtable_panel_name)) gtable_panel_name else paste0("panel-", panel_info$ROW, "-", panel_info$COL)
      panel_ctx <- list(
        panel_name = panel_name,
        row = panel_info$ROW,
        col = panel_info$COL,
        panel_id = panel_info$PANEL,
        layer_index = layer_idx
      )
      result <- processor$process(
        plot,
        layout,
        built,
        gtable,
        scale_mapping = NULL,
        grob_id = NULL,
        panel_id = panel_info$PANEL,
        panel_ctx = panel_ctx
      )

      layer_results[[layer_idx]] <- result
    }
  }

  # Combine layer results
  combined_data <- combine_facet_layer_data(layer_results)
  combined_selectors <- combine_facet_layer_selectors(layer_results)

  # Create proper subplot structure
  subplot_id <- paste0("maidr-subplot-", as.integer(Sys.time()), "-", panel_info$PANEL)

  # Create layers structure
  layers <- list()
  if (length(combined_data) > 0) {
    layer_id <- paste0("maidr-layer-", as.integer(Sys.time()), "-", panel_info$PANEL)

    # Determine layer type from the first layer processor
    registry <- get_global_registry()
    system_name <- "ggplot2"
    adapter <- registry$get_adapter(system_name)
    layer_type <- adapter$detect_layer_type(plot$layers[[1]], plot)

    # Create facet title from facet groups
    facet_title <- ""
    if (length(facet_groups) > 0) {
      facet_title <- paste(facet_groups, collapse = " & ")
    }

    # Create axes information
    axes <- list(
      x = if (!is.null(plot$labels$x)) plot$labels$x else "Categories",
      y = if (!is.null(plot$labels$y)) plot$labels$y else ""
    )

    layer <- list(
      id = layer_id,
      type = layer_type,
      title = facet_title,
      axes = axes,
      data = combined_data,
      selectors = combined_selectors
    )

    layers[[1]] <- layer
  }

  list(
    id = subplot_id,
    layers = layers
  )
}

#' Organize subplots into 2D grid structure
#' @param subplots List of processed subplot data
#' @param panel_layout Panel layout information
#' @return 2D grid structure
organize_facet_grid <- function(subplots, panel_layout) {
  # Determine grid dimensions from built layout
  max_row <- max(panel_layout$ROW)
  max_col <- max(panel_layout$COL)

  # Create 2D grid
  grid <- list()
  for (row in seq_len(max_row)) {
    grid[[row]] <- list()
    for (col in seq_len(max_col)) {
      grid[[row]][[col]] <- NULL
    }
  }

  # Fill in the grid using built layout positions
  for (i in seq_along(subplots)) {
    panel_info <- panel_layout[i, ]
    subplot <- subplots[[i]]
    grid[[panel_info$ROW]][[panel_info$COL]] <- subplot
  }

  grid
}

#' Combine data from multiple layers in facet processing
#' @param layer_results List of layer processing results
#' @return Combined data
combine_facet_layer_data <- function(layer_results) {
  combined_data <- list()

  for (result in layer_results) {
    if (!is.null(result) && !is.null(result$data)) {
      if (is.list(result$data) && length(result$data) > 0) {
        combined_data <- c(combined_data, result$data)
      } else {
        combined_data <- c(combined_data, list(result$data))
      }
    }
  }

  combined_data
}

#' Combine selectors from multiple layers in facet processing
#' @param layer_results List of layer processing results
#' @return Combined selectors
combine_facet_layer_selectors <- function(layer_results) {
  combined_selectors <- list()

  for (result in layer_results) {
    if (!is.null(result) && !is.null(result$selectors)) {
      combined_selectors <- c(combined_selectors, result$selectors)
    }
  }

  combined_selectors
}

#' Map visual panel position to DOM panel name
#'
#' This function handles the mismatch between visual layout order (row-major)
#' and DOM element generation order (column-major) in gridSVG.
#'
#' Visual layout (row-major):
#'  1  2
#'  3  4
#'
#' DOM order (column-major):
#'  1  3
#'  2  4
#'
#' @param panel_info Panel information from layout
#' @param gtable Gtable object
#' @return Gtable panel name or NULL if not found
map_visual_to_dom_panel <- function(panel_info, gtable) {
  # Get all panel names from gtable
  panel_names <- gtable$layout$name[grepl("^panel-", gtable$layout$name)]

  if (length(panel_names) == 0) {
    return(NULL)
  }

  # Extract ROW and COL from panel names to determine grid dimensions
  panel_coords <- strsplit(gsub("panel-", "", panel_names), "-")
  rows <- as.numeric(sapply(panel_coords, function(x) x[1]))
  cols <- as.numeric(sapply(panel_coords, function(x) x[2]))

  max_row <- max(rows)
  max_col <- max(cols)

  # Convert visual position (row-major) to DOM position (column-major)
  visual_row <- as.numeric(panel_info$ROW)
  visual_col <- as.numeric(panel_info$COL)

  # DOM order is column-major: (1,1), (2,1), (3,1), (1,2), (2,2), (3,2), etc.
  # Visual order is row-major: (1,1), (1,2), (1,3), (2,1), (2,2), (2,3), etc.

  # Calculate the index in row-major order (visual)
  visual_index <- (visual_row - 1) * max_col + visual_col

  # Convert to column-major order (DOM)
  dom_col <- ((visual_index - 1) %/% max_row) + 1
  dom_row <- ((visual_index - 1) %% max_row) + 1

  # Generate the expected DOM panel name
  expected_dom_name <- paste0("panel-", dom_row, "-", dom_col)

  # Check if this panel name exists in gtable
  if (expected_dom_name %in% gtable$layout$name) {
    return(expected_dom_name)
  }

  # Fallback: try direct mapping
  expected_name <- paste0("panel-", visual_row, "-", visual_col)
  if (expected_name %in% gtable$layout$name) {
    return(expected_name)
  }

  # Final fallback: return first available panel
  if (length(panel_names) > 0) {
    return(panel_names[1])
  }

  NULL
}
