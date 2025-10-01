#' Facet Processor
#'
#' Handles faceted plots by extracting individual panels and processing them
#' using existing layer processors. Creates temporary plots for each panel
#' to reuse existing processing logic.
#'
#' @keywords internal
FacetProcessor <- R6::R6Class("FacetProcessor",
  public = list(
    #' @field plot The original faceted ggplot2 object
    plot = NULL,
    
    #' @field built Built plot data from ggplot2::ggplot_build()
    built = NULL,
    
    #' @field gt Gtable object from ggplot2::ggplotGrob()
    gt = NULL,
    
    #' @field layout Layout information
    layout = NULL,
    
    #' @field scale_mapping Scale mapping for converting numeric positions to labels
    scale_mapping = NULL,
    
    #' @description Initialize the facet processor
    #' @param plot The faceted ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    initialize = function(plot, layout, built = NULL, gt = NULL) {
      self$plot <- plot
      self$layout <- layout
      self$built <- built %||% ggplot2::ggplot_build(plot)
      self$gt <- gt %||% ggplot2::ggplotGrob(plot)
      self$scale_mapping <- extract_scale_mapping(self$built)
    },
    
    #' @description Process the faceted plot
    #' @return List with subplots data in 2D grid format
    process = function() {
      # Extract panel information
      panels <- self$extract_panels()
      
      # Process each panel
      subplots <- list()
      for (i in seq_along(panels)) {
        panel <- panels[[i]]
        subplot_data <- self$process_panel(panel)
        subplots[[i]] <- subplot_data
      }
      
      # Organize into 2D grid structure
      grid_structure <- self$organize_into_grid(subplots, panels)
      
      list(
        subplots = grid_structure,
        scale_mapping = self$scale_mapping
      )
    },
    
    #' @description Extract panel information from the faceted plot
    #' @return List of panel information
    extract_panels = function() {
      # Get panel layout information
      panel_layout <- self$built$layout$layout
      
      # Get actual panel names from gtable
      gtable_panel_names <- self$gt$layout$name[grepl("^panel-", self$gt$layout$name)]
      
      
      panels <- list()
      for (i in seq_len(nrow(panel_layout))) {
        panel_info <- panel_layout[i, ]
        
        # Extract panel data
        panel_data <- self$built$data[[1]][self$built$data[[1]]$PANEL == panel_info$PANEL, ]
        
        # Get facet group information
        facet_groups <- self$get_facet_groups(panel_info)
        
        # Map based on visual position (ROW/COL) - find the gtable panel that matches this position
        # The gtable panel names are in column-major order, but we need to match by visual position
        expected_panel_name <- paste0("panel-", panel_info$ROW, "-", panel_info$COL)
        gtable_panel_name <- NULL
        if (expected_panel_name %in% gtable_panel_names) {
          gtable_panel_name <- expected_panel_name
          grob_id <- self$get_panel_grob_id_from_name(gtable_panel_name)
        } else {
          # Fallback to old method
          grob_id <- self$get_panel_grob_id(panel_info)
        }
        
        
        
        panels[[i]] <- list(
          panel_id = panel_info$PANEL,
          row = panel_info$ROW,
          col = panel_info$COL,
          data = panel_data,
          facet_groups = facet_groups,
          grob_id = grob_id,
          panel_info = panel_info,
          gtable_panel_name = if (i <= length(gtable_panel_names)) gtable_panel_names[i] else NULL
        )
      }
      
      panels
    },
    
    #' @description Process a single panel
    #' @param panel Panel information
    #' @return Processed panel data
    process_panel = function(panel) {
      # Process layers using existing processors with panel-specific data
      layer_results <- list()
      
      for (layer_idx in seq_along(self$plot$layers)) {
        layer <- self$plot$layers[[layer_idx]]
        processor <- self$create_layer_processor(layer, layer_idx)
        
        if (!is.null(processor)) {
          # Process the layer with scale mapping and grob ID
          result <- processor$process(
            self$plot,  # Use original plot
            self$layout,
            self$built,  # Use original built data
            self$gt,     # Use original gtable
            scale_mapping = self$scale_mapping,
            grob_id = panel$grob_id,
            panel_id = panel$panel_id
          )
          
          layer_results[[layer_idx]] <- result
        }
      }
      
      # Combine layer results
      combined_data <- self$combine_layer_data(layer_results)
      combined_selectors <- self$combine_layer_selectors(layer_results)
      
      # Create proper subplot structure
      subplot_id <- paste0("maidr-subplot-", as.integer(Sys.time()), "-", panel$panel_id)
      
      # Create layers structure
      layers <- list()
      if (length(combined_data) > 0) {
        layer_id <- paste0("maidr-layer-", as.integer(Sys.time()), "-", panel$panel_id)
        
        # Determine layer type from the first layer processor
        layer_type <- "bar"  # Default
        if (length(self$plot$layers) > 0) {
          geom_type <- class(self$plot$layers[[1]]$geom)[1]
          layer_type <- switch(geom_type,
            "GeomBar" = "bar",
            "GeomCol" = "bar", 
            "GeomPoint" = "point",
            "GeomLine" = "line",
            "GeomPath" = "line",
            "bar"  # Default
          )
        }
        
        # Create facet title from facet groups
        facet_title <- ""
        if (length(panel$facet_groups) > 0) {
          facet_title <- paste(panel$facet_groups, collapse = " & ")
        }
        
        # Create axes information
        axes <- list(
          x = if (!is.null(self$plot$labels$x)) self$plot$labels$x else "Categories",
          y = if (!is.null(self$plot$labels$y)) self$plot$labels$y else ""
        )
        
        # Keep selectors as returned by processors
        selector_value <- combined_selectors
        
        layer <- list(
          id = layer_id,
          type = layer_type,
          title = facet_title,
          axes = axes,
          data = combined_data,
          selectors = selector_value
        )
        
        layers[[1]] <- layer
      }
      
      list(
        id = subplot_id,
        layers = layers
      )
    },
    
    #' @description Create a temporary plot for a single panel
    #' @param panel Panel information
    #' @return Temporary ggplot2 object
    create_temp_plot = function(panel) {
      # Create a new plot with the same structure but different data
      temp_plot <- ggplot2::ggplot(panel$data, self$plot$mapping)
      
      # Add layers
      for (layer in self$plot$layers) {
        temp_plot <- temp_plot + layer
      }
      
      # Add theme and coordinates (skip labels for now)
      if (!is.null(self$plot$theme)) {
        temp_plot <- temp_plot + self$plot$theme
      }
      if (!is.null(self$plot$coordinates)) {
        temp_plot <- temp_plot + self$plot$coordinates
      }
      
      # Remove faceting
      temp_plot$facet <- ggplot2::facet_null()
      
      temp_plot
    },
    
    #' @description Create appropriate layer processor for a layer
    #' @param layer The ggplot2 layer
    #' @param layer_idx Layer index
    #' @return Layer processor instance or NULL
    create_layer_processor = function(layer, layer_idx) {
      layer_info <- list(index = layer_idx, type = class(layer$geom)[1])
      
      # Map geom types to processor classes - only support working types for now
      geom_type <- class(layer$geom)[1]
      
      switch(geom_type,
        "GeomBar" = BarLayerProcessor$new(layer_info),
        "GeomCol" = BarLayerProcessor$new(layer_info),
        "GeomPoint" = PointLayerProcessor$new(layer_info),
        "GeomLine" = LineLayerProcessor$new(layer_info),
        "GeomPath" = LineLayerProcessor$new(layer_info),
        # For now, return NULL for unsupported types
        NULL
      )
    },
    
    #' @description Get facet group information for a panel
    #' @param panel_info Panel information from layout
    #' @return List of facet group information
    get_facet_groups = function(panel_info) {
      facet_groups <- list()
      
      # Extract facet variable information
      if (!is.null(self$built$layout$facet)) {
        facet_vars <- names(self$built$layout$facet$params$facets)
        if (length(facet_vars) == 0) {
          facet_vars <- names(self$built$layout$facet$params$rows)
        }
        
        for (var in facet_vars) {
          if (var %in% names(panel_info)) {
            facet_groups[[var]] <- as.character(panel_info[[var]])
          }
        }
      }
      
      facet_groups
    },
    
    #' @description Get grob ID for a specific panel
    #' @param panel_info Panel information with row and col
    #' @return Grob ID string
    get_panel_grob_id_from_name = function(panel_name) {
      # Find the panel grob in the gtable
      panel_grobs <- which(self$gt$layout$name == panel_name)
      
      if (length(panel_grobs) > 0) {
        # Get the first child grob that contains the actual geometry
        panel_grob <- self$gt$grobs[[panel_grobs[1]]]
        
        if (inherits(panel_grob, "gTree") && length(panel_grob$children) > 0) {
          child_names <- names(panel_grob$children)
          
          # Look for geom_rect grobs (for bar plots)
          rect_children <- child_names[grepl("geom_rect", child_names)]
          if (length(rect_children) > 0) {
            return(rect_children[1])
          }
          
          # Look for geom_point grobs (for point plots)
          point_children <- child_names[grepl("geom_point", child_names)]
          if (length(point_children) > 0) {
            return(point_children[1])
          }
          
          # Look for GRID.polyline grobs (for line plots)
          polyline_children <- child_names[grepl("GRID\\.polyline", child_names)]
          if (length(polyline_children) > 0) {
            return(polyline_children[1])
          }
          
          # Look for geom_line grobs (for line plots)
          line_children <- child_names[grepl("geom_line", child_names)]
          if (length(line_children) > 0) {
            return(line_children[1])
          }
          
          # Return the first child grob name
          return(child_names[1])
        }
      }
      
      # Fallback to panel name
      panel_name
    },
    
    get_panel_grob_id = function(panel_info) {
      # Use row-col pattern for panel naming
      panel_name <- paste0("panel-", panel_info$ROW, "-", panel_info$COL)
      
      # Find the panel grob in the gtable
      panel_grobs <- which(self$gt$layout$name == panel_name)
      
      if (length(panel_grobs) > 0) {
        # Get the first child grob that contains the actual geometry
        panel_grob <- self$gt$grobs[[panel_grobs[1]]]
        
        if (inherits(panel_grob, "gTree") && length(panel_grob$children) > 0) {
          child_names <- names(panel_grob$children)
          
          # Look for geom_rect grobs (for bar plots)
          rect_children <- child_names[grepl("geom_rect", child_names)]
          if (length(rect_children) > 0) {
            return(rect_children[1])
          }
          
          # Look for geom_point grobs (for point plots)
          point_children <- child_names[grepl("geom_point", child_names)]
          if (length(point_children) > 0) {
            return(point_children[1])
          }
          
          # Look for GRID.polyline grobs (for line plots)
          polyline_children <- child_names[grepl("GRID\\.polyline", child_names)]
          if (length(polyline_children) > 0) {
            return(polyline_children[1])
          }
          
          # Look for geom_line grobs (for line plots)
          line_children <- child_names[grepl("geom_line", child_names)]
          if (length(line_children) > 0) {
            return(line_children[1])
          }
          
          # Return the first child grob name
          return(child_names[1])
        }
      }
      
      # Fallback to row-col pattern
      panel_name
    },
    
    #' @description Combine data from multiple layers
    #' @param layer_results List of layer processing results
    #' @return Combined data
    combine_layer_data = function(layer_results) {
      combined_data <- list()
      
      for (result in layer_results) {
        if (!is.null(result) && !is.null(result$data)) {
          if (is.list(result$data) && length(result$data) > 0) {
            # For arrays of data points
            combined_data <- c(combined_data, result$data)
          } else {
            # For single data objects
            combined_data <- c(combined_data, list(result$data))
          }
        }
      }
      
      combined_data
    },
    
    #' @description Combine selectors from multiple layers
    #' @param layer_results List of layer processing results
    #' @return Combined selectors
    combine_layer_selectors = function(layer_results) {
      combined_selectors <- list()
      
      for (result in layer_results) {
        if (!is.null(result) && !is.null(result$selectors)) {
          combined_selectors <- c(combined_selectors, result$selectors)
        }
      }
      
      combined_selectors
    },
    
    #' @description Organize subplots into 2D grid structure
    #' @param subplots List of processed subplot data
    #' @param panels List of panel information
    #' @return 2D grid structure
    organize_into_grid = function(subplots, panels) {
      # Determine grid dimensions from built layout
      max_row <- max(sapply(panels, function(p) p$row))
      max_col <- max(sapply(panels, function(p) p$col))
      
      # Create 2D grid
      grid <- list()
      for (row in seq_len(max_row)) {
        grid[[row]] <- list()
        for (col in seq_len(max_col)) {
          grid[[row]][[col]] <- NULL
        }
      }
      
      # Fill in the grid using built layout positions (which are correct)
      for (i in seq_along(subplots)) {
        panel <- panels[[i]]
        subplot <- subplots[[i]]
        
        
        # Use built layout positions which match the data order
        grid[[panel$row]][[panel$col]] <- subplot
      }
      
      
      grid
    }
  )
)
