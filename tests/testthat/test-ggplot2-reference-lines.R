# One `geom_hline()` turned a fully supported chart into a static image (#176).
#
# `detect_layer_type()` had no branch for GeomHline/GeomVline/GeomAbline, so
# they fell through to "unknown" -- and one "unknown" layer makes
# `has_unsupported_layers()` true, which drops the *whole plot* to a base64
# image. Measured with `save_html()`:
#
#     geom_boxplot()                     interactive SVG   44,353 bytes
#     geom_boxplot() + geom_hline()      base64 image      14,680 bytes
#     geom_boxplot() + geom_vline()      base64 image      14,480 bytes
#     geom_line()    + geom_hline()      base64 image      30,808 bytes
#
# The chart itself was fully supported. What it lost -- sonification, braille,
# keyboard navigation, the text description -- it lost to a threshold line,
# which is among the most ordinary things to draw on a chart: a target, a
# control limit, last year's median, a significance cutoff.
#
# A reference line carries no observations, so it is skipped rather than read.
# That is the same answer the Python binding reached in xability/py-maidr#434,
# and for the stronger of the two reasons: read as a line layer, an `axhline`
# there announced its endpoints as 0 and 1, because a blended transform puts
# its coordinates in axes-fraction space rather than data space. Not a partial
# reading -- a confident reading of a series that is not there.
#
# The trap on the other side is "no unsupported layers" quietly coming to mean
# "no layers at all". A plot made only of skipped layers emits zero layers, and
# announcing *that* as an interactive chart is worse than an image, because an
# image at least says what it is. Those cases are below, and they are the ones
# a naive version of this fix breaks -- one of them, `annotate("text")` alone,
# was already broken before #176, since GeomText was already tagged "skip":
# on the unfixed code it reported `should_fallback() == FALSE` and emitted 0
# layers.

testthat::skip_if_not_installed("ggplot2")

df <- function() {
  data.frame(
    g = rep(c("a", "b"), each = 25),
    v = rep(c(2, 4, 6, 8, 10), 10),
    x = 1:50,
    f = rep(c("p", "q"), 25),
    stringsAsFactors = FALSE
  )
}

# Render through `save_html()` and report what a reader actually receives: an
# interactive SVG, or a base64 image with the fallback warning.
rendered <- function(plot) {
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

# The layers the orchestrator emits, by type. A skipped layer contributes
# nothing here, which is the point of skipping it.
emitted_layers <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  res$subplots[[1]][[1]]$layers
}

layer_types <- function(plot) {
  vapply(emitted_layers(plot), function(layer) layer$type, character(1))
}

# ==============================================================================
# A reference line no longer costs the chart its interactivity
# ==============================================================================

test_that("a boxplot with a horizontal threshold still renders interactively", {
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
      ggplot2::geom_boxplot() +
      ggplot2::geom_hline(yintercept = 6)
  )

  testthat::expect_true(result$interactive)
  testthat::expect_false(result$fell_back)
})

test_that("a scatter plot with a vertical cutoff still renders interactively", {
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_point() +
      ggplot2::geom_vline(xintercept = 25)
  )

  testthat::expect_true(result$interactive)
  testthat::expect_false(result$fell_back)
})

test_that("a scatter plot with a reference slope still renders interactively", {
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_point() +
      ggplot2::geom_abline(slope = 0.1, intercept = 4)
  )

  testthat::expect_true(result$interactive)
  testthat::expect_false(result$fell_back)
})

test_that("a line chart with a threshold still renders interactively", {
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_line() +
      ggplot2::geom_hline(yintercept = 6)
  )

  testthat::expect_true(result$interactive)
  testthat::expect_false(result$fell_back)
})

# ==============================================================================
# The chart underneath is unchanged -- skipping must not read less
# ==============================================================================

