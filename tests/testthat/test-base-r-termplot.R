# `termplot()` drew a row of partial-effect curves that nothing read (#262)
#
# It is recorded -- `save_html()` succeeds rather than reporting "No Base R
# plots detected", which #262 fixed -- but `detect_layer_type()` had no branch
# for it, so it fell through to `unknown` and the chart came out as a static
# image with "Plot contains unsupported elements".
#
# What it draws is one panel per term of a fitted model: the term's
# contribution to the fit against that term's own carrier. So it is read the
# way `pairs()` and `lag.plot()` are, as a figure of subplots rather than as a
# layer -- the orchestrator maps a layer to a cell by its *group*, and one
# recorded call is one group, so without a declared grid every curve would
# land in the same cell.
#
# The part worth asserting hardest is which curves are on the page.
# `termplot()` sets no layout of its own, so the caller's `par(mfrow)` decides
# how many terms share a page and R starts a new one when it runs out of
# cells. Only the last page is exported. A reading that announced every term
# would name curves that were drawn and then covered over.

termplot_grid <- function(draw) {
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
  maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()$subplots
}

#' The single layer in one cell, or NULL where the cell is empty
cell <- function(grid, row, col) {
  layers <- grid[[row]][[col]]$layers
  if (!length(layers)) NULL else layers[[1]]
}

#' Which term each filled cell is announced as being about
carriers_of <- function(grid) {
  found <- character(0)
  for (r in seq_along(grid)) {
    for (c_idx in seq_along(grid[[r]])) {
      layer <- cell(grid, r, c_idx)
      if (!is.null(layer)) found <- c(found, layer$axes$x$label)
    }
  }
  found
}

#' A fit whose terms are told apart by their coefficients
fitted_model <- function(terms = 2) {
  set.seed(1)
  frame <- data.frame(a = rnorm(40), b = rnorm(40), c = rnorm(40))
  frame$y <- 2 * frame$a - 1.5 * frame$b + 0.7 * frame$c + rnorm(40, sd = 0.3)
  formula <- switch(as.character(terms),
    "2" = y ~ a + b,
    "3" = y ~ a + b + c
  )
  stats::lm(formula, data = frame)
}


test_that("a term plot reads as curves rather than as nothing", {
  # The reproduction: before this, no layer at all, so the figure fell back
  # to a picture.
  fit <- fitted_model(2)
  grid <- termplot_grid(function() {
    par(mfrow = c(1, 2))
    termplot(fit)
  })

  testthat::expect_equal(cell(grid, 1, 1)$type, "line")
  testthat::expect_equal(cell(grid, 1, 2)$type, "line")
})


test_that("the call routes to the processor that reads a fitted model", {
  # The name the adapter types it as and the name the factory answers to have
  # to be the same string, and the registry has to list it (#200, #214).
  adapter <- BaseRAdapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "termplot", args = list())),
    "termplot"
  )

  factory <- BaseRProcessorFactory$new()
  testthat::expect_true("termplot" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("termplot", list(plot_call = list(args = list()))),
    "BaseRTermplotLayerProcessor"
  )
})


test_that("each term gets its own cell, in the order it was drawn", {
  # The whole reason this declares a grid: without one, both curves land in
  # the same cell and the second is announced on top of the first.
  fit <- fitted_model(2)
  grid <- termplot_grid(function() {
    par(mfrow = c(1, 2))
    termplot(fit)
  })

  testthat::expect_length(grid, 1)
  testthat::expect_length(grid[[1]], 2)
  testthat::expect_equal(carriers_of(grid), c("a", "b"))
})


test_that("a curve carries the model's contribution, not the drawing's", {
  # The values are `predict(model, type = "terms")` against the carrier from
  # the model frame, sorted by carrier -- which is the order `termplot()`
  # draws them in, and the order a reader walks them in.
  fit <- fitted_model(2)
  grid <- termplot_grid(function() {
    par(mfrow = c(1, 2))
    termplot(fit)
  })
  layer <- cell(grid, 1, 1)

  frame <- stats::model.frame(fit)
  expected_x <- sort(frame$a)
  expected_y <- stats::predict(fit, type = "terms")[, "a"][order(frame$a)]

  testthat::expect_length(layer$data, length(expected_x))
  testthat::expect_equal(
    vapply(layer$data, function(point) point$x, numeric(1)),
    unname(expected_x)
  )
  testthat::expect_equal(
    vapply(layer$data, function(point) point$y, numeric(1)),
    unname(expected_y)
  )
})


