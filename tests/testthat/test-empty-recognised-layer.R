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

# `emitted_layers()`, `rendered()` and `fell_back()` live in
# `helper-render.R`, shared with #227's and #230's tests.

observations <- function() {
  data.frame(x = 1:10, y = (1:10)^1.2)
}


test_that("a recognised layer that drew nothing is not emitted", {
  skip_if_no_render()

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
  skip_if_no_render()

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
  testthat::expect_length(both, 1L)
  testthat::expect_match(both, "^point\\(10\\) smooth\\(1x[1-9]")
})


test_that("a plot whose only layer is empty falls back to an image", {
  skip_if_no_render()

  # "skip" rather than a fourth answer, so the #176 guard sees it: a chart
  # announcing itself as interactive with nothing in it is worse than an
  # image, because an image at least says what it is.
  d <- observations()
  plot <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point(data = d[0, ])

  testthat::expect_equal(emitted_layers(plot), "image")
})


test_that("a patchwork leaf's empty layer is skipped too", {
  skip_if_no_render()
  testthat::skip_if_not_installed("patchwork")

  # A leaf is classified by `ggplot2_patchwork_utils.R`, which never calls
  # the orchestrator's `detect_layers()`, so the rule had to be asked there
  # as well -- otherwise every composed chart kept ghosting while every plain
  # one stopped. `layers_that_drew_nothing()` is the one place it is written.
  d <- observations()
  left <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_point(data = d[0, ])
  right <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  testthat::expect_equal(
    emitted_layers(patchwork::wrap_plots(left, right)),
    c("point(10)", "point(10)")
  )
})


test_that("a faceted plot's empty layer is skipped too", {
  skip_if_no_render()

  # Faceting goes through `process_faceted_plot()`, which does call
  # `detect_layers()` -- so this holds for free, and holds it in place.
  d <- observations()
  faceted <- rbind(cbind(d, panel = "L"), cbind(d, panel = "R"))

  testthat::expect_equal(
    emitted_layers(
      ggplot2::ggplot(faceted, ggplot2::aes(x = x, y = y)) +
        ggplot2::geom_point() +
        ggplot2::geom_point(data = d[0, ]) +
        ggplot2::facet_wrap(~panel)
    ),
    c("point(10)", "point(10)")
  )
})


test_that("the emptiness question is not asked of the classifier", {
  skip_if_no_render()

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
