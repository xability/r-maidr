# The startup message is a promise made to every user on every library(maidr),
# so it has to match what the package actually does. It claimed plots were
# displayed automatically, which has never been true for Base R: auto-display
# is wired for ggplot2 through print.ggplot, while Base R plots are recorded
# and wait for an explicit show() (issue #53).

startup_message <- function() {
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

test_that("the startup message still documents how to turn interception off", {
  msg <- startup_message()

  testthat::expect_match(msg, "maidr_off()", fixed = TRUE)
  testthat::expect_match(msg, "maidr.auto_show = FALSE", fixed = TRUE)
})

test_that("the startup message honours maidr.startup_message", {
  withr_option <- getOption("maidr.startup_message")
  on.exit(options(maidr.startup_message = withr_option), add = TRUE)

  options(maidr.startup_message = FALSE)
  testthat::expect_identical(startup_message(), "")
})

# Note: that Base R auto-display is genuinely unwired -- schedule_auto_show()
# has no caller in the plotting path -- is already pinned by
# test-pr48-regressions.R, which inspects the wrapper sources directly.
