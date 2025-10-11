# Unified Architecture Refactor Plan

## Overview

This document outlines the comprehensive refactoring plan to unify the plot processing system in the `maidr` package, eliminating code duplication and improving maintainability through the use of design patterns.

## Current Problems

### 1. Code Duplication
- **`maidr.R`**: Contains duplicate logic for handling multipanel vs single plots
- **Multiple orchestrators**: `PlotOrchestrator`, `FacetProcessor`, `PatchworkProcessor` have overlapping responsibilities
- **Layer processing**: Similar logic scattered across different processors

### 2. Inconsistent Interfaces
- Different processors use different method signatures
- No unified way to handle single plots, faceted plots, and patchwork compositions
- Adapter pattern not fully utilized

### 3. Maintenance Issues
- Changes require updates in multiple places
- New plot types require modifications across several files
- Hard to extend to new plotting systems

## Design Patterns Solution

### 1. Composite Pattern
**Purpose**: Treat individual plots and compositions of plots uniformly

```r
# Component hierarchy
Ggplot2Component (abstract)
├── Ggplot2SinglePlot
├── Ggplot2FacetedPlot
└── Ggplot2PatchworkPlot
```

**Benefits**:
- Uniform interface for all plot types
- Recursive structure for nested compositions
- Easy to add new plot types

### 2. Template Method Pattern
**Purpose**: Define the algorithm skeleton with steps implemented by subclasses

```r
Ggplot2UnifiedProcessor
├── build_component_tree()     # Template method
├── process_component_tree()   # Template method
└── generate_maidr_data()      # Template method

# Specific implementations for each plot type
├── build_single_plot_tree()
├── build_faceted_plot_tree()
└── build_patchwork_plot_tree()
```

**Benefits**:
- Consistent processing flow
- Easy to modify steps without changing overall algorithm
- Code reuse across different plot types

### 3. Strategy Pattern
**Purpose**: Encapsulate interchangeable algorithms

```r
Ggplot2DetectorRegistry
├── SinglePlotDetector
├── FacetedPlotDetector
└── PatchworkDetector
```

**Benefits**:
- Easy to add new detection strategies
- Runtime algorithm selection
- Isolated algorithm logic

### 4. Registry Pattern
**Purpose**: Centralized management of components and strategies

```r
Ggplot2DetectorRegistry
├── register_detector()
├── get_detector()
└── detect_plot_structure()

Ggplot2ComponentRegistry
├── register_component()
├── get_component()
└── create_component()
```

**Benefits**:
- Centralized component management
- Easy registration of new components
- Decoupled component creation

### 5. Delegation Pattern
**Purpose**: New components delegate tasks to existing specialized processors

```r
Ggplot2UnifiedProcessor
├── delegates to PlotOrchestrator for single plots
├── delegates to FacetProcessor for faceted plots
└── delegates to PatchworkProcessor for patchwork plots
```

**Benefits**:
- Reuse existing proven logic
- Gradual migration path
- Backward compatibility

## Architecture Design

### Core Components

#### 1. Component System
```
maidr/R/ggplot2_plot_component.R
- Ggplot2Component (abstract base class)
- Ggplot2SinglePlot
- Ggplot2FacetedPlot  
- Ggplot2PatchworkPlot
```

#### 2. Structure Detection
```
maidr/R/ggplot2_structure_detector.R
- Ggplot2DetectorRegistry
- SinglePlotDetector
- FacetedPlotDetector
- PatchworkDetector
```

#### 3. Unified Processing
```
maidr/R/ggplot2_unified_processor.R
- Ggplot2UnifiedProcessor (Template Method)
- Process single, faceted, and patchwork plots uniformly
```

#### 4. Component Registry
```
maidr/R/ggplot2_component_registry.R
- Ggplot2ComponentRegistry
- Component creation and management
```

#### 5. Processor Adapters
```
maidr/R/ggplot2_processor_adapter.R
- Ggplot2OrchestratorAdapter
- Ggplot2LayerProcessorAdapter
- Bridge new system with existing processors
```

#### 6. Unified Orchestrator
```
maidr/R/plot_orchestrator_unified.R
- PlotOrchestratorUnified
- Maintains external interface compatibility
- Uses component system internally
```

### Integration Points

#### 1. Adapter Integration
```r
# In ggplot2_adapter.R
create_orchestrator = function(plot_object) {
  # Use unified orchestrator by default
  PlotOrchestratorUnified$new(plot_object)
}
```

