# Comprehensive tests for BaseRPlotOrchestrator
# Testing call capture, layer detection, and processing for Base R plots

# ==============================================================================
# Basic Orchestrator Initialization
# ==============================================================================

test_that("BaseRPlotOrchestrator initializes with barplot", {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")
  testthat::expect_true(R6::is.R6(orchestrator))

  clear_base_r_state()
})

test_that("BaseRPlotOrchestrator initializes with hist", {
  hist(mtcars$mpg)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

test_that("BaseRPlotOrchestrator initializes with boxplot", {
  boxplot(mpg ~ cyl, data = mtcars)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

# ==============================================================================
# Layer Detection Tests
# ==============================================================================

test_that("Orchestrator detects layers in barplot", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  testthat::expect_type(layers, "list")
  testthat::expect_gte(length(layers), 1)

  clear_base_r_state()
})

test_that("Orchestrator detects correct layer type for barplot", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  layer1 <- layers[[1]]

  testthat::expect_true("type" %in% names(layer1))
  testthat::expect_equal(layer1$type, "bar")

  clear_base_r_state()
})

test_that("Layer info contains required fields", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  layer1 <- layers[[1]]

  # Check required fields
  testthat::expect_true("index" %in% names(layer1))
  testthat::expect_true("type" %in% names(layer1))
  testthat::expect_true("function_name" %in% names(layer1))
  testthat::expect_true("args" %in% names(layer1))

  clear_base_r_state()
})

test_that("Orchestrator detects histogram layers", {
  hist(mtcars$mpg)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  testthat::expect_gte(length(layers), 1)
  testthat::expect_equal(layers[[1]]$type, "hist")

  clear_base_r_state()
})

test_that("Orchestrator detects boxplot layers", {
  boxplot(mpg ~ cyl, data = mtcars)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  testthat::expect_gte(length(layers), 1)
  testthat::expect_equal(layers[[1]]$type, "box")

  clear_base_r_state()
})

# ==============================================================================
# Layer Processor Creation Tests
# ==============================================================================

test_that("Orchestrator creates layer processors", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()

  testthat::expect_type(processors, "list")
  testthat::expect_gte(length(processors), 1)

  clear_base_r_state()
})

test_that("Layer processor inherits from LayerProcessor", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "LayerProcessor")
  testthat::expect_true(R6::is.R6(processor1))

  clear_base_r_state()
})

test_that("Correct processor created for barplot", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "BaseRBarplotLayerProcessor")

  clear_base_r_state()
})

test_that("Correct processor created for histogram", {
  hist(mtcars$mpg)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "BaseRHistogramLayerProcessor")

  clear_base_r_state()
})

test_that("Correct processor created for boxplot", {
  boxplot(mpg ~ cyl, data = mtcars)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "BaseRBoxplotLayerProcessor")

  clear_base_r_state()
})

# ==============================================================================
# Layer Processing Tests
# ==============================================================================

test_that("Orchestrator processes layers successfully", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  # Processing happens in initialize, verify it worked
  data <- orchestrator$get_combined_data()

  testthat::expect_type(data, "list")
  testthat::expect_gte(length(data), 1)

  clear_base_r_state()
})

test_that("Combined data is generated", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  data <- orchestrator$get_combined_data()

  testthat::expect_type(data, "list")

  clear_base_r_state()
})

test_that("Orchestrator generates MAIDR data", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  maidr_data <- orchestrator$generate_maidr_data()

  testthat::expect_type(maidr_data, "list")

  clear_base_r_state()
})

# ==============================================================================
# Different Plot Type Tests
# ==============================================================================

test_that("Orchestrator handles dodged barplot", {
  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  barplot(test_matrix, beside = TRUE)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  # Dodged bar may be detected as regular bar or dodged_bar
  testthat::expect_true(layers[[1]]$type %in% c("bar", "dodged_bar"))

  processors <- orchestrator$get_layer_processors()
  # Processor class depends on detection
  testthat::expect_true(inherits(processors[[1]], "LayerProcessor"))

  clear_base_r_state()
})

test_that("Orchestrator handles stacked barplot", {
  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  barplot(test_matrix, beside = FALSE)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  testthat::expect_equal(layers[[1]]$type, "stacked_bar")

  processors <- orchestrator$get_layer_processors()
  testthat::expect_s3_class(processors[[1]], "BaseRStackedBarLayerProcessor")

  clear_base_r_state()
})

# ==============================================================================
# Call Capture Tests
# ==============================================================================

test_that("Orchestrator captures plot calls", {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  plot_calls <- orchestrator$get_plot_calls()

  testthat::expect_type(plot_calls, "list")
  testthat::expect_gte(length(plot_calls), 1)

  clear_base_r_state()
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Orchestrator handles barplot with custom parameters", {
  barplot(c(10, 20, 30),
    names.arg = c("A", "B", "C"),
    col = "blue",
    main = "Test Plot"
  )

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

test_that("Orchestrator handles histogram with breaks", {
  hist(mtcars$mpg, breaks = 10)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

test_that("Orchestrator handles boxplot with notch", {
  boxplot(mpg ~ cyl, data = mtcars, notch = TRUE)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

# ==============================================================================
# Multiple Layer Tests
# ==============================================================================

test_that("Orchestrator handles plots with low-level additions", {
  barplot(c(10, 20, 30))
  # Add low-level call
  abline(h = 15, col = "red")

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  # Should detect both high-level (barplot) and potentially low-level (abline)
  testthat::expect_gte(length(layers), 1)

  clear_base_r_state()
})

# ==============================================================================
# Grob Management Tests
# ==============================================================================

test_that("Orchestrator can generate gtable", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  gt <- orchestrator$get_gtable()

  testthat::expect_true(!is.null(gt))

  clear_base_r_state()
})
