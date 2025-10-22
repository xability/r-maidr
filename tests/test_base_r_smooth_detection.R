#!/usr/bin/env Rscript

# Test Base R Smooth/Density Plot Detection
# This tests ONLY the patching and detection phase
# Focus: Single-layer density plots only

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
cat("  Base R Smooth/Density Plot Detection Tests\n")
cat("  Phase 1: Patching & Detection Only\n")
cat("=======================================================\n")

# Initialize test counters
tests_passed <- 0
tests_failed <- 0

# Helper function to check detection
check_detection <- function(test_name, expected_type) {
  device_id <- grDevices::dev.cur()
  calls <- get_device_calls(device_id)
  
  if (length(calls) == 0) {
    cat("❌", test_name, ": No calls captured\n")
    clear_device_storage(device_id)
    tests_failed <<- tests_failed + 1
    return(FALSE)
  }
  
  last_call <- calls[[length(calls)]]
  
  # Use adapter to detect type
  registry <- get_global_registry()
  adapter <- registry$get_adapter("base_r")
  detected_type <- adapter$detect_layer_type(last_call)
  
  if (detected_type == expected_type) {
    cat("✓ ", test_name, ": Detected as '", detected_type, "'\n", sep = "")
    clear_device_storage(device_id)
    tests_passed <<- tests_passed + 1
    return(TRUE)
  } else {
    cat("❌ ", test_name, ": Expected '", expected_type,
        "' but got '", detected_type, "'\n", sep = "")
    clear_device_storage(device_id)
    tests_failed <<- tests_failed + 1
    return(FALSE)
  }
}

# Test 1: Direct plot(density())
cat("\n--- Test 1: plot(density(data)) ---\n")
set.seed(123)
test_data <- rnorm(100)
plot(density(test_data))
check_detection("Direct plot(density())", "smooth")

# Test 2: Two-step density plot
cat("\n--- Test 2: Two-step (dens <- density(); plot(dens)) ---\n")
set.seed(456)
data2 <- rnorm(100)
dens2 <- density(data2)
plot(dens2)
check_detection("Two-step density plot", "smooth")

# Test 3: Density with custom bandwidth
cat("\n--- Test 3: plot(density(data, bw=0.5)) ---\n")
set.seed(789)
plot(density(rnorm(100), bw = 0.5))
check_detection("Custom bandwidth density", "smooth")

# Test 4: Density with custom kernel
cat("\n--- Test 4: plot(density(data, kernel='epanechnikov')) ---\n")
set.seed(101)
plot(density(rnorm(100), kernel = "epanechnikov"))
check_detection("Custom kernel density", "smooth")

# Test 5: Density with title and labels
cat("\n--- Test 5: plot(density(data), main='Title', xlab='X') ---\n")
set.seed(102)
plot(density(rnorm(100)), main = "Density Plot", xlab = "Value")
check_detection("Density with title", "smooth")

# Test 6: Verify non-density plots still work
cat("\n--- Test 6: Regular plot() (not density) ---\n")
plot(1:10, 1:10)
device_id <- grDevices::dev.cur()
calls <- get_device_calls(device_id)
if (length(calls) > 0) {
  last_call <- calls[[length(calls)]]
  registry <- get_global_registry()
  adapter <- registry$get_adapter("base_r")
  detected_type <- adapter$detect_layer_type(last_call)
  if (detected_type != "smooth") {
    cat("✓ Regular plot not detected as smooth (type: '",
        detected_type, "')\n", sep = "")
    tests_passed <- tests_passed + 1
  } else {
    cat("❌ Regular plot incorrectly detected as smooth\n")
    tests_failed <- tests_failed + 1
  }
}
clear_device_storage(device_id)

