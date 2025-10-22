#!/usr/bin/env Rscript

# Test Base R Smooth/Density Processor
# This tests the layer processor implementation
# Phase 2: Data extraction and selector generation

library(devtools)

# Get the directory where this script is located
script_path <- commandArgs(trailingOnly = FALSE)
script_file <- sub("--file=", "", script_path[grep("--file=", script_path)])
if (length(script_file) > 0) {
  script_dir <- dirname(normalizePath(script_file))
  maidr_dir <- dirname(script_dir)
} else {
  # Fallback for interactive mode
  maidr_dir <- getwd()
}

load_all(maidr_dir)

cat("\n")
cat("=======================================================\n")
cat("  Base R Smooth/Density Processor Tests\n")
cat("  Phase 2: Processor Implementation\n")
cat("=======================================================\n")

# Initialize test counters
tests_passed <- 0
tests_failed <- 0

# Test 1: Data Extraction - Simple density
cat("\n--- Test 1: Data Extraction from Density Object ---\n")
set.seed(123)
test_data <- rnorm(100)
dens <- density(test_data)

# Create layer_info structure
layer_info <- list(
  index = 1,
  type = "smooth",
  plot_call = list(
    function_name = "plot",
    args = list(dens)
  )
)

# Create processor and extract data
processor <- BaseRSmoothLayerProcessor$new(layer_info)
data <- processor$extract_data(layer_info)

# Verify data structure
if (is.list(data) && length(data) == 1) {
  cat("✓ Data is wrapped in outer array (length = 1)\n")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Data not properly wrapped (length = ", length(data), ")\n", sep = "")
  tests_failed <- tests_failed + 1
}

# Verify inner array
if (length(data[[1]]) == 512) {
  cat("✓ Data has 512 points (default density)\n")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Data has ", length(data[[1]]), " points (expected 512)\n", sep = "")
  tests_failed <- tests_failed + 1
}

# Verify point structure
first_point <- data[[1]][[1]]
if ("x" %in% names(first_point) && "y" %in% names(first_point)) {
  cat("✓ Each point has x and y properties\n")
  cat("  First point: x =", round(first_point$x, 4),
      ", y =", round(first_point$y, 4), "\n")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Point structure incorrect:", names(first_point), "\n")
  tests_failed <- tests_failed + 1
}

# Verify values are numeric
if (is.numeric(first_point$x) && is.numeric(first_point$y)) {
  cat("✓ x and y values are numeric\n")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ x and y values are not numeric\n")
  tests_failed <- tests_failed + 1
}

# Test 2: Data Extraction - Custom bandwidth
cat("\n--- Test 2: Data Extraction with Custom Bandwidth ---\n")
set.seed(456)
dens2 <- density(rnorm(100), bw = 0.5)
layer_info2 <- list(
  index = 1,
  type = "smooth",
  plot_call = list(
    function_name = "plot",
    args = list(dens2)
  )
)

processor2 <- BaseRSmoothLayerProcessor$new(layer_info2)
data2 <- processor2$extract_data(layer_info2)

if (length(data2[[1]]) == 512 && is.list(data2[[1]][[1]])) {
  cat("✓ Custom bandwidth density extracted correctly\n")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Custom bandwidth density extraction failed\n")
  tests_failed <- tests_failed + 1
}

# Test 3: Axis Title Extraction
cat("\n--- Test 3: Axis Title Extraction ---\n")
layer_info3 <- list(
  index = 1,
  type = "smooth",
  plot_call = list(
    function_name = "plot",
    args = list(dens, xlab = "Value", ylab = "Density")
  )
)

processor3 <- BaseRSmoothLayerProcessor$new(layer_info3)
axes <- processor3$extract_axis_titles(layer_info3)

if (axes$x == "Value" && axes$y == "Density") {
  cat("✓ Axis titles extracted correctly\n")
  cat("  xlab: '", axes$x, "', ylab: '", axes$y, "'\n", sep = "")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Axis titles incorrect: x='", axes$x, "', y='", axes$y, "'\n", sep = "")
  tests_failed <- tests_failed + 1
}

# Test 4: Main Title Extraction
cat("\n--- Test 4: Main Title Extraction ---\n")
layer_info4 <- list(
  index = 1,
  type = "smooth",
  plot_call = list(
    function_name = "plot",
    args = list(dens, main = "Density Plot")
  )
)

processor4 <- BaseRSmoothLayerProcessor$new(layer_info4)
title <- processor4$extract_main_title(layer_info4)

if (title == "Density Plot") {
  cat("✓ Main title extracted correctly: '", title, "'\n", sep = "")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Main title incorrect: '", title, "'\n", sep = "")
  tests_failed <- tests_failed + 1
}

# Test 5: Full Process Method (without grob)
cat("\n--- Test 5: Full Process Method (data only) ---\n")
layout <- list(
  title = "",
  axes = list(x = "", y = "")
)

