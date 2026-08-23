# A layer that drew nothing still cost the whole chart its interactivity (#227)
#
# An unclaimed layer makes `has_unsupported_layers()` true and drops the plot
# to a base64 image. That is right when the layer put a mark on the page that
# nothing describes -- a reader told the chart is complete would be told
# wrong. It is not right when the layer drew *nothing*: there is no mark, so
# there is nothing the reader is missing, and the chart pays everything to
# protect them from an absence.
#
# Measured with `save_html()` on ggplot2 3.4.4, thirty points in each row:
#
#     geom_point()                                interactive   50,406 bytes
#     geom_point() + geom_point(data = d[0, ])    interactive   51,313 bytes
#     geom_point() + geom_polygon(data = d[0, ])  base64 image  27,368 bytes
#     geom_point() + geom_polygon()               base64 image  31,848 bytes
#
# Rows two and three are the same chart in every way a reader could tell --
# thirty points and a layer of nothing -- and only one was interactive,
# because its empty layer happened to be of a *kind* the adapter names. Row
# four is the case the fallback exists for and keeps.
#
# The case it turns up in is not contrived: a missing Suggests package.
# `geom_quantile()` without quantreg warns, computes no rows and draws
# nothing. ggplot2 carries on; r-maidr turned the whole figure into a picture
# with no second warning connecting the two.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

# Built at top level: inside a closure the bare column names in `aes()` read
# as undefined globals to static analysis.
positions <- ggplot2::aes(x = x, y = y)
diagonals <- ggplot2::aes(x = x, xend = x + 1, y = y, yend = y + 1)
missing_column <- ggplot2::aes(x = no_such_column, y = y)

#' Thirty points on a rising diagonal
observations <- function() {
  data.frame(x = seq_len(30), y = seq_len(30) + 0.5)
}

#' The same frame with every row removed
#'
#' An empty `data =` is one of several ways to reach a layer that draws
#' nothing; a stat that filters everything out and a stat whose computation
#' failed are the others, and all three arrive here as zero built rows.
nothing <- function() {
  observations()[0, ]
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


test_that("an unclaimed layer that drew nothing is skipped, not unknown", {
  testthat::skip_if_not_installed("ggplot2")

  # Asked of the classifier directly, upstream of rendering, so a regression
  # here shows up as one failure rather than as a fistful about fallbacks.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_point() +
    ggplot2::geom_polygon(data = nothing())

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[2]], plot), "skip"
  )
})


test_that("an unclaimed layer that drew something is still unknown", {
  testthat::skip_if_not_installed("ggplot2")

  # The half that keeps this honest. A filled polygon is drawn and nothing
  # announces it, so declining the chart is what protects the reader -- and
  # this change must not touch it.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_point() +
    ggplot2::geom_polygon(alpha = 0.2)

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[2]], plot), "unknown"
  )
})


test_that("a chart is not taken down by a layer with nothing in it", {
  skip_if_no_render()

  html <- rendered(
    ggplot2::ggplot(observations(), positions) +
      ggplot2::geom_point() +
      ggplot2::geom_polygon(data = nothing())
  )

  testthat::expect_false(fell_back(html))
  testthat::expect_equal(
    vapply(layers_from(html), function(one) one$type, character(1)), "point"
  )
})


test_that("a chart is still taken down by a layer with something in it", {
  skip_if_no_render()

  testthat::expect_true(fell_back(rendered(
    ggplot2::ggplot(observations(), positions) +
      ggplot2::geom_point() +
      ggplot2::geom_polygon(alpha = 0.2)
  )))
})


test_that("a plot made only of empty unclaimed layers still falls back", {
  skip_if_no_render()

  # The trap #176 named, from the other side: "nothing unsupported" must not
  # quietly come to mean "nothing at all". A chart announcing itself as
  # interactive with no layers in it is worse than an image, because an image
  # at least says what it is. `has_unsupported_layers()` catches it because
  # every layer now reads "skip".
  testthat::expect_true(fell_back(rendered(
    ggplot2::ggplot(observations(), positions) +
      ggplot2::geom_polygon(data = nothing())
  )))
})


