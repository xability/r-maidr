# Regression tests for defects found while reviewing the Base R / ggplot2
# correctness sweep. Each test below fails on the code as it stood before
# the corresponding fix; together they pin the behaviour of the paths that
# broke, so the same defects cannot come back silently.

setup_clean <- function() {
  maidr:::clear_all_device_storage()
}

# ==============================================================================
# Auto-show must not end the Base R session
#
# show() clears the recorded calls and closes the temp device, so wiring it
# to a task callback after every top-level HIGH-level call made the most
# basic Base R idiom fail:
#
#   plot(x, y)      # auto-show fires here, tearing the session down
#   abline(h = 1)   # Error: plot.new has not been called yet
# ==============================================================================

test_that("no plotting wrapper schedules auto-show", {
  # The wrappers are built by create_function_wrapper()/create_nse_wrapper();
  # if any of them re-acquires an auto-show call this test fails.
  wrapper_sources <- vapply(
    c(
      "create_function_wrapper",
      "create_nse_wrapper",
      "create_barplot_wrapper",
      "create_axis_wrapper"
    ),
    function(fn_name) {
      paste(deparse(get(fn_name, envir = asNamespace("maidr"))), collapse = " ")
    },
    character(1)
  )

  testthat::expect_false(any(grepl("schedule_auto_show", wrapper_sources)))
})

test_that("a HIGH-level call leaves the session open for overlays", {
  setup_clean()

  plot(1:10, 1:10)
  device_id <- grDevices::dev.cur()

  # The recorded call must survive so that a following low-level overlay
  # still has a plot to draw onto.
  testthat::expect_gt(length(maidr:::get_device_calls(device_id)), 0)
  testthat::expect_error(abline(h = 5), NA)
  testthat::expect_gt(length(maidr:::get_device_calls(device_id)), 1)

  setup_clean()
})

test_that("cancel_auto_show removes maidr's callback by name", {
  # addTaskCallback() returns a POSITION in R's callback list, not a stable
  # handle. Removing by that stale position deletes whichever callback now
  # occupies the slot - potentially another package's.
  victim_fired <- FALSE
  addTaskCallback(function(...) TRUE, name = "maidr_test_innocent_bystander")
  on.exit(
    suppressWarnings(removeTaskCallback("maidr_test_innocent_bystander")),
    add = TRUE
  )

  maidr:::schedule_auto_show()
  maidr:::cancel_auto_show()

  remaining <- getTaskCallbackNames()
  testthat::expect_false("maidr_auto_show" %in% remaining)
  testthat::expect_true("maidr_test_innocent_bystander" %in% remaining)
  testthat::expect_false(victim_fired)
})

# ==============================================================================
# A trailing par(mfrow = c(1, 1)) reset must not collapse the grid
#
#   par(mfrow = c(2, 2)); plot(a); plot(b); plot(c); plot(d)
#   par(mfrow = c(1, 1))   # idiomatic cleanup
#
# The reset comes after every plot, so it governs nothing that was drawn.
# Letting it win dropped three of the four panels.
# ==============================================================================

test_that("panel config ignores a layout call made after the last plot", {
  setup_clean()
  device_id <- grDevices::dev.cur()

  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id)
  for (value in list(c(1, 2), c(3, 4), c(5, 6), c(7, 8))) {
    maidr:::log_plot_call_to_device("barplot", NULL, list(value), device_id)
  }
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(1, 1)), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_equal(config$nrows, 2)
  testthat::expect_equal(config$ncols, 2)
  testthat::expect_true(maidr:::is_multipanel_config(config))

  setup_clean()
})

test_that("a layout call that does govern later plots still wins", {
  setup_clean()
  device_id <- grDevices::dev.cur()

  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(c(1, 2)), device_id)
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(1, 3)), device_id)
  maidr:::log_plot_call_to_device("barplot", NULL, list(c(3, 4)), device_id)

  config <- maidr:::detect_panel_configuration(device_id)

  testthat::expect_equal(config$nrows, 1)
  testthat::expect_equal(config$ncols, 3)

  setup_clean()
})

test_that("layout calls with no plots after them yield no panel config", {
  setup_clean()
  device_id <- grDevices::dev.cur()

  maidr:::log_plot_call_to_device("barplot", NULL, list(c(1, 2)), device_id)
  maidr:::log_plot_call_to_device("par", NULL, list(mfrow = c(2, 2)), device_id)

  testthat::expect_null(maidr:::detect_panel_configuration(device_id))

  setup_clean()
})

# ==============================================================================
# Formula methods resolve `subset =` in parent.frame()
#
# A wrapper displaces that frame, so calls that work in plain R failed:
#   plot(y ~ x, data = d, subset = g == 1)   -> object 'g' not found
#   boxplot(y ~ g, data = d, subset = x > 5) -> ..3 used in an incorrect context
# ==============================================================================

