# An export that throws must cost the chart its interactivity, not the save.
#
# The reproducers are `matplot()` and `symbols()`, which fail inside gridSVG's
# `grid.export()`. Those are exercised at the end, guarded, because whether a
# given gridSVG release still fails on them is not this package's contract.
# The contract is the one asserted first: whatever the build raises, a caller
# who has fallback enabled gets a picture.

test_that("a build that throws falls back to the static image", {
  skip_if_not_installed("gridSVG")

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  plot(1:10)

  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      stop("We shouldn't be here!")
    }
  )

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  expect_warning(
    maidr::save_html(plot = NULL, file = file),
    "We shouldn't be here!"
  )

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_true(grepl("base64", html, fixed = TRUE))
})

test_that("the warning names the failure so it can be reported upstream", {
  skip_if_not_installed("gridSVG")

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  plot(1:10)

  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      stop("non-numeric argument to binary operator")
    }
  )

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  expect_warning(
    maidr::save_html(plot = NULL, file = file),
    "non-numeric argument to binary operator"
  )
})

test_that("a caller who disabled fallback gets the error, not the picture", {
  skip_if_not_installed("gridSVG")

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)
  previous <- options(maidr.fallback_enabled = FALSE)
  on.exit(options(previous), add = TRUE)

  plot(1:10)

  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      stop("We shouldn't be here!")
    }
  )

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  expect_error(
    maidr::save_html(plot = NULL, file = file),
    "We shouldn't be here!"
  )
})

test_that("a plot that exports cleanly is still read, not fallen back", {
  skip_if_not_installed("gridSVG")

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  plot(1:10)

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(maidr::save_html(plot = NULL, file = file))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_true(grepl("maidr-data", html, fixed = TRUE))
  expect_false(grepl("base64", html, fixed = TRUE))
})

# The two calls that surfaced this. A gridSVG release that learns to export
# them makes these plots interactive, which is a better outcome and not a
# regression -- so the assertion is on the save completing, not on which of
# the two answers it gives.
test_that("matplot and symbols leave the caller with a file either way", {
  skip_if_not_installed("gridSVG")

  for (draw in list(
    function() matplot(matrix(1:12, 4)),
    function() symbols(1:3, 1:3, circles = c(1, 2, 3), inches = 0.2)
  )) {
    grDevices::pdf(NULL)
    clear_all_device_storage()

    draw()
    file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
    suppressWarnings(maidr::save_html(plot = NULL, file = file))

    expect_true(file.exists(file))
    expect_gt(file.size(file), 0)

    clear_all_device_storage()
    grDevices::dev.off()
  }
})