test_that("the box layer is still emitted alongside the threshold", {
  # The guard. "Does not fall back" is satisfiable by rendering an interactive
  # shell with nothing in it, so what the chart still carries is asserted too.
  testthat::expect_identical(
    layer_types(
      ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
        ggplot2::geom_boxplot() +
        ggplot2::geom_hline(yintercept = 6)
    ),
    "box"
  )
})

test_that("the box layer carries exactly what it carries without the line", {
  # Stronger than the type: the values a reader is given must be the same
  # ones, not merely a layer of the same kind.
  with_line <- emitted_layers(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
      ggplot2::geom_boxplot() +
      ggplot2::geom_hline(yintercept = 6)
  )
  without_line <- emitted_layers(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
      ggplot2::geom_boxplot()
  )

  testthat::expect_identical(with_line[[1]]$data, without_line[[1]]$data)
})

test_that("the reference line adds no layer of its own", {
  # The line is decoration, and the grammar has no annotation shape to put it
  # in. Emitting one anyway would announce its intercept as a data series --
  # the failure mode xability/py-maidr#434 measured.
  testthat::expect_length(
    emitted_layers(
      ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
        ggplot2::geom_point() +
        ggplot2::geom_vline(xintercept = 25)
    ),
    1
  )
})

test_that("three reference lines are still no layers", {
  testthat::expect_identical(
    layer_types(
      ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
        ggplot2::geom_point() +
        ggplot2::geom_hline(yintercept = 6) +
        ggplot2::geom_vline(xintercept = 25) +
        ggplot2::geom_abline(slope = 0.1, intercept = 4)
    ),
    "point"
  )
})

# ==============================================================================
# A faceted plot types its panels from a layer that produced a reading
# ==============================================================================
#
# `process_facet_panel()` builds a processor per layer and then types the panel
# from "the first layer that produced a result". `create_processor()` has no
# "skip" arm, so a skipped layer fell to the switch default, got an *unknown*
# processor, and won that scan. Measured on a faceted scatter:
#
#     geom_hline() + geom_point() + facet_wrap(~f)   layers [skip skip]
#     geom_point() + geom_hline() + facet_wrap(~f)   layers [point point]
#
# Same chart, same data, typed by which layer happened to be written first.
# The patchwork paths already guarded this and `create_layer_processors()`
# does too; the facet path did not.
#
# Not introduced by #176 -- `GeomText` was already tagged "skip", so
# `geom_text() + geom_point() + facet_wrap()` typed both panels "skip" on the
# unfixed code, which is measured below. Skipping reference lines just makes
# it far easier to reach.

panel_types <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  types <- character(0)
  for (subplot in res$subplots) {
    for (cell in subplot) {
      for (layer in cell$layers) types <- c(types, layer$type)
    }
  }
  types
}

test_that("a faceted chart types its panels the same either way round", {
  after <- panel_types(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_point() +
      ggplot2::geom_hline(yintercept = 6) +
      ggplot2::facet_wrap(~f)
  )
  before <- panel_types(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_hline(yintercept = 6) +
      ggplot2::geom_point() +
      ggplot2::facet_wrap(~f)
  )

  testthat::expect_identical(before, after)
})

test_that("a faceted chart with the line drawn first is still points", {
  # Pinned as a value rather than only against the other ordering, so the two
  # agreeing on the *wrong* type would not pass.
  testthat::expect_identical(
    panel_types(
      ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
        ggplot2::geom_hline(yintercept = 6) +
        ggplot2::geom_point() +
        ggplot2::facet_wrap(~f)
    ),
    c("point", "point")
  )
})

test_that("a faceted chart with a text annotation first is still points", {
  # The case that predates #176: `GeomText` has been tagged "skip" all along,
  # so this ordering typed both panels "skip" before the facet guard existed.
  testthat::expect_identical(
    panel_types(
      ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
        ggplot2::geom_text(ggplot2::aes(label = "hi")) +
        ggplot2::geom_point() +
        ggplot2::facet_wrap(~f)
    ),
    c("point", "point")
  )
})

