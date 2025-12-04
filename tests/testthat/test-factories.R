# Comprehensive tests for Processor Factories
# Testing ProcessorFactory base class, Ggplot2ProcessorFactory, and BaseRProcessorFactory

# ==============================================================================
# ProcessorFactory Base Class Tests
# ==============================================================================

test_that("ProcessorFactory base class can be instantiated", {
  factory <- maidr:::ProcessorFactory$new()

  testthat::expect_s3_class(factory, "ProcessorFactory")
  testthat::expect_true(R6::is.R6(factory))
})

test_that("ProcessorFactory create_processor is abstract", {
  factory <- maidr:::ProcessorFactory$new()

  testthat::expect_error(
    factory$create_processor("bar", list()),
    "create_processor method must be implemented by subclass"
  )
})

test_that("ProcessorFactory get_supported_types is abstract", {
  factory <- maidr:::ProcessorFactory$new()

  testthat::expect_error(
    factory$get_supported_types(),
    "get_supported_types method must be implemented by subclass"
  )
})

test_that("ProcessorFactory get_system_name returns unknown", {
  factory <- maidr:::ProcessorFactory$new()

  result <- factory$get_system_name()
  testthat::expect_equal(result, "unknown")
})

test_that("ProcessorFactory supports_plot_type calls get_supported_types", {
  factory <- maidr:::ProcessorFactory$new()

  # This will fail because get_supported_types is abstract
  testthat::expect_error(
    factory$supports_plot_type("bar"),
    "get_supported_types method must be implemented by subclass"
  )
})

# ==============================================================================
# Ggplot2ProcessorFactory Initialization Tests
# ==============================================================================

test_that("Ggplot2ProcessorFactory initializes correctly", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  testthat::expect_s3_class(factory, "Ggplot2ProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
  testthat::expect_true(R6::is.R6(factory))
})

test_that("Ggplot2ProcessorFactory get_system_name returns ggplot2", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  result <- factory$get_system_name()
  testthat::expect_equal(result, "ggplot2")
})

test_that("Ggplot2ProcessorFactory get_supported_types returns expected types", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  types <- factory$get_supported_types()

  testthat::expect_type(types, "character")
  testthat::expect_true("bar" %in% types)
  testthat::expect_true("point" %in% types)
  testthat::expect_true("line" %in% types)
  testthat::expect_true("hist" %in% types)
  testthat::expect_true("box" %in% types)
  testthat::expect_true("heat" %in% types)
  testthat::expect_true("smooth" %in% types)
  testthat::expect_true("dodged_bar" %in% types)
  testthat::expect_true("stacked_bar" %in% types)
  testthat::expect_true("unknown" %in% types)
})

test_that("Ggplot2ProcessorFactory supports_plot_type works correctly", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  testthat::expect_true(factory$supports_plot_type("bar"))
  testthat::expect_true(factory$supports_plot_type("point"))
  testthat::expect_true(factory$supports_plot_type("line"))
  testthat::expect_true(factory$supports_plot_type("unknown"))
  testthat::expect_false(factory$supports_plot_type("unsupported_type"))
  testthat::expect_false(factory$supports_plot_type("random"))
})

# ==============================================================================
# Ggplot2ProcessorFactory create_processor Tests
# ==============================================================================

test_that("Ggplot2ProcessorFactory create_processor errors on NULL layer_info", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  testthat::expect_error(
    factory$create_processor("bar", NULL),
    "Layer info must be provided"
  )
})

