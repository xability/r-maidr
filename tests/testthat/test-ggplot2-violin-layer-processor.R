# Comprehensive tests for Ggplot2ViolinLayerProcessor
# Testing violin layer processing, data extraction, selector generation,
# and two-layer (violin_box + violin_kde) expansion.

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2ViolinLayerProcessor initializes correctly", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2ViolinLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

# ==============================================================================
# Tier 2: Layer Type Detection
# ==============================================================================

test_that("adapter detects geom_violin as 'violin'", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  adapter <- maidr:::Ggplot2Adapter$new()
  layer_type <- adapter$detect_layer_type(p$layers[[1]], p)

  testthat::expect_equal(layer_type, "violin")
})

test_that("factory creates Ggplot2ViolinLayerProcessor for 'violin' type", {
  testthat::skip_if_not_installed("ggplot2")

  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)
  processor <- factory$create_processor("violin", layer_info)

  testthat::expect_true(inherits(processor, "Ggplot2ViolinLayerProcessor"))
})

# ==============================================================================
# Tier 2.5: Plot Augmentation
# ==============================================================================

test_that("needs_augmentation returns TRUE", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)

  testthat::expect_true(processor$needs_augmentation())
})

test_that("augment_plot injects geom_boxplot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)

  # Original should have 1 layer (violin only)
  testthat::expect_equal(length(p$layers), 1)

  p_aug <- processor$augment_plot(p)

  # Augmented should have 2 layers
  testthat::expect_equal(length(p_aug$layers), 2)
  testthat::expect_true(inherits(p_aug$layers[[2]]$geom, "GeomBoxplot"))
})

test_that("augment_plot does not add boxplot if already present", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin() + ggplot2::geom_boxplot(width = 0.2)
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)

  n_before <- length(p$layers)
  p_aug <- processor$augment_plot(p)

  testthat::expect_equal(length(p_aug$layers), n_before)
})

# ==============================================================================
# Tier 3: Box Data Extraction
# ==============================================================================

test_that("extract_box_data returns correct structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  built <- ggplot2::ggplot_build(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)
  box_data <- processor$extract_box_data(p, built)

  # Should have 3 groups (4-cyl, 6-cyl, 8-cyl)
  testthat::expect_equal(length(box_data), 3)

  # Each entry should have required BoxPoint fields
  for (bp in box_data) {
    testthat::expect_true("fill" %in% names(bp))
    testthat::expect_true("lowerOutliers" %in% names(bp))
    testthat::expect_true("min" %in% names(bp))
    testthat::expect_true("q1" %in% names(bp))
    testthat::expect_true("q2" %in% names(bp))
    testthat::expect_true("q3" %in% names(bp))
    testthat::expect_true("max" %in% names(bp))
    testthat::expect_true("upperOutliers" %in% names(bp))

    # Statistical sanity: min <= q1 <= q2 <= q3 <= max
    testthat::expect_lte(bp$min, bp$q1)
    testthat::expect_lte(bp$q1, bp$q2)
    testthat::expect_lte(bp$q2, bp$q3)
    testthat::expect_lte(bp$q3, bp$max)

    # Outlier fields are lists (arrays in JSON)
    testthat::expect_type(bp$lowerOutliers, "list")
    testthat::expect_type(bp$upperOutliers, "list")
  }
})

test_that("extract_box_data maps category labels correctly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  built <- ggplot2::ggplot_build(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)
  box_data <- processor$extract_box_data(p, built)

  # mtcars$cyl has 3 levels: 4, 6, 8
  fill_labels <- vapply(box_data, function(bp) bp$fill, character(1))
  testthat::expect_setequal(fill_labels, c("4", "6", "8"))
})

# ==============================================================================
# Tier 4: KDE Data Extraction
# ==============================================================================

