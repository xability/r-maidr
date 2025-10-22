# MAIDR Documentation

This directory contains comprehensive documentation for the MAIDR package architecture and implementation.

## Documentation Files

### 1. BASE_R_PATCHING_SYSTEM.md
**Purpose:** Comprehensive guide to the Base R patching system

**Covers:**
- Complete architecture overview with diagrams
- Core components (function classification, patching, device storage, state tracking, plot grouping)
- Detailed data flow from user code to HTML output
- Device-scoped storage and isolation
- Multi-layer and multi-panel support
- Orchestrator integration
- Debugging guide with practical examples
- Troubleshooting common issues
- Advanced topics (adding new functions, custom grouping, performance)
- Step-by-step examples and code snippets

**Target Audience:** Developers who want to understand or extend the Base R plotting system in MAIDR.

**Key Features Documented:**
- ✅ Device-isolated plotting (no interference between devices)
- ✅ Multi-layer support (HIGH + LOW functions grouped correctly)
- ✅ Multi-panel detection (par(mfrow), layout())
- ✅ No call accumulation across sequential plots
- ✅ Function classification system (HIGH/LOW/LAYOUT)
- ✅ State tracking per device
- ✅ Plot grouping algorithm

### 2. GGPLOT2_SYSTEM_IMPLEMENTATION.md
**Purpose:** Comprehensive guide to the ggplot2 system implementation

**Covers:**
- Complete processing flow from ggplot2 object to interactive SVG
- Layer processors architecture and implementation
- Data extraction and selector generation
- Handling different plot types (single, faceted, patchwork)
- Data structure formats and examples
- How to add new plot types and layer processors
- Advanced features, error handling, and testing
- Performance optimization techniques

**Target Audience:** Developers who want to understand how ggplot2 plots are processed, or who want to add new plot types or extend existing functionality.

### 3. PLOTTING_SYSTEM_DETECTION.md
**Purpose:** Guide to the plotting system detection architecture

**Covers:**
- Registry Pattern implementation
- Adapter Pattern for different plotting systems
- System detection flow and logic
- How to add new plotting systems (lattice, plotly, etc.)
- Advanced detection patterns and error handling
- Performance considerations and testing strategies
- Complete examples for extending the system

**Target Audience:** Developers who want to understand how MAIDR detects and handles different plotting systems, or who want to add support for new plotting libraries.

## Quick Start Guide

### For Understanding Base R Plotting
**Start with:** `BASE_R_PATCHING_SYSTEM.md`

This is the complete, up-to-date guide for Base R plotting in MAIDR. It covers:
1. How function patching works
2. Device-scoped storage architecture
3. Multi-layer and multi-panel support
4. Complete debugging guide

### For Understanding ggplot2 Plotting
**Start with:** `GGPLOT2_SYSTEM_IMPLEMENTATION.md`

This covers the ggplot2 processing pipeline from plot objects to interactive SVG.

### For Adding New Plotting Systems
**Start with:** `PLOTTING_SYSTEM_DETECTION.md` → then the specific system guide

Understand the Registry/Adapter pattern first, then dive into system-specific implementation.

## Architecture Overview

```
User Plot Code
     ↓
System Detection (Registry)
     ↓
System Adapter (ggplot2 / Base R)
     ↓
Plot Orchestrator
     ↓
Layer Processors
     ↓
Enhanced Interactive SVG + MAIDR Data
```

## Base R Plotting Architecture (Current System)

```
User Code (barplot/hist/etc)
     ↓
Function Patching (33 functions: HIGH/LOW/LAYOUT)
     ↓
Device-Scoped Storage (isolated per device)
     ↓
State Tracking (plot index, panel config)
     ↓
Plot Grouping (HIGH + associated LOW calls)
     ↓
Orchestrator (processes groups, creates grobs)
     ↓
Layer Processors (extract data, generate selectors)
     ↓
HTML Output
```

## Key Differences: Base R vs ggplot2

| Aspect | ggplot2 | Base R |
|--------|---------|--------|
| Object Model | Plot object built before rendering | Immediate rendering |
| Layer Handling | Explicit layers in object | Implicit (HIGH + LOW functions) |
| Detection | `inherits(plot, "ggplot")` | Function patching + call capture |
| Multi-panel | `facet_wrap()` or patchwork | `par(mfrow)` or `layout()` |
| Data Access | Direct from plot object | Extracted from captured calls |

## Recent Updates (Phases 1-4 Complete)

✅ **Phase 1:** Device-scoped storage - No call accumulation, device isolation  
✅ **Phase 2:** Function classification - HIGH/LOW/LAYOUT distinction  
✅ **Phase 3:** State tracking & grouping - Multi-layer and multi-panel support  
✅ **Phase 4:** Orchestrator integration - Processes grouped plot data  

**Result:** Base R plotting now supports:
- Multi-layer plots (e.g., `barplot()` + `lines()` + `points()`)
- Multi-panel plots (e.g., `par(mfrow = c(2, 2))`)
- Device isolation (multiple devices don't interfere)
- No accumulation (sequential plots work correctly)

## For Developers

### Adding New Base R Plot Types
1. Classify the function in `R/base_r_function_classification.R`
2. Function patching is automatic (based on classification)
3. Create layer processor in `R/base_r_*_layer_processor.R`
4. Update factory in `R/base_r_processor_factory.R`
5. Test with multi-layer and multi-panel scenarios

See `BASE_R_PATCHING_SYSTEM.md` → "Advanced Topics" for detailed steps.

### Adding New ggplot2 Geoms
1. Create layer processor inheriting from `LayerProcessor`
2. Implement `extract_data()` and `generate_selectors()`
3. Update `Ggplot2ProcessorFactory`
4. Update `Ggplot2Adapter$detect_layer_type()`

See `GGPLOT2_SYSTEM_IMPLEMENTATION.md` → "Adding New Plot Types" for examples.

### Debugging Tools

#### Base R Debugging
```r
# Check device storage
has_device_calls(dev.cur())
get_device_calls(dev.cur())

# Check state
get_device_state(dev.cur())

# Check groups
get_all_plot_groups(dev.cur())

# Check patching
is_patching_active()
```

See `BASE_R_PATCHING_SYSTEM.md` → "Debugging Guide" for comprehensive debugging strategies.

## Testing

### Run Base R Examples
```r
devtools::load_all()
source("examples/base_r_plot_types_example.R")
```

### Run ggplot2 Examples
```r
devtools::load_all()
source("examples/ggplot2_all_plot_types_example.R")
```

## Contributing

When adding new functionality:
1. Follow the patterns established in existing code
2. Update relevant documentation
3. Add appropriate tests (use `devtools`, follow R package conventions)
4. Test multi-layer and multi-panel scenarios (for Base R)
5. Ensure backward compatibility

## Documentation Principles

✅ **Current:** All documentation reflects the implemented system (Phases 1-4)  
✅ **Comprehensive:** Each file is self-contained with complete examples  
✅ **Practical:** Debugging guides with real code examples  
✅ **Extensible:** Clear instructions for adding new functionality  

For questions or issues, refer to the debugging sections in each document or check the troubleshooting guides.