test_that("the axes name the term on both sides", {
  # A partial-effect plot has no meaning without them: the y axis is a
  # contribution to the fit, not the response.
  fit <- fitted_model(2)
  grid <- termplot_grid(function() {
    par(mfrow = c(1, 2))
    termplot(fit)
  })

  testthat::expect_equal(cell(grid, 1, 2)$axes$x$label, "b")
  testthat::expect_equal(cell(grid, 1, 2)$axes$y$label, "partial for b")
})


test_that("only the terms on the visible page are announced", {
  # `termplot()` sets no layout, so two terms with no `par(mfrow)` are two
  # pages and only the second survives the export -- measured, the export of
  # that call carries `graphics-plot-1` and nothing else. Announcing both
  # would name a curve that was drawn and then covered over.
  fit <- fitted_model(2)
  grid <- termplot_grid(function() termplot(fit))

  testthat::expect_length(grid, 1)
  testthat::expect_length(grid[[1]], 1)
  testthat::expect_equal(carriers_of(grid), "b")
})


test_that("a page that overflows keeps its tail, not its head", {
  # Three terms into two cells: `a` and `b` fill page one, `c` starts page
  # two, and page two is what is exported. Measured against a real export --
  # `mfrow = c(1, 2)` on a three-term fit writes `graphics-plot-1` alone.
  fit <- fitted_model(3)
  grid <- termplot_grid(function() {
    par(mfrow = c(1, 2))
    termplot(fit)
  })

  testthat::expect_equal(carriers_of(grid), "c")
})


test_that("a grid with room to spare is filled row by row", {
  # Three terms into four cells all fit on one page, so all three are read.
  # The fourth cell stays empty rather than absent -- the orchestrator's own
  # rule, since a bare NULL serialises as `{}` and the frontend cannot parse
  # it.
  fit <- fitted_model(3)
  grid <- termplot_grid(function() {
    par(mfrow = c(2, 2))
    termplot(fit)
  })

  testthat::expect_length(grid, 2)
  testthat::expect_length(grid[[1]], 2)
  testthat::expect_equal(carriers_of(grid), c("a", "b", "c"))
  testthat::expect_null(cell(grid, 2, 2))
})


test_that("each panel is outlined by the curve it drew", {
  # Measured against a real export: `graphics-plot-<panel>-lines-1.1` is a
  # `<g>` in the exported SVG, one per panel, numbered in draw order.
  fit <- fitted_model(2)
  grid <- termplot_grid(function() {
    par(mfrow = c(1, 2))
    termplot(fit)
  })

  testthat::expect_equal(
    cell(grid, 1, 1)$selectors,
    list("g#graphics-plot-1-lines-1\\.1")
  )
  testthat::expect_equal(
    cell(grid, 1, 2)$selectors,
    list("g#graphics-plot-2-lines-1\\.1")
  )
})


test_that("a factor term is left out rather than read as a slope", {
  # `termplot()` draws it as a step over the levels. Read as a line it would
  # announce a slope between levels that have no order, so it is declined and
  # the numeric term beside it is still read.
  set.seed(2)
  frame <- data.frame(
    g = factor(rep(c("lo", "hi"), each = 20)),
    x = rnorm(40)
  )
  frame$y <- as.numeric(frame$g) + 2 * frame$x + rnorm(40, sd = 0.2)
  fit <- stats::lm(y ~ g + x, data = frame)

  grid <- termplot_grid(function() {
    par(mfrow = c(1, 2))
    termplot(fit)
  })

  testthat::expect_equal(carriers_of(grid), "x")
})


test_that("a call with no model to read is declined", {
  # The arguments of a call that stopped are recorded all the same, so the
  # processor is asked about calls that drew nothing.
  result <- BaseRTermplotLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(plot_call = list(args = list()))
  )

  testthat::expect_null(result)
})


test_that("an object that is not a fitted model is declined", {
  # `predict(x, type = "terms")` on it has no answer, and inventing one would
  # announce a curve that was never drawn.
  result <- BaseRTermplotLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(plot_call = list(args = list(1:10)))
  )

  testthat::expect_null(result)
})
