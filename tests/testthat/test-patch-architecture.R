# Comprehensive tests for Base R Patch Architecture
# Testing the modular patch system for Base R plots

# ==============================================================================
# BaseRPatcher Abstract Class Tests
# ==============================================================================

test_that("BaseRPatcher is an R6 class", {
  testthat::expect_true(R6::is.R6Class(maidr:::BaseRPatcher))
})

test_that("BaseRPatcher abstract methods throw errors", {
  patcher <- maidr:::BaseRPatcher$new()

  testthat::expect_error(patcher$can_patch("test", list()))
  testthat::expect_error(patcher$apply_patch("test", list()))
  testthat::expect_error(patcher$get_name())
})

# ==============================================================================
# SortingPatcher Tests
# ==============================================================================

test_that("SortingPatcher creates instance correctly", {
  patcher <- maidr:::SortingPatcher$new()

  testthat::expect_s3_class(patcher, "SortingPatcher")
  testthat::expect_s3_class(patcher, "BaseRPatcher")
})

test_that("SortingPatcher get_name returns correct name", {
  patcher <- maidr:::SortingPatcher$new()

  testthat::expect_equal(patcher$get_name(), "SortingPatcher")
})

test_that("SortingPatcher can_patch returns TRUE for barplot with vector", {
  patcher <- maidr:::SortingPatcher$new()

  args <- list(c(10, 20, 30))

  testthat::expect_true(patcher$can_patch("barplot", args))
})

test_that("SortingPatcher can_patch returns TRUE for barplot with matrix", {
  patcher <- maidr:::SortingPatcher$new()

  args <- list(matrix(1:6, nrow = 2))

  testthat::expect_true(patcher$can_patch("barplot", args))
})

test_that("SortingPatcher can_patch returns FALSE for non-barplot", {
  patcher <- maidr:::SortingPatcher$new()

  testthat::expect_false(patcher$can_patch("hist", list(1:10)))
  testthat::expect_false(patcher$can_patch("plot", list(1:10)))
})

test_that("SortingPatcher patch_simple_barplot sorts by names", {
  patcher <- maidr:::SortingPatcher$new()

  values <- c(10, 20, 30)
  names_arg <- c("C", "A", "B")
  args <- list(values, names.arg = names_arg)

  result <- patcher$patch_simple_barplot(args)

  testthat::expect_equal(result$names.arg, c("A", "B", "C"))
})

test_that("SortingPatcher patch_simple_barplot handles NULL names", {
  patcher <- maidr:::SortingPatcher$new()

  values <- c(10, 20, 30)
  args <- list(values)

  # Should not error even without names
  result <- patcher$patch_simple_barplot(args)

  testthat::expect_type(result, "list")
})

test_that("SortingPatcher patch_simple_barplot uses names(height) as fallback", {
  patcher <- maidr:::SortingPatcher$new()

  values <- c(10, 20, 30)
  names(values) <- c("C", "A", "B")
  args <- list(values)

  result <- patcher$patch_simple_barplot(args)

  # Values should be reordered (ignoring names attribute)
  testthat::expect_equal(unname(result[[1]]), c(20, 30, 10))
})

test_that("SortingPatcher is_dodged_barplot detects dodged with beside=TRUE", {
  patcher <- maidr:::SortingPatcher$new()

  args_dodged <- list(matrix(1:4, nrow = 2), beside = TRUE)
  args_stacked <- list(matrix(1:4, nrow = 2), beside = FALSE)
  args_default <- list(matrix(1:4, nrow = 2))

  testthat::expect_true(patcher$is_dodged_barplot(args_dodged))
  testthat::expect_false(patcher$is_dodged_barplot(args_stacked))
  testthat::expect_false(patcher$is_dodged_barplot(args_default))
})

test_that("SortingPatcher patch_dodged_barplot sorts rows", {
  patcher <- maidr:::SortingPatcher$new()

  mat <- matrix(1:4, nrow = 2)
  rownames(mat) <- c("B", "A")
  colnames(mat) <- c("X", "Y")
  args <- list(mat, beside = TRUE)

  result <- patcher$patch_dodged_barplot(args)

  testthat::expect_equal(rownames(result[[1]]), c("A", "B"))
})

test_that("SortingPatcher patch_dodged_barplot sorts columns", {
  patcher <- maidr:::SortingPatcher$new()

  mat <- matrix(1:4, nrow = 2)
  rownames(mat) <- c("A", "B")
  colnames(mat) <- c("Y", "X")
  args <- list(mat, beside = TRUE)

  result <- patcher$patch_dodged_barplot(args)

  testthat::expect_equal(colnames(result[[1]]), c("X", "Y"))
})

test_that("SortingPatcher patch_dodged_barplot handles matrix without names", {
  patcher <- maidr:::SortingPatcher$new()

  mat <- matrix(1:4, nrow = 2)
  args <- list(mat, beside = TRUE)

  result <- patcher$patch_dodged_barplot(args)

  # Should not error
  testthat::expect_type(result, "list")
  testthat::expect_true(is.matrix(result[[1]]))
})

