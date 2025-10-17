# MAIDR ggplot2 System Implementation Guide

## Overview

This document provides a comprehensive guide to understanding the ggplot2 system implementation in MAIDR, including the complete processing flow, layer processors, and how to add new plotting functionalities.

## Architecture Overview

The ggplot2 system in MAIDR consists of several key components that work together to process ggplot2 objects and generate interactive SVG visualizations with accessibility features.

```
ggplot2 Plot Object
        ↓
   Ggplot2Adapter (Detection & Orchestration)
        ↓
   Ggplot2PlotOrchestrator (Coordination)
        ↓
   Ggplot2ProcessorFactory (Processor Creation)
        ↓
   Layer Processors (Data Extraction & Selector Generation)
        ↓
   Enhanced SVG Output
```

## Core Components

### 1. Ggplot2Adapter

**File:** `maidr/R/ggplot2_adapter.R`

The adapter is the entry point for all ggplot2 processing. It implements the `SystemAdapter` interface and provides ggplot2-specific functionality.

#### Key Responsibilities:
- **System Detection**: Determine if an object is a ggplot2 plot
- **Layer Type Detection**: Identify the type of each layer (bar, line, point, etc.)
- **Orchestrator Creation**: Create the appropriate orchestrator for processing
- **Plot Analysis**: Extract metadata and determine plot characteristics

#### Core Methods:

```r
Ggplot2Adapter <- R6::R6Class("Ggplot2Adapter",
  inherit = SystemAdapter,
  public = list(
    # System detection
    can_handle = function(plot_object) {
      inherits(plot_object, "ggplot")
    },
    
    # Layer type detection with sophisticated logic
    detect_layer_type = function(layer, plot_object) {
      geom_class <- class(layer$geom)[1]
      stat_class <- class(layer$stat)[1]
      position_class <- class(layer$position)[1]
      
      # Complex detection logic for different plot types
      if (geom_class %in% c("GeomLine", "GeomPath")) return("line")
      if (geom_class == "GeomSmooth" || stat_class == "StatDensity") return("smooth")
      if (geom_class %in% c("GeomBar", "GeomCol")) {
        if (stat_class == "StatBin") return("hist")
        if (position_class %in% c("PositionDodge", "PositionDodge2")) return("dodged_bar")
        if (position_class %in% c("PositionStack", "PositionFill")) {
          # Check for fill mapping to determine stacked vs regular bar
          layer_mapping <- layer$mapping
          plot_mapping <- plot_object$mapping
          has_fill <- (!is.null(layer_mapping) && !is.null(layer_mapping$fill)) ||
            (!is.null(plot_mapping) && !is.null(plot_mapping$fill))
          if (has_fill) return("stacked_bar")
        }
        return("bar")
      }
      if (geom_class == "GeomTile") return("heat")
      if (geom_class == "GeomPoint") return("point")
      if (geom_class == "GeomBoxplot") return("box")
      return("unknown")
    },
    
    # Orchestrator creation
    create_orchestrator = function(plot_object) {
      Ggplot2PlotOrchestrator$new(plot_object)
    }
  )
)
```

### 2. Ggplot2PlotOrchestrator

**File:** `maidr/R/ggplot2_plot_orchestrator.R`

The orchestrator coordinates the entire processing pipeline for ggplot2 plots. It handles different plot types (single, faceted, patchwork) and manages layer processing.

#### Key Responsibilities:
- **Plot Type Detection**: Determine if plot is single, faceted, or patchwork
- **Layer Management**: Detect and process all layers in the plot
- **Data Coordination**: Combine results from multiple layers
- **Layout Management**: Handle plot layout and structure

#### Core Processing Flow:

