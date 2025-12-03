# Minimal smoke tests to verify test infrastructure works

test_that("package loads successfully", {
  expect_true("maidr" %in% loadedNamespaces())
})

test_that("main functions exist", {
  expect_true(exists("show"))
  expect_true(exists("save_html"))
  expect_true(exists("maidr_widget"))
})

test_that("show() works with basic ggplot2 plot (widget mode)", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()

  # Test widget mode (no browser opening)
  widget <- show(p, as_widget = TRUE)
  expect_valid_maidr_widget(widget)
})

test_that("show() works with basic Base R plot (shiny mode)", {
  # Create plot directly in test (not in helper) so it persists
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  # Test shiny mode (returns HTML, no browser opening)
  html <- show(shiny = TRUE)
  expect_html_has_maidr(html)

  # Cleanup
  clear_base_r_state()
})

test_that("registry exists and detects systems", {
  registry <- maidr:::get_global_registry()

  expect_s3_class(registry, "PlotSystemRegistry")
  expect_true(is.function(registry$detect_system))
  expect_true(is.function(registry$get_adapter))
})

test_that("ggplot2 adapter exists and can detect ggplot objects", {
  testthat::skip_if_not_installed("ggplot2")

  registry <- maidr:::get_global_registry()
  adapter <- registry$get_adapter("ggplot2")

  testthat::expect_s3_class(adapter, "Ggplot2Adapter")

  # Should detect ggplot object
  p <- create_test_ggplot_bar()
  testthat::expect_true(adapter$can_handle(p))

  # Should not detect non-ggplot
  testthat::expect_false(adapter$can_handle(NULL))
  testthat::expect_false(adapter$can_handle(42))
})

test_that("Base R adapter exists and can detect Base R plots", {
  registry <- maidr:::get_global_registry()
  adapter <- registry$get_adapter("base_r")

  testthat::expect_s3_class(adapter, "BaseRAdapter")

  # Should not detect when no plot
  clear_base_r_state()
  testthat::expect_false(adapter$can_handle(NULL))

  # Should detect after plot created (create directly in test)
  barplot(c(10, 20, 30))
  testthat::expect_true(adapter$can_handle(NULL))

  # Cleanup
  clear_base_r_state()
})

test_that("save_html() creates HTML file with ggplot2", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(p, file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))
  testthat::expect_equal(result, tmp_file)

  # Cleanup
  unlink(tmp_file)
})

test_that("save_html() creates HTML file with Base R", {
  # Create plot directly in test
  barplot(c(10, 20, 30))
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  # Cleanup
  clear_base_r_state()
  unlink(tmp_file)
})

test_that("maidr_widget() creates htmlwidget", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()
  widget <- maidr_widget(p)

  expect_valid_maidr_widget(widget)
})
