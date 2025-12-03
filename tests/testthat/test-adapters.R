# Comprehensive tests for System Adapters
# Testing adapter detection, layer type identification, and orchestrator creation

# ==============================================================================
# SystemAdapter Base Class Tests
# ==============================================================================

test_that("SystemAdapter initialize sets system_name", {
  adapter <- maidr:::SystemAdapter$new("test_system")

  testthat::expect_equal(adapter$system_name, "test_system")
})

test_that("SystemAdapter can_handle is abstract (must be implemented)", {
  adapter <- maidr:::SystemAdapter$new("test_system")

  testthat::expect_error(
    adapter$can_handle(NULL),
    "can_handle method must be implemented by subclass"
  )
})

test_that("SystemAdapter create_orchestrator is abstract (must be implemented)", {
  adapter <- maidr:::SystemAdapter$new("test_system")

  testthat::expect_error(
    adapter$create_orchestrator(NULL),
    "create_orchestrator method must be implemented by subclass"
  )
})

# ==============================================================================
# Ggplot2Adapter - Initialization Tests
# ==============================================================================

test_that("Ggplot2Adapter initializes correctly", {
  adapter <- maidr:::Ggplot2Adapter$new()

  testthat::expect_s3_class(adapter, "Ggplot2Adapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
  testthat::expect_equal(adapter$system_name, "ggplot2")
})

test_that("Ggplot2Adapter inherits from SystemAdapter", {
  adapter <- maidr:::Ggplot2Adapter$new()

  testthat::expect_true(inherits(adapter, "SystemAdapter"))
})

# ==============================================================================
# Ggplot2Adapter - can_handle() Tests
# ==============================================================================

test_that("Ggplot2Adapter can_handle detects ggplot objects", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_bar()

  result <- adapter$can_handle(p)
  testthat::expect_true(result)
})

test_that("Ggplot2Adapter can_handle rejects non-ggplot objects", {
  adapter <- maidr:::Ggplot2Adapter$new()

  testthat::expect_false(adapter$can_handle(NULL))
  testthat::expect_false(adapter$can_handle(list(a = 1)))
  testthat::expect_false(adapter$can_handle(42))
  testthat::expect_false(adapter$can_handle("plot"))
})

test_that("Ggplot2Adapter can_handle works with all ggplot types", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()

  plot_generators <- list(
    create_test_ggplot_bar,
    create_test_ggplot_point,
    create_test_ggplot_line,
    create_test_ggplot_histogram,
    create_test_ggplot_boxplot
  )

  for (plot_fn in plot_generators) {
    p <- plot_fn()
    testthat::expect_true(adapter$can_handle(p))
  }
})

# ==============================================================================
# Ggplot2Adapter - detect_layer_type() Tests
# ==============================================================================

test_that("Ggplot2Adapter detect_layer_type detects bar plots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_bar()
  built <- ggplot2::ggplot_build(p)
  layer <- p$layers[[1]]

  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "bar")
})

test_that("Ggplot2Adapter detect_layer_type detects point plots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_point()
  layer <- p$layers[[1]]

  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "point")
})

test_that("Ggplot2Adapter detect_layer_type detects line plots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_line()
  layer <- p$layers[[1]]

  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "line")
})

test_that("Ggplot2Adapter detect_layer_type detects histograms", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_histogram()
  layer <- p$layers[[1]]

  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "hist")
})

test_that("Ggplot2Adapter detect_layer_type detects boxplots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_boxplot()
  layer <- p$layers[[1]]

  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "box")
})

test_that("Ggplot2Adapter detect_layer_type detects dodged bars", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "dodge")

  layer <- p$layers[[1]]
  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "dodged_bar")
})

test_that("Ggplot2Adapter detect_layer_type detects stacked bars", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "stack")

  layer <- p$layers[[1]]
  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "stacked_bar")
})

test_that("Ggplot2Adapter detect_layer_type detects heatmaps", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()

  df <- expand.grid(x = 1:3, y = 1:3)
  df$z <- rnorm(9)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_tile()

  layer <- p$layers[[1]]
  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "heat")
})

