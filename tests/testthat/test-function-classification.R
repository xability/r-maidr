# Comprehensive tests for Base R Function Classification
# Testing function classification and lookup utilities

# ==============================================================================
# classify_function Tests
# ==============================================================================

test_that("classify_function returns HIGH for high-level functions", {
  high_funcs <- c(
    "barplot", "plot", "hist", "boxplot", "image", "heatmap",
    "contour", "matplot", "curve", "dotchart", "stripchart",
    "stem", "pie", "mosaicplot", "assocplot", "pairs", "coplot"
  )

  for (func in high_funcs) {
    testthat::expect_equal(
      maidr:::classify_function(func),
      "HIGH",
      info = paste("Failed for function:", func)
    )
  }
})

test_that("classify_function returns LOW for low-level functions", {
  low_funcs <- c(
    "lines", "points", "text", "mtext", "abline", "segments",
    "arrows", "polygon", "rect", "symbols", "legend", "axis",
    "title", "grid"
  )

  for (func in low_funcs) {
    testthat::expect_equal(
      maidr:::classify_function(func),
      "LOW",
      info = paste("Failed for function:", func)
    )
  }
})

test_that("classify_function returns LAYOUT for layout functions", {
  layout_funcs <- c("par", "layout", "split.screen")

  for (func in layout_funcs) {
    testthat::expect_equal(
      maidr:::classify_function(func),
      "LAYOUT",
      info = paste("Failed for function:", func)
    )
  }
})

test_that("classify_function returns UNKNOWN for unrecognized functions", {
  testthat::expect_equal(maidr:::classify_function("unknown_func"), "UNKNOWN")
  testthat::expect_equal(maidr:::classify_function("random_function"), "UNKNOWN")
  testthat::expect_equal(maidr:::classify_function("ggplot"), "UNKNOWN")
})

test_that("classify_function returns UNKNOWN for NULL input", {
  testthat::expect_equal(maidr:::classify_function(NULL), "UNKNOWN")
})

test_that("classify_function returns UNKNOWN for non-character input", {
  testthat::expect_equal(maidr:::classify_function(123), "UNKNOWN")
  testthat::expect_equal(maidr:::classify_function(list()), "UNKNOWN")
  testthat::expect_equal(maidr:::classify_function(TRUE), "UNKNOWN")
})

test_that("classify_function handles .default suffix", {
  testthat::expect_equal(maidr:::classify_function("barplot.default"), "HIGH")
  testthat::expect_equal(maidr:::classify_function("plot.default"), "HIGH")
  testthat::expect_equal(maidr:::classify_function("hist.default"), "HIGH")
})

# ==============================================================================
# get_functions_by_class Tests
# ==============================================================================

test_that("get_functions_by_class returns HIGH functions", {
  high_funcs <- maidr:::get_functions_by_class("HIGH")

  testthat::expect_type(high_funcs, "character")
  testthat::expect_true("barplot" %in% high_funcs)
  testthat::expect_true("hist" %in% high_funcs)
  testthat::expect_true("plot" %in% high_funcs)
})

test_that("get_functions_by_class returns LOW functions", {
  low_funcs <- maidr:::get_functions_by_class("LOW")

  testthat::expect_type(low_funcs, "character")
  testthat::expect_true("lines" %in% low_funcs)
  testthat::expect_true("points" %in% low_funcs)
  testthat::expect_true("legend" %in% low_funcs)
})

test_that("get_functions_by_class returns LAYOUT functions", {
  layout_funcs <- maidr:::get_functions_by_class("LAYOUT")

  testthat::expect_type(layout_funcs, "character")
  testthat::expect_true("par" %in% layout_funcs)
  testthat::expect_true("layout" %in% layout_funcs)
})

test_that("get_functions_by_class returns empty for unknown class", {
  result <- maidr:::get_functions_by_class("NONEXISTENT")

  testthat::expect_type(result, "character")
  testthat::expect_equal(length(result), 0)
})

# ==============================================================================
# is_high_level_function Tests
# ==============================================================================

