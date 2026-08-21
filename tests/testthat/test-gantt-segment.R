# `geom_segment()` draws schedules, and they read as nothing (issue #194)
#
# A segment with the two ends of a span on one axis and a lane on the other is
# how ggplot2 draws a schedule, a range plot and a high-low chart.
# `ggplot_build` computes both ends and the lane exactly -- `x`, `xend`, `y`,
# `yend` -- and the panel's scale names the lanes at exactly the positions the
# built data records, so nothing is inverted from a pixel and nothing inferred.
#
# Two things had to be decided rather than assumed, and both are asserted here.
#
# **A segment whose ends share nothing is not a span.** An edge in a node-link
# diagram has no lane to sit in. The question is asked of the whole layer
# rather than of each row, which is the rule xability/maidr#1100 settled for
# the same reading: one call can hold spans and edges together, and reading
# three spans out of four segments announces a gantt quietly missing a quarter
# of its chart.
#
# **An empty lane is real.** A factor level nothing was drawn for is dropped by
# default and kept by `scale_y_discrete(drop = FALSE)`, and "nothing is booked
# here" is a statement about a schedule that a flat list cannot make.
# `GanttData` is nested per lane precisely so it can.
#
# `geom_curve()` computes the same four columns and reads the same way. It was
# refused here until #195 -- on its export rather than on its reading -- and
# now has its own file, `test-gantt-curve.R`, because the two geoms reach
# one-element-per-row by different routes and their selectors differ.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

# Built at top level: inside a closure the bare column names in `aes()` read as
# undefined globals to static analysis.
lanes_on_y <- ggplot2::aes(x = start, xend = end, y = task, yend = task)
lanes_on_x <- ggplot2::aes(y = start, yend = end, x = task, xend = task)
spans_reversed <- ggplot2::aes(x = end, xend = start, y = task, yend = task)
edges <- ggplot2::aes(x = x, xend = xend, y = y, yend = yend)
points_only <- ggplot2::aes(x = start, xend = start, y = task, yend = task)

#' A four-interval schedule whose second lane is booked twice
schedule <- function() {
  data.frame(
    task = factor(
      c("design", "build", "test", "build"),
      levels = c("design", "build", "test")
    ),
    start = c(0, 3, 8, 12),
    end = c(3, 8, 11, 15)
  )
}

#' The same schedule with `build`'s later booking written first, so the built
#' rows of one lane are not already in the order a reader sweeps them
unsorted_schedule <- function() {
  data.frame(
    task = factor(
      c("design", "build", "test", "build"),
      levels = c("design", "build", "test")
    ),
    start = c(0, 12, 8, 3),
    end = c(3, 15, 11, 8)
  )
}

#' Two segments that share neither coordinate -- a node-link diagram's edges
edge_frame <- function() {
  data.frame(x = c(0, 1), xend = c(2, 3), y = c(0, 1), yend = c(2, 3))
}

segment_plot <- function(mapping = lanes_on_y, frame = schedule()) {
  ggplot2::ggplot(frame) + ggplot2::geom_segment(mapping)
}

#' Render a plot and return its HTML
rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

#' The one layer a plot emits, or NULL when it emits none
gantt_layer <- function(plot, html = NULL) {
  if (is.null(html)) {
    html <- rendered(plot)
  }
  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(NULL)
  }
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  for (pair in list(
    c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"),
    c("&amp;", "&"), c("&#39;", "'")
  )) {
    json <- gsub(pair[1], pair[2], json, fixed = TRUE)
  }
  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

#' Every lane's intervals as "name start-end" strings, lane by lane
as_intervals <- function(layer) {
  lapply(layer$data, function(lane) {
    vapply(
      lane,
      function(one) sprintf("%s %g-%g", one$x, one$start, one$end),
      character(1)
    )
  })
}


test_that("a segment layer laying intervals in lanes reaches the gantt processor", {
  testthat::skip_if_not_installed("ggplot2")

  # Asked of the classifier directly, upstream of rendering: a regression here
  # would otherwise surface as a fistful of failures about lanes and selectors
  # rather than one about the branch that broke. Same reason
  # `test-raster-heatmap.R` asks it this way.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- segment_plot()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "gantt"
  )
})

test_that("a segment layer whose ends share nothing is not claimed", {
  testthat::skip_if_not_installed("ggplot2")

  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- segment_plot(edges, edge_frame())

  # "unknown" rather than a refusal of its own: it is what the layer returns
  # today, so a chart that is declined keeps exactly the static-image fallback
  # it already had.
  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "unknown"
  )
})