test_that("Ggplot2Adapter detect_layer_type detects smooth plots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_smooth()

  layer <- p$layers[[1]]
  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "smooth")
})

test_that("Ggplot2Adapter detect_layer_type returns unknown for NULL", {
  adapter <- maidr:::Ggplot2Adapter$new()

  layer_type <- adapter$detect_layer_type(NULL, NULL)
  testthat::expect_equal(layer_type, "unknown")
})

test_that("Ggplot2Adapter detect_layer_type skips text layers", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_text(ggplot2::aes(label = rownames(mtcars)))

  layer <- p$layers[[1]]
  layer_type <- adapter$detect_layer_type(layer, p)
  testthat::expect_equal(layer_type, "skip")
})

# ==============================================================================
# Ggplot2Adapter - create_orchestrator() Tests
# ==============================================================================

test_that("Ggplot2Adapter create_orchestrator returns orchestrator", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_bar()

  orchestrator <- adapter$create_orchestrator(p)

  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
})

test_that("Ggplot2Adapter create_orchestrator errors for non-ggplot", {
  adapter <- maidr:::Ggplot2Adapter$new()

  testthat::expect_error(
    adapter$create_orchestrator(list(a = 1)),
    "Plot object is not a ggplot2 object"
  )
})

# ==============================================================================
# Ggplot2Adapter - Utility Methods Tests
# ==============================================================================

test_that("Ggplot2Adapter get_system_name returns ggplot2", {
  adapter <- maidr:::Ggplot2Adapter$new()

  name <- adapter$get_system_name()
  testthat::expect_equal(name, "ggplot2")
})

test_that("Ggplot2Adapter get_adapter returns self", {
  adapter <- maidr:::Ggplot2Adapter$new()

  self_ref <- adapter$get_adapter()
  testthat::expect_identical(self_ref, adapter)
})

test_that("Ggplot2Adapter has_facets detects non-faceted plots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_bar()

  result <- adapter$has_facets(p)
  testthat::expect_false(result)
})

test_that("Ggplot2Adapter has_facets detects faceted plots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~cyl)

  result <- adapter$has_facets(p)
  testthat::expect_true(result)
})

test_that("Ggplot2Adapter has_facets returns FALSE for non-ggplot", {
  adapter <- maidr:::Ggplot2Adapter$new()

  result <- adapter$has_facets(list(a = 1))
  testthat::expect_false(result)
})

test_that("Ggplot2Adapter is_patchwork returns FALSE for normal plots", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_bar()

  result <- adapter$is_patchwork(p)
  testthat::expect_false(result)
})

# ==============================================================================
# BaseRAdapter - Initialization Tests
# ==============================================================================

test_that("BaseRAdapter initializes correctly", {
  adapter <- maidr:::BaseRAdapter$new()

  testthat::expect_s3_class(adapter, "BaseRAdapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
  testthat::expect_equal(adapter$system_name, "base_r")
})

test_that("BaseRAdapter inherits from SystemAdapter", {
  adapter <- maidr:::BaseRAdapter$new()

  testthat::expect_true(inherits(adapter, "SystemAdapter"))
})

# ==============================================================================
# BaseRAdapter - can_handle() Tests
# ==============================================================================

test_that("BaseRAdapter can_handle detects Base R plots", {
  adapter <- maidr:::BaseRAdapter$new()

  barplot(c(10, 20, 30))

  result <- adapter$can_handle(NULL)
  testthat::expect_true(result)

  clear_base_r_state()
})

test_that("BaseRAdapter can_handle returns FALSE when no plot", {
  adapter <- maidr:::BaseRAdapter$new()

  clear_base_r_state()

  result <- adapter$can_handle(NULL)
  testthat::expect_false(result)
})

test_that("BaseRAdapter can_handle works with different plot types", {
  adapter <- maidr:::BaseRAdapter$new()

  # Test with histogram
  hist(rnorm(100))
  testthat::expect_true(adapter$can_handle(NULL))
  clear_base_r_state()

  # Test with boxplot
  boxplot(mpg ~ cyl, data = mtcars)
  testthat::expect_true(adapter$can_handle(NULL))
  clear_base_r_state()
})

# ==============================================================================
# BaseRAdapter - detect_layer_type() Tests
# ==============================================================================

test_that("BaseRAdapter detect_layer_type detects simple barplot", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "barplot",
    args = list(c(10, 20, 30))
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "bar")
})

