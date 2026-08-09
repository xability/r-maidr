# Issue #97. Attaching quantmod after maidr, then charting a series, drew a
# plain inaccessible graphic and then died at export with "No Base R plots
# detected. Please create a plot first" -- false, the user *did* draw a chart.
# `package:quantmod` simply sits ahead of `package:maidr` on the search path,
# so the bare call binds to quantmod and maidr's recording wrapper is never
# entered. maidr does not patch quantmod's bindings to win that race, so it
# has to say what happened instead of misreporting it.
#
# WHAT THESE TESTS DO NOT COVER
# -----------------------------
# The masking itself. Which function a bare `chartSeries(...)` resolves to is
# fixed by search-path order at library() time, and a running testthat process
# cannot re-attach maidr behind quantmod to observe it. `attach()`-ing a stand-
# in `package:quantmod` frame (below) reproduces the *search-path state* that
# the diagnostics key off, and therefore pins every message this fix adds --
# but it does not prove that a real `library(quantmod)` masks the wrapper.
# That end of the behaviour is verified out of process against a real
# `R CMD INSTALL`; see the issue for the transcript.

# ==============================================================================
# Helpers
# ==============================================================================

# Put a stand-in `package:quantmod` frame ahead of `package:maidr`, which is
# the exact search-path shape `library(maidr); library(quantmod)` produces.
# Skips rather than lies if the real quantmod is already attached (a second
# frame of the same name would make `detach()` ambiguous) or if maidr is not
# attached at all (nothing to be masked).
with_quantmod_masking <- function(code) {
  testthat::skip_if_not("package:maidr" %in% search())
  testthat::skip_if("package:quantmod" %in% search())

  attach(list(), name = "package:quantmod", warn.conflicts = FALSE)
  on.exit(detach("package:quantmod"), add = TRUE)

  testthat::expect_true(maidr:::quantmod_masks_maidr())
  force(code)
}

startup_messages <- function(expr) {
  paste(
    utils::capture.output(force(expr), type = "message"),
    collapse = "\n"
  )
}

# ==============================================================================
# Search-path detection
# ==============================================================================

test_that("quantmod_masks_maidr() is FALSE when quantmod is not attached", {
  testthat::skip_if("package:quantmod" %in% search())

  testthat::expect_false(maidr:::quantmod_masks_maidr())
})

test_that("quantmod_masks_maidr() is TRUE when quantmod precedes maidr", {
  with_quantmod_masking({
    path <- search()
    testthat::expect_lt(
      match("package:quantmod", path),
      match("package:maidr", path)
    )
  })
})

# ==============================================================================
# The export error names the masking case
# ==============================================================================

test_that("the 'no plots' message is unchanged when quantmod is not attached", {
  testthat::skip_if("package:quantmod" %in% search())

  msg <- maidr:::no_base_r_plots_message()

  testthat::expect_match(msg, "No Base R plots detected")
  testthat::expect_false(grepl("quantmod", msg, fixed = TRUE))
})

test_that("the 'no plots' message names masking when quantmod precedes maidr", {
  with_quantmod_masking({
    msg <- maidr:::no_base_r_plots_message()

    # Still says what it always said -- this is an addition, not a swap.
    testthat::expect_match(msg, "No Base R plots detected")
    # ... plus the part that stops the message from misleading.
    testthat::expect_match(msg, "attached ahead of 'maidr'")
    testthat::expect_match(msg, "maidr::chartSeries()", fixed = TRUE)
  })
})

test_that("show() surfaces the masking advice instead of blaming the user", {
  clear_base_r_state()

  with_quantmod_masking({
    testthat::expect_error(
      maidr::show(plot = NULL),
      "attached ahead of 'maidr'"
    )
  })
})

test_that("save_html() surfaces the masking advice", {
  clear_base_r_state()

  with_quantmod_masking({
    testthat::expect_error(
      maidr::save_html(file = tempfile(fileext = ".html")),
      "attached ahead of 'maidr'"
    )
  })
})

# ==============================================================================
# The attach hook warns at the moment the ordering goes wrong
# ==============================================================================

test_that("the quantmod attach hook reports masking", {
  previous <- options(maidr.startup_message = TRUE)
  on.exit(options(previous), add = TRUE)

  with_quantmod_masking({
    msg <- startup_messages(maidr:::.maidr_quantmod_attach_hook())

    testthat::expect_match(msg, "attached ahead of 'maidr'")
    testthat::expect_match(msg, "maidr::chartSeries()", fixed = TRUE)
  })
})