# Test 7: Verify barplot still works
cat("\n--- Test 7: Barplot should not be detected as smooth ---\n")
barplot(c(3, 5, 7), names.arg = c("A", "B", "C"))
device_id <- grDevices::dev.cur()
calls <- get_device_calls(device_id)
if (length(calls) > 0) {
  last_call <- calls[[length(calls)]]
  registry <- get_global_registry()
  adapter <- registry$get_adapter("base_r")
  detected_type <- adapter$detect_layer_type(last_call)
  if (detected_type == "bar") {
    cat("✓ Barplot correctly detected as '", detected_type, "'\n", sep = "")
    tests_passed <- tests_passed + 1
  } else {
    cat("❌ Barplot detected as '", detected_type,
        "' instead of 'bar'\n", sep = "")
    tests_failed <- tests_failed + 1
  }
}
clear_device_storage(device_id)

# Test 8: Check density object structure
cat("\n--- Test 8: Density Object Structure Verification ---\n")
set.seed(123)
test_data8 <- rnorm(100)
dens_obj <- density(test_data8)
cat("  Class:", class(dens_obj), "\n")
cat("  Inherits 'density':", inherits(dens_obj, "density"), "\n")
cat("  Number of x points:", length(dens_obj$x), "\n")
cat("  Number of y points:", length(dens_obj$y), "\n")
cat("  X range:", paste(round(range(dens_obj$x), 2), collapse = " to "), "\n")
cat("  Y range:", paste(round(range(dens_obj$y), 4), collapse = " to "), "\n")
cat("  Bandwidth:", round(dens_obj$bw, 4), "\n")
cat("  Sample size:", dens_obj$n, "\n")
if (class(dens_obj) == "density" && length(dens_obj$x) > 0) {
  cat("✓ Density object structure is valid\n")
  tests_passed <- tests_passed + 1
} else {
  cat("❌ Density object structure is invalid\n")
  tests_failed <- tests_failed + 1
}

# Test 9: Check if density object is stored in args
cat("\n--- Test 9: Density Object Stored in Call Args ---\n")
set.seed(999)
plot(density(rnorm(100)))
device_id <- grDevices::dev.cur()
calls <- get_device_calls(device_id)
if (length(calls) > 0) {
  last_call <- calls[[length(calls)]]
  first_arg <- last_call$args[[1]]
  if (inherits(first_arg, "density")) {
    cat("✓ Density object stored in call args\n")
    cat("  - x points:", length(first_arg$x), "\n")
    cat("  - y points:", length(first_arg$y), "\n")
    cat("  - bandwidth:", round(first_arg$bw, 4), "\n")
    cat("  - sample size:", first_arg$n, "\n")
    tests_passed <- tests_passed + 1
  } else {
    cat("❌ Density object NOT found in args\n")
    cat("  - First arg class:", class(first_arg), "\n")
    tests_failed <- tests_failed + 1
  }
}
clear_device_storage(device_id)

# Test 10: Multiple density plots in sequence
cat("\n--- Test 10: Multiple density plots (clear between) ---\n")
set.seed(111)
plot(density(rnorm(50)))
result1 <- check_detection("First density plot", "smooth")

set.seed(222)
plot(density(rnorm(75)))
result2 <- check_detection("Second density plot", "smooth")

if (result1 && result2) {
  cat("✓ Multiple density plots handled correctly\n")
} else {
  cat("❌ Issue with multiple density plots\n")
}

# Summary
cat("\n")
cat("=======================================================\n")
cat("  Test Summary\n")
cat("=======================================================\n")
cat("Tests Passed: ", tests_passed, "\n", sep = "")
cat("Tests Failed: ", tests_failed, "\n", sep = "")
cat("Total Tests:  ", tests_passed + tests_failed, "\n", sep = "")

if (tests_failed == 0) {
  cat("\n✓ All tests passed! Phase 1 detection is working correctly.\n")
  cat("=======================================================\n\n")
  quit(status = 0)
} else {
  cat("\n❌ Some tests failed. Please review the output above.\n")
  cat("=======================================================\n\n")
  quit(status = 1)
}

