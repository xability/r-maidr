# Base R Multi-Layer Implementation Plan

## Overview

Implement multi-layer support for Base R plots (e.g., histogram + density curve) following ggplot2's proven architecture pattern.

**Key Insight from ggplot2**: 
- Create ONE unified grob tree containing ALL layers upfront
- Pass the SAME grob tree to ALL processors
- Each processor searches the unified grob for its specific elements

---

## Phase 1: Enhance Adapter to Detect LOW-Level Function Types

### 1.1 Modify `BaseRAdapter$detect_layer_type()`

**File:** `R/base_r_adapter.R`

**Current Limitation:** Only detects HIGH-level functions (barplot, hist, etc.)

**Enhancement:** Add detection for LOW-level functions

```r
detect_layer_type = function(layer, plot_object = NULL) {
  if (is.null(layer)) {
    return("unknown")
  }

  function_name <- layer$function_name
  args <- layer$args

  # HIGH-level function detection (EXISTING)
  layer_type <- switch(function_name,
    "barplot" = {
      if (self$is_dodged_barplot(args)) {
        "dodged_bar"
      } else if (self$is_stacked_barplot(args)) {
        "stacked_bar"
      } else {
        "bar"
      }
    },
    "hist" = "hist",
    "plot" = {
      first_arg <- args[[1]]
      if (!is.null(first_arg) && inherits(first_arg, "density")) {
        "smooth"
      } else {
        "line"
      }
    },
    "boxplot" = "box",
    NULL  # Continue to LOW-level detection
  )
  
  if (!is.null(layer_type)) {
    return(layer_type)
  }
  
  # LOW-level function detection (NEW)
  if (function_name == "lines") {
    # Check if first argument is a density object
    first_arg <- args[[1]]
    if (!is.null(first_arg) && inherits(first_arg, "density")) {
      return("smooth")  # Density curve
    }
    return("line")  # Regular line
  }
  
  if (function_name == "points") {
    return("point")
  }
  
  if (function_name == "abline") {
    return("line")
  }
  
  if (function_name == "polygon") {
    return("polygon")
  }
  
  return("unknown")
}
```

### Phase 1 Test Case

**File:** `tests/test_base_r_adapter_multilayer.R`

```r
test_that("BaseRAdapter detects LOW-level function types correctly", {
  adapter <- BaseRAdapter$new()
  
  # Test lines(density(...))
  density_obj <- density(rnorm(100))
  density_call <- list(
    function_name = "lines",
    args = list(density_obj, col = "red")
  )
  expect_equal(adapter$detect_layer_type(density_call), "smooth")
  
  # Test regular lines()
  regular_lines_call <- list(
    function_name = "lines",
    args = list(x = 1:10, y = 1:10)
  )
  expect_equal(adapter$detect_layer_type(regular_lines_call), "line")
  
  # Test points()
  points_call <- list(
    function_name = "points",
    args = list(x = 1:10, y = 1:10)
  )
  expect_equal(adapter$detect_layer_type(points_call), "point")
})
```

**Test Command:**
```r
devtools::load_all()
testthat::test_file("tests/test_base_r_adapter_multilayer.R")
```

**Success Criteria:**
- ✅ `lines(density(...))` detected as "smooth"
- ✅ `lines(x, y)` detected as "line"
- ✅ `points(x, y)` detected as "point"

---

## Phase 2: Expand Plot Groups into Multiple Layers

### 2.1 Modify `BaseRPlotOrchestrator$detect_layers()`

**File:** `R/base_r_plot_orchestrator.R`

**Current Behavior:** Creates one layer per plot group (HIGH call only)

**New Behavior:** Create multiple layers (HIGH + each LOW call)

