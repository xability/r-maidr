# Maidr Package Architecture - Detailed Documentation

## Overview

The `maidr` R package provides interactive HTML output for ggplot2 plots by converting them to SVG and adding interactive highlighting capabilities. The package uses a sophisticated R6 class-based architecture with a singleton orchestrator pattern to handle multiple plot layers independently.

## Core Architecture Components

### 1. PlotOrchestrator (Singleton Pattern)

**File**: `maidr/R/plot_orchestrator.R`

The `PlotOrchestrator` is the central coordinator that manages the entire plot processing workflow. It follows the singleton pattern to ensure only one orchestrator instance exists per plot.

#### Key Responsibilities:
- **Layer Detection**: Automatically detects plot layers and their types
- **Layer Processing**: Coordinates individual layer processors
- **Data Combination**: Merges results from multiple layers
- **GTable Management**: Handles the ggplot2 internal representation
- **Reordering/Sorting Coordination**: Manages plot modifications for correct DOM order

#### Critical Implementation Details:

```r
#' Process all layers
process_layers = function() {
  # Extract layout information
  private$.layout <- self$extract_layout()
  
  # Build the plot once to get consistent data
  built_plot <- ggplot2::ggplot_build(private$.plot)
  
  # Process each layer first to get any reordered/sorted plots
  layer_results <- list()
  reordered_plots <- list()
  sorted_plots <- list()
  
  for (i in seq_along(private$.layer_processors)) {
    processor <- private$.layer_processors[[i]]
    layer_info <- private$.layers[[i]]
    
    # Process the layer with built data
    result <- processor$process(private$.plot, private$.layout, NULL)
    
    # Store the result in the processor for later retrieval
    processor$set_last_result(result)
    
    layer_results[[i]] <- result
    
    # Check if this processor has a reordered plot
    if (!is.null(processor$get_reordered_plot())) {
      reordered_plots[[i]] <- processor$get_reordered_plot()
    }
    
    # Check if this processor has a sorted plot
    if (!is.null(processor$get_sorted_plot())) {
      sorted_plots[[i]] <- processor$get_sorted_plot()
    }
  }
  
  # Use reordered/sorted plot for gtable if any layer has modifications
  plot_for_gtable <- private$.plot
  if (length(reordered_plots) > 0) {
    plot_for_gtable <- reordered_plots[[1]]
  } else if (length(sorted_plots) > 0) {
    plot_for_gtable <- sorted_plots[[1]]
  }
  
  gt_plot <- ggplot2::ggplotGrob(plot_for_gtable)
  
  # Store the gtable for later use
  private$.gtable <- gt_plot
  
  # Re-process layers with the correct gtable (only for selectors)
  for (i in seq_along(private$.layer_processors)) {
    processor <- private$.layer_processors[[i]]
    
    # Re-generate selectors with the correct gtable
    if (!is.null(processor$get_last_result())) {
      result <- processor$get_last_result()
      result$selectors <- processor$generate_selectors(plot_for_gtable, gt_plot)
      processor$set_last_result(result)
    }
  }
  
  # Combine results
  self$combine_layer_results(layer_results)
}
```

**Critical Insight**: The orchestrator processes layers twice - first to get any plot modifications (reordering/sorting), then again to generate selectors using the modified plot. This ensures SVG element IDs match the modified data structure.

### 2. LayerProcessor Base Class

**File**: `maidr/R/layer_processor.R`

The base class that all specific layer processors inherit from. Provides common functionality and interface.

#### Key Methods:
- `process()`: Main processing method (to be overridden)
- `extract_data_impl()`: Data extraction (to be overridden)
- `generate_selectors()`: Selector generation (to be overridden)
- `set_last_result()` / `get_last_result()`: Result storage
- `get_reordered_plot()` / `get_sorted_plot()`: Plot modification retrieval

#### Private Fields:
- `last_result`: Stores the processed result for each layer
- `reordered_plot`: Stores plot after reordering (for dodged bars)
- `sorted_plot`: Stores plot after sorting (for bar plots)

### 3. Specific Layer Processors

Each plot type has its own specialized processor that inherits from `LayerProcessor`.

#### BarLayerProcessor
**File**: `maidr/R/bar_layer_processor.R`

**Key Features**:
- **Sorting Implementation**: Sorts plot data by x-axis values before building
- **Fill Attribute Logic**: Only includes fill in JSON if user explicitly mapped it
- **Selector Generation**: Uses recursive grob tree traversal

