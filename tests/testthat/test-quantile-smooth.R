# `geom_quantile()` cost its chart everything for being a subclass (#229)
#
# `detect_layer_type()` matches `class(geom)[1]`, and the chain is
# `GeomQuantile < GeomPath < Geom`. `GeomPath` reads as `line`; the subclass
# matched no branch, reached the unknown processor and took the whole plot
# down -- the third geom missed this way, after `GeomFunction` (#202) and
# `GeomSpoke` (#225).
#
# Measured with `save_html()` on thirty points, with a quantile layer that
# draws:
#
#     geom_point()                             interactive SVG   50,409 bytes
#     geom_point() + a GeomQuantile layer      base64 image      44,724 bytes
#     geom_point() + geom_smooth(se = FALSE)   interactive SVG   57,823 bytes
#
# The scatter read on its own and read as nothing the moment a quantile fit
# was drawn beside it, while the *mean* fit beside the same points read fine.
#
# `smooth` rather than `line`, for the reason `StatFunction` is:
# `stat_quantile()` fits `rq`/`rqss` and evaluates it at renderer-chosen
# positions exactly as `stat_smooth()` does for the conditional mean, so the
# curve is a model over the data rather than a series of it.
#
# ## Testing this without quantreg
#
# `geom_quantile()` needs the **quantreg** package, which this package does
# not declare. Naming it -- even inside a `skip_if` -- makes `R CMD check`
# report `'library' or 'require' call not declared from: 'quantreg'`, and
# `check-r-package` errors on warnings. That is the failure #228 hit.
#
# Both halves are reachable without it, and nothing below mentions it:
#
#   - the dispatch needs no data, because it reads `class(layer$geom)[1]`;
#   - the reading needs a layer that draws, which `layer(geom = GeomQuantile,
#     stat = "identity", ...)` gives over data the test supplies.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

# Built at top level: inside a closure the bare column names in `aes()` read
# as undefined globals to static analysis.
positions <- ggplot2::aes(x = x, y = y)

#' Ten points on a rising line, so a fit over them is exactly the input
observations <- function() {
  data.frame(x = 1:10, y = (1:10) * 2)
}

#' A real `GeomQuantile` layer that draws without quantreg
#'
#' The geom is what dispatch keys on, so the stat can be anything yielding
#' path-shaped data. `geom_quantile()` itself pairs this geom with
#' `stat_quantile`, which cannot run here -- and which the reading does not
#' need, since what is under test is how a drawn quantile curve is read.
quantile_layer <- function(frame = observations()) {
  ggplot2::layer(
    geom = ggplot2::GeomQuantile, stat = "identity", position = "identity",
    data = frame, mapping = positions
  )
}

#' Render a plot and return its HTML
rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

#' Whether a rendering is the static-image fallback rather than a chart
fell_back <- function(html) {
  grepl("base64", html, fixed = TRUE)
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

#' The layers of one type, in emission order
of_type <- function(layers, type) {
  layers[vapply(layers, function(one) one$type, character(1)) == type]
}


test_that("a quantile fit is classified as the smooth it is", {
  testthat::skip_if_not_installed("ggplot2")

  # Asked of the classifier directly, upstream of rendering, and of
  # `geom_quantile()` itself rather than of the stand-in below: dispatch
  # reads the geom's class and needs no data, so this is the real call.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(observations(), positions) + ggplot2::geom_quantile()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "smooth"
  )
})


test_that("a plain path is still a line", {
  testthat::skip_if_not_installed("ggplot2")

  # The additive half. `GeomQuantile` is named rather than reached through
  # `GeomPath`, so the parent keeps its own reading -- a `geom_path()` draws
  # observations and must not start announcing itself as a fit.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(observations(), positions) + ggplot2::geom_path()

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "line"
  )
})


test_that("a chart is not taken down by a quantile fit drawn beside it", {
  skip_if_no_render()

  # What the issue is about.
  plot <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_point() +
    quantile_layer()

  html <- rendered(plot)

  testthat::expect_false(fell_back(html))
  testthat::expect_equal(
    vapply(layers_from(html), function(one) one$type, character(1)),
    c("point", "smooth")
  )
})


test_that("the curve announces the positions it was drawn at", {
  skip_if_no_render()

  # Written out once, so the file states what a reader is told rather than
  # only that a layer of the right type appeared. The fit here is the input,
  # which is what makes the expected values checkable by eye.
  layer <- of_type(layers_from(rendered(
    ggplot2::ggplot(observations(), positions) +
      ggplot2::geom_point() +
      quantile_layer()
  )), "smooth")[[1]]

  drawn <- vapply(
    layer$data[[1]], function(one) sprintf("%g/%g", one$x, one$y), character(1)
  )

  testthat::expect_equal(
    drawn,
    c("1/2", "2/4", "3/6", "4/8", "5/10", "6/12", "7/14", "8/16", "9/18", "10/20")
  )
})


test_that("a mean fit and a quantile fit beside it are told apart", {
  skip_if_no_render()

  # The shape review caught on #226: two layers of a kind resolving to the
  # same grob, so the second highlights the first's mark while announcing
  # its own. Both curves are polylines, which is the population that
  # collided there, so it is worth asserting rather than assuming.
  plot <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(se = FALSE, method = "lm", formula = y ~ x) +
    quantile_layer()

  curves <- of_type(layers_from(rendered(plot)), "smooth")

  testthat::expect_length(curves, 2)
  first <- unlist(curves[[1]]$selectors)
  second <- unlist(curves[[2]]$selectors)
  testthat::expect_length(intersect(first, second), 0L)
  testthat::expect_false(
    identical(length(curves[[1]]$data[[1]]), length(curves[[2]]$data[[1]]))
  )
})


test_that("every position the curve announces can be highlighted", {
  skip_if_no_render()

  # A reading that announces correctly and outlines nothing is the blind spot
  # xability/maidr#814 names. A quantile curve's grob is named by grid's own
  # counter rather than after the geom, so the selectors are worth asserting
  # against the page they were built from.
  html <- rendered(
    ggplot2::ggplot(observations(), positions) +
      ggplot2::geom_point() +
      quantile_layer()
  )
  layer <- of_type(layers_from(html), "smooth")[[1]]

  selectors <- unlist(layer$selectors)
  testthat::expect_gt(length(selectors), 0L)
  for (selector in selectors) {
    id <- gsub("\\\\", "", sub("^#", "", selector))
    testthat::expect_true(grepl(id, html, fixed = TRUE))
  }
})


test_that("a quantile stat on another geom is left to that geom", {
  testthat::skip_if_not_installed("ggplot2")

  # Deliberately not claimed, and pinned so the symmetric addition is a
  # decision rather than a reflex. `StatQuantile` beside `StatDensity` in the
  # smooth branch would type `stat_quantile(geom = "point")` as a smooth,
  # whose `GeomPoint` the smooth processor does not recognise -- and the
  # render then stops outright rather than declining. `StatFunction` already
  # does exactly that; it is reported as #230 rather than matched here.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(observations(), positions) +
    ggplot2::stat_quantile(geom = "point")

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "point"
  )
})