test_that("Ggplot2ProcessorFactory creates bar processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("bar", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2BarLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates point processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("point", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2PointLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates line processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("line", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2LineLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates histogram processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("hist", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2HistogramLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates boxplot processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("box", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2BoxplotLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates heatmap processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("heat", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2HeatmapLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates smooth processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("smooth", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2SmoothLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates dodged_bar processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("dodged_bar", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2DodgedBarLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates stacked_bar processor", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("stacked_bar", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2StackedBarProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("Ggplot2ProcessorFactory creates unknown processor for unrecognized types", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("unsupported_type", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2UnknownLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

# ==============================================================================
# Ggplot2ProcessorFactory Utility Methods Tests
# ==============================================================================

test_that("Ggplot2ProcessorFactory is_processor_available returns logical", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  # Method should return logical values
  result1 <- factory$is_processor_available("Ggplot2BarLayerProcessor")
  result2 <- factory$is_processor_available("NonExistentProcessor")

  testthat::expect_type(result1, "logical")
  testthat::expect_type(result2, "logical")

  # Non-existent classes should not be available
  testthat::expect_false(factory$is_processor_available("NonExistentProcessor"))
  testthat::expect_false(factory$is_processor_available("FakeProcessor"))
})

test_that("Ggplot2ProcessorFactory get_available_processors returns character vector", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  processors <- factory$get_available_processors()

  # Should return character vector (may be empty if exists() doesn't find R6 classes)
  testthat::expect_type(processors, "character")
})

test_that("Ggplot2ProcessorFactory try_create_processor handles valid types", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$try_create_processor("bar", layer_info)

  testthat::expect_s3_class(processor, "Ggplot2BarLayerProcessor")
})

test_that("Ggplot2ProcessorFactory try_create_processor falls back on error", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  # Passing NULL should trigger error handling and fallback
  result <- suppressWarnings(factory$try_create_processor("bar", NULL))

  # Should fall back to unknown processor or NULL
  testthat::expect_true(
    is.null(result) || inherits(result, "Ggplot2UnknownLayerProcessor")
  )
})

# ==============================================================================
# BaseRProcessorFactory Initialization Tests
# ==============================================================================

