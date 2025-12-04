# Comprehensive tests for Base R Device Storage
# Testing device-scoped storage, call logging, and retrieval

# ==============================================================================
# Setup and Teardown
# ==============================================================================

# Helper to ensure clean state for each test
setup_clean_storage <- function() {
  maidr:::clear_all_device_storage()
}

# ==============================================================================
# get_device_storage Tests
# ==============================================================================

test_that("get_device_storage returns initialized storage", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  storage <- maidr:::get_device_storage(device_id)

  testthat::expect_type(storage, "list")
  testthat::expect_true("device_id" %in% names(storage))
  testthat::expect_true("calls" %in% names(storage))
  testthat::expect_true("metadata" %in% names(storage))

  setup_clean_storage()
})

test_that("get_device_storage handles NULL device_id", {
  setup_clean_storage()

  # Should use current device when NULL
  storage <- maidr:::get_device_storage(NULL)

  testthat::expect_type(storage, "list")
  testthat::expect_true("calls" %in% names(storage))

  setup_clean_storage()
})

test_that("get_device_storage handles NA device_id", {
  setup_clean_storage()

  storage <- maidr:::get_device_storage(NA)

  testthat::expect_type(storage, "list")

  setup_clean_storage()
})

test_that("get_device_storage handles invalid device_id", {
  setup_clean_storage()

  # Device ID 0 or negative should use current device

  storage <- maidr:::get_device_storage(0)
  testthat::expect_type(storage, "list")

  storage <- maidr:::get_device_storage(-1)
  testthat::expect_type(storage, "list")

  setup_clean_storage()
})

test_that("get_device_storage returns same storage for same device", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  storage1 <- maidr:::get_device_storage(device_id)
  storage2 <- maidr:::get_device_storage(device_id)

  testthat::expect_equal(storage1$device_id, storage2$device_id)

  setup_clean_storage()
})

test_that("get_device_storage creates metadata with timestamp", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  storage <- maidr:::get_device_storage(device_id)

  testthat::expect_true("created" %in% names(storage$metadata))
  testthat::expect_s3_class(storage$metadata$created, "POSIXct")

  setup_clean_storage()
})

# ==============================================================================
# log_plot_call_to_device Tests
# ==============================================================================

test_that("log_plot_call_to_device stores call correctly", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device(
    function_name = "barplot",
    call_expr = quote(barplot(c(1, 2, 3))),
    args = list(c(1, 2, 3)),
    device_id = device_id
  )

  calls <- maidr:::get_device_calls(device_id)

  testthat::expect_equal(length(calls), 1)
  testthat::expect_equal(calls[[1]]$function_name, "barplot")

  setup_clean_storage()
})

test_that("log_plot_call_to_device stores multiple calls", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()

  maidr:::log_plot_call_to_device("barplot", NULL, list(c(1, 2)), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(rnorm(10)), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(1:5, 1:5), device_id)

  calls <- maidr:::get_device_calls(device_id)

  testthat::expect_equal(length(calls), 3)
  testthat::expect_equal(calls[[1]]$function_name, "barplot")
  testthat::expect_equal(calls[[2]]$function_name, "hist")
  testthat::expect_equal(calls[[3]]$function_name, "lines")

  setup_clean_storage()
})

test_that("log_plot_call_to_device stores class_level", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()

  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)

  calls <- maidr:::get_device_calls(device_id)

  testthat::expect_equal(calls[[1]]$class_level, "HIGH")
  testthat::expect_equal(calls[[2]]$class_level, "LOW")

  setup_clean_storage()
})

test_that("log_plot_call_to_device stores timestamp", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  before <- Sys.time()

  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  after <- Sys.time()
  calls <- maidr:::get_device_calls(device_id)

  testthat::expect_true(calls[[1]]$timestamp >= before)
  testthat::expect_true(calls[[1]]$timestamp <= after)

  setup_clean_storage()
})

