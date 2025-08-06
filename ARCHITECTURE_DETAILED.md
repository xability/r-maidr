# Maidr Package Architecture - Detailed Documentation

## Overview

The `maidr` R package is designed to convert ggplot2 plots into interactive HTML visualizations with embedded data for AI model consumption. The package uses a sophisticated R6 class-based architecture with a singleton orchestrator pattern to handle multiple plot layers and their specific processing requirements.

## Core Architecture Components

### 1. PlotOrchestrator (Singleton Pattern)

**File**: `maidr/R/plot_orchestrator.R`

The `PlotOrchestrator` is the central coordinator that manages the entire plot processing pipeline. It implements a singleton pattern to ensure consistent state management across the package.

#### Key Responsibilities:
- **Layer Detection**: Automatically detects plot layers and their types
- **Processor Creation**: Creates appropriate `LayerProcessor` instances for each layer
- **Data Flow Management**: Coordinates data extraction and selector generation
- **Reordering Coordination**: Manages plot reordering for consistent DOM/data alignment
- **Result Combination**: Combines results from multiple layers into a unified JSON structure

#### Core Methods:

```r
# Initialize orchestrator with plot
orchestrator <- PlotOrchestrator$new(plot)

# Detect and create processors for all layers
orchestrator$detect_layers()
orchestrator$create_layer_processors()

# Process all layers with unified reordering
orchestrator$process_layers()

# Extract final results
results <- orchestrator$get_combined_results()
```

#### Layer Detection Logic:
```r
detect_layer_type = function(layer) {
  geom_name <- class(layer$geom)[1]
  
  # Map geom types to processor types
  switch(geom_name,
    "GeomBar" = {
      if (layer$position$class[1] == "PositionDodge") "dodged_bar"
      else if (layer$position$class[1] == "PositionStack") "stacked_bar"
      else "bar"
    },
    "GeomHistogram" = "hist",
    "GeomDensity" = "smooth",
    "GeomSmooth" = "smooth",
    "unknown"
  )
}
```

### 2. LayerProcessor Base Class

**File**: `maidr/R/layer_processor.R`

The `LayerProcessor` base class provides a unified interface for all layer-specific processing. It defines the contract that all specific processors must implement.

#### Core Interface:
```r
LayerProcessor <- R6::R6Class("LayerProcessor",
  public = list(
    # Process the layer and return structured data
    process = function(plot, layout, gt = NULL) { ... },
    
    # Extract data points from the layer
    extract_data_impl = function(plot) { ... },
    
    # Generate CSS selectors for SVG elements
    generate_selectors = function(plot, gt) { ... },
    
    # Check if layer needs reordering
    needs_reordering = function() { ... },
    
    # Apply reordering to plot data
    apply_reordering = function(plot) { ... },
    
    # Get reordered plot for orchestrator
    get_reordered_plot = function() { ... },
    
    # Store/retrieve last processing result
    set_last_result = function(result) { ... },
    get_last_result = function() { ... }
  ),
  
  private = list(
    reordered_plot = NULL,
    last_result = NULL
  )
)
```

### 3. Specific Layer Processors

Each plot type has its own specialized processor that inherits from `LayerProcessor`:

#### BarLayerProcessor
**File**: `maidr/R/bar_layer_processor.R`

Handles simple bar plots with:
- **Reordering**: Sorts data by x-axis for consistent SVG rect order
- **Fill Detection**: Only includes `fill` attribute if explicitly mapped by user
- **Selector Generation**: Uses recursive grob traversal to find correct rect elements

```r
# Example bar plot processing
bar_processor <- BarLayerProcessor$new()
result <- bar_processor$process(plot, layout, gt)
# Returns: {type: "bar", data: [...], selectors: ["#geom_rect\\.rect\\.145\\.1 rect"]}
```

#### DodgedBarLayerProcessor
**File**: `maidr/R/dodged_bar_layer_processor.R`

