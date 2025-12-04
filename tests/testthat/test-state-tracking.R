# Comprehensive tests for Base R State Tracking
# Testing device state management, panel configuration, and plot indexing

# ==============================================================================
# Setup and Teardown
# ==============================================================================

setup_clean_state <- function() {
  maidr:::clear_all_device_storage()
}

# ==============================================================================
# get_device_state Tests
# ==============================================================================

test_that("get_device_state returns initialized state", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state <- maidr:::get_device_state(device_id)

  testthat::expect_type(state, "list")
  testthat::expect_true("current_plot_index" %in% names(state))
  testthat::expect_true("panel_config" %in% names(state))
  testthat::expect_true("layout_active" %in% names(state))

  setup_clean_state()
})

test_that("get_device_state initializes current_plot_index to 0", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$current_plot_index, 0)

  setup_clean_state()
})

test_that("get_device_state initializes layout_active to FALSE", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state <- maidr:::get_device_state(device_id)

  testthat::expect_false(state$layout_active)

  setup_clean_state()
})

test_that("get_device_state initializes single panel config", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$panel_config$type, "single")
  testthat::expect_equal(state$panel_config$nrows, 1)
  testthat::expect_equal(state$panel_config$ncols, 1)
  testthat::expect_equal(state$panel_config$total_panels, 1)

  setup_clean_state()
})

test_that("get_device_state returns same state for same device", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state1 <- maidr:::get_device_state(device_id)
  state2 <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state1$current_plot_index, state2$current_plot_index)

  setup_clean_state()
})

# ==============================================================================
# update_device_state Tests
# ==============================================================================

test_that("update_device_state updates state correctly", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state <- maidr:::get_device_state(device_id)

  state$current_plot_index <- 5
  maidr:::update_device_state(device_id, state)

  updated_state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(updated_state$current_plot_index, 5)

  setup_clean_state()
})

test_that("update_device_state returns NULL invisibly", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state <- maidr:::get_device_state(device_id)

  result <- maidr:::update_device_state(device_id, state)

  testthat::expect_null(result)

  setup_clean_state()
})

test_that("update_device_state preserves panel_config changes", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  state <- maidr:::get_device_state(device_id)

  state$panel_config$type <- "mfrow"
  state$panel_config$nrows <- 2
  state$panel_config$ncols <- 3
  maidr:::update_device_state(device_id, state)

  updated_state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(updated_state$panel_config$type, "mfrow")
  testthat::expect_equal(updated_state$panel_config$nrows, 2)
  testthat::expect_equal(updated_state$panel_config$ncols, 3)

  setup_clean_state()
})

# ==============================================================================
# on_high_level_call Tests
# ==============================================================================

test_that("on_high_level_call increments plot index", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  maidr:::on_high_level_call(device_id, 1)

  state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(state$current_plot_index, 1)

  maidr:::on_high_level_call(device_id, 2)

  state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(state$current_plot_index, 2)

  setup_clean_state()
})

test_that("on_high_level_call sets last_high_call_index", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  maidr:::on_high_level_call(device_id, 5)

  state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(state$last_high_call_index, 5)

  setup_clean_state()
})

test_that("on_high_level_call returns NULL invisibly", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  result <- maidr:::on_high_level_call(device_id, 1)

  testthat::expect_null(result)

  setup_clean_state()
})

test_that("on_high_level_call updates current_panel in multi-panel layout", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  # Set up a multi-panel layout
  state <- maidr:::get_device_state(device_id)
  state$layout_active <- TRUE
  state$panel_config <- list(
    type = "mfrow",
    nrows = 2,
    ncols = 2,
    current_panel = 0,
    total_panels = 4
  )
  maidr:::update_device_state(device_id, state)

  # First HIGH call
  maidr:::on_high_level_call(device_id, 1)

  state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(state$panel_config$current_panel, 1)

  # Second HIGH call
  maidr:::on_high_level_call(device_id, 2)

  state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(state$panel_config$current_panel, 2)

  setup_clean_state()
})

# ==============================================================================
# on_layout_call Tests
# ==============================================================================

test_that("on_layout_call handles par with mfrow", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  maidr:::on_layout_call(device_id, "par", list(mfrow = c(2, 3)))

  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$panel_config$type, "mfrow")
  testthat::expect_equal(state$panel_config$nrows, 2)
  testthat::expect_equal(state$panel_config$ncols, 3)
  testthat::expect_equal(state$panel_config$total_panels, 6)
  testthat::expect_true(state$layout_active)

  setup_clean_state()
})

test_that("on_layout_call handles layout with matrix", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  layout_matrix <- matrix(c(1, 2, 3, 3), nrow = 2, ncol = 2, byrow = TRUE)

  maidr:::on_layout_call(device_id, "layout", list(layout_matrix))

  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$panel_config$type, "layout")
  testthat::expect_equal(state$panel_config$nrows, 2)
  testthat::expect_equal(state$panel_config$ncols, 2)
  testthat::expect_equal(state$panel_config$total_panels, 3) # 3 unique panels
  testthat::expect_true(state$layout_active)

  setup_clean_state()
})

