# Recorded arguments are read from the slot they were written in
#
# Defects the release-notes audit measured (#294) in readers that assumed
# the first recorded argument was the data, or that a call's own defaults
# would survive a replay through `do.call()`.

leftover_figure <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)

  draw()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)
  list(
    fallback = orchestrator$should_fallback(),
    subplots = orchestrator$generate_maidr_data()$subplots
  )
}

first_layer <- function(figure, panel = 1L) {
  figure$subplots[[1]][[panel]]$layers[[1]]
}

test_that("a barplot with height named after another argument is still a bar chart", {
  counts <- matrix(1:6, nrow = 2, dimnames = list(c("a", "b"), c("x", "y", "z")))
  figure <- leftover_figure(function() {
    barplot(beside = TRUE, height = counts, legend.text = TRUE)
  })
  layer <- first_layer(figure)

  expect_false(figure$fallback)
  expect_identical(layer$type, "dodged_bar")
  expect_length(layer$data, 2L)
  expect_identical(
    vapply(layer$data[[1]], function(point) point$y, numeric(1)),
    c(1, 3, 5)
  )
})

test_that("recorded_barplot_height reads the named slot before the first positional", {
  expect_identical(maidr:::recorded_barplot_height(list(beside = TRUE, height = 1:3)), 1:3)
  expect_identical(maidr:::recorded_barplot_height(list(1:3, beside = TRUE)), 1:3)
  expect_null(maidr:::recorded_barplot_height(list(beside = TRUE)))

  args <- maidr:::set_recorded_barplot_height(list(beside = TRUE, height = 1:3), 3:1)
  expect_identical(args$height, 3:1)
  args <- maidr:::set_recorded_barplot_height(list(1:3, beside = TRUE), 3:1)
  expect_identical(args[[1]], 3:1)
})

test_that("a word cloud given its words and counts by position reads them", {
  testthat::skip_if_not_installed("wordcloud")

  set.seed(1)
  figure <- leftover_figure(function() {
    wordcloud(c("alpha", "beta", "gamma"), c(10, 5, 4))
  })
  layer <- first_layer(figure)

  expect_identical(layer$type, "word_cloud")
  expect_identical(
    vapply(layer$data, function(term) term$x, character(1)),
    c("alpha", "beta", "gamma")
  )
})

test_that("abline runs across the axis plot.default() set up", {
  # `plot.default()` extends the data range by 4 % each way, and that is
  # the extent `abline()` is clipped to; an explicit `xlim` replaces the
  # data as the range being extended.
  line_x <- function(figure) {
    vapply(figure$subplots[[1]][[1]]$layers[[2]]$data[[1]], function(p) p$x, numeric(1))
  }

  plain <- leftover_figure(function() {
    plot(c(10, 20, 30), c(1, 2, 3))
    abline(0, 0.1)
  })
  expect_equal(line_x(plain), grDevices::extendrange(c(10, 30), f = 0.04))

  limited <- leftover_figure(function() {
    plot(c(10, 20, 30), c(1, 2, 3), xlim = c(0, 100))
    abline(0, 0.1)
  })
  expect_equal(line_x(limited), grDevices::extendrange(c(0, 100), f = 0.04))
})

test_that("a periodogram in a second panel is outlined by that panel's grob", {
  series <- stats::ts(sin(seq(0, 20, length.out = 200)), frequency = 12)
  figure <- leftover_figure(function() {
    par(mfrow = c(1, 2))
    spectrum(series)
    cpgram(series)
  })

  expect_false(figure$fallback)
  expect_identical(
    first_layer(figure, 1L)$selectors,
    list("g#graphics-plot-1-lines-1\\.1")
  )
  expect_identical(
    first_layer(figure, 2L)$selectors,
    list("g#graphics-plot-2-step-1\\.1")
  )
})

test_that("the static picture of a multi-panel figure keeps its grid", {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)
  par(mfrow = c(1, 2))
  plot(1:3)
  plot(3:1)

  picture <- tempfile(fileext = ".png")
  grDevices::png(picture)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)
  maidr:::replay_base_r_plot(device_id)

  # The replayed `par()` set the grid, and the second `plot()` landed in
  # its second cell rather than over the first.
  expect_identical(graphics::par("mfrow"), c(1L, 2L))
  expect_identical(graphics::par("mfg")[1:2], c(1L, 2L))
})

test_that("spineplot(x, y) names its axes after the variables, not their values", {
  level <- factor(rep(c("lo", "mid", "hi"), c(20, 15, 10)), levels = c("lo", "mid", "hi"))
  answer <- factor(rep(c("no", "yes"), length.out = 45))

  bare <- first_layer(leftover_figure(function() spineplot(level, answer)))
  expect_identical(bare$axes$x$label, "level")
  expect_identical(bare$axes$z$label, "answer")

  # A written title wins, as it does in the drawing.
  titled <- first_layer(leftover_figure(function() {
    spineplot(level, answer, xlab = "Level")
  }))
  expect_identical(titled$axes$x$label, "Level")
  expect_identical(titled$axes$z$label, "answer")
})

test_that("spineplot_written_axis_names leaves a table or a formula alone", {
  args <- list(table(a = c(1, 1, 2), b = c("x", "y", "x")))
  expect_identical(
    maidr:::spineplot_written_axis_names(args, "spineplot(table(a, b))"),
    args
  )
  args <- list(y ~ x, data = data.frame(x = 1:2, y = c("a", "b")))
  expect_identical(
    maidr:::spineplot_written_axis_names(args, "spineplot(y ~ x, data = d)"),
    args
  )
  expect_identical(
    maidr:::spineplot_written_axis_names(list(1:3, 4:6), NA_character_),
    list(1:3, 4:6)
  )
})
