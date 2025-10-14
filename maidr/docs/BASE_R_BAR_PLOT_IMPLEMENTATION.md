# Base R Bar Plot Implementation Guide

This document provides a comprehensive explanation of how Base R bar plots (both simple and dodged) are implemented in the MAIDR package, including the patching system, data processing, and DOM ordering.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Plot Type Detection](#plot-type-detection)
4. [Patching System](#patching-system)
5. [Simple Bar Plots](#simple-bar-plots)
6. [Dodged Bar Plots](#dodged-bar-plots)
7. [DOM Ordering and Backend Integration](#dom-ordering-and-backend-integration)
8. [Data Flow](#data-flow)
9. [Examples](#examples)

## Overview

The Base R bar plot implementation in MAIDR handles two main types of bar plots:

- **Simple Bar Plots**: Single series bar charts created with `barplot(vector)`
- **Dodged Bar Plots**: Multi-series bar charts created with `barplot(matrix, beside=TRUE)`

Both types are processed through a unified system that ensures consistent data ordering, proper selector generation, and seamless integration with the MAIDR backend.

## Architecture

The Base R bar plot system consists of several key components:

```
Base R Function Patching → Plot Type Detection → Data Processing → Selector Generation → HTML Output
```

### Key Components:

1. **Function Patching** (`base_r_function_patching.R`)
2. **Plot System Registry** (`plot_system_registry.R`)
3. **Base R Adapter** (`base_r_adapter.R`)
4. **Plot Orchestrator** (`base_r_plot_orchestrator.R`)
5. **Processor Factory** (`base_r_processor_factory.R`)
6. **Layer Processors** (`base_r_barplot_layer_processor.R`, `base_r_dodged_bar_layer_processor.R`)
7. **Patching Architecture** (`base_r_patch_architecture.R`)

## Plot Type Detection

Plot types are detected in the `BaseRAdapter.detect_layer_type()` method based on the `barplot()` call arguments:

### Simple Bar Plots
```r
# Detected when height is a vector
barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
```

**Detection Logic:**
- `height` argument is atomic (vector)
- No `beside` argument or `beside = FALSE`

### Dodged Bar Plots
```r
# Detected when height is a matrix with beside=TRUE
barplot(matrix(c(10,15,20,25,30,35), nrow=2), beside=TRUE)
```

**Detection Logic:**
- `height` argument is a matrix
- `beside = TRUE` (explicit or implied)

### Stacked Bar Plots
```r
# Detected when height is a matrix with beside=FALSE
barplot(matrix(c(10,15,20,25,30,35), nrow=2), beside=FALSE)
```

**Detection Logic:**
- `height` argument is a matrix
- `beside = FALSE` or `beside` is not specified (defaults to FALSE)

## Patching System

The patching system ensures consistent data ordering regardless of how users input their data. It uses a modular architecture with the following components:

### PatchManager
Central coordinator that applies patches to function arguments before execution.

### SortingPatcher
Handles data sorting for both simple and dodged bar plots:

#### Simple Bar Plot Patching
```r
# Input: barplot(c(30, 10, 20), names.arg = c("C", "A", "B"))
# Output: barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
```

**Sorting Logic:**
- Sorts by x-axis values (names of the vector)
- Updates `names.arg` to match sorted order
- Ensures consistent visual ordering (A, B, C)

#### Dodged Bar Plot Patching
```r
# Input matrix with unsorted rows/columns:
#     Cat3 Cat1 Cat2
# A     15   10   20
# C     25   20   30
# B     20   15   25

# Output matrix with sorted rows/columns:
#     Cat1 Cat2 Cat3
# A     10   20   15
# B     15   25   20
# C     20   30   25
```

**Sorting Logic:**
- Sorts fill values (rows) in ascending order (A, B, C)
- Sorts x-axis values (columns) in ascending order (Cat1, Cat2, Cat3)
- Updates `names.arg` to match reordered columns
- Ensures consistent visual ordering

## Simple Bar Plots

### Data Extraction
The `BaseRBarplotLayerProcessor.extract_data()` method:

1. Extracts `height` vector from plot call arguments
2. Extracts labels from `names.arg` or `names(height)`
3. Creates data frame and sorts by x-values
4. Converts to list format for MAIDR

**Example Output:**
```json
{
  "data": [
    {"x": "A", "y": 10},
    {"x": "B", "y": 20},
    {"x": "C", "y": 30}
  ]
}
```

### Selector Generation
Uses recursive grob search to find rect elements:

```r
# Pattern: graphics-plot-{call_index}-rect-1
# Selector: #graphics-plot-1-rect-1\.1 rect
```

## Dodged Bar Plots

### Data Extraction
The `BaseRDodgedBarLayerProcessor.extract_data()` method:

1. Extracts height matrix from plot call arguments
2. Gets row names (fill values) and column names (x values)
3. Sorts fill values in ascending order (A, B, C)
4. Sorts x values in ascending order within each fill group
5. Groups data by fill values
6. Returns data in format expected by backend

**Example Output:**
```json
{
  "data": [
    [
      {"x": "Cat1", "y": 10, "fill": "A"},
      {"x": "Cat2", "y": 20, "fill": "A"},
      {"x": "Cat3", "y": 15, "fill": "A"}
    ],
    [
      {"x": "Cat1", "y": 15, "fill": "B"},
      {"x": "Cat2", "y": 25, "fill": "B"},
      {"x": "Cat3", "y": 20, "fill": "B"}
    ],
    [
      {"x": "Cat1", "y": 20, "fill": "C"},
      {"x": "Cat2", "y": 30, "fill": "C"},
      {"x": "Cat3", "y": 25, "fill": "C"}
    ]
  ],
  "domOrder": "forward"
}
```

### Selector Generation
Uses the same recursive grob search as simple bars:

```r
# Pattern: graphics-plot-{call_index}-rect-1
# Selector: #graphics-plot-1-rect-1\.1 rect
```

### DOM Ordering
The `domOrder: "forward"` field tells the backend that DOM elements are ordered A,B,C,A,B,C,A,B,C (forward order) rather than C,B,A,C,B,A,C,B,A (reverse order like ggplot2).

## DOM Ordering and Backend Integration

### The Challenge
Base R `barplot()` generates DOM elements in forward order (A,B,C,A,B,C,A,B,C), but the MAIDR backend's `SegmentedTrace` class by default expects reverse order (C,B,A,C,B,A,C,B,A) to match ggplot2 behavior.

### The Solution
We added a `domOrder` field to the `MaidrLayer` interface:

```typescript
export interface MaidrLayer {
  // ... other fields
  domOrder?: 'forward' | 'reverse'; // New field for DOM ordering
}
```

The backend's `SegmentedTrace.mapToSvgElements()` method now handles both orderings:

```typescript
if (this.domOrder === 'forward') {
  // Forward order: DOM elements are A,B,C,A,B,C,A,B,C
  for (let r = 0; r < this.barValues.length; r++) {
    // Map data to DOM elements in forward order
  }
} else {
  // Reverse order: DOM elements are C,B,A,C,B,A,C,B,A (default)
  for (let r = this.barValues.length - 1; r >= 0; r--) {
    // Map data to DOM elements in reverse order
  }
}
```

### Data and Visual Ordering
- **Visual Order**: A, B, C (left to right) - controlled by patching system
- **Data Array Order**: [A_data, B_data, C_data] - controlled by extract_data method
- **DOM Order**: A, B, C, A, B, C, A, B, C - natural Base R order
- **Backend Mapping**: Uses `domOrder: "forward"` to correctly map data to DOM elements

## Data Flow

### 1. Function Call Interception
```r
barplot(matrix_data, beside=TRUE)
↓
Function wrapper captures call and arguments
↓
Patching system sorts data (A,B,C order)
↓
Original barplot() executes with sorted data
```

### 2. Plot Processing
```r
Plot call recorded in registry
↓
BaseRAdapter detects layer type (dodged_bar)
↓
BaseRProcessorFactory creates BaseRDodgedBarLayerProcessor
↓
Orchestrator converts plot to grob using ggplotify::as.grob
```

### 3. Data and Selector Extraction
```r
Processor extracts data (grouped by fill, sorted by x)
↓
Processor generates selectors (recursive grob search)
↓
Processor adds domOrder: "forward"
↓
Combined into maidr-data JSON
```

### 4. HTML Generation
```r
SVG exported using gridSVG::grid.export
↓
maidr-data embedded as HTML attribute
↓
HTML file saved
```

## Examples

### Simple Bar Plot Example
```r
# Input data in any order
barplot(c(30, 10, 20), names.arg = c("C", "A", "B"))

# Patching sorts to: barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
# Visual result: A(10), B(20), C(30)
# Data output: [{"x":"A","y":10}, {"x":"B","y":20}, {"x":"C","y":30}]
```

### Dodged Bar Plot Example
```r
# Input matrix with unsorted rows/columns
matrix_data <- matrix(c(
  15, 25, 20,    # Row C
  10, 20, 15,    # Row A  
  20, 30, 25     # Row B
), nrow = 3, byrow = TRUE)
rownames(matrix_data) <- c("C", "A", "B")
colnames(matrix_data) <- c("Cat3", "Cat1", "Cat2")

barplot(matrix_data, beside = TRUE)

# Patching sorts to:
#     Cat1 Cat2 Cat3
# A     10   15   15
# B     20   25   25
# C     25   30   20

# Visual result: A,B,C for each category
# Data output: [A_data, B_data, C_data] with domOrder: "forward"
```

### Robustness Testing
The implementation handles various edge cases:

- **Different fill orders**: C,B,A → A,B,C
- **Different x value orders**: Cat3,Cat1,Cat2 → Cat1,Cat2,Cat3
- **Numeric x values**: 3,1,2 → 1,2,3
- **Mixed data types**: Strings and numbers
- **Single categories**: Single column matrices
- **Scrambled data**: Completely random row/column orders

## Key Benefits

1. **Consistency**: All bar plots produce consistent visual and data ordering
2. **Robustness**: Handles any input data order gracefully
3. **Backend Compatibility**: Seamless integration with existing MAIDR backend
4. **User Experience**: Users can input data in any order and get predictable results
5. **Maintainability**: Clean separation between patching, processing, and rendering

## Implementation Files

- `maidr/R/base_r_function_patching.R` - Function interception and wrapping
- `maidr/R/base_r_patch_architecture.R` - Modular patching system
- `maidr/R/base_r_adapter.R` - Plot type detection
- `maidr/R/base_r_barplot_layer_processor.R` - Simple bar plot processing
- `maidr/R/base_r_dodged_bar_layer_processor.R` - Dodged bar plot processing
- `maidr/R/base_r_plot_orchestrator.R` - Plot coordination
- `maidr/R/base_r_processor_factory.R` - Processor creation

This implementation provides a robust, consistent, and user-friendly system for Base R bar plots that integrates seamlessly with the MAIDR ecosystem.