test_that("on_layout_call resets current_plot_index", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  # First set a plot index
  maidr:::on_high_level_call(device_id, 1)
  maidr:::on_high_level_call(device_id, 2)

  state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(state$current_plot_index, 2)

  # Now set layout
  maidr:::on_layout_call(device_id, "par", list(mfrow = c(2, 2)))

  state <- maidr:::get_device_state(device_id)
  testthat::expect_equal(state$current_plot_index, 0)

  setup_clean_state()
})

test_that("on_layout_call returns NULL invisibly", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  result <- maidr:::on_layout_call(device_id, "par", list(mfrow = c(1, 1)))

  testthat::expect_null(result)

  setup_clean_state()
})

test_that("on_layout_call ignores par without mfrow", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  # Call par without layout args
  maidr:::on_layout_call(device_id, "par", list(col = "red"))

  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$panel_config$type, "single")
  testthat::expect_false(state$layout_active)

  setup_clean_state()
})

test_that("on_layout_call ignores layout with non-matrix", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  # Call layout without matrix
  maidr:::on_layout_call(device_id, "layout", list(c(1, 2, 3)))

  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$panel_config$type, "single")

  setup_clean_state()
})

# ==============================================================================
# get_current_plot_index Tests
# ==============================================================================

test_that("get_current_plot_index returns correct index", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  testthat::expect_equal(maidr:::get_current_plot_index(device_id), 0)

  maidr:::on_high_level_call(device_id, 1)
  testthat::expect_equal(maidr:::get_current_plot_index(device_id), 1)

  maidr:::on_high_level_call(device_id, 2)
  testthat::expect_equal(maidr:::get_current_plot_index(device_id), 2)

  setup_clean_state()
})

# ==============================================================================
# get_panel_config Tests
# ==============================================================================

test_that("get_panel_config returns panel configuration", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()
  config <- maidr:::get_panel_config(device_id)

  testthat::expect_type(config, "list")
  testthat::expect_true("type" %in% names(config))
  testthat::expect_true("nrows" %in% names(config))
  testthat::expect_true("ncols" %in% names(config))

  setup_clean_state()
})

test_that("get_panel_config reflects layout changes", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  maidr:::on_layout_call(device_id, "par", list(mfrow = c(3, 2)))

  config <- maidr:::get_panel_config(device_id)

  testthat::expect_equal(config$type, "mfrow")
  testthat::expect_equal(config$nrows, 3)
  testthat::expect_equal(config$ncols, 2)

  setup_clean_state()
})

# ==============================================================================
# is_multipanel_active Tests
# ==============================================================================

test_that("is_multipanel_active returns FALSE for single panel", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  testthat::expect_false(maidr:::is_multipanel_active(device_id))

  setup_clean_state()
})

test_that("is_multipanel_active returns TRUE for multi-panel layout", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  maidr:::on_layout_call(device_id, "par", list(mfrow = c(2, 2)))

  testthat::expect_true(maidr:::is_multipanel_active(device_id))

  setup_clean_state()
})

test_that("is_multipanel_active returns FALSE for 1x1 layout", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  maidr:::on_layout_call(device_id, "par", list(mfrow = c(1, 1)))

  testthat::expect_false(maidr:::is_multipanel_active(device_id))

  setup_clean_state()
})

# ==============================================================================
# reset_device_state Tests
# ==============================================================================

test_that("reset_device_state clears state", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  # Set some state
  maidr:::on_high_level_call(device_id, 1)
  maidr:::on_layout_call(device_id, "par", list(mfrow = c(2, 2)))

  # Reset
  maidr:::reset_device_state(device_id)

  # Get fresh state (should be re-initialized)
  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$current_plot_index, 0)
  testthat::expect_equal(state$panel_config$type, "single")

  setup_clean_state()
})

test_that("reset_device_state returns NULL invisibly", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  result <- maidr:::reset_device_state(device_id)

  testthat::expect_null(result)

  setup_clean_state()
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("State tracking works with device storage", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  # Log some calls which should update state
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 1)), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(c(1, 2)), device_id)
  maidr:::log_plot_call_to_device("hist", NULL, list(rnorm(10)), device_id)

  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$current_plot_index, 2)
  testthat::expect_true(state$layout_active)

  setup_clean_state()
})

test_that("State persists across multiple operations", {
  setup_clean_state()

  device_id <- grDevices::dev.cur()

  maidr:::on_layout_call(device_id, "par", list(mfrow = c(2, 2)))

  for (i in 1:4) {
    maidr:::on_high_level_call(device_id, i)
  }

  state <- maidr:::get_device_state(device_id)

  testthat::expect_equal(state$current_plot_index, 4)
  testthat::expect_equal(state$panel_config$current_panel, 4)

  setup_clean_state()
})
