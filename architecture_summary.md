# Layer-Wise Detection Architecture for maidr Package

## Overview

Instead of detecting complex multi-layer plot types, we detect each layer individually and let the system handle multiple layers naturally. This approach is more flexible, extensible, and maintainable.

## Key Principles

### 1. **Layer-Wise Detection**
- Each layer is analyzed independently
- No complex plot type combinations to detect
- Each layer gets its own processor

### 2. **Singleton Orchestrator**
- `PlotOrchestrator` class manages the entire process
- Detects all layers in a plot
- Creates appropriate processors for each layer
- Combines results from all layers

### 3. **Layer-Specific Processors**
- Each layer type has its own processor class
- Processors handle data extraction and selector generation
- Easy to add new layer types

## Architecture Components

### 1. **PlotOrchestrator (Singleton)**
```r
PlotOrchestrator$new(plot)
├── detect_layers()           # Analyze each layer
├── create_layer_processors() # Create processors
├── process_layers()          # Process all layers
└── generate_maidr_data()     # Generate final output
```

### 2. **Layer Detection Logic**
```r
detect_layer_type(geom_class, stat_class, position_class)
├── "GeomBar" + "StatBin" → "histogram"
├── "GeomBar" + "PositionStack" → "stacked_bar"
├── "GeomBar" + "PositionDodge" → "dodged_bar"
├── "GeomBar" + default → "bar"
├── "GeomSmooth" → "smooth"
├── "GeomLine" → "line"
├── "GeomPoint" → "point"
├── "GeomText" → "text"
└── "GeomErrorbar" → "errorbar"
```

### 3. **Layer Processors**
```r
LayerProcessor (Base)
├── BarLayerProcessor
├── StackedBarLayerProcessor
├── DodgedBarLayerProcessor
├── HistogramLayerProcessor
├── SmoothLayerProcessor
├── LineLayerProcessor
├── PointLayerProcessor
├── TextLayerProcessor
├── ErrorBarLayerProcessor
└── UnknownLayerProcessor
```

## Data Flow

### 1. **Input**: ggplot2 object
```r
plot <- ggplot(data, aes(x, y)) + 
  geom_bar() + 
  geom_text(aes(label = ..count..), stat = "count")
```

### 2. **Layer Detection**
```r
Layer 1: geom_bar() → "bar"
Layer 2: geom_text() → "text"
```

### 3. **Processor Creation**
```r
BarLayerProcessor$new(layer_info_1)
TextLayerProcessor$new(layer_info_2)
```

### 4. **Layer Processing**
```r
BarLayerProcessor$process() → {data: [...], selectors: [...]}
TextLayerProcessor$process() → {data: [...], selectors: [...]}
```

### 5. **Result Combination**
```r
combined_data = [bar_data, text_data]
combined_selectors = [bar_selectors, text_selectors]
```

### 6. **Output**: maidr data structure
```r
{
  id: "maidr-plot-1234567890",
  subplots: [{
    id: "maidr-subplot-1234567890",
    layers: [
      {type: "bar", data: [...], selectors: [...]},
      {type: "text", data: [...], selectors: [...]}
    ]
  }]
}
```

## Benefits

### 1. **Simplicity**
- No complex plot type detection logic
- Each layer is handled independently
- Clear separation of concerns

### 2. **Extensibility**
- Easy to add new layer types
- Just create a new processor class
- No changes to core detection logic

### 3. **Maintainability**
- Each processor is self-contained
- Changes to one layer type don't affect others
- Clear inheritance structure

### 4. **Flexibility**
- Handles any combination of layers
- No need to define all possible combinations
- Natural support for complex plots

## Integration with Existing maidr Package

### 1. **Replace Current Factory Pattern**
```r
# Current (plot-type based)
create_plot_processor(plot) → detect_plot_type() → process_*_plot()

# New (layer-wise)
PlotOrchestrator$new(plot) → detect_layers() → process_layers()
```

### 2. **Reuse Existing Functions**
```r
# Existing functions become layer processor methods
extract_bar_data() → BarLayerProcessor$extract_data()
make_bar_selectors() → BarLayerProcessor$generate_selectors()
```

### 3. **Backward Compatibility**
```r
# Single-layer plots work exactly as before
# Multi-layer plots get enhanced functionality
```

## Implementation Plan

### Phase 1: Core Architecture
1. Create `PlotOrchestrator` class
2. Implement layer detection logic
3. Create base `LayerProcessor` class
4. Implement existing layer processors (bar, stacked_bar, dodged_bar, histogram, smooth)

### Phase 2: Multi-Layer Support
1. Add new layer processors (text, point, line, errorbar)
2. Implement layer combination logic
3. Test with complex multi-layer plots

### Phase 3: Enhanced Features
1. Layer-specific interactions
2. Layer relationships and dependencies
3. Advanced selector generation

## Example Usage

```r
# Create a complex multi-layer plot
plot <- ggplot(mtcars, aes(factor(cyl), fill = factor(vs))) + 
  geom_bar(position = "stack") + 
  geom_text(aes(label = ..count..), stat = "count", position = "stack") +
  geom_errorbar(aes(ymin = ..count.. - 1, ymax = ..count.. + 1), stat = "count")

# Process with orchestrator
orchestrator <- PlotOrchestrator$new(plot)
orchestrator$process_layers()
maidr_data <- orchestrator$generate_maidr_data()

# Result: Each layer gets its own data and selectors
# Interactive features work for each layer type
```

## Advantages Over Current Approach

### Current Approach (Plot-Type Based)
- ❌ Complex detection logic for plot combinations
- ❌ Hard to add new plot types
- ❌ Limited to predefined combinations
- ❌ Brittle to ggplot2 changes

### New Approach (Layer-Wise)
- ✅ Simple layer-by-layer detection
- ✅ Easy to add new layer types
- ✅ Handles any layer combination
- ✅ Robust to ggplot2 changes
- ✅ Natural support for complex plots
- ✅ Each layer can have its own interactions 