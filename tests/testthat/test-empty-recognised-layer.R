# #232. A layer can be typed perfectly well and still have nothing in it.
#
# #227 stopped an *unclaimed* empty layer from costing the chart its
# interactivity: `detect_layer_type()` asks `layer_drew_nothing()` before
# answering "unknown", and returns "skip" instead. A layer of a *recognised*
# type got no such question -- it was typed on its geom, a processor was built
# for it, and it reached the schema holding nothing.
#
# Measured on ten points, the second layer drawn from `d[0, ]`:
#
#     geom_point()   point(10) point(0)      an empty layer of points
#     geom_col()     point(10) bar(0)        an empty layer of bars
#     geom_line()    point(10) line(1x0)     one series, holding nothing
#     geom_smooth()  point(10) smooth(1x0)   one series, holding nothing
#
# The two series cases are the worse ones: a reader is offered something to
# walk into, and there is nothing in it. That is the shape xability/py-maidr#421
# named on the Python side.
#
# The question is now asked once per chart, in the orchestrator, which already
# has to build the plot -- rather than per layer in the classifier, which is
# what made #231 leave it. Measured on a 5,000-point two-layer chart: 3.38 s
# against 3.22 s, one `ggplot_build()` of 0.14 s, and the same 0.14 s however
# many layers the chart has.

skip_unless_renderable <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

observations <- function() {
  data.frame(x = 1:10, y = (1:10)^1.2)
}

#' The layers a plot emits, as "type(n)" strings in order
#'
#' A series layer reports "type(SxN)" -- S series of N points -- because a
#' smooth's `data` is a list of series, so its length alone cannot tell an
#' empty layer from a full one. Measured: a real smooth is `smooth(1x80)` and
#' an empty one was `smooth(1x0)`.
emitted_layers <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  html <- paste(readLines(file, warn = FALSE), collapse = "")

  if (grepl("base64", html, fixed = TRUE)) {
    return("image")
  }

  attribute <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (!length(attribute)) {
    return(character(0))
  }
  json <- sub('"$', "", sub('^maidr-data="', "", attribute))
  for (pair in list(c("&amp;", "&"), c("&lt;", "<"), c("&gt;", ">"),
                    c("&quot;", '"'))) {
    json <- gsub(pair[[1]], pair[[2]], json, fixed = TRUE)
  }
  schema <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  vapply(schema$subplots[[1]][[1]]$layers, function(layer) {
    rows <- layer$data
    series <- length(rows) > 0 && is.list(rows[[1]]) && is.null(names(rows[[1]]))
    size <- if (series) {
      paste0(length(rows), "x", paste(vapply(rows, length, 0L), collapse = "/"))
    } else {
      as.character(length(rows))
    }
    sprintf("%s(%s)", layer$type, size)
  }, "")
}


test_that("a recognised layer that drew nothing is not emitted", {
  skip_unless_renderable()

  d <- observations()
  empties <- list(
    point = ggplot2::geom_point(data = d[0, ]),
    bar = ggplot2::geom_col(data = d[0, ]),
    line = ggplot2::geom_line(data = d[0, ]),
    smooth = ggplot2::geom_smooth(data = d[0, ], se = FALSE)
  )

  for (name in names(empties)) {
    plot <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
      ggplot2::geom_point() +
      empties[[name]]
    testthat::expect_equal(emitted_layers(plot), "point(10)", info = name)
  }
})


test_that("a layer that drew something is untouched", {
  skip_unless_renderable()

  d <- observations()

  testthat::expect_equal(
    emitted_layers(ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
      ggplot2::geom_point()),
    "point(10)"
  )

  # The real smooth is the one worth pinning beside the empty one: both emit a
  # single *series*, so a rule counting `data` alone would have called this
  # empty too.
  both <- emitted_layers(
    ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
      ggplot2::geom_point() +
      ggplot2::geom_smooth(se = FALSE)
  )
  testthat::expect_length(both, 2L)
  testthat::expect_equal(both[[1]], "point(10)")
  testthat::expect_match(both[[2]], "^smooth\\(1x[1-9]")
})


test_that("a plot whose only layer is empty falls back to an image", {
  skip_unless_renderable()

  # "skip" rather than a fourth answer, so the #176 guard sees it: a chart
  # announcing itself as interactive with nothing in it is worse than an
  # image, because an image at least says what it is.
  d <- observations()
  plot <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point(data = d[0, ])

  testthat::expect_equal(emitted_layers(plot), "image")
})


test_that("the emptiness question is not asked of the classifier", {
  skip_unless_renderable()

  # Where this is asked matters. `detect_layer_type()` answers what *kind* of
  # chart a layer is, and an empty `geom_point()` is still a point layer --
  # the orchestrator is what decides there is nothing to make a processor
  # for. Keeping the two apart is why the classifier stays a pure question
  # about kind, and why the cost is one build per chart rather than one per
  # layer.
  d <- observations()
  adapter <- Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point(data = d[0, ])

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot),
    "point"
  )
})