```r
Ggplot2PlotOrchestrator <- R6::R6Class("Ggplot2PlotOrchestrator",
  private = list(
    .plot = NULL,
    .layers = list(),
    .layer_processors = list(),
    .combined_data = list(),
    .combined_selectors = list(),
    .layout = NULL,
    .gtable = NULL,
    .adapter = NULL
  ),
  public = list(
    initialize = function(plot) {
      private$.plot <- plot
      registry <- get_global_registry()
      system_name <- registry$detect_system(plot)
      private$.adapter <- registry$get_adapter(system_name)

      # Route to appropriate processing method
      if (self$is_patchwork_plot()) {
        self$process_patchwork_plot()
      } else if (self$is_faceted_plot()) {
        self$process_faceted_plot()
      } else {
        # Single plot processing
        self$detect_layers()
        self$create_layer_processors()
        self$process_layers()
      }
    },
    
    # Layer detection and processing
    detect_layers = function() {
      private$.layers <- private$.plot$layers
    },
    
    create_layer_processors = function() {
      for (i in seq_along(private$.layers)) {
        layer <- private$.layers[[i]]
        layer_info <- list(index = i, type = class(layer$geom)[1])
        processor <- self$create_unified_layer_processor(layer_info)
        private$.layer_processors[[i]] <- processor
      }
    },
    
    process_layers = function() {
      layer_results <- list()
      plot_for_render <- private$.plot
      built_final <- ggplot2::ggplot_build(plot_for_render)
      
      for (i in seq_along(private$.layer_processors)) {
        processor <- private$.layer_processors[[i]]
        result <- processor$process(plot_for_render, private$.layout, 
                                  built = built_final, gt = private$.gtable)
        processor$set_last_result(result)
        layer_results[[i]] <- result
      }
      
      self$combine_layer_results(layer_results)
    }
  )
)
```

### 3. Ggplot2ProcessorFactory

**File:** `maidr/R/ggplot2_processor_factory.R`

The factory creates appropriate layer processors based on layer type. It implements the factory pattern to decouple layer type detection from processor creation.

#### Core Implementation:

```r
Ggplot2ProcessorFactory <- R6::R6Class("Ggplot2ProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    create_processor = function(layer_type, layer_info) {
      switch(layer_type,
        "bar" = Ggplot2BarLayerProcessor$new(layer_info),
        "dodged_bar" = Ggplot2DodgedBarLayerProcessor$new(layer_info),
        "stacked_bar" = Ggplot2StackedBarLayerProcessor$new(layer_info),
        "line" = Ggplot2LineLayerProcessor$new(layer_info),
        "point" = Ggplot2PointLayerProcessor$new(layer_info),
        "hist" = Ggplot2HistogramLayerProcessor$new(layer_info),
        "smooth" = Ggplot2SmoothLayerProcessor$new(layer_info),
        "heat" = Ggplot2HeatmapLayerProcessor$new(layer_info),
        "box" = Ggplot2BoxplotLayerProcessor$new(layer_info),
        # Default to unknown processor
        Ggplot2UnknownLayerProcessor$new(layer_info)
      )
    }
  )
)
```

## Layer Processors

Layer processors are the core components that handle individual plot layers. Each processor type is specialized for a specific plot type and implements the `LayerProcessor` interface.

### LayerProcessor Interface

**File:** `maidr/R/layer_processor.R`

```r
LayerProcessor <- R6::R6Class("LayerProcessor",
  public = list(
    layer_info = NULL,
    
    # Core processing method
    process = function(plot, layout, built = NULL, gt = NULL, ...) {
      data <- self$extract_data(plot, built, ...)
      selectors <- self$generate_selectors(plot, gt, ...)
      list(data = data, selectors = selectors)
    },
    
    # Abstract methods to be implemented by subclasses
    extract_data = function(plot, built, ...) {
      stop("extract_data() method must be implemented by subclasses")
    },
    
    generate_selectors = function(plot, gt, ...) {
      stop("generate_selectors() method must be implemented by subclasses")
    }
  )
)
```

### Specific Layer Processors

#### 1. Bar Layer Processor

**File:** `maidr/R/ggplot2_bar_layer_processor.R`

Handles simple bar charts with data extraction and selector generation.

