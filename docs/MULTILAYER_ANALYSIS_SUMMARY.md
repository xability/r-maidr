# Base R Multi-Layer Implementation - Analysis Summary

## 🔍 Key Findings from ggplot2 Architecture

### 1. **Unified Grob Tree Pattern** ⭐ CRITICAL

**Discovery:** ggplot2 creates ONE grob tree upfront and passes it to ALL processors.

```r
# From ggplot2_plot_orchestrator.R:126-155
process_layers = function() {
  # Create grob tree ONCE
  built_final <- ggplot2::ggplot_build(plot_for_render)
  gt_final <- ggplot2::ggplotGrob(plot_for_render)  # ← Single grob
  private$.gtable <- gt_final
  
  # Pass SAME grob to ALL processors
  for (i in seq_along(private$.layer_processors)) {
    processor <- private$.layer_processors[[i]]
    result <- processor$process(plot, layout, 
                               built = built_final, 
                               gt = private$.gtable)  # ← Same grob
  }
}
```

**Why This Matters:**
- Each processor searches the unified grob for its specific elements
- Histogram processor finds `rect` grobs
- Density processor finds `polyline` grobs
- Both work from the same tree structure

### 2. **Recursive Grob Search Pattern**

**Discovery:** Processors recursively traverse the grob tree to find elements.

```r
# From ggplot2_smooth_layer_processor.R:49-62
collect_all_polyline_grobs <- function(grob) {
  polyline_grobs <- list()
  
  # Check current grob
  if (!is.null(grob$name) && grepl("GRID\\.polyline", grob$name)) {
    polyline_grobs <- append(polyline_grobs, grob$name)
  }
  
  # Recursively search children
  if ("children" %in% names(grob)) {
    for (child in grob$children) {
      child_grobs <- collect_all_polyline_grobs(child)
      polyline_grobs <- append(polyline_grobs, child_grobs)
    }
  }
  
  return(polyline_grobs)
}
```

**Pattern to Follow:**
1. Check if current grob matches pattern
2. Recursively search children (gTree)
3. Recursively search items (gList)
4. Return all matches

### 3. **Layer Type Detection**

**Discovery:** Adapter examines geom/stat classes to determine layer type.

```r
# From ggplot2_adapter.R:40-43
detect_layer_type = function(layer, plot_object) {
  geom_class <- class(layer$geom)[1]
  stat_class <- class(layer$stat)[1]
  
  if (geom_class == "GeomSmooth" || stat_class == "StatDensity") {
    return("smooth")  # Density curve
  }
}
```

**Base R Equivalent:**
- Examine function name (`lines`, `points`, etc.)
- Examine first argument type (`inherits(arg, "density")`)
- Return appropriate type string

---

## 📊 MAIDR Data Structure Analysis

### ggplot2 Histogram + Density Example

From `example_histogram_density_ggplot2.html`:

```json
{
  "id": "maidr-plot-1761069159",
  "subplots": [[{
    "id": "maidr-subplot-1761069159",
    "layers": [
      {
        "id": 1,
        "type": "hist",
        "selectors": ["#geom_rect\\.rect\\.448\\.1 rect"],
        "data": [
          {"x": -0.5, "y": 0.0133, "xMin": -0.75, "xMax": -0.25, ...},
          {"x": 0, "y": 0.0133, "xMin": -0.25, "xMax": 0.25, ...},
          ...
        ]
      },
      {
        "id": 2,
        "type": "smooth",
        "selectors": ["#GRID\\.polyline\\.450\\.1\\.1"],
        "data": [[
          {"x": -0.3565, "y": 0.0135},
          {"x": -0.3407, "y": 0.0139},
          ... (512 points total)
        ]]
      }
    ]
  }]]
}
```

**Key Observations:**
1. ✅ TWO separate layers in `layers` array
2. ✅ Each layer has distinct `type` ("hist" vs "smooth")
3. ✅ Each layer has different `selectors`
4. ✅ Histogram data: array of bins with xMin/xMax
5. ✅ Density data: nested array (one line with many points)

---

## 🎯 Base R Implementation Strategy

### Current vs. Target Architecture

**CURRENT:**
```
Plot Groups: [
  {
    high_call: hist(...),
    low_calls: [lines(density(...))]
  }
]
↓
Layers: [
  { type: "hist", source: "HIGH" }  // Only HIGH call
]
↓
ONE grob from HIGH + ALL LOW
```

