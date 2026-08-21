# Eight base R calls were not recorded at all, so the save stopped (#216)
#
# `classify_function()` returns "UNKNOWN" for a name in none of the three
# lists, the wrapper is never installed, and the call is never logged. The
# device then looks empty and `save_html()` raises
#
#     No Base R plots detected. Please create a plot first
#
# which is the right message for `plot.new()` and a false one for a caller
# whose chart is on the device. Measured before the fix, all eight of
# `persp`, `sunflowerplot`, `fourfoldplot`, `spineplot`, `cdplot`, `qqnorm`,
# `qqplot` and `filled.contour` raised it, while `dotchart` and `mosaicplot`
# -- unread too, but listed in HIGH -- degraded correctly to a picture.
#
# Listed in HIGH they take that same route: no branch in
# `detect_layer_type()`, so the switch falls through to "unknown",
# `unsupported_layer_flags()` sees it, and the static-image path runs.
# That is the LOWER of the two claims, not a reading.
#
# `qqnorm(x, plot.it = FALSE)` is the case that has to come with it: it is
# how you *compute* theoretical quantiles and it draws nothing, so recording
# it put a call on a blank device and the save failed the other way, with
# "Failed to create fallback image". The wrapper already declined
# `hist(x, plot = FALSE)`; `plot.it` is the same request under the spelling
# `qqnorm()` and `qqplot()` use, and both of those are now recorded, so both
# need it.

skip_unless_jsonlite <- function() {
  testthat::skip_if_not_installed("jsonlite")
}

# Draw on an off-screen device, save as a user would, report what arrived.
# Errors are captured rather than raised, because "it raised at all" is the
# defect under test.
save_base_figure <- function(plot_fun) {
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      while (grDevices::dev.cur() != 1L) grDevices::dev.off()
      unlink(file)
      clear_all_device_storage()
    },
    add = TRUE
  )

  warnings_seen <- character(0)
  error_seen <- NULL
  withCallingHandlers(
    tryCatch(
      {
        plot_fun()
        maidr::save_html(plot = NULL, file = file)
      },
      error = function(e) {
        error_seen <<- conditionMessage(e)
      }
    ),
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  html <- if (is.null(error_seen) && file.exists(file)) {
    paste(readLines(file, warn = FALSE), collapse = "\n")
  } else {
    ""
  }

  list(
    error = error_seen,
    fell_back = grepl("base64", html, fixed = TRUE),
    warned = any(grepl("unsupported elements", warnings_seen, fixed = TRUE)),
    html = html
  )
}

# Each of the eight, with the smallest call that draws one.
unrecorded_calls <- list(
  persp = function() {
    z <- outer(
      seq(-2, 2, length.out = 12),
      seq(-2, 2, length.out = 12),
      function(a, b) a * b
    )
    persp(z = z)
  },
  sunflowerplot = function() {
    sunflowerplot(c(1, 1, 2, 2, 3), c(1, 1, 2, 3, 3))
  },
  fourfoldplot = function() fourfoldplot(matrix(c(10, 5, 3, 12), nrow = 2)),
  spineplot = function() spineplot(factor(c("a", "a", "b")) ~ c(1, 2, 3)),
  cdplot = function() {
    cdplot(factor(c("a", "a", "b", "b")) ~ c(1, 2, 3, 4))
  },
  qqnorm = function() qqnorm(c(1, 2, 3, 4, 5, 6, 7, 8)),
  qqplot = function() qqplot(c(1, 2, 3, 4), c(2, 3, 4, 5)),
  filled.contour = function() filled.contour(matrix(1:12, nrow = 3))
)


test_that("none of the eight stops the save any more", {
  skip_unless_jsonlite()

  for (name in names(unrecorded_calls)) {
    result <- save_base_figure(unrecorded_calls[[name]])
    expect_null(result$error, info = name)
  }
})

test_that("each of the eight falls back to a picture, and says so", {
  skip_unless_jsonlite()

  for (name in names(unrecorded_calls)) {
    result <- save_base_figure(unrecorded_calls[[name]])
    expect_true(result$fell_back, info = name)
    expect_true(result$warned, info = name)
  }
})

test_that("it is the same path a recorded-but-unread call already took", {
  skip_unless_jsonlite()

  # `dotchart` has always degraded correctly, being in HIGH with no
  # processor. Asserted beside the eight so the two cannot drift apart.
  result <- save_base_figure(function() dotchart(c(3, 7, 5)))

  expect_null(result$error)
  expect_true(result$fell_back)
  expect_true(result$warned)
})

# One PNG through the device `create_fallback_image()` uses: 7x5 inches at
# 150 dpi, which is the 1050x750 the header check below expects.
png_bytes <- function(draw) {
  file <- tempfile(fileext = ".png")
  on.exit(unlink(file), add = TRUE)
  grDevices::png(file, width = 7 * 150, height = 5 * 150, res = 150)
  suppressWarnings(draw())
  grDevices::dev.off()
  file.info(file)$size
}