test_that("a schedule is read as the gantt it draws", {
  skip_if_no_render()

  layer <- gantt_layer(segment_plot())

  testthat::expect_false(is.null(layer))
  testthat::expect_equal(layer$type, "gantt")
})

test_that("intervals nest under the lane they were drawn in", {
  skip_if_no_render()

  layer <- gantt_layer(segment_plot())

  # `build` is booked twice, and both bookings belong to one row a reader
  # moves along -- which is the whole reason `points` is nested.
  testthat::expect_equal(
    as_intervals(layer),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )
})

test_that("lanes are named from the scale, in the order it lays them out", {
  skip_if_no_render()

  layer <- gantt_layer(segment_plot())

  testthat::expect_equal(
    unlist(layer$lanes), c("design", "build", "test")
  )
})

test_that("a lane nothing was booked on is kept as an empty row", {
  skip_if_no_render()

  plot <- segment_plot() +
    ggplot2::scale_y_discrete(
      drop = FALSE, limits = c("design", "build", "test", "idle")
    )
  layer <- gantt_layer(plot)

  testthat::expect_equal(length(layer$data), 4L)
  testthat::expect_equal(length(layer$data[[4]]), 0L)
  testthat::expect_equal(unlist(layer$lanes), c("design", "build", "test", "idle"))
})

test_that("lanes on y are announced as the horizontal chart they are", {
  skip_if_no_render()

  layer <- gantt_layer(segment_plot() + ggplot2::labs(x = "day", y = "task"))

  # The bars run left to right, which the frontend calls "horz" -- and it
  # swaps the two axis labels itself, so they stay the plot's own here.
  testthat::expect_equal(layer$orientation, "horz")
  testthat::expect_equal(layer$axes$x$label, "day")
  testthat::expect_equal(layer$axes$y$label, "task")
})

test_that("lanes on x read the same schedule the other way up", {
  skip_if_no_render()

  layer <- gantt_layer(
    segment_plot(lanes_on_x) + ggplot2::labs(x = "task", y = "day")
  )

  testthat::expect_equal(layer$orientation, "vert")
  testthat::expect_equal(
    as_intervals(layer),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )
})

test_that("a lane's intervals ascend however they were written", {
  skip_if_no_render()

  # ggplot2 keeps the rows in the order the frame gave them, so a lane whose
  # second booking was written first arrives out of order. A reader sweeps a
  # lane along the axis, not along the data frame.
  html <- rendered(segment_plot(frame = unsorted_schedule()))
  layer <- gantt_layer(NULL, html)

  testthat::expect_equal(
    as_intervals(layer),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )

  # And the selectors follow the regrouping rather than the document: the
  # built rows are 1, 4, 2, 3 in emission order, so highlighting is right for
  # a chart whose rows were not already sorted.
  ids <- sub("^\\*\\[id='", "", sub("'\\]$", "", unlist(layer$selectors)))
  testthat::expect_equal(sub("^.*\\.", "", ids), c("1", "4", "2", "3"))
})

test_that("segments that are level on both axes are not a schedule", {
  testthat::skip_if_not_installed("ggplot2")

  # Every span reduced to a point: a scatter drawn with segments. Read as a
  # gantt it would announce a schedule in which no task takes any time, which
  # is a confident reading of something the chart does not say. A milestone
  # sits in a lane beside intervals that have length, and that chart still
  # reads.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- segment_plot(points_only)

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "unknown"
  )
})

test_that("a span written backwards is still the span it draws", {
  skip_if_no_render()

  # `aes(x = end, xend = start)` draws the same interval right to left. A
  # negative length is not a statement the chart makes.
  layer <- gantt_layer(segment_plot(spans_reversed))

  testthat::expect_equal(
    as_intervals(layer),
    list("design 0-3", c("build 3-8", "build 12-15"), "test 8-11")
  )
})

test_that("a continuous lane axis announces the position it has instead", {
  skip_if_no_render()

  frame <- schedule()
  frame$task <- as.numeric(frame$task)
  layer <- gantt_layer(segment_plot(frame = frame))

  # Nothing named the lanes, so the number is what a reader is told --
  # `GanttPoint$x` takes a number or a string for exactly this case, and
  # `lanes` is omitted rather than filled with invented names.
  testthat::expect_equal(
    as_intervals(layer),
    list("1 0-3", c("2 3-8", "2 12-15"), "3 8-11")
  )
  testthat::expect_null(layer$lanes)
})

