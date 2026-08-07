# Tests for the knitr integration in R/knitr_support.R

# ==============================================================================
# Setup and Teardown
# ==============================================================================

# maidr_on()/maidr_off() mutate global state (options, Base R patching, knitr
# hooks). Snapshot everything we touch so the rest of the suite is unaffected.
save_knitr_env <- function() {
  knitr_state <- maidr:::.maidr_knitr_state

  state <- list(
    options = options("maidr.auto_show", "maidr.base_r", "maidr.ggplot2"),
    patching_active = maidr:::is_patching_active(),
    plot_hook = NULL,
    original_plot_hook = knitr_state$original_plot_hook,
    enabled = knitr_state$enabled
  )

  if (requireNamespace("knitr", quietly = TRUE)) {
    state$plot_hook <- knitr::knit_hooks$get("plot")
  }

  state
}

restore_knitr_env <- function(state) {
  # Go back through maidr_on()/maidr_off() rather than writing the flag
  # directly: they install and remove the Base R wrappers as well as setting
  # it, and a flag that disagrees with which wrappers are installed is worse
  # than either state on its own.
  if (isTRUE(state$patching_active)) {
    maidr::maidr_on()
  } else {
    maidr::maidr_off()
  }

  if (requireNamespace("knitr", quietly = TRUE) && !is.null(state$plot_hook)) {
    knitr::knit_hooks$set(plot = state$plot_hook)
  }

  knitr_state <- maidr:::.maidr_knitr_state
  knitr_state$original_plot_hook <- state$original_plot_hook
  knitr_state$enabled <- state$enabled
  # Last, so the saved values win over whatever maidr_on()/maidr_off() set.
  options(state$options)
  maidr:::clear_all_device_storage()

  invisible(NULL)
}

# ==============================================================================
# maidr_plot_hook Tests
# ==============================================================================

test_that("maidr_plot_hook clears device storage when interception is off", {
  testthat::skip_if_not_installed("knitr")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)

  maidr::maidr_on()
  maidr:::clear_all_device_storage()

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    tryCatch(grDevices::dev.off(device_id), error = function(e) NULL),
    add = TRUE
  )

  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  testthat::expect_true(maidr:::has_device_calls(device_id))

  # maidr_off() disables interception; the hook must behave like the original
  # hook AND drop what was already recorded, rather than leaving it behind.
  maidr::maidr_off()
  testthat::expect_false(maidr:::is_base_r_enabled())

  maidr:::maidr_plot_hook("figure-1.png", list())

  testthat::expect_false(maidr:::has_device_calls(device_id))
  testthat::expect_length(maidr:::get_device_calls(device_id), 0)
})

test_that("toggling maidr_off()/maidr_on() does not leak phantom layers", {
  testthat::skip_if_not_installed("knitr")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)

  maidr::maidr_on()
  maidr:::clear_all_device_storage()

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    tryCatch(grDevices::dev.off(device_id), error = function(e) NULL),
    add = TRUE
  )

  # Chunk 1: recorded while interception is on.
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  # Chunk 2: rendered after maidr_off() - the stale barplot must not survive.
  maidr::maidr_off()
  maidr:::maidr_plot_hook("figure-1.png", list())

  # Chunk 3: interception back on, a brand new plot.
  maidr::maidr_on()
  hist(c(1, 2, 2, 3, 3, 3, 4, 4, 5))

  calls <- maidr:::get_device_calls(device_id)
  recorded <- vapply(calls, function(entry) entry$function_name, character(1))

  testthat::expect_false("barplot" %in% recorded)
  testthat::expect_true("hist" %in% recorded)
})

test_that("the test helpers leave global patching state as they found it", {
  testthat::skip_if_not_installed("knitr")

  # These tests call maidr_on()/maidr_off(), which install and remove the Base
  # R wrappers globally. Without this the first test above -- which ends with
  # interception off -- would leave it off for whatever runs next, making the
  # suite quietly order-dependent.
  for (start_on in c(TRUE, FALSE)) {
    if (start_on) maidr::maidr_on() else maidr::maidr_off()
    before <- maidr:::is_patching_active()

    env_state <- save_knitr_env()
    if (start_on) maidr::maidr_off() else maidr::maidr_on()
    restore_knitr_env(env_state)

    testthat::expect_identical(maidr:::is_patching_active(), before)
  }

  maidr::maidr_on()
})
