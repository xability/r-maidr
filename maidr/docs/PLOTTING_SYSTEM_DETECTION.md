# MAIDR Plotting System Detection Architecture

## Overview

The MAIDR package uses a sophisticated **Registry Pattern** with **Adapter Pattern** to create an extensible, pluggable architecture that can support multiple plotting systems (ggplot2, base R, lattice, plotly, etc.) through a unified interface.

## Architecture Components

### 1. PlotSystemRegistry (Central Hub)

**File:** `maidr/R/plot_system_registry.R`

The central registry manages all plotting systems and their components. It acts as a factory and service locator for the entire system.

#### Key Responsibilities:
- **System Registration**: Register new plotting systems with their adapters and factories
- **System Detection**: Automatically detect which system can handle a given plot object
- **Component Retrieval**: Provide access to adapters and processor factories for specific systems
- **System Management**: List, check, and unregister plotting systems

#### Core Methods:

```r
# Register a new plotting system
register_system(system_name, adapter, processor_factory)

# Detect which system can handle a plot object
detect_system(plot_object) -> system_name | NULL

# Get components for a specific system
get_adapter(system_name) -> adapter
get_processor_factory(system_name) -> processor_factory

# Auto-detect and get components
get_adapter_for_plot(plot_object) -> adapter
get_processor_factory_for_plot(plot_object) -> processor_factory
```

#### Internal Structure:
```r
private = list(
  .registered_systems = list(),      # Registered system names
  .system_adapters = list(),         # Adapter instances by system
  .processor_factories = list()      # Factory instances by system
)
```

### 2. SystemAdapter (Abstract Base Class)

**File:** `maidr/R/system_adapter.R`

Abstract base class defining the interface that all plotting system adapters must implement. This ensures consistent behavior across different plotting systems.

#### Required Interface:
```r
SystemAdapter <- R6::R6Class("SystemAdapter",
  public = list(
    system_name = NULL,                    # System identifier
    
    # Core detection methods
    can_handle(plot_object) -> logical,    # Can this adapter handle the plot?
    
    # Processing methods
    create_orchestrator(plot_object) -> orchestrator,  # Create system-specific orchestrator
  )
)
```

#### Design Principles:
- **Single Responsibility**: Each adapter handles exactly one plotting system
- **Interface Segregation**: Clean, focused interface
- **Polymorphism**: Same interface, different implementations
- **Extensibility**: Easy to add new plotting systems

### 3. Global Registry Management

**File:** `maidr/R/plot_system_registry.R`

#### Global Registry Instance:
```r
# Singleton pattern for global registry
global_registry <- NULL

get_global_registry() -> PlotSystemRegistry
reset_global_registry()  # For testing
```

## System Detection Flow

### Complete Detection Process:

```
1. User Input
   ↓
   maidr::show(plot_object)
   ↓

2. Entry Point
   ↓
   create_maidr_html(plot_object)
   ↓

3. System Detection
   ↓
   registry <- get_global_registry()
   system_name <- registry$detect_system(plot_object)
   ↓

4. Registry Detection Logic
   ↓
   for each registered_system in registry:
     adapter <- get_adapter(system)
     if adapter$can_handle(plot_object):
       return system_name
   return NULL
   ↓

5. Adapter-Specific Detection
   ↓
   Ggplot2Adapter$can_handle(plot_object):
     return inherits(plot_object, "ggplot")
   ↓

6. Component Retrieval
   ↓
   adapter <- registry$get_adapter(system_name)
   orchestrator <- adapter$create_orchestrator(plot_object)
   ↓

7. System-Specific Processing
   ↓
   [Continue with detected system's processing pipeline]
```

### Detection Examples:

#### ggplot2 Detection:
```r
# Input: ggplot object
plot <- ggplot(mtcars, aes(x=mpg, y=hp)) + geom_point()

# Detection process:
# 1. registry$detect_system(plot)
# 2. Loop through systems: ["ggplot2"]
# 3. Ggplot2Adapter$can_handle(plot)
# 4. inherits(plot, "ggplot") -> TRUE
# 5. Return "ggplot2"
```