test_that("the picture is the chart, not a blank canvas", {
  skip_unless_jsonlite()
  skip_if_not_installed("base64enc")

  # The replay has to rebuild `factor(...) ~ x` in the caller's frame, so a
  # fallback that silently drew nothing would still pass every assertion
  # above.
  #
  # Measured against two references rendered on the same machine, rather
  # than against a byte count: this first read `> 10000`, calibrated on
  # Linux, and the identical chart encodes to 9,600 bytes on Windows -- a
  # threshold that was really asserting which PNG encoder ran. Asking
  # whether the captured image is nearer the chart than an empty page is
  # the question that was meant, and it needs no constant at all.
  blank <- png_bytes(function() graphics::plot.new())
  reference <- png_bytes(unrecorded_calls$spineplot)
  expect_gt(reference, blank)

  result <- save_base_figure(unrecorded_calls$spineplot)
  encoded <- regmatches(
    result$html,
    regexpr("base64,[A-Za-z0-9+/=]+", result$html)
  )
  expect_length(encoded, 1)

  decoded <- base64enc::base64decode(sub("^base64,", "", encoded))
  expect_gt(length(decoded), (blank + reference) / 2)

  # The PNG header carries the size: bytes 17-24 of IHDR, big-endian. A
  # capture that produced a thumbnail or an empty page would not match the
  # device the fallback asks for.
  header <- as.integer(decoded[1:24])
  expect_equal(sum(header[17:20] * 256^(3:0)), 1050)
  expect_equal(sum(header[21:24] * 256^(3:0)), 750)
})

test_that("a call that computes without drawing is still not recorded", {
  skip_unless_jsonlite()

  # `qqnorm(x, plot.it = FALSE)` returns the quantiles and draws nothing.
  # Recorded, it would send an empty device down the fallback path and fail
  # with "Failed to create fallback image" -- a worse answer than the one
  # this call has always had, which is correct for a device with no plot.
  result <- save_base_figure(function() {
    qqnorm(c(1, 2, 3, 4), plot.it = FALSE)
  })

  expect_match(result$error, "No Base R plots detected")
  expect_false(result$fell_back)
})

test_that("plot.it = FALSE is refused without disturbing plot = FALSE", {
  skip_unless_jsonlite()

  # The guard gained a second name; this pins that it kept the first. Both
  # spellings mean the same thing and neither may reach the recorder.
  computed <- save_base_figure(function() hist(c(1, 2, 3), plot = FALSE))
  expect_match(computed$error, "No Base R plots detected")

  # `cdplot.default` has a real `plot` argument, unlike most of the eight,
  # so the existing half of the guard covers it.
  computed <- save_base_figure(function() {
    cdplot(factor(c("a", "a", "b", "b")) ~ c(1, 2, 3, 4), plot = FALSE)
  })
  expect_match(computed$error, "No Base R plots detected")

  # The other function that spells it `plot.it`. Asserted separately from
  # `qqnorm` because the guard reads the argument off the recorded call, so
  # it holds for a second function only if that function is recorded at all.
  computed <- save_base_figure(function() {
    qqplot(c(1, 2, 3, 4), c(2, 3, 4, 5), plot.it = FALSE)
  })
  expect_match(computed$error, "No Base R plots detected")
})

test_that("qqnorm still hands back the quantiles it computed", {
  # The wrapper returns the original's value; a chart the package cannot read
  # must not also break the call's contract as a computation.
  clear_all_device_storage()
  grDevices::pdf(NULL)
  on.exit(
    {
      while (grDevices::dev.cur() != 1L) grDevices::dev.off()
      clear_all_device_storage()
    },
    add = TRUE
  )

  drawn <- qqnorm(c(1, 2, 3, 4))
  expect_equal(drawn$y, c(1, 2, 3, 4))

  computed <- qqnorm(c(1, 2, 3, 4), plot.it = FALSE)
  expect_equal(computed$y, c(1, 2, 3, 4))
})

test_that("the charts that already read still read", {
  skip_unless_jsonlite()

  # Eight names added to HIGH and one name to the computation-only guard.
  # This pins that neither reached a chart with a processor.
  result <- save_base_figure(function() barplot(c(a = 1, b = 2, c = 3)))
  expect_null(result$error)
  expect_false(result$fell_back)

  result <- save_base_figure(function() plot(1:10, (1:10)^2))
  expect_null(result$error)
  expect_false(result$fell_back)

  result <- save_base_figure(function() hist(c(1, 2, 2, 3, 3, 3)))
  expect_null(result$error)
  expect_false(result$fell_back)
})

test_that("all eight are classified, and classification is what changed", {
  for (name in names(unrecorded_calls)) {
    expect_equal(classify_function(name), "HIGH", info = name)
  }

  # Being in HIGH is not a claim that the type is read: none of the eight
  # gains a `detect_layer_type()` branch, so each falls through to "unknown".
  factory <- BaseRProcessorFactory$new()
  for (name in names(unrecorded_calls)) {
    expect_false(name %in% factory$get_supported_types(), info = name)
  }
})
