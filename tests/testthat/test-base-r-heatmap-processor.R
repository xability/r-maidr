# Comprehensive tests for Base R Heatmap Layer Processor
# Testing heatmap data extraction and selector generation

# ==============================================================================
# Setup
# ==============================================================================

# Helper to ensure package is loaded
setup_clean_state <- function() {
  tryCatch(
    maidr:::clear_all_device_storage(),
    error = function(e) NULL
  )
}

# Helper to create a minimal layer_info
create_heatmap_layer_info <- function(
    heat_matrix = NULL,
    main = NULL,
    xlab = NULL,
    ylab = NULL) {
  args <- list()
  if (!is.null(heat_matrix)) {
    args[[1]] <- heat_matrix
    names(args)[1] <- ""
  }
  if (!is.null(main)) args$main <- main
  if (!is.null(xlab)) args$xlab <- xlab
  if (!is.null(ylab)) args$ylab <- ylab

  list(
    index = 1,
    type = "heat",
    function_name = "heatmap",
    group_index = 1,
    plot_call = list(
      function_name = "heatmap",
      args = args
    )
  )
}

# ==============================================================================
# BaseRHeatmapLayerProcessor Class Tests
# ==============================================================================

test_that("BaseRHeatmapLayerProcessor creates instance correctly", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  testthat::expect_s3_class(processor, "BaseRHeatmapLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

# ==============================================================================
# extract_data Tests
# ==============================================================================

test_that("extract_data returns empty list for NULL layer_info", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_data(NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("extract_data returns empty structure for non-matrix argument", {
  layer_info <- list(
    plot_call = list(
      args = list(c(1, 2, 3)) # Vector, not matrix
    )
  )
  base_layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(base_layer_info)

  result <- processor$extract_data(layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_true("points" %in% names(result))
  testthat::expect_equal(length(result$points), 0)
})

test_that("extract_data extracts matrix data correctly", {
  heat_matrix <- matrix(1:6, nrow = 2, ncol = 3)
  rownames(heat_matrix) <- c("R1", "R2")
  colnames(heat_matrix) <- c("C1", "C2", "C3")

  layer_info <- create_heatmap_layer_info(heat_matrix = heat_matrix)
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_data(layer_info)

  testthat::expect_type(result, "list")
  testthat::expect_true("points" %in% names(result))
  testthat::expect_true("x" %in% names(result))
  testthat::expect_true("y" %in% names(result))
})

test_that("extract_data generates default row/col names for unnamed matrix", {
  heat_matrix <- matrix(1:4, nrow = 2, ncol = 2)
  # No row/col names

  layer_info <- create_heatmap_layer_info(heat_matrix = heat_matrix)
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_data(layer_info)

  testthat::expect_equal(length(result$x), 2)
  testthat::expect_equal(length(result$y), 2)
  testthat::expect_equal(result$x[[1]], "1")
  testthat::expect_equal(result$x[[2]], "2")
})

test_that("extract_data reverses row order for visual layout", {
  heat_matrix <- matrix(1:4, nrow = 2, ncol = 2)
  rownames(heat_matrix) <- c("R1", "R2")
  colnames(heat_matrix) <- c("C1", "C2")

  layer_info <- create_heatmap_layer_info(heat_matrix = heat_matrix)
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_data(layer_info)

  # Rows should be reversed for visual layout
  testthat::expect_equal(result$y[[1]], "R2")
  testthat::expect_equal(result$y[[2]], "R1")
})

# ==============================================================================
# generate_selectors Tests
# ==============================================================================

test_that("generate_selectors returns empty list for NULL gtable", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$generate_selectors(list(), NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("generate_selectors generates fallback selector", {
  layer_info <- create_heatmap_layer_info()
  layer_info$group_index <- 1
  layer_info$index <- 1
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  # Minimal grob structure without image-rect
  fake_grob <- list(name = "other-grob")

  result <- processor$generate_selectors(layer_info, fake_grob)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 1)
  testthat::expect_true(grepl("graphics-plot-1", result[[1]]))
})

test_that("generate_selectors uses group_index when available", {
  layer_info <- create_heatmap_layer_info()
  layer_info$group_index <- 3
  layer_info$index <- 1
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  fake_grob <- list(name = "other-grob")

  result <- processor$generate_selectors(layer_info, fake_grob)

  testthat::expect_true(grepl("graphics-plot-3", result[[1]]))
})

test_that("generate_selectors falls back to index when no group_index", {
  layer_info <- create_heatmap_layer_info()
  layer_info$group_index <- NULL
  layer_info$index <- 2
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  fake_grob <- list(name = "other-grob")

  result <- processor$generate_selectors(layer_info, fake_grob)

  testthat::expect_true(grepl("graphics-plot-2", result[[1]]))
})

# ==============================================================================
# find_image_rect_grobs Tests
# ==============================================================================

test_that("find_image_rect_grobs returns empty for simple grob without pattern", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  grob <- list(name = "other-grob")

  result <- processor$find_image_rect_grobs(grob, 1)

  testthat::expect_type(result, "character")
  testthat::expect_equal(length(result), 0)
})

test_that("find_image_rect_grobs finds matching grob name", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  grob <- list(name = "graphics-plot-1-image-rect-1.1")

  result <- processor$find_image_rect_grobs(grob, 1)

  testthat::expect_equal(length(result), 1)
  testthat::expect_equal(result[1], "graphics-plot-1-image-rect-1.1")
})

test_that("find_image_rect_grobs searches gList recursively", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  grob <- structure(
    list(
      list(name = "other-grob"),
      list(name = "graphics-plot-1-image-rect-1.1")
    ),
    class = "gList"
  )

  result <- processor$find_image_rect_grobs(grob, 1)

  testthat::expect_gte(length(result), 1)
})

test_that("find_image_rect_grobs searches gTree children", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  grob <- structure(
    list(
      name = "parent",
      children = list(
        list(name = "graphics-plot-2-image-rect-1.1")
      )
    ),
    class = c("gTree", "grob")
  )

  result <- processor$find_image_rect_grobs(grob, 2)

  testthat::expect_gte(length(result), 1)
})

# ==============================================================================
# extract_axis_titles Tests
# ==============================================================================

test_that("extract_axis_titles returns defaults for NULL layer_info", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_axis_titles(NULL)

  testthat::expect_equal(result$x, "")
  testthat::expect_equal(result$y, "")
  testthat::expect_equal(result$fill, "")
})

test_that("extract_axis_titles extracts xlab and ylab", {
  layer_info <- create_heatmap_layer_info(xlab = "X Axis", ylab = "Y Axis")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(result$x, "X Axis")
  testthat::expect_equal(result$y, "Y Axis")
  testthat::expect_equal(result$fill, "value")
})

test_that("extract_axis_titles uses defaults when labels missing", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_axis_titles(layer_info)

  testthat::expect_equal(result$x, "")
  testthat::expect_equal(result$y, "")
})