#### 2. Main Entry Point
```r
# In maidr.R
create_maidr_html = function(plot, ...) {
  # Single path through unified system
  orchestrator <- adapter$create_orchestrator(plot)
  maidr_data <- orchestrator$generate_maidr_data()
  # ... rest of processing
}
```

## Migration Strategy

### Phase 1: Component Foundation
1. Create `Ggplot2Component` hierarchy
2. Implement `Ggplot2DetectorRegistry` and detectors
3. Create `Ggplot2UnifiedProcessor` skeleton

### Phase 2: Adapter Layer
1. Implement processor adapters
2. Create delegation mechanisms
3. Ensure backward compatibility

### Phase 3: Integration
1. Integrate unified processor with adapter
2. Add feature flag for gradual rollout
3. Test with existing plot types

### Phase 4: Migration
1. Remove feature flags
2. Make unified system the default
3. Update all entry points

### Phase 5: Cleanup
1. Remove duplicate code from `maidr.R`
2. Simplify `create_maidr_html()`
3. Remove unused functions

### Phase 6: Final Cleanup
1. Remove `create_layers_from_orchestrator()`
2. Remove `create_maidr_data()` duplication
3. Final testing and validation

## Benefits

### 1. Code Reduction
- Eliminate duplicate logic in `maidr.R`
- Consolidate similar processing across different plot types
- Reduce maintenance burden

### 2. Extensibility
- Easy to add new plot types
- Simple to extend to new plotting systems
- Plugin architecture for future enhancements

### 3. Maintainability
- Single source of truth for processing logic
- Consistent interfaces across components
- Clear separation of concerns

### 4. Performance
- Reuse existing optimized processors
- Minimal overhead from delegation
- Efficient component creation

## Implementation Details

### File Structure
```
maidr/R/
├── ggplot2_plot_component.R      # Component hierarchy
├── ggplot2_structure_detector.R  # Detection strategies
├── ggplot2_unified_processor.R   # Main processing logic
├── ggplot2_component_registry.R  # Component management
├── ggplot2_processor_adapter.R   # Adapter layer
└── plot_orchestrator_unified.R   # Unified orchestrator
```

### Key Methods

#### Ggplot2UnifiedProcessor
```r
build_component_tree(structure_info, layout, gt)
process_component_tree(component_tree)
process_layers_for_subplot(plot, subplot, layout, gt)
process_layers_for_facet_subplot(plot, subplot, layout, gt)
process_layers_for_patchwork_subplot(plot, subplot, layout, gt)
```

#### PlotOrchestratorUnified
```r
generate_maidr_data()
get_combined_data()
get_combined_selectors()
get_layout()
get_gtable()
```

## Testing Strategy

### 1. Unit Tests
- Test each component individually
- Verify detection strategies
- Test adapter functionality

### 2. Integration Tests
- Test complete processing pipeline
- Verify output consistency with original system
- Test all plot types (single, faceted, patchwork)

### 3. Regression Tests
- Compare outputs before and after refactoring
- Verify selector generation
- Test SVG generation consistency

## Risk Mitigation

### 1. Gradual Migration
- Feature flags for safe rollout
- Parallel testing of old and new systems
- Easy rollback mechanism

### 2. Backward Compatibility
- Maintain existing external interfaces
- Preserve all existing functionality
- No breaking changes for users

### 3. Comprehensive Testing
- Automated testing suite
- Manual verification of all plot types
- Performance benchmarking

## Success Criteria

1. **Functionality**: All existing plot types work correctly
2. **Performance**: No significant performance degradation
3. **Code Quality**: Reduced duplication and improved maintainability
4. **Extensibility**: Easy to add new plot types and systems
5. **Compatibility**: No breaking changes for existing users

## Future Enhancements

### 1. Additional Plot Types
- Box plots, violin plots, etc.
- Custom geom support
- Statistical plot types

### 2. New Plotting Systems
- Base R plots
- Lattice plots
- Other ggplot2 extensions

### 3. Advanced Features
- Interactive annotations
- Dynamic styling
- Real-time updates

## Conclusion

This unified architecture refactor will transform the `maidr` package from a collection of specialized processors into a cohesive, extensible system. By applying proven design patterns and maintaining backward compatibility, we can achieve significant improvements in code quality, maintainability, and extensibility while preserving all existing functionality.

The phased migration approach ensures a safe transition with minimal risk, while the component-based architecture provides a solid foundation for future enhancements and new plotting system support.
