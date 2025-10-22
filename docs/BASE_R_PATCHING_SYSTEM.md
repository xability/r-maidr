# Base R Patching System Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Data Flow](#data-flow)
5. [Function Classification](#function-classification)
6. [Device-Scoped Storage](#device-scoped-storage)
7. [State Tracking](#state-tracking)
8. [Plot Grouping](#plot-grouping)
9. [Orchestrator Integration](#orchestrator-integration)
10. [Debugging Guide](#debugging-guide)
11. [Troubleshooting](#troubleshooting)

---

## Overview

The Base R Patching System intercepts Base R plotting function calls to make them accessible to MAIDR for creating interactive visualizations. Unlike ggplot2 which provides plot objects, Base R plots are rendered immediately, so we must capture the calls before they execute.

### Key Features
- **Function Patching**: Wraps Base R plotting functions to intercept calls
- **Device Isolation**: Each graphics device has separate storage
- **Multi-layer Support**: Groups HIGH-level plots with LOW-level additions (lines, points)
- **Multi-panel Support**: Detects and handles `par(mfrow)` and `layout()` configurations
- **No Accumulation**: Calls are cleared after each `save_html()` or `show()` call

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User R Code                              │
│  barplot(c(3,5,7))                                         │
│  lines(c(1,2,3), c(4,6,5))                                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│          Function Patching Layer                            │
│  (base_r_function_patching.R)                              │
│  - Wraps 33 functions (HIGH, LOW, LAYOUT)                  │
│  - Captures calls AFTER execution                          │
│  - Logs to device-scoped storage                           │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│     Device-Scoped Storage                                   │
│  (base_r_device_storage.R)                                 │
│  - Stores calls per graphics device                        │
│  - Classifies as HIGH/LOW/LAYOUT                           │
│  - Maintains device state                                  │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│       State Tracking                                        │
│  (base_r_state_tracking.R)                                 │
│  - Tracks current plot index                               │
│  - Detects multi-panel layouts                             │
│  - Updates on HIGH/LAYOUT calls                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│        Plot Grouping                                        │
│  (base_r_plot_grouping.R)                                  │
│  - Groups HIGH + associated LOW calls                      │
│  - Separates LAYOUT calls                                  │
│  - Returns logical plot units                              │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│      Orchestrator                                           │
│  (base_r_plot_orchestrator.R)                              │
│  - Processes plot groups                                   │
│  - Creates grob trees via ggplotify                        │
│  - Generates MAIDR data                                    │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│            HTML Output                                      │
│  Interactive accessible visualization                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Function Classification (`base_r_function_classification.R`)

Categorizes 33 Base R plotting functions into three levels:

#### HIGH-level (16 functions)
Main plot creation functions that start a new plot:
- `barplot`, `plot`, `hist`, `boxplot`, `image`, `contour`, `matplot`
- `curve`, `dotchart`, `stripchart`, `stem`, `pie`
- `mosaicplot`, `assocplot`, `pairs`, `coplot`

#### LOW-level (14 functions)
Functions that add to existing plots:
- `lines`, `points`, `text`, `mtext`, `abline`, `segments`
- `arrows`, `polygon`, `rect`, `symbols`, `legend`, `axis`, `title`, `grid`

#### LAYOUT (3 functions)
Functions that configure canvas layout:
- `par` (specifically `par(mfrow)`)
- `layout`
- `split.screen`

**Key Function:**
```r
classify_function(function_name)
# Returns: "HIGH", "LOW", "LAYOUT", or "UNKNOWN"
```

### 2. Function Patching (`base_r_function_patching.R`)

**How It Works:**

1. **Initialization** (called in `.onLoad()`):
   ```r
   initialize_base_r_patching()
   ```
   - Wraps all 33 functions by replacing them in `.GlobalEnv`
   - Stores originals in `.maidr_patching_env$.saved_graphics_fns`

2. **Wrapper Pattern**:
   ```r
   wrapper <- function(...) {
     # Capture call and arguments
     this_call <- match.call()
     args_list <- list(...)
     
     # Execute original function FIRST
     result <- original_function(...)
     
     # Log AFTER execution (critical for device ID)
     device_id <- grDevices::dev.cur()
     log_plot_call_to_device(function_name, this_call, args_list, device_id)
     
     # Return result
     result
   }
   ```

**Why Execute First, Then Log?**

When a Base R plotting function like `barplot()` is called:
1. If no device is open, R opens a new one (e.g., device 2)
2. We need to capture which device was actually used
3. Therefore, we execute the function first, then check `dev.cur()`

### 3. Device-Scoped Storage (`base_r_device_storage.R`)

**Storage Structure:**
```r
.maidr_base_r_session$devices <- list(
  "2" = list(  # Device ID as key
    device_id = 2,
    calls = list(
      list(
        function_name = "barplot",
        args = list(...),
        call_expr = "barplot(...)",
        class_level = "HIGH",
        timestamp = <POSIXct>,
        device_id = 2
      ),
      ...
    ),
    metadata = list(
      created = <POSIXct>,
      call_count = 3
    ),
    state = list(...)  # See State Tracking
  ),
  "3" = list(...),  # Another device
  ...
)
```

**Key Functions:**
```r
# Storage operations
get_device_storage(device_id)
get_device_calls(device_id)
clear_device_storage(device_id)
has_device_calls(device_id)

# Filtering by classification
get_high_level_calls(device_id)
get_low_level_calls(device_id)
get_layout_calls(device_id)
```

**Device Isolation Benefits:**
- Multiple plots can be prepared on different devices
- No interference between devices
- Automatic cleanup per device

---

## Data Flow

### Step-by-Step Example

```r
# User code
library(maidr)

barplot(c(3, 5, 7), names.arg = c("A", "B", "C"))
lines(c(1, 2, 3), c(4, 6, 5), col = "red")
save_html(file = "output/plot.html")
```

**What Happens:**

1. **`barplot()` call**:
   - Wrapper executes `original_barplot(c(3,5,7), ...)`
   - Opens device 2, renders plot
   - `log_plot_call_to_device("barplot", ..., device_id=2)`
   - Stores: `{function_name: "barplot", class_level: "HIGH", ...}`
   - Triggers: `on_high_level_call(2, call_index=1)`
   - State updated: `current_plot_index = 1`

2. **`lines()` call**:
   - Wrapper executes `original_lines(...)`
   - Adds lines to device 2
   - `log_plot_call_to_device("lines", ..., device_id=2)`
   - Stores: `{function_name: "lines", class_level: "LOW", ...}`

3. **`save_html()` call**:
   - Adapter checks: `has_device_calls(2)` → TRUE
   - Creates orchestrator with `device_id=2`
   - Orchestrator calls `group_device_calls(2)`:
     ```r
     groups = list(
       list(
         high_call = <barplot call>,
         low_calls = list(<lines call>),
         ...
       )
     )
     ```
   - Processes group: creates single grob from both calls
   - Generates MAIDR data
   - Creates HTML
   - Clears device storage: `clear_device_storage(2)`

---

## Function Classification

### Implementation

```r
# From base_r_function_classification.R

classify_function <- function(function_name) {
  base_name <- sub("\\.default$", "", function_name)
  
  if (base_name %in% .base_r_function_classes$HIGH) {
    return("HIGH")
  } else if (base_name %in% .base_r_function_classes$LOW) {
    return("LOW")
  } else if (base_name %in% .base_r_function_classes$LAYOUT) {
    return("LAYOUT")
  }
  
  "UNKNOWN"
}
```

### Usage in Logging

```r
log_plot_call_to_device <- function(function_name, call_expr, args, device_id) {
  class_level <- classify_function(function_name)  # "HIGH", "LOW", or "LAYOUT"
  
  # Store with classification
  call_entry <- list(
    function_name = function_name,
    class_level = class_level,  # Added to each call
    ...
  )
  
  # Trigger state updates
  if (class_level == "HIGH") {
    on_high_level_call(device_id, call_index)
  } else if (class_level == "LAYOUT") {
    on_layout_call(device_id, function_name, args)
  }
}
```

---

## State Tracking

### State Structure (`base_r_state_tracking.R`)

Each device maintains state:
```r
state <- list(
  current_plot_index = 0,      # Number of HIGH calls
  panel_config = list(
    type = "single",            # or "mfrow", "layout"
    nrows = 1,
    ncols = 1,
    current_panel = 1,
    total_panels = 1,
    matrix = NULL               # For layout() only
  ),
  layout_active = FALSE,
  last_high_call_index = NULL
)
```

### Event Handlers

#### HIGH-level Call Handler
```r
on_high_level_call <- function(device_id, call_index) {
  state <- get_device_state(device_id)
  
  # Increment plot counter
  state$current_plot_index <- state$current_plot_index + 1
  state$last_high_call_index <- call_index
  
  # Update panel if multi-panel layout is active
  if (state$layout_active && state$panel_config$type != "single") {
    if (state$current_plot_index <= state$panel_config$total_panels) {
      state$panel_config$current_panel <- state$current_plot_index
    }
  }
  
  update_device_state(device_id, state)
}
```

#### LAYOUT Call Handler
```r
on_layout_call <- function(device_id, function_name, args) {
  state <- get_device_state(device_id)
  
  if (function_name == "par" && !is.null(args$mfrow)) {
    # par(mfrow = c(2, 2))
    mfrow <- args$mfrow
    state$panel_config <- list(
      type = "mfrow",
      nrows = mfrow[1],
      ncols = mfrow[2],
      current_panel = 0,
      total_panels = mfrow[1] * mfrow[2]
    )
    state$layout_active <- TRUE
    state$current_plot_index = 0
  } 
  else if (function_name == "layout") {
    # layout(matrix(...))
    mat <- args[[1]]
    if (is.matrix(mat)) {
      state$panel_config <- list(
        type = "layout",
        nrows = nrow(mat),
        ncols = ncol(mat),
        total_panels = length(unique(as.vector(mat))),
        matrix = mat
      )
      state$layout_active <- TRUE
      state$current_plot_index <- 0
    }
  }
  
  update_device_state(device_id, state)
}
```

---

## Plot Grouping

### Grouping Algorithm (`base_r_plot_grouping.R`)

```r
group_device_calls <- function(device_id) {
  all_calls <- get_device_calls(device_id)
  
  groups <- list()
  current_group <- NULL
  layout_calls <- list()
  
  for (call in all_calls) {
    if (call$class_level == "LAYOUT") {
      # Store separately
      layout_calls <- append(layout_calls, list(call))
    }
    else if (call$class_level == "HIGH") {
      # Start new group
      if (!is.null(current_group)) {
        groups <- append(groups, list(current_group))
      }
      current_group <- list(
        high_call = call,
        low_calls = list(),
        ...
      )
    }
    else if (call$class_level == "LOW") {
      # Add to current group
      if (!is.null(current_group)) {
        current_group$low_calls <- append(current_group$low_calls, list(call))
      }
    }
  }
  
  # Don't forget the last group
  if (!is.null(current_group)) {
    groups <- append(groups, list(current_group))
  }
  
  return(list(
    groups = groups,
    layout_calls = layout_calls
  ))
}
```

### Group Structure

```r
group <- list(
  high_call = list(
    function_name = "barplot",
    args = list(...),
    class_level = "HIGH",
    ...
  ),
  high_call_index = 1,
  low_calls = list(
    list(function_name = "lines", class_level = "LOW", ...),
    list(function_name = "points", class_level = "LOW", ...)
  ),
  low_call_indices = c(2, 3),
  panel_info = NULL
)
```

---

## Orchestrator Integration

### Initialization (`base_r_plot_orchestrator.R`)

```r
initialize <- function(device_id) {
  # Get calls from device
  private$.plot_calls <- get_device_calls(device_id)
  
  # Group into logical units
  grouped <- group_device_calls(device_id)
  private$.plot_groups <- grouped$groups
  
  # Process each group as a layer
  self$detect_layers()      # One layer per group
  self$create_layer_processors()
  self$process_layers()
}
```

### Creating Grobs from Groups

```r
get_gtable <- function() {
  grob_list <- list()
  
  for (i in seq_along(private$.plot_groups)) {
    group <- private$.plot_groups[[i]]
    high_call <- group$high_call
    low_calls <- group$low_calls
    
    # Create function that replays BOTH high and low calls
    plot_func <- function() {
      # Execute HIGH-level call
      do.call(high_call$function_name, high_call$args)
      
      # Execute LOW-level calls in order
      if (length(low_calls) > 0) {
        for (low_call in low_calls) {
          do.call(low_call$function_name, low_call$args)
        }
      }
    }
    
    # Convert to grob
    grob <- ggplotify::as.grob(plot_func)
    grob_list[[i]] <- grob
  }
  
  return(grob_list[[1]])  # Return first as main
}
```

**Key Insight:** By replaying both HIGH and LOW calls together, we create a single grob that contains the complete multi-layer plot.

---

## Debugging Guide

### Enable Verbose Mode

To add logging for debugging (temporary):

```r
# In base_r_device_storage.R
log_plot_call_to_device <- function(...) {
  message("[DEBUG] Device ", device_id, ": ", function_name, " [", class_level, "]")
  # ... rest of function
}
```

### Check Device Storage

```r
# Get current device ID
dev.cur()

# Check if device has calls
has_device_calls(dev.cur())

# Inspect calls
calls <- get_device_calls(dev.cur())
str(calls)

# Get summary
summary <- get_device_storage_summary()
print(summary)
```

### Inspect Groups

```r
# Get groups
groups <- get_all_plot_groups(dev.cur())

# Check group structure
for (i in seq_along(groups)) {
  cat("Group", i, ":\n")
  cat("  HIGH:", groups[[i]]$high_call$function_name, "\n")
  cat("  LOW:", length(groups[[i]]$low_calls), "calls\n")
}
```

### Check State

```r
# Get device state
state <- get_device_state(dev.cur())
str(state)

# Check if multi-panel
is_multipanel_active(dev.cur())

# Get panel config
panel_config <- get_panel_config(dev.cur())
print(panel_config)
```

### Trace Call Flow

```r
# 1. Create plot
barplot(c(3, 5, 7))

# 2. Check storage
cat("Calls:", length(get_device_calls(dev.cur())), "\n")

# 3. Check classification
calls <- get_device_calls(dev.cur())
cat("Classification:", calls[[1]]$class_level, "\n")

# 4. Check state
state <- get_device_state(dev.cur())
cat("Plot index:", state$current_plot_index, "\n")

# 5. Check groups
groups <- get_all_plot_groups(dev.cur())
cat("Groups:", length(groups), "\n")
```

---

## Troubleshooting

### Issue: Calls Not Being Captured

**Symptoms:** `has_device_calls()` returns FALSE after plotting

**Possible Causes:**
1. Patching not initialized
2. Wrong device ID
3. Function not in patch list

**Solutions:**
```r
# Check patching is active
is_patching_active()

# Check device ID matches
cat("Current device:", dev.cur(), "\n")

# Manually check storage
str(.maidr_base_r_session$devices)

# Reinitialize patching
initialize_base_r_patching()
```

### Issue: Calls Accumulating Across Plots

**Symptoms:** Second plot includes data from first plot

**Cause:** Device storage not cleared after save_html()

**Solution:**
```r
# Manual clear if needed
clear_device_storage(dev.cur())

# Check clear is called in save_html():
# Should have: clear_device_storage(device_id) after HTML generation
```

### Issue: Multi-layer Not Grouping

**Symptoms:** Lines appear as separate plot instead of with barplot

**Diagnosis:**
```r
# Check groups
groups <- get_all_plot_groups(dev.cur())
cat("Expected: 1 group\n")
cat("Actual:", length(groups), "groups\n")

# Check LOW call classification
calls <- get_device_calls(dev.cur())
for (call in calls) {
  cat(call$function_name, "->", call$class_level, "\n")
}
```

**Solution:**
- Ensure `lines()` is classified as "LOW"
- Ensure `lines()` called AFTER `barplot()`
- Check grouping algorithm logic

### Issue: Wrong Device ID

**Symptoms:** Calls logged to different device than expected

**Cause:** Device opens during function execution

**Solution:**
- This is expected behavior
- Device ID is captured AFTER function execution
- Use `dev.cur()` to check active device

### Issue: Multi-panel Not Detected

**Symptoms:** `par(mfrow)` not creating panels

**Diagnosis:**
```r
# Check layout calls
grouped <- group_device_calls(dev.cur())
cat("Layout calls:", length(grouped$layout_calls), "\n")

# Check state
state <- get_device_state(dev.cur())
print(state$panel_config)

# Check if active
is_multipanel_active(dev.cur())
```

**Solution:**
- Ensure `par(mfrow=...)` called BEFORE plots
- Check `on_layout_call()` is triggered
- Verify `args$mfrow` is not NULL

---

## Advanced Topics

### Adding New Functions to Patch

1. **Classify the function:**
   ```r
   # In base_r_function_classification.R
   .base_r_function_classes$HIGH <- c(
     .base_r_function_classes$HIGH,
     "your_new_function"
   )
   ```

2. **Function will be automatically patched** on next `initialize_base_r_patching()`

3. **Add layer processor if needed:**
   ```r
   # In base_r_processor_factory.R
   create_processor <- function(layer_type, layer_info) {
     if (layer_type == "your_type") {
       return(YourLayerProcessor$new())
     }
     ...
   }
   ```

### Custom Grouping Logic

To modify how calls are grouped:

```r
# In base_r_plot_grouping.R
group_device_calls <- function(device_id) {
  # Custom logic here
  # Example: Group by time window
  # Example: Group by panel
  # Example: Group by custom metadata
}
```

### Performance Considerations

- Device storage is in-memory: cleared after each `save_html()`
- Grob creation can be slow for complex plots
- Consider caching grobs if reprocessing same plot

---

## Summary

The Base R Patching System provides a robust, extensible framework for intercepting and processing Base R plots:

✅ **Device-isolated** - No interference between devices  
✅ **Classification-based** - Automatic categorization of functions  
✅ **State-aware** - Tracks plot index and panel configuration  
✅ **Group-based** - Logically groups related calls  
✅ **Clean** - No call accumulation, automatic cleanup  

For LLMs and developers: This system is designed to be easily understood and extended. Each component has a single responsibility, and the data flow is linear and predictable.