test_that("log_plot_call_to_device handles NULL call_expr", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  calls <- maidr:::get_device_calls(device_id)

  testthat::expect_true(is.na(calls[[1]]$call_expr))

  setup_clean_storage()
})

test_that("log_plot_call_to_device updates call_count", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()

  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)

  storage <- maidr:::get_device_storage(device_id)

  testthat::expect_equal(storage$metadata$call_count, 2)

  setup_clean_storage()
})

# ==============================================================================
# get_device_calls Tests
# ==============================================================================

test_that("get_device_calls returns empty list for new device", {
  setup_clean_storage()

  calls <- maidr:::get_device_calls(grDevices::dev.cur())

  testthat::expect_type(calls, "list")
  testthat::expect_equal(length(calls), 0)

  setup_clean_storage()
})

test_that("get_device_calls returns empty list for NULL device_id", {
  setup_clean_storage()

  calls <- maidr:::get_device_calls(NULL)

  testthat::expect_type(calls, "list")
  testthat::expect_equal(length(calls), 0)

  setup_clean_storage()
})

test_that("get_device_calls returns empty list for NA device_id", {
  setup_clean_storage()

  calls <- maidr:::get_device_calls(NA)

  testthat::expect_type(calls, "list")
  testthat::expect_equal(length(calls), 0)

  setup_clean_storage()
})

test_that("get_device_calls returns empty list for invalid device_id", {
  setup_clean_storage()

  calls <- maidr:::get_device_calls(-1)

  testthat::expect_type(calls, "list")
  testthat::expect_equal(length(calls), 0)

  setup_clean_storage()
})

# ==============================================================================
# clear_device_storage Tests
# ==============================================================================

test_that("clear_device_storage clears calls", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()

  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  testthat::expect_equal(length(maidr:::get_device_calls(device_id)), 1)

  maidr:::clear_device_storage(device_id)

  testthat::expect_equal(length(maidr:::get_device_calls(device_id)), 0)

  setup_clean_storage()
})

test_that("clear_device_storage returns NULL invisibly", {
  setup_clean_storage()

  result <- maidr:::clear_device_storage(grDevices::dev.cur())

  testthat::expect_null(result)

  setup_clean_storage()
})

test_that("clear_device_storage handles NULL device_id", {
  setup_clean_storage()

  # Should not error
  result <- maidr:::clear_device_storage(NULL)
  testthat::expect_null(result)

  setup_clean_storage()
})

test_that("clear_device_storage handles invalid device_id", {
  setup_clean_storage()

  # Should not error
  result <- maidr:::clear_device_storage(-1)
  testthat::expect_null(result)

  setup_clean_storage()
})

# ==============================================================================
# clear_all_device_storage Tests
# ==============================================================================

test_that("clear_all_device_storage clears all devices", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  maidr:::clear_all_device_storage()

  summary <- maidr:::get_device_storage_summary()
  testthat::expect_equal(summary$total_devices, 0)

  setup_clean_storage()
})

test_that("clear_all_device_storage returns NULL invisibly", {
  setup_clean_storage()

  result <- maidr:::clear_all_device_storage()

  testthat::expect_null(result)

  setup_clean_storage()
})

# ==============================================================================
# has_device_calls Tests
# ==============================================================================

test_that("has_device_calls returns FALSE for empty storage", {
  setup_clean_storage()

  result <- maidr:::has_device_calls(grDevices::dev.cur())

  testthat::expect_false(result)

  setup_clean_storage()
})

test_that("has_device_calls returns TRUE after logging call", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  result <- maidr:::has_device_calls(device_id)

  testthat::expect_true(result)

  setup_clean_storage()
})

test_that("has_device_calls returns FALSE for NULL device_id", {
  setup_clean_storage()

  result <- maidr:::has_device_calls(NULL)

  testthat::expect_false(result)

  setup_clean_storage()
})

test_that("has_device_calls returns FALSE for invalid device_id", {
  setup_clean_storage()

  testthat::expect_false(maidr:::has_device_calls(-1))
  testthat::expect_false(maidr:::has_device_calls(0))
  testthat::expect_false(maidr:::has_device_calls(NA))

  setup_clean_storage()
})