Handles dodged bar plots with complex reordering:
- **DOM Order**: Ensures `right-left-right-left` pattern for highlighting
- **Data Structure**: Maintains `Type1, Type2` order for data consistency
- **Reordering Logic**: Uses `rev(fill_values)` to achieve desired visual order

```r
# Complex reordering for dodged bars
reorder_data_for_visual_order = function(data, x_col, y_col, fill_col) {
  x_values <- sort(unique(data[[x_col]]))
  fill_values <- sort(unique(data[[fill_col]]))
  
  reordered_data <- data.frame()
  for (x_val in x_values) {
    for (fill_val in rev(fill_values)) {  # Type2 first, then Type1
      matching_rows <- which(data[[x_col]] == x_val & data[[fill_col]] == fill_val)
      if (length(matching_rows) > 0) {
        reordered_data <- rbind(reordered_data, data[matching_rows, ])
      }
    }
  }
  return(reordered_data)
}
```

#### StackedBarLayerProcessor
**File**: `maidr/R/stacked_bar_layer_processor.R`

Handles stacked bar plots with:
- **Height Calculation**: Properly calculates stacked bar heights
- **Fill Grouping**: Groups data by fill values for proper stacking
- **Selector Generation**: Uses `find_geom_rect_grobs` for accurate targeting

#### HistogramLayerProcessor
**File**: `maidr/R/histogram_layer_processor.R`

Handles histogram plots with:
- **Density Scaling**: Supports `aes(y = ..density..)` for density histograms
- **Bin Data**: Extracts bin boundaries and heights
- **Selector Generation**: Uses `find_bar_grobs` with `.1` suffix

#### SmoothLayerProcessor
**File**: `maidr/R/smooth_layer_processor.R`

Handles smooth plots (density curves, loess, etc.) with:
- **Point Extraction**: Extracts 512+ data points for smooth curves
- **SVG Coordinates**: Includes `svg_x` and `svg_y` for precise positioning
- **Selector Generation**: Uses `find_polyline_grobs` with `.1.1` suffix

#### UnknownLayerProcessor
**File**: `maidr/R/unknown_layer_processor.R`

Fallback processor for unsupported layer types:
- **Graceful Handling**: Returns empty data without errors
- **Type Detection**: Marks as "unknown" for debugging
- **Minimal Impact**: Allows processing to continue for other layers

## Unified Reordering System

### Overview
The package uses a unified "reordering" approach instead of separate "sorting" and "reordering" mechanisms. This simplifies the architecture and ensures consistent behavior across all layer types.

### Implementation Details

#### 1. Reordering Interface
All layer processors implement the same reordering interface:
```r
needs_reordering = function() {
  # Return TRUE if layer needs reordering
}

apply_reordering = function(plot) {
  # Apply reordering logic and return modified plot
}

get_reordered_plot = function() {
  # Return the reordered plot for orchestrator use
}
```

#### 2. Orchestrator Integration
The `PlotOrchestrator` manages reordering at the system level:
```r
process_layers = function() {
  # Process layers first to get reordered plots
  for (i in seq_along(private$.layer_processors)) {
    processor <- private$.layer_processors[[i]]
    result <- processor$process(private$.plot, private$.layout, NULL)
    
    # Store reordered plot if available
    if (!is.null(processor$get_reordered_plot())) {
      reordered_plots[[i]] <- processor$get_reordered_plot()
    }
  }
  
  # Use reordered plot for gtable generation
  plot_for_gtable <- private$.plot
  if (length(reordered_plots) > 0) {
    plot_for_gtable <- reordered_plots[[1]]
  }
  
  # Generate gtable from reordered plot
  gt_plot <- ggplot2::ggplotGrob(plot_for_gtable)
}
```

#### 3. Reordering Examples

**Bar Plots**: Sort by x-axis for consistent rect order
```r
apply_reordering = function(plot) {
  x_col <- rlang::as_name(plot$mapping$x)
  reordered_data <- original_data[order(original_data[[x_col]]), ]
  new_plot <- plot
  new_plot$data <- reordered_data
  return(new_plot)
}
```