```r
detect_layers = function() {
  plot_groups <- private$.plot_groups
  private$.layers <- list()
  
  if (length(plot_groups) == 0) {
    return(invisible(NULL))
  }
  
  layer_counter <- 0
  
  for (group_idx in seq_along(plot_groups)) {
    group <- plot_groups[[group_idx]]
    high_call <- group$high_call
    
    # LAYER 1: HIGH-level call
    layer_counter <- layer_counter + 1
    high_layer_type <- private$.adapter$detect_layer_type(high_call)
    
    private$.layers[[layer_counter]] <- list(
      index = layer_counter,
      type = high_layer_type,
      function_name = high_call$function_name,
      args = high_call$args,
      call_expr = high_call$call_expr,
      plot_call = high_call,
      group = group,
      group_index = group_idx,
      source = "HIGH"
    )
    
    # LAYERS 2+: LOW-level calls (NEW)
    if (length(group$low_calls) > 0) {
      for (low_idx in seq_along(group$low_calls)) {
        low_call <- group$low_calls[[low_idx]]
        low_layer_type <- private$.adapter$detect_layer_type(low_call)
        
        # Only create layer if we can identify its type
        if (low_layer_type != "unknown") {
          layer_counter <- layer_counter + 1
          
          private$.layers[[layer_counter]] <- list(
            index = layer_counter,
            type = low_layer_type,
            function_name = low_call$function_name,
            args = low_call$args,
            call_expr = low_call$call_expr,
            plot_call = low_call,
            group = group,
            group_index = group_idx,
            source = "LOW",
            low_call_index = low_idx
          )
        }
      }
    }
  }
}
```

### Phase 2 Test Case

**File:** `tests/test_base_r_orchestrator_layers.R`

```r
test_that("Orchestrator expands plot groups into multiple layers", {
  # Setup: Create histogram + density curve
  set.seed(123)
  data <- rnorm(100, mean = 5, sd = 2)
  
  hist(data, probability = TRUE, main = "Test")
  lines(density(data), col = "red")
  
  device_id <- grDevices::dev.cur()
  orchestrator <- BaseRPlotOrchestrator$new(device_id = device_id)
  
  layers <- orchestrator$get_layers()
  
  # Should have 2 layers
  expect_equal(length(layers), 2)
  
  # Layer 1: Histogram (HIGH)
  expect_equal(layers[[1]]$type, "hist")
  expect_equal(layers[[1]]$source, "HIGH")
  expect_equal(layers[[1]]$function_name, "hist")
  
  # Layer 2: Density (LOW)
  expect_equal(layers[[2]]$type, "smooth")
  expect_equal(layers[[2]]$source, "LOW")
  expect_equal(layers[[2]]$function_name, "lines")
  
  # Both should belong to same group
  expect_equal(layers[[1]]$group_index, layers[[2]]$group_index)
  
  # Clean up
  clear_device_storage(device_id)
})
```

**Test Command:**
```r
devtools::load_all()
testthat::test_file("tests/test_base_r_orchestrator_layers.R")
```

**Success Criteria:**
- ✅ 2 layers created from hist() + lines(density())
- ✅ Layer 1: type="hist", source="HIGH"
- ✅ Layer 2: type="smooth", source="LOW"
- ✅ Both layers reference same group

---

## Phase 3: Create Unified Grob Tree

### 3.1 Modify `BaseRPlotOrchestrator$get_gtable()`

**Key Change:** Create ONE grob per group (not per layer), store by group_index

**File:** `R/base_r_plot_orchestrator.R`

```r
get_gtable = function() {
  if (length(private$.plot_groups) == 0) {
    return(NULL)
  }
  
  # Create ONE grob per plot GROUP (not per layer)
  grob_by_group <- list()
  
  for (group_idx in seq_along(private$.plot_groups)) {
    group <- private$.plot_groups[[group_idx]]
    high_call <- group$high_call
    low_calls <- group$low_calls
    
    # Create function that executes ALL calls in the group
    plot_func <- function() {
      # Execute HIGH-level call
      do.call(high_call$function_name, high_call$args)
      
      # Execute ALL LOW-level calls
      if (length(low_calls) > 0) {
        for (low_call in low_calls) {
          do.call(low_call$function_name, low_call$args)
        }
      }
    }
    
    # Convert to grob using ggplotify
    tryCatch(
      {
        grob <- ggplotify::as.grob(plot_func)
        grob_by_group[[group_idx]] <- grob
      },
      error = function(e) {
        grob_by_group[[group_idx]] <- NULL
      }
    )
  }
  
  # Store grobs indexed by group
  private$.grob_by_group <- grob_by_group
  
  # Return first grob as main gtable
  if (length(grob_by_group) > 0 && !is.null(grob_by_group[[1]])) {
    return(grob_by_group[[1]])
  }
  
  return(NULL)
}
```

