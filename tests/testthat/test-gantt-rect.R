# A rectangle layer is a schedule when its author says so (#197)
#
# `geom_rect()` draws gantt charts, and nothing in the rectangles says when it
# did. Five structural candidates were measured against the issue's eight
# charts on ggplot2 3.4.4, reading real `ggplot_build(p)$data[[i]]` frames:
#
#   chart                            n  nb nsx lattice parts | R1 R2 R3 R6 R7
#   gantt (the target)               4  3   4   FALSE  TRUE  |  T  T  T  T  T
#   gantt, tasks overlapping in x    3  3   3   FALSE  TRUE  |  T  T  T  T  T
#   gantt, varying bar heights       3  3   3   FALSE  TRUE  |  T  T  F  T  F
#   single annotate('rect')          1  1   1   TRUE   TRUE  |  T  F  F  F  F
#   two-region highlight (1 layer)   2  2   2   FALSE  TRUE  |  T  T  T  T  T
#   waterfall (lanes on x)           4  4   4   FALSE  FALSE |  F  F  F  F  F
#   heatmap via geom_rect            9  3   3   TRUE   TRUE  |  T  T  T  F  F
#   heatmap with one cell missing    8  3   3   FALSE  TRUE  |  T  T  T  T  T
#   ---------------------------------------------------------------------
#   correct out of 8                                        |  4  5  4  6  5
#
# R1, R2 and R3 each claim the `geom_rect()` heatmap; R6 refuses that one and
# claims the gappy one; every one of them claims the two-region highlight,
# which is decoration announced as data. And two further charts, measured the
# same way, close the gap for good:
#
#   waterfall, equal increments      3  3   3   FALSE  TRUE  |  T  T  T  T  T
#   gantt, all tasks equal duration  3  3   3   FALSE  TRUE  |  T  T  T  T  T
#
# A waterfall whose steps are all the same size and a schedule whose tasks all
# take the same time agree in every column, and one of them is a chart the
# issue forbids. They are the same rectangles: the information is not in the
# geometry at all.
#
# So the author is asked, with `maidr_gantt()`, the same way `annotate()` is
# already read as "this is decoration". The tests below assert, in order, that
# nothing undeclared moved, that a declaration is carried and read, that it is
# processed by the landed gantt machinery rather than a second copy of it,
# that lanes are named by the ticks inside them, that the right rectangles are
# highlighted -- and last, out loud, the wrong answer the declaration buys.

skip_unless_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

#' The repository's own four-interval schedule, drawn as bands
#'
#' The same four intervals `test-gantt-segment.R::schedule()` draws with
#' segments, lane 2 booked twice, as bands 0.8 wide around the lanes 1, 2, 3.
schedule_bands <- function() {
  data.frame(
    xmin = c(0, 3, 8, 12), xmax = c(3, 8, 11, 15),
    ymin = c(0.6, 1.6, 2.6, 1.6), ymax = c(1.4, 2.4, 3.4, 2.4)
  )
}

#' The same schedule with lane 2's later booking written first
unsorted_bands <- function() {
  data.frame(
    xmin = c(0, 12, 8, 3), xmax = c(3, 15, 11, 8),
    ymin = c(0.6, 1.6, 2.6, 1.6), ymax = c(1.4, 2.4, 3.4, 2.4)
  )
}

band_aes <- ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax)

heatmap_frame <- function() {
  frame <- expand.grid(i = 1:3, j = 1:3)
  frame$v <- seq_len(nrow(frame))
  frame
}

heatmap_aes <- ggplot2::aes(
  xmin = i - 0.5, xmax = i + 0.5, ymin = j - 0.5, ymax = j + 0.5, fill = v
)

task_labels <- function() {
  ggplot2::scale_y_continuous(breaks = 1:3, labels = c("design", "build", "test"))
}

declared_plot <- function(frame = schedule_bands()) {
  ggplot2::ggplot(frame) +
    maidr_gantt(band_aes) +
    task_labels() +
    ggplot2::labs(x = "week", y = "task")
}

detected <- function(plot, index = 1) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

#' The lanes of a processed layer as "name start-end" strings, lane by lane
as_intervals <- function(result) {
  lapply(result$data$points, function(lane) {
    vapply(lane, function(one) sprintf("%s %g-%g", one$x, one$start, one$end), "")
  })
}

processed <- function(plot, index = 1) {
  built <- ggplot2::ggplot_build(plot)
  processor <- maidr:::Ggplot2GanttLayerProcessor$new(
    list(index = index, type = "gantt")
  )
  processor$process(plot, built$layout, built, ggplot2::ggplotGrob(plot))
}


