# Comprehensive tests for PlotSystemRegistry
# Testing registry pattern, system registration, and adapter management

# Note: global_registry is initialized when package loads and persists across tests
# Each test should be independent and not rely on registry state

# ==============================================================================
# Registry Singleton Tests
# ==============================================================================

test_that("get_global_registry() returns a PlotSystemRegistry instance", {
  registry <- maidr:::get_global_registry()

  testthat::expect_s3_class(registry, "PlotSystemRegistry")
  testthat::expect_true(R6::is.R6(registry))
})

test_that("get_global_registry() returns same instance (singleton)", {
  registry1 <- maidr:::get_global_registry()
  registry2 <- maidr:::get_global_registry()

  # Same object reference
  testthat::expect_identical(registry1, registry2)
})

# ==============================================================================
# System Registration Tests
# ==============================================================================

test_that("register_system() successfully registers a system", {
  registry <- maidr:::get_global_registry()

  # Create mock adapter and factory
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  result <- registry$register_system("test_system_xyz", adapter, factory)

  # Returns self for chaining
  testthat::expect_identical(result, registry)

  # System is registered
  testthat::expect_true(registry$is_system_registered("test_system_xyz"))

  # Cleanup
  registry$unregister_system("test_system_xyz")
})

test_that("register_system() sets adapter system_name", {
  registry <- maidr:::get_global_registry()

  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()

  registry$register_system("ggplot2", adapter, factory)

  testthat::expect_equal(adapter$system_name, "ggplot2")
})

test_that("register_system() errors for non-SystemAdapter", {
  registry <- maidr:::get_global_registry()

  factory <- maidr:::Ggplot2ProcessorFactory$new()

  testthat::expect_error(
    registry$register_system("test", list(), factory),
    "Adapter must inherit from SystemAdapter"
  )
})

test_that("register_system() errors for non-ProcessorFactory", {
  registry <- maidr:::get_global_registry()

  adapter <- maidr:::Ggplot2Adapter$new()

  testthat::expect_error(
    registry$register_system("test", adapter, list()),
    "Processor factory must inherit from ProcessorFactory"
  )
})

test_that("register_system() can register multiple systems", {
  registry <- maidr:::get_global_registry()

  ggplot2_adapter <- maidr:::Ggplot2Adapter$new()
  ggplot2_factory <- maidr:::Ggplot2ProcessorFactory$new()

  base_r_adapter <- maidr:::BaseRAdapter$new()
  base_r_factory <- maidr:::BaseRProcessorFactory$new()

  registry$register_system("ggplot2", ggplot2_adapter, ggplot2_factory)
  registry$register_system("base_r", base_r_adapter, base_r_factory)

  systems <- registry$list_systems()
  testthat::expect_true("ggplot2" %in% systems)
  testthat::expect_true("base_r" %in% systems)
  # May have additional systems registered from other tests
  testthat::expect_gte(length(systems), 2)
})

# ==============================================================================
# System Detection Tests
# ==============================================================================

test_that("detect_system() returns correct system for ggplot2", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  p <- create_test_ggplot_bar()

  system_name <- registry$detect_system(p)
  testthat::expect_equal(system_name, "ggplot2")
})

test_that("detect_system() returns correct system for Base R", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::BaseRAdapter$new()
  factory <- maidr:::BaseRProcessorFactory$new()
  registry$register_system("base_r", adapter, factory)

  # Create a Base R plot
  barplot(c(10, 20, 30))

  system_name <- registry$detect_system(NULL)
  testthat::expect_equal(system_name, "base_r")

  clear_base_r_state()
})

test_that("detect_system() returns NULL for unrecognized plot", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  # Non-plot object
  result <- registry$detect_system(list(x = 1, y = 2))
  testthat::expect_null(result)
})

test_that("detect_system() checks systems in registration order", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()

  ggplot2_adapter <- maidr:::Ggplot2Adapter$new()
  ggplot2_factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", ggplot2_adapter, ggplot2_factory)

  base_r_adapter <- maidr:::BaseRAdapter$new()
  base_r_factory <- maidr:::BaseRProcessorFactory$new()
  registry$register_system("base_r", base_r_adapter, base_r_factory)

  p <- create_test_ggplot_bar()

  # Should detect ggplot2, not base_r
  system_name <- registry$detect_system(p)
  testthat::expect_equal(system_name, "ggplot2")
})

# ==============================================================================
# Adapter Retrieval Tests
# ==============================================================================

test_that("get_adapter() returns registered adapter", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  retrieved <- registry$get_adapter("ggplot2")

  testthat::expect_identical(retrieved, adapter)
  testthat::expect_s3_class(retrieved, "Ggplot2Adapter")
})

test_that("get_adapter() errors for unregistered system", {
  registry <- maidr:::get_global_registry()

  testthat::expect_error(
    registry$get_adapter("nonexistent"),
    "System 'nonexistent' is not registered"
  )
})

test_that("get_adapter_for_plot() returns correct adapter", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  p <- create_test_ggplot_bar()

  retrieved <- registry$get_adapter_for_plot(p)

  testthat::expect_identical(retrieved, adapter)
  testthat::expect_s3_class(retrieved, "Ggplot2Adapter")
})

test_that("get_adapter_for_plot() errors for unrecognized plot", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  testthat::expect_error(
    registry$get_adapter_for_plot(list(x = 1)),
    "No registered system can handle this plot object"
  )
})

# ==============================================================================
# Factory Retrieval Tests
# ==============================================================================

test_that("get_processor_factory() returns registered factory", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  retrieved <- registry$get_processor_factory("ggplot2")

  testthat::expect_identical(retrieved, factory)
  testthat::expect_s3_class(retrieved, "Ggplot2ProcessorFactory")
})

