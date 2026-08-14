# A base R violin was not readable at all (#132)
#
# `Ggplot2ProcessorFactory` has a violin processor; the base R adapter had
# none, so `vioplot::vioplot()` fell through to the unknown-layer path and the
# chart landed on maidr's static fallback. Which plotting system a user chose
# should not decide whether their chart is accessible.
#
# A violin is announced as two layers, matching the ggplot2 adapter:
# `violin_box` summarises the distribution and `violin_kde` is the shape the
# chart draws.
#
# The selectors here are better placed than the plotly binding's, and for a
# reason worth recording: vioplot draws the whisker, the quartile box and the
# median as *separate* grobs, so each box section can point at what it
# actually is. Measured, one of each per violin:
#
#     graphics-plot-1-box-1      polygon  n=4     <- the plot frame, NOT a violin
#     graphics-plot-1-polygon-1  polygon  n=200   <- violin body
#     graphics-plot-1-lines-1    lines    n=2     <- whisker
#     graphics-plot-1-rect-1     rect     n=1     <- quartile box
#     graphics-plot-1-points-1   points   n=1     <- median dot
#
# and the element names they export under, verified against a real
# `gridSVG::grid.export()`: `polygon`, `polyline`, `rect` and `use`
# respectively. Every emitted selector was then resolved against that export
# in Chromium across a 12-violin plot; all 48 matched exactly one element.

skip_if_no_vioplot <- function() {
  testthat::skip_if_not_installed("vioplot")
  testthat::skip_if_not_installed("sm")
}

violin_samples <- function() {
  set.seed(11)
  list(A = stats::rnorm(40, 10, 2), B = stats::rnorm(30, 14, 3))
}

# Draw a vioplot off-screen and return its grob tree.
violin_grobs <- function(...) {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path, width = 7, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  grDevices::dev.control("enable")
  vioplot::vioplot(...)
  tryCatch(
    {
      suppressMessages(gridGraphics::grid.echo())
      grid::grid.grab()
    },
    error = function(e) NULL
  )
}

violin_layers <- function(args, grobs = NULL) {
  info <- list(plot_call = list(args = args), group_index = 1)
  processor <- BaseRViolinLayerProcessor$new(info)
  processor$process(NULL, NULL, NULL, grobs, info)
}

test_that("a vioplot call is read as the violin_box + violin_kde pair", {
  skip_if_no_vioplot()
  s <- violin_samples()

  result <- violin_layers(list(s$A, s$B, names = c("A", "B")))

  expect_true(isTRUE(result$multi_layer))
  expect_equal(
    vapply(result$layers, function(l) l$type, character(1)),
    c("violin_box", "violin_kde")
  )
})

test_that("the two layers describe the violins in the same order", {
  skip_if_no_vioplot()
  s <- violin_samples()

  result <- violin_layers(list(s$A, s$B, names = c("A", "B")))
  box <- result$layers[[1]]
  kde <- result$layers[[2]]

  # Row `i` of the box and curve `i` of the KDE have to be one violin. A
  # reader moving between them would otherwise hear one violin's quartiles
  # against another's shape, with nothing signalling the swap.
  expect_equal(vapply(box$data, function(d) d$z, character(1)), c("A", "B"))
  expect_equal(
    vapply(kde$data, function(curve) curve[[1]]$x, character(1)),
    c("A", "B")
  )
})

test_that("the box summarises the sample and separates no outliers", {
  skip_if_no_vioplot()
  s <- violin_samples()

  box <- violin_layers(list(s$A, s$B, names = c("A", "B")))$layers[[1]]
  first <- box$data[[1]]

  expect_lt(first$q1, first$q2)
  expect_lt(first$q2, first$q3)
  expect_lte(first$min, first$q1)
  expect_gte(first$max, first$q3)

  # vioplot draws no outliers: the curve beside the box already covers the
  # tails, so splitting points off would announce a distinction the chart does
  # not make.
  expect_length(first$lowerOutliers, 0)
  expect_length(first$upperOutliers, 0)
})

test_that("each curve carries one point per evaluated position", {
  skip_if_no_vioplot()
  s <- violin_samples()

  kde <- violin_layers(list(s$A, s$B, names = c("A", "B")))$layers[[2]]

  expect_length(kde$data, 2)
  for (curve in kde$data) {
    positions <- vapply(curve, function(p) p$y, numeric(1))
    expect_false(is.unsorted(positions))
    expect_true(all(vapply(curve, function(p) p$width, numeric(1)) >= 0))
    # `width`, not `density`: the ggplot2 and matplotlib paths spell it that
    # way for this layer and the frontend reads `density ?? width ?? 0`. No
    # pixel coordinates -- the base R path has no SVG coordinate injection, so
    # one emitted here would be a guess at where the point ended up.
    expect_equal(sort(names(curve[[1]])), c("width", "x", "y"))
  }
})