test_that("is_high_level_function returns TRUE for high-level functions", {
  testthat::expect_true(maidr:::is_high_level_function("barplot"))
  testthat::expect_true(maidr:::is_high_level_function("hist"))
  testthat::expect_true(maidr:::is_high_level_function("plot"))
  testthat::expect_true(maidr:::is_high_level_function("boxplot"))
})

test_that("is_high_level_function returns FALSE for low-level functions", {
  testthat::expect_false(maidr:::is_high_level_function("lines"))
  testthat::expect_false(maidr:::is_high_level_function("points"))
})

test_that("is_high_level_function returns FALSE for layout functions", {
  testthat::expect_false(maidr:::is_high_level_function("par"))
  testthat::expect_false(maidr:::is_high_level_function("layout"))
})

test_that("is_high_level_function returns FALSE for unknown functions", {
  testthat::expect_false(maidr:::is_high_level_function("unknown"))
})

# ==============================================================================
# is_low_level_function Tests
# ==============================================================================

test_that("is_low_level_function returns TRUE for low-level functions", {
  testthat::expect_true(maidr:::is_low_level_function("lines"))
  testthat::expect_true(maidr:::is_low_level_function("points"))
  testthat::expect_true(maidr:::is_low_level_function("legend"))
  testthat::expect_true(maidr:::is_low_level_function("text"))
})

test_that("is_low_level_function returns FALSE for high-level functions", {
  testthat::expect_false(maidr:::is_low_level_function("barplot"))
  testthat::expect_false(maidr:::is_low_level_function("hist"))
})

test_that("is_low_level_function returns FALSE for layout functions", {
  testthat::expect_false(maidr:::is_low_level_function("par"))
})

# ==============================================================================
# is_layout_function Tests
# ==============================================================================

test_that("is_layout_function returns TRUE for layout functions", {
  testthat::expect_true(maidr:::is_layout_function("par"))
  testthat::expect_true(maidr:::is_layout_function("layout"))
  testthat::expect_true(maidr:::is_layout_function("split.screen"))
})

test_that("is_layout_function returns FALSE for high-level functions", {
  testthat::expect_false(maidr:::is_layout_function("barplot"))
})

test_that("is_layout_function returns FALSE for low-level functions", {
  testthat::expect_false(maidr:::is_layout_function("lines"))
})

# ==============================================================================
# get_all_patchable_functions Tests
# ==============================================================================

test_that("get_all_patchable_functions returns list structure", {
  result <- maidr:::get_all_patchable_functions()

  testthat::expect_type(result, "list")
  testthat::expect_true("HIGH" %in% names(result))
  testthat::expect_true("LOW" %in% names(result))
  testthat::expect_true("LAYOUT" %in% names(result))
})

test_that("get_all_patchable_functions contains expected functions", {
  result <- maidr:::get_all_patchable_functions()

  testthat::expect_true("barplot" %in% result$HIGH)
  testthat::expect_true("lines" %in% result$LOW)
  testthat::expect_true("par" %in% result$LAYOUT)
})

# ==============================================================================
# get_all_function_names Tests
# ==============================================================================

test_that("get_all_function_names returns character vector", {
  result <- maidr:::get_all_function_names()

  testthat::expect_type(result, "character")
  testthat::expect_true(length(result) > 0)
})

test_that("get_all_function_names includes all categories", {
  result <- maidr:::get_all_function_names()

  # Should include HIGH functions
  testthat::expect_true("barplot" %in% result)
  testthat::expect_true("hist" %in% result)

  # Should include LOW functions
  testthat::expect_true("lines" %in% result)
  testthat::expect_true("points" %in% result)

  # Should include LAYOUT functions
  testthat::expect_true("par" %in% result)
})

test_that("get_all_function_names has no duplicate entries", {
  result <- maidr:::get_all_function_names()

  testthat::expect_equal(length(result), length(unique(result)))
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Classification is case-sensitive", {
  testthat::expect_equal(maidr:::classify_function("BARPLOT"), "UNKNOWN")
  testthat::expect_equal(maidr:::classify_function("Hist"), "UNKNOWN")
})

test_that("Empty string is classified as UNKNOWN", {
  testthat::expect_equal(maidr:::classify_function(""), "UNKNOWN")
})