```r
Ggplot2BarLayerProcessor <- R6::R6Class("Ggplot2BarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    extract_data = function(plot, built, scale_mapping = NULL, panel_id = NULL) {
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      
      # Extract x and y values
      x_values <- layer_data$x
      y_values <- layer_data$y
      
      # Create data points
      data_points <- list()
      for (i in seq_along(x_values)) {
        data_points[[i]] <- list(
          x = x_values[i],
          y = y_values[i]
        )
      }
      
      data_points
    },
    
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      # Generate CSS selectors for SVG elements
      if (!is.null(grob_id)) {
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        selector <- paste0("#", escaped_grob_id, " rect")
        return(list(selector))
      } else {
        # Single plot selector generation
        if (is.null(gt)) gt <- ggplot2::ggplotGrob(plot)
        
        panel_index <- which(gt$layout$name == "panel")
        if (length(panel_index) == 0) return(list())
        
        panel_grob <- gt$grobs[[panel_index]]
        if (!inherits(panel_grob, "gTree")) return(list())
        
        # Find rect elements and generate selectors
        rect_names <- self$find_rect_names(panel_grob)
        selectors <- lapply(rect_names, function(name) {
          svg_id <- paste0(name, ".1")
          escaped <- gsub("\\.", "\\\\.", svg_id)
          paste0("#", escaped, " rect")
        })
        
        return(selectors)
      }
    }
  )
)
```

#### 2. Line Layer Processor

**File:** `maidr/R/ggplot2_line_layer_processor.R`

Handles line plots with support for single and multi-line scenarios.

```r
Ggplot2LineLayerProcessor <- R6::R6Class("Ggplot2LineLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    extract_data = function(plot, built, scale_mapping = NULL, panel_id = NULL) {
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      
      # Check if this is a multi-line plot
      if ("group" %in% names(layer_data)) {
        # Multi-line: group by group
        groups <- unique(layer_data$group)
        line_data <- list()
        
        for (group_val in groups) {
          group_data <- layer_data[layer_data$group == group_val, ]
          points <- list()
          
          for (i in seq_len(nrow(group_data))) {
            points[[i]] <- list(
              x = group_data$x[i],
              y = group_data$y[i]
            )
          }
          
          line_data[[length(line_data) + 1]] <- points
        }
        
        return(line_data)
      } else {
        # Single line: return as single series
        points <- list()
        for (i in seq_len(nrow(layer_data))) {
          points[[i]] <- list(
            x = layer_data$x[i],
            y = layer_data$y[i]
          )
        }
        return(list(points))
      }
    },
    
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      # Generate selectors for line elements
      if (!is.null(grob_id)) {
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        selector <- paste0("#", escaped_grob_id, " polyline")
        return(list(selector))
      } else {
        # Single plot selector generation
        if (is.null(gt)) gt <- ggplot2::ggplotGrob(plot)
        
        # Find polyline elements
        polyline_names <- self$find_polyline_names(gt)
        selectors <- lapply(polyline_names, function(name) {
          svg_id <- paste0(name, ".1")
          escaped <- gsub("\\.", "\\\\.", svg_id)
          paste0("#", escaped, " polyline")
        })
        
        return(selectors)
      }
    }
  )
)
```

#### 3. Boxplot Layer Processor

**File:** `maidr/R/ggplot2_boxplot_layer_processor.R`

Handles boxplots with complex selector generation for different boxplot elements.

```r
Ggplot2BoxplotLayerProcessor <- R6::R6Class("Ggplot2BoxplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, ...) {
      data <- self$extract_data(plot, built, ...)
      selectors <- self$generate_selectors(plot, gt, ...)
      orientation <- self$determine_orientation(plot)
      
      # Create axes information
      axes <- list(
        x = if (!is.null(layout$axes$x)) layout$axes$x else "",
        y = if (!is.null(layout$axes$y)) layout$axes$y else ""
      )
      
      list(
        data = data,
        selectors = selectors,
        axes = axes,
        orientation = orientation,
        type = "box"
      )
    },
    
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      # Complex selector generation for boxplot elements
      selectors <- list()
      
      if (!is.null(grob_id)) {
        # Generate selectors for different boxplot components
        base_id <- paste0(grob_id, ".1")
        escaped_id <- gsub("\\.", "\\\\.", base_id)
        
        selectors <- list(
          lowerOutliers = paste0("g#", escaped_id, " > use:nth-child(-n+2)"),
          upperOutliers = paste0("g#", escaped_id, " > use:nth-child(n+3)"),
          iq = paste0("g#", escaped_id, " > polygon"),
          q2 = paste0("g#", escaped_id, " > polyline"),
          min = paste0("g#", escaped_id, " > polyline:nth-child(2)"),
          max = paste0("g#", escaped_id, " > polyline:nth-child(1)")
        )
      }
      
      return(selectors)
    },
    
    determine_orientation = function(plot) {
      # Determine if boxplot is horizontal or vertical
      built <- ggplot2::ggplot_build(plot)
      layer_data <- built$data[[self$get_layer_index()]]
      
      # Analyze coordinates to determine orientation
      if ("x" %in% names(layer_data) && "y" %in% names(layer_data)) {
        x_range <- range(layer_data$x, na.rm = TRUE)
        y_range <- range(layer_data$y, na.rm = TRUE)
        
        # If y values are categorical (few unique values), it's horizontal
        if (length(unique(layer_data$y)) < length(unique(layer_data$x))) {
          return("horz")
        }
      }
      
      return("vert")
    }
  )
)
```

