# Comprehensive tests for Base R Plot Grouping
# Testing call grouping, plot groups, and panel configuration detection

# ==============================================================================
# Setup and Teardown
# ==============================================================================

setup_clean_grouping <- function() {
  maidr:::clear_all_device_storage()
}

# ==============================================================================
# group_device_calls Tests
# ==============================================================================

test_that("group_device_calls returns empty for no calls", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  result <- maidr:::group_device_calls(device_id)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)

  setup_clean_grouping()
})

test_that("group_device_calls groups single HIGH call", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(c(1, 2, 3)), device_id)

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$total_groups, 1)
  testthat::expect_equal(length(result$groups), 1)
  testthat::expect_equal(result$groups[[1]]$high_call$function_name, "barplot")

  setup_clean_grouping()
})

test_that("group_device_calls groups multiple HIGH calls separately", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("boxplot", NULL, list(), device_id)

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$total_groups, 3)
  testthat::expect_equal(result$groups[[1]]$high_call$function_name, "barplot")
  testthat::expect_equal(result$groups[[2]]$high_call$function_name, "hist")
  testthat::expect_equal(result$groups[[3]]$high_call$function_name, "boxplot")

  setup_clean_grouping()
})

test_that("group_device_calls associates LOW calls with preceding HIGH call", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("plot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("points", NULL, list(), device_id)

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$total_groups, 1)
  testthat::expect_equal(length(result$groups[[1]]$low_calls), 2)
  testthat::expect_equal(result$groups[[1]]$low_calls[[1]]$function_name, "lines")
  testthat::expect_equal(result$groups[[1]]$low_calls[[2]]$function_name, "points")

  setup_clean_grouping()
})

test_that("group_device_calls handles multiple groups with LOW calls", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("plot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("abline", NULL, list(), device_id)

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$total_groups, 2)
  testthat::expect_equal(length(result$groups[[1]]$low_calls), 1)
  testthat::expect_equal(length(result$groups[[2]]$low_calls), 1)

  setup_clean_grouping()
})

test_that("group_device_calls separates LAYOUT calls", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$total_groups, 2)
  testthat::expect_equal(result$total_layout_calls, 1)
  testthat::expect_equal(result$layout_calls[[1]]$function_name, "par")

  setup_clean_grouping()
})

test_that("group_device_calls stores high_call_index correctly", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id) # index 1
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id) # index 2
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id) # index 3
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id) # index 4

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$groups[[1]]$high_call_index, 2)
  testthat::expect_equal(result$groups[[2]]$high_call_index, 4)

  setup_clean_grouping()
})

test_that("group_device_calls stores low_call_indices correctly", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("plot", NULL, list(), device_id) # index 1
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id) # index 2
  maidr:::log_plot_call_to_device("points", NULL, list(), device_id) # index 3

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$groups[[1]]$low_call_indices, c(2, 3))

  setup_clean_grouping()
})

test_that("group_device_calls ignores orphan LOW calls", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  # LOW call without preceding HIGH call
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  result <- maidr:::group_device_calls(device_id)

  # The orphan LOW call should be ignored
  testthat::expect_equal(result$total_groups, 1)
  testthat::expect_equal(length(result$groups[[1]]$low_calls), 0)

  setup_clean_grouping()
})

# ==============================================================================
# get_plot_group Tests
# ==============================================================================

test_that("get_plot_group returns correct group", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)

  group1 <- maidr:::get_plot_group(device_id, 1)
  group2 <- maidr:::get_plot_group(device_id, 2)

  testthat::expect_equal(group1$high_call$function_name, "barplot")
  testthat::expect_equal(group2$high_call$function_name, "hist")

  setup_clean_grouping()
})

test_that("get_plot_group returns NULL for invalid index", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  testthat::expect_null(maidr:::get_plot_group(device_id, 0))
  testthat::expect_null(maidr:::get_plot_group(device_id, 2))
  testthat::expect_null(maidr:::get_plot_group(device_id, -1))

  setup_clean_grouping()
})

test_that("get_plot_group returns NULL for empty storage", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()

  testthat::expect_null(maidr:::get_plot_group(device_id, 1))

  setup_clean_grouping()
})

# ==============================================================================
# get_all_plot_groups Tests
# ==============================================================================

test_that("get_all_plot_groups returns all groups", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("boxplot", NULL, list(), device_id)

  groups <- maidr:::get_all_plot_groups(device_id)

  testthat::expect_equal(length(groups), 3)

  setup_clean_grouping()
})

test_that("get_all_plot_groups returns empty or NULL for no calls", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()

  groups <- maidr:::get_all_plot_groups(device_id)

  # May return NULL or empty list
  testthat::expect_true(is.null(groups) || length(groups) == 0)

  setup_clean_grouping()
})

# ==============================================================================
# get_group_count Tests
# ==============================================================================