**Dodged Bar Plots**: Complex reordering for visual consistency
```r
apply_reordering = function(plot) {
  # Reorder data to achieve right-left-right-left DOM order
  reordered_data <- reorder_data_for_visual_order(data, x_col, y_col, fill_col)
  new_plot <- plot
  new_plot$data <- reordered_data
  return(new_plot)
}
```

## Data Flow Architecture

### 1. Plot Input
```r
# User creates ggplot2 plot
p <- ggplot(data, aes(x = x, y = y)) + geom_bar()
```

### 2. Orchestrator Initialization
```r
# Create singleton orchestrator
orchestrator <- PlotOrchestrator$new(p)
```

### 3. Layer Detection & Processing
```r
# Detect layers automatically
orchestrator$detect_layers()
# Creates: [{type: "bar", layer: layer_object}]

# Create processors for each layer
orchestrator$create_layer_processors()
# Creates: [BarLayerProcessor$new()]

# Process all layers with reordering
orchestrator$process_layers()
# Calls: processor$process() for each layer
```

### 4. Data Extraction & Selector Generation
```r
# Each processor extracts data
data <- processor$extract_data_impl(plot)
# Returns: [{x: "A", y: 10, fill: "steelblue"}, ...]

# Each processor generates selectors
selectors <- processor$generate_selectors(plot, gt)
# Returns: ["#geom_rect\\.rect\\.145\\.1 rect"]
```

### 5. Result Combination
```r
# Orchestrator combines all layer results
combined_results <- orchestrator$get_combined_results()
# Returns: {layers: [{type: "bar", data: [...], selectors: [...]}]}
```

### 6. JSON Generation
```r
# Convert to JSON for HTML embedding
json_data <- jsonlite::toJSON(combined_results, auto_unbox = TRUE)
# Embed in SVG: maidr-data="{...}"
```

## Selector Generation System

### Overview
The selector generation system uses recursive grob tree traversal to find the exact SVG elements that correspond to each plot layer.

### Implementation Details

#### 1. Grob Tree Traversal
```r
find_bar_grobs = function(grob, grobs = list()) {
  if (inherits(grob, "gTree")) {
    for (child in grob$children) {
      grobs <- find_bar_grobs(child, grobs)
    }
  } else if (inherits(grob, "rect") && grepl("geom_rect", grob$name)) {
    grobs[[length(grobs) + 1]] <- grob
  }
  return(grobs)
}
```

#### 2. Selector Construction
```r
make_bar_selector = function(grob) {
  # Extract grob ID and construct CSS selector
  grob_id <- grob$name
  selector <- paste0("#", gsub("\\.", "\\\\.", grob_id), " rect")
  return(selector)
}
```

#### 3. Layer-Specific Selectors

**Bar Plots**: `#geom_rect\.rect\.145\.1 rect`
**Histograms**: `#geom_rect\.rect\.207\.1 rect`
**Smooth Plots**: `#GRID\.polyline\.264\.1\.1`
**Dodged Bars**: `#geom_rect\.rect\.145\.1 rect`

## JSON Data Structure

### Overview
The package generates a standardized JSON structure that embeds plot data and metadata for AI model consumption.

### Structure Definition
```json
{
  "id": "maidr-plot-1234567890",
  "subplots": [
    {
      "id": "maidr-subplot-1234567890",
      "layers": [
        {
          "id": 1,
          "type": "bar",
          "selectors": ["#geom_rect\\.rect\\.145\\.1 rect"],
          "data": [
            {
              "x": "A",
              "y": 10,
              "fill": "steelblue"
            }
          ],
          "title": "Plot Title",
          "axes": {
            "x": "Category",
            "y": "Value"
          }
        }
      ]
    }
  ]
}
```

### Data Extraction Examples