test_that("a faceted chart of nothing but a reference line falls back", {
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_hline(yintercept = 6) +
      ggplot2::facet_wrap(~f)
  )

  testthat::expect_true(orchestrator$should_fallback())
})

# ==============================================================================
# A plot that is only annotation must keep falling back
# ==============================================================================

test_that("a plot of nothing but a horizontal line falls back to an image", {
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
      ggplot2::geom_hline(yintercept = 6)
  )

  testthat::expect_false(result$interactive)
  testthat::expect_true(result$fell_back)
})

test_that("a plot of nothing but a vertical line falls back to an image", {
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_vline(xintercept = 25)
  )

  testthat::expect_false(result$interactive)
  testthat::expect_true(result$fell_back)
})

test_that("a plot of nothing but a text annotation falls back to an image", {
  # Not a #176 case: GeomText was already tagged "skip", so this plot claimed
  # to be interactive and emitted 0 layers long before reference lines were
  # skipped. Measured on the code as it stood: `should_fallback()` FALSE,
  # `length(layers)` 0.
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::annotate("text", x = 5, y = 5, label = "hi")
  )

  testthat::expect_false(result$interactive)
  testthat::expect_true(result$fell_back)
})

test_that("an annotation-only plot is caught because it reads as nothing", {
  # Why the fallback is the right answer here rather than a rule about which
  # geoms were used: there is no chart left to announce.
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
      ggplot2::geom_hline(yintercept = 6)
  )

  testthat::expect_true(orchestrator$should_fallback())
  testthat::expect_length(
    orchestrator$generate_maidr_data()$subplots[[1]][[1]]$layers, 0
  )
})

# ==============================================================================
# A genuinely unsupported geom still falls back
# ==============================================================================

# The stand-in for "a geom maidr cannot read" is `geom_polygon()`. It was
# `geom_rug()` until #222 gave a rug its own processor -- which is the risk a
# stand-in carries, and the reason this note is here rather than left for the
# next reader to work out from a failure. What these three tests are about is
# the fallback, not the geom: any layer that reads as `unknown` serves, and
# `geom_polygon()` is measured as one.
test_that("an unsupported geom over a boxplot still falls back", {
  # "skip" must stay narrow. Widening it into a general "ignore what we do not
  # understand" would leave charts announcing a partial reading as a complete
  # one, which is exactly what the fallback exists to prevent.
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
      ggplot2::geom_boxplot() +
      ggplot2::geom_polygon()
  )

  testthat::expect_false(result$interactive)
  testthat::expect_true(result$fell_back)
})

test_that("an unsupported geom alongside a reference line still falls back", {
  result <- rendered(
    ggplot2::ggplot(df(), ggplot2::aes(g, v)) +
      ggplot2::geom_boxplot() +
      ggplot2::geom_hline(yintercept = 6) +
      ggplot2::geom_polygon()
  )

  testthat::expect_false(result$interactive)
  testthat::expect_true(result$fell_back)
})

# ==============================================================================
# The adapter's own answer
# ==============================================================================

test_that("the adapter tags each reference-line geom as skip", {
  adapter <- maidr:::Ggplot2Adapter$new()

  plots <- list(
    hline = ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_hline(yintercept = 6),
    vline = ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_vline(xintercept = 25),
    abline = ggplot2::ggplot(df(), ggplot2::aes(x, v)) +
      ggplot2::geom_abline(slope = 0.1, intercept = 4)
  )

  for (name in names(plots)) {
    plot <- plots[[name]]
    testthat::expect_identical(
      adapter$detect_layer_type(plot$layers[[1]], plot), "skip",
      info = name
    )
  }
})

test_that("an unsupported geom is still unknown rather than skipped", {
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(df(), ggplot2::aes(x, v)) + ggplot2::geom_polygon()

  testthat::expect_identical(
    adapter$detect_layer_type(plot$layers[[1]], plot), "unknown"
  )
})
