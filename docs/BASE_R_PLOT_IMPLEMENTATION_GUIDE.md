# MAIDR Base R Plot Implementation Guide

## Overview

This guide provides comprehensive documentation for adding new Base R plot types to the MAIDR system. It covers the complete implementation process from understanding the architecture to creating new layer processors for specific Base R plotting functions.

## Architecture Overview

The Base R plotting system in MAIDR uses a **function patching approach** combined with the **Registry Pattern** to intercept and process Base R plotting calls. The system consists of several key components:

```
Base R Plotting Functions (barplot, plot, hist, etc.)
        ↓ (Function Patching)
   Call Recording & Interception
        ↓
   BaseRAdapter (Detection & Routing)
        ↓
   BaseRPlotOrchestrator (Coordination)
        ↓
   BaseRProcessorFactory (Processor Creation)
        ↓
   Layer Processors (Data Extraction & Selector Generation)
        ↓
   Enhanced SVG Output
```

## Core Components

### 1. Function Patching System

**File:** `maidr/R/base_r_function_patching.R`

The function patching system intercepts Base R plotting calls by "shadowing" original functions in the global environment. This allows MAIDR to capture plot calls and their arguments without modifying the original plotting behavior.

#### Key Features:
- **Non-invasive**: Original plotting functions work exactly as before
- **Automatic**: Function wrapping happens during package load
- **Robust**: Handles function lookup across multiple namespaces
- **Clean**: Original functions can be restored when needed

#### Wrapped Functions:
```r
fns_to_wrap <- c(
  "barplot",    # Bar charts
  "plot",       # Line/point plots
  "hist",       # Histograms
  "boxplot",    # Box plots
  "image",      # Heatmaps
  "contour",    # Contour plots
  "matplot"     # Multiple line plots
)
```

#### How It Works:
```r
# Original function call
barplot(c(1, 2, 3), names.arg = c("A", "B", "C"))

# Gets intercepted and logged:
log_entry <- list(
  function_name = "barplot",
  call_expr = "barplot(c(1, 2, 3), names.arg = c(\"A\", \"B\", \"C\"))",
  args = list(height = c(1, 2, 3), names.arg = c("A", "B", "C")),
  timestamp = Sys.time()
)

# Then original function is called normally
```

### 2. BaseRAdapter

**File:** `maidr/R/base_r_adapter.R`

The adapter implements the `SystemAdapter` interface and provides Base R-specific functionality for the MAIDR system.

#### Key Responsibilities:
- **System Detection**: Check if Base R plotting is active and has recorded calls
- **Layer Type Detection**: Map Base R function names to MAIDR layer types
- **Orchestrator Creation**: Create the Base R orchestrator for processing
- **Patching Management**: Interface with the function patching system

#### Core Methods:
```r
BaseRAdapter <- R6::R6Class("BaseRAdapter",
  inherit = SystemAdapter,
  public = list(
    # System detection
    can_handle = function(plot_object) {
      return(is_patching_active() && length(get_plot_calls()) > 0)
    },
    
    # Layer type detection
    detect_layer_type = function(layer, plot_object = NULL) {
      function_name <- layer$function_name
      switch(function_name,
        "barplot" = "bar",
        "plot" = "line",
        "hist" = "hist",
        "boxplot" = "box",
        "image" = "heat",
        "contour" = "contour",
        "matplot" = "line",
        "unknown"
      )
    },
    
    # Create orchestrator
    create_orchestrator = function(plot_object = NULL) {
      BaseRPlotOrchestrator$new()
    }
  )
)
```

### 3. BaseRPlotOrchestrator

**File:** `maidr/R/base_r_plot_orchestrator.R`

The orchestrator coordinates the processing of Base R plots, handling multiple layers and converting them to interactive SVG.

#### Key Responsibilities:
- **Layer Detection**: Analyze recorded plot calls to identify layers
- **Processor Creation**: Create appropriate processors for each layer type
- **Grob Conversion**: Convert Base R plot calls to grob trees using `ggplotify`
- **Data Coordination**: Combine results from multiple layers
- **Layout Management**: Extract titles, axis labels, and other plot metadata

