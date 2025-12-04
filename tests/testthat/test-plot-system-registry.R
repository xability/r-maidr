# Comprehensive tests for Plot System Registry
# Testing registry creation, system registration, detection, and management

# ==============================================================================
# Helper Classes for Testing
# ==============================================================================

# Mock SystemAdapter for testing
MockSystemAdapter <- R6::R6Class("MockSystemAdapter",
  inherit = maidr:::SystemAdapter,
  public = list(
    handled_class = NULL,
    initialize = function(handled_class = "mock_plot") {
      self$handled_class <- handled_class
    },
    can_handle = function(plot_object) {
      inherits(plot_object, self$handled_class)
    },
    get_plot_type = function(plot_object) {
      "mock_type"
    },
    create_orchestrator = function(plot_object, options = list()) {
      NULL
    }
  )
)

# Mock ProcessorFactory for testing
MockProcessorFactory <- R6::R6Class("MockProcessorFactory",
  inherit = maidr:::ProcessorFactory,
  public = list(
    get_system_name = function() {
      "mock_system"
    },
    create_processor = function(plot_type, layer_info = NULL) {
      NULL
    },
    is_processor_available = function(plot_type) {
      TRUE
    },
    get_supported_types = function() {
      c("mock_type")
    }
  )
)

# Mock plot object
create_mock_plot <- function() {
  obj <- list(data = 1:10)
  class(obj) <- "mock_plot"
  obj
}

# ==============================================================================
# PlotSystemRegistry Class Tests
# ==============================================================================

test_that("PlotSystemRegistry creates new instance", {
  registry <- maidr:::PlotSystemRegistry$new()

  testthat::expect_s3_class(registry, "PlotSystemRegistry")
  testthat::expect_s3_class(registry, "R6")
})
test_that("PlotSystemRegistry starts with no registered systems", {
  registry <- maidr:::PlotSystemRegistry$new()

  systems <- registry$list_systems()

  # list_systems returns NULL for empty registry (names of empty list)
  testthat::expect_true(is.null(systems) || length(systems) == 0)
})

# ==============================================================================
# register_system Tests
# ==============================================================================

test_that("register_system registers a system correctly", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()

  result <- registry$register_system("test_system", adapter, factory)

  testthat::expect_true(registry$is_system_registered("test_system"))
  testthat::expect_s3_class(result, "PlotSystemRegistry")
})

test_that("register_system sets system_name on adapter", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()

  registry$register_system("test_system", adapter, factory)

  testthat::expect_equal(adapter$system_name, "test_system")
})

test_that("register_system errors on non-SystemAdapter", {
  registry <- maidr:::PlotSystemRegistry$new()
  factory <- MockProcessorFactory$new()

  testthat::expect_error(
    registry$register_system("test", list(), factory),
    "Adapter must inherit from SystemAdapter"
  )
})

test_that("register_system errors on non-ProcessorFactory", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()

  testthat::expect_error(
    registry$register_system("test", adapter, list()),
    "Processor factory must inherit from ProcessorFactory"
  )
})

test_that("register_system returns self for chaining", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()

  result <- registry$register_system("test_system", adapter, factory)

  testthat::expect_identical(result, registry)
})

test_that("register_system can register multiple systems", {
  registry <- maidr:::PlotSystemRegistry$new()

  adapter1 <- MockSystemAdapter$new("type1")
  factory1 <- MockProcessorFactory$new()
  registry$register_system("system1", adapter1, factory1)

  adapter2 <- MockSystemAdapter$new("type2")
  factory2 <- MockProcessorFactory$new()
  registry$register_system("system2", adapter2, factory2)

  systems <- registry$list_systems()

  testthat::expect_equal(length(systems), 2)
  testthat::expect_true("system1" %in% systems)
  testthat::expect_true("system2" %in% systems)
})

# ==============================================================================
# detect_system Tests
# ==============================================================================

test_that("detect_system returns system name for handled plot", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new("mock_plot")
  factory <- MockProcessorFactory$new()
  registry$register_system("mock_system", adapter, factory)

  plot <- create_mock_plot()
  result <- registry$detect_system(plot)

  testthat::expect_equal(result, "mock_system")
})

test_that("detect_system returns NULL for unhandled plot", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new("other_plot")
  factory <- MockProcessorFactory$new()
  registry$register_system("mock_system", adapter, factory)

  plot <- create_mock_plot()
  result <- registry$detect_system(plot)

  testthat::expect_null(result)
})

test_that("detect_system returns NULL for empty registry", {
  registry <- maidr:::PlotSystemRegistry$new()

  plot <- create_mock_plot()
  result <- registry$detect_system(plot)

  testthat::expect_null(result)
})