### 3.2 Modify `get_grob_for_layer()`

**File:** `R/base_r_plot_orchestrator.R`

```r
get_grob_for_layer = function(layer_index) {
  if (layer_index < 1 || layer_index > length(private$.layers)) {
    return(NULL)
  }
  
  # Get layer info
  layer <- private$.layers[[layer_index]]
  group_idx <- layer$group_index
  
  # Ensure grobs are created
  if (length(private$.grob_by_group) == 0) {
    self$get_gtable()
  }
  
  # Return grob for this layer's group
  # CRITICAL: All layers in same group get the SAME grob
  if (group_idx <= length(private$.grob_by_group)) {
    return(private$.grob_by_group[[group_idx]])
  }
  
  return(NULL)
}
```

### Phase 3 Test Case

**File:** `tests/test_base_r_unified_grob.R`

```r
test_that("Unified grob contains all layer elements", {
  # Setup: Create histogram + density curve
  set.seed(123)
  data <- rnorm(100, mean = 5, sd = 2)
  
  hist(data, probability = TRUE, main = "Test")
  lines(density(data), col = "red")
  
  device_id <- grDevices::dev.cur()
  orchestrator <- BaseRPlotOrchestrator$new(device_id = device_id)
  
  # Get the unified grob
  gt <- orchestrator$get_gtable()
  
  # Verify grob is not NULL
  expect_false(is.null(gt))
  
  # Helper function to search grob tree
  find_grobs_by_pattern <- function(grob, pattern) {
    results <- character(0)
    
    if (!is.null(grob$name) && grepl(pattern, grob$name)) {
      results <- c(results, grob$name)
    }
    
    if (inherits(grob, "gTree") && !is.null(grob$children)) {
      for (child in grob$children) {
        results <- c(results, find_grobs_by_pattern(child, pattern))
      }
    }
    
    if (inherits(grob, "gList")) {
      for (item in grob) {
        results <- c(results, find_grobs_by_pattern(item, pattern))
      }
    }
    
    return(results)
  }
  
  # Verify grob contains BOTH rect (histogram) and polyline (density)
  rect_grobs <- find_grobs_by_pattern(gt, "rect")
  polyline_grobs <- find_grobs_by_pattern(gt, "polyline")
  
  expect_true(length(rect_grobs) > 0, "Grob should contain histogram rectangles")
  expect_true(length(polyline_grobs) > 0, "Grob should contain density polyline")
  
  # Verify both layers get same grob
  grob_layer1 <- orchestrator$get_grob_for_layer(1)
  grob_layer2 <- orchestrator$get_grob_for_layer(2)
  
  expect_identical(grob_layer1, grob_layer2, "Both layers should share same grob")
  
  # Clean up
  clear_device_storage(device_id)
})
```

**Test Command:**
```r
devtools::load_all()
testthat::test_file("tests/test_base_r_unified_grob.R")
```

**Success Criteria:**
- ✅ Single grob created containing all elements
- ✅ Grob contains rect elements (histogram)
- ✅ Grob contains polyline elements (density)
- ✅ Both layers receive same grob reference

---

## Phase 4: Update Processors to Search Unified Grob

### 4.1 Update `BaseRHistogramLayerProcessor`

**File:** `R/base_r_histogram_layer_processor.R`

**Current:** Searches for specific rect grobs by call index

**Enhanced:** Search unified grob tree for ALL rect grobs, filter by pattern

