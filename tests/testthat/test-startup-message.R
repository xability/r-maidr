# The startup message is a promise made to every user on every library(maidr),
# so it has to match what the package actually does. It claimed plots were
# displayed automatically, which has never been true for Base R: auto-display
# is wired for ggplot2 through print.ggplot, while Base R plots are recorded
# and wait for an explicit show() (issue #53).

# Set the option rather than inheriting it. `maidr.startup_message = FALSE`
# suppresses the message entirely, so a test that took the ambient value would
# quietly compare its expectations against "" if anything upstream had turned
# it off.
startup_message <- function(enabled = TRUE) {
  previous <- options(maidr.startup_message = enabled)
  on.exit(options(previous), add = TRUE)

  paste(
    utils::capture.output(
      maidr:::.onAttach("lib", "maidr"),
      type = "message"
    ),
    collapse = "\n"
  )
}

test_that("the startup message does not promise Base R auto-display", {
  msg <- startup_message()

  # The old blanket claim covered both systems and was false for one of them.
  testthat::expect_false(
    grepl("Plots are displayed in the maidr interactive viewer by default", msg,
      fixed = TRUE
    )
  )
  testthat::expect_match(msg, "ggplot2 plots open in the maidr interactive viewer")
  testthat::expect_match(msg, "Base R plots are recorded")
  testthat::expect_match(msg, "show()", fixed = TRUE)
})

test_that("the startup message says a lattice chart opens in the viewer when printed", {
  msg <- startup_message()

  # Printed, not drawn: plot() of a trellis object and a print into a file
  # or onto a shared page are lattice's, and the message promises no more.
  testthat::expect_match(
    msg, "lattice plots open in it too when printed at the console",
    fixed = TRUE
  )
})

test_that("the startup message still documents how to turn interception off", {
  msg <- startup_message()

  testthat::expect_match(msg, "maidr_off()", fixed = TRUE)
  testthat::expect_match(msg, "maidr.auto_show = FALSE", fixed = TRUE)
})

test_that("the startup message honours maidr.startup_message", {
  testthat::expect_identical(startup_message(enabled = FALSE), "")
})

test_that("reading the message leaves maidr.startup_message as it found it", {
  previous <- options(maidr.startup_message = NULL)
  on.exit(options(previous), add = TRUE)

  for (ambient in list(TRUE, FALSE, NULL)) {
    options(maidr.startup_message = ambient)
    invisible(startup_message())
    invisible(startup_message(enabled = FALSE))
    testthat::expect_identical(getOption("maidr.startup_message"), ambient)
  }
})

# Note: that Base R auto-display is genuinely unwired -- schedule_auto_show()
# has no caller in the plotting path -- is already pinned by
# test-pr48-regressions.R, which inspects the wrapper sources directly.

test_that("no startup message is printed into a document being knitted", {
  previous <- options(knitr.in.progress = TRUE)
  on.exit(options(previous), add = TRUE)

  # The page would carry it, and it describes a viewer a document's plots
  # do not open.
  testthat::expect_identical(startup_message(), "")
})

test_that("maidr.startup_message = FALSE silences the masking advice too", {
  testthat::local_mocked_bindings(
    packages_masking_maidr = function() "quantmod",
    .package = "maidr"
  )
  testthat::expect_identical(startup_message(enabled = FALSE), "")
  testthat::expect_match(startup_message(), "'quantmod' is attached ahead of 'maidr'", fixed = TRUE)
})