test_that("get_group_count returns correct count", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()

  # Initially 0 or NULL
  initial_count <- maidr:::get_group_count(device_id)
  testthat::expect_true(is.null(initial_count) || initial_count == 0)

  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  testthat::expect_equal(maidr:::get_group_count(device_id), 1)

  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)
  testthat::expect_equal(maidr:::get_group_count(device_id), 2)

  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id) # LOW call
  testthat::expect_equal(maidr:::get_group_count(device_id), 2) # Still 2

  setup_clean_grouping()
})

# ==============================================================================
# detect_panel_configuration Tests
# ==============================================================================

test_that("detect_panel_configuration returns NULL for no layout", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_null(config)

  setup_clean_grouping()
})

test_that("detect_panel_configuration detects mfrow", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 3)), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_equal(config$type, "mfrow")
  testthat::expect_equal(config$nrows, 2)
  testthat::expect_equal(config$ncols, 3)
  testthat::expect_equal(config$total_panels, 6)

  setup_clean_grouping()
})

test_that("detect_panel_configuration detects mfcol", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("par", NULL, list(mfcol = c(3, 2)), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_equal(config$type, "mfcol")
  testthat::expect_equal(config$nrows, 3)
  testthat::expect_equal(config$ncols, 2)
  testthat::expect_equal(config$total_panels, 6)

  setup_clean_grouping()
})

test_that("detect_panel_configuration detects layout", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  layout_matrix <- matrix(c(1, 2, 3, 3), nrow = 2, ncol = 2, byrow = TRUE)
  maidr:::log_plot_call_to_device("layout", NULL, list(layout_matrix), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_equal(config$type, "layout")
  testthat::expect_equal(config$nrows, 2)
  testthat::expect_equal(config$ncols, 2)
  testthat::expect_equal(config$total_panels, 3) # 3 unique panels
  testthat::expect_true("matrix" %in% names(config))

  setup_clean_grouping()
})

test_that("detect_panel_configuration ignores par without layout args", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("par", NULL, list(col = "red", lwd = 2), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_null(config)

  setup_clean_grouping()
})

test_that("detect_panel_configuration ignores layout with non-matrix", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("layout", NULL, list(c(1, 2, 3)), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_null(config)

  setup_clean_grouping()
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Grouping works with complex plot sequence", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()

  # Simulate a realistic plotting session
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(c(1, 2, 3)), device_id)
  maidr:::log_plot_call_to_device("abline", NULL, list(h = 2), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(rnorm(100)), device_id)
  maidr:::log_plot_call_to_device("plot", NULL, list(1:10, 1:10), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(1:10, 1:10 + 1), device_id)
  maidr:::log_plot_call_to_device("points", NULL, list(5, 5), device_id)
  maidr:::log_plot_call_to_device("boxplot", NULL, list(rnorm(50)), device_id)

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$total_groups, 4)
  testthat::expect_equal(result$total_layout_calls, 1)

  # Group 1: barplot with abline
  testthat::expect_equal(result$groups[[1]]$high_call$function_name, "barplot")
  testthat::expect_equal(length(result$groups[[1]]$low_calls), 1)

  # Group 2: hist with no LOW calls
  testthat::expect_equal(result$groups[[2]]$high_call$function_name, "hist")
  testthat::expect_equal(length(result$groups[[2]]$low_calls), 0)

  # Group 3: plot with lines and points
  testthat::expect_equal(result$groups[[3]]$high_call$function_name, "plot")
  testthat::expect_equal(length(result$groups[[3]]$low_calls), 2)

  # Group 4: boxplot
  testthat::expect_equal(result$groups[[4]]$high_call$function_name, "boxplot")

  # Panel configuration
  config <- maidr:::detect_panel_configuration(device_id)
  testthat::expect_equal(config$type, "mfrow")
  testthat::expect_equal(config$total_panels, 4)

  setup_clean_grouping()
})

test_that("Grouping handles empty groups correctly", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()

  # Only layout calls, no HIGH calls
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id)

  result <- maidr:::group_device_calls(device_id)

  testthat::expect_equal(result$total_groups, 0)
  testthat::expect_equal(result$total_layout_calls, 1)

  setup_clean_grouping()
})

test_that("Group retrieval is consistent", {
  setup_clean_grouping()

  device_id <- grDevices::dev.cur()
  maidr:::log_plot_call_to_device("barplot", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("lines", NULL, list(), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(), device_id)

  # Get via different methods
  all_groups <- maidr:::get_all_plot_groups(device_id)
  group1 <- maidr:::get_plot_group(device_id, 1)
  group2 <- maidr:::get_plot_group(device_id, 2)
  count <- maidr:::get_group_count(device_id)

  testthat::expect_equal(length(all_groups), count)
  testthat::expect_equal(all_groups[[1]]$high_call$function_name, group1$high_call$function_name)
  testthat::expect_equal(all_groups[[2]]$high_call$function_name, group2$high_call$function_name)

  setup_clean_grouping()
})