```r
generate_selectors = function(layer_info, gt = NULL) {
  selectors <- list()
  
  if (is.null(gt)) {
    return(selectors)
  }
  
  # Recursively find ALL rect grobs in the tree
  find_rect_grobs <- function(grob) {
    rect_names <- character(0)
    
    # Check current grob
    if (!is.null(grob$name) && grepl("rect", grob$name, ignore.case = TRUE)) {
      rect_names <- c(rect_names, grob$name)
    }
    
    # Search children
    if (inherits(grob, "gTree") && !is.null(grob$children)) {
      for (child in grob$children) {
        rect_names <- c(rect_names, find_rect_grobs(child))
      }
    }
    
    if (inherits(grob, "gList")) {
      for (item in grob) {
        rect_names <- c(rect_names, find_rect_grobs(item))
      }
    }
    
    return(rect_names)
  }
  
  # Find all rect grobs
  rect_names <- find_rect_grobs(gt)
  
  if (length(rect_names) == 0) {
    return(selectors)
  }
  
  # Generate selectors
  # For histogram, we want the FIRST set of rects (not density polygon)
  for (name in rect_names) {
    svg_id <- paste0(name, ".1")
    escaped <- gsub("\\.", "\\\\.", svg_id)
    selector <- paste0("#", escaped, " rect")
    selectors <- append(selectors, list(selector))
  }
  
  # Return first selector (histogram bars)
  if (length(selectors) > 0) {
    return(list(selectors[[1]]))
  }
  
  return(list())
}
```

### 4.2 Enhance `BaseRSmoothLayerProcessor`

**File:** `R/base_r_smooth_layer_processor.R`

**Current:** May not handle density objects properly

**Enhanced:** Extract density data and search for polyline grobs

```r
extract_data = function(layer_info) {
  if (is.null(layer_info)) {
    return(list())
  }
  
  plot_call <- layer_info$plot_call
  args <- plot_call$args
  
  # Get first argument - should be density object
  density_obj <- args[[1]]
  
  # Handle density object
  if (!is.null(density_obj) && inherits(density_obj, "density")) {
    # Extract x and y from density
    data_points <- list()
    
    for (i in seq_along(density_obj$x)) {
      data_points[[i]] <- list(
        x = round(density_obj$x[i], 4),
        y = round(density_obj$y[i], 4)
      )
    }
    
    # Return as nested list (one line series)
    return(list(data_points))
  }
  
  # Fallback: try to extract from arguments
  x <- args$x
  y <- args$y
  
  if (!is.null(x) && !is.null(y)) {
    data_points <- list()
    for (i in seq_along(x)) {
      data_points[[i]] <- list(x = x[i], y = y[i])
    }
    return(list(data_points))
  }
  
  return(list())
}

generate_selectors = function(layer_info, gt = NULL) {
  selectors <- list()
  
  if (is.null(gt)) {
    return(selectors)
  }
  
  # Recursively find ALL polyline grobs
  find_polyline_grobs <- function(grob) {
    polyline_names <- character(0)
    
    # Check current grob
    if (!is.null(grob$name) && grepl("polyline", grob$name, ignore.case = TRUE)) {
      polyline_names <- c(polyline_names, grob$name)
    }
    
    # Search children
    if (inherits(grob, "gTree") && !is.null(grob$children)) {
      for (child in grob$children) {
        polyline_names <- c(polyline_names, find_polyline_grobs(child))
      }
    }
    
    if (inherits(grob, "gList")) {
      for (item in grob) {
        polyline_names <- c(polyline_names, find_polyline_grobs(item))
      }
    }
    
    return(polyline_names)
  }
  
  # Find all polyline grobs
  polyline_names <- find_polyline_grobs(gt)
  
  if (length(polyline_names) == 0) {
    return(selectors)
  }
  
  # For density curve, typically want the LAST polyline
  # (similar to ggplot2's geom_smooth pattern)
  target_name <- polyline_names[length(polyline_names)]
  
  svg_id <- paste0(target_name, ".1")
  escaped <- gsub("\\.", "\\\\.", svg_id)
  selector <- paste0("#", escaped)
  
  return(list(selector))
}
```