#### Bar Plot Data
```r
extract_data_impl = function(plot) {
  # Extract x, y, fill values
  data_points <- list()
  for (i in seq_len(nrow(data))) {
    data_points[[i]] <- list(
      x = as.character(data[[x_col]][i]),
      y = data[[y_col]][i],
      fill = if (has_fill_mapping) as.character(data[[fill_col]][i]) else NULL
    )
  }
  return(data_points)
}
```

#### Histogram Data
```r
extract_data_impl = function(plot) {
  # Extract bin data with boundaries
  data_points <- list()
  for (i in seq_len(nrow(data))) {
    data_points[[i]] <- list(
      x = data[[x_col]][i],
      y = data[[y_col]][i],
      xMin = data[[xmin_col]][i],
      xMax = data[[xmax_col]][i],
      yMin = 0,
      yMax = data[[y_col]][i]
    )
  }
  return(data_points)
}
```

#### Smooth Plot Data
```r
extract_data_impl = function(plot) {
  # Extract curve points with SVG coordinates
  data_points <- list()
  for (i in seq_len(nrow(data))) {
    data_points[[i]] <- list(
      x = data[[x_col]][i],
      y = data[[y_col]][i],
      svg_x = svg_coords[[i]]$x,
      svg_y = svg_coords[[i]]$y
    )
  }
  return(data_points)
}
```

## Multi-Layer Support

### Overview
The package supports plots with multiple layers (e.g., histogram + density curve) through the orchestrator's layer management system.

### Implementation Details

#### 1. Layer Detection
```r
detect_layers = function() {
  layers <- list()
  for (i in seq_along(private$.plot$layers)) {
    layer <- private$.plot$layers[[i]]
    layer_type <- self$detect_layer_type(layer)
    layers[[i]] <- list(type = layer_type, layer = layer)
  }
  return(layers)
}
```

#### 2. Multi-Processor Creation
```r
create_layer_processors = function() {
  processors <- list()
  for (layer_info in private$.layers) {
    processor <- self$create_layer_processor(layer_info$type)
    processors[[length(processors) + 1]] <- processor
  }
  return(processors)
}
```

#### 3. Result Combination
```r
combine_layer_results = function(layer_results) {
  combined_data <- list()
  combined_selectors <- list()
  
  for (result in layer_results) {
    combined_data <- c(combined_data, result$data)
    combined_selectors <- c(combined_selectors, result$selectors)
  }
  
  return(list(
    data = combined_data,
    selectors = combined_selectors
  ))
}
```

### Example: Histogram with Density Curve
```r
# Plot with two layers
p <- ggplot(data, aes(x = x)) +
  geom_histogram(aes(y = ..density..), binwidth = 0.5) +
  geom_density(color = "red")

# Orchestrator detects both layers
# Layer 1: "hist" -> HistogramLayerProcessor
# Layer 2: "smooth" -> SmoothLayerProcessor

# Results combined into single JSON
{
  "layers": [
    {
      "type": "hist",
      "data": [...],  # 18 histogram bars
      "selectors": ["#geom_rect\\.rect\\.145\\.1 rect"]
    },
    {
      "type": "smooth", 
      "data": [...],  # 512 density curve points
      "selectors": ["#GRID\\.polyline\\.147\\.1\\.1"]
    }
  ]
}
```

## Error Handling & Robustness

### 1. Unknown Layer Types
```r
UnknownLayerProcessor <- R6::R6Class("UnknownLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    extract_data_impl = function(plot) {
      return(list())  # Return empty data
    },
    generate_selectors = function(plot, gt) {
      return(list())  # Return empty selectors
    }
  )
)
```

### 2. Missing Aesthetic Mappings
```r
# Graceful handling of missing aesthetics
if (is.null(x_col)) {
  stop("Could not determine x aesthetic mapping")
}
```

### 3. Grob Tree Traversal Failures
```r
# Fallback selector generation
if (length(grobs) == 0) {
  return(list())  # Return empty selectors
}
```

## Performance Considerations

### 1. Singleton Pattern Benefits
- **Memory Efficiency**: Single orchestrator instance
- **State Consistency**: Centralized plot processing state
- **Resource Management**: Coordinated gtable generation

