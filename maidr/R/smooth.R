#' Smooth curve processing functions
#'
#' This file contains functions for processing smooth curves (density curves)
#' and extracting smooth-specific data structures.

#' Extract smooth curve data from ggplot object
#' @param plot A ggplot2 object
#' @return List of smooth curve data points with proper SmoothPoint structure
#' @export
extract_smooth_data <- function(plot) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  # Build the plot to get data
  built <- ggplot2::ggplot_build(plot)

  # Find smooth curve layers
  smooth_layers <- which(sapply(plot$layers, function(layer) {
    inherits(layer$geom, "GeomDensity") || 
    (inherits(layer$geom, "GeomLine") && inherits(layer$stat, "StatDensity"))
  }))

  if (length(smooth_layers) == 0) {
    stop("No smooth curve layers found in plot")
  }

  # Extract data from first smooth layer
  built_data <- built$data[[smooth_layers[1]]]

  # Convert to SVG coordinates using gridSVG
  svg_coords <- extract_svg_coordinates(plot, smooth_layers[1])

  # Build smooth curve data points with proper SmoothPoint structure
  data_points <- list()
  if (nrow(built_data) > 0) {
    for (j in seq_len(nrow(built_data))) {
      point <- list()
      
      # Add x and y values from built data
      point$x <- built_data$x[j]
      point$y <- built_data$y[j]
      
      # Add SVG coordinates if available
      if (length(svg_coords) >= j) {
        point$svg_x <- svg_coords[[j]]$svg_x  # Use transformed SVG coordinates
        point$svg_y <- svg_coords[[j]]$svg_y  # Use transformed SVG coordinates
      }
      
      data_points[[j]] <- point
    }
  }
  
  # Convert list to array for backend compatibility
  # The backend expects data to be an array that can be mapped over
  # The structure should be [[point1, point2, ...]] not [point1, point2, ...]
  # This matches the Python maidr output structure
  # We need to wrap the data_points list in another list to create the nested array structure
  list(data_points)
}

#' Extract SVG coordinates for smooth curves using gridSVG coordinate system
#' @param plot A ggplot2 object
#' @param layer_index Index of the smooth layer
#' @return List of SVG coordinate pairs
#' @keywords internal
extract_svg_coordinates <- function(plot, layer_index) {
  # Build the plot to get coordinate information
  built <- ggplot2::ggplot_build(plot)
  built_data <- built$data[[layer_index]]
  
  # Get panel parameters which contain the actual coordinate ranges
  panel_params <- built$layout$panel_params[[1]]
  
  if (!is.null(panel_params)) {
    # Get data ranges from panel parameters
    x_range <- panel_params$x.range
    y_range <- panel_params$y.range
    
    # Create a temporary SVG to extract coordinate information
    temp_svg_file <- tempfile(fileext = ".svg")
    
    # Create the plot as a gtable
    gt <- ggplot2::ggplotGrob(plot)
    
    # Export with coordinate information
    grid::grid.newpage()
    grid::grid.draw(gt)
    gridSVG::grid.export(temp_svg_file, exportCoords = "inline", exportMappings = "inline")
    
    svg_content <- readLines(temp_svg_file, warn = FALSE)
    
    # Extract coordinate information from JavaScript
    coord_lines <- grep("gridSVGCoords", svg_content, value = TRUE)
    
    if (length(coord_lines) > 0) {
      # Extract JavaScript coordinate data
      js_line <- coord_lines[1]
      js_line <- gsub("var gridSVGCoords = ", "", js_line)
      js_line <- gsub(";$", "", js_line)
      
      tryCatch({
        coords_data <- jsonlite::fromJSON(js_line)
        
        # Find panel viewport
        panel_names <- names(coords_data)[grep("panel", names(coords_data))]
        
        if (length(panel_names) > 0) {
          panel_name <- panel_names[1]
          panel_info <- coords_data[[panel_name]]
          
          # Initialize gridSVG coordinates
          gridSVG::gridSVGCoords(coords_data)
          
          # Transform data coordinates to SVG coordinates
          svg_coords <- list()
          
          for (i in seq_len(nrow(built_data))) {
            x_data <- built_data$x[i]
            y_data <- built_data$y[i]
            
            # Convert using gridSVG's coordinate system
            # First convert to normalized coordinates (0-1)
            x_norm <- (x_data - x_range[1]) / (x_range[2] - x_range[1])
            y_norm <- (y_data - y_range[1]) / (y_range[2] - y_range[1])
            
            # Then convert normalized coordinates to SVG coordinates
            svg_x <- panel_info$x + x_norm * panel_info$width
            svg_y <- panel_info$y + y_norm * panel_info$height  # Don't flip Y axis
            
            svg_coords[[i]] <- list(
              x = x_data,
              y = y_data,
              svg_x = svg_x,
              svg_y = svg_y
            )
          }
          
          unlink(temp_svg_file)
          return(svg_coords)
        }
      }, error = function(e) {
        # Could not parse coordinate information from SVG
      })
    }
    
    unlink(temp_svg_file)
  } 
  
  # Fallback: Return empty list if gridSVG approach fails
  list()
}