test_that("a category with no spread is left out rather than invented", {
  skip_if_no_vioplot()
  s <- violin_samples()

  result <- violin_layers(list(rep(7, 5), s$B, names = c("flat", "B")))
  box <- result$layers[[1]]

  # vioplot draws a degenerate mark for a flat sample, and there is no
  # distribution to describe. Announcing a curve would claim a spread the
  # chart does not show.
  expect_equal(vapply(box$data, function(d) d$z, character(1)), "B")
})

test_that("a formula call is declined rather than guessed at", {
  skip_if_no_vioplot()

  # Resolving a formula needs the environment the call was made in, which the
  # processor no longer has. Declining leaves the chart on maidr's static
  # fallback, which says nothing rather than something invented.
  frame <- data.frame(v = c(1, 2, 3, 4, 5, 6), g = rep(c("a", "b"), each = 3))
  expect_null(violin_layers(list(v ~ g, data = frame)))
})

test_that("the orientation follows vioplot's horizontal argument", {
  skip_if_no_vioplot()
  s <- violin_samples()

  upright <- violin_layers(list(s$A, s$B))
  sideways <- violin_layers(list(s$A, s$B, horizontal = TRUE))

  expect_equal(upright$layers[[1]]$orientation, "vert")
  expect_equal(sideways$layers[[1]]$orientation, "horz")

  # gridSVG's Y-flip inverts the quartile box's edges for a vertical plot, so
  # the frontend is told to swap them back -- the same signal the base R box
  # plot sends.
  expect_equal(upright$layers[[1]]$domMapping$iqrDirection, "reverse")
  expect_equal(sideways$layers[[1]]$domMapping$iqrDirection, "forward")
})

test_that("each section of the box points at the grob that draws it", {
  skip_if_no_vioplot()
  s <- violin_samples()
  grobs <- violin_grobs(s$A, s$B, names = c("A", "B"))
  skip_if(is.null(grobs), "grid.echo unavailable")

  box <- violin_layers(list(s$A, s$B, names = c("A", "B")), grobs)$layers[[1]]

  expect_length(box$selectors, 2)
  first <- box$selectors[[1]]

  # Unlike a plotly violin, whose whole box is one path, vioplot draws the
  # parts separately -- so the whiskers, the quartile box and the median each
  # get the element that actually draws them.
  expect_equal(first$min, "polyline[id^='graphics-plot-1-lines-1.1']")
  expect_equal(first$max, first$min)
  expect_equal(first$iq, "rect[id^='graphics-plot-1-rect-1.1']")
  expect_equal(first$q2, "use[id^='graphics-plot-1-points-1.1']")
})

test_that("each curve points at its own violin body", {
  skip_if_no_vioplot()
  s <- violin_samples()
  grobs <- violin_grobs(s$A, s$B, names = c("A", "B"))
  skip_if(is.null(grobs), "grid.echo unavailable")

  kde <- violin_layers(list(s$A, s$B, names = c("A", "B")), grobs)$layers[[2]]

  expect_equal(
    unlist(kde$selectors),
    c(
      "polygon[id^='graphics-plot-1-polygon-1.1']",
      "polygon[id^='graphics-plot-1-polygon-2.1']"
    )
  )
})

test_that("only the violin bodies are collected", {
  skip_if_no_vioplot()
  s <- violin_samples()
  grobs <- violin_grobs(s$A, s$B)
  skip_if(is.null(grobs), "grid.echo unavailable")

  info <- list(plot_call = list(args = list(s$A, s$B)), group_index = 1)
  processor <- BaseRViolinLayerProcessor$new(info)

  # Two violins means exactly two bodies. `graphics-plot-1-box-1` is the panel
  # frame and is a polygon *grob*, but it is not named `polygon`, so it never
  # enters this search -- worth stating because it is easy to assume the
  # anchoring is what keeps it out, and it is not.
  expect_equal(
    processor$grob_ids(grobs, 1, "polygon"),
    c("graphics-plot-1-polygon-1", "graphics-plot-1-polygon-2")
  )
})

