# A stat-keyed `smooth` type could name a geom the processor cannot read (#230)
#
# `detect_layer_type()` decides a layer is a `smooth` partly on its *stat* --
# `StatFunction` and `StatDensity` both claim one -- while
# `Ggplot2SmoothLayerProcessor$resolve_target_layer()` decides what to read on
# the *geom*. A stat can name a geom that list does not, and when it did the
# processor rejected the layer's own index, found nothing in its fallback
# search, and `stop()`ped.
#
# Measured on `main`:
#
#     stat_function(fun = sin, geom = "point")  Error: No smooth curve layers found
#     stat_function(fun = sin, geom = "step")   Error: No smooth curve layers found
#     stat_function(fun = sin)                  interactive
#
# Not a fallback to a picture -- an error out of `save_html()`, so the
# caller's script stopped, and which geom the author passed decided whether
# the call returned at all. A decline is a reading decision; an exception is a
# broken call.
#
# The two lists are now one: `smooth_reads_geom()` states what the processor
# can read, and the classifier consults it before claiming. A function drawn
# as points then falls through to the branch for the geom it was actually
# drawn with and reads as the scatter on the page. That loses "this is a fit,
# not observations" for those spellings, which is worth less than a chart that
# renders.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

positions <- ggplot2::aes(x = x, y = y)

observations <- function() {
  data.frame(x = 1:10, y = (1:10) * 2)
}

#' A sampled sine over a fixed range, drawn with whichever geom is asked for
sampled <- function(geom = "function") {
  ggplot2::ggplot(observations(), positions) +
    ggplot2::xlim(0, 5) +
    ggplot2::stat_function(fun = sin, geom = geom)
}

#' Render a plot and return its HTML
rendered <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

fell_back <- function(html) {
  grepl("base64", html, fixed = TRUE)
}

kind_of <- function(plot, index = 1L) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}


test_that("a function drawn as points renders instead of raising", {
  skip_if_no_render()

  # The whole of #230. `save_html()` used to raise "No smooth curve layers
  # found in plot" and stop the caller's script.
  plot <- sampled("point")

  # One render, three claims about it. `rendered()` runs `save_html()` and
  # round-trips a temp file, so asking twice costs twice.
  html <- NULL
  testthat::expect_no_error(html <- suppressWarnings(rendered(plot)))
  testthat::expect_equal(kind_of(plot), "point")
  testthat::expect_false(fell_back(html))
})


test_that("a function drawn as a staircase declines instead of raising", {
  skip_if_no_render()

  # `GeomStep` is claimed only on `StatIdentity` and `StatEcdf`, which the
  # step branch says in as many words: a step layer on some other computed
  # stat keeps returning "unknown" and so keeps the static-image fallback.
  # This restores that answer, which #202's stat check had turned into a
  # crash.
  plot <- sampled("step")

  html <- NULL
  testthat::expect_no_error(html <- suppressWarnings(rendered(plot)))
  testthat::expect_equal(kind_of(plot), "unknown")
  testthat::expect_true(fell_back(html))
})


test_that("a function drawn the way it is meant to be still reads as a curve", {
  skip_if_no_render()

  # Additive. The spellings the processor *can* read are untouched, which is
  # what keeps this a fix rather than a narrowing.
  for (geom in c("function", "area", "smooth")) {
    plot <- sampled(geom)
    testthat::expect_equal(kind_of(plot), "smooth", info = geom)
    testthat::expect_false(fell_back(rendered(plot)), info = geom)
  }
})


test_that("a density drawn as points is not claimed either", {
  testthat::skip_if_not_installed("ggplot2")

  # `StatDensity` is the other stat-keyed claim, and it had the same trap
  # waiting. Nothing measured reaches it as a crash today, and this keeps it
  # that way rather than leaving the second stat unguarded.
  plot <- ggplot2::ggplot(observations(), ggplot2::aes(x = x)) +
    ggplot2::stat_density(geom = "point")

  testthat::expect_false(kind_of(plot) == "smooth")
})


test_that("a density drawn as a curve still reads as one", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(observations(), ggplot2::aes(x = x)) +
    ggplot2::geom_density()

  testthat::expect_equal(kind_of(plot), "smooth")
})


test_that("the processor's list is the one the classifier consults", {
  testthat::skip_if_not_installed("ggplot2")

  # The invariant #230 named: the two lists cannot disagree, because there is
  # only one. Asked of the predicate directly so a geom added to it without
  # the processor being able to read it fails here rather than in a render.
  reads <- maidr:::smooth_reads_geom

  for (name in c(
    "GeomSmooth", "GeomLine", "GeomDensity", "GeomFunction",
    "GeomQuantile", "GeomArea"
  )) {
    testthat::expect_true(reads(get(name, envir = asNamespace("ggplot2"))), info = name)
  }
  for (name in c("GeomPoint", "GeomStep", "GeomBar", "GeomTile")) {
    testthat::expect_false(reads(get(name, envir = asNamespace("ggplot2"))), info = name)
  }
})


test_that("every layer typed smooth is one the processor can read", {
  testthat::skip_if_not_installed("ggplot2")

  # The property, over the spellings that reach a stat-keyed claim. A `smooth`
  # the processor cannot read is the crash, so this is the pairing itself
  # rather than a list of known-good cases.
  for (geom in c("function", "line", "path", "point", "step", "area", "smooth")) {
    plot <- sampled(geom)
    if (kind_of(plot) == "smooth") {
      testthat::expect_true(
        maidr:::smooth_reads_geom(plot$layers[[1]]$geom),
        info = geom
      )
    }
  }
})
