# MAIDR Documentation

This directory contains comprehensive documentation for the MAIDR package architecture and implementation.

## Documentation Files

### 1. PLOTTING_SYSTEM_DETECTION.md
**Purpose:** Complete guide to understanding the plotting system detection architecture

**Covers:**
- Registry Pattern implementation
- Adapter Pattern for different plotting systems
- System detection flow and logic
- How to add new plotting systems (base R, lattice, plotly, etc.)
- Advanced detection patterns and error handling
- Performance considerations and testing strategies

**Target Audience:** Developers who want to understand how MAIDR detects and handles different plotting systems, or who want to add support for new plotting libraries.

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

**Target Audience:** Developers who want to understand how ggplot2 plots are processed, or who want to add new plot types or extend existing functionality.

### 3. BASE_R_PLOT_IMPLEMENTATION_GUIDE.md
**Purpose:** Complete guide to implementing new Base R plot types

**Covers:**
- Base R function patching system architecture
- Step-by-step implementation process for new plot types
- Data extraction patterns for different plot structures
- Selector generation techniques (recursive grob search, pattern-based)
- Layer processor implementation templates
- Integration with the MAIDR registry system
- Testing and debugging strategies
- Common patterns and best practices

**Target Audience:** Developers who want to add support for new Base R plotting functions to MAIDR, or who want to understand how the Base R system works.

### 4. BASE_R_BAR_PLOT_IMPLEMENTATION.md
**Purpose:** Comprehensive guide to Base R bar plot implementation (simple and dodged)

**Covers:**
- Complete architecture of Base R bar plot processing
- Plot type detection logic (simple vs dodged vs stacked)
- Modular patching system for consistent data ordering
- Data extraction and processing for both plot types
- DOM ordering and backend integration with `domOrder` field
- Selector generation using recursive grob search
- Robustness testing with various data configurations
- Complete data flow from function call to HTML output
- Examples and edge cases

**Target Audience:** Developers who want to understand how Base R bar plots work in MAIDR, or who need to debug or extend bar plot functionality.

## Quick Start

1. **For System Detection:** Start with `PLOTTING_SYSTEM_DETECTION.md` to understand the overall architecture
2. **For ggplot2 Implementation:** Start with `GGPLOT2_SYSTEM_IMPLEMENTATION.md` to understand the specific ggplot2 processing pipeline
3. **For Base R Implementation:** Start with `BASE_R_PLOT_IMPLEMENTATION_GUIDE.md` to understand how to add new Base R plot types
4. **For Adding New Features:** All documents provide step-by-step guides for extending the system

## Architecture Overview

```
Plot Object → System Detection → Adapter → Orchestrator → Layer Processors → Enhanced SVG
```

The documentation explains each step in detail, from high-level architecture decisions to low-level implementation specifics.

## Contributing

When adding new functionality:
1. Follow the patterns established in the existing code
2. Update relevant documentation
3. Add appropriate tests
4. Consider performance implications
5. Maintain backward compatibility

Both documentation files include examples, code snippets, and best practices to guide development.