# ---------------------------------------------------------------------------
# Nothing undeclared moved
# ---------------------------------------------------------------------------

test_that("every undeclared chart keeps exactly the reading it had", {
  skip_unless_ggplot2()

  # Measured before the change and asserted after it, which is what makes
  # "this is opt-in" a fact rather than an intention. Every row here answered
  # the same thing on the commit before this one.
  points <- data.frame(x = 1:10, y = c(2, 4, 6, 8, 10, 3, 5, 7, 9, 1))
  fixtures <- list(
    list("annotate('rect')", "skip", 2, ggplot2::ggplot(points, ggplot2::aes(x, y)) +
      ggplot2::geom_point() +
      ggplot2::annotate("rect", xmin = 2, xmax = 3, ymin = 2, ymax = 8, alpha = 0.2)),
    list("bare geom_rect gantt", "unknown", 1, ggplot2::ggplot(schedule_bands()) +
      ggplot2::geom_rect(band_aes)),
    list("geom_rect heatmap", "unknown", 1, ggplot2::ggplot(heatmap_frame()) +
      ggplot2::geom_rect(heatmap_aes)),
    list("waterfall via geom_rect", "unknown", 1, ggplot2::ggplot(data.frame(
      xmin = c(0.6, 1.6, 2.6, 3.6), xmax = c(1.4, 2.4, 3.4, 4.4),
      ymin = c(0, 100, 120, 0), ymax = c(100, 150, 150, 120)
    )) + ggplot2::geom_rect(band_aes)),
    list("two-region highlight", "unknown", 2, ggplot2::ggplot(points, ggplot2::aes(x, y)) +
      ggplot2::geom_point() +
      ggplot2::geom_rect(
        data = data.frame(xmin = c(1, 6), xmax = c(3, 9), ymin = c(1, 5), ymax = c(4, 8)),
        mapping = band_aes, inherit.aes = FALSE, alpha = 0.2
      )),
    list("geom_tile heatmap", "heat", 1, ggplot2::ggplot(heatmap_frame()) +
      ggplot2::geom_tile(ggplot2::aes(i, j, fill = v))),
    list("geom_col bar", "bar", 1, ggplot2::ggplot(data.frame(a = letters[1:3], b = 1:3)) +
      ggplot2::geom_col(ggplot2::aes(a, b))),
    list("geom_segment gantt", "gantt", 1, ggplot2::ggplot(data.frame(
      task = factor(c("a", "b")), s = c(0, 3), e = c(3, 8)
    )) + ggplot2::geom_segment(ggplot2::aes(x = s, xend = e, y = task, yend = task))),
    list("geom_point", "point", 1, ggplot2::ggplot(points, ggplot2::aes(x, y)) +
      ggplot2::geom_point()),
    list("empty geom_rect", "skip", 2, ggplot2::ggplot(points, ggplot2::aes(x, y)) +
      ggplot2::geom_point() +
      ggplot2::geom_rect(
        data = schedule_bands()[0, ], mapping = band_aes, inherit.aes = FALSE
      ))
  )

  for (fixture in fixtures) {
    testthat::expect_equal(
      detected(fixture[[4]], fixture[[3]]), fixture[[2]],
      info = fixture[[1]]
    )
  }
})

test_that("the three charts #197 forbids stay refused", {
  skip_unless_ggplot2()

  # These are the tests that fail the moment someone smuggles a structural
  # rule back in, which is their whole job: R6, the best of the five, claims
  # the gappy heatmap and the two-region highlight, and its refusal of the
  # waterfall is a property of *that* waterfall rather than of waterfalls.
  gappy <- heatmap_frame()[-5, ]
  charts <- list(
    heatmap = ggplot2::ggplot(heatmap_frame()) + ggplot2::geom_rect(heatmap_aes),
    gappy_heatmap = ggplot2::ggplot(gappy) + ggplot2::geom_rect(heatmap_aes),
    monotone_waterfall = ggplot2::ggplot(data.frame(
      xmin = c(0.6, 1.6, 2.6), xmax = c(1.4, 2.4, 3.4),
      ymin = c(0, 100, 150), ymax = c(100, 150, 170)
    )) + ggplot2::geom_rect(band_aes),
    two_region_highlight = ggplot2::ggplot(data.frame(
      xmin = c(1, 6), xmax = c(3, 9), ymin = c(1, 5), ymax = c(4, 8)
    )) + ggplot2::geom_rect(band_aes)
  )

  for (name in names(charts)) {
    testthat::expect_equal(detected(charts[[name]], 1), "unknown", info = name)
  }
})