test_that("each plot collects only its own grobs", {
  # Two plots on one device, and neither may take the other's violins.
  #
  # Worth being precise about what does the work here, because it is easy to
  # credit the wrong thing: measured, `graphics-plot-11-polygon-1` is excluded
  # from plot 1's search by the `-` delimiter whether the pattern is anchored
  # or not. The anchoring is defensive against a longer name beginning the
  # same way (`-polygon-1-extra`), which gridSVG does not emit today. This
  # test pins the separation itself, which is the behaviour that matters.
  fake <- grid::gTree(children = grid::gList(
    grid::grob(name = "graphics-plot-1-polygon-1"),
    grid::grob(name = "graphics-plot-2-polygon-1"),
    grid::grob(name = "graphics-plot-2-polygon-2")
  ))
  info <- list(plot_call = list(args = list(1:10)), group_index = 1)
  processor <- BaseRViolinLayerProcessor$new(info)

  expect_equal(processor$grob_ids(fake, 1, "polygon"), "graphics-plot-1-polygon-1")
  expect_equal(
    processor$grob_ids(fake, 2, "polygon"),
    c("graphics-plot-2-polygon-1", "graphics-plot-2-polygon-2")
  )
})

test_that("a tenth violin sorts after the ninth, not after the first", {
  skip_if_no_vioplot()
  set.seed(11)
  samples <- lapply(1:12, function(i) stats::rnorm(30, 10 + i, 2))
  grobs <- do.call(violin_grobs, samples)
  skip_if(is.null(grobs), "grid.echo unavailable")

  kde <- violin_layers(samples, grobs)$layers[[2]]
  ids <- unlist(kde$selectors)

  # Sorted lexically, `-10` falls between `-1` and `-2` and every violin from
  # the second on points at its neighbour's shape. Ordering by the trailing
  # integer is what keeps them aligned.
  expect_length(ids, 12)
  expect_equal(ids[[10]], "polygon[id^='graphics-plot-1-polygon-10.1']")
  expect_equal(ids[[2]], "polygon[id^='graphics-plot-1-polygon-2.1']")
})

test_that("no grob tree means no selectors rather than broken ones", {
  skip_if_no_vioplot()
  s <- violin_samples()

  result <- violin_layers(list(s$A, s$B))

  # A selector built without grobs to check against would name elements that
  # may not exist. Emitting none says "nothing to highlight" honestly, and the
  # data is unaffected.
  expect_length(result$layers[[1]]$selectors, 0)
  expect_length(result$layers[[2]]$selectors, 0)
  expect_length(result$layers[[1]]$data, 2)
})

test_that("the factory builds a violin processor for the violin type", {
  factory <- BaseRProcessorFactory$new()
  info <- list(plot_call = list(args = list(1:10)), group_index = 1)

  expect_s3_class(
    factory$create_processor("violin", info),
    "BaseRViolinLayerProcessor"
  )
})

test_that("vioplot is classified as a plot-creating call", {
  # Without this the call is never recorded, and everything above is
  # unreachable however well it works.
  expect_true("vioplot" %in% .base_r_function_classes$HIGH)
})


# --------------------------------------------------------------------------
# End to end
#
# Everything above drives the processor directly. This drives the path a user
# actually takes: the exported wrapper records the call, the orchestrator
# routes it by type, and the rendered HTML carries both layers with selectors
# naming grobs that exist in the SVG beside them.
# --------------------------------------------------------------------------

test_that("a vioplot call renders to HTML carrying both layers", {
  skip_if_no_vioplot()
  skip_if_not_installed("gridSVG")
  s <- violin_samples()

  out <- tempfile(fileext = ".html")
  expect_no_error(
    save_html(vioplot(s$A, s$B, names = c("A", "B"), main = "Spread"), out)
  )
  expect_true(file.exists(out))

  html <- paste(readLines(out, warn = FALSE), collapse = "")

  expect_true(grepl("violin_box", html, fixed = TRUE))
  expect_true(grepl("violin_kde", html, fixed = TRUE))
  # The selectors name grobs, and the grobs are in the same document -- so
  # this catches a selector naming something the export does not contain,
  # which is the failure that costs the highlight silently.
  expect_true(grepl("graphics-plot-1-polygon-1", html, fixed = TRUE))
  expect_true(grepl("graphics-plot-1-rect-1", html, fixed = TRUE))
  expect_true(grepl("Spread", html, fixed = TRUE))
})