test_that("plot() accepts a formula with subset =", {
  setup_clean()

  df <- data.frame(x = 1:20, y = (1:20)^1.5, g = rep(1:2, 10))
  testthat::expect_error(plot(y ~ x, data = df, subset = g == 1), NA)
  testthat::expect_gt(length(maidr:::get_device_calls(grDevices::dev.cur())), 0)

  setup_clean()
})

test_that("boxplot() accepts a formula with subset =", {
  setup_clean()

  df <- data.frame(x = 1:20, y = (1:20)^1.5, g = rep(c("a", "b"), 10))
  testthat::expect_error(boxplot(y ~ g, data = df, subset = x > 5), NA)

  setup_clean()
})

test_that("the subset = retry works from inside a function scope", {
  setup_clean()

  draw <- function() {
    local_df <- data.frame(x = 1:10, y = 1:10, keep = rep(c(TRUE, FALSE), 5))
    plot(y ~ x, data = local_df, subset = keep)
    TRUE
  }

  testthat::expect_true(draw())

  setup_clean()
})

test_that("a genuinely invalid call still reports its own error", {
  setup_clean()

  # The retry must not mask real user errors behind a different message.
  testthat::expect_error(
    plot(y ~ x, data = data.frame(x = 1:5, y = 1:5), subset = no_such_var > 1),
    "no_such_var"
  )

  setup_clean()
})

# ==============================================================================
# Computation-only calls must not be recorded
#
# barplot(x, plot = FALSE) returns bar midpoints without drawing. Recording
# it injects a phantom bar layer into the next render.
# ==============================================================================

test_that("barplot(plot = FALSE) records nothing", {
  setup_clean()

  midpoints <- barplot(c(a = 1, b = 2), plot = FALSE)

  testthat::expect_equal(length(maidr:::get_device_calls(grDevices::dev.cur())), 0)
  testthat::expect_length(midpoints, 2)

  setup_clean()
})

test_that("barplot(plot = FALSE) does not contaminate the next plot", {
  setup_clean()

  invisible(barplot(c(a = 1, b = 2), plot = FALSE))
  barplot(c(x = 5, y = 6, z = 7))

  calls <- maidr:::get_device_calls(grDevices::dev.cur())
  testthat::expect_equal(length(calls), 1)

  setup_clean()
})

test_that("hist(plot = FALSE) records nothing", {
  setup_clean()

  result <- hist(c(1, 2, 2, 3, 3, 3, 4), plot = FALSE)

  testthat::expect_equal(length(maidr:::get_device_calls(grDevices::dev.cur())), 0)
  testthat::expect_s3_class(result, "histogram")

  setup_clean()
})

# ==============================================================================
# Dodged bars with expression aesthetics
#
# rlang::as_label() renders aes(fill = factor(cyl)) as the STRING
# "factor(cyl)", which is not a column, so data[["factor(cyl)"]] was NULL
# and table() failed with "all arguments must have the same length".
# ==============================================================================

test_that("dodged bars accept an expression fill aesthetic", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    category = rep(c("a", "b", "c"), each = 4),
    grp = rep(c(1, 1, 2, 2), 3)
  )
  plot_obj <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = category, fill = factor(grp))
  ) +
    ggplot2::geom_bar(position = "dodge")

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(plot_obj)

  testthat::expect_type(data, "list")
  testthat::expect_length(data, 2) # one series per fill level
  testthat::expect_length(data[[1]], 3) # one bar per x level
  testthat::expect_equal(data[[1]][[1]]$x, "a")
  testthat::expect_equal(data[[1]][[1]]$y, 2)
})

test_that("dodged bar counts skip combinations that are never drawn", {
  testthat::skip_if_not_installed("ggplot2")

  # "c" never occurs with "v", so ggplot2 draws 5 bars, not 6. Emitting the
  # full cartesian product left the announced data longer than the rect list
  # the selector matches, shifting every later bar's description.
  df <- data.frame(
    category = c("a", "a", "b", "b", "c", "c"),
    grp = c("u", "v", "u", "v", "u", "u")
  )
  plot_obj <- ggplot2::ggplot(df, ggplot2::aes(x = category, fill = grp)) +
    ggplot2::geom_bar(position = "dodge")

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(plot_obj)

  drawn_bars <- nrow(ggplot2::ggplot_build(plot_obj)$data[[1]])
  testthat::expect_equal(sum(vapply(data, length, integer(1))), drawn_bars)

  # no zero-count entry survives
  all_y <- unlist(lapply(data, function(s) vapply(s, function(p) p$y, numeric(1))))
  testthat::expect_false(any(all_y == 0))
})

test_that("dodged bars accept an expression x aesthetic", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(num = rep(c(4, 6), each = 4), grp = rep(c("u", "v"), 4))
  plot_obj <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = factor(num), fill = grp)
  ) +
    ggplot2::geom_bar(position = "dodge")

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))

  testthat::expect_error(processor$extract_data(plot_obj), NA)
})