test_that("SortingPatcher patch_stacked_barplot delegates to dodged", {
  patcher <- maidr:::SortingPatcher$new()

  mat <- matrix(1:4, nrow = 2)
  rownames(mat) <- c("B", "A")
  args <- list(mat, beside = FALSE)

  result <- patcher$patch_stacked_barplot(args)

  testthat::expect_equal(rownames(result[[1]]), c("A", "B"))
})

test_that("SortingPatcher apply_patch routes correctly", {
  patcher <- maidr:::SortingPatcher$new()

  # Vector - simple barplot
  vec_args <- list(c(10, 20), names.arg = c("B", "A"))
  vec_result <- patcher$apply_patch("barplot", vec_args)
  testthat::expect_equal(vec_result$names.arg, c("A", "B"))

  # Matrix with beside=TRUE - dodged
  mat <- matrix(1:4, nrow = 2)
  rownames(mat) <- c("B", "A")
  mat_args <- list(mat, beside = TRUE)
  mat_result <- patcher$apply_patch("barplot", mat_args)
  testthat::expect_equal(rownames(mat_result[[1]]), c("A", "B"))
})

test_that("SortingPatcher apply_patch returns unchanged for non-barplot", {
  patcher <- maidr:::SortingPatcher$new()

  args <- list(1:10)
  result <- patcher$apply_patch("hist", args)

  testthat::expect_identical(result, args)
})

# ==============================================================================
# PatchManager Tests
# ==============================================================================

test_that("PatchManager creates instance with default patchers", {
  manager <- maidr:::PatchManager$new()

  testthat::expect_s3_class(manager, "PatchManager")

  names <- manager$get_patcher_names()
  testthat::expect_true("SortingPatcher" %in% names)
})

test_that("PatchManager add_patcher adds new patcher", {
  manager <- maidr:::PatchManager$new()
  initial_count <- length(manager$get_patcher_names())

  # Create a custom patcher
  CustomPatcher <- R6::R6Class("CustomPatcher",
    inherit = maidr:::BaseRPatcher,
    public = list(
      can_patch = function(function_name, args) FALSE,
      apply_patch = function(function_name, args) args,
      get_name = function() "CustomPatcher"
    )
  )

  manager$add_patcher(CustomPatcher$new())

  testthat::expect_equal(
    length(manager$get_patcher_names()),
    initial_count + 1
  )
  testthat::expect_true("CustomPatcher" %in% manager$get_patcher_names())
})

test_that("PatchManager add_patcher errors on non-patcher", {
  manager <- maidr:::PatchManager$new()

  testthat::expect_error(
    manager$add_patcher(list()),
    "must inherit from BaseRPatcher"
  )
})

test_that("PatchManager apply_patches processes through all patchers", {
  manager <- maidr:::PatchManager$new()

  # Barplot args that should be sorted
  args <- list(c(10, 20), names.arg = c("B", "A"))

  result <- manager$apply_patches("barplot", args)

  testthat::expect_equal(result$names.arg, c("A", "B"))
})

test_that("PatchManager apply_patches returns unchanged when no patcher matches", {
  manager <- maidr:::PatchManager$new()

  args <- list(1:10)
  result <- manager$apply_patches("hist", args)

  testthat::expect_identical(result, args)
})

test_that("PatchManager get_patcher_names returns character vector", {
  manager <- maidr:::PatchManager$new()

  names <- manager$get_patcher_names()

  testthat::expect_type(names, "character")
  testthat::expect_true(length(names) > 0)
})

# ==============================================================================
# get_patch_manager Tests
# ==============================================================================

test_that("get_patch_manager function exists", {
  # Note: get_patch_manager uses <<- which may not work with namespace
  # locking in loaded packages. We just verify the function exists.
  testthat::expect_true(is.function(maidr:::get_patch_manager))
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Full patch pipeline works for simple barplot", {
  # Use PatchManager directly instead of get_patch_manager
  manager <- maidr:::PatchManager$new()

  # Unsorted bar data
  args <- list(
    c(30, 10, 20),
    names.arg = c("C", "A", "B")
  )

  result <- manager$apply_patches("barplot", args)

  testthat::expect_equal(result$names.arg, c("A", "B", "C"))
  testthat::expect_equal(result[[1]], c(10, 20, 30))
})

test_that("Full patch pipeline works for dodged barplot", {
  # Use PatchManager directly
  manager <- maidr:::PatchManager$new()

  mat <- matrix(c(4, 3, 2, 1), nrow = 2)
  rownames(mat) <- c("B", "A")
  colnames(mat) <- c("Y", "X")

  args <- list(mat, beside = TRUE)

  result <- manager$apply_patches("barplot", args)

  testthat::expect_equal(rownames(result[[1]]), c("A", "B"))
  testthat::expect_equal(colnames(result[[1]]), c("X", "Y"))
})
