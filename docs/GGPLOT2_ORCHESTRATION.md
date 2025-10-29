# ggplot2 Orchestration Complete Guide

## Overview

The ggplot2 orchestration system processes ggplot2 plot objects to generate interactive visualizations. Unlike Base R (which must replay captured calls), ggplot2 has structured plot objects with explicit layers, faceting, and patchwork support built-in.

**Note:** This document focuses on explanations. Refer to the actual code files for implementation details.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Orchestrator Initialization](#orchestrator-initialization)
3. [Plot Type Detection](#plot-type-detection)
4. [Single Plot Processing](#single-plot-processing)
5. [Faceted Plot Processing](#faceted-plot-processing)
6. [Patchwork Plot Processing](#patchwork-plot-processing)
7. [Unified Grob Pattern](#unified-grob-pattern)
8. [Layer Processor System](#layer-processor-system)
9. [Comparison with Base R](#comparison-with-base-r)

---

## Architecture Overview

### Flow from System Detection

After system detection identifies "ggplot2":

1. **Adapter creates orchestrator** with ggplot object (not device ID)
2. **Orchestrator receives structured plot object** with explicit layers
3. **Plot type determined** (single, faceted, or patchwork)
4. **Processing routed** to appropriate method
5. **Grobs created** (one unified grob for entire plot)
6. **Layer processors extract data** from built ggplot data
7. **Selectors generated** from grob tree
8. **Results combined** into MAIDR format

### Key Principle: Object Structure Advantage

ggplot2 plots are structured objects with:
- Explicit layers in `plot$layers`
- Built data via `ggplot_build()`
- Faceting via `plot$facet`
- Patchwork composition via patchwork library

No replay needed—access object properties directly.

**File:** `R/ggplot2_plot_orchestrator.R`

---

## Orchestrator Initialization

**File:** `R/ggplot2_plot_orchestrator.R` - `initialize()`

### Initialization Process

1. Store plot object
2. Get adapter from registry
3. Determine plot type
   - Patchwork → call `process_patchwork_plot()`
   - Faceted → call `process_faceted_plot()`
   - Single → call `detect_layers()`, `create_layer_processors()`, `process_layers()`

### Key Difference from Base R

**ggplot2:** Receives structured plot object with layers  
**Base R:** Receives device ID, retrieves calls, groups, expands

---

## Plot Type Detection

**File:** `R/ggplot2_plot_orchestrator.R`

### Three Plot Types

1. **Patchwork:** Multiple independent plots composed together
2. **Faceted:** Single plot with panels (rows/columns of sub-plots)
3. **Single:** Standard single-panel plot

### Detection Logic

**Patchwork Detection:**
```r
is_patchwork_plot() → inherits(plot, "patchwork")
```

**Faceted Detection:**
```r
is_faceted_plot() {
  if (is.null(plot$facet)) return(FALSE)
  facet_class ← class(plot$facet)[1]
  return(facet_class != "FacetNull")
}
```

**Single Plot:** Default when neither patchwork nor faceted

### Detection Order

Checked in order:
1. Patchwork (checked first)
2. Faceted (if not patchwork)
3. Single (fallback)

---

## Single Plot Processing

### Layer Detection

**File:** `R/ggplot2_plot_orchestrator.R` - `detect_layers()`

**Process:**
1. Retrieve layers from `plot$layers`
2. For each layer, call `analyze_single_layer()`

**Layer Structure:**
- `index`: Position in plot
- `type`: Layer type (bar, line, point, etc.)
- `geom_class`: Geom class
- `stat_class`: Stat class  
- `position_class`: Position class
- `aesthetics`: Mapping names
- `parameters`: Parameter names
- `layer_object`: Full ggplot layer object

**File:** `R/ggplot2_plot_orchestrator.R` - `analyze_single_layer()`

**Extraction:**
- Inspects `layer$geom`, `layer$stat`, `layer$position`
- Safely extracts mapping and parameters
- Delegates type detection to adapter
- Returns layer information

### Layer Type Detection

**File:** `R/ggplot2_adapter.R` - `detect_layer_type()`

**Detection logic:**
- Inspects geom/stat/position classes
- Maps to layer types:
  - `GeomLine`, `GeomPath` → "line"
  - `GeomSmooth`, `StatDensity` → "smooth"
  - `GeomBar`, `GeomCol` → "bar" variants
  - `GeomTile` → "heat"
  - `GeomPoint` → "point"
  - `GeomBoxplot` → "box"
  - `GeomText` → "skip"

**Special cases:**
- Bar: check stat → hist; position → dodged_bar; position + fill → stacked_bar
- Line: geom determines direct mapping
- Smooth: stat or geom determines type

### Processor Creation

**File:** `R/ggplot2_plot_orchestrator.R` - `create_layer_processors()`

**Process:**
1. Iterate detected layers
2. Skip "skip" types
3. Get processor factory from registry
4. Create processor via `factory$create_processor(layer_type, layer_info)`
5. Store processor

**Factory File:** `R/ggplot2_processor_factory.R`

**Processor mapping:**
- "bar" → Ggplot2BarLayerProcessor
- "dodged_bar" → Ggplot2DodgedBarLayerProcessor
- "stacked_bar" → Ggplot2StackedBarLayerProcessor
- "hist" → Ggplot2HistogramLayerProcessor
- "line" → Ggplot2LineLayerProcessor
- "smooth" → Ggplot2SmoothLayerProcessor
- "point" → Ggplot2PointLayerProcessor
- "box" → Ggplot2BoxplotLayerProcessor
- "heat" → Ggplot2HeatmapLayerProcessor
- Default → Ggplot2UnknownLayerProcessor

### Data Reordering

**File:** `R/ggplot2_plot_orchestrator.R` - `process_layers()`

**Purpose:** Some processors require data reordering before building.

**Process:**
1. Check if processor needs reordering via `needs_reordering()`
2. If true, call `processor$reorder_layer_data(plot$data, plot)`
3. Update plot data with reordered result

**Rationale:** Bar charts often store bottom-to-top; MAIDR expects top-to-bottom.

### Unified Grob Creation

**File:** `R/ggplot2_plot_orchestrator.R` - `process_layers()`

**Key steps:**
1. Build once: `built_final <- ggplot_build(plot_for_render)`
2. Create grob once: `gt_final <- ggplotGrob(plot_for_render)`
3. Store grob: `private$.gtable <- gt_final`

**Pattern:** One grob for all layers; processors search it.

### Processing Layers

**File:** `R/ggplot2_plot_orchestrator.R` - `process_layers()`

For each processor:
1. Pass plot, layout, built, and grob
2. Call `processor$process()`
   - Extracts data from built data
   - Searches grob tree
   - Generates selectors
3. Store result
4. Combine results into MAIDR format

---

## Faceted Plot Processing

**Files:** `R/ggplot2_facet_utils.R` + `R/ggplot2_plot_orchestrator.R`

### Overview

Faceted plots split data into panels. Processing handles per-panel data and selectors.

### Processing Entry

**File:** `R/ggplot2_plot_orchestrator.R` - `process_faceted_plot()`

**Process:**
1. Extract layout info
2. Build grob first
3. Get built data
4. Call `process_faceted_plot_data()`

### Facet Processing

**File:** `R/ggplot2_facet_utils.R` - `process_faceted_plot_data()`

**Steps:**
1. Extract panel layout from built
2. For each panel:
   - Get panel data
   - Get facet groups
   - Map visual to DOM panel
   - Call `process_facet_panel()`
     - Iterate layers
     - Create processors
     - Process with panel context
     - Combine panel results
3. Organize into 2D grid by ROW/COL
4. Return grid structure

### 2D Grid Structure

**Output format:**
```r
subplots = [
  [ subplot_1_1, subplot_1_2 ],  # Row 1
  [ subplot_2_1, subplot_2_2 ]   # Row 2
]
```

Rows and columns match visual layout.

### Panel Processing

**File:** `R/ggplot2_facet_utils.R` - `process_facet_panel()`

**Process:**
1. Iterate layers
2. Create processors via factory
3. Build panel context
4. Call `processor$process()` with context:
   - `panel_name`: Name in gtable
   - `row`, `col`: Position
   - `panel_id`: Panel identifier
   - `layer_index`: Layer index
5. Combine layer results
6. Build panel structure

### Panel Context

**Purpose:** Scoped selectors and data.

**Panel context structure:**
- `panel_name`: Gtable panel name
- `row`: Panel row
- `col`: Panel column
- `panel_id`: Panel ID from built layout
- `layer_index`: Layer index

**Usage:** Selectors target panel elements.

### Visual to DOM Mapping

**File:** `R/ggplot2_facet_utils.R` - `map_visual_to_dom_panel()`

**Problem:** Visual layout is row-major; DOM order is column-major.

**Solution:** Convert visual (row, col) to DOM panel name.

**Example:**
```
Visual:   DOM:
1  2      1  3
3  4      2  4
```

**Process:**
1. Get panel dimensions
2. Convert visual position to row-major index
3. Convert to column-major position
4. Generate DOM panel name

---

## Patchwork Plot Processing

**Files:** `R/ggplot2_patchwork_utils.R` + `R/ggplot2_plot_orchestrator.R`

### Overview

Patchwork composes multiple ggplot plots. Processing extracts and processes leaf plots.

### Processing Entry

**File:** `R/ggplot2_plot_orchestrator.R` - `process_patchwork_plot()`

**Process:**
1. Extract layout info
2. Build patchwork grob
3. Call `process_patchwork_plot_data()`

### Patchwork Processing

**File:** `R/ggplot2_patchwork_utils.R` - `process_patchwork_plot_data()`

**Steps:**
1. Discover panels
2. Determine grid dimensions
3. Prepare grid structure
4. Extract leaf plots
5. For each panel in row-major order:
   - Get leaf plot
   - Get panel name and position
   - Call `process_patchwork_panel()`
   - Place result in grid
6. Return 2D grid

### Panel Discovery

**File:** `R/ggplot2_patchwork_utils.R` - `find_patchwork_panels()`

**Process:**
1. Search gtable for names like "panel-<num>" or "panel-<row>-<col>"
2. Extract positions (t, l)
3. Infer row/col by ranking unique positions
4. Parse row/col from names if present
5. Return panel data frame

**Output:**
- `panel_index`
- `name`
- `row`, `col`

### Leaf Extraction

**File:** `R/ggplot2_patchwork_utils.R` - `extract_patchwork_leaves()`

**Purpose:** Extract ggplot objects from patchwork in visual order.

**Process:** Recursively traverse patchwork; return leaves.

**Result:** List of ggplot objects in order.

### Patchwork Panel Processing

**File:** `R/ggplot2_patchwork_utils.R` - `process_patchwork_panel()`

**Process:**
1. Create subplot ID
2. Iterate leaf layers
3. Create processors
4. Build panel context
5. Call `processor$process()` with patchwork context
6. Build layer structure
7. Return subplot with layers

### Grid Organization

Organize panels by position into a 2D grid.

**Grid structure:**
```r
grid[row][col] = subplot
```

Process in row-major order; support gaps.

---

## Unified Grob Pattern

### Single Plot

One grob for the entire plot; all processors share it.

### Faceted Plot

One grob with multiple panels; processors target specific panels via context.

### Patchwork Plot

One composed grob including all leaf plots; processors search the relevant portion.

### Processor Access

Processors receive the grob and search for their elements:
- Bars: search for rect grobs
- Lines: search for polyline grobs
- Points: search for point grobs

**Shared access:** Different layers, same grob; searches return distinct results.

---

## Layer Processor System

### Abstract Base Class

**File:** `R/layer_processor.R`

**Class:** `LayerProcessor`

**Required methods:**
- `process()`: Orchestrates processing
- `extract_data()`: Extracts data
- `generate_selectors()`: Generates CSS selectors

### Processor Implementations

**Files:** Individual processor files

**Bar processors:**
- `Ggplot2BarLayerProcessor` - Simple bars
- `Ggplot2DodgedBarLayerProcessor` - Dodged bars
- `Ggplot2StackedBarLayerProcessor` - Stacked bars

**Statistical processors:**
- `Ggplot2HistogramLayerProcessor` - Histograms
- `Ggplot2BoxplotLayerProcessor` - Boxplots
- `Ggplot2SmoothLayerProcessor` - Smooth curves

**Geometric processors:**
- `Ggplot2LineLayerProcessor` - Lines
- `Ggplot2PointLayerProcessor` - Points
- `Ggplot2HeatmapLayerProcessor` - Heatmaps

### Data Extraction

Processors extract data from built ggplot data using layer indices.

**Example - Bar processor:**
- Accesses `built$data[[layer_index]]`
- Extracts x (categories) and y (values)

**Example - Line processor:**
- Accesses layer data
- Checks for grouping
- Returns single line or multi-line arrays

### Selector Generation

Processors search the grob tree and generate CSS selectors.

**Strategies:**
- Recursive search for grobs matching a pattern
- Recursive search for child elements
- Generate SVG IDs and CSS selectors

**Panel support:**
- Panel context restricts to relevant panels
- Selectors target panel-specific elements

---

## Comparison with Base R

### Architectural Differences

| Aspect | ggplot2 | Base R |
|--------|---------|--------|
| **Input** | ggplot object | Device ID |
| **Layer detection** | Direct from `plot$layers` | Call grouping required |
| **Grouping needed** | No (explicit structure) | Yes (HIGH/LOW logic) |
| **Plot types** | Single / Faceted / Patchwork | Single only |
| **Grob creation** | Once, shared by all | Per group |
| **Data source** | `ggplot_build()` data | Call arguments |
| **Processing order** | Object-driven | Call-driven |
| **Multi-panel** | Native (facet/patchwork) | Not supported |
| **Reordering** | Supported | Not applicable |

### Detection Comparison

**ggplot2:** Uses object structure (`plot$layers`, `plot$facet`)  
**Base R:** Groups and expands calls

### Processing Comparison

**ggplot2:**
- Structured plot object
- Built data available
- Direct layer access

**Base R:**
- Captured call sequence
- Arguments as data source
- Grouping to derive layers

### Grob Creation Comparison

**ggplot2:**
- One grob for entire plot
- All layers share grob
- Panel support included

**Base R:**
- One grob per group
- Groups are independent
- No panel support

---

## Orchestration Flow Summary

### Single Plot

**Flow:**
1. Receive ggplot object
2. Detect layers from `plot$layers`
3. Create layer processors
4. Reorder data if needed
5. Build grob once
6. Process layers with shared grob
7. Combine results

### Faceted Plot

**Flow:**
1. Receive faceted ggplot
2. Detect facet configuration
3. Build grob with all panels
4. For each panel:
   - Process layers with panel context
   - Generate panel-specific selectors
5. Organize into 2D grid
6. Return grid structure

### Patchwork Plot

**Flow:**
1. Receive patchwork object
2. Build composed grob
3. Discover panels
4. Extract leaf plots
5. For each panel:
   - Process leaf layers
   - Generate panel-specific selectors
6. Organize into 2D grid
7. Return grid structure

### Key Design Patterns

**Unified grob:**
- One grob for the entire composition
- Panel-scoped selection via context

**Object-based processing:**
- Uses plot object, not replay
- Layers available without grouping

**Multi-panel support:**
- Native faceting
- Patchwork composition
- Grid-based organization

---

## Related Files

**Core Orchestration:**
- `R/ggplot2_plot_orchestrator.R` - Main orchestrator
- `R/ggplot2_adapter.R` - Layer type detection

**Multi-Panel Processing:**
- `R/ggplot2_facet_utils.R` - Faceted plot processing
- `R/ggplot2_patchwork_utils.R` - Patchwork processing

**Processors:**
- `R/ggplot2_processor_factory.R` - Processor factory
- `R/ggplot2_bar_layer_processor.R` - Bar plots
- `R/ggplot2_dodged_bar_layer_processor.R` - Dodged bars
- `R/ggplot2_stacked_bar_layer_processor.R` - Stacked bars
- `R/ggplot2_histogram_layer_processor.R` - Histograms
- `R/ggplot2_line_layer_processor.R` - Line plots
- `R/ggplot2_point_layer_processor.R` - Point plots
- `R/ggplot2_boxplot_layer_processor.R` - Boxplots
- `R/ggplot2_smooth_layer_processor.R` - Smooth curves
- `R/ggplot2_heatmap_layer_processor.R` - Heatmaps

**Base Classes:**
- `R/layer_processor.R` - Abstract processor interface
- `R/processor_factory.R` - Abstract factory interface