```r
#' Apply sorting to the plot data
apply_sorting = function(plot) {
  # Get the original data
  original_data <- plot$data
  
  # Get column names from aesthetics
  plot_mapping <- plot$mapping
  layer_mapping <- plot$layers[[1]]$mapping
  
  x_col <- NULL
  if (!is.null(layer_mapping$x)) {
    x_col <- rlang::as_name(layer_mapping$x)
  } else if (!is.null(plot_mapping$x)) {
    x_col <- rlang::as_name(plot_mapping$x)
  }
  
  if (!is.null(x_col)) {
    # Sort the data by x-axis values
    sorted_data <- original_data[order(original_data[[x_col]]), ]
    
    # Create a new plot with sorted data
    sorted_plot <- plot
    sorted_plot$data <- sorted_data
    
    return(sorted_plot)
  }
  
  return(plot)
}
```

**Critical Insight**: The sorting is applied to the plot data itself, not just the output JSON. This ensures the SVG rects are generated in the correct order.

#### DodgedBarLayerProcessor
**File**: `maidr/R/dodged_bar_layer_processor.R`

**Key Features**:
- **Complex Reordering**: Reorders data to achieve specific DOM element order
- **Visual Order Control**: Ensures right-left-right-left DOM order for highlighting
- **Data Structure Alignment**: Aligns JSON data structure with DOM order

```r
reorder_data_for_visual_order = function(data, x_col, y_col, fill_col) {
  # Get unique values and sort them consistently
  x_values <- sort(unique(data[[x_col]]))
  fill_values <- sort(unique(data[[fill_col]]))
  
  reordered_data <- data.frame()
  
  # For each x value, process fill values in reverse order
  # This creates: A-Type2, A-Type1, B-Type2, B-Type1, C-Type2, C-Type1
  for (x_val in x_values) {
    for (fill_val in rev(fill_values)) {  # Type2 first, then Type1 for each x
      # Find the row for this x-fill combination
      matching_rows <- which(data[[x_col]] == x_val & data[[fill_col]] == fill_val)
      if (length(matching_rows) > 0) {
        reordered_data <- rbind(reordered_data, data[matching_rows, ])
      }
    }
  }
  return(reordered_data)
}
```

**Critical Insight**: The reordering logic is crucial for achieving the desired highlighting behavior. The DOM order (right-left-right-left) must match the data structure order for proper interaction.

#### StackedBarLayerProcessor
**File**: `maidr/R/stacked_bar_layer_processor.R`

**Key Features**:
- **Reordering Logic**: Similar to dodged bars but for stacked arrangement
- **Selector Generation**: Uses recursive grob finding

#### HistogramLayerProcessor
**File**: `maidr/R/histogram_layer_processor.R`

**Key Features**:
- **Type Detection**: Detected as "hist" (not "histogram")
- **Selector Generation**: Uses bar grob finding with `.1` suffix

#### SmoothLayerProcessor
**File**: `maidr/R/smooth_layer_processor.R`

**Key Features**:
- **Polyline Selectors**: Targets `GRID.polyline` elements
- **Array Output**: Returns selectors as array of strings

## Data Flow Architecture

### 1. Plot Processing Pipeline

```
User Plot → PlotOrchestrator → Layer Detection → Layer Processors → 
Data Extraction + Selector Generation → Result Combination → JSON Output
```

### 2. Critical Data Flow Steps

#### Step 1: Layer Detection
```r
detect_layer_type = function(layer) {
  geom <- layer$geom
  stat <- layer$stat
  
  if (inherits(geom, "GeomBar") || inherits(geom, "GeomCol")) {
    position <- layer$position
    if (inherits(position, "PositionDodge")) {
      return("dodged_bar")
    } else if (inherits(position, "PositionStack")) {
      return("stacked_bar")
    } else {
      return("bar")
    }
  } else if (inherits(geom, "GeomBar") && inherits(stat, "StatBin")) {
    return("hist")
  } else if (inherits(geom, "GeomSmooth")) {
    return("smooth")
  }
  
  return("unknown")
}
```

#### Step 2: Plot Modification (Reordering/Sorting)
- **Dodged Bars**: Apply reordering to achieve right-left DOM order
- **Bar Plots**: Apply sorting to achieve alphabetical x-axis order
- **Other Plots**: No modification needed

#### Step 3: GTable Generation
- Use modified plot (if any) for `ggplotGrob()` call
- This ensures SVG elements match the modified data structure

#### Step 4: Selector Generation
- Traverse gtable recursively to find actual grob IDs
- Generate CSS selectors that target specific SVG elements

#### Step 5: Data Extraction
- Extract data from the modified plot
- Structure data to match DOM element order
- Apply final sorting for JSON output