## Processing Flow for Different Plot Types

### 1. Single Plot Processing

```
ggplot2 Plot Object
        ↓
   Ggplot2PlotOrchestrator$initialize()
        ↓
   self$detect_layers()
        ↓
   self$create_layer_processors()
        ↓
   self$process_layers()
        ↓
   self$combine_layer_results()
        ↓
   Enhanced SVG Output
```

### 2. Faceted Plot Processing

```
Faceted ggplot2 Plot
        ↓
   Ggplot2PlotOrchestrator$initialize()
        ↓
   self$is_faceted_plot() -> TRUE
        ↓
   self$process_faceted_plot()
        ↓
   process_faceted_plot_data() [utility function]
        ↓
   For each panel:
     - Extract panel data
     - Create layer processors
     - Process layers
     - Generate selectors
        ↓
   Organize as 2D grid structure
        ↓
   Enhanced SVG Output
```

### 3. Patchwork Plot Processing

```
Patchwork Plot Object
        ↓
   Ggplot2PlotOrchestrator$initialize()
        ↓
   self$is_patchwork_plot() -> TRUE
        ↓
   self$process_patchwork_plot()
        ↓
   process_patchwork_plot_data() [utility function]
        ↓
   For each leaf plot:
     - Extract leaf plot
     - Create layer processors
     - Process layers
     - Generate selectors
        ↓
   Organize as 2D grid structure
        ↓
   Enhanced SVG Output
```

## Data Structure Formats

### Single Plot Data Structure:

```json
{
  "id": "maidr-plot-1234567890",
  "subplots": [
    [
      {
        "id": "maidr-subplot-1234567890",
        "layers": [
          {
            "id": 1,
            "selectors": ["#geom_rect\\.rect\\.2\\.1 rect"],
            "type": "bar",
            "data": [
              {"x": "A", "y": 30},
              {"x": "B", "y": 25}
            ],
            "title": {},
            "axes": {}
          }
        ]
      }
    ]
  ]
}
```

### Faceted Plot Data Structure:

```json
{
  "id": "maidr-plot-1234567890",
  "subplots": [
    [
      {
        "id": "maidr-subplot-1234567890-1-1",
        "layers": [...]
      },
      {
        "id": "maidr-subplot-1234567890-1-2",
        "layers": [...]
      }
    ],
    [
      {
        "id": "maidr-subplot-1234567890-2-1",
        "layers": [...]
      },
      {
        "id": "maidr-subplot-1234567890-2-2",
        "layers": [...]
      }
    ]
  ]
}
```

### Patchwork Plot Data Structure:

```json
{
  "id": "maidr-plot-1234567890",
  "subplots": [
    [
      {
        "id": "maidr-subplot-1234567890-1-1",
        "layers": [
          {
            "id": "maidr-layer-1",
            "type": "line",
            "title": "Line Plot: Random Data",
            "data": [[{"x": "1", "y": 2}, {"x": "2", "y": 4}]],
            "selectors": ["#GRID\\.polyline\\.1444\\.1\\.1"]
          }
        ]
      },
      {
        "id": "maidr-subplot-1234567890-1-2",
        "layers": [
          {
            "id": "maidr-layer-1",
            "type": "bar",
            "title": "Bar Plot: Random Values",
            "data": [{"x": "A", "y": 5.8471}, {"x": "B", "y": 1.1378}],
            "selectors": ["#geom_rect\\.rect\\.1478\\.1 rect"]
          }
        ]
      }
    ]
  ]
}
```

