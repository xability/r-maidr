# Base R Boxplot Implementation

This document provides a comprehensive guide to how boxplot support has been implemented for Base R plots in the MAIDR R package. It covers the entire flow from detection through data extraction to selector generation, with enough detail for another developer (or AI agent) to understand the implementation and continue working on it.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Flow](#architecture-flow)
3. [Detection Phase](#detection-phase)
4. [Orchestration Phase](#orchestration-phase)
5. [Processor Implementation](#processor-implementation)
6. [Data Extraction](#data-extraction)
7. [Selector Generation](#selector-generation)
8. [Orientation Handling](#orientation-handling)
9. [Differences from ggplot2](#differences-from-ggplot2)
10. [Testing and Examples](#testing-and-examples)
11. [Known Limitations](#known-limitations)
12. [Future Improvements](#future-improvements)

---

## Overview

Base R boxplot support enables MAIDR to process plots created using the `boxplot()` function from base R graphics. Unlike ggplot2, which has structured layer data, Base R plots are created by function calls that render immediately. MAIDR intercepts these calls, captures their arguments, and later recreates the statistical summaries to extract data for interactive visualization.

**Key Files:**
- `R/base_r_adapter.R` - Detects `boxplot()` calls as type "box"
- `R/base_r_processor_factory.R` - Maps "box" → `BaseRBoxplotLayerProcessor`
- `R/base_r_boxplot_layer_processor.R` - Main processor implementation
- `R/base_r_plot_orchestrator.R` - Creates layer_info and calls processor

**Example Scripts:**
- `examples/base_r_boxplot_example.R` - Horizontal boxplot example
- `examples/base_r_boxplot_vertical_example.R` - Vertical boxplot example

---

## Architecture Flow

The complete flow from user code to HTML output:

```
1. User calls boxplot(...)
   ↓
2. Function patching intercepts the call
   ↓
3. Base R adapter detects layer_type = "box"
   ↓
4. Orchestrator groups calls and creates layer_info
   ↓
5. Factory creates BaseRBoxplotLayerProcessor
   ↓
6. Processor extracts data via boxplot.stats()
   ↓
7. Processor generates selectors from grob tree
   ↓
8. Results combined into maidr-data JSON
   ↓
9. HTML output with interactive boxplot
```

---

## Detection Phase

### Step 1: Function Patching

When `maidr::show()` is called, Base R plotting functions (including `boxplot`) are patched to log their calls instead of rendering immediately.

**Location:** `R/base_r_patch_architecture.R`

The patched `boxplot()` function:
- Captures function name, arguments, and call expression
- Stores this in device-specific storage via `record_device_call()`
- Does NOT render the plot (plotting deferred)

### Step 2: Adapter Detection

When the orchestrator is created, it calls the adapter's `detect_layer_type()` method.

**File:** `R/base_r_adapter.R` (lines 62)

```r
detect_layer_type = function(layer, plot_object = NULL) {
  # ...
  layer_type <- switch(function_name,
    # ...
    "boxplot" = "box",  # ← Returns "box" for boxplot() calls
    # ...
  )
}
```

**Key points:**
- HIGH-level `boxplot()` calls are detected as `type = "box"`
- LOW-level calls (lines, points, segments) from boxplot internals are typically detected as their own types, but boxplot groups them together

---

## Orchestration Phase

### Step 1: Grouping Plot Calls

The orchestrator groups plot calls into HIGH/LOW pairs:
- **HIGH call**: The `boxplot()` call itself
- **LOW calls**: Any subsequent modifications (typically none for simple boxplots)

**File:** `R/base_r_plot_orchestrator.R` - `detect_layers()` (lines 43-98)

For a boxplot, typically:
- One group with HIGH call = `boxplot(...)`
- No LOW calls (boxplot renders everything in one call)

### Step 2: Creating layer_info

Each detected layer gets a `layer_info` structure:

```r
layer_info = list(
  index = 1,                    # Sequential layer number
  type = "box",                 # From adapter detection
  function_name = "boxplot",    # Original function
  args = list(...),            # Captured arguments (data, horizontal, etc.)
  call_expr = "...",           # Call expression string
  plot_call = {...},           # Full call object
  group = {...},               # Reference to plot group
  group_index = 1,             # Which group this belongs to
  source = "HIGH"              # HIGH or LOW
)
```

**Critical:** `layer_info$args` contains the actual arguments passed to `boxplot()`, including:
- `x` or formula: The data
- `horizontal`: TRUE/FALSE for orientation
- `main`, `xlab`, `ylab`: Titles and labels
- Other styling arguments

### Step 3: Creating Processor

The orchestrator calls the factory to create a processor:

**File:** `R/base_r_processor_factory.R` (line 35)

```r
"box" = BaseRBoxplotLayerProcessor$new(layer_info)
```

The processor stores `layer_info` internally for later use.

### Step 4: Processing Layer

The orchestrator calls `processor$process()` with:
- `plot`: NULL (Base R has no plot object)
- `layout`: Extracted layout info
- `built`: NULL (not used for Base R)
- `gt`: Unified grob tree from the group
- `layer_info`: Complete layer information

**File:** `R/base_r_plot_orchestrator.R` - `process_layers()` (line 165)

---

## Processor Implementation

### Class Structure

**File:** `R/base_r_boxplot_layer_processor.R`

```r
BaseRBoxplotLayerProcessor <- R6::R6Class("BaseRBoxplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(...),           # Main orchestration
    extract_data = function(...),      # Get stats from boxplot.stats()
    generate_selectors = function(...), # Find SVG elements in grob tree
    extract_axis_titles = function(...), # Get xlab/ylab
    extract_main_title = function(...),  # Get main title
    determine_orientation = function(...) # horz or vert
  )
)
```

---

## Data Extraction

### Method: `extract_data()`

**Location:** `R/base_r_boxplot_layer_processor.R` (lines 27-85)

### Process

1. **Get original arguments:**
   ```r
   plot_call <- layer_info$plot_call
   args <- plot_call$args
   ```

2. **Recreate boxplot call with `plot=FALSE`:**
   ```r
   args_no_plot <- args
   args_no_plot$plot <- FALSE
   stats_obj <- do.call(boxplot, args_no_plot)
   ```
   This gives us the statistical summaries without rendering.

3. **Extract statistics matrix:**
   ```r
   stats_mat <- stats_obj$stats  # 5 rows × N columns
   # Row 1: min (whisker end)
   # Row 2: Q1 (lower quartile)
   # Row 3: median (Q2)
   # Row 4: Q3 (upper quartile)
   # Row 5: max (whisker end)
   # Each column = one group/category
   ```

4. **Extract group names:**
   ```r
   group_names <- stats_obj$names  # e.g., c("setosa", "versicolor", "virginica")
   ```

5. **Process outliers:**
   ```r
   out_vals <- stats_obj$out      # All outlier values
   out_groups <- stats_obj$group  # Which group each outlier belongs to
   ```
   For each group, outliers are split into:
   - `lowerOutliers`: Values below the min whisker
   - `upperOutliers`: Values above the max whisker

6. **Build data structure per group:**
   ```r
   for (i in seq_len(ncol(stats_mat))) {
     results[[i]] <- list(
       min = stats_mat[1, i],
       q1 = stats_mat[2, i],
       q2 = stats_mat[3, i],  # median
       q3 = stats_mat[4, i],
       max = stats_mat[5, i],
       fill = group_names[[i]],
       lowerOutliers = [...],
       upperOutliers = [...]
     )
   }
   ```

7. **Handle horizontal orientation:**
   ```r
   if (!is.null(args$horizontal) && isTRUE(args$horizontal)) {
     results <- rev(results)  # Reverse data order
   }
   ```
   **Why:** The TypeScript layer reverses arrays for horizontal plots to start navigation from lower-left. We reverse here so that after TS reversal, the visual order is preserved (top→bottom in HTML corresponds to top→bottom in data).

### Output Format

The `extract_data()` method returns a list of box summaries, one per category:

```r
list(
  list(min=1.1, q1=1.4, q2=1.5, q3=1.6, max=1.9, 
       fill="setosa", lowerOutliers=list(1), upperOutliers=list()),
  list(min=3.3, q1=4.0, q2=4.35, q3=4.6, max=5.1,
       fill="versicolor", lowerOutliers=list(3), upperOutliers=list()),
  # ... more groups
)
```

---

## Selector Generation

### Method: `generate_selectors()`

**Location:** `R/base_r_boxplot_layer_processor.R` (lines 87-160)

### Challenge

Unlike ggplot2, where boxplot elements are grouped per category in the grob tree, Base R's gridSVG export creates individual grobs scattered across the tree:
- Each box's IQ rectangle: `graphics-plot-1-polygon-1`, `graphics-plot-1-polygon-2`, ...
- Median lines: `graphics-plot-1-segments-1`, ...
- Whiskers: Other segments groups
- Outliers: `graphics-plot-1-points-1`, ...

We need to map these scattered grobs back to the correct category.

### Process

1. **Collect all grob names from the grob tree:**
   ```r
   collect_names <- function(g) {
     # Recursively traverse gTree, gList, etc.
     # Return all grob names
   }
   all_names <- collect_names(gt)
   ```

2. **Filter for polygon grobs:**
   ```r
   poly_ids <- grep('^graphics-plot-[0-9]+-polygon-[0-9]+$', 
                    all_names, value = TRUE)
   ```
   These are the IQ box rectangles.

3. **Sort by trailing number:**
   ```r
   sort_ids <- function(ids) {
     # Extract trailing integer and sort
     ord <- order(as.integer(sub('.*-([0-9]+)$', '\\1', ids)))
     ids[ord]
   }
   poly_ids <- sort_ids(poly_ids)
   ```

4. **Heuristic mapping per box:**
   ```r
   # Base R often creates 2 polygons per box (filled + outline)
   # We take every other polygon (the filled ones)
   if (length(poly_ids) >= data_len * 2) {
     per_box_ids <- poly_ids[seq(1, by = 2, length.out = data_len)]
   } else if (length(poly_ids) >= data_len) {
     per_box_ids <- poly_ids[seq_len(data_len)]
   } else {
     # Fallback: reuse last polygon
     per_box_ids <- rep(poly_ids[length(poly_ids)], data_len)
   }
   ```

5. **Build CSS selectors:**
   ```r
   make_poly_sel <- function(id) {
     paste0("polygon[id^='", id, ".1']")
   }
   ```
   The `.1` suffix is added by gridSVG when exporting.

6. **Create selector structure per group:**
   ```r
   for (i in seq_len(data_len)) {
     iq_sel <- make_poly_sel(per_box_ids[[i]])
     selectors[[i]] <- list(
       lowerOutliers = list(),      # TODO: implement outlier selectors
       min = iq_sel,                # Simplified: use polygon for all parts
       iq = iq_sel,
       q2 = iq_sel,
       max = iq_sel,
       upperOutliers = list()       # TODO: implement outlier selectors
     )
   }
   ```

7. **Handle horizontal orientation:**
   ```r
   if (!is.null(args$horizontal) && isTRUE(args$horizontal)) {
     selectors <- rev(selectors)  # Mirror data reversal
   }
   ```

### Current Simplification

Currently, all parts (min, iq, q2, max) use the same polygon selector. This means highlights will show the entire IQ box for any section. This is a simplification; a future improvement would map:
- `iq`: IQ box polygon
- `q2`: Median line segment (from segments grobs)
- `min`/`max`: Whisker segments (from segments grobs)
- `lowerOutliers`/`upperOutliers`: Point grobs filtered by position

### Output Format

```r
list(
  list(lowerOutliers=list(), min="polygon[id^='graphics-plot-1-polygon-1.1']",
       iq="...", q2="...", max="...", upperOutliers=list()),
  list(lowerOutliers=list(), min="polygon[id^='graphics-plot-1-polygon-3.1']",
       iq="...", q2="...", max="...", upperOutliers=list()),
  # ... one per group
)
```

---

## Orientation Handling

### Detection

**File:** `R/base_r_boxplot_layer_processor.R` (lines 177-182)

```r
determine_orientation = function(layer_info) {
  args <- layer_info$plot_call$args
  horizontal <- if (!is.null(args$horizontal)) isTRUE(args$horizontal) else FALSE
  if (horizontal) "horz" else "vert"
}
```

### Data Ordering

For **horizontal** boxplots:
- Data array is reversed (top→bottom visual order → reversed data)
- Selectors array is also reversed
- **Reason:** TypeScript layer reverses arrays for horizontal to start navigation from lower-left. By reversing in R, after TS reversal, the effective order matches visual appearance.

For **vertical** boxplots:
- Data and selectors remain in original order (left→right)

### Axes Extraction

**File:** `R/base_r_boxplot_layer_processor.R` (lines 162-169)

```r
extract_axis_titles = function(layer_info) {
  args <- layer_info$plot_call$args
  list(
    x = if (!is.null(args$xlab)) args$xlab else "",
    y = if (!is.null(args$ylab)) args$ylab else ""
  )
}
```

Note: For horizontal boxplots, the xlab/ylab are swapped visually, but we keep them as provided in the original call. The TypeScript layer handles the display orientation.

---

## Differences from ggplot2

### 1. Data Source

| Aspect | ggplot2 | Base R |
|--------|---------|--------|
| **Data source** | `ggplot_build(plot)$data[[layer_index]]` | Re-run `boxplot(..., plot=FALSE)` |
| **Pre-computed stats** | Already in layer data | Computed on-the-fly via `boxplot.stats()` |
| **Outlier format** | String like `"c(1, 2, 3)"` | Numeric vectors from `stats_obj$out` |

### 2. Selector Generation

| Aspect | ggplot2 | Base R |
|--------|---------|--------|
| **Grob structure** | Grouped per category | Scattered across tree |
| **Grob names** | Semantic names like `"boxplot-1-1"` | Generic `"graphics-plot-1-polygon-N"` |
| **Grouping** | Already grouped in gtable | Must manually map to categories |
| **Selector precision** | Can target specific parts | Currently simplified to polygon-only |

### 3. Orientation

Both systems handle horizontal/vertical similarly:
- Check `horizontal` parameter
- Reverse arrays for horizontal (R side)
- TypeScript handles display logic

---

## Testing and Examples

### Example 1: Horizontal Boxplot

**File:** `examples/base_r_boxplot_example.R`

```r
boxplot(
  Petal.Length ~ Species,
  data = iris_data,
  horizontal = TRUE,
  main = "Petal Length by Species",
  xlab = "Petal Length",
  ylab = "Species"
)
```

**Output:** `output/example_boxplot_base_r.html`

**Verification:**
- Check `maidr-data` attribute on SVG element
- Verify `type: "box"`, `orientation: "horz"`
- Verify data array has 3 groups (setosa, versicolor, virginica)
- Verify selectors array matches data length

### Example 2: Vertical Boxplot

**File:** `examples/base_r_boxplot_vertical_example.R`

```r
boxplot(
  Petal.Length ~ Species,
  data = iris_data,
  horizontal = FALSE,  # or omit (default is FALSE)
  main = "Petal Length by Species",
  xlab = "Species",
  ylab = "Petal Length"
)
```

**Output:** `output/example_boxplot_vertical_base_r.html`

**Key difference:** `orientation: "vert"`, data/selectors NOT reversed

### Running Examples

```bash
# Horizontal
Rscript examples/base_r_boxplot_example.R

# Vertical
Rscript examples/base_r_boxplot_vertical_example.R
```

### Inspecting Output

Open the HTML file and check:
1. **Browser console:** Should show no errors
2. **Navigation:** Arrow keys should navigate between boxes
3. **Data integrity:** Values should match R's `boxplot.stats()` output
4. **Visual:** Boxplot should render correctly

---

## Known Limitations

### 1. Simplified Selectors

**Current:** All parts (min, iq, q2, max) use the same polygon selector.

**Impact:** Highlights show the entire IQ box regardless of which part is selected.

**Future:** Map individual grobs:
- `iq`: IQ box polygon (already working)
- `q2`: Median line from segments grobs
- `min`/`max`: Whisker segments from segments grobs
- Outliers: Point grobs filtered by position

### 2. Outlier Selectors Not Implemented

**Current:** `lowerOutliers` and `upperOutliers` are empty arrays in selectors.

**Impact:** Outliers cannot be highlighted separately (though they're in the data).

**Future:** Find point grobs, filter by x/y position relative to whiskers, assign to correct group.

### 3. Heuristic Polygon Mapping

**Current:** Assumes polygons come in pairs (filled + outline) and takes every other one.

**Limitation:** May fail if:
- Base R rendering changes
- Multiple boxplots in one plot
- Custom styling affects polygon creation

**Future:** Use coordinate-based clustering to assign polygons to categories more robustly.

### 4. No Support for Formula Variations

**Current:** Supports standard `boxplot(x ~ group, ...)` and `boxplot(list(...), ...)`.

**Limitation:** May not handle all formula variations or edge cases.

---

## Future Improvements

### 1. Robust Selector Mapping

Instead of heuristic polygon matching, use coordinate-based clustering:
- Compute y-center for each polygon
- Cluster by y-position to assign to categories
- Map median/whisker segments to categories via coordinate proximity
- Map outlier points similarly

### 2. Complete Selector Coverage

Implement selectors for all boxplot parts:
- Median line (`q2`)
- Whiskers (`min`, `max`)
- Outliers (both lower and upper)

### 3. Coordinate-Based Band Assignment

For complex cases, use a k-means-like approach:
- Extract y-coordinates from axis labels to determine number of bands
- Cluster polygons/segments/points by vertical position
- Assign to nearest band

### 4. Edge Case Handling

- Multiple boxplots in one plot
- Boxplots with varying numbers of groups
- Custom styling that changes grob structure

### 5. Testing

Add unit tests for:
- Data extraction accuracy (compare to `boxplot.stats()`)
- Selector validity (check CSS selectors match SVG elements)
- Orientation handling (horizontal vs vertical)
- Edge cases (single group, no outliers, etc.)

---

## Key Implementation Notes

### Why Reverse Data for Horizontal?

The TypeScript layer (`maidrjs/src/model/box.ts`) reverses arrays for horizontal plots to enable lower-left navigation start. By reversing in R:
1. Data appears in visual top→bottom order
2. TS reverses it to bottom→top
3. Navigation starts at lower-left (first box in reversed array)
4. Visual and data order remain consistent

### Why Re-run `boxplot()`?

Base R plots don't store computed statistics. We must re-run `boxplot()` with `plot=FALSE` to get the stats that were computed during the original call. This is safe because:
- We use the exact same arguments
- `plot=FALSE` prevents re-rendering
- The stats are deterministic

### Grob Tree Structure

The grob tree (`gt`) passed to `generate_selectors()` contains all elements from the plot group, converted from Base R graphics to grid grobs via `ggplotify::as.grob()`. gridSVG then exports these with stable IDs like `graphics-plot-1-polygon-N.1`.

### CSS Selector Format

Selectors use attribute selectors to avoid escaping dots:
- `polygon[id^='graphics-plot-1-polygon-1.1']` matches any polygon whose id starts with that prefix
- More robust than `#graphics-plot-1-polygon-1\.1` (requires escaping)

---

## Summary

The Base R boxplot implementation:
1. ✅ Detects `boxplot()` calls via adapter
2. ✅ Extracts statistics via `boxplot.stats()`
3. ✅ Generates polygon-based selectors from grob tree
4. ✅ Handles horizontal/vertical orientation
5. ✅ Produces valid maidr-data JSON for TypeScript layer
6. ⚠️ Simplified selectors (polygon-only for all parts)
7. ⚠️ Outlier selectors not yet implemented
8. ⚠️ Heuristic polygon mapping (may need improvement)

The implementation is functional for navigation and basic interaction, with opportunities for improvement in selector precision and edge case handling.