test_that("a declaration does not override the annotation check", {
  skip_unless_ggplot2()

  # `layer_is_annotation()` returns before any geom branch, and an
  # `annotate("rect")` layer is never declared -- so the two author-intent
  # rules cannot contradict each other.
  plot <- ggplot2::ggplot(
    data.frame(x = 1:10, y = 1:10), ggplot2::aes(x, y)
  ) +
    ggplot2::geom_point() +
    ggplot2::annotate("rect", xmin = 2, xmax = 3, ymin = 2, ymax = 8, alpha = 0.2)

  testthat::expect_false(maidr:::layer_is_declared_gantt(plot$layers[[2]]))
  testthat::expect_equal(detected(plot, 2), "skip")
})


# ---------------------------------------------------------------------------
# The declaration, and what carries it
# ---------------------------------------------------------------------------

test_that("declaring a layer does not redraw the author's chart", {
  skip_unless_ggplot2()

  # The property that decided the design. `maidr_gantt()` declares; it does
  # not plot. Measured on ggplot2 3.4.4, the built frame and both panel ranges
  # come back identical to the bare `geom_rect()` layer's, so swapping
  # `geom_rect(` for `maidr_gantt(` moves nothing on the page.
  declared <- ggplot2::ggplot_build(
    ggplot2::ggplot(schedule_bands()) + maidr_gantt(band_aes)
  )
  bare <- ggplot2::ggplot_build(
    ggplot2::ggplot(schedule_bands()) + ggplot2::geom_rect(band_aes)
  )

  testthat::expect_identical(declared$data$points[[1]], bare$data$points[[1]])
  testthat::expect_identical(
    declared$layout$panel_params[[1]]$x.range,
    bare$layout$panel_params[[1]]$x.range
  )
  testthat::expect_identical(
    declared$layout$panel_params[[1]]$y.range,
    bare$layout$panel_params[[1]]$y.range
  )
})

test_that("maidr_gantt() constructs and builds without raising a condition", {
  skip_unless_ggplot2()

  # Every other spelling of a declaration costs the author a warning on every
  # construction: `geom_rect(..., maidr = "gantt")` says `Ignoring unknown
  # parameters` and discards the value, `aes(maidr = "gantt")` says `Ignoring
  # unknown aesthetics` on each call. Calling `layer()` costs neither, and
  # leaves ggplot2's own aesthetic checking on.
  testthat::expect_silent(layer <- maidr_gantt(band_aes))
  testthat::expect_equal(class(layer$geom)[1], "GeomRect")
  testthat::expect_equal(class(layer)[1], "LayerInstance")
  testthat::expect_silent(
    ggplot2::ggplot_build(ggplot2::ggplot(schedule_bands()) + maidr_gantt(band_aes))
  )

  # The shared prototype is untouched, so no other rect layer is tagged.
  testthat::expect_null(ggplot2::GeomRect$maidr_type)

  # `...` is `geom_rect()`'s in everything but `stat`, which that function
  # takes as a formal and this one does not. The stat is fixed at identity --
  # a declared schedule is drawn from the author's own bounds -- and a `stat`
  # written here lands in `params` and is dropped. The wrong answer is pinned
  # rather than chased, because passing it through would mean a declared
  # layer whose bounds are computed by something else.
  testthat::expect_warning(
    fixed <- maidr_gantt(band_aes, stat = "count"), "Ignoring unknown parameters"
  )
  testthat::expect_equal(class(fixed$stat)[1], "StatIdentity")
  testthat::expect_equal(class(ggplot2::geom_rect(band_aes, stat = "count")$stat)[1], "StatCount")
})

