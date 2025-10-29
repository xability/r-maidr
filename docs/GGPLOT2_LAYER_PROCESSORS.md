# ggplot2 Layer Processors Complete Guide

## Overview

ggplot2 layer processors extract data from built plot objects and generate CSS selectors from unified grob trees. Unlike Base R processors (which extract from captured function calls), ggplot2 processors work with ggplot's layer structure and built plot data from `ggplot2::ggplot_build()`.

**Note:** This document focuses on explanations. Refer to the actual code files for implementation details.

## Table of Contents

1. [Processor Structure](#processor-structure)
2. [Inputs from Orchestrator](#inputs-from-orchestrator)
3. [Processor Methods](#processor-methods)
4. [Data Extraction](#data-extraction)
5. [Selector Generation](#selector-generation)
6. [Reordering Logic](#reordering-logic)
7. [Faceting Support](#faceting-support)
8. [Complete Processing Flow](#complete-processing-flow)
9. [Processor Examples](#processor-examples)
10. [Key Design Patterns](#key-design-patterns)

---

## Processor Structure

### Base Class: LayerProcessor

**File:** `R/layer_processor.R`

Abstract base class defining the processor interface.

**Key fields:**
- `layer_info`: Information about the layer (set at initialization)

**Required methods (must be implemented by subclasses):**
- `process()`: Orchestrates the processing
- `extract_data()`: Extracts data from the layer
- `generate_selectors()`: Generates CSS selectors

**Optional methods (have defaults):**
- `needs_reordering()`: Returns whether reordering is needed (default: FALSE)
- `reorder_layer_data()`: Reorders plot data if needed (default: no-op)

**Utility methods:**
- `get_layer_index()`: Gets layer index from layer_info
- `set_last_result()`: Stores result for orchestrator
- `get_last_result()`: Retrieves stored result
- `apply_scale_mapping()`: Applies scale mapping to values

### Concrete Processors

All ggplot2 processors inherit from `LayerProcessor`:

- `Ggplot2BarLayerProcessor` - Bar charts
- `Ggplot2DodgedBarLayerProcessor` - Grouped bars (side-by-side)
- `Ggplot2StackedBarLayerProcessor` - Stacked bars
- `Ggplot2HistogramLayerProcessor` - Histograms
- `Ggplot2LineLayerProcessor` - Line plots (single and multi-line)
- `Ggplot2SmoothLayerProcessor` - Smooth curves and density plots
- `Ggplot2PointLayerProcessor` - Scatter plots
- `Ggplot2BoxplotLayerProcessor` - Box plots
- `Ggplot2HeatmapLayerProcessor` - Heatmaps
- `Ggplot2UnknownLayerProcessor` - Fallback for unsupported types

Each processor implements the required methods with plot-type-specific logic.

---

## Inputs from Orchestrator

### When Processor is Called

The orchestrator calls processors in `process_layers()` method:

**File:** `R/ggplot2_plot_orchestrator.R` - lines 126-155

**Context:**
- After reordering pass completes
- For each layer processor
- With built data and grob tree ready

### Parameters Passed

**Primary parameters:**
- `plot`: The ggplot2 plot object
- `layout`: Layout information (title, axes labels)
- `built`: Built plot data from `ggplot2::ggplot_build(plot)`
- `gt`: Unified grob tree (gtable object)

**Additional parameters (for faceted plots):**
- `scale_mapping`: Mapping from numeric indices to actual axis values
- `grob_id`: Grob identifier for faceted panel
- `panel_id`: Panel identifier for faceted plot
- `panel_ctx`: Panel context for panel-scoped selector generation

### The Critical Input: built Data

**Structure of built data:**
```r
built = ggplot2::ggplot_build(plot)
built$data[[layer_index]]  # Layer-specific data
```

**What built$data contains:**
- For each layer: `x`, `y`, `group`, `fill`, `colour`, `PANEL`, etc.
- PANEL column for faceted plots (identifies which panel each row belongs to)
- Scale-transformed values (numeric indices for categorical data)

**How processors access it:**
```r
layer_data <- built$data[[layer_index]]
# Access: layer_data$x, layer_data$y, etc.
```

### The Grob Tree Input

**What is passed:**
- Unified grob tree containing all elements from the plot
- Same grob shared by all layers in the plot
- Contains grob structure with names, children, etc.

**Why it matters:** Processors search this grob tree for their specific elements (geom_rect, GRID.polyline, etc.).

### layer_info Structure

**File:** `R/ggplot2_plot_orchestrator.R` - `analyze_single_layer()`

**Structure of layer_info:**
```r
layer_info = {
  index: Layer index (1, 2, 3, ...)
  type: Layer type ("bar", "hist", "line", etc.)
  geom_class: Geom class name ("GeomBar", "GeomLine", etc.)
  stat_class: Stat class name
  position_class: Position class name
  aesthetics: Names of aesthetic mappings
  parameters: Names of layer parameters
  layer_object: The ggplot layer object
}
```

**Key point:** `layer_info` contains layer metadata and index, while data comes from `built$data[[index]]`.

---

## Processor Methods

### 1. process() - Main Orchestration Method

**Purpose:** Coordinates all processing steps

**What it does:**
1. Calls `extract_data(plot, built, ...)` to get data points
2. Calls `generate_selectors(plot, gt, ...)` to get CSS selectors
3. Combines into standard result structure
4. Returns to orchestrator

**Return structure:**
```r
{
  data: Extracted data points (list or nested list)
  selectors: CSS selectors list
  type: Layer type ("bar", "hist", "line", etc.)
  title: Layer title (optional)
  axes: {x: "X axis label", y: "Y axis label"} (optional)
  orientation: "horz" or "vert" (for boxplots)
}
```

**Role:** Main entry point; orchestrates extraction and selector generation.

### 2. extract_data() - Data Extraction

**Purpose:** Extracts plot data from built plot object

**Input:** `plot` object, `built` data (optional)

**What it accesses:**
- `built$data[[layer_index]]`: Layer-specific built data
- `plot$layers[[layer_index]]$mapping`: Layer-specific aesthetic mappings
- `plot$mapping`: Plot-level aesthetic mappings
- `plot$data`: Original data used to create plot

**Extraction process:**
1. Get layer data from `built$data[[self$get_layer_index()]]`
2. Filter by panel if panel_id is provided (for faceting)
3. Extract aesthetic mappings (x, y, fill, colour, etc.)
4. Map indices to actual values using scale mapping or original data
5. Convert to MAIDR data format
6. Return data points

**Data formats:**
- **Bars:** List of `{x, y}` objects
- **Dodged/Stacked bars:** Nested list (groups by fill)
- **Histograms:** List of `{x, y, xMin, xMax, yMin, yMax}` objects
- **Lines:** Nested list (groups by series for multiline)
- **Points:** List of `{x, y, color?}` objects
- **Boxplots:** List of statistical objects

**Role:** Converts ggplot built data into structured MAIDR data.

### 3. generate_selectors() - Selector Generation

**Purpose:** Generates CSS selectors for SVG elements

**Input:** `plot`, `gt` (grob tree), `grob_id`, `panel_ctx`

**Process:**
1. Search grob tree for elements matching layer type
2. Look for specific patterns (geom_rect, GRID.polyline, etc.)
3. Extract grob names
4. Convert to CSS selectors
5. Return selectors list

**Two approaches:**
- **Panel-scoped (panel_ctx):** Search within specific panel's grob
- **Global (gt):** Search entire gtable structure

**Selector format:**
```css
#geom_rect.rect.1.1 rect
```
- Target: SVG elements of type "rect"
- ID prefix: "geom_rect.rect.1"
- Suffix: ".1" (gridSVG convention)

**Role:** Creates selectors that target SVG elements in the HTML.

### 4. needs_reordering() - Reordering Check

**Purpose:** Indicates whether plot data needs reordering

**Returns:** TRUE or FALSE

**When TRUE:**
- Bar charts need data sorted to match SVG rendering order
- Processors that need `reorder_layer_data()`

**When FALSE:**
- Line plots, point plots, histograms (data order matches SVG)

**Role:** Tells orchestrator to reorder data before building grob.

### 5. reorder_layer_data() - Data Reordering

**Purpose:** Reorders plot data to match SVG element order

**Input:** `data` (data.frame), `plot` (ggplot object)

**Reordering logic:**
- Bar plots: Sort by x values
- Dodged bars: Sort by x, then by fill
- Stacked bars: Sort by category, then by fill
- Heatmaps: Sort by x and y

**Critical point:** Reordering happens BEFORE `ggplot2::ggplot_build()` is called, ensuring the grob reflects the desired order.

**Role:** Ensures data and SVG elements are in the same order.

---

## Data Extraction

### Bar Plot Extraction

**File:** `R/ggplot2_bar_layer_processor.R` - `extract_data()`

**Process:**
1. Get layer data from `built$data[[layer_index]]`
2. Extract aesthetic mappings (x column)
3. Filter by panel if panel_id is provided
4. Map x indices to actual values using:
   - `scale_mapping` (if provided for faceted plots)
   - Original data from `plot$data`
5. Extract y values from built data
6. Convert to data points

**Example:**
```r
# User plot: ggplot(df, aes(x=category, y=value)) + geom_bar(stat="identity")
# Layer data: built$data[[1]] contains x (indices), y (values)
# Original data: df$category = ["A", "B", "C"]
# Extracted: [{x: "A", y: 10}, {x: "B", y: 20}, {x: "C", y: 30}]
```

**Faceted plots:** Maps numeric x indices to actual category values using scale mapping or original data filtering.

### Dodged Bar Extraction

**File:** `R/ggplot2_dodged_bar_layer_processor.R` - `extract_data()`

**Process:**
1. Get aesthetic mappings (x, y, fill)
2. Split original data by fill column
3. For each fill group:
   - Get rows for that group
   - Sort by x values
   - Extract as list of points
4. Return nested list: outer list (fill groups), inner list (points)

**Example:**
```r
# User plot: ggplot(df, aes(x=cat, y=val, fill=group)) + geom_bar(position="dodge")
# Data: df has columns cat=["A","B"], val=[10,20,30,40], group=["G1","G2"]
# Extracted: [
#   [{x: "A", y: 10, fill: "G1"}, {x: "B", y: 20, fill: "G1"}],
#   [{x: "A", y: 30, fill: "G2"}, {x: "B", y: 40, fill: "G2"}]
# ]
```

**Key point:** Outer list = fill groups; inner list = points within group.

### Stacked Bar Extraction

**File:** `R/ggplot2_stacked_bar_layer_processor.R` - `extract_data()`

**Process:**
1. Get aesthetic mappings (x, y, fill)
2. Extract stacking order from first bar in built data
3. Split original data by fill column
4. For each fill group (in stacking order):
   - Get rows for that group
   - Sort by x values
   - Extract as list of points
5. Return nested list by fill group

**Key difference from dodged:** Stacking order determined from built data (which shows first bar's segment order).

**Example:**
```r
# User plot: ggplot(df, aes(x=cat, y=val, fill=seg)) + geom_bar(position="stack")
# Stacking order from built data: ["B", "A"] (bottom to top)
# Extracted: [
#   [{x: "1", y: 5, fill: "B"}, ...],  # Bottom segments
#   [{x: "1", y: 3, fill: "A"}, ...]   # Top segments
# ]
```

### Histogram Extraction

**File:** `R/ggplot2_histogram_layer_processor.R` - `extract_data()`

**Process:**
1. Find histogram layers in built data
2. For each layer:
   - Extract x, y, xmin, xmax, ymin, ymax
3. Convert to data points with bin boundaries

**Data format:**
```r
{
  x: Bin midpoint,
  y: Bin count/density,
  xMin: Bin left edge,
  xMax: Bin right edge,
  yMin: 0,
  yMax: Bin count/density
}
```

**Example:**
```r
# User plot: ggplot(df, aes(x=value)) + geom_histogram()
# Extracted: [
#   {x: 10.5, y: 5, xMin: 10, xMax: 11, yMin: 0, yMax: 5},
#   {x: 11.5, y: 8, xMin: 11, xMax: 12, yMin: 0, yMax: 8},
#   ...
# ]
```

### Line Plot Extraction

**File:** `R/ggplot2_line_layer_processor.R` - `extract_data()`

**Process:**
1. Get layer data from built
2. Check for group column
3. If multiple groups: Extract multiline data
   - Split by group
   - Map group numbers to category names
   - Return nested list (one array per series)
4. If single group: Extract single line data
   - Return single list of points

**Multiline example:**
```r
# User plot: ggplot(df, aes(x=year, y=value, color=category)) + geom_line()
# Groups: [-1, -1, 1, 1, 2, 2]
# Categories: ["A", "B"]
# Extracted: [
#   [{x: 2020, y: 10, fill: "A"}, {x: 2021, y: 15, fill: "A"}, ...],  # Series A
#   [{x: 2020, y: 20, fill: "B"}, {x: 2021, y: 25, fill: "B"}, ...]  # Series B
# ]
```

**Key point:** Returns nested list when multiple groups exist.

### Smooth Curve Extraction

**File:** `R/ggplot2_smooth_layer_processor.R` - `extract_data()`

**Process:**
1. Find smooth layers (GeomSmooth, GeomLine, GeomDensity)
2. Get first smooth layer's data
3. Extract x and y values
4. Return as nested list (one line with many points)

**Example:**
```r
# User plot: ggplot(df, aes(x=x, y=y)) + geom_smooth()
# Extracted: [[{x: -1.2, y: 0.01}, {x: -1.1, y: 0.02}, ...]]
```

**Key point:** Returns single list with many points (nested for consistency with multiline format).

### Point Plot Extraction

**File:** `R/ggplot2_point_layer_processor.R` - `extract_data()`

**Process:**
1. Get layer data from built
2. Filter by panel if panel_id is provided
3. Extract aesthetic mappings (x, y, colour)
4. Map x indices to actual values
5. Create point objects: `{x, y, color?}`
6. Return flat list of points

**Example:**
```r
# User plot: ggplot(df, aes(x=xval, y=yval, color=group)) + geom_point()
# Extracted: [
#   {x: 1.0, y: 2.0, color: "A"},
#   {x: 2.0, y: 3.0, color: "A"},
#   {x: 3.0, y: 4.0, color: "B"},
#   ...
# ]
```

### Boxplot Extraction

**File:** `R/ggplot2_boxplot_layer_processor.R` - `extract_data()`

**Process:**
1. Get layer data from built
2. Extract boxplot statistics for each category
3. For each category:
   - Extract min, max, q1, q3, q2 (median)
   - Parse outliers string: "c(value1, value2)"
   - Split into lower and upper outliers
4. Map numeric category codes to actual category names
5. Return list of boxplot statistics

**Data format:**
```r
{
  min: Minimum value (including outliers)
  max: Maximum value (including outliers)
  q1: First quartile (box bottom)
  q3: Third quartile (box top)
  q2: Median (box middle line)
  fill: Category name
  lowerOutliers: [list of outlier values < whisker]
  upperOutliers: [list of outlier values > whisker]
}
```

**Example:**
```r
# User plot: ggplot(df, aes(x=category, y=value)) + geom_boxplot()
# Extracted: [
#   {
#     min: 5, max: 20, q1: 10, q3: 15, q2: 12,
#     fill: "A",
#     lowerOutliers: [],
#     upperOutliers: [18, 19, 20]
#   },
#   ...
# ]
```

**Key point:** Needs to parse outlier strings and map numeric categories to names.

---

## Selector Generation

### Pattern-Based Selection

**Basic approach:**
- Look for patterns in grob names
- Use `grepl()` to match patterns
- Extract grob names

**Patterns by plot type:**
- **Bar:** `geom_rect\\.rect`
- **Line:** `GRID\\.polyline`
- **Point:** `geom_point\\.points`
- **Boxplot:** `geom_boxplot\\.gTree`
- **Smooth:** `GRID\\.polyline` (last/highest numbered)

### Recursive Grob Search

**Search algorithm:**
1. Check current grob's name (if matches pattern)
2. Search in `gTree$children`
3. Search in `gList` items
4. Return all matching names

**Helper function pattern:**
```r
find_elements <- function(grob, pattern) {
  names <- character(0)
  if (!is.null(grob$name) && grepl(pattern, grob$name)) {
    names <- c(names, grob$name)
  }
  if (inherits(grob, "gList")) {
    for (child in grob) {
      names <- c(names, find_elements(child, pattern))
    }
  }
  if (inherits(grob, "gTree")) {
    for (child in grob$children) {
      names <- c(names, find_elements(child, pattern))
    }
  }
  names
}
```

### Selector Conversion

**From grob name to CSS selector:**

**Process:**
1. Add `.1` suffix (gridSVG convention)
2. Escape dots for CSS: `.` → `\\.`
3. Create selector: `#escaped_name element`

**Example:**
```
Grob name: "geom_rect.rect.1"
With suffix: "geom_rect.rect.1.1"
Escaped: "geom_rect\\.rect\\.1\\.1"
Selector: "#geom_rect\\.rect\\.1\\.1 rect"
```

### Panel-Scoped Selection

**When panel_ctx is provided:**

**Process:**
1. Get panel name from `panel_ctx$panel_name`
2. Find panel grob in gtable layout
3. Search within that panel's grob only
4. Generate selectors for elements found

**Advantage:** More robust for faceted plots (doesn't accidentally match elements from other panels).

### Faceted Plot Selection

**File:** `R/ggplot2_bar_layer_processor.R` - `generate_selectors()`

**Two modes:**
1. **Panel-scoped (panel_ctx):** Search within specific panel
2. **Global (gt):** Use provided grob_id or search full gtable

**When panel_ctx is used:**
- More robust selector generation
- Limits search to specific panel
- Avoids cross-panel matching

**When grob_id is used:**
- Direct reference to grob
- Faster selector generation
- Used by orchestrator when grob already identified

---

## Reordering Logic

### Why Reordering is Needed

**Problem:** ggplot2 sometimes renders elements in a different order than the data appears.

**Example:** Bar chart with unsorted data
```r
df <- data.frame(category = c("C", "A", "B"), value = c(30, 10, 20))
p <- ggplot(df, aes(x=category, y=value)) + geom_bar(stat="identity")
```

**Issue:** SVG bars render in alphabetical order (A, B, C), but data is (C, A, B).

**Solution:** Reorder data to match SVG rendering order.

### When Reordering Happens

**File:** `R/ggplot2_plot_orchestrator.R` - lines 130-140

**Sequence:**
1. Orchestrator calls `needs_reordering()` for each processor
2. If TRUE, calls `reorder_layer_data()` to modify `plot$data`
3. After all processors checked, calls `ggplot2::ggplot_build()` with reordered data
4. SVG elements now rendered in same order as (reordered) data

**Key point:** Reordering happens BEFORE grob is built.

### Reordering by Plot Type

**Bar plots:**
```r
# Reorder by x values
data[order(data[[x_col]]), , drop = FALSE]
```

**Dodged bars:**
```r
# Reorder by x, then by fill
x_ordered <- factor(data[[x_col]], levels = sort(unique(data[[x_col]])))
fill_ordered <- factor(data[[fill_col]], levels = rev(sort(unique(data[[fill_col]]))))
data[order(x_ordered, fill_ordered), , drop = FALSE]
```

**Stacked bars:**
```r
# Reorder by category, then by fill
data[order(data[[category_col]], data[[fill_col]]), , drop = FALSE]
```

**Heatmaps:**
```r
# Reorder by x and y (to match visual layout)
# Implementation varies by processor
```

### Impact on Processing

**What changes:**
- `plot$data` is reordered BEFORE `ggplot2::ggplot_build()` is called
- Built data reflects reordered structure
- SVG elements rendered in reordered order
- Data extraction matches SVG element order
- Selectors match data points in correct sequence

**What doesn't change:**
- Layer structure
- Aesthetic mappings
- Visual appearance of plot
- User's original data (only processing copy is modified)

---

## Faceting Support

### Understanding Faceting

**What is faceting:** Breaking data into multiple panels based on variables.

**Example:**
```r
ggplot(df, aes(x=category, y=value)) + 
  geom_bar(stat="identity") + 
  facet_wrap(~group)
```

Creates multiple panels, one per group value.

### Faceting Parameters

**Provided by orchestrator:**

**scale_mapping:**
- Maps numeric indices to actual axis values
- Example: `{1: "A", 2: "B", 3: "C"}` for x-axis

**panel_id:**
- Identifies which panel is being processed
- Example: `1, 2, 3, ...` for each panel

**panel_ctx:**
- Panel context for selector generation
- Contains panel name, position, etc.

### Faceted Plot Processing

**File:** `R/ggplot2_facet_utils.R`

**Process:**
1. Build full faceted plot
2. Extract panel information
3. For each panel:
   - Filter built data by PANEL column
   - Generate scale mapping for axis values
   - Process layers for that panel
   - Create panel-specific grob context
4. Organize into 2D grid structure

### Scale Mapping Application

**Purpose:** Convert numeric indices to actual category values.

**Example:**
```r
# Built data has x = c(1, 2, 3)  # Numeric indices
# Scale mapping: {1: "A", 2: "B", 3: "C"}
# Applied: x_values = c("A", "B", "C")  # Actual values
```

**How processors use it:**
```r
if (!is.null(scale_mapping)) {
  x_values <- self$apply_scale_mapping(layer_data$x, scale_mapping)
} else {
  # Fallback: get from original data
  x_values <- unique(panel_data[[x_col]])
}
```

### Panel Data Filtering

**For each panel:**
```r
layer_data <- built$data[[layer_index]]
if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
  layer_data <- layer_data[layer_data$PANEL == panel_id, ]
}
```

**Key point:** Only process data belonging to current panel.

---

## Complete Processing Flow

### Orchestrator Calls Processor

**Context:** `Ggplot2PlotOrchestrator$process_layers()`

**When:** After reordering pass completes

**Call:**
```r
processor$process(
  plot = private$.plot,  # ggplot2 plot object
  layout = private$.layout,  # Layout info
  built = built_final,  # Built plot data
  gt = private$.gtable,  # Unified grob
  scale_mapping = NULL,  # For faceted plots
  grob_id = NULL,  # For faceted plots
  panel_id = NULL,  # For faceted plots
  panel_ctx = NULL  # For faceted plots
)
```

### Processor Executes

**Step 1: Extract data**
- Calls `extract_data(plot, built, scale_mapping, panel_id)`
- Gets layer index: `self$get_layer_index()`
- Accesses layer data: `built$data[[layer_index]]`
- Filters by panel if panel_id provided
- Maps indices to actual values
- Converts to MAIDR format
- Returns data points

**Step 2: Generate selectors**
- Calls `generate_selectors(plot, gt, grob_id, panel_ctx)`
- Searches grob tree for elements
- Generates CSS selectors
- Returns selectors list

**Step 3: Combine results**
- Creates standard result structure
- Returns to orchestrator

### Orchestrator Uses Results

**Context:** `Ggplot2PlotOrchestrator$process_layers()`

**After processing:**
1. Store result: `processor$set_last_result(result)`
2. Add to layer results list
3. Continue with next processor

**Then:** `combine_layer_results()` combines all processor results into MAIDR format

---

## Processor Examples

### Example 1: Simple Bar Plot

**User code:**
```r
df <- data.frame(category = c("A", "B", "C"), value = c(10, 20, 30))
p <- ggplot(df, aes(x=category, y=value)) + geom_bar(stat="identity")
maidr::show(p)
```

**Processing:**

**Layer created:**
```r
{
  index: 1,
  type: "bar",
  geom_class: "GeomBar",
  ...
}
```

**Processor: Ggplot2BarLayerProcessor**

**Data extraction:**
- Get layer data from `built$data[[1]]`
- Extract x mapping: "category"
- Extract y values: [10, 20, 30]
- Map x values from original data: ["A", "B", "C"]
- Return: `[{x: "A", y: 10}, {x: "B", y: 20}, {x: "C", y: 30}]`

**Selector generation:**
- Search grob for `geom_rect.rect` patterns
- Find grobs: "geom_rect.rect.1"
- Generate: `["#geom_rect\\.rect\\.1\\.1 rect"]`

**Result:**
```r
{
  data: [{x: "A", y: 10}, {x: "B", y: 20}, {x: "C", y: 30}],
  selectors: ["#geom_rect\\.rect\\.1\\.1 rect"],
  type: "bar"
}
```

### Example 2: Multiline Plot

**User code:**
```r
df <- data.frame(year = c(2020, 2021, 2022, 2020, 2021, 2022),
                 value = c(10, 15, 20, 20, 25, 30),
                 series = c("A", "A", "A", "B", "B", "B"))
p <- ggplot(df, aes(x=year, y=value, color=series)) + geom_line()
maidr::show(p)
```

**Processing:**

**Layer created:**
```r
{
  index: 1,
  type: "line",
  geom_class: "GeomLine",
  ...
}
```

**Processor: Ggplot2LineLayerProcessor**

**Data extraction:**
- Get layer data from `built$data[[1]]`
- Detect multiple groups: [1, 1, 2, 2, 1, 1]  # groups
- Extract group column: "series"
- Get category names: ["A", "B"]
- Split by group
- Return nested:
  ```r
  [
    [{x: 2020, y: 10, fill: "A"}, {x: 2021, y: 15, fill: "A"}, {x: 2022, y: 20, fill: "A"}],
    [{x: 2020, y: 20, fill: "B"}, {x: 2021, y: 25, fill: "B"}, {x: 2022, y: 30, fill: "B"}]
  ]
  ```

**Selector generation:**
- Search for `GRID.polyline` grobs
- Find main grob: "GRID.polyline.61"
- Extract base ID: "61"
- Count groups: 2
- Generate: `["#GRID\\.polyline\\.61\\.1\\.1", "#GRID\\.polyline\\.61\\.1\\.2"]`

**Result:**
```r
{
  data: [...],  # Nested by series
  selectors: ["#GRID\\.polyline\\.61\\.1\\.1", "#GRID\\.polyline\\.61\\.1\\.2"],
  type: "line"
}
```

### Example 3: Dodged Bar Plot

**User code:**
```r
df <- data.frame(category = c("A", "B", "A", "B"),
                 value = c(10, 20, 30, 40),
                 group = c("G1", "G1", "G2", "G2"))
p <- ggplot(df, aes(x=category, y=value, fill=group)) + 
     geom_bar(stat="identity", position="dodge")
maidr::show(p)
```

**Processing:**

**Layer created:**
```r
{
  index: 1,
  type: "dodged_bar",
  geom_class: "GeomBar",
  ...
}
```

**Processor: Ggplot2DodgedBarLayerProcessor**

**Reordering:**
- Needs reordering: TRUE
- Reorder data by x (category), then by fill (group)
- Reordered data matches SVG rendering order

**Data extraction:**
- Extract mappings: x="category", y="value", fill="group"
- Split by fill: Group="G1", Group="G2"
- For each group: extract points sorted by x
- Return nested:
  ```r
  [
    [{x: "A", y: 10, fill: "G1"}, {x: "B", y: 20, fill: "G1"}],
    [{x: "A", y: 30, fill: "G2"}, {x: "B", y: 40, fill: "G2"}]
  ]
  ```

**Selector generation:**
- Search for `geom_rect.rect` patterns
- Find grobs: "geom_rect.rect.1"
- Generate: `["#geom_rect\\.rect\\.1\\.1 rect"]`

**Result:**
```r
{
  data: [...],  # Nested by fill group
  selectors: ["#geom_rect\\.rect\\.1\\.1 rect"],
  type: "dodged_bar"
}
```

### Example 4: Stacked Bar Plot

**User code:**
```r
df <- data.frame(category = c("A", "B", "A", "B"),
                 value = c(10, 20, 30, 40),
                 segment = c("B1", "B1", "B2", "B2"))
p <- ggplot(df, aes(x=category, y=value, fill=segment)) + 
     geom_bar(stat="identity", position="stack")
maidr::show(p)
```

**Processing:**

**Layer created:**
```r
{
  index: 1,
  type: "stacked_bar",
  geom_class: "GeomBar",
  ...
}
```

**Processor: Ggplot2StackedBarLayerProcessor**

**Reordering:**
- Needs reordering: TRUE
- Extract stacking order from first bar's built data
- Stacking order: ["B1", "B2"] (bottom to top)
- Reorder data to match this order

**Data extraction:**
- Extract mappings: x="category", y="value", fill="segment"
- Get stacking order: ["B1", "B2"]
- Split by segment (in stacking order)
- For each segment: extract points sorted by x
- Return nested:
  ```r
  [
    [{x: "A", y: 10, fill: "B1"}, {x: "B", y: 20, fill: "B1"}],  # Bottom
    [{x: "A", y: 30, fill: "B2"}, {x: "B", y: 40, fill: "B2"}]   # Top
  ]
  ```

**Selector generation:**
- Search for `geom_rect.rect` patterns
- Generate: `["#geom_rect\\.rect\\.1\\.1 rect"]`

**Result:**
```r
{
  data: [...],  # Nested by segment (stacking order)
  selectors: ["#geom_rect\\.rect\\.1\\.1 rect"],
  type: "stacked_bar"
}
```

---

## Key Design Patterns

### 1. built Data as Primary Source

ggplot2 processors receive:
- `built` data from `ggplot2::ggplot_build(plot)`
- Layer-specific data in `built$data[[layer_index]]`
- Contains x, y, group, fill, colour, PANEL, etc.

Not needed in ggplot2: captured call arguments (Base R concept).

### 2. Unified Grob Pattern

Processors receive:
- One grob per plot (shared by all layers)
- Search for specific elements (geom_rect, GRID.polyline, etc.)
- Creates CSS selectors from grob names

Different from Base R: Base R creates grobs by replaying calls.

### 3. Built Data Based Extraction

Data extraction:
- Uses transformed values from ggplot2::ggplot_build()
- Numeric indices for categorical data
- Scale-transformed positions
- Group information for multiline/multibar

Different from Base R, which uses function arguments directly.

### 4. Reordering Before Building

Critical sequence:
1. Check if reordering needed
2. Reorder plot$data if needed
3. THEN call ggplot2::ggplot_build()
4. NOW grob reflects reordered structure

This ensures SVG elements match data order.

### 5. Faceting Support

Processors handle faceting through:
- `panel_id`: Filter data for specific panel
- `scale_mapping`: Map indices to values
- `panel_ctx`: Panel-scoped selector generation

Different from Base R, which doesn't support faceting yet.

### 6. Scale Mapping Pattern

For faceted plots:
- built data contains numeric indices (1, 2, 3)
- Scale mapping provides actual values ("A", "B", "C")
- Processors apply mapping to get real category names

Critical for correct axis labels in faceted plots.

---

## Related Files

**Processor Files:**
- `R/ggplot2_bar_layer_processor.R` - Bar plot processor
- `R/ggplot2_dodged_bar_layer_processor.R` - Dodged bar processor
- `R/ggplot2_stacked_bar_layer_processor.R` - Stacked bar processor
- `R/ggplot2_histogram_layer_processor.R` - Histogram processor
- `R/ggplot2_line_layer_processor.R` - Line plot processor
- `R/ggplot2_point_layer_processor.R` - Point plot processor
- `R/ggplot2_boxplot_layer_processor.R` - Boxplot processor
- `R/ggplot2_smooth_layer_processor.R` - Smooth curve processor
- `R/ggplot2_heatmap_layer_processor.R` - Heatmap processor

**Base Classes:**
- `R/layer_processor.R` - Abstract processor interface
- `R/processor_factory.R` - Factory base class

**Factories:**
- `R/ggplot2_processor_factory.R` - Creates ggplot2 processors
- `R/base_r_processor_factory.R` - Creates Base R processors

**Orchestration:**
- `R/ggplot2_plot_orchestrator.R` - Calls processors
- `R/ggplot2_facet_utils.R` - Faceting utilities
- `R/ggplot2_patchwork_utils.R` - Patchwork utilities