# ==============================================================================
# extract_main_title Tests
# ==============================================================================

test_that("extract_main_title returns empty for NULL layer_info", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_main_title(NULL)

  testthat::expect_equal(result, "")
})

test_that("extract_main_title extracts main argument", {
  layer_info <- create_heatmap_layer_info(main = "Heatmap Title")
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_main_title(layer_info)

  testthat::expect_equal(result, "Heatmap Title")
})

test_that("extract_main_title returns empty when main not present", {
  layer_info <- create_heatmap_layer_info()
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$extract_main_title(layer_info)

  testthat::expect_equal(result, "")
})

# ==============================================================================
# process Tests
# ==============================================================================

test_that("process returns complete structure", {
  heat_matrix <- matrix(1:4, nrow = 2, ncol = 2)
  rownames(heat_matrix) <- c("R1", "R2")
  colnames(heat_matrix) <- c("C1", "C2")

  layer_info <- create_heatmap_layer_info(
    heat_matrix = heat_matrix,
    main = "Test",
    xlab = "X",
    ylab = "Y"
  )
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL,
    list(),
    layer_info = layer_info,
    gt = NULL
  )

  testthat::expect_type(result, "list")
  testthat::expect_true("data" %in% names(result))
  testthat::expect_true("selectors" %in% names(result))
  testthat::expect_true("type" %in% names(result))
  testthat::expect_true("title" %in% names(result))
  testthat::expect_true("axes" %in% names(result))
  testthat::expect_equal(result$type, "heat")
})

test_that("process includes domMapping", {
  heat_matrix <- matrix(1:4, nrow = 2, ncol = 2)

  layer_info <- create_heatmap_layer_info(heat_matrix = heat_matrix)
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$process(NULL, list(), layer_info = layer_info, gt = NULL)

  testthat::expect_true("domMapping" %in% names(result))
  testthat::expect_equal(result$domMapping$order, "row")
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Heatmap processor works with real heatmap call", {
  testthat::skip_if_not_installed("ggplotify")

  setup_clean_state()

  # Simulate logged heatmap call
  heat_matrix <- matrix(c(1, 2, 3, 4, 5, 6), nrow = 2, ncol = 3)
  rownames(heat_matrix) <- c("Gene1", "Gene2")
  colnames(heat_matrix) <- c("Sample1", "Sample2", "Sample3")

  layer_info <- create_heatmap_layer_info(
    heat_matrix = heat_matrix,
    main = "Gene Expression",
    xlab = "Samples",
    ylab = "Genes"
  )
  processor <- maidr:::BaseRHeatmapLayerProcessor$new(layer_info)

  result <- processor$process(NULL, list(), layer_info = layer_info, gt = NULL)

  testthat::expect_equal(result$type, "heat")
  testthat::expect_equal(result$title, "Gene Expression")
  testthat::expect_equal(result$axes$x, "Samples")
  testthat::expect_equal(result$axes$y, "Genes")
  testthat::expect_equal(length(result$data$x), 3)
  testthat::expect_equal(length(result$data$y), 2)

  setup_clean_state()
})