test_that("both carriers are set, and each covers the other's blind spot", {
  skip_unless_ggplot2()

  layer <- maidr_gantt(band_aes)
  testthat::expect_equal(as.character(layer$constructor[[1]]), "maidr_gantt")
  testthat::expect_equal(layer$maidr_type, "gantt")

  # The constructor route survives a user's own wrapper, because `layer()`
  # records the call in the frame that called it -- a helper wrapping
  # `geom_rect()` would record `geom_rect` and be invisible. The field route
  # survives `do.call()`, where `constructor[[1]]` is the closure itself and
  # `as.character()` raises "cannot coerce type 'closure'".
  own_gantt <- function(...) maidr_gantt(...)
  deeper <- function(...) own_gantt(...)
  called <- do.call(maidr_gantt, list(band_aes))

  testthat::expect_equal(as.character(own_gantt(band_aes)$constructor[[1]]), "maidr_gantt")
  testthat::expect_equal(as.character(deeper(band_aes)$constructor[[1]]), "maidr_gantt")
  testthat::expect_equal(
    as.character(maidr::maidr_gantt(band_aes)$constructor[[1]]),
    c("::", "maidr", "maidr_gantt")
  )
  testthat::expect_error(as.character(called$constructor[[1]]), "closure")
  testthat::expect_equal(called$maidr_type, "gantt")

  for (layer in list(
    maidr_gantt(band_aes), own_gantt(band_aes), deeper(band_aes),
    maidr::maidr_gantt(band_aes), called
  )) {
    testthat::expect_true(maidr:::layer_is_declared_gantt(layer))
  }

  # And the field alone is enough, for a ggplot2 that re-instantiated the
  # layer and dropped what it did not recognise.
  stripped <- maidr_gantt(band_aes)
  stripped$constructor <- NULL
  testthat::expect_true(maidr:::layer_is_declared_gantt(stripped))
})

test_that("nothing but a declaration reads as one", {
  skip_unless_ggplot2()

  testthat::expect_false(maidr:::layer_is_declared_gantt(NULL))
  testthat::expect_false(
    maidr:::layer_is_declared_gantt(ggplot2::geom_rect(band_aes))
  )
  testthat::expect_false(maidr:::layer_is_declared_gantt(
    ggplot2::annotate("rect", xmin = 1, xmax = 2, ymin = 1, ymax = 2)
  ))
})

test_that("a declared rect layer reads as a gantt, however it was called", {
  skip_unless_ggplot2()

  own_gantt <- function(...) maidr_gantt(...)
  testthat::expect_equal(detected(declared_plot()), "gantt")
  testthat::expect_equal(
    detected(ggplot2::ggplot(schedule_bands()) + maidr::maidr_gantt(band_aes)), "gantt"
  )
  testthat::expect_equal(
    detected(ggplot2::ggplot(schedule_bands()) + own_gantt(band_aes)), "gantt"
  )
  testthat::expect_equal(
    detected(ggplot2::ggplot(schedule_bands()) +
      do.call(maidr_gantt, list(band_aes))), "gantt"
  )
})

test_that("a declared layer with no span is refused", {
  skip_unless_ggplot2()

  # The degenerate guard, and it comes free rather than being a rule: bands of
  # zero width normalise to level on both axes, which `segment_lane_axis()`
  # already refuses as "every span reduced to a point".
  frame <- schedule_bands()
  frame$xmax <- frame$xmin
  plot <- ggplot2::ggplot(frame) + maidr_gantt(band_aes)

  testthat::expect_true(maidr:::layer_is_declared_gantt(plot$layers[[1]]))
  testthat::expect_null(maidr:::segment_lane_axis(
    maidr:::rect_gantt_frame(ggplot2::ggplot_build(plot)$data[[1]])
  ))
  testthat::expect_equal(detected(plot), "unknown")
})

