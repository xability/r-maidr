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
# The replay puts the session's own state back afterwards: exporting a chart
# no longer moves a script's random numbers on, which changed what every
# `set.seed()` gave the calls after it.

random_device <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  draw()
  device_id
}

close_random_device <- function(device_id) {
  clear_base_r_device(device_id)
  grDevices::dev.off(device_id)
}

#' The rotation of every text grob a drawing echoes, in grob order
text_rotations <- function(gt) {
  rotations <- numeric(0)
  walk <- function(g) {
    if (inherits(g, "text") && !is.null(g$rot)) {
      rotations <<- c(rotations, g$rot)
    }
    if (inherits(g, "gTree")) for (child in g$children) walk(child)
    if (inherits(g, "gList")) for (child in g) walk(child)
    if (!is.null(g$grobs)) for (child in g$grobs) walk(child)
  }
  walk(gt)
  rotations
}

WORDS <- c("machine", "learning", "data", "model", "neural", "vision", "graph")
COUNTS <- c(412, 300, 250, 120, 90, 80, 60)

draw_cloud <- function() {
  wordcloud(WORDS, COUNTS, min.freq = 1, random.order = TRUE, rot.per = 0.5)
}


test_that("a word cloud is exported with the words turned as they were drawn", {
  testthat::skip_if_not_installed("wordcloud")
  testthat::skip_if_not_installed("gridGraphics")

  # The reader's drawing, echoed as grid grobs on a page of the export's
  # size, so the two can be compared grob for grob.
  shown <- grid::grid.grabExpr(
    gridGraphics::grid.echo(function() {
      set.seed(11)
      wordcloud::wordcloud(
        WORDS, COUNTS, min.freq = 1, random.order = TRUE, rot.per = 0.5
      )
    }),
    warn = 0, width = 7, height = 5
  )

  device_id <- random_device(function() {
    set.seed(11)
    draw_cloud()
    # Random numbers the session draws after the chart, which the export
    # used to start from.
    stats::runif(25)
  })
  on.exit(close_random_device(device_id), add = TRUE)
  exported <- BaseRPlotOrchestrator$new(device_id)$get_gtable()

  turned <- text_rotations(shown)
  testthat::expect_true(any(turned != 0) && any(turned == 0))
  testthat::expect_equal(text_rotations(exported), turned)
})


test_that("saving a chart twice gives the same chart", {
  testthat::skip_if_not_installed("wordcloud")
  device_id <- random_device(function() {
    set.seed(5)
    draw_cloud()
  })
  on.exit(close_random_device(device_id), add = TRUE)

  first <- text_rotations(BaseRPlotOrchestrator$new(device_id)$get_gtable())
  stats::runif(10)
  second <- text_rotations(BaseRPlotOrchestrator$new(device_id)$get_gtable())

  testthat::expect_equal(second, first)
})


test_that("a jittered strip chart is exported with the jitter it was drawn with", {
  points_x <- function(gt) {
    xs <- numeric(0)
    walk <- function(g) {
      if (inherits(g, "points")) xs <<- c(xs, as.numeric(g$x))
      if (inherits(g, "gTree")) for (child in g$children) walk(child)
      if (inherits(g, "gList")) for (child in g) walk(child)
      if (!is.null(g$grobs)) for (child in g$grobs) walk(child)
    }
    walk(gt)
    xs
  }
  values <- c(3, 3, 3, 4, 4, 5)
  draw <- function() {
    set.seed(2)
    stripchart(values, method = "jitter", vertical = TRUE)
  }

  shown <- grid::grid.grabExpr(
    gridGraphics::grid.echo(function() {
      set.seed(2)
      graphics::stripchart(values, method = "jitter", vertical = TRUE)
    }),
    warn = 0, width = 7, height = 5
  )
  device_id <- random_device(function() {
    draw()
    stats::runif(25)
  })
  on.exit(close_random_device(device_id), add = TRUE)
  exported <- BaseRPlotOrchestrator$new(device_id)$get_gtable()

  testthat::expect_equal(points_x(exported), points_x(shown))
})


test_that("exporting a chart leaves the session's random numbers where they were", {
  testthat::skip_if_not_installed("wordcloud")
  device_id <- random_device(function() {
    set.seed(9)
    draw_cloud()
  })
  on.exit(close_random_device(device_id), add = TRUE)

  before <- get(".Random.seed", envir = globalenv())
  BaseRPlotOrchestrator$new(device_id)$get_gtable()

  testthat::expect_identical(get(".Random.seed", envir = globalenv()), before)
})


test_that("a session with no random state is left with none", {
  state <- maidr:::recorded_random_state()
  on.exit(
    if (!is.null(state)) assign(".Random.seed", state, envir = globalenv()),
    add = TRUE
  )
  set.seed(1)
  recorded <- .Random.seed
  rm(".Random.seed", envir = globalenv())

  drawn <- maidr:::with_random_state(recorded, stats::runif(1))
  set.seed(1)

  testthat::expect_equal(drawn, stats::runif(1))
  rm(".Random.seed", envir = globalenv())
  maidr:::with_random_state(recorded, stats::runif(1))
  testthat::expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})