## Sorting and Reordering Mechanisms

### 1. Bar Plot Sorting

**Purpose**: Ensure x-axis values are sorted alphabetically to match ggplot2's default behavior.

**Implementation**:
```r
# In BarLayerProcessor$apply_sorting()
sorted_data <- original_data[order(original_data[[x_col]]), ]
sorted_plot$data <- sorted_data
```

**Effect**: 
- SVG rects are generated in alphabetical order (A, B, C, D)
- JSON data matches rect order
- Highlighting works correctly from left to right

### 2. Dodged Bar Reordering

**Purpose**: Achieve specific DOM element order for proper highlighting behavior.

**Implementation**:
```r
# In DodgedBarLayerProcessor$reorder_data_for_visual_order()
for (x_val in x_values) {
  for (fill_val in rev(fill_values)) {  # Type2 first, then Type1
    # Add data in this order
  }
}
```

**Effect**:
- DOM order: Type2 (right), Type1 (left) for each category
- Data structure: Type1 first, then Type2 (for highlighting)
- Creates right-left-right-left visual pattern

### 3. Fill Value Sorting

**Purpose**: Ensure consistent fill value ordering in JSON output.

**Implementation**:
```r
# In DodgedBarLayerProcessor$extract_data_impl()
fill_order <- sort(unique(original_data[[fill_col]]))
```

**Effect**: JSON data groups are sorted by fill values (Type1, Type2)

## Selector Generation Architecture

### 1. Grob Tree Traversal

All selectors are generated by recursively traversing the gtable's grob tree:

```r
find_bar_grobs = function(grob) {
  if (inherits(grob, "grob")) {
    if (grepl("geom_rect", grob$name) && grepl("rect", grob$name)) {
      return(list(grob))
    }
  }
  
  if (inherits(grob, "gTree")) {
    result <- list()
    for (child in grob$children) {
      result <- c(result, find_bar_grobs(child))
    }
    return(result)
  }
  
  return(list())
}
```

### 2. Selector Format

Different plot types use different selector formats:

- **Bar Plots**: `#geom_rect\\.rect\\.42\\.1\\.1 rect`
- **Dodged Bars**: `#geom_rect\\.rect\\.42\\.1\\.1 rect`
- **Stacked Bars**: `#geom_rect\\.rect\\.42\\.1\\.1 rect`
- **Histograms**: `#geom_rect\\.rect\\.207\\.1 rect`
- **Smooth Plots**: `#GRID\\.polyline\\.264\\.1\\.1`

### 3. Critical Selector Rules

1. **Escape Special Characters**: Use `\\.` for dots in CSS selectors
2. **Append Element Type**: Add ` rect` for rectangles, ` polyline` for lines
3. **Use Actual Grob IDs**: Don't hardcode - find actual IDs from gtable
4. **Consistent Suffixes**: Use `.1` for bars, `.1.1` for smooth plots

## JSON Output Structure

### 1. Maidr-Data Format

```json
{
  "id": "maidr-plot-1234567890",
  "subplots": [
    {
      "id": "maidr-subplot-1234567890",
      "layers": [
        {
          "id": 1,
          "selectors": "#geom_rect\\.rect\\.42\\.1\\.1 rect",
          "type": "bar",
          "data": [
            {"x": "A", "y": 30},
            {"x": "B", "y": 25},
            {"x": "C", "y": 15},
            {"x": "D", "y": 10}
          ],
          "title": "Simple Bar Test",
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

### 2. Data Structure Rules

- **Single Layer**: `"selectors": "string"` (bar, stacked_bar, dodged_bar)
- **Multiple Elements**: `"selectors": ["string1", "string2"]` (smooth, histogram)
- **Fill Attribute**: Only included if user explicitly mapped `aes(fill = variable)`
- **Data Ordering**: Must match DOM element order for proper highlighting

## Implementing New Features

### What an AI Model Needs to Know

#### 1. Layer Detection Requirements

When adding a new plot type, you must:

1. **Update `detect_layer_type()`** in `PlotOrchestrator`:
```r
if (inherits(geom, "GeomYourNewGeom")) {
  return("your_new_type")
}
```

2. **Update `create_layer_processor()`** in `PlotOrchestrator`:
```r
case "your_new_type":
  return(YourNewLayerProcessor$new())