test_that("a declared layer that drew nothing is skipped, not refused", {
  skip_unless_ggplot2()

  # Same answer a drawless `geom_rect()` gets, through the same
  # `unread_layer_type()`: there is no mark, so there is nothing the reader is
  # missing and the chart keeps its interactivity.
  points <- data.frame(x = 1:10, y = 1:10)
  plot <- ggplot2::ggplot(points, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    maidr_gantt(data = schedule_bands()[0, ], mapping = band_aes, inherit.aes = FALSE)

  testthat::expect_equal(detected(plot, 2), "skip")
})


# ---------------------------------------------------------------------------
# Processing: the landed gantt machinery, reached through a renamed frame
# ---------------------------------------------------------------------------

test_that("a rect frame is renamed into the frame the segment gantt reads", {
  skip_unless_ggplot2()

  built <- ggplot2::ggplot_build(declared_plot())
  frame <- maidr:::rect_gantt_frame(built$data[[1]])

  testthat::expect_equal(maidr:::segment_lane_axis(frame), "y")
  testthat::expect_equal(frame$x, c(0, 3, 8, 12))
  testthat::expect_equal(frame$xend, c(3, 8, 11, 15))
  # The band's midpoint, so a lane sits where a reader sees it.
  testthat::expect_equal(frame$y, c(1, 2, 3, 2))
  testthat::expect_equal(frame$y, frame$yend)

  grouped <- maidr:::segment_lanes(frame, "y", NULL)
  testthat::expect_equal(lengths(grouped$data), c(1L, 2L, 1L))
  testthat::expect_equal(grouped$order, c(1L, 2L, 4L, 3L))

  # A segment layer's own frame is left alone -- this is a rect reading, not
  # a second implementation of the segment one.
  segments <- ggplot2::ggplot(data.frame(t = factor("a"), s = 0, e = 3)) +
    ggplot2::geom_segment(ggplot2::aes(x = s, xend = e, y = t, yend = t))
  testthat::expect_null(
    maidr:::rect_gantt_frame(ggplot2::ggplot_build(segments)$data[[1]])
  )
})

test_that("a declared schedule is read as the schedule it draws", {
  skip_unless_ggplot2()

  result <- processed(declared_plot())

  testthat::expect_equal(
    as_intervals(result),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )
  testthat::expect_equal(unlist(result$data$lanes), c("design", "build", "test"))
  testthat::expect_equal(result$orientation, "horz")
  testthat::expect_equal(result$axes$x$label, "week")
  testthat::expect_equal(result$axes$y$label, "task")
})

test_that("a declared schedule reads exactly as the segment spelling does", {
  skip_unless_ggplot2()

  # Compared against the chart rather than against written-down numbers, the
  # way `test-gantt-spoke.R` compares a spoke against a segment: the whole
  # argument for renaming the frame is that one reading answers both
  # spellings, and a second implementation that merely agrees today is not
  # that.
  segments <- ggplot2::ggplot(data.frame(
    task = factor(c("design", "build", "test", "build"),
      levels = c("design", "build", "test")
    ),
    start = c(0, 3, 8, 12), end = c(3, 8, 11, 15)
  )) +
    ggplot2::geom_segment(
      ggplot2::aes(x = start, xend = end, y = task, yend = task)
    ) +
    ggplot2::labs(x = "week", y = "task")

  from_segments <- processed(segments)
  from_rects <- processed(declared_plot())

  testthat::expect_identical(from_rects$data$points, from_segments$data$points)
  testthat::expect_identical(from_rects$data$lanes, from_segments$data$lanes)
  testthat::expect_identical(from_rects$orientation, from_segments$orientation)
  testthat::expect_identical(from_rects$axes, from_segments$axes)

  # Only the grob the selectors name differs -- a rect layer draws
  # `geom_rect.rect.*` where a segment layer draws `GRID.segments.*`.
  suffix <- function(result) sub("^.*\\.", "", unlist(result$selectors))
  testthat::expect_equal(suffix(from_rects), suffix(from_segments))
})

test_that("a lane's intervals ascend however they were written", {
  skip_unless_ggplot2()

  # The rows arrive with lane 2's later booking first; a reader sweeps a lane
  # along the axis, not along the data frame, and the selectors follow the
  # regrouping rather than the document.
  result <- processed(declared_plot(unsorted_bands()))

  testthat::expect_equal(
    as_intervals(result),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )
  ids <- sub("'\\]$", "", sub("^\\*\\[id='", "", unlist(result$selectors)))
  testthat::expect_equal(sub("^.*\\.", "", ids), c("1", "4", "2", "3"))
})

test_that("lanes on x read the same schedule the other way up", {
  skip_unless_ggplot2()

  # The mirror image, and `lane_axis` selects it rather than guessing: both
  # axes partition for the target schedule, so structure can neither confirm
  # nor contradict what the author meant.
  frame <- data.frame(
    ymin = c(0, 3, 8, 12), ymax = c(3, 8, 11, 15),
    xmin = c(0.6, 1.6, 2.6, 1.6), xmax = c(1.4, 2.4, 3.4, 2.4)
  )
  plot <- ggplot2::ggplot(frame) +
    maidr_gantt(band_aes, lane_axis = "x") +
    ggplot2::scale_x_continuous(breaks = 1:3, labels = c("design", "build", "test"))

  testthat::expect_equal(detected(plot), "gantt")
  result <- processed(plot)
  testthat::expect_equal(result$orientation, "vert")
  testthat::expect_equal(
    as_intervals(result),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )

  testthat::expect_error(maidr_gantt(band_aes, lane_axis = "z"))
  testthat::expect_equal(maidr:::layer_declared_lane_axis(NULL), "y")
  testthat::expect_equal(
    maidr:::layer_declared_lane_axis(ggplot2::geom_rect(band_aes)), "y"
  )
})


# ---------------------------------------------------------------------------
# Lane names: the tick inside the band, or the position
# ---------------------------------------------------------------------------

test_that("a label that is its own number is a coordinate, not a name", {
  skip_unless_ggplot2()

  testthat::expect_true(maidr:::label_names_its_lane("design", 1))
  testthat::expect_true(maidr:::label_names_its_lane("2021", 1))
  testthat::expect_false(maidr:::label_names_its_lane("1", 1))
  testthat::expect_false(maidr:::label_names_its_lane("1.0", 1))
  testthat::expect_false(maidr:::label_names_its_lane("01", 1))
  testthat::expect_false(maidr:::label_names_its_lane(" 1", 1))
  testthat::expect_false(maidr:::label_names_its_lane("1e+00", 1))
  # The strip is what covers `scales::comma` and `scales::dollar`.
  testthat::expect_false(maidr:::label_names_its_lane("1,000", 1000))
  testthat::expect_false(maidr:::label_names_its_lane("$1", 1))
  testthat::expect_false(maidr:::label_names_its_lane(NA_character_, 1))
  testthat::expect_false(maidr:::label_names_its_lane("", 1))

  # The wrong answer, pinned so it is read rather than discovered:
  # `scales::percent` renders the break 1 as "100%", which is the axis writing
  # its own coordinate out and is read as a name. A lane is then called "100%"
  # instead of 1 -- a cosmetic mis-name inside a schedule the author already
  # declared, not a false claim, so it is recorded rather than chased.
  testthat::expect_true(maidr:::label_names_its_lane("100%", 1))
})

test_that("a lane is named by the one explicit tick inside it", {
  skip_unless_ggplot2()

  testthat::expect_equal(
    unlist(processed(declared_plot())$data$lanes), c("design", "build", "test")
  )
})

test_that("an axis writing its own coordinates out names nothing", {
  skip_unless_ggplot2()

  # The trap #197 names. On the default scale the panel's labels are
  # NA, 1, 2, 3, NA -- each one a rendering of its own break -- and a lane
  # called "2" says less than a lane called by the position 2 it sits at.
  # `GanttPoint$x` takes a number for exactly this case.
  for (scale in list(
    NULL,
    ggplot2::scale_y_continuous(breaks = 1:3),
    ggplot2::scale_y_continuous(breaks = 1:3, labels = c("1", "2", "3")),
    ggplot2::scale_y_continuous(breaks = seq(0, 4, 0.5))
  )) {
    plot <- ggplot2::ggplot(schedule_bands()) + maidr_gantt(band_aes)
    if (!is.null(scale)) {
      plot <- plot + scale
    }
    result <- processed(plot)
    testthat::expect_null(result$data$lanes)
    testthat::expect_equal(
      as_intervals(result),
      list("1 0-3", c("2 3-8", "2 12-15"), "3 8-11")
    )
  }
})

test_that("a band holding no tick, or two, is named by its position", {
  skip_unless_ggplot2()

  # Both guards are xability/py-maidr#533's: a lane with no explicit tick of
  # its own has no name, and a lane holding two labelled ticks is named by
  # neither of them.
  no_tick <- processed(
    ggplot2::ggplot(schedule_bands()) + maidr_gantt(band_aes) +
      ggplot2::scale_y_continuous(breaks = c(1, 3), labels = c("design", "test"))
  )
  testthat::expect_equal(
    vapply(no_tick$data$lanes, as.character, ""), c("design", "2", "test")
  )
  testthat::expect_equal(
    as_intervals(no_tick),
    list("design 0-3", c("2 3-8", "2 12-15"), "test 8-11")
  )

  two_ticks <- processed(
    ggplot2::ggplot(schedule_bands()) + maidr_gantt(band_aes) +
      ggplot2::scale_y_continuous(
        breaks = c(0.8, 1.2, 2, 3), labels = c("start", "end", "build", "test")
      )
  )
  testthat::expect_equal(
    vapply(two_ticks$data$lanes, as.character, ""), c("1", "build", "test")
  )
})

test_that("coord_flip lanes are named by the ticks the chart draws on them", {
  skip_unless_ggplot2()

  # `panel_params` is keyed by the axis the chart *draws*, and `coord_flip()`
  # swaps that against the axis the data lives on, so the lane axis's ticks
  # arrive under `$x`. Reading them under `$y` instead gives the span axis,
  # which fails in two different directions -- both pinned here.
  flipped <- function(span_scale = NULL) {
    plot <- ggplot2::ggplot(schedule_bands()) +
      maidr_gantt(band_aes) + task_labels() + ggplot2::coord_flip()
    if (!is.null(span_scale)) {
      plot <- plot + span_scale
    }
    processed(plot)
  }

  # 1. The span axis carrying names of its own. Before the swap the lanes came
  #    back "Jan", "Feb", "Mar" -- names the chart draws along the other axis.
  named_span <- flipped(
    ggplot2::scale_x_continuous(breaks = 1:3, labels = c("Jan", "Feb", "Mar"))
  )
  testthat::expect_equal(
    unlist(named_span$data$lanes), c("design", "build", "test")
  )
  testthat::expect_equal(
    as_intervals(named_span),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )

  # 2. The ordinary case, and the quieter failure: the default time axis draws
  #    0, 5, 10, 15, every one of which is its own coordinate, so before the
  #    swap `label_names_its_lane()` refused all of them and the lanes lost
  #    their names entirely on a chart drawing design/build/test.
  testthat::expect_equal(
    unlist(flipped()$data$lanes), c("design", "build", "test")
  )

  # The mirror spelling flips the same way.
  mirror <- ggplot2::ggplot(data.frame(
    ymin = c(0, 3, 8, 12), ymax = c(3, 8, 11, 15),
    xmin = c(0.6, 1.6, 2.6, 1.6), xmax = c(1.4, 2.4, 3.4, 2.4)
  )) +
    maidr_gantt(band_aes, lane_axis = "x") +
    ggplot2::scale_x_continuous(breaks = 1:3, labels = c("design", "build", "test")) +
    ggplot2::scale_y_continuous(breaks = 1:3, labels = c("Jan", "Feb", "Mar")) +
    ggplot2::coord_flip()
  testthat::expect_equal(
    unlist(processed(mirror)$data$lanes), c("design", "build", "test")
  )

  # The negative case, which is not this issue's to change: the
  # `geom_segment()` spelling of the same flipped chart goes through
  # `lane_names()`, which requires a discrete axis and so cannot borrow the
  # span axis's labels either way. Measured, it comes back with no `lanes`
  # and the positions 1, 2, 2, 3 -- the reading it has today.
  segments <- processed(
    ggplot2::ggplot(data.frame(
      x = c(0, 3, 8, 12), xend = c(3, 8, 11, 15), y = c(1, 2, 3, 2)
    )) +
      ggplot2::geom_segment(ggplot2::aes(x = x, xend = xend, y = y, yend = y)) +
      task_labels() + ggplot2::coord_flip()
  )
  testthat::expect_null(segments$data$lanes)
  testthat::expect_equal(
    as_intervals(segments),
    list("1 0-3", c("2 3-8", "2 12-15"), "3 8-11")
  )
})


# ---------------------------------------------------------------------------
# Highlighting: the right rectangles, not the theme's and not the bar chart's
# ---------------------------------------------------------------------------

test_that("the bars are found by name, because the theme draws rects too", {
  skip_unless_ggplot2()

  # Measured, the rect grobs of a lone declared gantt in tree order:
  #
  #     plot.background..rect.33  panel.background..rect.6  geom_rect.rect.2
  #
  # so a class-keyed search resolves position 1 to the plot background and
  # the reader has the whole page highlighted for their first task.
  plot <- declared_plot()
  gt <- ggplot2::ggplotGrob(plot)
  processor <- maidr:::Ggplot2GanttLayerProcessor$new(list(index = 1, type = "gantt"))
  name <- processor$find_segments_name(plot, gt, NULL)

  testthat::expect_true(grepl("^geom_rect\\.", name))
  selectors <- unlist(processor$generate_selectors(gt, plot, NULL, c(1L, 2L, 4L, 3L)))
  testthat::expect_length(selectors, 4L)
  testthat::expect_false(any(grepl("background", selectors)))
  testthat::expect_equal(
    selectors,
    paste0("*[id='", name, ".1.", c(1, 2, 4, 3), "']")
  )
})

test_that("a declared layer beside a bar chart highlights its own bars", {
  skip_unless_ggplot2()

  # `GeomRect$draw_panel()` hard-codes the grob name, so `geom_col()` draws
  # `geom_rect.rect.*` too while `geom_grob_prefix()` calls it `geom_col`.
  # Measured, the base class's `find_layer_grob_tree()` counts the gantt as
  # position 1 and hands it the column chart's five bars.
  plot <- ggplot2::ggplot() +
    ggplot2::geom_col(data = data.frame(a = 1:5, b = 1:5), ggplot2::aes(a, b)) +
    maidr_gantt(data = schedule_bands(), mapping = band_aes)
  gt <- ggplot2::ggplotGrob(plot)

  count_rects <- function(target) {
    found <- NULL
    walk <- function(node) {
      if (identical(node$name, target)) {
        found <<- node
        return(invisible(NULL))
      }
      if (inherits(node, "gTree")) for (child in node$children) walk(child)
    }
    for (root in gt$grobs) walk(root)
    if (is.null(found)) NA_integer_ else length(found$x)
  }

  processor <- maidr:::Ggplot2GanttLayerProcessor$new(list(index = 2, type = "gantt"))
  testthat::expect_equal(count_rects(processor$find_segments_name(plot, gt, NULL)), 4L)
  testthat::expect_equal(
    count_rects(maidr:::LayerProcessor$new(
      list(index = 2, type = "gantt")
    )$find_layer_grob_tree(plot, gt, NULL, 2)$name),
    5L
  )

  testthat::expect_equal(detected(plot, 1), "bar")
  testthat::expect_equal(detected(plot, 2), "gantt")
})

test_that("a declared layer beside a tile heatmap highlights its own bars", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot() +
    ggplot2::geom_tile(data = heatmap_frame(), ggplot2::aes(i, j, fill = v)) +
    maidr_gantt(data = schedule_bands(), mapping = band_aes)
  processor <- maidr:::Ggplot2GanttLayerProcessor$new(list(index = 2, type = "gantt"))
  name <- processor$find_segments_name(plot, ggplot2::ggplotGrob(plot), NULL)

  testthat::expect_true(grepl("^geom_rect\\.", name))
  testthat::expect_equal(detected(plot, 1), "heat")
})