test_that("the attach hook is silent when there is no masking", {
  testthat::skip_if("package:quantmod" %in% search())
  previous <- options(maidr.startup_message = TRUE)
  on.exit(options(previous), add = TRUE)

  testthat::expect_identical(
    startup_messages(maidr:::.maidr_quantmod_attach_hook()),
    ""
  )
})

test_that("the attach hook honours maidr.startup_message", {
  previous <- options(maidr.startup_message = FALSE)
  on.exit(options(previous), add = TRUE)

  with_quantmod_masking({
    testthat::expect_identical(
      startup_messages(maidr:::.maidr_quantmod_attach_hook()),
      ""
    )
  })
})

test_that(".onAttach mentions masking when maidr lands behind quantmod", {
  previous <- options(maidr.startup_message = TRUE)
  on.exit(options(previous), add = TRUE)

  with_quantmod_masking({
    msg <- startup_messages(maidr:::.onAttach("lib", "maidr"))

    testthat::expect_match(msg, "maidr .* loaded")
    testthat::expect_match(msg, "attached ahead of 'maidr'")
  })
})

# ==============================================================================
# Hook registration and teardown
# ==============================================================================

test_that(".onLoad registers an attach hook and .onUnload removes it", {
  event <- packageEvent("quantmod", "attach")
  before <- getHook(event)
  on.exit(setHook(event, before, action = "replace"), add = TRUE)

  setHook(event, list(), action = "replace")
  maidr:::.onLoad("lib", "maidr")

  installed <- getHook(event)
  is_maidr_hook <- vapply(
    installed, identical, logical(1), maidr:::.maidr_quantmod_attach_hook
  )
  testthat::expect_true(any(is_maidr_hook))

  # CRAN policy: unloading must not leave session state behind.
  maidr:::.onUnload("lib")
  remaining <- getHook(event)
  still_there <- vapply(
    remaining, identical, logical(1), maidr:::.maidr_quantmod_attach_hook
  )
  testthat::expect_false(any(still_there))
})

# ==============================================================================
# The `@`-slot crash on the namespace-only path
# ==============================================================================

# `maidr::chartSeries()` forwards through `...`, but quantmod records its own
# arguments with match.call(expand.dots = TRUE). Through `...` that record
# holds the dot symbols (`..3`), so an explicit `TA = NULL` arrived as a
# `name` and quantmod died reaching for the `call` S4 slot of each element of
# the `TA` entry in the chob's `passed.args`, with "no applicable method for
# `@` applied to an object of class \"name\"".
test_that("maidr::chartSeries(TA = NULL) does not hit quantmod's `@` crash", {
  testthat::skip_if_not_installed("quantmod")
  testthat::skip_if_not_installed("xts")

  dates <- as.Date(c("2023-01-02", "2023-01-03", "2023-01-04", "2023-01-05"))
  m <- cbind(
    Open = c(100, 105, 110, 108),
    High = c(115, 108, 112, 110),
    Low = c(95, 102, 105, 100),
    Close = c(110, 103, 111, 108)
  )
  colnames(m) <- paste0("TST.", colnames(m))
  series <- xts::xts(m, order.by = dates)

  clear_base_r_state()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  testthat::expect_no_error(
    maidr::chartSeries(series, type = "candlesticks", TA = NULL)
  )

  # Recorded, not merely survived: the retry must still reach the logger.
  calls <- maidr:::get_device_calls(grDevices::dev.cur())
  recorded <- vapply(calls, function(x) x$function_name, character(1))
  testthat::expect_true("chartSeries" %in% recorded)

  clear_base_r_state()
})

test_that("a bare `...` forward into quantmod is what corrupts TA = NULL", {
  testthat::skip_if_not_installed("quantmod")
  testthat::skip_if_not_installed("xts")

  dates <- as.Date(c("2023-01-02", "2023-01-03"))
  m <- cbind(Open = c(1, 2), High = c(3, 4), Low = c(0, 1), Close = c(2, 3))
  colnames(m) <- paste0("TST.", colnames(m))
  series <- xts::xts(m, order.by = dates)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  # Pins the upstream behaviour the fix works around, so that if quantmod
  # ever stops mangling forwarded dots the workaround can be retired.
  forwarder <- function(...) quantmod::chartSeries(...)
  testthat::expect_error(
    forwarder(series, type = "candlesticks", TA = NULL),
    "applied to an object of class"
  )

  # ... and that rebuilding the call in the caller's frame is the cure.
  recorded_call <- quote(
    chartSeries(series, type = "candlesticks", TA = NULL)
  )
  testthat::expect_no_error(
    maidr:::retry_call_in_caller_frame(
      quantmod::chartSeries, recorded_call, environment(),
      simpleError("unused")
    )
  )
})