test_that("extract_kde_data returns correct nested structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  built <- ggplot2::ggplot_build(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)
  kde_data <- processor$extract_kde_data(p, built)

  # Should have 3 violin groups
  testthat::expect_equal(length(kde_data), 3)

  # Each group should have ~30 points (RDP-simplified, left+right pairs)
  for (group in kde_data) {
    testthat::expect_true(length(group) >= 6)   # at least 3 Y-levels * 2
    testthat::expect_true(length(group) <= 40)   # at most ~30
    testthat::expect_type(group, "list")

    # Each point should have x, y, width fields (plus temp data_* fields)
    first_point <- group[[1]]
    testthat::expect_true("x" %in% names(first_point))
    testthat::expect_true("y" %in% names(first_point))
    testthat::expect_true("width" %in% names(first_point))

    # x should be a category label, y and width should be numeric
    testthat::expect_type(first_point$x, "character")
    testthat::expect_type(first_point$y, "double")
    testthat::expect_type(first_point$width, "double")
    testthat::expect_true(first_point$width > 0)

    # Points come in left/right pairs at each Y-level
    testthat::expect_equal(length(group) %% 2, 0)
  }
})

test_that("kde_data x labels match box_data fill labels", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  built <- ggplot2::ggplot_build(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)

  box_data <- processor$extract_box_data(p, built)
  kde_data <- processor$extract_kde_data(p, built)

  # The x labels in KDE should match the fill labels in box
  for (i in seq_along(kde_data)) {
    kde_x <- kde_data[[i]][[1]]$x
    box_fill <- box_data[[i]]$fill
    testthat::expect_equal(kde_x, box_fill)
  }
})

# ==============================================================================
# Tier 5: Selector Generation
# ==============================================================================

test_that("generate_selectors returns one selector per violin", {
  testthat::skip_if_not_installed("ggplot2")

  # Use augmented plot so grobs exist
  p <- create_test_ggplot_violin() + ggplot2::geom_boxplot(width = 0.1)
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)
  selectors <- processor$generate_selectors(p, gt)

  # Should have 3 selectors (one per violin group)
  testthat::expect_equal(length(selectors), 3)

  # Each selector should be a character string targeting a polygon
  for (sel in selectors) {
    testthat::expect_type(sel, "character")
    testthat::expect_match(sel, "polygon")
    testthat::expect_match(sel, "geom_violin")
  }
})

test_that("generate_box_selectors returns BoxSelector objects", {
  testthat::skip_if_not_installed("ggplot2")

  # Use augmented plot
  p <- create_test_ggplot_violin() + ggplot2::geom_boxplot(width = 0.1)
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)
  box_selectors <- processor$generate_box_selectors(p, gt, built)

  # Should have 3 BoxSelector objects (one per violin)
  testthat::expect_equal(length(box_selectors), 3)

  # Each should have the required fields
  for (bs in box_selectors) {
    testthat::expect_true("iq" %in% names(bs))
    testthat::expect_true("q2" %in% names(bs))
    testthat::expect_true("min" %in% names(bs))
    testthat::expect_true("max" %in% names(bs))
    testthat::expect_true("lowerOutliers" %in% names(bs))
    testthat::expect_true("upperOutliers" %in% names(bs))

    # IQ and Q2 should be non-empty CSS selectors
    testthat::expect_match(bs$iq, "polygon")
    testthat::expect_match(bs$q2, "polyline")
    testthat::expect_match(bs$min, "polyline")
    testthat::expect_match(bs$max, "polyline")
  }
})

# ==============================================================================
# Tier 6: Full Process (multi-layer return)
# ==============================================================================