test_that("dodged bars still work with bare column aesthetics", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    category = rep(c("a", "b"), each = 4),
    grp = factor(rep(c("u", "v"), 4)),
    value = c(1, 2, 3, 4, 5, 6, 7, 8)
  )
  plot_obj <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = category, y = value, fill = grp)
  ) +
    ggplot2::geom_col(position = "dodge")

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(plot_obj)

  testthat::expect_length(data, 2)
  # y values must be plain numbers, never 1x1 data frames
  testthat::expect_true(is.numeric(data[[1]][[1]]$y))
  testthat::expect_length(data[[1]][[1]]$y, 1)
})

test_that("dodged bar values survive a tibble input", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tibble")

  df <- tibble::tibble(
    category = rep(c("a", "b"), each = 2),
    grp = rep(c("u", "v"), 2),
    value = c(10, 20, 30, 40)
  )
  plot_obj <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = category, y = value, fill = grp)
  ) +
    ggplot2::geom_col(position = "dodge")

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(plot_obj)

  testthat::expect_true(is.numeric(data[[1]][[1]]$y))
  testthat::expect_length(data[[1]][[1]]$y, 1)
})

# ==============================================================================
# Faceted boxplots must be labelled from their own panel
#
# The category names were looked up in an UNFILTERED vector of axis
# positions indexed by position within the panel-filtered box list, so
# every panel was announced with panel 1's categories while carrying its
# own values.
# ==============================================================================

test_that("each facet panel's boxes carry that panel's category names", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    grp = c(rep(c("aa", "bb"), each = 6), rep(c("xx", "yy"), each = 6)),
    panel = rep(c("P1", "P2"), each = 12),
    value = c(seq_len(12), seq_len(12) + 20)
  )
  plot_obj <- ggplot2::ggplot(df, ggplot2::aes(grp, value)) +
    ggplot2::geom_boxplot() +
    ggplot2::facet_wrap(~panel)
  built <- ggplot2::ggplot_build(plot_obj)

  processor <- maidr:::Ggplot2BoxplotLayerProcessor$new(list(index = 1))

  panel1 <- processor$extract_data(plot_obj, built, panel_id = 1)
  panel2 <- processor$extract_data(plot_obj, built, panel_id = 2)

  testthat::expect_equal(vapply(panel1, function(b) b$z, character(1)), c("aa", "bb"))
  testthat::expect_equal(vapply(panel2, function(b) b$z, character(1)), c("xx", "yy"))
})

test_that("an unfaceted boxplot still gets its category names", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    grp = rep(c("one", "two"), each = 6),
    value = c(seq_len(6), seq_len(6) + 10)
  )
  plot_obj <- ggplot2::ggplot(df, ggplot2::aes(grp, value)) +
    ggplot2::geom_boxplot()

  processor <- maidr:::Ggplot2BoxplotLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(plot_obj)

  testthat::expect_equal(
    vapply(data, function(b) b$z, character(1)),
    c("one", "two")
  )
})

# ==============================================================================
# matplot(matrix) draws one series per column
#
# Routing a lone matrix through xy.coords() reads a two-column matrix as
# x = column 1, y = column 2, so every series but one disappeared and
# series 1's values were announced as x coordinates.
# ==============================================================================

test_that("matplot(matrix) emits one series per column", {
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))
  values <- matrix(c(1, 2, 3, 10, 20, 30), nrow = 3, ncol = 2)

  data <- processor$extract_data(list(
    plot_call = list(args = list(values)),
    function_name = "matplot"
  ))

  testthat::expect_length(data, 2)
  testthat::expect_length(data[[1]], 3)
  testthat::expect_equal(
    vapply(data[[1]], function(p) p$y, numeric(1)),
    c(1, 2, 3)
  )
  testthat::expect_equal(
    vapply(data[[2]], function(p) p$y, numeric(1)),
    c(10, 20, 30)
  )
})

test_that("plot(matrix) keeps xy.coords semantics", {
  # plot() genuinely does read a two-column matrix as an x/y pair, so the
  # matplot fix must not leak into it.
  processor <- maidr:::BaseRLineLayerProcessor$new(list(index = 1))
  values <- matrix(c(1, 2, 3, 10, 20, 30), nrow = 3, ncol = 2)

  data <- processor$extract_data(list(
    plot_call = list(args = list(values)),
    function_name = "plot"
  ))

  testthat::expect_length(data, 1)
  testthat::expect_equal(
    vapply(data[[1]], function(p) p$y, numeric(1)),
    c(10, 20, 30)
  )
})

test_that("reorder_layer_data sorts data with an expression aesthetic", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    category = c("b", "a", "b", "a"),
    grp = c(2, 2, 1, 1),
    value = c(1, 2, 3, 4)
  )
  plot_obj <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = category, y = value, fill = factor(grp))
  ) +
    ggplot2::geom_col(position = "dodge")

  processor <- maidr:::Ggplot2DodgedBarLayerProcessor$new(list(index = 1))
  reordered <- processor$reorder_layer_data(df, plot_obj)

  # Sorting must actually happen: previously an expression aesthetic fell
  # through the column-name guard and returned the data untouched, leaving
  # the emitted order out of step with the drawn bars.
  testthat::expect_equal(reordered$category, c("a", "a", "b", "b"))
})