#### Future Base R Detection:
```r
# Input: base R plot object
plot <- recordPlot()  # After base plotting commands

# Detection process:
# 1. registry$detect_system(plot)
# 2. Loop through systems: ["ggplot2", "base_r"]
# 3. Ggplot2Adapter$can_handle(plot) -> FALSE
# 4. BaseRAdapter$can_handle(plot) -> TRUE
# 5. Return "base_r"
```

## Adding New Plotting Systems

### Step-by-Step Guide:

#### 1. Create System Adapter

```r
# File: maidr/R/base_r_adapter.R
BaseRAdapter <- R6::R6Class("BaseRAdapter",
  inherit = SystemAdapter,
  public = list(
    initialize = function() {
      super$initialize("base_r")
    },
    
    can_handle = function(plot_object) {
      # Base R specific detection logic
      inherits(plot_object, "recordedplot") ||
      is.function(plot_object) ||
      is.expression(plot_object)
    },
    
    detect_plot_type = function(plot_object) {
      # Analyze plot structure to determine type
      if (is.function(plot_object)) {
        return("function_plot")
      }
      # More detection logic...
      return("unknown")
    },
    
    create_orchestrator = function(plot_object) {
      BaseRPlotOrchestrator$new(plot_object)
    }
  )
)
```

#### 2. Create Processor Factory

```r
# File: maidr/R/base_r_processor_factory.R
BaseRProcessorFactory <- R6::R6Class("BaseRProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    create_processor = function(layer_type, layer_info) {
      switch(layer_type,
        "points" = BaseRPointProcessor$new(layer_info),
        "lines" = BaseRLineProcessor$new(layer_info),
        "bars" = BaseRBarProcessor$new(layer_info),
        # Default to unknown processor
        BaseRUnknownProcessor$new(layer_info)
      )
    }
  )
)
```

#### 3. Create System Initialization

```r
# File: maidr/R/base_r_system_init.R
initialize_base_r_system <- function() {
  registry <- get_global_registry()
  
  if (registry$is_system_registered("base_r")) {
    return(invisible(NULL))
  }
  
  # Create components
  base_r_adapter <- BaseRAdapter$new()
  base_r_factory <- BaseRProcessorFactory$new()
  
  # Register system
  registry$register_system("base_r", base_r_adapter, base_r_factory)
  
  invisible(NULL)
}
```

#### 4. Auto-Registration

```r
# In package .onLoad function
.onLoad <- function(libname, pkgname) {
  initialize_ggplot2_system()
  initialize_base_r_system()      # Add new system
  initialize_lattice_system()     # Add more systems...
}
```

## Advanced Detection Patterns

### Multi-System Detection:

```r
# Complex detection logic for ambiguous objects
can_handle = function(plot_object) {
  # Primary detection
  if (inherits(plot_object, "ggplot")) return(TRUE)
  
  # Secondary detection (for complex objects)
  if (inherits(plot_object, "list") && 
      "ggplot" %in% sapply(plot_object, class)) return(TRUE)
  
  # Tertiary detection (for wrapped objects)
  if (!is.null(attr(plot_object, "ggplot_class"))) return(TRUE)
  
  return(FALSE)
}
```

### Conditional Registration:

```r
# Register systems only if dependencies are available
initialize_plotly_system <- function() {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    return(invisible(NULL))  # Skip if plotly not available
  }
  
  registry <- get_global_registry()
  # Register plotly system...
}
```

### Priority-Based Detection:

```r
# Systems with higher priority are checked first
detect_system = function(plot_object) {
  # Check high-priority systems first
  priority_systems <- c("ggplot2", "plotly", "base_r")
  
  for (system_name in priority_systems) {
    if (system_name %in% names(private$.registered_systems)) {
      adapter <- private$.system_adapters[[system_name]]
      if (adapter$can_handle(plot_object)) {
        return(system_name)
      }
    }
  }
  
  # Check remaining systems
  for (system_name in setdiff(names(private$.registered_systems), priority_systems)) {
    adapter <- private$.system_adapters[[system_name]]
    if (adapter$can_handle(plot_object)) {
      return(system_name)
    }
  }
  
  return(NULL)
}
```

