# A title that is not text is announced as empty, not fatal
#
# `main = expression(alpha^2)` is the ordinary way to put a Greek letter on a
# base R chart. A dozen readers passed the recorded value through as the
# layer's `title`, and `jsonlite::toJSON()` has no method for an expression,
# so the save failed on the title of a chart it had otherwise read.

test_that("an expression title does not fail the save", {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_base_r_device(device_id)
  on.exit(clear_base_r_device(device_id), add = TRUE)

  # gridGraphics warns on an expression title while echoing the drawing;
  # that is its reading of `title()`, not this package's.
  suppressWarnings(plot(1:5, main = expression(alpha^2)))

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(maidr::save_html(plot = NULL, file = file))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  testthat::expect_true(grepl("maidr-data", html, fixed = TRUE))
})

test_that("recorded_main_title reads text and declines the rest", {
  testthat::expect_identical(maidr:::recorded_main_title(list(main = "Title")), "Title")
  testthat::expect_identical(maidr:::recorded_main_title(list()), "")
  testthat::expect_identical(maidr:::recorded_main_title(NULL), "")
  testthat::expect_identical(
    maidr:::recorded_main_title(list(main = expression(alpha^2))),
    ""
  )
  testthat::expect_identical(maidr:::recorded_main_title(list(main = quote(x))), "")
  testthat::expect_identical(maidr:::recorded_main_title(list(main = NA)), "")
})
