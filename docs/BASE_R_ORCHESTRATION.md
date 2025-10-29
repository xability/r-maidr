# Base R Orchestration Complete Guide

## Overview

The Base R orchestration system processes Base R plot calls to generate interactive visualizations. Unlike ggplot2 (which has plot objects), Base R plots are rendered immediately, so the system must replay captured calls to extract data and create interactive elements.

**Note:** This document focuses on explanations. Refer to the actual code files for implementation details.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Function Classification](#function-classification)
3. [Plot Grouping](#plot-grouping)
4. [Layer Detection](#layer-detection)
5. [Grob Creation](#grob-creation)
6. [Layer Processor Creation](#layer-processor-creation)
7. [Processing Layers](#processing-layers)
8. [Results Combination](#results-combination)

---

## Architecture Overview

### Flow from System Detection

After system detection identifies "base_r", the following happens:

1. **Adapter creates orchestrator** with device ID (not plot object)
2. **Orchestrator retrieves calls** from device storage
3. **Calls are grouped** by HIGH/LOW logic
4. **Groups are expanded** into individual layers
5. **Layer processors created** for each layer type
6. **Grobs created** (unified grob per group)
7. **Processors extract data** from grobs
8. **Results combined** into MAIDR format

### Key Principle: Unified Grob Pattern

Each plot **group** creates ONE grob containing ALL elements (HIGH + LOW calls). All layers within that group share this same grob. Each layer processor searches the grob for its specific elements.

**File:** `R/base_r_plot_orchestrator.R`

---

## Function Classification

**File:** `R/base_r_function_classification.R`

### Three Classification Levels

**HIGH-Level Functions:**
- Create new plots: barplot, hist, plot, boxplot, image, contour, matplot, curve, dotchart, stripchart, stem, pie, mosaicplot, assocplot, pairs, coplot
- Create a new canvas

**LOW-Level Functions:**
- Add to existing plots: lines, points, text, mtext, abline, segments, arrows, polygon, rect, symbols, legend, axis, title, grid
- Augment an existing plot

**LAYOUT-Level Functions:**
- Modify canvas layout: par, layout, split.screen
- Configure multi-panel arrangements

### Classification Process

When a plotting function is called:
1. Original function executes (renders to screen)
2. Wrapper logs call with classification
3. Classification added to call entry via `classify_function()`

**File:** `R/base_r_function_patching.R` - Function wrapper adds `class_level` to logged calls

---

## Plot Grouping

**File:** `R/base_r_plot_grouping.R`

### Grouping Algorithm

**Method:** `group_device_calls(device_id)`

Processes calls sequentially:
1. Retrieves all calls from device storage
2. Creates empty groups list
3. Iterates through calls in order
4. Groups logic:
   - **LAYOUT calls:** stored separately (not in groups)
   - **HIGH call:** starts a new group; closes previous group if exists
   - **LOW call:** appends to current group

### Group Structure

Each group contains:
- `high_call`: The HIGH-level function call that started the group
- `high_call_index`: Position in original calls list
- `low_calls`: List of LOW-level calls that follow the HIGH call
- `low_call_indices`: Positions of LOW calls in original list
- `panel_info`: Panel configuration (for multi-panel layouts)

### Grouping Examples

**Single Plot with Layers:**
```
User code:  barplot(c(3,5,7))
            lines(c(1,2,3), c(4,6,5))
            points(c(2,4,6), c(5,7,8))

Result: One group
{
  high_call: { barplot(...) },
  low_calls: [
    { lines(...) },
    { points(...) }
  ]
}
```

**Sequential Plots:**
```
User code:  hist(data1)
            barplot(data2)
            plot(data3)

Result: Three groups
Group 1: { high_call: hist(...), low_calls: [] }
Group 2: { high_call: barplot(...), low_calls: [] }
Group 3: { high_call: plot(...), low_calls: [] }
```

**Multi-layer Plot:**
```
User code:  hist(data, probability=TRUE)
            lines(density(data))

Result: One group
{
  high_call: { hist(...) },
  low_calls: [
    { lines(density(...)) }
  ]
}
```

### Key Points

- Each HIGH call starts a new group
- All LOW calls before the next HIGH call belong to the current group
- Sequential plots create separate groups
- Multi-layer plots create one group with multiple LOW calls

---

## Layer Detection

**File:** `R/base_r_plot_orchestrator.R` - `detect_layers()`

### Expansion Logic

Transforms groups into layers:
- For each group
- Create layer for the HIGH call
- Create a layer for each LOW call in that group

### Layer Structure

Each layer contains:
- `index`: Sequential layer number
- `type`: Layer type (detected by adapter)
- `function_name`: Original function name
- `args`: Function arguments
- `call_expr`: Call expression
- `plot_call`: Full call object
- `group`: Reference to original group
- `group_index`: Which group this layer belongs to
- `source`: "HIGH" or "LOW"
- `low_call_index`: Position within LOW calls (for LOW layers)

### Layer Detection Process

1. Iterate through all plot groups
2. For each group:
   - Get HIGH call
   - Use adapter to detect layer type
   - Create layer 1 (HIGH-level)
3. Check if group has LOW calls:
   - For each LOW call:
     - Detect layer type via adapter
     - Create a layer for non-"unknown" types
     - All layers reference the same group via `group_index`

### Multi-Layer Example

**Group:**
```r
{
  high_call: { hist(...) },
  low_calls: [
    { lines(density(...)) },
    { points(...) }
  ]
}
```

**Detected Layers:**
```r
Layer 1: { type = "hist", source = "HIGH", group_index = 1 }
Layer 2: { type = "smooth", source = "LOW", group_index = 1 }
Layer 3: { type = "point", source = "LOW", group_index = 1 }
```

All three layers share `group_index = 1`, indicating they belong to the same plot group.

### Layer Type Detection

**File:** `R/base_r_adapter.R` - `detect_layer_type()`

**HIGH-level detection:**
- barplot → "bar", "dodged_bar", or "stacked_bar"
- hist → "hist"
- plot → "line" or "smooth" (checks first argument)
- boxplot → "box"

**LOW-level detection:**
- lines → "smooth" (if density object) or "line"
- points → "point"
- abline → "line"
- polygon → "polygon"

**Special case:** `lines(density(data))` detects as "smooth"

---

## Grob Creation

**File:** `R/base_r_plot_orchestrator.R` - `get_gtable()`

### Unified Grob Pattern

Creates one grob per group that includes both HIGH and LOW calls:

Process:
1. For each plot group
2. Create a closure that:
   - Executes the HIGH call
   - Executes all LOW calls in sequence
3. Convert the closure to a grob using `ggplotify::as.grob()`
4. Store the grob in the list by group index

**Storage:** Grobs stored in `grob_list` indexed by group index

### Grob Retrieval

**Method:** `get_grob_for_layer(layer_index)`

For a layer:
1. Get the layer info
2. Read `group_index`
3. Return the grob for that group

Because layers in the same group share a `group_index`, they receive the same grob.

### Why Unified Grob

- One execution captures all elements
- Processors search the grob for their elements
- Keeps HIGH + LOW calls together
- Allows layered visualizations (e.g., histogram + density)

---

## Layer Processor Creation

**File:** `R/base_r_plot_orchestrator.R` - `create_layer_processors()`

### Processor Factory Pattern

For each layer:
1. Skip unknown layers
2. Get the processor factory from the registry
3. Use the factory to create a processor based on layer type
4. Store the processor

**Factory File:** `R/base_r_processor_factory.R`

### Processor Mapping

Layer types map to processors:
- "bar" → BaseRBarplotLayerProcessor
- "dodged_bar" → BaseRDodgedBarLayerProcessor
- "stacked_bar" → BaseRStackedBarLayerProcessor
- "hist" → BaseRHistogramLayerProcessor
- "smooth" → BaseRSmoothLayerProcessor
- Others → BaseRUnknownLayerProcessor

### Processor Responsibilities

Each processor:
- Extracts data from call arguments
- Searches the grob tree for matching elements
- Generates CSS selectors for SVG elements
- Returns data and selectors

**Interface:** Inherits from `LayerProcessor` base class

---

## Processing Layers

**File:** `R/base_r_plot_orchestrator.R` - `process_layers()`

### Processing Flow

For each layer processor:
1. Get the grob via `get_grob_for_layer(layer_index)`
2. Call `processor$process()` with:
   - `plot=NULL` (Base R has no plot object)
   - `layout`
   - `layer_info` (call arguments)
   - `gt=layer_grob`
3. Processor extracts data and selectors
4. Store the result
5. Combine all results into MAIDR format

### Data Extraction

Processor extracts data from call arguments:
- Histogram: bins with counts from `hist()` args
- Barplot: heights from `barplot()` args
- Density: x/y from `density()` args in `lines(density())`

**File:** Individual processor files (e.g., `R/base_r_histogram_layer_processor.R`)

### Selector Generation

Processors search the unified grob tree and produce CSS selectors:
- Histogram: find rect grobs
- Smooth/Density: find polyline grobs
- Points: find circle or point grobs

Selectors use grob names to target SVG elements.

### Grob Sharing

Layers in the same group share a grob, so a processor searches the full tree for its elements.

---

## Results Combination

**File:** `R/base_r_plot_orchestrator.R` - `combine_layer_results()`

### MAIDR Structure

Combines processor results into:
```r
{
  id = "maidr-plot-...",
  subplots = [
    [
      {
        id = "maidr-subplot-...",
        layers = [
          { id = 1, type = "...", data = [...], selectors = [...] },
          { id = 2, type = "...", data = [...], selectors = [...] }
        ]
      }
    ]
  ]
}
```

### Combination Process

1. Iterate layer results
2. For each result:
   - Get layer type
   - Create layer object with standard structure
   - Preserve additional fields (orientation, labels, etc.)
3. Combine selectors from all layers
4. Build 2D subplot grid (single plot = 1x1 grid)
5. Set combined data for retrieval

### Standard Layer Object

Each layer in MAIDR data contains:
- `id`: Layer index
- `type`: Layer type string
- `data`: Extracted data points
- `selectors`: CSS selectors for SVG elements
- `title`: Title (if any)
- `axes`: Axis info (if any)
- Additional fields: orientation (boxplot), labels, etc.

---

## Orchestration Flow Summary

### Complete Process

**Phase 1: Retrieval**
- Get device ID from adapter
- Retrieve all calls from device storage
- Committed to the current device

**Phase 2: Grouping**
- Group calls by HIGH/LOW logic
- Each HIGH starts a new group
- LOW calls append to the current group

**Phase 3: Layer Detection**
- Expand groups into layers
- HIGH call becomes layer 1
- Each LOW call becomes additional layers
- Detect layer types

**Phase 4: Processor Creation**
- Factory creates processors per layer type
- Each processor handles its layer

**Phase 5: Grob Creation**
- Create one grob per group
- Unify HIGH + LOW calls
- Store by group index

**Phase 6: Processing**
- Each processor searches the grob
- Extracts data and selectors
- Returns results

**Phase 7: Combination**
- Combine results into MAIDR structure
- Ready for HTML generation

### Key Design Patterns

**Unified Grob:**
- One grob per group
- Shared by all layers in the group
- Contains all elements

**Layer Expansion:**
- Groups → layers (1 HIGH + N LOW)
- Simple grouping expanded for processing

**Processor Search:**
- Each processor searches the grob
- Finds its elements
- Generates selectors

**Grob Sharing:**
- Same `group_index` → same grob
- Multiple layers from the same plot share grob reference

---

## Related Files

**Core Orchestration:**
- `R/base_r_plot_orchestrator.R` - Main orchestrator class
- `R/base_r_adapter.R` - Layer type detection

**Classification & Grouping:**
- `R/base_r_function_classification.R` - Function categorization
- `R/base_r_plot_grouping.R` - Grouping algorithm
- `R/base_r_device_storage.R` - Call storage and retrieval

**Processor System:**
- `R/base_r_processor_factory.R` - Processor factory
- `R/base_r_barplot_layer_processor.R` - Bar plot processor
- `R/base_r_histogram_layer_processor.R` - Histogram processor
- `R/base_r_smooth_layer_processor.R` - Smooth/density processor
- Individual processor files for each plot type

**Supporting:**
- `R/base_r_state_tracking.R` - State management
- `R/base_r_function_patching.R` - Function wrapping
- `R/processor_factory.R` - Base processor factory class

