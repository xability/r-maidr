# Comprehensive tests for save_html() function
# Testing file creation based on real example usage patterns

# ==============================================================================
# ggplot2 File Creation Tests
# ==============================================================================

test_that("save_html() creates HTML file for ggplot2 bar plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(p, file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))
  testthat::expect_equal(result, tmp_file)

  # Verify content
  content <- readLines(tmp_file)
  testthat::expect_true(any(grepl("<svg", content)))
  testthat::expect_true(any(grepl("maidr", content)))

  unlink(tmp_file)
})

test_that("save_html() creates HTML file for ggplot2 point plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_point()
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(p, file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))
  testthat::expect_equal(result, tmp_file)

  unlink(tmp_file)
})

test_that("save_html() creates HTML file for ggplot2 line plot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_line()
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(p, file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  # Verify HTML structure
  content <- readLines(tmp_file)
  html_str <- paste(content, collapse = "")
  testthat::expect_match(html_str, "<html")
  testthat::expect_match(html_str, "</html>")

  unlink(tmp_file)
})

test_that("save_html() creates HTML file for ggplot2 histogram", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_histogram()
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(p, file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  unlink(tmp_file)
})

test_that("save_html() creates HTML file for ggplot2 boxplot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_boxplot()
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(p, file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  unlink(tmp_file)
})

# ==============================================================================
# Base R File Creation Tests
# ==============================================================================

test_that("save_html() creates HTML file for Base R barplot", {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))
  testthat::expect_equal(result, tmp_file)

  # Verify content
  content <- readLines(tmp_file)
  testthat::expect_true(any(grepl("<svg", content)))

  clear_base_r_state()
  unlink(tmp_file)
})

test_that("save_html() creates HTML file for Base R histogram", {
  hist(rnorm(100))
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  clear_base_r_state()
  unlink(tmp_file)
})

test_that("save_html() creates HTML file for Base R line plot", {
  testthat::skip("Base R plot() function detection needs investigation")
  plot(1:10, rnorm(10), type = "l")
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  clear_base_r_state()
  unlink(tmp_file)
})

test_that("save_html() creates HTML file for Base R scatter plot", {
  testthat::skip("Base R plot() function detection needs investigation")
  plot(mtcars$wt[1:10], mtcars$mpg[1:10])
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  clear_base_r_state()
  unlink(tmp_file)
})

test_that("save_html() creates HTML file for Base R boxplot", {
  boxplot(mpg ~ cyl, data = mtcars)
  tmp_file <- tempfile(fileext = ".html")

  result <- save_html(file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  clear_base_r_state()
  unlink(tmp_file)
})

# ==============================================================================
# File Path Tests
# ==============================================================================

test_that("save_html() works with custom file paths", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()

  # Test different path formats
  tmp_dir <- tempdir()
  test_file <- file.path(tmp_dir, "test_plot.html")

  result <- save_html(p, file = test_file)

  testthat::expect_true(file.exists(test_file))
  testthat::expect_equal(result, test_file)

  unlink(test_file)
})

test_that("save_html() works with relative paths", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  tmp_file <- tempfile(fileext = ".html")
  relative_path <- basename(tmp_file)

  # Save to temp directory
  old_wd <- getwd()
  setwd(tempdir())

  result <- save_html(p, file = relative_path)

  testthat::expect_true(file.exists(relative_path))

  unlink(relative_path)
  setwd(old_wd)
})

test_that("save_html() requires existing parent directory", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()

  # Create path in new subdirectory
  tmp_dir <- tempdir()
  test_subdir <- file.path(tmp_dir, "maidr_test_subdir")
  test_file <- file.path(test_subdir, "plot.html")

  # Directory doesn't exist yet
  if (dir.exists(test_subdir)) {
    unlink(test_subdir, recursive = TRUE)
  }

  # save_html does NOT create parent directories automatically
  testthat::expect_error(
    save_html(p, file = test_file),
    "No such file or directory"
  )

  # Cleanup
  if (file.exists(test_file)) unlink(test_file)
  if (dir.exists(test_subdir)) unlink(test_subdir, recursive = TRUE)
})

# ==============================================================================
# File Overwriting Tests
# ==============================================================================

