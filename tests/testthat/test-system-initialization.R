# Comprehensive tests for System Initialization
# Testing ggplot2 and Base R system initialization and registration

# ==============================================================================
# initialize_ggplot2_system Tests
# ==============================================================================

test_that("initialize_ggplot2_system returns NULL invisibly", {
  result <- maidr:::initialize_ggplot2_system()

  testthat::expect_null(result)
})

test_that("initialize_ggplot2_system registers ggplot2 system", {
  registry <- maidr:::get_global_registry()

  # Re-initialize (should be idempotent)
  maidr:::initialize_ggplot2_system()

  testthat::expect_true(registry$is_system_registered("ggplot2"))
})

test_that("initialize_ggplot2_system creates adapter", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()

  adapter <- registry$get_adapter("ggplot2")

  testthat::expect_s3_class(adapter, "Ggplot2Adapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
})

test_that("initialize_ggplot2_system creates processor factory", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()

  factory <- registry$get_processor_factory("ggplot2")

  testthat::expect_s3_class(factory, "Ggplot2ProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
})

test_that("initialize_ggplot2_system is idempotent", {
  registry <- maidr:::get_global_registry()

  # Call multiple times
  maidr:::initialize_ggplot2_system()
  maidr:::initialize_ggplot2_system()
  maidr:::initialize_ggplot2_system()

  # Should still have exactly one ggplot2 system
  systems <- registry$list_systems()
  ggplot2_count <- sum(systems == "ggplot2")

  testthat::expect_equal(ggplot2_count, 1)
})

# ==============================================================================
# initialize_base_r_system Tests
# ==============================================================================

test_that("initialize_base_r_system returns NULL invisibly", {
  result <- maidr:::initialize_base_r_system()

  testthat::expect_null(result)
})

test_that("initialize_base_r_system registers base_r system", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_base_r_system()

  testthat::expect_true(registry$is_system_registered("base_r"))
})

test_that("initialize_base_r_system creates adapter", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_base_r_system()

  adapter <- registry$get_adapter("base_r")

  testthat::expect_s3_class(adapter, "BaseRAdapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
})

test_that("initialize_base_r_system creates processor factory", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_base_r_system()

  factory <- registry$get_processor_factory("base_r")

  testthat::expect_s3_class(factory, "BaseRProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
})

test_that("initialize_base_r_system is idempotent", {
  registry <- maidr:::get_global_registry()

  # Call multiple times
  maidr:::initialize_base_r_system()
  maidr:::initialize_base_r_system()
  maidr:::initialize_base_r_system()

  # Should still have exactly one base_r system
  systems <- registry$list_systems()
  base_r_count <- sum(systems == "base_r")

  testthat::expect_equal(base_r_count, 1)
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Both systems can be initialized together", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()
  maidr:::initialize_base_r_system()

  testthat::expect_true(registry$is_system_registered("ggplot2"))
  testthat::expect_true(registry$is_system_registered("base_r"))

  systems <- registry$list_systems()
  testthat::expect_true("ggplot2" %in% systems)
  testthat::expect_true("base_r" %in% systems)
})

test_that("Systems are independent", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()
  maidr:::initialize_base_r_system()

  ggplot2_adapter <- registry$get_adapter("ggplot2")
  base_r_adapter <- registry$get_adapter("base_r")

  # Should be different classes
  testthat::expect_s3_class(ggplot2_adapter, "Ggplot2Adapter")
  testthat::expect_s3_class(base_r_adapter, "BaseRAdapter")

  # Should have different system names
  testthat::expect_equal(ggplot2_adapter$system_name, "ggplot2")
  testthat::expect_equal(base_r_adapter$system_name, "base_r")
})

test_that("Factories are system-specific", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()
  maidr:::initialize_base_r_system()

  ggplot2_factory <- registry$get_processor_factory("ggplot2")
  base_r_factory <- registry$get_processor_factory("base_r")

  testthat::expect_equal(ggplot2_factory$get_system_name(), "ggplot2")
  testthat::expect_equal(base_r_factory$get_system_name(), "base_r")
})

# ==============================================================================
# Registry After Initialization Tests
# ==============================================================================

test_that("Registry can detect ggplot2 plots after initialization", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  maidr:::initialize_ggplot2_system()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()

  system_name <- registry$detect_system(p)

  testthat::expect_equal(system_name, "ggplot2")
})

test_that("Registry can get adapter for ggplot2 plots", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  maidr:::initialize_ggplot2_system()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()

  adapter <- registry$get_adapter_for_plot(p)

  testthat::expect_s3_class(adapter, "Ggplot2Adapter")
})

test_that("Registry can get factory for ggplot2 plots", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  maidr:::initialize_ggplot2_system()

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()

  factory <- registry$get_processor_factory_for_plot(p)

  testthat::expect_s3_class(factory, "Ggplot2ProcessorFactory")
})

# ==============================================================================
# Error Handling Tests
# ==============================================================================

test_that("Registry errors on unregistered system", {
  registry <- maidr:::get_global_registry()

  testthat::expect_error(
    registry$get_adapter("nonexistent_system"),
    "is not registered"
  )

  testthat::expect_error(
    registry$get_processor_factory("nonexistent_system"),
    "is not registered"
  )
})

test_that("Registry errors on unsupported plot object", {
  registry <- maidr:::get_global_registry()

  # A random list that no system can handle
  fake_plot <- list(type = "unknown", data = 1:10)

  testthat::expect_error(
    registry$get_adapter_for_plot(fake_plot),
    "No registered system can handle this plot object"
  )
})