## Adding New Plot Types

### Step 1: Create Layer Processor

```r
# File: maidr/R/ggplot2_violin_layer_processor.R
Ggplot2ViolinLayerProcessor <- R6::R6Class("Ggplot2ViolinLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    extract_data = function(plot, built, scale_mapping = NULL, panel_id = NULL) {
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      
      # Extract violin plot data
      violin_data <- list()
      for (i in seq_len(nrow(layer_data))) {
        violin_data[[i]] <- list(
          x = layer_data$x[i],
          density = layer_data$density[i],
          scaled = layer_data$scaled[i],
          count = layer_data$count[i],
          n = layer_data$n[i],
          violinwidth = layer_data$violinwidth[i]
        )
      }
      
      violin_data
    },
    
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      # Generate selectors for violin plot elements
      if (!is.null(grob_id)) {
        full_grob_id <- paste0(grob_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", full_grob_id)
        selector <- paste0("#", escaped_grob_id, " polygon")
        return(list(selector))
      } else {
        # Single plot selector generation
        if (is.null(gt)) gt <- ggplot2::ggplotGrob(plot)
        
        # Find polygon elements for violin shapes
        polygon_names <- self$find_polygon_names(gt)
        selectors <- lapply(polygon_names, function(name) {
          svg_id <- paste0(name, ".1")
          escaped <- gsub("\\.", "\\\\.", svg_id)
          paste0("#", escaped, " polygon")
        })
        
        return(selectors)
      }
    }
  )
)
```

### Step 2: Update Processor Factory

```r
# In Ggplot2ProcessorFactory$create_processor()
create_processor = function(layer_type, layer_info) {
  switch(layer_type,
    "bar" = Ggplot2BarLayerProcessor$new(layer_info),
    "line" = Ggplot2LineLayerProcessor$new(layer_info),
    "point" = Ggplot2PointLayerProcessor$new(layer_info),
    "violin" = Ggplot2ViolinLayerProcessor$new(layer_info),  # Add new processor
    # ... other processors
    Ggplot2UnknownLayerProcessor$new(layer_info)
  )
}
```

### Step 3: Update Adapter Detection

```r
# In Ggplot2Adapter$detect_layer_type()
detect_layer_type = function(layer, plot_object) {
  geom_class <- class(layer$geom)[1]
  stat_class <- class(layer$stat)[1]
  position_class <- class(layer$position)[1]

  # Add violin detection
  if (geom_class == "GeomViolin") {
    return("violin")
  }
  
  # ... existing detection logic
}
```

### Step 4: Add to NAMESPACE

```r
# In maidr/NAMESPACE
export(Ggplot2ViolinLayerProcessor)
```

## Advanced Features

### 1. Complex Selector Generation

```r
# For complex plots with multiple element types
generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
  selectors <- list()
  
  if (!is.null(grob_id)) {
    base_id <- paste0(grob_id, ".1")
    escaped_id <- gsub("\\.", "\\\\.", base_id)
    
    # Different selectors for different components
    selectors <- list(
      main_elements = paste0("#", escaped_id, " rect"),
      labels = paste0("#", escaped_id, " text"),
      axes = paste0("#", escaped_id, " line"),
      grid = paste0("#", escaped_id, " polyline")
    )
  }
  
  return(selectors)
}
```

### 2. Conditional Data Extraction

```r
extract_data = function(plot, built, scale_mapping = NULL, panel_id = NULL) {
  layer_index <- self$get_layer_index()
  layer_data <- built$data[[layer_index]]
  
  # Conditional extraction based on plot characteristics
  if (self$has_grouping(plot)) {
    return(self$extract_grouped_data(layer_data))
  } else if (self$has_faceting(plot)) {
    return(self$extract_faceted_data(layer_data, panel_id))
  } else {
    return(self$extract_simple_data(layer_data))
  }
}
```