### Phase 4 Test Case

**File:** `tests/test_base_r_processor_selectors.R`

```r
test_that("Processors generate correct selectors from unified grob", {
  # Setup: Create histogram + density curve
  set.seed(123)
  data <- rnorm(100, mean = 5, sd = 2)
  
  hist(data, probability = TRUE, main = "Test", col = "lightblue")
  lines(density(data), col = "red", lwd = 2)
  
  device_id <- grDevices::dev.cur()
  orchestrator <- BaseRPlotOrchestrator$new(device_id = device_id)
  
  # Get processors
  processors <- orchestrator$get_layer_processors()
  
  expect_equal(length(processors), 2)
  
  # Get unified grob
  gt <- orchestrator$get_gtable()
  
  # Test Layer 1: Histogram processor
  hist_processor <- processors[[1]]
  hist_result <- hist_processor$get_last_result()
  
  expect_equal(hist_result$type, "hist")
  expect_true(length(hist_result$selectors) > 0)
  expect_true(grepl("rect", hist_result$selectors[[1]]))
  
  # Test Layer 2: Smooth processor
  smooth_processor <- processors[[2]]
  smooth_result <- smooth_processor$get_last_result()
  
  expect_equal(smooth_result$type, "smooth")
  expect_true(length(smooth_result$selectors) > 0)
  expect_true(grepl("polyline", smooth_result$selectors[[1]]))
  
  # Verify selectors are different
  expect_false(hist_result$selectors[[1]] == smooth_result$selectors[[1]])
  
  # Clean up
  clear_device_storage(device_id)
})
```

**Test Command:**
```r
devtools::load_all()
testthat::test_file("tests/test_base_r_processor_selectors.R")
```

**Success Criteria:**
- ✅ Histogram processor finds rect selectors
- ✅ Smooth processor finds polyline selectors
- ✅ Selectors are different for each layer
- ✅ Both processors work with same unified grob

---

## Phase 5: Integration Testing

### 5.1 End-to-End Test

**File:** `tests/test_base_r_multilayer_integration.R`

```r
test_that("Complete multilayer flow works end-to-end", {
  # Create histogram + density curve
  set.seed(123)
  data <- rnorm(150, mean = 3.8, sd = 1.8)
  
  hist(data, probability = TRUE, 
       col = "lightblue", border = "black",
       main = "Histogram with Density Curve",
       xlab = "Value", ylab = "Density")
  
  lines(density(data), col = "red", lwd = 2)
  
  # Generate MAIDR data
  device_id <- grDevices::dev.cur()
  orchestrator <- BaseRPlotOrchestrator$new(device_id = device_id)
  maidr_data <- orchestrator$generate_maidr_data()
  
  # Verify structure
  expect_true("id" %in% names(maidr_data))
  expect_true("subplots" %in% names(maidr_data))
  expect_equal(length(maidr_data$subplots), 1)
  
  subplot <- maidr_data$subplots[[1]][[1]]
  layers <- subplot$layers
  
  # Should have 2 layers
  expect_equal(length(layers), 2)
  
  # Layer 1: Histogram
  layer1 <- layers[[1]]
  expect_equal(layer1$type, "hist")
  expect_true(length(layer1$data) > 0)
  expect_true(length(layer1$selectors) > 0)
  expect_true("xMin" %in% names(layer1$data[[1]]))
  expect_true("xMax" %in% names(layer1$data[[1]]))
  
  # Layer 2: Density
  layer2 <- layers[[2]]
  expect_equal(layer2$type, "smooth")
  expect_true(length(layer2$data) > 0)
  expect_true(length(layer2$selectors) > 0)
  expect_true(is.list(layer2$data[[1]]))  # Nested list for line
  
  # Clean up
  clear_device_storage(device_id)
})
```

### 5.2 HTML Generation Test

**File:** `examples/test_multilayer_base_r.R`

