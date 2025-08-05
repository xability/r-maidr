#' Smooth Layer Processor
#' 
#' Processes smooth plot layers with complete logic included
#' 
#' @export
SmoothLayerProcessor <- R6::R6Class("SmoothLayerProcessor",
  inherit = LayerProcessor,
  
  public = list(
    process = function(plot, layout, gt = NULL) {
      data <- self$extract_data(plot)
      selectors <- self$generate_selectors(plot, gt)
      
      return(list(
        data = data,
        selectors = selectors
      ))
    },
    
    #' Extract data implementation
    extract_data_impl = function(plot) {
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
      svg_coords <- self$extract_svg_coordinates(plot, smooth_layers[1])

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
      return(list(data_points))
    },
    
    #' Extract SVG coordinates for smooth curves using gridSVG coordinate system
    extract_svg_coordinates = function(plot, layer_index) {
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
    },
    
    generate_selectors = function(plot, gt = NULL) {
      # Convert to gtable to get grob information if not provided
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }
    
      # Find polyline grobs using the same logic as original bar.R
      grobs <- self$find_polyline_grobs(gt)
    
      # For smooth plots, we expect only one grob
      if (length(grobs) == 0) {
        return(list())
      }
    
      # Use the first (and only) grob
      grob <- grobs[[1]]
      grob_name <- grob$name
      
      # Extract the numeric part from grob name
      # (e.g., "264" from "GRID.polyline.264")
      layer_id <- gsub("GRID\\.polyline\\.", "", grob_name)
    
      # Create selector for this smooth line
      selector <- self$make_polyline_selector(layer_id)
      
      return(list(selector))
    },
    
    #' Make polyline selector (same as original bar.R pattern)
    make_polyline_selector = function(layer_id) {
      grob_id <- paste0("GRID.polyline.", layer_id, ".1.1")
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
      paste0("#", escaped_grob_id)
    },
    
    #' Find polyline grobs from a gtable (same as original bar.R)
    find_polyline_grobs = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        stop("No panel found in gtable")
      }
    
      panel_grob <- gt$grobs[[panel_index]]
    
      if (!inherits(panel_grob, "gTree")) {
        stop("Panel grob is not a gTree")
      }
    
      find_polyline_grobs_recursive <- function(grob) {
        polyline_grobs <- list()
    
        # Look specifically for GRID.polyline grobs
        if (!is.null(grob$name) && grepl("GRID\\.polyline", grob$name)) {
          polyline_grobs[[length(polyline_grobs) + 1]] <- grob
        }
    
        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            polyline_grobs <- c(polyline_grobs, find_polyline_grobs_recursive(grob[[i]]))
          }
        }
    
        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            polyline_grobs <- c(polyline_grobs, find_polyline_grobs_recursive(grob$children[[i]]))
          }
        }
    
        return(polyline_grobs)
      }
    
      polyline_grobs <- find_polyline_grobs_recursive(panel_grob)
      
      # Prioritize the most specific grob (with .1.1 suffix)
      if (length(polyline_grobs) > 0) {
        # Sort by name length (longer names are more specific)
        grob_names <- sapply(polyline_grobs, function(g) g$name)
        polyline_grobs <- polyline_grobs[order(nchar(grob_names), decreasing = TRUE)]
      }
      
      return(polyline_grobs)
    }
  )
) 