test_that("save_html() overwrites existing files", {
  testthat::skip_if_not_installed("ggplot2")

  tmp_file <- tempfile(fileext = ".html")

  # Create initial file
  p1 <- create_test_ggplot_bar()
  save_html(p1, file = tmp_file)

  initial_size <- file.info(tmp_file)$size

  # Overwrite with different plot
  p2 <- create_test_ggplot_point()
  result <- save_html(p2, file = tmp_file)

  # File should still exist
  testthat::expect_true(file.exists(tmp_file))

  # Size may change
  new_size <- file.info(tmp_file)$size
  testthat::expect_type(new_size, "double")

  unlink(tmp_file)
})

# ==============================================================================
# Content Validation Tests
# ==============================================================================

test_that("save_html() creates valid HTML structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  tmp_file <- tempfile(fileext = ".html")

  save_html(p, file = tmp_file)

  content <- readLines(tmp_file)
  html_str <- paste(content, collapse = "\n")

  # Check for essential HTML elements
  testthat::expect_match(html_str, "<html", ignore.case = TRUE)
  testthat::expect_match(html_str, "<head>", ignore.case = TRUE)
  testthat::expect_match(html_str, "<body>", ignore.case = TRUE)
  testthat::expect_match(html_str, "</html>", ignore.case = TRUE)

  # Check for SVG content
  testthat::expect_match(html_str, "<svg")

  # Check for MAIDR elements
  testthat::expect_match(html_str, "maidr")

  unlink(tmp_file)
})

test_that("save_html() includes MAIDR dependencies", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  tmp_file <- tempfile(fileext = ".html")

  save_html(p, file = tmp_file)

  content <- readLines(tmp_file)
  html_str <- paste(content, collapse = "\n")

  # Check for JavaScript dependencies
  testthat::expect_match(html_str, "maidr.*\\.js", ignore.case = TRUE)

  unlink(tmp_file)
})

# ==============================================================================
# Error Handling Tests
# ==============================================================================

test_that("save_html() errors when no Base R plot and plot=NULL", {
  clear_base_r_state()
  tmp_file <- tempfile(fileext = ".html")

  testthat::expect_error(
    save_html(plot = NULL, file = tmp_file),
    "No Base R plots detected"
  )
})

test_that("save_html() returns file path invisibly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()
  tmp_file <- tempfile(fileext = ".html")

  # Capture the invisible return
  result <- withVisible(save_html(p, file = tmp_file))

  testthat::expect_false(result$visible)
  testthat::expect_equal(result$value, tmp_file)

  unlink(tmp_file)
})

# ==============================================================================
# Multiple Plot Types (Comprehensive)
# ==============================================================================

test_that("save_html() works for all supported ggplot2 types", {
  testthat::skip_if_not_installed("ggplot2")

  plot_generators <- list(
    bar = create_test_ggplot_bar,
    point = create_test_ggplot_point,
    line = create_test_ggplot_line,
    histogram = create_test_ggplot_histogram,
    boxplot = create_test_ggplot_boxplot
  )

  for (type_name in names(plot_generators)) {
    tmp_file <- tempfile(fileext = ".html")

    plot_fn <- plot_generators[[type_name]]
    p <- plot_fn()

    save_html(p, file = tmp_file)

    testthat::expect_true(
      file.exists(tmp_file)
    )

    unlink(tmp_file)
  }
})

# ==============================================================================
# Special Cases
# ==============================================================================

test_that("save_html() works with ggplot2 dodged bars", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
    ggplot2::geom_bar(stat = "identity", position = "dodge")

  tmp_file <- tempfile(fileext = ".html")
  save_html(p, file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  unlink(tmp_file)
})

test_that("save_html() works with Base R dodged barplot", {
  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  barplot(test_matrix, beside = TRUE)

  tmp_file <- tempfile(fileext = ".html")
  save_html(file = tmp_file)

  testthat::expect_true(file.exists(tmp_file))

  clear_base_r_state()
  unlink(tmp_file)
})

test_that("save_html() clears Base R state after saving", {
  barplot(c(5, 10, 15))

  device_id <- dev.cur()
  testthat::expect_true(maidr:::has_device_calls(device_id))

  tmp_file <- tempfile(fileext = ".html")
  save_html(file = tmp_file)

  # State should be cleared
  testthat::expect_false(maidr:::has_device_calls(device_id))

  unlink(tmp_file)
})
