# Base R Multipanel Plot Implementation

## Overview
This document describes the implementation of multipanel (faceted) plot support in Base R for the MAIDR system. The implementation detects and processes plots created with `par(mfrow)`, `par(mfcol)`, and layout configurations.

## Architecture

### Detection Flow
```
par(mfrow/mfcol) → plot() calls → Device Storage → Orchestrator → Composite Grob → SVG/HTML
```

### Key Components

1. **Panel Detection** (`R/base_r_utils.R`)
   - `detect_panel_configuration()` - Detects mfrow/mfcol settings
   - Returns panel type, nrows, ncols

2. **Orchestrator** (`R/base_r_plot_orchestrator.R`)
   - Modified to handle multipanel layouts
   - Creates composite grob for all panels
   - Organizes data as 2D grid structure

3. **Layer Processors**
   - Use `group_index` instead of `layer_index` for multipanel selectors
   - Share composite grob across all layers

## Implementation Details

### 1. Panel Configuration Detection

```r
detect_panel_configuration <- function(device_id = dev.cur()) {
  # Returns:
  # - type: "mfrow" or "mfcol"
  # - nrows: number of rows
  # - ncols: number of columns
}
```

### 2. Composite Grob Generation

The orchestrator's `get_gtable()` method creates a single composite grob containing all panels:

```r
get_gtable = function() {
  panel_config <- detect_panel_configuration(private$.device_id)

  if (!is.null(panel_config) &&
      panel_config$type %in% c("mfrow", "mfcol") &&
      (panel_config$nrows > 1 || panel_config$ncols > 1)) {

    # Create composite grob function
    composite_func <- function() {
      # Set panel configuration
      par(mfrow = c(panel_config$nrows, panel_config$ncols))

      # Replay all plot groups
      for (group in private$.plot_groups) {
        invisible(do.call(group$high_call$function_name,
                         group$high_call$args))
        # Replay low-level calls if any
      }
    }

    # Convert to grob
    composite_grob <- ggplotify::as.grob(composite_func)
    return(composite_grob)
  }
}
```

### 3. Data Structure Organization

The `combine_layer_results()` method organizes data as a 2D grid matching the panel layout:

```r
combine_layer_results = function(layer_results) {
  panel_config <- detect_panel_configuration(private$.device_id)

  if (multipanel) {
    # Initialize 2D grid
    subplot_grid <- vector("list", nrows)
    for (r in seq_len(nrows)) {
      subplot_grid[[r]] <- vector("list", ncols)
    }

    # Map layers to panels
    for (layer in layers) {
      # Calculate position (row-major for mfrow, column-major for mfcol)
      if (panel_config$type == "mfrow") {
        row <- ceiling(group_idx / ncols)
        col <- ((group_idx - 1) %% ncols) + 1
      } else {
        col <- ceiling(group_idx / nrows)
        row <- ((group_idx - 1) %% nrows) + 1
      }

      # Add layer to subplot
      subplot_grid[[row]][[col]]$layers <- append(...)
    }

    private$.combined_data <- subplot_grid
  }
}
```

### 4. Selector Generation

Layer processors use `group_index` for multipanel layouts to ensure correct panel numbering:

```r
generate_selectors = function(layer_info, gt) {
  # Use group_index for multipanel, layer_index for single panel
  selector_index <- if (!is.null(layer_info$group_index)) {
    layer_info$group_index
  } else {
    layer_info$index
  }

  # Generate selectors with panel-specific numbering
  selectors <- sprintf("graphics-plot-%d-*", selector_index)
}
```

## Data Format

### Output Structure
```javascript
{
  "id": "maidr-plot-...",
  "subplots": [
    [
      {
        "id": "maidr-subplot-1-1",
        "layers": [...]
      },
      {
        "id": "maidr-subplot-1-2",
        "layers": [...]
      }
    ],
    [
      {
        "id": "maidr-subplot-2-1",
        "layers": [...]
      },
      {
        "id": "maidr-subplot-2-2",
        "layers": [...]
      }
    ]
  ]
}
```

## Panel Ordering

- **mfrow**: Row-major order (fills rows first)
  - Panel 1 → (1,1), Panel 2 → (1,2), Panel 3 → (2,1), etc.

- **mfcol**: Column-major order (fills columns first)
  - Panel 1 → (1,1), Panel 2 → (2,1), Panel 3 → (1,2), etc.

## Key Implementation Points

1. **Unified Grob**: All panels share a single composite grob
2. **Group Index**: Each plot group corresponds to a panel position
3. **Replay Mechanism**: Plots are replayed with `invisible(do.call())` to suppress output
4. **Device Isolation**: Storage is cleared after each `save_html()` call
5. **2D Grid Structure**: Matches ggplot2 patchwork format for consistency

## Usage Example

```r
# Create multipanel plot
par(mfrow = c(2, 2))

plot(1:10, 1:10, main = "Panel 1")
barplot(c(5, 10, 15), main = "Panel 2")
plot(1:10, log(1:10), type = "l", main = "Panel 3")
plot(1:10, sqrt(1:10), main = "Panel 4")

# Save as accessible HTML
maidr::save_html(file = "multipanel.html")
```

## Files Modified for Multipanel Support

1. **`R/base_r_plot_orchestrator.R`**
   - Added multipanel detection in `get_gtable()`
   - Modified `combine_layer_results()` for 2D grid
   - Updated `get_grob_for_layer()` for composite grob

2. **`R/base_r_barplot_layer_processor.R`**
   - Modified selector generation to use `group_index`

3. **`R/base_r_plot_layer_processor.R`**
   - Modified selector generation to use `group_index`

4. **`R/base_r_dodged_bar_layer_processor.R`**
   - Modified selector generation to use `group_index`

## Technical Considerations

1. **Grob Conversion**: Uses `ggplotify::as.grob()` to convert Base R plots to grid objects
2. **Selector Mapping**: Panel-specific selectors use plot group index
3. **Memory Management**: Device storage cleared after processing
4. **Compatibility**: Works with existing single-panel infrastructure

## Testing Approach

```r
# Test different layouts
layouts <- list(
  c(2, 2),  # 2x2 grid
  c(3, 2),  # 3x2 grid
  c(2, 3),  # 2x3 grid
  c(1, 3),  # 1x3 horizontal
  c(3, 1)   # 3x1 vertical
)

for (layout in layouts) {
  par(mfrow = layout)
  # Create plots...
  save_html(file = sprintf("test_%dx%d.html", layout[1], layout[2]))
}
```