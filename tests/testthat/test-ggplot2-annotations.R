# `annotate()` costs a chart every bit of its interactivity (#197)
#
# `annotate("rect", ...)` -- a highlighted region behind a chart -- reaches
# `GeomRect`, which nothing reads, so `detect_layer_type()` answered "unknown".
# That is what makes `has_unsupported_layers()` true and drops the **whole
# plot** to a static image, exactly the cost #176 measured for a reference
# line. A band drawn behind a boxplot is at least as ordinary a thing to put
# on a chart as a threshold line is.
#
# #197 framed this as needing a rule for telling a rect-drawn gantt from an
# annotation, and offered four candidates -- do the bands partition, do the
# spans differ, are they uniform, or ask the author to declare it -- while
# noting that none is obviously right and that guessing wrong announces
# decoration as data.
#
# It turns out no geometry rule is needed, because ggplot2 already records
# which function built each layer. Measured on ggplot2 3.4.4:
#
#     geom_rect(aes(...))                       constructor -> geom_rect
#     annotate("rect", xmin = 2, xmax = 3, ...) constructor -> annotate
#     annotate("text",  x = 2, y = 3, ...)      constructor -> annotate
#
# `annotate()` *is* ggplot2's word for decoration, so the function the author
# called is the answer rather than evidence towards it. The `geom_rect()`
# reading stays exactly as undecided as it was.

skip_unless_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

points_frame <- function() {
  data.frame(x = 1:10, y = c(2, 4, 6, 8, 10, 3, 5, 7, 9, 1))
}

schedule_bounds <- function() {
  data.frame(
    xmin = c(0, 3, 8, 12), xmax = c(3, 8, 11, 15),
    ymin = c(0.6, 1.6, 2.6, 1.6), ymax = c(1.4, 2.4, 3.4, 2.4)
  )
}

detected <- function(plot, index) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

# Render through `save_html()` and report what a reader actually receives.
annotated_render <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  warnings_seen <- character(0)
  withCallingHandlers(
    maidr::save_html(plot, file = file),
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  list(
    interactive = grepl("<svg", html, fixed = TRUE) &&
      !grepl("base64", html, fixed = TRUE),
    fell_back = any(grepl("static image", warnings_seen, fixed = TRUE))
  )
}


test_that("a rectangle annotation is skipped rather than left unknown", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot(points_frame(), ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::annotate("rect", xmin = 2, xmax = 3, ymin = 2, ymax = 8, alpha = 0.2)

  testthat::expect_equal(detected(plot, 1), "point")
  testthat::expect_equal(detected(plot, 2), "skip")
})

test_that("an annotation is skipped whatever mark it happens to draw", {
  skip_unless_ggplot2()

  # The case that makes asking the constructor better than asking the
  # geometry: `annotate("segment")` is an arrow pointing at something, and its
  # two ends lie level on y -- so the gantt test #196 added would *claim* it
  # and announce a one-task schedule that the chart does not contain.
  plot <- ggplot2::ggplot(points_frame(), ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::annotate("segment", x = 1, xend = 4, y = 5, yend = 5)

  testthat::expect_equal(detected(plot, 2), "skip")
})

test_that("a real geom_rect layer is left exactly as undecided as it was", {
  skip_unless_ggplot2()

  # #197's actual question -- when a rectangle layer *is* a schedule -- is not
  # answered here and must not be answered by accident.
  plot <- ggplot2::ggplot(schedule_bounds()) +
    ggplot2::geom_rect(
      ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax)
    )

  testthat::expect_equal(detected(plot, 1), "unknown")
})

test_that("a geom_rect written to look like an annotation is not one", {
  skip_unless_ggplot2()

  # The falsification of the obvious cheaper rule. `annotate()` sets
  # `inherit.aes = FALSE` and `show.legend = FALSE`, so those two look like a
  # signature -- but they are settings any caller may pass, and a rule keyed
  # on them would silently discard this user's data.
  plot <- ggplot2::ggplot(schedule_bounds()) +
    ggplot2::geom_rect(
      ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
      inherit.aes = FALSE, show.legend = FALSE
    )

  testthat::expect_equal(detected(plot, 1), "unknown")
})

test_that("a layer with no recorded constructor keeps the reading it had", {
  skip_unless_ggplot2()

  # A ggplot2 that stopped recording `constructor`, or a layer built by hand.
  # Answering FALSE leaves the geom branches to decide, which is the same
  # behaviour as before this rule existed.
  plot <- ggplot2::ggplot(points_frame(), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  layer <- plot$layers[[1]]
  layer$constructor <- NULL

  testthat::expect_false(maidr:::layer_is_annotation(layer))
  testthat::expect_equal(
    maidr:::Ggplot2Adapter$new()$detect_layer_type(layer, plot), "point"
  )
})

test_that("a chart keeps its interactivity when an annotation is added", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("jsonlite")

  # The whole point, measured the way #176 measured its own: the chart a
  # reader receives, not the classifier's answer.
  plain <- annotated_render(
    ggplot2::ggplot(points_frame(), ggplot2::aes(x, y)) + ggplot2::geom_point()
  )
  annotated <- annotated_render(
    ggplot2::ggplot(points_frame(), ggplot2::aes(x, y)) +
      ggplot2::geom_point() +
      ggplot2::annotate("rect", xmin = 2, xmax = 3, ymin = 2, ymax = 8, alpha = 0.2)
  )

  testthat::expect_true(plain$interactive)
  testthat::expect_true(annotated$interactive)
  testthat::expect_false(annotated$fell_back)
})

test_that("a plot of nothing but annotations still falls back", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("jsonlite")

  # Skipping is not claiming. A plot with no data layer left reads as nothing,
  # and an image is the honest answer -- caught because there is no chart to
  # announce rather than by a rule about which geoms were used.
  result <- annotated_render(
    ggplot2::ggplot(points_frame(), ggplot2::aes(x, y)) +
      ggplot2::annotate("rect", xmin = 2, xmax = 3, ymin = 2, ymax = 8)
  )

  testthat::expect_false(result$interactive)
  testthat::expect_true(result$fell_back)
})
