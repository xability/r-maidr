# The static picture is drawn with the original functions
#
# A chart that could not be built interactively is still delivered as a
# picture (#216). The picture is drawn by printing the ggplot, or by replaying
# the recorded base R calls, onto a throwaway png() device -- and both of
# those had to go through maidr's own interception to get there.
#
# For ggplot2, a bare `print()` dispatches to `maidr_print_ggplot()`, which
# runs the whole build again, fails again, and asks for the picture again,
# opening another png() device each time until R has no more (~60 nested
# devices), at which point the caller gets neither the chart nor the picture.
#
# For base R, `do.call("barplot", ...)` resolved the name in maidr's
# namespace, where it is the recording wrapper, so the picture's own replay
# was recorded against the png() device. R hands that device number out
# again to the next device opened, and the stale calls surfaced there as
# phantom layers.

test_that("a ggplot that fails to build is drawn once, not recursively", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("gridSVG")

  p <- ggplot2::ggplot(
    data.frame(x = c("a", "b"), y = c(1, 2)),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_col()

  attempts <- 0L
  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      attempts <<- attempts + 1L
      stop("We shouldn't be here!")
    }
  )

  devices_before <- length(grDevices::dev.list())
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)

  expect_warning(
    maidr::save_html(p, file = file),
    "We shouldn't be here!"
  )

  expect_identical(attempts, 1L)
  expect_identical(length(grDevices::dev.list()), devices_before)

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_true(grepl("data:image/png", html, fixed = TRUE))
})

test_that("a base R picture is replayed without recording its own replay", {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  barplot(c(a = 3, b = 1, c = 2))

  img <- create_fallback_image(plot = NULL, format = "png")
  expect_true(grepl("^data:image/png", img))

  # The only device with recorded calls is the one the chart was drawn on;
  # the png() device the picture used left nothing behind.
  summary <- get_device_storage_summary()
  expect_identical(names(summary$devices), as.character(device_id))
})

test_that("a base R picture replays an NSE call the way it was drawn", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  # `curve()` is recorded with its expression unevaluated. Replaying it by
  # name through `do.call()` reached the recording wrapper and skipped the
  # environment the expression has to be evaluated in; through
  # `replay_plot_call()` it is drawn as the original drew it.
  curve(sin(x), 0, pi)

  expect_no_warning(create_fallback_image(plot = NULL, format = "png"))
})

test_that("maidr_set_fallback(format = ) chooses the picture's format", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)
  previous <- options(maidr.fallback_format = "svg")
  on.exit(options(previous), add = TRUE)

  plot(1:10)

  # The image itself is mocked: what is under test is that the configured
  # format reaches the renderer, and `grDevices::svg()` is not available on
  # every platform the suite runs on (the macOS runner has no cairo).
  format_used <- NULL
  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      stop("We shouldn't be here!")
    },
    create_fallback_image = function(plot = NULL, format = "png", ...) {
      format_used <<- format
      "data:image/svg+xml;base64,PHN2Zy8+"
    }
  )

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  expect_warning(maidr::save_html(plot = NULL, file = file))

  expect_identical(format_used, "svg")
})
