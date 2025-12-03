# Comprehensive tests for Ggplot2PlotOrchestrator
# Testing layer detection, processing, and orchestration

# ==============================================================================
# Basic Orchestrator Initialization
# ==============================================================================

test_that("Ggplot2PlotOrchestrator initializes with bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
  testthat::expect_true(R6::is.R6(orchestrator))
})

test_that("Ggplot2PlotOrchestrator initializes with point plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
})

test_that("Ggplot2PlotOrchestrator initializes with line plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_line()

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
})

test_that("Ggplot2PlotOrchestrator initializes with histogram", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_histogram()

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
})

test_that("Ggplot2PlotOrchestrator initializes with boxplot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_boxplot()

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
})

# ==============================================================================
# Layer Detection Tests
# ==============================================================================

test_that("Orchestrator detects single layer in bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  layers <- orchestrator$get_layers()

  testthat::expect_type(layers, "list")
  testthat::expect_gte(length(layers), 1)
})

test_that("Orchestrator detects layer type correctly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  layers <- orchestrator$get_layers()
  layer1 <- layers[[1]]

  testthat::expect_true("type" %in% names(layer1))
  testthat::expect_equal(layer1$type, "bar")
})

test_that("Orchestrator detects multiple layers", {
  testthat::skip("Multiple layer detection needs data scope fix")

  testthat::skip_if_not_installed("ggplot2")

  # Create plot with multiple layers (use existing data in plot)
  p <- create_test_ggplot_bar() +
    ggplot2::geom_point(ggplot2::aes(y = mpg))

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  layers <- orchestrator$get_layers()

  testthat::expect_gte(length(layers), 2)
})

test_that("Layer info contains required fields", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  layers <- orchestrator$get_layers()
  layer1 <- layers[[1]]

  # Check required fields
  testthat::expect_true("index" %in% names(layer1))
  testthat::expect_true("type" %in% names(layer1))
  testthat::expect_true("geom_class" %in% names(layer1))
  testthat::expect_true("stat_class" %in% names(layer1))
  testthat::expect_true("position_class" %in% names(layer1))
})

# ==============================================================================
# Layer Processor Creation Tests
# ==============================================================================

test_that("Orchestrator creates layer processors", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  processors <- orchestrator$get_layer_processors()

  testthat::expect_type(processors, "list")
  testthat::expect_gte(length(processors), 1)
})

test_that("Layer processor inherits from LayerProcessor", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "LayerProcessor")
  testthat::expect_true(R6::is.R6(processor1))
})

test_that("Correct processor created for bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "Ggplot2BarLayerProcessor")
})

test_that("Correct processor created for point plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "Ggplot2PointLayerProcessor")
})

test_that("Correct processor created for line plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_line()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "Ggplot2LineLayerProcessor")
})

# ==============================================================================
# Layer Processing Tests
# ==============================================================================

test_that("Orchestrator processes layers successfully", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  # Processing happens in initialize, verify it worked
  data <- orchestrator$get_combined_data()

  testthat::expect_type(data, "list")
  testthat::expect_gte(length(data), 1)
})

test_that("Combined data is generated", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  data <- orchestrator$get_combined_data()

  testthat::expect_type(data, "list")
})

test_that("Orchestrator generates MAIDR data", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  maidr_data <- orchestrator$generate_maidr_data()

  testthat::expect_type(maidr_data, "list")
})

# ==============================================================================
# Faceted Plot Tests
# ==============================================================================

test_that("Orchestrator detects faceted plots", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~cyl)

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_true(orchestrator$is_faceted_plot())
})

test_that("Simple plots are not detected as faceted", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_false(orchestrator$is_faceted_plot())
})

# ==============================================================================
# Patchwork Detection Tests
# ==============================================================================

test_that("Simple plots are not detected as patchwork", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_false(orchestrator$is_patchwork_plot())
})

# ==============================================================================
# Different Plot Type Tests
# ==============================================================================

test_that("Orchestrator handles histogram correctly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_histogram()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  layers <- orchestrator$get_layers()
  testthat::expect_equal(layers[[1]]$type, "hist")

  processors <- orchestrator$get_layer_processors()
  testthat::expect_s3_class(processors[[1]], "Ggplot2HistogramLayerProcessor")
})

test_that("Orchestrator handles boxplot correctly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_boxplot()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  layers <- orchestrator$get_layers()
  testthat::expect_equal(layers[[1]]$type, "box")

  processors <- orchestrator$get_layer_processors()
  testthat::expect_s3_class(processors[[1]], "Ggplot2BoxplotLayerProcessor")
})

test_that("Orchestrator handles dodged bars correctly", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "dodge")

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  layers <- orchestrator$get_layers()
  testthat::expect_equal(layers[[1]]$type, "dodged_bar")
})

test_that("Orchestrator handles stacked bars correctly", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "stack")

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  layers <- orchestrator$get_layers()
  testthat::expect_equal(layers[[1]]$type, "stacked_bar")
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Orchestrator handles plot with theme modifications", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar() +
    ggplot2::theme_minimal() +
    ggplot2::labs(title = "Test Plot")

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
})

test_that("Orchestrator handles plot with custom labels", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar() +
    ggplot2::xlab("Custom X") +
    ggplot2::ylab("Custom Y")

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
})
