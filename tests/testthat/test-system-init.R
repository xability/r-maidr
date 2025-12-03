# Tests for system initialization functions
# These tests call .onLoad initialization logic directly to get covr coverage
# See: https://github.com/r-lib/covr/issues/40
#
# Note: We can't reset global_registry (namespace is locked), so we test
# re-initialization and idempotency instead

# ==============================================================================
# ggplot2 System Initialization Tests
# ==============================================================================

test_that("initialize_ggplot2_system() is idempotent (can be called multiple times)", {
  registry <- maidr:::get_global_registry()

  # System should already be registered from .onLoad
  initial_state <- registry$is_system_registered("ggplot2")

  # Call initialization function under covr tracking
  result <- maidr:::initialize_ggplot2_system()

  # Should still be registered
  testthat::expect_true(registry$is_system_registered("ggplot2"))

  # Verify return value
  testthat::expect_null(result)
})

test_that("initialize_ggplot2_system() ensures adapter exists", {
  registry <- maidr:::get_global_registry()

  # Call init (may be 2nd time, that's OK - tests idempotency)
  maidr:::initialize_ggplot2_system()

  adapter <- registry$get_adapter("ggplot2")
  testthat::expect_s3_class(adapter, "Ggplot2Adapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
})

test_that("initialize_ggplot2_system() ensures factory exists", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()

  factory <- registry$get_processor_factory("ggplot2")
  testthat::expect_s3_class(factory, "Ggplot2ProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
})

test_that("Multiple calls to initialize_ggplot2_system() don't duplicate registrations", {
  registry <- maidr:::get_global_registry()

  # Call multiple times
  maidr:::initialize_ggplot2_system()
  maidr:::initialize_ggplot2_system()
  maidr:::initialize_ggplot2_system()

  # Should still be registered
  testthat::expect_true(registry$is_system_registered("ggplot2"))

  # Should only have one registration
  systems <- registry$list_systems()
  ggplot2_count <- sum(systems == "ggplot2")
  testthat::expect_equal(ggplot2_count, 1)
})

test_that("initialize_ggplot2_system() sets adapter system_name", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()

  adapter <- registry$get_adapter("ggplot2")
  testthat::expect_equal(adapter$system_name, "ggplot2")
})

# ==============================================================================
# Base R System Initialization Tests
# ==============================================================================

test_that("initialize_base_r_system() is idempotent", {
  registry <- maidr:::get_global_registry()

  # System should already be registered from .onLoad
  initial_state <- registry$is_system_registered("base_r")

  # Call initialization function under covr tracking
  result <- maidr:::initialize_base_r_system()

  # Should be registered
  testthat::expect_true(registry$is_system_registered("base_r"))

  # Verify return value
  testthat::expect_null(result)
})

test_that("initialize_base_r_system() ensures adapter exists", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_base_r_system()

  adapter <- registry$get_adapter("base_r")
  testthat::expect_s3_class(adapter, "BaseRAdapter")
  testthat::expect_s3_class(adapter, "SystemAdapter")
})

test_that("initialize_base_r_system() ensures factory exists", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_base_r_system()

  factory <- registry$get_processor_factory("base_r")
  testthat::expect_s3_class(factory, "BaseRProcessorFactory")
  testthat::expect_s3_class(factory, "ProcessorFactory")
})

test_that("Multiple calls to initialize_base_r_system() don't duplicate registrations", {
  registry <- maidr:::get_global_registry()

  # Call multiple times
  maidr:::initialize_base_r_system()
  maidr:::initialize_base_r_system()
  maidr:::initialize_base_r_system()

  # Should still be registered
  testthat::expect_true(registry$is_system_registered("base_r"))

  # Should only have one registration
  systems <- registry$list_systems()
  base_r_count <- sum(systems == "base_r")
  testthat::expect_equal(base_r_count, 1)
})

test_that("initialize_base_r_system() sets adapter system_name", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_base_r_system()

  adapter <- registry$get_adapter("base_r")
  testthat::expect_equal(adapter$system_name, "base_r")
})

# ==============================================================================
# Combined Initialization Tests
# ==============================================================================

test_that("Both systems are initialized", {
  registry <- maidr:::get_global_registry()

  # Call both init functions
  maidr:::initialize_ggplot2_system()
  maidr:::initialize_base_r_system()

  systems <- registry$list_systems()
  testthat::expect_true("ggplot2" %in% systems)
  testthat::expect_true("base_r" %in% systems)
  testthat::expect_gte(length(systems), 2)
})

test_that("Re-initialization in any order works", {
  registry <- maidr:::get_global_registry()

  # Try base_r first, then ggplot2
  maidr:::initialize_base_r_system()
  maidr:::initialize_ggplot2_system()

  systems <- registry$list_systems()
  testthat::expect_true("ggplot2" %in% systems)
  testthat::expect_true("base_r" %in% systems)
})

# ==============================================================================
# Registry Method Coverage via Initialization
# ==============================================================================
# These tests ensure registry methods get coverage by being called
# through the initialization functions, even though systems are already
# registered from .onLoad

test_that("Re-initialization exercises registry$is_system_registered()", {
  registry <- maidr:::get_global_registry()

  # This call will check is_system_registered and hit the early return
  # (line 12-13 in ggplot2_system_init.R)
  maidr:::initialize_ggplot2_system()

  # Verify the check works
  testthat::expect_true(registry$is_system_registered("ggplot2"))
})

test_that("Initialization flow accesses registry methods", {
  registry <- maidr:::get_global_registry()

  # Call init functions to exercise registry methods
  maidr:::initialize_ggplot2_system()
  maidr:::initialize_base_r_system()

  # Verify we can access adapters (exercises get_adapter)
  adapter_gg <- registry$get_adapter("ggplot2")
  adapter_br <- registry$get_adapter("base_r")

  testthat::expect_s3_class(adapter_gg, "Ggplot2Adapter")
  testthat::expect_s3_class(adapter_br, "BaseRAdapter")
})

test_that("Initialization flow accesses factory getters", {
  registry <- maidr:::get_global_registry()

  maidr:::initialize_ggplot2_system()
  maidr:::initialize_base_r_system()

  # This exercises get_processor_factory method under covr
  factory_gg <- registry$get_processor_factory("ggplot2")
  factory_br <- registry$get_processor_factory("base_r")

  testthat::expect_s3_class(factory_gg, "Ggplot2ProcessorFactory")
  testthat::expect_s3_class(factory_br, "BaseRProcessorFactory")
})

# ==============================================================================
# Error Handling in Initialization
# ==============================================================================

test_that("Initialization functions are safe to call multiple times", {
  # The .onLoad function wraps initialization in tryCatch
  # Verify these don't throw even when called after .onLoad

  testthat::expect_silent(maidr:::initialize_ggplot2_system())
  testthat::expect_silent(maidr:::initialize_base_r_system())

  # Call again
  testthat::expect_silent(maidr:::initialize_ggplot2_system())
  testthat::expect_silent(maidr:::initialize_base_r_system())
})