test_that("BaseRProcessorFactory initializes correctly", {
  factory <- maidr:::BaseRProcessorFactory$new()

  testthat::expect_s3_class(factory, "BaseRProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
  testthat::expect_true(R6::is.R6(factory))
})

test_that("BaseRProcessorFactory get_system_name returns base_r", {
  factory <- maidr:::BaseRProcessorFactory$new()

  result <- factory$get_system_name()
  testthat::expect_equal(result, "base_r")
})

test_that("BaseRProcessorFactory get_supported_types returns expected types", {
  factory <- maidr:::BaseRProcessorFactory$new()

  types <- factory$get_supported_types()

  testthat::expect_type(types, "character")
  testthat::expect_true("bar" %in% types)
  testthat::expect_true("point" %in% types)
  testthat::expect_true("line" %in% types)
  testthat::expect_true("hist" %in% types)
  testthat::expect_true("box" %in% types)
  testthat::expect_true("heat" %in% types)
  testthat::expect_true("smooth" %in% types)
  testthat::expect_true("dodged_bar" %in% types)
  testthat::expect_true("stacked_bar" %in% types)
  testthat::expect_true("contour" %in% types)
  testthat::expect_true("unknown" %in% types)
})

test_that("BaseRProcessorFactory supports_plot_type works correctly", {
  factory <- maidr:::BaseRProcessorFactory$new()

  testthat::expect_true(factory$supports_plot_type("bar"))
  testthat::expect_true(factory$supports_plot_type("point"))
  testthat::expect_true(factory$supports_plot_type("line"))
  testthat::expect_true(factory$supports_plot_type("contour"))
  testthat::expect_true(factory$supports_plot_type("unknown"))
  testthat::expect_false(factory$supports_plot_type("unsupported_type"))
})

# ==============================================================================
# BaseRProcessorFactory create_processor Tests
# ==============================================================================

test_that("BaseRProcessorFactory create_processor errors on NULL layer_info", {
  factory <- maidr:::BaseRProcessorFactory$new()

  testthat::expect_error(
    factory$create_processor("bar", NULL),
    "Layer info must be provided"
  )
})

test_that("BaseRProcessorFactory creates bar processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("bar", layer_info)

  testthat::expect_s3_class(processor, "BaseRBarplotLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates point processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("point", layer_info)

  testthat::expect_s3_class(processor, "BaseRPointLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates line processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("line", layer_info)

  testthat::expect_s3_class(processor, "BaseRLineLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates histogram processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("hist", layer_info)

  testthat::expect_s3_class(processor, "BaseRHistogramLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates boxplot processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("box", layer_info)

  testthat::expect_s3_class(processor, "BaseRBoxplotLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates heatmap processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("heat", layer_info)

  testthat::expect_s3_class(processor, "BaseRHeatmapLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates smooth processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("smooth", layer_info)

  testthat::expect_s3_class(processor, "BaseRSmoothLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates dodged_bar processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("dodged_bar", layer_info)

  testthat::expect_s3_class(processor, "BaseRDodgedBarLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates stacked_bar processor", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("stacked_bar", layer_info)

  testthat::expect_s3_class(processor, "BaseRStackedBarLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates unknown processor for contour", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("contour", layer_info)

  testthat::expect_s3_class(processor, "BaseRUnknownLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

test_that("BaseRProcessorFactory creates unknown processor for unrecognized types", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$create_processor("unsupported_type", layer_info)

  testthat::expect_s3_class(processor, "BaseRUnknownLayerProcessor")
  testthat::expect_s3_class(processor, "LayerProcessor")
})

# ==============================================================================
# BaseRProcessorFactory Utility Methods Tests
# ==============================================================================

test_that("BaseRProcessorFactory is_processor_available returns logical", {
  factory <- maidr:::BaseRProcessorFactory$new()

  # Method should return logical values
  result1 <- factory$is_processor_available("BaseRBarplotLayerProcessor")
  result2 <- factory$is_processor_available("NonExistentProcessor")

  testthat::expect_type(result1, "logical")
  testthat::expect_type(result2, "logical")

  # Non-existent classes should not be available
  testthat::expect_false(factory$is_processor_available("NonExistentProcessor"))
  testthat::expect_false(factory$is_processor_available("FakeProcessor"))
})

test_that("BaseRProcessorFactory get_available_processors returns character vector", {
  factory <- maidr:::BaseRProcessorFactory$new()

  processors <- factory$get_available_processors()

  # Should return character vector (may be empty if exists() doesn't find R6 classes)
  testthat::expect_type(processors, "character")
})

test_that("BaseRProcessorFactory try_create_processor handles valid types", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1)

  processor <- factory$try_create_processor("bar", layer_info)

  testthat::expect_s3_class(processor, "BaseRBarplotLayerProcessor")
})

test_that("BaseRProcessorFactory try_create_processor falls back on error", {
  factory <- maidr:::BaseRProcessorFactory$new()

  # Passing NULL should trigger error handling and fallback
  result <- suppressWarnings(factory$try_create_processor("bar", NULL))

  # Should fall back to unknown processor or NULL
  testthat::expect_true(
    is.null(result) || inherits(result, "BaseRUnknownLayerProcessor")
  )
})

# ==============================================================================
# Factory Comparison Tests
# ==============================================================================

test_that("Both factories support same core plot types", {
  ggplot2_factory <- maidr:::Ggplot2ProcessorFactory$new()
  base_r_factory <- maidr:::BaseRProcessorFactory$new()

  core_types <- c("bar", "point", "line", "hist", "box", "heat", "smooth")

  for (type in core_types) {
    testthat::expect_true(
      ggplot2_factory$supports_plot_type(type),
      info = paste("ggplot2 should support", type)
    )
    testthat::expect_true(
      base_r_factory$supports_plot_type(type),
      info = paste("base_r should support", type)
    )
  }
})

test_that("Factories have different system names", {
  ggplot2_factory <- maidr:::Ggplot2ProcessorFactory$new()
  base_r_factory <- maidr:::BaseRProcessorFactory$new()

  testthat::expect_equal(ggplot2_factory$get_system_name(), "ggplot2")
  testthat::expect_equal(base_r_factory$get_system_name(), "base_r")
  testthat::expect_false(
    ggplot2_factory$get_system_name() == base_r_factory$get_system_name()
  )
})

test_that("Both factories create processors with correct layer_info", {
  ggplot2_factory <- maidr:::Ggplot2ProcessorFactory$new()
  base_r_factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 5, type = "bar")

  ggplot2_processor <- ggplot2_factory$create_processor("bar", layer_info)
  base_r_processor <- base_r_factory$create_processor("bar", layer_info)

  testthat::expect_equal(ggplot2_processor$get_layer_index(), 5)
  testthat::expect_equal(base_r_processor$get_layer_index(), 5)
})