test_that("the segment branch declines through the same answer", {
  testthat::skip_if_not_installed("ggplot2")

  # `geom_segment()` has a rule of its own and returns "unknown" when its
  # segments lay no lanes (#194). That decline is the same decline, so an
  # empty segment layer must skip and a drawn one that spans no lanes must
  # not -- otherwise the fix would hold at one of the two places the adapter
  # says "unknown" and not the other.
  adapter <- maidr:::Ggplot2Adapter$new()

  empty <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_point() +
    ggplot2::geom_segment(data = nothing(), mapping = diagonals)
  drawn <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_point() +
    ggplot2::geom_segment(mapping = diagonals)

  testthat::expect_equal(
    adapter$detect_layer_type(empty$layers[[2]], empty), "skip"
  )
  testthat::expect_equal(
    adapter$detect_layer_type(drawn$layers[[2]], drawn), "unknown"
  )
})


test_that("a layer the build says nothing about is declined", {
  testthat::skip_if_not_installed("ggplot2")

  # Absent is not empty. A layer that is not in this plot has no frame in
  # this build, and answering "skip" for it would wave through a mark that
  # may well have been drawn -- so the conservative answer is the one that
  # keeps costing what it costs.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(observations(), positions) + ggplot2::geom_point()
  stranger <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_polygon()

  testthat::expect_equal(
    adapter$unread_layer_type(stranger$layers[[1]], plot), "unknown"
  )
  testthat::expect_equal(adapter$detect_layer_type(NULL, plot), "unknown")
})


test_that("a stat that computed nothing does not cost the chart everything", {
  skip_if_no_render()

  # The shape #227 was actually found through, and the reason this is worth
  # more than an argument about empty data frames. A layer's rows can vanish
  # in the *stat* rather than in its input: a filter that matched nothing, an
  # aggregate over no groups, or -- the measured case -- a stat that could
  # not run because a Suggests package is absent. `stat_quantile()` without
  # quantreg warns, computes no rows, and ggplot2 draws the rest of the chart
  # and carries on. Measured before the fix, the same thirty points:
  #
  #     geom_point()                    interactive SVG   50,406 bytes
  #     geom_point() + geom_quantile()  base64 image      27,368 bytes
  #
  # No second warning said the figure had stopped being accessible.
  #
  # Written with a stat of its own rather than by calling `geom_quantile()`:
  # naming quantreg here makes `R CMD check` report it as an unstated
  # dependency of the tests, and declaring it to satisfy that would install
  # it in CI and stop the case from arising at all. The stat below reaches
  # the same state the classifier sees -- a layer with zero built rows,
  # arrived at by computation rather than by an empty input.
  nothing_at_all <- ggplot2::ggproto(
    "StatNothingAtAll", ggplot2::Stat,
    compute_group = function(data, scales) data[0, , drop = FALSE]
  )
  plot <- ggplot2::ggplot(observations(), positions) +
    ggplot2::geom_point() +
    ggplot2::layer(
      stat = nothing_at_all, geom = "polygon", position = "identity",
      data = observations(), mapping = positions
    )

  html <- rendered(plot)

  testthat::expect_false(fell_back(html))
  testthat::expect_equal(
    vapply(layers_from(html), function(one) one$type, character(1)), "point"
  )
})


test_that("a plot that cannot be built is declined rather than skipped", {
  testthat::skip_if_not_installed("ggplot2")

  # The emptiness is read off the built data, so a build that raises has said
  # nothing about what any layer drew. Answering "skip" there would wave
  # through marks that may well have been drawn -- and a plot broken enough
  # not to build is the last one to guess about.
  adapter <- maidr:::Ggplot2Adapter$new()
  broken <- ggplot2::ggplot(observations(), missing_column) +
    ggplot2::geom_polygon()

  testthat::expect_error(suppressWarnings(ggplot2::ggplot_build(broken)))
  testthat::expect_equal(
    adapter$detect_layer_type(broken$layers[[1]], broken), "unknown"
  )
})
