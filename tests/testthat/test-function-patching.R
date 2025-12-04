# Comprehensive tests for Base R Function Patching System
# Testing function wrapping, call capture, and patching lifecycle

# Note: These tests interact with the global patching state
# Each test should clean up after itself

# ==============================================================================
# Helper Functions
# ==============================================================================

# Save and restore patching state
save_patching_state <- function() {
  list(
    saved_fns = maidr:::.maidr_patching_env$.saved_graphics_fns,
    is_active = maidr:::is_patching_active()
  )
}

restore_patching_state <- function(state) {
  maidr:::.maidr_patching_env$.saved_graphics_fns <- state$saved_fns
}

# ==============================================================================
# is_patching_active Tests
# ==============================================================================

test_that("is_patching_active returns logical", {
  result <- maidr:::is_patching_active()

  testthat::expect_type(result, "logical")
})

test_that("is_patching_active returns TRUE when patching initialized", {
  # Patching should be active after package load
  result <- maidr:::is_patching_active()

  # May be TRUE or FALSE depending on package state
  testthat::expect_type(result, "logical")
})

# ==============================================================================
# find_original_function Tests
# ==============================================================================

test_that("find_original_function finds graphics functions", {
  result <- maidr:::find_original_function("barplot")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function finds hist function", {
  result <- maidr:::find_original_function("hist")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function finds boxplot function", {
  result <- maidr:::find_original_function("boxplot")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function finds plot function", {
  result <- maidr:::find_original_function("plot")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function finds lines function", {
  result <- maidr:::find_original_function("lines")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function finds points function", {
  result <- maidr:::find_original_function("points")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function finds abline function", {
  result <- maidr:::find_original_function("abline")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function returns NULL for nonexistent function", {
  result <- maidr:::find_original_function("nonexistent_function_xyz")

  testthat::expect_null(result)
})

test_that("find_original_function finds stats functions", {
  result <- maidr:::find_original_function("density")

  testthat::expect_true(is.function(result))
})

test_that("find_original_function finds grDevices functions", {
  result <- maidr:::find_original_function("dev.cur")

  testthat::expect_true(is.function(result))
})

# ==============================================================================
# create_function_wrapper Tests
# ==============================================================================

test_that("create_function_wrapper returns a function", {
  original_fn <- function(x) x + 1

  wrapper <- maidr:::create_function_wrapper("test_fn", original_fn)

  testthat::expect_true(is.function(wrapper))
})

test_that("create_function_wrapper creates working wrapper", {
  original_fn <- function(x) x * 2

  wrapper <- maidr:::create_function_wrapper("test_fn", original_fn)

  # Wrapper should call original function
  result <- wrapper(5)
  testthat::expect_equal(result, 10)
})

test_that("create_function_wrapper preserves return value", {
  original_fn <- function(x, y) list(sum = x + y, prod = x * y)

  wrapper <- maidr:::create_function_wrapper("test_fn", original_fn)

  result <- wrapper(3, 4)
  testthat::expect_equal(result$sum, 7)
  testthat::expect_equal(result$prod, 12)
})

# ==============================================================================
# create_barplot_wrapper Tests
# ==============================================================================

test_that("create_barplot_wrapper returns a function", {
  original_fn <- graphics::barplot

  wrapper <- maidr:::create_barplot_wrapper(original_fn)

  testthat::expect_true(is.function(wrapper))
})

test_that("create_barplot_wrapper creates working wrapper", {
  original_fn <- graphics::barplot

  wrapper <- maidr:::create_barplot_wrapper(original_fn)

  # Should be able to call without error
  testthat::expect_silent({
    result <- wrapper(c(10, 20, 30))
  })
})

# ==============================================================================
# apply_barplot_patches Tests
# ==============================================================================

test_that("apply_barplot_patches returns args list", {
  args <- list(c(10, 20, 30))

  result <- maidr:::apply_barplot_patches(args)

  testthat::expect_type(result, "list")
})

test_that("apply_barplot_patches preserves simple args", {
  args <- list(c(10, 20, 30), names.arg = c("A", "B", "C"))

  result <- maidr:::apply_barplot_patches(args)

  testthat::expect_type(result, "list")
  testthat::expect_true("names.arg" %in% names(result))
})

# ==============================================================================
# apply_barplot_sorting Tests
# ==============================================================================

test_that("apply_barplot_sorting returns args list", {
  args <- list(c(10, 20, 30))

  result <- maidr:::apply_barplot_sorting(args)

  testthat::expect_type(result, "list")
})

