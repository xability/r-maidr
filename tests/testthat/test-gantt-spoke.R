# `geom_spoke()` cost a readable chart everything (issue #225)
#
# A spoke is `geom_segment()` reparameterised: an angle and a radius rather
# than an endpoint. `GeomSpoke$setup_data()` turns the pair into the same
# `xend`/`yend` columns the segment branch already reads, so ggplot2 has done
# the work before any of this is asked -- but `GeomSpoke` is a direct `Geom`
# subclass and matched no branch, so it reached the unknown processor and took
# the whole plot with it.
#
# Measured on ggplot2 3.4.4 with `save_html()`, the same thirty-point scatter
# in each row:
#
#     geom_point()                    interactive SVG   51,395 bytes
#     geom_point() + geom_spoke()     base64 image      48,249 bytes
#
# Dispatched through the segment branch rather than given a rule of its own,
# which is what makes this change decide nothing new: the same
# `segments_span_lanes()` question is asked, and the two spellings of one mark
# answer it alike.
#
#     geom_spoke(angle = 0.5, radius = 0.3)   spans lanes FALSE   -> unknown
#     geom_spoke(angle = 0,   radius = r)     spans lanes TRUE    -> gantt
#
# An angled spoke is a vector field, not a schedule, and it stays `"unknown"`
# exactly as the segment spelling of the same chart would -- so nothing that
# was declined before is claimed now. A flat one is a gantt written the other
# way round: a lane per y, running from x to x + radius.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

# Built at top level: inside a closure the bare column names in `aes()` read as
# undefined globals to static analysis.
flat_spokes <- ggplot2::aes(x = start, y = task, angle = 0, radius = span)
angled_spokes <- ggplot2::aes(x = start, y = task, angle = 0.5, radius = span)

#' A three-interval schedule, written as a start and a length
#'
#' A spoke says how far it runs rather than where it ends, which is the whole
#' difference in the spelling. The lanes are numeric because a spoke's `y` is
#' a position it turns about; a factor would be the segment file's case.
schedule <- function() {
  data.frame(
    task = c(1, 2, 3),
    start = c(0, 3, 8),
    span = c(3, 5, 3)
  )
}

spoke_plot <- function(mapping = flat_spokes, frame = schedule()) {
  ggplot2::ggplot(frame) + ggplot2::geom_spoke(mapping)
}

#' The equivalent chart written as segments, for comparing the two readings
segment_plot <- function(frame = schedule()) {
  ggplot2::ggplot(frame) +
    ggplot2::geom_segment(
      ggplot2::aes(x = start, xend = start + span, y = task, yend = task)
    )
}

#' Render a plot and return its HTML
rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

#' Every layer a plot emits, or NULL when the chart fell back to a picture
layers_from <- function(html) {
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
  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers
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


test_that("a spoke laying intervals in lanes reaches the gantt processor", {
  testthat::skip_if_not_installed("ggplot2")

  # Asked of the classifier directly, upstream of rendering, for the reason
  # `test-gantt-segment.R` gives: a regression in the branch shows up here as
  # one failure rather than as a fistful about lanes and selectors.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- spoke_plot()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "gantt"
  )
})


test_that("an angled spoke is still not claimed", {
  testthat::skip_if_not_installed("ggplot2")

  # The half that keeps this honest. A vector field is not a schedule, and
  # "unknown" is what the layer returned before -- so a chart that is declined
  # keeps exactly the static-image fallback it already had, rather than being
  # read as a gantt of spokes that share no lane.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- spoke_plot(angled_spokes)

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "unknown"
  )
})


test_that("a spoke reads exactly as the segment spelling of the same chart", {
  skip_if_no_render()

  # The point of dispatching it here rather than giving it a rule: two ways of
  # writing one mark, one reading. Compared against the segment chart rather
  # than against written-down numbers, so a change to how a gantt is emitted
  # moves both sides together and this keeps asserting what it means to.
  spoke <- layers_from(rendered(spoke_plot()))
  segment <- layers_from(rendered(segment_plot()))

  testthat::expect_length(spoke, 1)
  testthat::expect_equal(spoke[[1]]$type, "gantt")
  testthat::expect_equal(as_intervals(spoke[[1]]), as_intervals(segment[[1]]))
})


test_that("the spans come off the radius, not off a second coordinate", {
  skip_if_no_render()

  # Written out once, so the file states what a reader is actually told and
  # does not only compare two readings that could both be wrong. `start` and
  # `span` are chosen so no two lanes share an end and no end is a start.
  layer <- layers_from(rendered(spoke_plot()))[[1]]

  testthat::expect_equal(
    as_intervals(layer),
    list("1 0-3", "2 3-8", "3 8-11")
  )
})


test_that("a chart is not taken down by a spoke drawn beside it", {
  skip_if_no_render()

  # What the issue is about. The scatter reads on its own and read as nothing
  # the moment a spoke was added, because one unclaimed layer makes
  # `has_unsupported_layers()` true and drops the whole plot to a base64
  # image.
  plot <- ggplot2::ggplot(schedule()) +
    ggplot2::geom_point(ggplot2::aes(x = start, y = task)) +
    ggplot2::geom_spoke(flat_spokes)

  layers <- layers_from(rendered(plot))

  testthat::expect_equal(
    vapply(layers, function(one) one$type, character(1)),
    c("point", "gantt")
  )
})


test_that("every interval a spoke announces can be highlighted", {
  skip_if_no_render()

  # A reading that announces correctly and outlines nothing is the blind spot
  # xability/maidr#814 names, and a spoke's grobs are named by grid's own
  # counter rather than after the geom -- so the selectors are worth asserting
  # against the page they were built from rather than assumed to follow the
  # segment's.
  html <- rendered(spoke_plot())
  layer <- layers_from(html)[[1]]

  testthat::expect_length(layer$selectors, length(layer$data))
  for (selector in layer$selectors) {
    id <- sub(".*id='([^']+)'.*", "\\1", selector)
    testthat::expect_true(grepl(id, html, fixed = TRUE))
  }
})