```

3. **Create a new LayerProcessor class** that inherits from `LayerProcessor`

#### 2. LayerProcessor Implementation Requirements

Your new processor must implement:

```r
YourNewLayerProcessor <- R6::R6Class("YourNewLayerProcessor",
  inherit = LayerProcessor,
  
  public = list(
    process = function(plot, layout, gt = NULL) {
      # Apply any needed modifications (sorting/reordering)
      # Extract data
      # Generate selectors
      return(list(data = data, selectors = selectors))
    },
    
    extract_data_impl = function(plot) {
      # Extract data points in correct order
      # Return list of data points
    },
    
    generate_selectors = function(plot, gt) {
      # Find grobs in gtable
      # Generate CSS selectors
      # Return string or array of strings
    }
  )
)
```

#### 3. Critical Implementation Patterns

**For Plot Modifications (Sorting/Reordering)**:
```r
process = function(plot, layout, gt = NULL) {
  # Apply modification if needed
  if (self$needs_modification()) {
    plot <- self$apply_modification(plot)
    private$modified_plot <- plot
  }
  
  # Extract data from modified plot
  data <- self$extract_data_impl(plot)
  
  # Generate selectors using modified plot
  selectors <- self$generate_selectors(plot, gt)
  
  return(list(data = data, selectors = selectors))
}
```

**For Grob Finding**:
```r
find_your_grobs = function(grob) {
  if (inherits(grob, "grob")) {
    if (grepl("your_pattern", grob$name)) {
      return(list(grob))
    }
  }
  
  if (inherits(grob, "gTree")) {
    result <- list()
    for (child in grob$children) {
      result <- c(result, find_your_grobs(child))
    }
    return(result)
  }
  
  return(list())
}
```

**For Selector Generation**:
```r
generate_selectors = function(plot, gt) {
  # Find the panel grob
  panel_grob <- find_panel_grob(gt)
  
  # Find your specific grobs
  your_grobs <- find_your_grobs(panel_grob)
  
  # Generate selectors
  selectors <- lapply(your_grobs, function(grob) {
    make_your_selector(grob)
  })
  
  # Return appropriate format
  if (length(selectors) == 1) {
    return(selectors[[1]])
  } else {
    return(selectors)
  }
}
```

#### 4. Testing Requirements

1. **Create test data** with known structure
2. **Generate plot** using ggplot2
3. **Call maidr()** to create HTML
4. **Verify JSON structure** matches expected format
5. **Check SVG elements** match selector targets
6. **Test highlighting behavior** in browser

#### 5. Common Pitfalls to Avoid

1. **Hardcoded Selectors**: Always find actual grob IDs from gtable
2. **Inconsistent Data Order**: Ensure JSON data order matches DOM order
3. **Missing Plot Modifications**: Apply sorting/reordering before building gtable
4. **Incorrect Selector Format**: Use proper CSS escaping and element suffixes
5. **Forgetting Fill Logic**: Only include fill if user explicitly mapped it

#### 6. Debugging Techniques

1. **Add Debug Logs**:
```r
cat("Processing layer", i, "(", layer_info$type, ")\n")
cat("Found grob:", grob$name, "\n")
```

2. **Inspect GTable Structure**:
```r
str(gt, max.level = 3)
```

3. **Check JSON Output**:
```r
cat("JSON data:", jsonlite::toJSON(data, auto_unbox = TRUE), "\n")
```

4. **Verify SVG Elements**:
```r
# Look for the actual element IDs in the generated HTML
```

## Package Structure

```
maidr/
├── R/
│   ├── maidr.R                    # Main entry point
│   ├── plot_orchestrator.R        # Singleton orchestrator
│   ├── layer_processor.R          # Base layer processor
│   ├── bar_layer_processor.R      # Bar plot processor
│   ├── dodged_bar_layer_processor.R
│   ├── stacked_bar_layer_processor.R
│   ├── histogram_layer_processor.R
│   ├── smooth_layer_processor.R
│   └── unknown_layer_processor.R
├── inst/
│   └── htmlwidgets/
│       ├── maidrWidget.js         # JavaScript for highlighting
│       └── maidrWidget.yaml       # Widget configuration
├── man/                           # Documentation
└── DESCRIPTION                     # Package metadata
```

## Key Design Principles

1. **Separation of Concerns**: Each layer type has its own processor
2. **Singleton Pattern**: One orchestrator per plot ensures consistency
3. **Modification Before Building**: Apply sorting/reordering before gtable generation
4. **Recursive Grob Traversal**: Find actual element IDs, don't hardcode
5. **Consistent Data Order**: JSON data must match DOM element order
6. **Robust Error Handling**: Graceful fallbacks for unknown plot types

This architecture provides a solid foundation for extending the package with new plot types while maintaining consistency and reliability. 