## Error Handling and Fallbacks

### Graceful Degradation:

```r
detect_system = function(plot_object) {
  tryCatch({
    for (system_name in names(private$.registered_systems)) {
      adapter <- private$.system_adapters[[system_name]]
      if (adapter$can_handle(plot_object)) {
        return(system_name)
      }
    }
    return(NULL)
  }, error = function(e) {
    warning("Error during system detection: ", e$message)
    return("unknown")  # Fallback system
  })
}
```

### Unknown System Handling:

```r
# Fallback adapter for unknown systems
UnknownAdapter <- R6::R6Class("UnknownAdapter",
  inherit = SystemAdapter,
  public = list(
    can_handle = function(plot_object) {
      return(TRUE)  # Always return TRUE as fallback
    },
    
    detect_plot_type = function(plot_object) {
      return("unknown")
    },
    
    create_orchestrator = function(plot_object) {
      UnknownPlotOrchestrator$new(plot_object)
    }
  )
)
```

## Testing System Detection

### Unit Tests:

```r
# Test system registration
test_that("System registration works", {
  registry <- PlotSystemRegistry$new()
  adapter <- Ggplot2Adapter$new()
  factory <- Ggplot2ProcessorFactory$new()
  
  registry$register_system("test", adapter, factory)
  
  expect_true(registry$is_system_registered("test"))
  expect_equal(registry$list_systems(), "test")
})

# Test detection logic
test_that("Detection works for ggplot2", {
  registry <- get_global_registry()
  plot <- ggplot(mtcars, aes(x=mpg, y=hp)) + geom_point()
  
  system_name <- registry$detect_system(plot)
  expect_equal(system_name, "ggplot2")
})

# Test fallback behavior
test_that("Unknown objects return NULL", {
  registry <- get_global_registry()
  unknown_object <- list(x=1, y=2)
  
  system_name <- registry$detect_system(unknown_object)
  expect_null(system_name)
})
```

## Performance Considerations

### Caching Detection Results:

```r
# Cache detection results for expensive operations
detect_system = function(plot_object) {
  # Create cache key from object characteristics
  cache_key <- digest::digest(list(
    class(plot_object),
    length(plot_object),
    if (inherits(plot_object, "ggplot")) length(plot_object$layers)
  ))
  
  # Check cache first
  if (exists(cache_key, envir = detection_cache)) {
    return(get(cache_key, envir = detection_cache))
  }
  
  # Perform detection
  result <- self$detect_system_internal(plot_object)
  
  # Cache result
  assign(cache_key, result, envir = detection_cache)
  
  return(result)
}
```

### Lazy Loading:

```r
# Only initialize systems when needed
get_adapter = function(system_name) {
  if (!system_name %in% names(private$.system_adapters)) {
    # Lazy initialization
    if (system_name == "plotly") {
      initialize_plotly_system()
    } else if (system_name == "lattice") {
      initialize_lattice_system()
    }
  }
  
  private$.system_adapters[[system_name]]
}
```

## Best Practices

### 1. Detection Logic:
- Keep detection logic simple and fast
- Use `inherits()` checks when possible
- Avoid expensive operations in detection
- Provide clear, unambiguous detection criteria

### 2. Error Handling:
- Always provide fallbacks for unknown objects
- Log detection failures for debugging
- Gracefully handle missing dependencies

### 3. Extensibility:
- Design adapters to be self-contained
- Minimize dependencies between systems
- Provide clear interfaces for new systems

### 4. Testing:
- Test detection with various object types
- Test error conditions and edge cases
- Test system registration and unregistration

This architecture provides a robust, extensible foundation for supporting multiple plotting systems while maintaining clean separation of concerns and easy extensibility.