test_that("BaseRAdapter detect_layer_type detects histogram", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "hist",
    args = list(rnorm(100))
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "hist")
})

test_that("BaseRAdapter detect_layer_type detects boxplot", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "boxplot",
    args = list(mpg ~ cyl)
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "box")
})

test_that("BaseRAdapter detect_layer_type detects heatmap", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "image",
    args = list(matrix(1:9, 3, 3))
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "heat")
})

test_that("BaseRAdapter detect_layer_type detects point plot", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "plot",
    args = list(1:10, rnorm(10))
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "point")
})

test_that("BaseRAdapter detect_layer_type detects line plot", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "plot",
    args = list(1:10, rnorm(10), type = "l")
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "line")
})

test_that("BaseRAdapter detect_layer_type detects lines function", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "lines",
    args = list(1:10, rnorm(10))
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "line")
})

test_that("BaseRAdapter detect_layer_type detects points function", {
  adapter <- maidr:::BaseRAdapter$new()

  layer <- list(
    function_name = "points",
    args = list(1:10, rnorm(10))
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "point")
})

test_that("BaseRAdapter detect_layer_type returns unknown for NULL", {
  adapter <- maidr:::BaseRAdapter$new()

  layer_type <- adapter$detect_layer_type(NULL)
  testthat::expect_equal(layer_type, "unknown")
})

# ==============================================================================
# BaseRAdapter - Barplot Type Detection Tests
# ==============================================================================

test_that("BaseRAdapter is_dodged_barplot detects dodged bars", {
  adapter <- maidr:::BaseRAdapter$new()

  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  args <- list(test_matrix, beside = TRUE)

  result <- adapter$is_dodged_barplot(args)
  testthat::expect_true(result)
})

test_that("BaseRAdapter is_dodged_barplot returns FALSE for simple bars", {
  adapter <- maidr:::BaseRAdapter$new()

  args <- list(c(10, 20, 30))

  result <- adapter$is_dodged_barplot(args)
  testthat::expect_false(result)
})

test_that("BaseRAdapter is_dodged_barplot returns FALSE for stacked bars", {
  adapter <- maidr:::BaseRAdapter$new()

  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  args <- list(test_matrix, beside = FALSE)

  result <- adapter$is_dodged_barplot(args)
  testthat::expect_false(result)
})

test_that("BaseRAdapter is_stacked_barplot detects stacked bars", {
  adapter <- maidr:::BaseRAdapter$new()

  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  args <- list(test_matrix, beside = FALSE)

  result <- adapter$is_stacked_barplot(args)
  testthat::expect_true(result)
})

test_that("BaseRAdapter is_stacked_barplot with default beside", {
  adapter <- maidr:::BaseRAdapter$new()

  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  args <- list(test_matrix)

  # Default beside is NULL, which means NOT stacked (the function returns FALSE for NULL)
  # Only matrix with explicit beside=FALSE is considered stacked
  result <- adapter$is_stacked_barplot(args)
  testthat::expect_false(result)
})

test_that("BaseRAdapter detect_layer_type uses is_dodged_barplot", {
  adapter <- maidr:::BaseRAdapter$new()

  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  layer <- list(
    function_name = "barplot",
    args = list(test_matrix, beside = TRUE)
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "dodged_bar")
})

test_that("BaseRAdapter detect_layer_type uses is_stacked_barplot", {
  adapter <- maidr:::BaseRAdapter$new()

  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  layer <- list(
    function_name = "barplot",
    args = list(test_matrix, beside = FALSE)
  )

  layer_type <- adapter$detect_layer_type(layer)
  testthat::expect_equal(layer_type, "stacked_bar")
})

