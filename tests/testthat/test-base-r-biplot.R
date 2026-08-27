# `biplot()` drew two things and nothing read either (#262)
#
# It is recorded -- `save_html()` succeeds rather than reporting "No Base R
# plots detected" -- but `detect_layer_type()` had no branch for it, so it
# fell through to `unknown` and the chart came out as a static image with
# "Plot contains unsupported elements".
#
# It is the last of the twelve #262 found, and the one that took a design
# decision rather than only a measurement.
#
# **Why a grid.** `pairs()`, `lag.plot()` and `termplot()` are read as grids
# because they draw panels side by side. A biplot draws its two halves *on
# top of each other* -- but against two different pairs of axes, which is the
# whole trick of the chart. Measured, the scores run -1.716..2.199 on PC1
# while the loadings run -0.962..-0.012, so announcing both against one axis
# pair would misstate every loading. A cell each is the only way the grammar
# can say "these have separate scales".
#
# **Why labels.** Both `plot.xy` calls are `type = "n"`: biplot draws no
# points whatever. Every mark is a text label or an arrow, and the export
# gives one addressable child per label on each panel. The arrows are not
# emitted separately -- an arrow and its label name the same variable and sit
# in the same place.

biplot_grid <- function(draw) {
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
cell_layer <- function(grid, row, col) {
  layers <- grid[[row]][[col]]$layers
  if (!length(layers)) NULL else layers[[1]]
}

labels_of <- function(layer) {
  vapply(layer$data, function(point) point$label, character(1))
}
xs_of <- function(layer) vapply(layer$data, function(point) point$x, numeric(1))
ys_of <- function(layer) vapply(layer$data, function(point) point$y, numeric(1))

#' Ten observations of four named variables
READINGS <- local({
  set.seed(5)
  matrix(
    stats::rnorm(40), nrow = 10,
    dimnames = list(paste0("r", 1:10), c("v1", "v2", "v3", "v4"))
  )
})


test_that("a biplot reads as two panels rather than as nothing", {
  # The reproduction: before this, no layer at all, so the figure fell back
  # to a picture.
  grid <- biplot_grid(function() biplot(stats::prcomp(READINGS)))

  testthat::expect_length(grid, 1)
  testthat::expect_length(grid[[1]], 2)
  testthat::expect_equal(cell_layer(grid, 1, 1)$type, "point")
  testthat::expect_equal(cell_layer(grid, 1, 2)$type, "point")
})


test_that("the call routes to the processor that reads a fitted model", {
  # The name the adapter types it as and the name the factory answers to have
  # to be the same string, and the registry has to list it (#200, #214).
  adapter <- BaseRAdapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "biplot", args = list())),
    "biplot"
  )

  factory <- BaseRProcessorFactory$new()
  testthat::expect_true("biplot" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("biplot", list(plot_call = list(args = list()))),
    "BaseRBiplotLayerProcessor"
  )
})


test_that("the observations and the variables get a cell each", {
  # The whole reason this declares a grid: the two halves have different
  # scales, so one axis pair cannot carry both.
  grid <- biplot_grid(function() biplot(stats::prcomp(READINGS)))

  testthat::expect_length(cell_layer(grid, 1, 1)$data, 10)
  testthat::expect_length(cell_layer(grid, 1, 2)$data, 4)
})


test_that("the scores are the model's, not the drawing's", {
  # `biplot()` divides the scores by `sdev * sqrt(n)` so both halves fit one
  # page, so the coordinates on the page are neither half's own scale.
  # Announcing those would give a reader numbers that mean nothing outside
  # this picture.
  fit <- stats::prcomp(READINGS)
  layer <- cell_layer(biplot_grid(function() biplot(fit)), 1, 1)

  testthat::expect_equal(xs_of(layer), unname(fit$x[, 1]))
  testthat::expect_equal(ys_of(layer), unname(fit$x[, 2]))
})