#' Process smooth curve plot using factory pattern
#' @param plot A ggplot2 object
#' @param ... Additional arguments
#' @return A smooth_plot_data object
#' @keywords internal
process_smooth_plot <- function(plot, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  layout <- extract_layout(plot)
  data <- extract_smooth_data(plot)
  selectors <- make_smooth_selectors(plot)

  smooth_plot_data(data = data, layout = layout, selectors = selectors)
}

#' Extract smooth layer data from plot processor
#' @param plot_processor The plot processor object
#' @param layer_id The layer ID
#' @return Smooth layer data structure (nested array format)
#' @keywords internal
extract_smooth_layer_data <- function(plot_processor, layer_id) {
  if (is.null(plot_processor$data)) {
    return(list())
  }
  
  # For smooth plots, keep the nested array structure
  if (length(plot_processor$data) > 0) {
    return(plot_processor$data)
  }
  
  return(list())
}

#' Find polyline grobs from a gtable
#' @param gt A gtable object (from ggplotGrob)
#' @return List of polyline grobs
#' @keywords internal
find_polyline_grobs <- function(gt) {
  find_polyline_grobs_recursive <- function(grob) {
    polyline_grobs <- list()

    if (inherits(grob, "polylineGrob") ||
        (inherits(grob, "polyline") && !inherits(grob, "zeroGrob"))) {
      polyline_grobs[[length(polyline_grobs) + 1]] <- grob
    }

    if (inherits(grob, "gList")) {
      for (i in seq_along(grob)) {
        polyline_grobs <- c(polyline_grobs, find_polyline_grobs_recursive(grob[[i]]))
      }
    }

    if (inherits(grob, "gTree")) {
      for (i in seq_along(grob$children)) {
        polyline_grobs <- c(
          polyline_grobs,
          find_polyline_grobs_recursive(grob$children[[i]])
        )
      }
    }

    polyline_grobs
  }

  # Search through ALL grobs in the gtable, not just the panel
  all_polylines <- list()
  for (i in seq_along(gt$grobs)) {
    grob <- gt$grobs[[i]]
    polyline_grobs <- find_polyline_grobs_recursive(grob)
    all_polylines <- c(all_polylines, polyline_grobs)
  }

  # Return all polyline grobs - let the calling function determine which ones are density curves
  # This is more robust as it doesn't make assumptions about colors or names
  all_polylines
}

#' Extract polyline layer IDs from gtable
#' @param gt A gtable object
#' @return Character vector of layer IDs
#' @keywords internal
extract_polyline_layer_ids_from_gtable <- function(gt) {
  # Find polyline grobs
  grobs <- find_polyline_grobs(gt)
  
  # Extract layer IDs from grob names, filtering out grid lines
  layer_ids <- character(0)
  for (i in seq_along(grobs)) {
    grob <- grobs[[i]]
    grob_name <- grob$name
    
    # Skip grid lines (they have "panel.grid" in their name)
    if (grepl("panel\\.grid", grob_name)) {
      next
    }
    
    # Extract the numeric part from grob name
    # (e.g., "2" from "GRID.polyline.2")
    if (grepl("^GRID\\.polyline\\.", grob_name)) {
      layer_id <- gsub("GRID\\.polyline\\.", "", grob_name)
      layer_id <- gsub("\\..*$", "", layer_id)  # Remove everything after first dot
      layer_ids <- c(layer_ids, layer_id)
    }
  }
  
  # Return unique layer IDs
  unique(layer_ids)
}

#' Make smooth curve selector
#' @param layer_id The layer ID
#' @return CSS selector string
#' @keywords internal
make_smooth_selector <- function(layer_id) {
  grob_id <- paste0("GRID.polyline.", layer_id, ".1.1")
  escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
  paste0("#", escaped_grob_id)
}

#' Make smooth curve selectors
#' @param plot A ggplot2 object
#' @return List of CSS selector strings
#' @keywords internal
make_smooth_selectors <- function(plot) {
  # Convert to gtable to get grob information
  gt <- ggplot2::ggplotGrob(plot)
  
  # Use the same layer ID extraction logic as extract_layer_ids
  layer_ids <- extract_polyline_layer_ids_from_gtable(gt)
  
  # Create selectors for all found layer IDs
  selectors <- character(0)
  for (layer_id in layer_ids) {
    selector <- make_smooth_selector(layer_id)
    selectors <- c(selectors, selector)
  }

  selectors
}

#' Create smooth plot data object
#' @param data List of smooth curve data points
#' @param layout Layout information
#' @param selectors List of CSS selectors
#' @return A smooth_plot_data object
#' @export
smooth_plot_data <- function(data, layout, selectors) {
  structure(
    list(
      type = "smooth",
      data = data,
      layout = layout,
      selectors = selectors
    ),
    class = c("smooth_plot_data", "plot_data")
  )
} 