# ==============================================================================
# BaseRAdapter - create_orchestrator() Tests
# ==============================================================================

test_that("BaseRAdapter create_orchestrator returns orchestrator", {
  adapter <- maidr:::BaseRAdapter$new()

  barplot(c(10, 20, 30))

  orchestrator <- adapter$create_orchestrator()

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

test_that("BaseRAdapter create_orchestrator errors when no plot", {
  adapter <- maidr:::BaseRAdapter$new()

  clear_base_r_state()

  testthat::expect_error(
    adapter$create_orchestrator(),
    "Base R plotting system is not active or no plot calls recorded"
  )
})

# ==============================================================================
# BaseRAdapter - Utility Methods Tests
# ==============================================================================

test_that("BaseRAdapter get_system_name returns base_r", {
  adapter <- maidr:::BaseRAdapter$new()

  name <- adapter$get_system_name()
  testthat::expect_equal(name, "base_r")
})

test_that("BaseRAdapter get_adapter returns self", {
  adapter <- maidr:::BaseRAdapter$new()

  self_ref <- adapter$get_adapter()
  testthat::expect_identical(self_ref, adapter)
})

test_that("BaseRAdapter has_facets always returns FALSE", {
  adapter <- maidr:::BaseRAdapter$new()

  result <- adapter$has_facets()
  testthat::expect_false(result)

  result2 <- adapter$has_facets(NULL)
  testthat::expect_false(result2)
})

test_that("BaseRAdapter is_patchwork always returns FALSE", {
  adapter <- maidr:::BaseRAdapter$new()

  result <- adapter$is_patchwork()
  testthat::expect_false(result)

  result2 <- adapter$is_patchwork(NULL)
  testthat::expect_false(result2)
})

test_that("BaseRAdapter get_plot_calls retrieves calls", {
  adapter <- maidr:::BaseRAdapter$new()

  barplot(c(10, 20, 30))

  calls <- adapter$get_plot_calls()

  testthat::expect_type(calls, "list")
  testthat::expect_gte(length(calls), 1)

  clear_base_r_state()
})

test_that("BaseRAdapter clear_plot_calls clears storage", {
  adapter <- maidr:::BaseRAdapter$new()

  barplot(c(10, 20, 30))

  # Should have calls
  testthat::expect_true(adapter$can_handle(NULL))

  adapter$clear_plot_calls()

  # Should not have calls anymore
  testthat::expect_false(adapter$can_handle(NULL))
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Adapters work together in registry", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()

  gg_adapter <- maidr:::Ggplot2Adapter$new()
  base_adapter <- maidr:::BaseRAdapter$new()

  # ggplot2 plot should be detected by ggplot2 adapter
  p <- create_test_ggplot_bar()
  testthat::expect_true(gg_adapter$can_handle(p))
  testthat::expect_false(base_adapter$can_handle(p))

  # Base R plot should be detected by Base R adapter
  barplot(c(10, 20, 30))
  testthat::expect_false(gg_adapter$can_handle(NULL))
  testthat::expect_true(base_adapter$can_handle(NULL))

  clear_base_r_state()
})

test_that("Ggplot2Adapter orchestrator processes plot correctly", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- create_test_ggplot_bar()

  orchestrator <- adapter$create_orchestrator(p)

  # Orchestrator should have processed the plot
  testthat::expect_s3_class(orchestrator, "Ggplot2PlotOrchestrator")
  # Orchestrator should be an R6 object
  testthat::expect_true(R6::is.R6(orchestrator))
})

test_that("BaseRAdapter orchestrator processes plot correctly", {
  adapter <- maidr:::BaseRAdapter$new()

  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  orchestrator <- adapter$create_orchestrator()

  # Orchestrator should have processed the plot
  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")
  # Orchestrator should be an R6 object
  testthat::expect_true(R6::is.R6(orchestrator))

  clear_base_r_state()
})
