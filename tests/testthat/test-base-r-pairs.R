# `pairs()` draws a scatterplot matrix and was read as nothing (#272).
#
# It is HIGH, so the call is recorded, but no processor read it and the figure
# took the static-image path. The four "exact home" readings #251 named end
# here; this is the one it called "a much bigger piece than the other three",
# and the reason is structural rather than about the data.
#
# **The grid cannot come from the recording.** Measured, `pairs()` sets its own
# `par(mfrow)` internally and restores it, so `get_layout_calls()` answers zero
# and `detect_panel_configuration()` sees a single panel. Every other base R
# processor answers with a layer, or several layers in one cell; this one has
# to answer with a *figure's* shape.
#
# **The panels are numbered column-major.** Measured against a real
# `grid.echo()` export of three columns, gridGraphics writes nine
# `graphics-plot-N` groups -- one per cell, diagonal included -- and pairing
# them with a `panel` that recorded what it was handed gives
# `k = (col - 1) * n + row`, with the panel at `(row, col)` plotting column
# `col` horizontally against column `row` vertically. The diagonals (1, 5, 9)
# draw the variable's name and no marks.
#
# Every emitted selector was then resolved in Chromium against a rendering of
# a three-column matrix: six panels, three elements each, eighteen `<use>`
# elements on the page.

