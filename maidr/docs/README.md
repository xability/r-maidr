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

## Quick Start

1. **For System Detection:** Start with `PLOTTING_SYSTEM_DETECTION.md` to understand the overall architecture
2. **For ggplot2 Implementation:** Start with `GGPLOT2_SYSTEM_IMPLEMENTATION.md` to understand the specific ggplot2 processing pipeline
3. **For Adding New Features:** Both documents provide step-by-step guides for extending the system

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