#### Processing Flow:
```r
BaseRPlotOrchestrator <- R6::R6Class("BaseRPlotOrchestrator",
  public = list(
    initialize = function() {
      # Get recorded plot calls
      private$.plot_calls <- get_plot_calls()
      
      # Process the calls
      self$detect_layers()
      self$create_layer_processors()
      self$process_layers()
    },
    
    detect_layers = function() {
      # Analyze each plot call as a separate layer
      for (i in seq_along(private$.plot_calls)) {
        layer_info <- self$analyze_single_layer(private$.plot_calls[[i]], i)
        private$.layers[[i]] <- layer_info
      }
    },
    
    get_gtable = function() {
      # Convert plot calls to grob trees using ggplotify
      grob_list <- list()
      for (i in seq_along(private$.plot_calls)) {
        plot_call <- private$.plot_calls[[i]]
        plot_func <- function() { do.call(plot_call$function_name, plot_call$args) }
        grob <- ggplotify::as.grob(plot_func)
        grob_list[[i]] <- grob
      }
      private$.grob_list <- grob_list
      return(grob_list[[1]])  # Return first grob as main gtable
    }
  )
)
```

### 4. BaseRProcessorFactory

**File:** `maidr/R/base_r_processor_factory.R`

The factory creates appropriate layer processors based on the detected plot type.

#### Implementation:
```r
BaseRProcessorFactory <- R6::R6Class("BaseRProcessorFactory",
  inherit = ProcessorFactory,
  public = list(
    create_processor = function(layer_type, layer_info) {
      switch(layer_type,
        "bar" = BaseRBarplotLayerProcessor$new(layer_info),
        "line" = BaseRLineLayerProcessor$new(layer_info),
        "hist" = BaseRHistogramLayerProcessor$new(layer_info),
        "box" = BaseRBoxplotLayerProcessor$new(layer_info),
        "heat" = BaseRHeatmapLayerProcessor$new(layer_info),
        "contour" = BaseRContourLayerProcessor$new(layer_info),
        BaseRUnknownLayerProcessor$new(layer_info)
      )
    }
  )
)
```

## Layer Processors

### LayerProcessor Interface

**File:** `maidr/R/layer_processor.R`

All layer processors inherit from the abstract `LayerProcessor` class, which defines the interface that must be implemented:

```r
LayerProcessor <- R6::R6Class("LayerProcessor",
  public = list(
    # Core processing method
    process = function(plot, layout, built = NULL, gt = NULL, ...) {
      data <- self$extract_data(...)
      selectors <- self$generate_selectors(...)
      list(data = data, selectors = selectors)
    },
    
    # Abstract methods to implement
    extract_data = function(...) {
      stop("extract_data() method must be implemented by subclasses")
    },
    
    generate_selectors = function(...) {
      stop("generate_selectors() method must be implemented by subclasses")
    }
  )
)
```

### Base R Layer Processor Example

**File:** `maidr/R/base_r_barplot_layer_processor.R`

Here's a complete example of a Base R layer processor:

```r
BaseRBarplotLayerProcessor <- R6::R6Class("BaseRBarplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)
      
      list(
        data = data,
        selectors = selectors,
        type = "bar",
        title = title,
        axes = axes
      )
    },
    
    extract_data = function(layer_info) {
      plot_call <- layer_info$plot_call
      args <- plot_call$args
      
      # Extract height (primary argument)
      height <- args$height
      if (is.null(height) && length(args) > 0) {
        height <- args[[1]]  # First argument if height not named
      }
      
      # Extract labels
      labels <- args$names.arg
      if (is.null(labels)) {
        labels <- names(height)
      }
      if (is.null(labels)) {
        labels <- seq_along(height)
      }
      
      # Convert to data points format
      data_points <- list()
      if (!is.null(height)) {
        height <- as.numeric(height)
        labels <- as.character(labels)
        n <- min(length(height), length(labels))
        
        for (i in seq_len(n)) {
          data_points[[i]] <- list(
            x = labels[i],
            y = height[i]
          )
        }
      }
      
      data_points
    },
    
    generate_selectors = function(layer_info, gt = NULL) {
      plot_call_index <- layer_info$index
      
      # Use recursive grob search if grob is available
      if (!is.null(gt)) {
        selectors <- self$generate_selectors_from_grob(gt, plot_call_index)
        if (length(selectors) > 0) {
          return(selectors)
        }
      }
      
      # Fallback to pattern-based selector
      selector <- paste0("rect[id^='graphics-plot-", plot_call_index, "-rect-1']")
      list(selector)
    }
  )
)
```

