# MAIDR R Package - Quick Reference

## Overview
MAIDR creates accessible, interactive visualizations from ggplot2 and Base R plots using a Registry + Adapter pattern architecture.

## Core Architecture

### System Detection Flow
```
maidr::show(plot) → Registry → Adapter → Orchestrator → Processors → HTML/SVG
```

### Two Systems
1. **ggplot2**: Uses plot object structure directly
2. **Base R**: Captures and replays function calls

## Key Components

### Entry Points
- `R/maidr.R` - Main user functions (`show()`, `save_html()`)
- `R/plot_system_registry.R` - Central registry (singleton)

### System-Specific Components

| Component | ggplot2 | Base R |
|-----------|---------|--------|
| **Adapter** | `ggplot2_adapter.R` | `base_r_adapter.R` |
| **Orchestrator** | `ggplot2_plot_orchestrator.R` | `base_r_plot_orchestrator.R` |
| **Factory** | `ggplot2_processor_factory.R` | `base_r_processor_factory.R` |
| **Processors** | `ggplot2_*_layer_processor.R` | `base_r_*_layer_processor.R` |

### Base Classes
- `R/layer_processor.R` - Abstract processor interface
- `R/system_adapter.R` - Abstract adapter interface
- `R/processor_factory.R` - Abstract factory interface

## Usage Examples

### Basic Usage
```r
library(maidr)

# ggplot2
library(ggplot2)
p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_bar(stat = "identity")
maidr::show(p)

# Base R
barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
maidr::show()  # No argument for Base R

# Save to file
maidr::save_html(p, "plot.html")
```

### Supported Plot Types
```r
# Bar charts
ggplot(df, aes(x, y)) + geom_bar(stat="identity")
barplot(values)

# Dodged bars
ggplot(df, aes(x, y, fill=group)) + geom_bar(position="dodge")
barplot(matrix, beside=TRUE)

# Stacked bars
ggplot(df, aes(x, y, fill=group)) + geom_bar(position="stack")
barplot(matrix, beside=FALSE)

# Histograms
ggplot(df, aes(x)) + geom_histogram()
hist(data)

# Line plots
ggplot(df, aes(x, y)) + geom_line()
plot(x, y, type="l")

# Scatter plots
ggplot(df, aes(x, y)) + geom_point()
plot(x, y)

# Box plots
ggplot(df, aes(x, y)) + geom_boxplot()
boxplot(data)

# Heatmaps
ggplot(df, aes(x, y, fill=z)) + geom_tile()
image(matrix)

# Smooth/density
ggplot(df, aes(x, y)) + geom_smooth()
lines(density(data))
```

## Adding New Plot Types

### 1. Create Processor Class
```r
# R/base_r_newplot_layer_processor.R
BaseRNewplotLayerProcessor <- R6::R6Class("BaseRNewplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      list(data = data, selectors = selectors, type = "newplot")
    },

    extract_data = function(layer_info) {
      # Extract from layer_info$plot_call$args
      args <- layer_info$plot_call$args
      # Process arguments and return data
    },

    generate_selectors = function(layer_info, gt) {
      # Search grob tree for elements
      # Return CSS selectors
    }
  )
)
```

### 2. Register in Factory
```r
# R/base_r_processor_factory.R
create_processor = function(plot_type, layer_info) {
  switch(plot_type,
    # ... existing types ...
    "newplot" = BaseRNewplotLayerProcessor$new(layer_info),
    # ...
  )
}
```

### 3. Add Detection Logic
```r
# R/base_r_adapter.R
detect_layer_type = function(plot_call) {
  if (plot_call$function_name == "newplot") {
    return("newplot")
  }
  # ... existing logic ...
}
```

## Data Structure Requirements

### Processor Output Format
```r
list(
  data = [...],           # Plot data (format varies by type)
  selectors = [...],      # CSS selectors for SVG elements
  type = "plot_type",     # Type identifier
  title = "...",          # Optional: plot title
  axes = list(x="", y="") # Optional: axis labels
)
```

### Data Formats by Type
- **Simple plots**: `[{x: val, y: val}, ...]`
- **Grouped plots**: `[[{x, y, fill}, ...], [...]]` (nested by group)
- **Histograms**: `[{x, y, xMin, xMax, yMin, yMax}, ...]`
- **Box plots**: `[{min, max, q1, q2, q3, fill, outliers}, ...]`

## Testing & Debugging

### Test Individual Components
```r
# Test processor directly
processor <- BaseRBarplotLayerProcessor$new(layer_info)
result <- processor$process(NULL, layout, NULL, gt, layer_info)
print(result$data)
print(result$selectors)
```

### Debug Base R Call Capture
```r
# Check captured calls
device_id <- dev.cur()
get_device_calls(device_id)

# Check grouping
grouped <- group_device_calls(device_id)
str(grouped$groups)
```

### Debug ggplot2 Processing
```r
# Check built data
p <- ggplot(...) + geom_bar(...)
built <- ggplot2::ggplot_build(p)
str(built$data[[1]])  # Layer 1 data

# Check grob structure
gt <- ggplot2::ggplotGrob(p)
grid::grid.ls(gt)  # List grob names
```

## Key Files for Reference

### Documentation
- `docs/SYSTEM_DETECTION_COMPLETE.md` - Detection architecture
- `docs/BASE_R_LAYER_PROCESSORS.md` - Base R processing
- `docs/GGPLOT2_LAYER_PROCESSORS.md` - ggplot2 processing
- `docs/BASE_R_ORCHESTRATION.md` - Base R orchestration
- `docs/GGPLOT2_ORCHESTRATION.md` - ggplot2 orchestration

### Critical Implementation Files
- `R/layer_processor.R` - Processor interface (MUST inherit)
- `R/maidr.R` - Entry point logic
- `R/plot_system_registry.R` - System registration

## Common Issues & Solutions

### Base R Not Detecting
```r
# Ensure patching is active
is_patching_active()  # Should be TRUE

# Check device has calls
has_device_calls(dev.cur())  # Should be TRUE
```

### Wrong Selectors Generated
- Check group_index vs layer_index usage
- Verify grob tree structure with `grid::grid.ls()`
- Use robust selector utilities in `R/base_r_selector_utils.R`

### Data Order Mismatch
- ggplot2: Implement `needs_reordering()` and `reorder_layer_data()`
- Base R: Sort data consistently in `extract_data()`

## Architecture Principles

1. **Unified Grob**: One grob shared by all layers in a group
2. **Isolation**: Base R clears storage after each `show()`
3. **Extensibility**: Add processors without modifying core
4. **Registry Pattern**: Central system management
5. **Adapter Pattern**: System-specific handling

## Quick Development Workflow

1. Create plot and test with `maidr::show()`
2. Check if detected: `registry$detect_system(plot)`
3. Debug processor: Test `extract_data()` and `generate_selectors()` separately
4. Verify output structure matches MAIDR format
5. Test with different data configurations