test_that("detect_system returns first matching system", {
  registry <- maidr:::PlotSystemRegistry$new()

  # Both can handle mock_plot, should return first registered
  adapter1 <- MockSystemAdapter$new("mock_plot")
  factory1 <- MockProcessorFactory$new()
  registry$register_system("first_system", adapter1, factory1)

  adapter2 <- MockSystemAdapter$new("mock_plot")
  factory2 <- MockProcessorFactory$new()
  registry$register_system("second_system", adapter2, factory2)

  plot <- create_mock_plot()
  result <- registry$detect_system(plot)

  testthat::expect_equal(result, "first_system")
})

# ==============================================================================
# get_adapter Tests
# ==============================================================================

test_that("get_adapter returns registered adapter", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()
  registry$register_system("test_system", adapter, factory)

  result <- registry$get_adapter("test_system")

  testthat::expect_s3_class(result, "MockSystemAdapter")
  testthat::expect_identical(result, adapter)
})

test_that("get_adapter errors on unregistered system", {
  registry <- maidr:::PlotSystemRegistry$new()

  testthat::expect_error(
    registry$get_adapter("nonexistent"),
    "is not registered"
  )
})

# ==============================================================================
# get_processor_factory Tests
# ==============================================================================

test_that("get_processor_factory returns registered factory", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()
  registry$register_system("test_system", adapter, factory)

  result <- registry$get_processor_factory("test_system")

  testthat::expect_s3_class(result, "MockProcessorFactory")
  testthat::expect_identical(result, factory)
})

test_that("get_processor_factory errors on unregistered system", {
  registry <- maidr:::PlotSystemRegistry$new()

  testthat::expect_error(
    registry$get_processor_factory("nonexistent"),
    "is not registered"
  )
})

# ==============================================================================
# get_adapter_for_plot Tests
# ==============================================================================

test_that("get_adapter_for_plot returns adapter for detected system", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new("mock_plot")
  factory <- MockProcessorFactory$new()
  registry$register_system("mock_system", adapter, factory)

  plot <- create_mock_plot()
  result <- registry$get_adapter_for_plot(plot)

  testthat::expect_s3_class(result, "MockSystemAdapter")
})

test_that("get_adapter_for_plot errors on unhandled plot", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new("other_plot")
  factory <- MockProcessorFactory$new()
  registry$register_system("mock_system", adapter, factory)

  plot <- create_mock_plot()

  testthat::expect_error(
    registry$get_adapter_for_plot(plot),
    "No registered system can handle this plot object"
  )
})

# ==============================================================================
# get_processor_factory_for_plot Tests
# ==============================================================================

test_that("get_processor_factory_for_plot returns factory for detected system", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new("mock_plot")
  factory <- MockProcessorFactory$new()
  registry$register_system("mock_system", adapter, factory)

  plot <- create_mock_plot()
  result <- registry$get_processor_factory_for_plot(plot)

  testthat::expect_s3_class(result, "MockProcessorFactory")
})

test_that("get_processor_factory_for_plot errors on unhandled plot", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new("other_plot")
  factory <- MockProcessorFactory$new()
  registry$register_system("mock_system", adapter, factory)

  plot <- create_mock_plot()

  testthat::expect_error(
    registry$get_processor_factory_for_plot(plot),
    "No registered system can handle this plot object"
  )
})

# ==============================================================================
# list_systems Tests
# ==============================================================================

test_that("list_systems returns empty or NULL for no systems", {
  registry <- maidr:::PlotSystemRegistry$new()

  result <- registry$list_systems()

  # names() on empty list returns NULL
  testthat::expect_true(is.null(result) || length(result) == 0)
})

test_that("list_systems returns all registered system names", {
  registry <- maidr:::PlotSystemRegistry$new()

  adapter1 <- MockSystemAdapter$new()
  factory1 <- MockProcessorFactory$new()
  registry$register_system("system_a", adapter1, factory1)

  adapter2 <- MockSystemAdapter$new()
  factory2 <- MockProcessorFactory$new()
  registry$register_system("system_b", adapter2, factory2)

  result <- registry$list_systems()

  testthat::expect_equal(length(result), 2)
  testthat::expect_true("system_a" %in% result)
  testthat::expect_true("system_b" %in% result)
})

# ==============================================================================
# is_system_registered Tests
# ==============================================================================

test_that("is_system_registered returns FALSE for unregistered system", {
  registry <- maidr:::PlotSystemRegistry$new()

  testthat::expect_false(registry$is_system_registered("nonexistent"))
})

test_that("is_system_registered returns TRUE for registered system", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()
  registry$register_system("test_system", adapter, factory)

  testthat::expect_true(registry$is_system_registered("test_system"))
})