# ==============================================================================
# get_device_storage_summary Tests
# ==============================================================================

test_that("get_device_storage_summary returns correct structure", {
  setup_clean_storage()

  summary <- maidr:::get_device_storage_summary()

  testthat::expect_type(summary, "list")
  testthat::expect_true("total_devices" %in% names(summary))
  testthat::expect_true("devices" %in% names(summary))

  setup_clean_storage()
})

test_that("get_device_storage_summary counts devices correctly", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  summary <- maidr:::get_device_storage_summary()

  testthat::expect_equal(summary$total_devices, 1)

  setup_clean_storage()
})

test_that("get_device_storage_summary includes device info", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)

  summary <- maidr:::get_device_storage_summary()
  key <- as.character(device_id)

  testthat::expect_true(key %in% names(summary$devices))
  testthat::expect_equal(summary$devices[[key]]$call_count, 2)

  setup_clean_storage()
})

# ==============================================================================
# get_device_calls_by_class Tests
# ==============================================================================

test_that("get_device_calls_by_class filters HIGH calls", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)

  high_calls <- maidr:::get_device_calls_by_class(device_id, "HIGH")

  testthat::expect_equal(length(high_calls), 2)
  testthat::expect_true(all(sapply(high_calls, function(c) c$class_level == "HIGH")))

  setup_clean_storage()
})

test_that("get_device_calls_by_class filters LOW calls", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("points", NULL, list(), device_id)

  low_calls <- maidr:::get_device_calls_by_class(device_id, "LOW")

  testthat::expect_equal(length(low_calls), 2)
  testthat::expect_true(all(sapply(low_calls, function(c) c$class_level == "LOW")))

  setup_clean_storage()
})

test_that("get_device_calls_by_class returns empty for no matches", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  layout_calls <- maidr:::get_device_calls_by_class(device_id, "LAYOUT")

  testthat::expect_equal(length(layout_calls), 0)

  setup_clean_storage()
})

# ==============================================================================
# get_high_level_calls Tests
# ==============================================================================

test_that("get_high_level_calls returns only HIGH calls", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)

  high_calls <- maidr:::get_high_level_calls(device_id)

  testthat::expect_equal(length(high_calls), 1)
  testthat::expect_equal(high_calls[[1]]$function_name, "barplot")

  setup_clean_storage()
})

# ==============================================================================
# get_low_level_calls Tests
# ==============================================================================

test_that("get_low_level_calls returns only LOW calls", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("points", NULL, list(), device_id)

  low_calls <- maidr:::get_low_level_calls(device_id)

  testthat::expect_equal(length(low_calls), 2)

  setup_clean_storage()
})

# ==============================================================================
# get_layout_calls Tests
# ==============================================================================

test_that("get_layout_calls returns only LAYOUT calls", {
  setup_clean_storage()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  layout_calls <- maidr:::get_layout_calls(device_id)

  testthat::expect_equal(length(layout_calls), 1)
  testthat::expect_equal(layout_calls[[1]]$function_name, "par")

  setup_clean_storage()
})

# ==============================================================================
# Internal Guard Tests
# ==============================================================================

test_that("set_internal_guard sets and clears flag", {
  maidr:::set_internal_guard(TRUE)
  testthat::expect_true(maidr:::is_internal_call())

  maidr:::set_internal_guard(FALSE)
  testthat::expect_false(maidr:::is_internal_call())
})

test_that("is_internal_call returns FALSE by default", {
  maidr:::set_internal_guard(FALSE)

  testthat::expect_false(maidr:::is_internal_call())
})

test_that("set_internal_guard handles non-logical values", {
  maidr:::set_internal_guard("not_logical")
  testthat::expect_false(maidr:::is_internal_call())

  maidr:::set_internal_guard(NULL)
  testthat::expect_false(maidr:::is_internal_call())
})
