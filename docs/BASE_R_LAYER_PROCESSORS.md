# Base R Layer Processors Complete Guide

## Overview

Base R layer processors extract data from captured function calls and generate CSS selectors from grob trees. Unlike ggplot2 processors (which extract from built plot data), Base R processors work with logged call arguments and grob trees created from replays.

**Note:** This document focuses on explanations. Refer to the actual code files for implementation details.

## Table of Contents

1. [Processor Structure](#processor-structure)
2. [Inputs from Orchestrator](#inputs-from-orchestrator)
3. [Processor Methods](#processor-methods)
4. [Data Extraction](#data-extraction)
5. [Selector Generation](#selector-generation)
6. [Utility Methods](#utility-methods)
7. [Complete Processing Flow](#complete-processing-flow)
8. [Processor Examples](#processor-examples)

---

## Processor Structure

### Base Class: LayerProcessor

**File:** `R/layer_processor.R`

Abstract base class defining the processor interface.

**Key fields:**
- `layer_info`: Information about the layer (set at initialization)
- `.last_result`: Stores last processing result (private field)

**Required methods (must be implemented by subclasses):**
- `process()`: Orchestrates the processing
- `extract_data()`: Extracts data from the layer
- `generate_selectors()`: Generates CSS selectors

**Optional methods (have defaults):**
- `needs_reordering()`: Returns FALSE (Base R doesn't need reordering)
- `reorder_layer_data()`: No-op for Base R

**Utility methods:**
- `get_layer_index()`: Gets layer index from layer_info
- `set_last_result()`: Stores result for orchestrator
- `get_last_result()`: Retrieves stored result
- `apply_scale_mapping()`: Applies scale mapping to values

### Concrete Processors

All Base R processors inherit from `LayerProcessor`:

- `BaseRBarplotLayerProcessor` - Simple bar plots
- `BaseRDodgedBarLayerProcessor` - Dodged (grouped) bars
- `BaseRStackedBarLayerProcessor` - Stacked bars
- `BaseRHistogramLayerProcessor` - Histograms
- `BaseRSmoothLayerProcessor` - Density/smooth curves
- `BaseRUnknownLayerProcessor` - Fallback for unsupported types

Each processor implements the required methods with plot-type-specific logic.

---

## Inputs from Orchestrator

### When Processor is Called

The orchestrator calls processors in `process_layers()` method:

**File:** `R/base_r_plot_orchestrator.R` - lines 152-171

**Context:**
- For each layer processor
- Get grob for the layer
- Call `processor$process()` with parameters

### Parameters Passed

**Primary parameters:**
- `plot`: NULL (Base R has no plot object)
- `layout`: Layout information (title, axes)
- `built`: NULL (Base R doesn't use built data)
- `gt`: The unified grob tree for the layer's group
- `layer_info`: Complete layer information (new for Base R)

**Additional parameters (not used by Base R):**
- `scale_mapping`: NULL
- `grob_id`: NULL
- `panel_id`: NULL
- `panel_ctx`: NULL

### The Critical Input: layer_info

**Structure of layer_info:**
```r
layer_info = {
  index: Layer index (1, 2, 3, ...)
  type: Layer type ("bar", "hist", "smooth", etc.)
  function_name: Original function name ("barplot", "hist", "lines")
  args: Function arguments (the actual data!)
  call_expr: Call expression (string)
  plot_call: Full call object
  group: Reference to original group
  group_index: Which group this layer belongs to
  source: "HIGH" or "LOW"
  low_call_index: Position within LOW calls (if LOW)
}
```

**Key point:** `layer_info$args` contains the actual function arguments used when the plot was created.

### The Grob Tree Input

**File:** `R/base_r_plot_orchestrator.R` - `get_grob_for_layer()`

**What is passed:**
- Unified grob containing all elements from the group
- Same grob shared by all layers in the group
- Contains grob structure with names, children, etc.

**Why it matters:** Processors search this grob tree for their specific elements (rect, polyline, etc.).

---

## Processor Methods

### 1. process() - Main Orchestration Method

**Purpose:** Coordinates all processing steps

**What it does:**
1. Calls `extract_data(layer_info)` to get data points
2. Calls `generate_selectors(layer_info, gt)` to get CSS selectors
3. Calls `extract_axis_titles(layer_info)` for axis labels
4. Calls `extract_main_title(layer_info)` for plot title
5. Combines all into standard result structure

**Return structure:**
```r
{
  data: Extracted data points
  selectors: CSS selectors list
  type: Layer type ("bar", "hist", etc.)
  title: Main title string
  axes: { x: "X axis label", y: "Y axis label" }
  domOrder: "forward" (for dodged/stacked bars)
}
```

**Role:** Main entry point; orchestrates extraction and selector generation.

### 2. extract_data() - Data Extraction

**Purpose:** Extracts plot data from function call arguments

**Input:** `layer_info` object

**What it accesses:**
- `layer_info$plot_call`: The captured call object
- `layer_info$plot_call$args`: Function arguments (height, x, labels, etc.)
- `layer_info$args`: Same as above (direct access)

**Extraction process:**
1. Get args from `layer_info$plot_call$args` or `layer_info$args`
2. Extract specific argument (e.g., `args[[1]]` for first argument)
3. Convert to MAIDR data format
4. Return data points list

**Data formats:**
- **Bars:** List of `{x, y}` objects
- **Histograms:** List of `{x, y, xMin, xMax, yMin, yMax}` objects
- **Smooth:** Nested list (one line with many points)
- **Dodged bars:** Nested list (groups by fill)

**Role:** Converts Base R arguments into structured MAIDR data.

### 3. generate_selectors() - Selector Generation

**Purpose:** Generates CSS selectors for SVG elements

**Input:** `layer_info` and `gt` (grob tree)

**Process:**
1. Get group index from layer_info
2. Call helper method to search grob tree
3. Find grobs matching element type (rect, polyline, etc.)
4. Generate CSS selectors from grob names
5. Return selectors list

**Two approaches:**
- **Pattern-based:** Look for specific patterns in grob names
- **Robust search:** Use utility functions to find elements

**Selector format:**
```css
#graphics-plot-1-rect-1.1 rect
```
- Target: SVG elements of type "rect"
- ID prefix: "graphics-plot-1-rect-1"
- Suffix: ".1" (gridSVG convention)

**Role:** Creates selectors that target SVG elements in the HTML.

### 4. extract_axis_titles() - Axis Labels

**Purpose:** Extracts x-axis and y-axis titles

**Input:** `layer_info`

**Extraction logic:**
- Reads `args$xlab` for x-axis
- Reads `args$ylab` for y-axis
- Returns as `list(x = "...", y = "...")`

**Special cases:**
- Smooth layers may get labels from HIGH call in same group (since `lines()` has no labels)

**Role:** Provides axis labels for accessibility.

### 5. extract_main_title() - Plot Title

**Purpose:** Extracts main title

**Input:** `layer_info`

**Extraction logic:**
- Reads `args$main` for main title
- Returns title string or empty string

**Role:** Provides plot title for accessibility.

### 6. Utility Methods

**find_rect_grobs()**, **find_polyline_grobs()**, etc.
- Recursively search grob tree
- Find grobs matching specific pattern
- Return grob names

**generate_selectors_from_grob()**
- Takes grob tree and pattern
- Finds matching grobs
- Converts to CSS selectors
- Returns selector list

**Role:** Helper methods to search grob trees and convert to selectors.

---

## Data Extraction

### Bar Plot Extraction

**File:** `R/base_r_barplot_layer_processor.R` - `extract_data()`

**Process:**
1. Get `args` from `layer_info$plot_call$args`
2. Extract `height` (bars data)
   - Try `args$height`
   - Fallback to `args[[1]]` (first argument)
3. Extract labels
   - Try `args$names.arg`
   - Fallback to `names(height)`
   - Default to sequential numbers
4. Convert to data points
   - Create data frame
   - Sort by x values for consistency
   - Return as list of `{x, y}` objects

**Example:**
```r
# User called: barplot(c(3,5,7), names.arg=c("A","B","C"))
# Extracted: [
#   {x: "A", y: 3},
#   {x: "B", y: 5},
#   {x: "C", y: 7}
# ]
```

### Histogram Extraction

**File:** `R/base_r_histogram_layer_processor.R` - `extract_data()`

**Process:**
1. Get `args` from `layer_info$plot_call$args`
2. Extract data (first argument): `args[[1]]`
3. Recreate histogram object
   - Call `hist()` with `plot=FALSE`
   - Pass original parameters (breaks, probability)
4. Extract breaks, counts, mids
5. Convert to MAIDR format
   - For each bin: `{x, y, xMin, xMax, yMin, yMax}`

**Example:**
```r
# User called: hist(data, breaks=10)
# Recreate: hist_obj <- hist(data, breaks=10, plot=FALSE)
# Extracted: [
#   {x: 5.5, y: 10, xMin: 0, xMax: 11, yMin: 0, yMax: 10},
#   ...
# ]
```

**Why recreate?** Need to get exact bin boundaries that match the plotted histogram.

### Smooth/Density Extraction

**File:** `R/base_r_smooth_layer_processor.R` - `extract_data()`

**Process:**
1. Get `args` from `layer_info$plot_call$args`
2. Extract first argument: `args[[1]]`
3. Check if it's a density object: `inherits(arg, "density")`
4. Extract x and y values from density object
5. Convert to MAIDR format (nested list for line)
   - Outer list: one line
   - Inner list: points as `{x, y}`

**Example:**
```r
# User called: lines(density(data))
# Extracted: [[{x: -1.2, y: 0.01}, {x: -1.1, y: 0.02}, ...]]
```

**Key point:** Returns nested list because it's a single line with many points.

### Dodged Bar Extraction

**File:** `R/base_r_dodged_bar_layer_processor.R` - `extract_data()`

**Process:**
1. Get `args` from `layer_info$plot_call$args`
2. Extract height matrix: `args[[1]]`
3. Extract row and column names
   - Columns (categories): from `names.arg` or `colnames(height)`
   - Rows (series): from `rownames(height)`
4. Sort both for consistency
5. Build nested structure
   - Outer: by series (fill value)
   - Inner: by category (x value)
   - Each point: `{x, category, y: height, fill: series}`

**Example:**
```r
# User called: barplot(matrix, beside=TRUE, names.arg=c("A","B"))
# Extracted: [
#   [{x: "A", y: 3, fill: "Series1"}, {x: "B", y: 5, fill: "Series1"}],
#   [{x: "A", y: 4, fill: "Series2"}, {x: "B", y: 6, fill: "Series2"}]
# ]
```

### Stacked Bar Extraction

**File:** `R/base_r_stacked_bar_layer_processor.R` - `extract_data()`

**Process:**
1. Get `args` from `layer_info$plot_call$args`
2. Extract height matrix: `args[[1]]`
3. Get row and column names
   - Columns (categories): from `colnames(height)`
   - Rows (stacked segments): from `rownames(height)`
4. Build nested structure
   - Outer: by row (stacked segment)
   - Inner: by column (category)
   - Each point: `{x: category, y: height, fill: segment}`

**Key difference from dodged:** Structure by stacking order (rows) rather than groups.

---

## Selector Generation

### Pattern-Based Selection

**Basic approach:**
- Look for patterns like `graphics-plot-1-rect-1`
- Use `grepl()` to match patterns
- Return matching grob names

**Method:** `find_rect_grobs()`, `find_polyline_grobs()`, etc.

### Robust Selector Generation

**File:** `R/base_r_selector_utils.R`

**Functions:**
- `find_graphics_plot_grob()`: Searches for grob by element type
- `generate_robust_css_selector()`: Creates selector from grob name
- `generate_robust_selector()`: Main function processors should use

**Process:**
1. Search grob tree recursively
2. Find grob matching pattern: `graphics-plot-<number>-<type>-<number>`
3. Generate selector: `element[id^='pattern']`
4. Return robust selector

**Advantages:**
- Works regardless of panel structure
- Doesn't rely on hardcoded values
- Handles edge cases better

### Recursive Grob Search

**Search algorithm:**
1. Check current grob's name (if matches pattern)
2. Search in `gList` items
3. Search in `gTree$children`
4. Search in `gTree$grobs`
5. Return all matching names

**Pattern used:**
- `graphics-plot-<number>-<element_type>-<number>`
- Example: `graphics-plot-1-rect-1`

### Selector Conversion

**From grob name to CSS selector:**

**Process:**
1. Add `.1` suffix (gridSVG convention)
2. Escape dots for CSS: `.` → `\\.`
3. Create selector: `#escaped_name element`

**Example:**
```
Grob name: "graphics-plot-1-rect-1"
With suffix: "graphics-plot-1-rect-1.1"
Escaped: "graphics-plot-1-rect-1\\.1"
Selector: "#graphics-plot-1-rect-1\\.1 rect"
```

### Group Index Consideration

**File:** `R/base_r_plot_orchestrator.R`

**Key insight:** Use `group_index` not `layer_index` for selector generation.

**Reasoning:**
- Multiple layers from same group share same grob
- Grob names reference group index, not layer index
- Example: `graphics-plot-1-rect-1` where 1 is group index

**In processors:**
```r
group_index <- if (!is.null(layer_info$group_index)) {
  layer_info$group_index
} else {
  layer_info$index  # Fallback
}
```

---

## Utility Methods

### extract_axis_titles()

**Purpose:** Extract x and y axis labels from call arguments

**Process:**
1. Get args from `layer_info$plot_call$args`
2. Try to get `args$xlab` and `args$ylab`
3. Return as list: `{x = "...", y = "..."}`

**Special cases:**
- Smooth layers may get labels from HIGH call in the same group (because `lines()` has no labels parameter)
- Fallback to empty strings if not provided

**Role:** Provides axis labels for screen readers

### extract_main_title()

**Purpose:** Extract main title from call arguments

**Process:**
1. Get args from `layer_info$plot_call$args`
2. Try to get `args$main`
3. Return title string or empty string

**Role:** Provides plot title for screen readers

### needs_reordering()

**Purpose:** Check if data needs reordering before processing

**For Base R:** Always returns `FALSE`

**Why:** Base R plots use call arguments directly; no transformation needed  
**Contrast:** ggplot2 bar charts need reordering for consistent display

**Role:** Indicates to orchestrator whether reordering is needed

### get_layer_index()

**Purpose:** Get the layer's index

**Returns:** `layer_info$index`

**Use:** When layer-specific information is needed

**Role:** Provides layer position in the plot

### set_last_result() / get_last_result()

**Purpose:** Store and retrieve processing results

**Used by:** Orchestrator to access processor results after processing

**Storage:** Private field `.last_result`

**Role:** Enables orchestrator to access results without re-running processors

---

## Complete Processing Flow

### Orchestrator Calls Processor

**Context:** `BaseRPlotOrchestrator$process_layers()`

**When:** For each layer with a processor

**Call:**
```r
processor$process(
  plot = NULL,
  layout = private$.layout,
  built = NULL,
  gt = layer_grob,  # Unified grob for group
  layer_info = private$.layers[[i]]  # Full layer info
)
```

### Processor Executes

**Step 1: Extract data**
- Calls `extract_data(layer_info)`
- Accesses `layer_info$plot_call$args`
- Extracts specific arguments
- Converts to MAIDR format
- Returns data points

**Step 2: Generate selectors**
- Calls `generate_selectors(layer_info, gt)`
- Gets group index from layer_info
- Searches grob tree for elements
- Generates CSS selectors
- Returns selectors list

**Step 3: Extract metadata**
- Calls `extract_axis_titles(layer_info)`
- Calls `extract_main_title(layer_info)`
- Returns axis labels and title

**Step 4: Combine results**
- Creates standard result structure:
  ```r
  {
    data: [...],
    selectors: [...],
    type: "...",
    title: "...",
    axes: {x: "...", y: "..."},
    domOrder: "forward" (optional)
  }
  ```
- Returns to orchestrator

### Orchestrator Uses Results

**Context:** `BaseRPlotOrchestrator$process_layers()`

**After processing:**
1. Store result: `processor$set_last_result(result)`
2. Add to results list
3. Continue with next processor

**Then:** `combine_layer_results()` combines all processor results into MAIDR format

---

## Processor Examples

### Example 1: Simple Bar Plot

**User code:**
```r
barplot(c(3,5,7), names.arg=c("A","B","C"))
maidr::show()
```

**Processing:**

**Layer created:**
```r
{
  index: 1,
  type: "bar",
  function_name: "barplot",
  args: list(height = c(3,5,7), names.arg = c("A","B","C")),
  ...
}
```

**Processor: BaseRBarplotLayerProcessor**

**Data extraction:**
- Extract height: `c(3,5,7)`
- Extract labels: `c("A","B","C")`
- Sort by labels for consistency
- Return: `[{x: "A", y: 3}, {x: "B", y: 5}, {x: "C", y: 7}]`

**Selector generation:**
- Search grob for pattern: `graphics-plot-1-rect-1`
- Find rect grobs
- Generate: `["#graphics-plot-1-rect-1\\.1 rect"]`

**Result:**
```r
{
  data: [{x: "A", y: 3}, {x: "B", y: 5}, {x: "C", y: 7}],
  selectors: ["#graphics-plot-1-rect-1\\.1 rect"],
  type: "bar",
  title: "",
  axes: {x: "", y: ""}
}
```

### Example 2: Histogram + Density

**User code:**
```r
hist(data, probability=TRUE)
lines(density(data))
maidr::show()
```

**Processing:**

**Two layers created:**

**Layer 1 (histogram):**
```r
{
  index: 1,
  type: "hist",
  function_name: "hist",
  args: list(data, probability=TRUE),
  source: "HIGH",
  group_index: 1
}
```

**Layer 2 (density):**
```r
{
  index: 2,
  type: "smooth",
  function_name: "lines",
  args: list(density(data)),
  source: "LOW",
  group_index: 1  # Same group!
}
```

**Grob:** ONE unified grob containing both histogram and density

**Processor 1 (Histogram):**
- Data: Extract from `hist()` args, recreate bins
- Selectors: Find rect grobs in unified grob
- Gets rect elements for histogram bars

**Processor 2 (Smooth/Density):**
- Data: Extract x,y from `density()` object
- Selectors: Find polyline grobs in unified grob
- Gets polyline elements for density curve

**Key:** Both processors search the same grob tree but find different elements.

### Example 3: Dodged Bar Plot

**User code:**
```r
matrix_data <- matrix(c(3,5,7, 4,6,8), nrow=2, byrow=TRUE,
                      dimnames=list(c("Series1","Series2"), c("A","B","C")))
barplot(matrix_data, beside=TRUE)
maidr::show()
```

**Processing:**

**Layer created:**
```r
{
  index: 1,
  type: "dodged_bar",
  function_name: "barplot",
  args: list(
    height = matrix_data,
    beside = TRUE
  ),
  ...
}
```

**Processor: BaseRDodgedBarLayerProcessor**

**Data extraction:**
- Extract matrix: `height` (2 rows, 3 columns)
- Extract row names: `["Series1", "Series2"]`
- Extract col names: `["A", "B", "C"]`
- Sort for consistency
- Build nested structure by series:
  ```r
  [
    [{x: "A", y: 3, fill: "Series1"}, {x: "B", y: 5, fill: "Series1"}, ...],
    [{x: "A", y: 4, fill: "Series2"}, {x: "B", y: 6, fill: "Series2"}, ...]
  ]
  ```

**Selector generation:**
- Search for rect grobs in unified grob
- Generate selectors for all bars
- Return: `["#graphics-plot-1-rect-1\\.1 rect"]`

**Result:**
```r
{
  data: [...],  # Nested by series
  selectors: ["#graphics-plot-1-rect-1\\.1 rect"],
  type: "dodged_bar",
  domOrder: "forward",
  title: "",
  axes: {x: "", y: ""}
}
```

---

## Key Design Patterns

### 1. layer_info as Primary Input

Base R processors receive `layer_info` containing:
- Captured call with arguments
- Metadata (index, type, source)
- Group reference

Not needed in Base R: plot object, built data (ggplot2 concepts).

### 2. Unified Grob Pattern

Processors receive:
- One grob per group
- Shared by all layers in the group
- Search for specific elements (rect, polyline, etc.)

Different from ggplot2: Base R creates grob by replaying calls.

### 3. Argument-Based Extraction

Data extraction:
- Uses function arguments from captured calls
- Different from ggplot2, which uses built plot data
- Recreates objects when needed (e.g., histogram)

### 4. Recursive Grob Search

Selector generation:
- Traverses grob tree recursively
- Looks for pattern matches
- Converts grob names to CSS selectors

Alternative: Use robust utilities for pattern-based search.

### 5. Group-Based Identification

Critical understanding:
- Grob names reference `group_index`, not `layer_index`
- Multiple layers in same group share grob
- Selectors must use group index for correct targeting

---

## Related Files

**Processor Files:**
- `R/base_r_barplot_layer_processor.R` - Bar plot processor
- `R/base_r_dodged_bar_layer_processor.R` - Dodged bar processor
- `R/base_r_stacked_bar_layer_processor.R` - Stacked bar processor
- `R/base_r_histogram_layer_processor.R` - Histogram processor
- `R/base_r_smooth_layer_processor.R` - Smooth/density processor

**Base Classes:**
- `R/layer_processor.R` - Abstract processor interface
- `R/processor_factory.R` - Factory base class

**Utilities:**
- `R/base_r_selector_utils.R` - Robust selector generation

**Orchestration:**
- `R/base_r_plot_orchestrator.R` - Calls processors
- `R/base_r_processor_factory.R` - Creates processors