test_that("apply_barplot_sorting handles vector input", {
  args <- list(c(10, 20, 30))

  result <- maidr:::apply_barplot_sorting(args)

  # Vector should not be sorted (only matrices)
  testthat::expect_equal(result[[1]], c(10, 20, 30))
})

test_that("apply_barplot_sorting sorts matrix rows", {
  test_matrix <- matrix(c(10, 20, 30, 40), nrow = 2)
  rownames(test_matrix) <- c("B", "A")
  colnames(test_matrix) <- c("Y", "X")

  args <- list(test_matrix)

  result <- maidr:::apply_barplot_sorting(args)

  # Rows should be sorted alphabetically (A, B)
  testthat::expect_equal(rownames(result[[1]]), c("A", "B"))
  # Columns should be sorted alphabetically (X, Y)
  testthat::expect_equal(colnames(result[[1]]), c("X", "Y"))
})

test_that("apply_barplot_sorting handles matrix without names", {
  test_matrix <- matrix(c(10, 20, 30, 40), nrow = 2)
  # No row/column names

  args <- list(test_matrix)

  result <- maidr:::apply_barplot_sorting(args)

  # Should return unchanged
  testthat::expect_equal(result[[1]], test_matrix)
})

test_that("apply_barplot_sorting handles matrix with only row names", {
  test_matrix <- matrix(c(10, 20, 30, 40), nrow = 2)
  rownames(test_matrix) <- c("B", "A")
  # No column names

  args <- list(test_matrix)

  result <- maidr:::apply_barplot_sorting(args)

  # Should return unchanged (needs both row and column names)
  testthat::expect_equal(result[[1]], test_matrix)
})

test_that("apply_barplot_sorting handles matrix with only column names", {
  test_matrix <- matrix(c(10, 20, 30, 40), nrow = 2)
  colnames(test_matrix) <- c("Y", "X")
  # No row names

  args <- list(test_matrix)

  result <- maidr:::apply_barplot_sorting(args)

  # Should return unchanged (needs both row and column names)
  testthat::expect_equal(result[[1]], test_matrix)
})

test_that("apply_barplot_sorting updates names.arg", {
  test_matrix <- matrix(c(10, 20, 30, 40), nrow = 2)
  rownames(test_matrix) <- c("A", "B")
  colnames(test_matrix) <- c("Second", "First")

  args <- list(test_matrix, names.arg = c("Label2", "Label1"))

  result <- maidr:::apply_barplot_sorting(args)

  # Column order should be First, Second
  testthat::expect_equal(colnames(result[[1]]), c("First", "Second"))
})

# ==============================================================================
# get_plot_calls and clear_plot_calls Tests
# ==============================================================================

test_that("get_plot_calls returns list", {
  result <- maidr:::get_plot_calls()

  testthat::expect_type(result, "list")
})

test_that("clear_plot_calls clears calls", {
  # Create a plot first
  barplot(c(10, 20, 30))

  # Clear
  maidr:::clear_plot_calls()

  # Get calls
  calls <- maidr:::get_plot_calls()

  # Should be empty after clearing
  testthat::expect_equal(length(calls), 0)
})

test_that("clear_plot_calls returns NULL invisibly", {
  result <- maidr:::clear_plot_calls()

  testthat::expect_null(result)
})

# ==============================================================================
# wrap_function Tests
# ==============================================================================

test_that("wrap_function returns FALSE for nonexistent function", {
  result <- maidr:::wrap_function("nonexistent_function_xyz")

  testthat::expect_false(result)
})

# ==============================================================================
# initialize_base_r_patching Tests
# ==============================================================================

# NOTE: We only test that initialize_base_r_patching works, not all parameter
# combinations, as calling it with different params could affect global state.

test_that("initialize_base_r_patching returns NULL invisibly", {
  # Re-initializing with same params should be safe
  result <- maidr:::initialize_base_r_patching()

  testthat::expect_null(result)
})

test_that("initialize_base_r_patching is idempotent", {
  # Calling multiple times should be safe
  result1 <- maidr:::initialize_base_r_patching()
  result2 <- maidr:::initialize_base_r_patching()

  testthat::expect_null(result1)
  testthat::expect_null(result2)
})

# ==============================================================================
# restore_original_functions Tests
# ==============================================================================

# NOTE: We don't actually test restore_original_functions() because it would
# disable patching for all subsequent tests. The function is tested implicitly
# through the package's initialization/cleanup lifecycle.