## Step-by-Step Implementation Guide

### Step 1: Add Function to Patching List

**File:** `maidr/R/base_r_function_patching.R`

Add your new plotting function to the `fns_to_wrap` list:

```r
fns_to_wrap <- c(
  "barplot",
  "plot", 
  "hist",
  "boxplot",
  "image",
  "contour",
  "matplot",
  "your_new_function"  # Add your function here
)
```

### Step 2: Update Layer Type Detection

**File:** `maidr/R/base_r_adapter.R`

Add your function mapping in the `detect_layer_type` method:

```r
detect_layer_type = function(layer, plot_object = NULL) {
  function_name <- layer$function_name
  switch(function_name,
    "barplot" = "bar",
    "plot" = "line",
    "hist" = "hist",
    "boxplot" = "box",
    "image" = "heat",
    "contour" = "contour",
    "matplot" = "line",
    "your_new_function" = "your_layer_type",  # Add your mapping
    "unknown"
  )
}
```

### Step 3: Create Layer Processor

**File:** `maidr/R/base_r_your_plot_layer_processor.R`

Create a new layer processor file following this template:

```r
#' Base R Your Plot Layer Processor
#'
#' Processes Base R your_plot layers based on recorded plot calls
#'
#' @keywords internal
BaseRYourPlotLayerProcessor <- R6::R6Class("BaseRYourPlotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)
      
      list(
        data = data,
        selectors = selectors,
        type = "your_layer_type",
        title = title,
        axes = axes
      )
    },
    
    extract_data = function(layer_info) {
      # Implement data extraction logic specific to your plot type
      # Extract relevant data from layer_info$plot_call$args
      # Return data in the format: list(list(x = ..., y = ...), ...)
    },
    
    extract_axis_titles = function(layer_info) {
      # Extract xlab, ylab from plot call arguments
      plot_call <- layer_info$plot_call
      args <- plot_call$args
      
      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""
      
      list(x = x_title, y = y_title)
    },
    
    extract_main_title = function(layer_info) {
      # Extract main title from plot call arguments
      plot_call <- layer_info$plot_call
      args <- plot_call$args
      
      if (!is.null(args$main)) args$main else ""
    },
    
    generate_selectors = function(layer_info, gt = NULL) {
      # Implement selector generation for your plot type
      # Use recursive grob search for complex plots
      # Fallback to pattern-based selectors for simple cases
    }
  )
)
```

### Step 4: Update Processor Factory

**File:** `maidr/R/base_r_processor_factory.R`

Add your processor to the factory:

```r
create_processor = function(layer_type, layer_info) {
  switch(layer_type,
    "bar" = BaseRBarplotLayerProcessor$new(layer_info),
    "line" = BaseRLineLayerProcessor$new(layer_info),
    "hist" = BaseRHistogramLayerProcessor$new(layer_info),
    "box" = BaseRBoxplotLayerProcessor$new(layer_info),
    "heat" = BaseRHeatmapLayerProcessor$new(layer_info),
    "contour" = BaseRContourLayerProcessor$new(layer_info),
    "your_layer_type" = BaseRYourPlotLayerProcessor$new(layer_info),  # Add your processor
    BaseRUnknownLayerProcessor$new(layer_info)
  )
}
```

### Step 5: Update NAMESPACE

**File:** `maidr/NAMESPACE`

Add your new processor class to the exports:

```r
export(BaseRYourPlotLayerProcessor)
```

## Data Extraction Patterns

### Simple Vector Data

For plots that take simple vectors (like `barplot`, `plot`):

```r
extract_data = function(layer_info) {
  plot_call <- layer_info$plot_call
  args <- plot_call$args
  
  # Get primary data (usually first argument)
  data_vector <- args[[1]]
  
  # Get labels if provided
  labels <- args$names.arg  # or xlab, ylab, etc.
  if (is.null(labels)) {
    labels <- names(data_vector)
  }
  if (is.null(labels)) {
    labels <- seq_along(data_vector)
  }
  
  # Convert to MAIDR format
  data_points <- list()
  for (i in seq_along(data_vector)) {
    data_points[[i]] <- list(
      x = labels[i],
      y = data_vector[i]
    )
  }
  
  data_points
}
```