### 3. Dynamic Selector Generation

```r
generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
  # Generate selectors based on plot complexity
  if (self$is_complex_plot(plot)) {
    return(self$generate_complex_selectors(gt, grob_id))
  } else {
    return(self$generate_simple_selectors(gt, grob_id))
  }
}
```

## Error Handling and Validation

### Input Validation

```r
extract_data = function(plot, built, scale_mapping = NULL, panel_id = NULL) {
  # Validate inputs
  if (is.null(plot)) {
    stop("Plot object cannot be NULL")
  }
  
  if (is.null(built)) {
    built <- ggplot2::ggplot_build(plot)
  }
  
  layer_index <- self$get_layer_index()
  if (layer_index > length(built$data)) {
    stop("Layer index out of bounds")
  }
  
  # Continue with extraction...
}
```

### Graceful Degradation

```r
generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
  tryCatch({
    # Normal selector generation
    if (!is.null(grob_id)) {
      return(self$generate_grob_selectors(grob_id))
    } else {
      return(self$generate_gt_selectors(gt))
    }
  }, error = function(e) {
    warning("Failed to generate selectors: ", e$message)
    # Return fallback selectors
    return(list("fallback-selector"))
  })
}
```

## Testing Layer Processors

### Unit Tests

```r
# Test data extraction
test_that("Bar processor extracts data correctly", {
  plot <- ggplot(mtcars, aes(x=cyl, y=mpg)) + geom_bar(stat="identity")
  built <- ggplot2::ggplot_build(plot)
  processor <- Ggplot2BarLayerProcessor$new(list(index=1))
  
  data <- processor$extract_data(plot, built)
  
  expect_is(data, "list")
  expect_true(length(data) > 0)
  expect_true(all(c("x", "y") %in% names(data[[1]])))
})

# Test selector generation
test_that("Bar processor generates selectors", {
  plot <- ggplot(mtcars, aes(x=cyl, y=mpg)) + geom_bar(stat="identity")
  processor <- Ggplot2BarLayerProcessor$new(list(index=1))
  
  selectors <- processor$generate_selectors(plot)
  
  expect_is(selectors, "list")
  expect_true(length(selectors) > 0)
  expect_true(all(grepl("rect", selectors)))
})
```

### Integration Tests

```r
# Test complete processing pipeline
test_that("Bar plot processing works end-to-end", {
  plot <- ggplot(mtcars, aes(x=cyl, y=mpg)) + geom_bar(stat="identity")
  
  # Process through orchestrator
  orchestrator <- Ggplot2PlotOrchestrator$new(plot)
  maidr_data <- orchestrator$generate_maidr_data()
  
  expect_is(maidr_data, "list")
  expect_true("id" %in% names(maidr_data))
  expect_true("subplots" %in% names(maidr_data))
  expect_true(length(maidr_data$subplots) > 0)
})
```

## Performance Optimization

### Caching Layer Data

```r
# Cache expensive data extraction operations
extract_data = function(plot, built, scale_mapping = NULL, panel_id = NULL) {
  # Create cache key
  cache_key <- digest::digest(list(
    plot_hash = digest::digest(plot),
    layer_index = self$get_layer_index(),
    panel_id = panel_id
  ))
  
  # Check cache
  if (exists(cache_key, envir = data_cache)) {
    return(get(cache_key, envir = data_cache))
  }
  
  # Extract data
  data <- self$extract_data_internal(plot, built, scale_mapping, panel_id)
  
  # Cache result
  assign(cache_key, data, envir = data_cache)
  
  return(data)
}
```

### Lazy Selector Generation

```r
# Generate selectors only when needed
generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
  if (is.null(gt) && is.null(grob_id)) {
    # Lazy generation - create gt only when needed
    gt <- ggplot2::ggplotGrob(plot)
  }
  
  # Continue with selector generation...
}
```

This comprehensive guide provides everything needed to understand the ggplot2 system implementation and add new plotting functionalities to MAIDR. The modular architecture makes it easy to extend the system while maintaining clean separation of concerns and robust error handling.