test_that("the loadings are the model's, not the drawing's", {
  fit <- stats::prcomp(READINGS)
  layer <- cell_layer(biplot_grid(function() biplot(fit)), 1, 2)

  testthat::expect_equal(xs_of(layer), unname(fit$rotation[, 1]))
  testthat::expect_equal(ys_of(layer), unname(fit$rotation[, 2]))
})


test_that("every point says what it is", {
  # A biplot draws no symbols at all -- both `plot.xy` calls are
  # `type = "n"`, and the marks are the labels. Identity is the payload
  # here, not a decoration: "PC1 is 0.05" tells a reader nothing without
  # "this is r1".
  grid <- biplot_grid(function() biplot(stats::prcomp(READINGS)))

  testthat::expect_equal(labels_of(cell_layer(grid, 1, 1)), rownames(READINGS))
  testthat::expect_equal(labels_of(cell_layer(grid, 1, 2)), colnames(READINGS))
})


test_that("the axes are named for the components the object carries", {
  # Read off the fitted object's own column names rather than written here,
  # so `prcomp` and `princomp` each get the spelling they use.
  grid <- biplot_grid(function() biplot(stats::prcomp(READINGS)))
  layer <- cell_layer(grid, 1, 1)

  testthat::expect_equal(layer$axes$x$label, "PC1")
  testthat::expect_equal(layer$axes$y$label, "PC2")
})


test_that("a princomp fit is read the way it names itself", {
  # `biplot` is generic: `biplot.prcomp` reads `x`/`rotation` while
  # `biplot.princomp` reads `scores`/`loadings`, and the components are
  # called `Comp.1` rather than `PC1`.
  fit <- stats::princomp(READINGS)
  grid <- biplot_grid(function() biplot(fit))

  scores <- cell_layer(grid, 1, 1)
  testthat::expect_equal(scores$axes$x$label, "Comp.1")
  testthat::expect_equal(labels_of(scores), rownames(READINGS))
  testthat::expect_equal(xs_of(scores), unname(fit$scores[, 1]))

  loadings <- cell_layer(grid, 1, 2)
  testthat::expect_length(loadings$data, 4)
  testthat::expect_equal(labels_of(loadings), colnames(READINGS))
})


test_that("each panel is outlined by the labels it drew", {
  # Measured against a real export: both panels write their marks as a
  # `text` grob with one addressable child per datum, in data order -- the
  # shape `lag.plot()`'s labelled panels already established.
  grid <- biplot_grid(function() biplot(stats::prcomp(READINGS)))

  testthat::expect_equal(
    cell_layer(grid, 1, 1)$selectors,
    list("g#graphics-plot-1-text-1\\.1 > g")
  )
  testthat::expect_equal(
    cell_layer(grid, 1, 2)$selectors,
    list("g#graphics-plot-2-text-1\\.1 > g")
  )
})


test_that("an unnamed matrix is announced by position rather than not at all", {
  # There is nothing else a point could be called, and identity is what this
  # chart is for.
  plain <- matrix(stats::rnorm(20), nrow = 5)
  grid <- biplot_grid(function() biplot(stats::prcomp(plain)))

  testthat::expect_equal(labels_of(cell_layer(grid, 1, 1)), as.character(1:5))
})


test_that("an object that is not a fitted model is declined", {
  # The arguments of a call that stopped are recorded all the same, so the
  # processor is asked about calls that drew nothing.
  result <- BaseRBiplotLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(plot_call = list(args = list(1:10)))
  )

  testthat::expect_null(result)
})


test_that("a call with no argument at all is declined", {
  testthat::expect_null(
    BaseRBiplotLayerProcessor$new(NULL)$process(
      NULL, NULL,
      layer_info = list(plot_call = list(args = list()))
    )
  )
})


test_that("a fit with only one component is declined rather than halved", {
  # `biplot()` draws `choices = 1:2`; with one component there is no second
  # axis, and inventing one would announce a coordinate the fit does not
  # have.
  result <- BaseRBiplotLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(plot_call = list(args = list(
      list(x = matrix(1:4, ncol = 1), rotation = matrix(1:4, ncol = 1))
    )))
  )

  testthat::expect_null(result)
})