### Matrix Data

For plots that take matrices (like `image`, `contour`):

```r
extract_data = function(layer_info) {
  plot_call <- layer_info$plot_call
  args <- plot_call$args
  
  # Get matrix data
  matrix_data <- args$z  # or first argument
  x_coords <- args$x
  y_coords <- args$y
  
  # Convert matrix to point format
  data_points <- list()
  for (i in seq_len(nrow(matrix_data))) {
    for (j in seq_len(ncol(matrix_data))) {
      data_points[[length(data_points) + 1]] <- list(
        x = x_coords[j],
        y = y_coords[i],
        z = matrix_data[i, j]
      )
    }
  }
  
  data_points
}
```

### Multi-Series Data

For plots with multiple series (like `matplot`):

```r
extract_data = function(layer_info) {
  plot_call <- layer_info$plot_call
  args <- plot_call$args
  
  x_data <- args$x
  y_data <- args$y
  
  # Handle multiple columns in y_data
  series_data <- list()
  for (col in seq_len(ncol(y_data))) {
    series_points <- list()
    for (i in seq_len(nrow(y_data))) {
      series_points[[i]] <- list(
        x = x_data[i],
        y = y_data[i, col]
      )
    }
    series_data[[col]] <- series_points
  }
  
  series_data
}
```

## Selector Generation Patterns

### Recursive Grob Search

For complex plots, use recursive search through the grob tree:

```r
find_element_grobs = function(grob, pattern) {
  names <- character(0)
  
  # Check if current grob matches pattern
  if (!is.null(grob$name) && grepl(pattern, grob$name)) {
    names <- c(names, grob$name)
  }
  
  # Recursively search children
  if (inherits(grob, "gList")) {
    for (i in seq_along(grob)) {
      names <- c(names, self$find_element_grobs(grob[[i]], pattern))
    }
  }
  
  if (inherits(grob, "gTree")) {
    if (!is.null(grob$children)) {
      for (i in seq_along(grob$children)) {
        names <- c(names, self$find_element_grobs(grob$children[[i]], pattern))
      }
    }
  }
  
  names
}

generate_selectors_from_grob = function(grob, call_index) {
  # Find elements matching your plot type
  element_names <- self$find_element_grobs(grob, "your-pattern")
  
  if (length(element_names) == 0) {
    return(list())
  }
  
  # Generate selectors
  selectors <- lapply(element_names, function(name) {
    svg_id <- paste0(name, ".1")
    escaped <- gsub("\\.", "\\\\.", svg_id)
    paste0("#", escaped, " your-element-type")
  })
  
  selectors
}
```

### Pattern-Based Selectors

For simple plots, use pattern-based selectors:

```r
generate_selectors = function(layer_info, gt = NULL) {
  plot_call_index <- layer_info$index
  
  # Create selector pattern based on your plot type
  # Common patterns:
  selector <- paste0("rect[id^='graphics-plot-", plot_call_index, "-rect-1']")      # bars
  selector <- paste0("polyline[id^='graphics-plot-", plot_call_index, "-polyline-1']")  # lines
  selector <- paste0("polygon[id^='graphics-plot-", plot_call_index, "-polygon-1']")    # areas
  selector <- paste0("circle[id^='graphics-plot-", call_index, "-circle-1']")           # points
  
  list(selector)
}
```

## Testing Your Implementation

### 1. Create Test Script

```r
# File: test_your_plot_type.R
library(devtools)
load_all("maidr")

# Test your new plot type
your_plot_function(data, xlab = "X Label", ylab = "Y Label", main = "Title")

# Generate interactive HTML
show(file = "test_output.html", open = FALSE)
```

### 2. Verify Data Extraction

Check that your data extraction correctly captures:
- Primary data values
- Labels and categories
- Axis titles
- Main title
- Any special parameters

### 3. Verify Selector Generation

Ensure selectors correctly target:
- The right SVG elements
- All data points in your plot
- Match the visual structure

### 4. Test Multi-Layer Plots

Verify that your plot type works correctly when combined with other plot types:

```r
# Test multi-layer Base R plot
barplot(c(1, 2, 3))
lines(c(0.5, 1.5, 2.5), c(1.5, 2.5, 0.5))
points(c(1, 2, 3), c(1, 2, 3))

show(file = "test_multilayer.html", open = FALSE)
```

## Common Patterns and Best Practices

### 1. Argument Extraction

```r
# Robust argument extraction
extract_argument = function(args, name, default = NULL) {
  if (!is.null(args[[name]])) {
    return(args[[name]])
  }
  
  # Try positional argument
  if (name == "x" && length(args) > 0) {
    return(args[[1]])
  }
  if (name == "y" && length(args) > 1) {
    return(args[[2]])
  }
  
  return(default)
}
```

### 2. Data Validation

```r
# Validate and clean data
validate_data = function(data_vector) {
  if (is.null(data_vector)) {
    return(NULL)
  }
  
  # Convert to numeric
  data_vector <- as.numeric(data_vector)
  
  # Remove NAs
  data_vector <- data_vector[!is.na(data_vector)]
  
  if (length(data_vector) == 0) {
    return(NULL)
  }
  
  data_vector
}
```

### 3. Error Handling

```r
# Robust error handling
extract_data = function(layer_info) {
  tryCatch({
    # Your extraction logic here
    data_points <- self$extract_data_internal(layer_info)
    return(data_points)
  }, error = function(e) {
    warning("Failed to extract data for layer: ", e$message)
    return(list())
  })
}
```

### 4. Fallback Selectors

```r
# Always provide fallback selectors
generate_selectors = function(layer_info, gt = NULL) {
  # Try sophisticated approach first
  if (!is.null(gt)) {
    selectors <- self$generate_selectors_from_grob(gt, layer_info$index)
    if (length(selectors) > 0) {
      return(selectors)
    }
  }
  
  # Fallback to simple pattern
  selector <- paste0("your-element[id^='graphics-plot-", layer_info$index, "-your-element-1']")
  list(selector)
}
```

## Integration with Existing System

### 1. System Initialization

Your new plot type will automatically be available once you:
- Add the function to `fns_to_wrap`
- Update the adapter's `detect_layer_type` method
- Create the layer processor
- Update the processor factory
- Export the processor class

### 2. Registry Integration

The Base R system is automatically registered during package load:

```r
# In maidr/R/ggplot2_system_init.R
.onLoad <- function(libname, pkgname) {
  initialize_ggplot2_system()
  initialize_base_r_system()      # Your system is included here
  initialize_base_r_patching()    # Function patching starts automatically
}
```

### 3. User Interface

Users can use your new plot type seamlessly:

```r
library(maidr)

# Create your plot (function patching is automatic)
your_plot_function(data, ...)

# Generate interactive HTML
show(file = "output.html", open = FALSE)
```

## Troubleshooting

### Common Issues

1. **Function Not Being Intercepted**
   - Check that function is in `fns_to_wrap` list
   - Verify function exists in expected namespace
   - Ensure patching is initialized

2. **Wrong Layer Type Detected**
   - Check `detect_layer_type` mapping in adapter
   - Verify function name matches exactly

3. **Data Extraction Fails**
   - Debug argument structure with `str(layer_info$plot_call$args)`
   - Check for named vs. positional arguments
   - Validate data types and structure

4. **Selectors Don't Match**
   - Inspect grob structure with `str(gt)`
   - Verify element naming patterns
   - Test selector patterns manually

5. **Multi-Layer Issues**
   - Ensure each layer gets correct grob
   - Check layer indexing in orchestrator
   - Verify selector uniqueness across layers

### Debugging Tools

```r
# Debug plot calls
get_plot_calls()

# Debug grob structure
gt <- orchestrator$get_gtable()
str(gt)

# Debug layer info
layer_info <- private$.layers[[1]]
str(layer_info)
```

## Conclusion

This guide provides everything needed to add new Base R plot types to the MAIDR system. The architecture is designed to be extensible while maintaining consistency with existing patterns. Follow the step-by-step process, use the provided templates, and test thoroughly to ensure your implementation works correctly with the rest of the system.

For more advanced features or complex plot types, refer to the existing implementations in the codebase and consider extending the base classes if needed.