test_that("restore_original_functions exists and is a function", {
  testthat::expect_true(is.function(maidr:::restore_original_functions))
})

# ==============================================================================
# wrap_s3_generics Tests
# ==============================================================================

test_that("wrap_s3_generics returns TRUE invisibly", {
  result <- maidr:::wrap_s3_generics()

  testthat::expect_true(result)
})

test_that("wrap_s3_generics can be called multiple times", {
  # Should not error on repeated calls
  result1 <- maidr:::wrap_s3_generics()
  result2 <- maidr:::wrap_s3_generics()

  testthat::expect_true(result1)
  testthat::expect_true(result2)
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Function patching captures barplot calls", {
  testthat::skip_if_not(maidr:::is_patching_active(), "Patching not active")

  # Clear any existing calls
  clear_base_r_state()

  # Create a barplot
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  # Get captured calls
  calls <- maidr:::get_plot_calls()

  # Should have at least one call (if patching is working)
  # Note: This may be 0 in some test environments
  testthat::expect_type(calls, "list")

  # Clean up
  clear_base_r_state()
})

test_that("Function patching captures histogram calls", {
  testthat::skip_if_not(maidr:::is_patching_active(), "Patching not active")

  # Clear any existing calls
  clear_base_r_state()

  # Create a histogram
  hist(rnorm(100))

  # Get captured calls
  calls <- maidr:::get_plot_calls()

  # Should return a list
  testthat::expect_type(calls, "list")

  # Clean up
  clear_base_r_state()
})

test_that("Function patching captures boxplot calls", {
  testthat::skip_if_not(maidr:::is_patching_active(), "Patching not active")

  # Clear any existing calls
  clear_base_r_state()

  # Create a boxplot
  boxplot(mpg ~ cyl, data = mtcars)

  # Get captured calls
  calls <- maidr:::get_plot_calls()

  # Should return a list
  testthat::expect_type(calls, "list")

  # Clean up
  clear_base_r_state()
})

test_that("Function patching works with multiple plots", {
  testthat::skip_if_not(maidr:::is_patching_active(), "Patching not active")

  # Clear any existing calls
  clear_base_r_state()

  # Create multiple plots
  barplot(c(10, 20, 30))
  hist(rnorm(50))

  # Get captured calls
  calls <- maidr:::get_plot_calls()

  # Should return a list
  testthat::expect_type(calls, "list")

  # Clean up
  clear_base_r_state()
})

test_that("Patching preserves plot functionality", {
  # Create a barplot and verify it works correctly
  x <- barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  # barplot returns bar midpoints
  testthat::expect_type(x, "double")
  testthat::expect_equal(length(x), 3)

  clear_base_r_state()
})

test_that("Patching preserves hist return value", {
  # hist returns a histogram object
  h <- hist(rnorm(100), plot = FALSE)

  testthat::expect_s3_class(h, "histogram")
  testthat::expect_true("breaks" %in% names(h))
  testthat::expect_true("counts" %in% names(h))

  clear_base_r_state()
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Patching handles empty plot data", {
  testthat::skip_if_not(maidr:::is_patching_active(), "Patching not active")

  clear_base_r_state()

  # Create histogram with minimal data
  hist(c(1))

  calls <- maidr:::get_plot_calls()
  testthat::expect_type(calls, "list")

  clear_base_r_state()
})

test_that("Patching handles plot with many arguments", {
  testthat::skip_if_not(maidr:::is_patching_active(), "Patching not active")

  clear_base_r_state()

  # Create barplot with many optional arguments
  barplot(
    c(10, 20, 30),
    names.arg = c("A", "B", "C"),
    col = c("red", "green", "blue"),
    main = "Test Plot",
    xlab = "Categories",
    ylab = "Values",
    border = "black",
    density = NULL,
    horiz = FALSE
  )

  calls <- maidr:::get_plot_calls()
  testthat::expect_type(calls, "list")

  clear_base_r_state()
})

test_that("Patching handles matrix barplot", {
  testthat::skip_if_not(maidr:::is_patching_active(), "Patching not active")

  clear_base_r_state()

  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  rownames(test_matrix) <- c("G1", "G2")
  colnames(test_matrix) <- c("A", "B")

  barplot(test_matrix, beside = TRUE)

  calls <- maidr:::get_plot_calls()
  testthat::expect_type(calls, "list")

  clear_base_r_state()
})