### 2. Lazy Processing
- **On-Demand Processing**: Layers processed only when needed
- **Cached Results**: Store processing results for reuse
- **Incremental Updates**: Process only changed layers

### 3. Efficient Data Structures
- **List-Based Storage**: Efficient for variable-length data
- **JSON Serialization**: Optimized for HTML embedding
- **Selector Caching**: Avoid repeated grob tree traversal

## Testing & Validation

### 1. Unit Tests
```r
# Test individual processors
test_that("BarLayerProcessor extracts correct data", {
  processor <- BarLayerProcessor$new()
  result <- processor$extract_data_impl(test_plot)
  expect_equal(length(result), 4)
  expect_equal(result[[1]]$x, "A")
})
```

### 2. Integration Tests
```r
# Test complete pipeline
test_that("Orchestrator processes multi-layer plot", {
  orchestrator <- PlotOrchestrator$new(multi_layer_plot)
  results <- orchestrator$process_layers()
  expect_equal(length(results$layers), 2)
})
```

### 3. Visual Validation
- **HTML Output**: Verify correct SVG generation
- **Selector Accuracy**: Confirm CSS selectors target correct elements
- **Data Completeness**: Ensure all plot data is captured

## Extension Points

### 1. Adding New Plot Types
```r
# 1. Create new processor class
NewPlotProcessor <- R6::R6Class("NewPlotProcessor",
  inherit = LayerProcessor,
  public = list(
    extract_data_impl = function(plot) { ... },
    generate_selectors = function(plot, gt) { ... }
  )
)

# 2. Add detection logic to orchestrator
detect_layer_type = function(layer) {
  switch(geom_name,
    "GeomNewPlot" = "new_plot",
    # ... existing cases
  )
}

# 3. Add processor creation logic
create_layer_processor = function(type) {
  switch(type,
    "new_plot" = NewPlotProcessor$new(),
    # ... existing cases
  )
}
```

### 2. Custom Reordering Logic
```r
# Override reordering methods in new processor
needs_reordering = function() {
  return(TRUE)  # Custom logic
}

apply_reordering = function(plot) {
  # Custom reordering implementation
  return(reordered_plot)
}
```

### 3. Custom Data Extraction
```r
# Override data extraction in new processor
extract_data_impl = function(plot) {
  # Custom data extraction logic
  return(custom_data_structure)
}
```

## Best Practices for AI Model Integration

### 1. JSON Structure Consistency
- **Standardized Format**: Always use the defined JSON structure
- **Type Consistency**: Ensure data types match expected formats
- **Null Handling**: Use empty arrays/objects instead of null values

### 2. Selector Reliability
- **CSS Escaping**: Properly escape dots in grob names
- **Element Targeting**: Target specific SVG elements (rect, polyline, etc.)
- **Fallback Handling**: Provide empty selectors for unsupported elements

### 3. Data Completeness
- **All Plot Elements**: Capture all visible plot elements
- **Metadata Inclusion**: Include titles, axes labels, and legends
- **Coordinate Systems**: Preserve both data and SVG coordinates

### 4. Performance Optimization
- **Efficient Processing**: Minimize redundant calculations
- **Memory Management**: Clean up large objects after processing
- **Caching Strategy**: Cache expensive operations (grob traversal, etc.)

## Conclusion

The `maidr` package architecture provides a robust, extensible foundation for converting ggplot2 plots into interactive HTML visualizations. The unified reordering system, multi-layer support, and comprehensive error handling ensure reliable operation across diverse plot types and configurations.

The R6 class-based design with singleton orchestrator pattern enables clean separation of concerns while maintaining efficient resource usage. The standardized JSON output format ensures compatibility with AI model consumption requirements.

For developers extending the package, the well-defined interfaces and extension points provide clear guidance for adding new plot types and customizing processing behavior. The comprehensive testing framework ensures reliability and maintainability as the package evolves. 