```r
library(maidr)

# Create output directory
output_dir <- "output"
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

# Example: Histogram + Density Curve
set.seed(123)
petal_lengths <- rnorm(150, mean = 3.8, sd = 1.8)

hist(petal_lengths, probability = TRUE, 
     col = "lightblue", border = "black",
     main = "Petal Lengths with Density Curve",
     xlab = "Petal Length (cm)", 
     ylab = "Density")

lines(density(petal_lengths), col = "red", lwd = 2)

# Generate HTML
html_file <- file.path(output_dir, "test_hist_density_base_r.html")
save_html(file = html_file)

cat("Generated:", html_file, "\n")

# Verify file exists
if (file.exists(html_file)) {
  cat("✓ HTML file created successfully\n")
  
  # Read and check MAIDR data
  html_content <- readLines(html_file, warn = FALSE)
  maidr_line <- grep("maidr-data=", html_content, value = TRUE)[1]
  
  if (!is.na(maidr_line)) {
    cat("✓ MAIDR data found in HTML\n")
    
    # Extract and parse
    require(jsonlite)
    require(htmltools)
    
    maidr_json <- sub('.*maidr-data="([^"]*)".*', '\\1', maidr_line)
    maidr_json <- htmltools::htmlUnescape(maidr_json)
    maidr_data <- jsonlite::fromJSON(maidr_json)
    
    layers <- maidr_data$subplots[[1]][[1]]$layers
    
    cat("✓ Found", length(layers), "layers\n")
    cat("  Layer 1 type:", layers[[1]]$type, "\n")
    cat("  Layer 2 type:", layers[[2]]$type, "\n")
  }
} else {
  cat("✗ HTML file not created\n")
}
```

**Test Command:**
```r
devtools::load_all()
source("examples/test_multilayer_base_r.R")
```

**Success Criteria:**
- ✅ HTML file created successfully
- ✅ MAIDR data contains 2 layers
- ✅ Layer 1: type="hist" with histogram data
- ✅ Layer 2: type="smooth" with density data
- ✅ Both layers have valid selectors
- ✅ SVG contains both histogram and density curve elements

---

## Testing Strategy

### Unit Tests (Per Phase)
```bash
# Run all Base R multilayer tests
devtools::load_all()
testthat::test_dir("tests", filter = "base_r_.*multilayer")
```

### Integration Test
```bash
# Run complete integration test
devtools::load_all()
testthat::test_file("tests/test_base_r_multilayer_integration.R")
```

### Manual Verification
```bash
# Generate example and inspect
devtools::load_all()
source("examples/test_multilayer_base_r.R")

# Open in browser and test interactivity
```

---

## Success Metrics

### Phase Completion Checklist

- [ ] **Phase 1**: Adapter detects LOW-level types correctly
- [ ] **Phase 2**: Orchestrator creates multiple layers
- [ ] **Phase 3**: Unified grob contains all elements
- [ ] **Phase 4**: Processors generate correct selectors
- [ ] **Phase 5**: Complete flow produces valid MAIDR structure

### Final Validation

- [ ] MAIDR data has correct structure (2 layers)
- [ ] Histogram layer has bin data with xMin/xMax
- [ ] Density layer has smooth curve data
- [ ] Selectors target correct SVG elements
- [ ] HTML renders both layers visibly
- [ ] Interactive features work for both layers

---

## Rollback Plan

If issues arise, phases can be rolled back independently:

1. **Phase 5 failure**: Check MAIDR data structure
2. **Phase 4 failure**: Verify grob tree structure, check processor logic
3. **Phase 3 failure**: Verify grob contains all elements
4. **Phase 2 failure**: Check layer detection logic
5. **Phase 1 failure**: Verify adapter function type detection

Each phase has isolated test cases for debugging.

---

## Next Steps After Implementation

1. **Add more LOW-level types**: points, polygon, abline, etc.
2. **Support complex combinations**: barplot + lines + points
3. **Handle edge cases**: Empty density, invalid arguments
4. **Performance optimization**: Cache grob searches
5. **Documentation**: Update user guide with multilayer examples