#' The subplot grid a base R drawing produces
#'
#' `base_r_layers()` answers with the first cell's layers, which is the whole
#' reading for every chart but this one.
pairs_grid <- function(draw) {
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

#' One cell's only layer, or NULL when the cell is empty
cell_layer <- function(grid, row, col) {
  layers <- grid[[row]][[col]]$layers
  if (!length(layers)) NULL else layers[[1]]
}

#' A cell's points as `(x, y)` pairs
cell_points <- function(layer) {
  lapply(layer$data, function(point) c(point$x, point$y))
}

#' Three columns whose values say which is which at a glance
THREE <- data.frame(a = c(1, 2, 3), b = c(10, 20, 30), c = c(100, 200, 300))


test_that("a scatterplot matrix reads as a grid rather than as nothing", {
  # The reproduction: before this, one cell holding no layers at all, so the
  # whole figure fell back to a picture.
  grid <- pairs_grid(function() pairs(THREE))

  testthat::expect_length(grid, 3)
  testthat::expect_length(grid[[1]], 3)
  drawn <- sum(vapply(
    grid, function(row) sum(vapply(row, function(cell) length(cell$layers), 0)), 0
  ))
  testthat::expect_equal(drawn, 6)
})


test_that("each panel plots the column across against the column down", {
  # The mapping measured off the drawing: the panel at `(row, col)` takes its
  # x from column `col` and its y from column `row`. Getting this the other
  # way round transposes the whole matrix and every panel still looks
  # plausible, which is why it is asserted per cell rather than in aggregate.
  grid <- pairs_grid(function() pairs(THREE))

  testthat::expect_equal(cell_points(cell_layer(grid, 2, 1)), list(
    c(1, 10), c(2, 20), c(3, 30)
  ))
  testthat::expect_equal(cell_points(cell_layer(grid, 1, 2)), list(
    c(10, 1), c(20, 2), c(30, 3)
  ))
  testthat::expect_equal(cell_points(cell_layer(grid, 3, 1)), list(
    c(1, 100), c(2, 200), c(3, 300)
  ))
})


test_that("each panel names its own two columns", {
  grid <- pairs_grid(function() pairs(THREE))
  axes <- cell_layer(grid, 3, 2)$axes

  testthat::expect_equal(axes$x$label, "b")
  testthat::expect_equal(axes$y$label, "c")
})


test_that("the diagonal has no layer", {
  # `pairs()`'s default `diag.panel` draws nothing -- the cell carries the
  # variable's name and no marks -- so the cell is empty rather than carrying
  # a distribution the chart never drew.
  grid <- pairs_grid(function() pairs(THREE))

  for (i in 1:3) {
    testthat::expect_length(grid[[i]][[i]]$layers, 0)
  }
})


test_that("a panel addresses the marks it was drawn into", {
  # Built rather than searched for: `find_graphics_plot_grob()` answers with
  # the first `points` grob of the plot, and a matrix draws one per cell, so a
  # search would give every panel the first cell's marks.
  #
  # `k = (col - 1) * n + row`, measured against the export and then resolved
  # in Chromium -- three elements per panel, one per observation.
  grid <- pairs_grid(function() pairs(THREE))

  testthat::expect_equal(
    cell_layer(grid, 2, 1)$selectors[[1]],
    "g#graphics-plot-2-points-1\\.1 > use"
  )
  testthat::expect_equal(
    cell_layer(grid, 1, 2)$selectors[[1]],
    "g#graphics-plot-4-points-1\\.1 > use"
  )
  testthat::expect_equal(
    cell_layer(grid, 2, 3)$selectors[[1]],
    "g#graphics-plot-8-points-1\\.1 > use"
  )
})


test_that("two columns make a two by two grid", {
  # One column is not a case to guard: `pairs()` itself stops with "only one
  # column in the argument to 'pairs'".
  grid <- pairs_grid(function() pairs(THREE[, c("a", "b")]))

  testthat::expect_length(grid, 2)
  testthat::expect_length(grid[[1]], 2)
  testthat::expect_equal(cell_points(cell_layer(grid, 2, 1)), list(
    c(1, 10), c(2, 20), c(3, 30)
  ))
})


test_that("a matrix reads like a data frame, and an unnamed one is labelled the way it is drawn", {
  # Measured: an unnamed matrix's diagonals read "var 1" and "var 2", which is
  # what `pairs.default` writes when the columns have no names.
  named <- pairs_grid(function() pairs(as.matrix(THREE[, c("a", "b")])))
  unnamed <- pairs_grid(function() {
    pairs(matrix(c(1, 2, 3, 10, 20, 30), ncol = 2))
  })

  testthat::expect_equal(cell_layer(named, 2, 1)$axes$x$label, "a")
  testthat::expect_equal(cell_layer(unnamed, 2, 1)$axes$x$label, "var 1")
  testthat::expect_equal(cell_layer(unnamed, 2, 1)$axes$y$label, "var 2")
})


test_that("a formula call reads the frame the drawing was made from", {
  # `pairs(~ a + b)` records the formula, and a formula is a reference rather
  # than a value -- so it is resolved from the frame the recording kept (#254)
  # rather than from whatever the names hold at render time.
  scope <- new.env(parent = baseenv())
  scope$a <- c(1, 2, 3)
  scope$b <- c(10, 20, 30)
  drawn <- eval(quote(~ a + b), scope)

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

  pairs(drawn)
  assign("a", c(99, 98, 97), envir = scope)
  grid <- maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()$subplots

  testthat::expect_length(grid, 2)
  testthat::expect_equal(cell_points(cell_layer(grid, 2, 1)), list(
    c(1, 10), c(2, 20), c(3, 30)
  ))
})


test_that("a pair with a missing coordinate is dropped rather than announced", {
  # Measured, `pairs()` hands its panel the raw columns including `NA`, and
  # `points()` draws nothing for that pair -- so announcing it would offer a
  # sample the chart does not draw (#170).
  gappy <- data.frame(a = c(1, NA, 3), b = c(10, 20, 30))
  grid <- pairs_grid(function() pairs(gappy))

  testthat::expect_equal(cell_points(cell_layer(grid, 2, 1)), list(
    c(1, 10), c(3, 30)
  ))
  testthat::expect_equal(cell_points(cell_layer(grid, 1, 2)), list(
    c(10, 1), c(30, 3)
  ))
})


test_that("a matrix beside another chart reads as it did before grids existed", {
  # A call that takes over the device's layout is by construction the whole
  # page, so a grid is read from a single call only. The refused result
  # carries no type and no data; emitted it would become a layer announcing
  # nothing, with the grid's own bookkeeping leaked into the payload beside
  # it -- so it is skipped, and what is left is the reading the figure had
  # before this change.
  grid <- pairs_grid(function() {
    plot(1:3, c(2, 4, 6))
    pairs(THREE[, c("a", "b")])
  })

  testthat::expect_length(grid, 1)
  testthat::expect_length(grid[[1]][[1]]$layers, 1)
  testthat::expect_equal(grid[[1]][[1]]$layers[[1]]$type, "point")
})