test_that("every interval is addressed by its own drawn element", {
  skip_if_no_render()

  html <- rendered(segment_plot())
  layer <- gantt_layer(NULL, html)
  selectors <- unlist(layer$selectors)

  # One per interval, and in the order the lanes hold them: the frontend
  # slices this flat list by lane length and withdraws highlighting outright
  # unless the count matches, so a list off by one highlights the wrong task
  # for the rest of the row.
  testthat::expect_equal(length(selectors), 4L)

  ids <- sub("^\\*\\[id='", "", sub("'\\]$", "", selectors))
  testthat::expect_equal(sub("\\.[0-9]+$", "", ids[1]), sub("\\.[0-9]+$", "", ids[4]))
  # `build`'s two bookings are built rows 2 and 4, and they sit together in
  # the second lane -- so the flat list runs 1, 2, 4, 3 rather than 1, 2, 3, 4.
  testthat::expect_equal(sub("^.*\\.", "", ids), c("1", "2", "4", "3"))

  # And the elements are really there. A selector naming nothing is the
  # highlight-only blind spot xability/maidr#814 describes: audio, text and
  # braille all read correctly and nothing lights up, which no assertion about
  # the payload alone can see.
  for (id in ids) {
    testthat::expect_true(
      grepl(paste0('id="', id, '"'), html, fixed = TRUE),
      info = paste("selector resolves to no element:", id)
    )
  }
})

test_that("a second segment layer highlights its own intervals", {
  skip_if_no_render()

  # `find_segments_name()` counts this layer's position among the segment
  # layers and takes the segments grob at that position. Two layers would
  # otherwise both resolve to the first one's elements, and the second would
  # highlight the first's intervals while announcing its own -- the
  # highlight-only failure xability/maidr#814 names, which reads correctly and
  # outlines the wrong thing.
  later <- data.frame(
    task = factor(c("design", "test"), levels = c("design", "build", "test")),
    start = c(20, 25), end = c(24, 29)
  )
  plot <- ggplot2::ggplot(mapping = lanes_on_y) +
    ggplot2::geom_segment(data = schedule()) +
    ggplot2::geom_segment(data = later)
  html <- rendered(plot)

  layers <- jsonlite::fromJSON(
    {
      raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
      json <- sub('"$', "", sub('^maidr-data="', "", raw))
      for (pair in list(
        c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"),
        c("&amp;", "&"), c("&#39;", "'")
      )) {
        json <- gsub(pair[1], pair[2], json, fixed = TRUE)
      }
      json
    },
    simplifyVector = FALSE
  )$subplots[[1]][[1]]$layers

  testthat::expect_equal(length(layers), 2L)

  grob_of <- function(layer) {
    unique(sub("\\.1\\.[0-9]+'\\]$", "", sub("^\\*\\[id='", "", unlist(layer$selectors))))
  }
  first <- grob_of(layers[[1]])
  second <- grob_of(layers[[2]])

  testthat::expect_length(first, 1L)
  testthat::expect_length(second, 1L)
  testthat::expect_false(identical(first, second))

  # And both name elements that are really in the SVG.
  for (id in unlist(lapply(layers, function(l) sub("^\\*\\[id='", "", sub("'\\]$", "", unlist(l$selectors)))))) {
    testthat::expect_true(
      grepl(paste0('id="', id, '"'), html, fixed = TRUE),
      info = paste("selector resolves to no element:", id)
    )
  }
})

test_that("a layer that draws nothing costs the next one its highlight, not its accuracy", {
  testthat::skip_if_not_installed("ggplot2")

  # ggplot2 draws no segments grob at all for a layer with no rows -- measured,
  # two layers and one grob -- so counting this layer's position among the
  # segment layers runs past the end of what was drawn. The answer has to be
  # no selectors rather than the last one found: a reader losing an outline is
  # recoverable, being shown a different layer's interval is not.
  #
  # Asked of the lookup directly. A `geom_segment()` layer with no rows
  # classifies as "unknown" -- `segment_lane_axis()` has nothing to answer
  # about -- and an unknown layer drops the whole plot to a static image, so
  # rendering this chart would exercise that pre-existing behaviour instead of
  # the thing under test.
  plot <- ggplot2::ggplot(mapping = lanes_on_y) +
    ggplot2::geom_segment(data = schedule()[0, ]) +
    ggplot2::geom_segment(data = schedule())
  processor <- maidr:::Ggplot2GanttLayerProcessor$new(list(index = 2, type = "gantt"))

  found <- processor$find_segments_name(plot, ggplot2::ggplotGrob(plot), NULL)

  testthat::expect_null(found)
  testthat::expect_equal(
    length(processor$generate_selectors(NULL, plot, NULL, 1:4)), 0L
  )
})

test_that("a chart of edges keeps the static image it had", {
  skip_if_no_render()

  testthat::expect_null(gantt_layer(segment_plot(edges, edge_frame())))
})