# ---------------------------------------------------------------------------
# What a reader receives
# ---------------------------------------------------------------------------

test_that("a declared schedule keeps its interactivity and its lane names", {
  skip_if_no_render()

  html <- rendered(declared_plot())
  testthat::expect_false(fell_back(html))

  layer <- layers_from(html)[[1]]
  testthat::expect_equal(layer$type, "gantt")
  testthat::expect_equal(layer$orientation, "horz")
  testthat::expect_equal(unlist(layer$data$lanes), c("design", "build", "test"))
  testthat::expect_equal(
    as_intervals(layer),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )

  # A selector naming nothing is the highlight-only blind spot
  # xability/maidr#814 describes, so each id is looked for in the export.
  ids <- sub("'\\]$", "", sub("^\\*\\[id='", "", unlist(layer$selectors)))
  testthat::expect_length(ids, 4L)
  for (id in ids) {
    testthat::expect_true(grepl(paste0('id="', id, '"'), html, fixed = TRUE))
  }
})

test_that("the same schedule undeclared still falls back, and that is the cost", {
  skip_if_no_render()

  # Zero charts improve on the day this lands. The reading arrives only for an
  # author who writes `maidr_gantt(` instead of `geom_rect(`, and that is the
  # price of never announcing a decoration, a heatmap or a waterfall as a
  # schedule.
  html <- rendered(ggplot2::ggplot(schedule_bands()) + ggplot2::geom_rect(band_aes))

  testthat::expect_true(fell_back(html))
})


# ---------------------------------------------------------------------------
# The hole
# ---------------------------------------------------------------------------

test_that("a declared heatmap is announced as a schedule, and that is the hole", {
  skip_unless_ggplot2()

  # The wrong answer, asserted out loud. `maidr_gantt()` over heatmap
  # coordinates is read as a nine-task, three-lane schedule whose durations
  # are cell widths. The author declared it, so the package believes them.
  #
  # This is not an oversight: the only guard that would catch it is a
  # structural rule over (xmin, xmax, ymin, ymax), and the table at the top of
  # this file is the measurement that no such rule can be right. If a future
  # change makes this test fail by refusing the chart, check what else that
  # guard refuses before deciding it is an improvement -- every candidate
  # measured also refused real schedules.
  plot <- ggplot2::ggplot(heatmap_frame()) + maidr_gantt(heatmap_aes)

  testthat::expect_equal(detected(plot), "gantt")
  result <- processed(plot)
  testthat::expect_equal(lengths(result$data$points), c(3L, 3L, 3L))
  testthat::expect_equal(result$data$points[[1]][[1]]$start, 0.5)
})