test_that("get_processor_factory() errors for unregistered system", {
  registry <- maidr:::get_global_registry()

  testthat::expect_error(
    registry$get_processor_factory("nonexistent"),
    "System 'nonexistent' is not registered"
  )
})

test_that("get_processor_factory_for_plot() returns correct factory", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  p <- create_test_ggplot_bar()

  retrieved <- registry$get_processor_factory_for_plot(p)

  testthat::expect_identical(retrieved, factory)
  testthat::expect_s3_class(retrieved, "Ggplot2ProcessorFactory")
})

test_that("get_processor_factory_for_plot() errors for unrecognized plot", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  testthat::expect_error(
    registry$get_processor_factory_for_plot(list(x = 1)),
    "No registered system can handle this plot object"
  )
})

# ==============================================================================
# System Listing Tests
# ==============================================================================

test_that("list_systems() returns character vector", {
  registry <- maidr:::get_global_registry()

  systems <- registry$list_systems()

  testthat::expect_type(systems, "character")
  # Registry may already have systems registered from package initialization
  testthat::expect_gte(length(systems), 0)
})

test_that("list_systems() returns all registered systems", {
  registry <- maidr:::get_global_registry()

  ggplot2_adapter <- maidr:::Ggplot2Adapter$new()
  ggplot2_factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", ggplot2_adapter, ggplot2_factory)

  base_r_adapter <- maidr:::BaseRAdapter$new()
  base_r_factory <- maidr:::BaseRProcessorFactory$new()
  registry$register_system("base_r", base_r_adapter, base_r_factory)

  systems <- registry$list_systems()

  # May have additional systems from other tests
  testthat::expect_gte(length(systems), 2)
  testthat::expect_true("ggplot2" %in% systems)
  testthat::expect_true("base_r" %in% systems)
})

# ==============================================================================
# System Registration Check Tests
# ==============================================================================

test_that("is_system_registered() returns FALSE for unregistered system", {
  registry <- maidr:::get_global_registry()

  # Use a system name that definitely won't be registered
  result <- registry$is_system_registered("nonexistent_system_xyz")
  testthat::expect_false(result)
})

test_that("is_system_registered() returns TRUE for registered system", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  result <- registry$is_system_registered("ggplot2")
  testthat::expect_true(result)
})

# ==============================================================================
# System Unregistration Tests
# ==============================================================================

test_that("unregister_system() removes registered system", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  testthat::expect_true(registry$is_system_registered("ggplot2"))

  result <- registry$unregister_system("ggplot2")

  # Returns self for chaining
  testthat::expect_identical(result, registry)

  # System is no longer registered
  testthat::expect_false(registry$is_system_registered("ggplot2"))
})

test_that("unregister_system() handles non-existent system gracefully", {
  registry <- maidr:::get_global_registry()

  # Should not error
  testthat::expect_silent(registry$unregister_system("nonexistent"))
})

test_that("unregister_system() removes adapter access", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  registry$unregister_system("ggplot2")

  testthat::expect_error(
    registry$get_adapter("ggplot2"),
    "System 'ggplot2' is not registered"
  )
})

test_that("unregister_system() removes factory access", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  registry$unregister_system("ggplot2")

  testthat::expect_error(
    registry$get_processor_factory("ggplot2"),
    "System 'ggplot2' is not registered"
  )
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("registry works end-to-end with ggplot2", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  adapter <- maidr:::Ggplot2Adapter$new()
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("ggplot2", adapter, factory)

  p <- create_test_ggplot_bar()

  # Detect system
  system_name <- registry$detect_system(p)
  testthat::expect_equal(system_name, "ggplot2")

  # Get adapter
  retrieved_adapter <- registry$get_adapter(system_name)
  testthat::expect_s3_class(retrieved_adapter, "Ggplot2Adapter")

  # Get factory
  retrieved_factory <- registry$get_processor_factory(system_name)
  testthat::expect_s3_class(retrieved_factory, "Ggplot2ProcessorFactory")

  # Adapter can handle plot
  testthat::expect_true(retrieved_adapter$can_handle(p))
})

test_that("registry works end-to-end with Base R", {
  registry <- maidr:::get_global_registry()
  adapter <- maidr:::BaseRAdapter$new()
  factory <- maidr:::BaseRProcessorFactory$new()
  registry$register_system("base_r", adapter, factory)

  barplot(c(10, 20, 30))

  # Detect system
  system_name <- registry$detect_system(NULL)
  testthat::expect_equal(system_name, "base_r")

  # Get adapter
  retrieved_adapter <- registry$get_adapter(system_name)
  testthat::expect_s3_class(retrieved_adapter, "BaseRAdapter")

  # Get factory
  retrieved_factory <- registry$get_processor_factory(system_name)
  testthat::expect_s3_class(retrieved_factory, "BaseRProcessorFactory")

  # Adapter can handle plot
  testthat::expect_true(retrieved_adapter$can_handle(NULL))

  clear_base_r_state()
})

test_that("registry handles re-registration of same system", {
  registry <- maidr:::get_global_registry()

  adapter1 <- maidr:::Ggplot2Adapter$new()
  factory1 <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("test_reregister", adapter1, factory1)

  adapter2 <- maidr:::Ggplot2Adapter$new()
  factory2 <- maidr:::Ggplot2ProcessorFactory$new()
  registry$register_system("test_reregister", adapter2, factory2)

  # Should use latest registration
  retrieved <- registry$get_adapter("test_reregister")
  testthat::expect_identical(retrieved, adapter2)
  testthat::expect_false(identical(retrieved, adapter1))

  # Cleanup
  registry$unregister_system("test_reregister")
})
