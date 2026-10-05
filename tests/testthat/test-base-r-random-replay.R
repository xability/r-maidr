# A chart that draws random numbers is exported as the reader was shown it
#
# maidr exports a Base R chart by drawing the recorded call again. A call
# that draws random numbers -- `wordcloud()` turns each word at random and
# places it along a random spiral, `stripchart(method = "jitter")` jitters
# its points -- drew from whatever state the session had by then, so the
# page showed a different chart from the one on the reader's device, and a
# different one again on every save. Each call now keeps the random state it
# started from, and the replay draws from it.
#
# The state is noted in `ensure_maidr_device()`, which every recording
# wrapper calls before it draws: the generated wrappers and the stubs maidr
# exports for packages that load after it, `maidr::wordcloud()` among them.
# The word cloud cases go through that stub and the strip chart through a
# generated wrapper, so both paths are held to it.
#
# The replay puts the session's own state back afterwards: exporting a chart
# no longer moves a script's random numbers on, which changed what every
# `set.seed()` gave the calls after it.

#' Keep the session's random state as the test found it
keep_random_state <- function(env = parent.frame()) {
  state <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
  withr::defer(
    if (is.null(state)) {
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(".Random.seed", envir = globalenv())
      }
    } else {
      assign(".Random.seed", state, envir = globalenv())
    },
    envir = env
  )
}

#' Draw on a fresh recording device, returning its id
random_device <- function(draw, env = parent.frame()) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  withr::defer(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off(device_id)
    },
    envir = env
  )
  draw()
  device_id
}

#' The drawing maidr exports for a device
exported_drawing <- function(device_id) {
  BaseRPlotOrchestrator$new(device_id)$get_gtable()
}

#' A drawing made by base graphics alone, echoed as grid grobs on a page of
#' the export's size, so the two can be compared grob for grob
shown_drawing <- function(draw) {
  grid::grid.grabExpr(
    gridGraphics::grid.echo(draw),
    warn = 0, width = 7, height = 5
  )
}

#' One field of every grob of a class in a drawing, in grob order
grob_field <- function(gt, class, field) {
  values <- numeric(0)
  walk <- function(g) {
    if (inherits(g, class) && !is.null(g[[field]])) {
      values <<- c(values, as.numeric(g[[field]]))
    }
    if (inherits(g, "gTree")) for (child in g$children) walk(child)
    if (inherits(g, "gList")) for (child in g) walk(child)
    if (!is.null(g$grobs)) for (child in g$grobs) walk(child)
  }
  walk(gt)
  values
}

WORDS <- c("machine", "learning", "data", "model", "neural", "vision", "graph")
COUNTS <- c(412, 300, 250, 120, 90, 80, 60)


test_that("a word cloud is exported with the words turned as they were drawn", {
  testthat::skip_if_not_installed("wordcloud")
  testthat::skip_if_not_installed("gridGraphics")
  keep_random_state()

  shown <- shown_drawing(function() {
    set.seed(11)
    wordcloud::wordcloud(
      WORDS, COUNTS, min.freq = 1, random.order = TRUE, rot.per = 0.5
    )
  })
  device_id <- random_device(function() {
    set.seed(11)
    maidr::wordcloud(
      WORDS, COUNTS, min.freq = 1, random.order = TRUE, rot.per = 0.5
    )
    # Random numbers the session draws after the chart, which the export
    # used to start from.
    stats::runif(25)
  })

  turned <- grob_field(shown, "text", "rot")
  testthat::expect_true(any(turned != 0) && any(turned == 0))
  testthat::expect_equal(
    grob_field(exported_drawing(device_id), "text", "rot"), turned
  )
})


test_that("saving a chart twice gives the same chart", {
  testthat::skip_if_not_installed("wordcloud")
  keep_random_state()
  device_id <- random_device(function() {
    set.seed(5)
    maidr::wordcloud(
      WORDS, COUNTS, min.freq = 1, random.order = TRUE, rot.per = 0.5
    )
  })

  first <- grob_field(exported_drawing(device_id), "text", "rot")
  stats::runif(10)
  second <- grob_field(exported_drawing(device_id), "text", "rot")

  testthat::expect_equal(second, first)
})


test_that("a jittered strip chart is exported with the jitter it was drawn with", {
  testthat::skip_if_not_installed("gridGraphics")
  keep_random_state()
  values <- c(3, 3, 3, 4, 4, 5)

  shown <- shown_drawing(function() {
    set.seed(2)
    graphics::stripchart(values, method = "jitter", vertical = TRUE)
  })
  # Through maidr's generated wrapper, as a bare call written after
  # `library(maidr)` is.
  device_id <- random_device(function() {
    set.seed(2)
    stripchart(values, method = "jitter", vertical = TRUE)
    stats::runif(25)
  })

  testthat::expect_equal(
    grob_field(exported_drawing(device_id), "points", "x"),
    grob_field(shown, "points", "x")
  )
})


test_that("exporting a chart leaves the session's random numbers where they were", {
  testthat::skip_if_not_installed("wordcloud")
  keep_random_state()
  device_id <- random_device(function() {
    set.seed(9)
    maidr::wordcloud(
      WORDS, COUNTS, min.freq = 1, random.order = TRUE, rot.per = 0.5
    )
  })

  before <- get(".Random.seed", envir = globalenv())
  exported_drawing(device_id)

  testthat::expect_identical(get(".Random.seed", envir = globalenv()), before)
})


test_that("a call that did not pass through a recording wrapper keeps no state", {
  # The noted state is taken by the call it was noted for; one recorded
  # without the wrapper's `ensure_maidr_device()` gets none rather than it.
  keep_random_state()
  device_id <- random_device(function() NULL)
  set.seed(3)
  note_call_random_state()
  testthat::expect_false(is.null(.maidr_call_start$rng_state))

  log_plot_call_to_device("plot", NULL, list(1:3), device_id)
  log_plot_call_to_device("lines", NULL, list(1:3), device_id)

  calls <- get_device_calls(device_id)
  testthat::expect_false(is.null(calls[[1]]$rng_state))
  testthat::expect_null(calls[[2]]$rng_state)
})


test_that("a session with no random state is left with none", {
  keep_random_state()
  set.seed(1)
  recorded <- .Random.seed
  expected <- stats::runif(1)
  rm(".Random.seed", envir = globalenv())

  drawn <- with_random_state(recorded, stats::runif(1))

  testthat::expect_equal(drawn, expected)
  testthat::expect_false(
    exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  )
})