**TARGET:**
```
Plot Groups: [
  {
    high_call: hist(...),
    low_calls: [lines(density(...))]
  }
]
↓
Layers: [
  { type: "hist", source: "HIGH" },
  { type: "smooth", source: "LOW" }  // Expanded!
]
↓
ONE unified grob (same for all layers)
↓
Each processor searches grob for its elements
```

### Implementation Phases

```
Phase 1: Adapter Enhancement
  └─> Add LOW-level function detection
  └─> lines(density()) → "smooth"
  └─> lines(x, y) → "line"
  └─> points(x, y) → "point"

Phase 2: Layer Expansion
  └─> Modify detect_layers()
  └─> Create layer for HIGH call
  └─> Create layers for each LOW call
  └─> Store source marker and group reference

Phase 3: Unified Grob Creation
  └─> Modify get_gtable()
  └─> Create ONE grob per group (HIGH + ALL LOW)
  └─> Store grob indexed by group_index
  └─> get_grob_for_layer() returns grob by group

Phase 4: Processor Updates
  └─> Histogram: Search unified grob for rects
  └─> Smooth: Handle density objects, find polylines
  └─> Both use recursive search pattern

Phase 5: Integration & Testing
  └─> End-to-end test
  └─> MAIDR data validation
  └─> HTML generation and verification
```

---

## 🔬 Base R Plotting Pattern

### Standard Histogram + Density Code

```r
# Create sample data
set.seed(123)
data <- rnorm(150, mean = 3.8, sd = 1.8)

# HIGH-level call: Create histogram
hist(data, probability = TRUE,     # ← Must use probability = TRUE
     col = "lightblue", 
     border = "black",
     main = "Histogram with Density",
     xlab = "Value", 
     ylab = "Density")

# LOW-level call: Add density curve
lines(density(data),                # ← density() creates density object
      col = "red", 
      lwd = 2)
```

**What happens:**
1. `hist()` renders bars scaled to probability density
2. `lines(density())` overlays smooth curve
3. Both captured by patching system
4. Grouped together (HIGH + LOW)
5. Need to split into 2 layers for MAIDR

---

## ✅ Requirements Confirmed

### Functional Requirements
- [x] Detect LOW-level function types
- [x] Expand plot groups into multiple layers
- [x] Create unified grob containing all elements
- [x] Each processor searches unified grob
- [x] Generate correct selectors for each layer
- [x] Produce MAIDR structure with multiple layers

### Non-Functional Requirements
- [x] Follow ggplot2 architecture patterns
- [x] Maintain backward compatibility
- [x] Each phase independently testable
- [x] Clear rollback strategy
- [x] Comprehensive test coverage

### Data Structure Requirements
- [x] Multiple layers in `layers` array
- [x] Each layer has unique type
- [x] Each layer has unique selectors
- [x] Histogram data includes xMin/xMax
- [x] Density data as nested array

---

## 🚦 Ready to Implement

### Prerequisites Met
✅ Architecture pattern understood (unified grob tree)  
✅ ggplot2 implementation studied (recursive search)  
✅ Base R plotting pattern researched (hist + lines)  
✅ MAIDR data structure defined (2 layers)  
✅ Test strategy established (5 phases)  
✅ Rollback plan created (per-phase isolation)  

### Implementation Order
1. **Phase 1** (Low Risk): Adapter enhancement - pure detection logic
2. **Phase 2** (Low Risk): Layer expansion - orchestrator modification
3. **Phase 3** (Medium Risk): Unified grob - critical architectural change
4. **Phase 4** (Medium Risk): Processor updates - selector generation
5. **Phase 5** (Low Risk): Integration - validation and testing

### Success Metrics
- All phase tests pass
- MAIDR data has 2 layers
- HTML renders correctly
- Interactive features work
- No regressions on single-layer plots

---

## 📚 Reference Documentation

- **Implementation Plan**: `docs/BASE_R_MULTILAYER_IMPLEMENTATION.md`
- **Architecture Overview**: `docs/BASE_R_PATCHING_SYSTEM.md`
- **ggplot2 Reference**: `docs/GGPLOT2_SYSTEM_IMPLEMENTATION.md`
- **System Detection**: `docs/PLOTTING_SYSTEM_DETECTION.md`

---

## 🎯 Next Action

**Start Phase 1:** Enhance `BaseRAdapter$detect_layer_type()` to handle LOW-level functions.

```bash
# Begin implementation
devtools::load_all()
# Edit R/base_r_adapter.R
# Run: testthat::test_file("tests/test_base_r_adapter_multilayer.R")
```