# ==============================================================================
# unregister_system Tests
# ==============================================================================

test_that("unregister_system removes registered system", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()
  registry$register_system("test_system", adapter, factory)

  testthat::expect_true(registry$is_system_registered("test_system"))

  registry$unregister_system("test_system")

  testthat::expect_false(registry$is_system_registered("test_system"))
})

test_that("unregister_system returns self for chaining", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()
  registry$register_system("test_system", adapter, factory)

  result <- registry$unregister_system("test_system")

  testthat::expect_identical(result, registry)
})

test_that("unregister_system handles non-existent system gracefully", {
  registry <- maidr:::PlotSystemRegistry$new()

  # Should not error
  result <- registry$unregister_system("nonexistent")

  testthat::expect_s3_class(result, "PlotSystemRegistry")
})

test_that("unregister_system removes adapter and factory", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()
  registry$register_system("test_system", adapter, factory)

  registry$unregister_system("test_system")

  testthat::expect_error(
    registry$get_adapter("test_system"),
    "is not registered"
  )

  testthat::expect_error(
    registry$get_processor_factory("test_system"),
    "is not registered"
  )
})

# ==============================================================================
# Global Registry Tests
# ==============================================================================

test_that("get_global_registry returns PlotSystemRegistry", {
  registry <- maidr:::get_global_registry()

  testthat::expect_s3_class(registry, "PlotSystemRegistry")
})

test_that("get_global_registry returns same instance on multiple calls", {
  registry1 <- maidr:::get_global_registry()
  registry2 <- maidr:::get_global_registry()

  testthat::expect_identical(registry1, registry2)
})

test_that("reset_global_registry exists as a function", {
  # Note: reset_global_registry uses <<- which may not work with namespace
  # locking in loaded packages. We just verify the function exists.
  testthat::expect_true(is.function(maidr:::reset_global_registry))
})

# ==============================================================================
# Integration with Real Adapters Tests
# ==============================================================================

test_that("Global registry has ggplot2 system registered", {
  registry <- maidr:::get_global_registry()

  # Ensure ggplot2 is initialized
  maidr:::initialize_ggplot2_system()

  testthat::expect_true(registry$is_system_registered("ggplot2"))
})

test_that("Global registry has base_r system registered", {
  registry <- maidr:::get_global_registry()

  # Ensure base_r is initialized
  maidr:::initialize_base_r_system()

  testthat::expect_true(registry$is_system_registered("base_r"))
})

test_that("Global registry can detect ggplot2 plots", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  maidr:::initialize_ggplot2_system()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()

  system <- registry$detect_system(p)

  testthat::expect_equal(system, "ggplot2")
})

test_that("Global registry returns correct adapter for ggplot2", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  maidr:::initialize_ggplot2_system()

  adapter <- registry$get_adapter("ggplot2")

  testthat::expect_s3_class(adapter, "Ggplot2Adapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
})

test_that("Global registry returns correct factory for ggplot2", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  maidr:::initialize_ggplot2_system()

  factory <- registry$get_processor_factory("ggplot2")

  testthat::expect_s3_class(factory, "Ggplot2ProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
})

test_that("Global registry returns correct adapter for base_r", {
  registry <- maidr:::get_global_registry()
  maidr:::initialize_base_r_system()

  adapter <- registry$get_adapter("base_r")

  testthat::expect_s3_class(adapter, "BaseRAdapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
})

test_that("Global registry returns correct factory for base_r", {
  registry <- maidr:::get_global_registry()
  maidr:::initialize_base_r_system()

  factory <- registry$get_processor_factory("base_r")

  testthat::expect_s3_class(factory, "BaseRProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Registry handles re-registration of same system", {
  registry <- maidr:::PlotSystemRegistry$new()

  adapter1 <- MockSystemAdapter$new()
  factory1 <- MockProcessorFactory$new()
  registry$register_system("test", adapter1, factory1)

  adapter2 <- MockSystemAdapter$new()
  factory2 <- MockProcessorFactory$new()
  registry$register_system("test", adapter2, factory2)

  # Should have replaced with new adapter
  result <- registry$get_adapter("test")
  testthat::expect_identical(result, adapter2)
})

test_that("Registry handles NULL plot object in detect_system", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()
  registry$register_system("test", adapter, factory)

  result <- registry$detect_system(NULL)

  testthat::expect_null(result)
})

test_that("Registry handles empty string system name", {
  registry <- maidr:::PlotSystemRegistry$new()
  adapter <- MockSystemAdapter$new()
  factory <- MockProcessorFactory$new()

  # Should work - empty string is a valid key
  registry$register_system("", adapter, factory)

  testthat::expect_true(registry$is_system_registered(""))
})