result <- processor$process(NULL, layout, layer_info = layer_info, gt = NULL)

if (!is.null(result$data) && !is.null(result$type) && result$type == "smooth") {
  cat("✓ Process method returns correct structure\n")
  cat("  - type:", result$type, "\n")
  cat("  - data points:", length(result$data[[1]]), "\n")
  cat("  - title:", result$title, "\n")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Process method structure incorrect\n")
  tests_failed <- tests_failed + 1
}

# Test 6: Grob Creation and Selector Generation
cat("\n--- Test 6: Grob Creation and Selector Generation ---\n")
set.seed(789)

# Create a plot function
plot_func <- function() {
  plot(density(rnorm(100)), main = "Test Density")
}

# Create grob
grob <- tryCatch({
  ggplotify::as.grob(plot_func)
}, error = function(e) {
  cat("Warning: ggplotify error:", e$message, "\n")
  NULL
})

if (!is.null(grob)) {
  cat("✓ Grob created successfully\n")
  tests_passed <- tests_passed + 1
  
  # Try to find polylines
  layer_info6 <- list(
    index = 1,
    type = "smooth",
    plot_call = list(
      function_name = "plot",
      args = list(density(rnorm(100)))
    )
  )
  
  processor6 <- BaseRSmoothLayerProcessor$new(layer_info6)
  polylines <- processor6$find_polyline_grobs(grob, 1)
  
  cat("  Found", length(polylines), "polyline grob(s)\n")
  if (length(polylines) > 0) {
    cat("  Polyline name:", polylines[1], "\n")
    
    # Generate selectors
    selectors <- processor6$generate_selectors(layer_info6, grob)
    
    if (length(selectors) > 0) {
      cat("✓ Selectors generated:\n")
      cat("  ", selectors[[1]], "\n", sep = "")
      tests_passed <- tests_passed + 1
    } else {
      cat("❌ No selectors generated\n")
      tests_failed <- tests_failed + 1
    }
  } else {
    cat("⚠ No polylines found (may need to check grob structure)\n")
    tests_failed <- tests_failed + 1
  }
} else {
  cat("❌ Grob creation failed\n")
  tests_failed <- tests_failed + 1
}

# Test 7: End-to-End Processing
cat("\n--- Test 7: End-to-End Processing ---\n")
set.seed(999)

# Create density plot using patching system
plot(density(rnorm(100)), main = "E2E Test", xlab = "X", ylab = "Y")

# Get device calls
device_id <- grDevices::dev.cur()
calls <- get_device_calls(device_id)

if (length(calls) > 0) {
  cat("✓ Plot call captured\n")
  
  # Detect type
  registry <- get_global_registry()
  adapter <- registry$get_adapter("base_r")
  layer_type <- adapter$detect_layer_type(calls[[1]])
  
  if (layer_type == "smooth") {
    cat("✓ Detected as 'smooth'\n")
    
    # Create processor
    layer_info7 <- list(
      index = 1,
      type = layer_type,
      plot_call = calls[[1]]
    )
    
    processor7 <- BaseRSmoothLayerProcessor$new(layer_info7)
    result7 <- processor7$process(NULL, layout, layer_info = layer_info7,
                                  gt = NULL)
    
    if (result7$type == "smooth" && length(result7$data[[1]]) == 512) {
      cat("✓ End-to-end processing successful\n")
      cat("  - Type:", result7$type, "\n")
      cat("  - Points:", length(result7$data[[1]]), "\n")
      cat("  - Title:", result7$title, "\n")
      cat("  - X axis:", result7$axes$x, "\n")
      cat("  - Y axis:", result7$axes$y, "\n")
      tests_passed <- tests_passed + 1
    } else {
      cat("❌ End-to-end result incorrect\n")
      tests_failed <- tests_failed + 1
    }
  } else {
    cat("❌ Type detected as '", layer_type, "' not 'smooth'\n", sep = "")
    tests_failed <- tests_failed + 1
  }
} else {
  cat("❌ No calls captured\n")
  tests_failed <- tests_failed + 1
}

clear_device_storage(device_id)

# Summary
cat("\n")
cat("=======================================================\n")
cat("  Test Summary\n")
cat("=======================================================\n")
cat("Tests Passed: ", tests_passed, "\n", sep = "")
cat("Tests Failed: ", tests_failed, "\n", sep = "")
cat("Total Tests:  ", tests_passed + tests_failed, "\n", sep = "")

if (tests_failed == 0) {
  cat("\n✓ All processor tests passed! Phase 2 is complete.\n")
  cat("=======================================================\n\n")
  quit(status = 0)
} else {
  cat("\n❌ Some tests failed. Please review the output above.\n")
  cat("=======================================================\n\n")
  quit(status = 1)
}