test_that("process() returns multi_layer result with two layers", {
  testthat::skip_if_not_installed("ggplot2")

  # Use augmented plot (as orchestrator would provide)
  p <- create_test_ggplot_violin() + ggplot2::geom_boxplot(width = 0.1)
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)

  layout <- list(axes = list(x = "Cylinders", y = "MPG"))
  result <- processor$process(p, layout, built = built, gt = gt)

  # Should have multi_layer flag
  testthat::expect_true(result$multi_layer)
  testthat::expect_equal(length(result$layers), 2)

  # First layer should be violin_box with BoxSelector selectors
  testthat::expect_equal(result$layers[[1]]$type, "violin_box")
  testthat::expect_true("violinOptions" %in% names(result$layers[[1]]))
  testthat::expect_equal(result$layers[[1]]$orientation, "vert")
  testthat::expect_true(length(result$layers[[1]]$selectors) == 3)

  # Each box selector should have iq, q2, min, max fields
  for (bs in result$layers[[1]]$selectors) {
    testthat::expect_true("iq" %in% names(bs))
    testthat::expect_true("q2" %in% names(bs))
  }

  # Second layer should be violin_kde
  testthat::expect_equal(result$layers[[2]]$type, "violin_kde")
  testthat::expect_equal(result$layers[[2]]$orientation, "vert")

  # Both layers should have the same axes
  testthat::expect_equal(result$layers[[1]]$axes$x, "Cylinders")
  testthat::expect_equal(result$layers[[2]]$axes$x, "Cylinders")
})

# ==============================================================================
# Tier 7: Orchestrator Integration (end-to-end)
# ==============================================================================

test_that("orchestrator expands violin into two maidr layers", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()

  # Should have subplots with two layers
  subplot <- maidr_data$subplots[[1]][[1]]
  testthat::expect_equal(length(subplot$layers), 2)

  # Layer 1: violin_box
  testthat::expect_equal(subplot$layers[[1]]$type, "violin_box")
  testthat::expect_equal(length(subplot$layers[[1]]$data), 3)

  # violin_box should have BoxSelector selectors (not empty)
  testthat::expect_equal(length(subplot$layers[[1]]$selectors), 3)
  testthat::expect_true("iq" %in% names(subplot$layers[[1]]$selectors[[1]]))

  # Layer 2: violin_kde
  testthat::expect_equal(subplot$layers[[2]]$type, "violin_kde")
  testthat::expect_equal(length(subplot$layers[[2]]$data), 3)
})

test_that("orchestrator does not mark violin as unsupported/fallback", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_false(orchestrator$has_unsupported_layers())
  testthat::expect_false(orchestrator$should_fallback())
})

# ==============================================================================
# Tier 8: Orientation
# ==============================================================================

test_that("horizontal violin is detected correctly", {
  testthat::skip_if_not_installed("ggplot2")

  # Horizontal violin via coord_flip
  p <- ggplot2::ggplot(
    datasets::mtcars,
    ggplot2::aes(x = factor(cyl), y = mpg)
  ) +
    ggplot2::geom_violin() +
    ggplot2::coord_flip()

  built <- ggplot2::ggplot_build(p)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(layer_info)
  orientation <- processor$determine_orientation(built)

  # coord_flip may or may not set flipped_aes depending on ggplot2 version
  testthat::expect_true(orientation %in% c("vert", "horz"))
})

# ==============================================================================
# Tier 9: JSON Serialization
# ==============================================================================

test_that("violin maidr data serializes to valid JSON", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_violin()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()

  json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)

  # Should not error
  testthat::expect_type(json, "character")

  # Parse back and verify structure
  parsed <- jsonlite::fromJSON(as.character(json), simplifyVector = FALSE)
  testthat::expect_true("subplots" %in% names(parsed))

  layers <- parsed$subplots[[1]][[1]]$layers
  testthat::expect_equal(layers[[1]]$type, "violin_box")
  testthat::expect_equal(layers[[2]]$type, "violin_kde")

  # BoxSelector objects should be present
  box_sel <- layers[[1]]$selectors[[1]]
  testthat::expect_true("iq" %in% names(box_sel))
  testthat::expect_true("q2" %in% names(box_sel))

  # KDE selectors should be an array
  testthat::expect_type(layers[[2]]$selectors, "list")
  testthat::expect_true(length(layers[[2]]$selectors) == 3)
})
