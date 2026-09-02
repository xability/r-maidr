# `lag.plot()` drew a grid of scatters that nothing read (#262)
#
# It is recorded -- `save_html()` succeeds rather than reporting "No Base R
# plots detected", which #262 fixed -- but `detect_layer_type()` had no branch
# for it, so it fell through to `unknown` and the chart came out as a static
# image with "Plot contains unsupported elements".
#
# What it draws is a grid, which is why it takes the `multi_panel` shape
# `pairs()` introduced rather than answering with one layer: `lag.plot()` sets
# its own `par(mfrow)` and restores it, so nothing lands in the device's
# layout calls and the grid has to come from the reading.
#
# Everything asserted here was measured first, by tracing `graphics::plot.xy`
# through real calls and by echoing them through `gridGraphics::grid.echo()`.
# The pairing is the part worth measuring: `plot(lag(X, k), X)` reads as
# "X against a lagged copy", and it is easy to assume that puts the *earlier*
# reading across. It does not -- `lag()` shifts the time base back, so the
# later reading goes across and the earlier one up.

#' The subplot grid a base R drawing produces
#'
#' `base_r_layers()` answers with the first cell's layers, which is the whole
#' reading for every chart but the two that declare their own grid.
lag_grid <- function(draw) {
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
lag_cell <- function(grid, row, col) {
  layers <- grid[[row]][[col]]$layers
  if (!length(layers)) NULL else layers[[1]]
}

#' A cell's points as `(x, y)` pairs
lag_points <- function(layer) {
  lapply(layer$data, function(point) c(point$x, point$y))
}

#' Twelve readings that rise and fall, so a value names its own position
SERIES <- c(5, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14, 17)


test_that("a lag plot reads as a grid rather than as nothing", {
  # The reproduction: before this, no layers anywhere, so the whole figure
  # fell back to a picture.
  grid <- lag_grid(function() lag.plot(SERIES, lags = 2, do.lines = FALSE))

  testthat::expect_length(grid, 2)
  testthat::expect_length(grid[[1]], 1)
  testthat::expect_equal(lag_cell(grid, 1, 1)$type, "point")
  testthat::expect_equal(lag_cell(grid, 2, 1)$type, "point")
})


test_that("the call routes to the processor that reads the grid", {
  # The name the adapter types it as and the name the factory answers to have
  # to be the same string, and the registry has to list it: a type the factory
  # builds but does not claim is refused before the processor is reached
  # (#200, #214).
  adapter <- BaseRAdapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(
      list(function_name = "lag.plot", args = list())
    ),
    "lag"
  )

  factory <- BaseRProcessorFactory$new()
  testthat::expect_true("lag" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("lag", list(plot_call = list(args = list()))),
    "BaseRLagLayerProcessor"
  )
})


test_that("a panel puts the later reading across and the earlier one up", {
  # Measured by tracing `plot.xy`: the lag-1 panel is handed
  # x = 7, 6, 9, ... and y = 5, 7, 6, ..., which is `X[t + 1]` against `X[t]`.
  # The other way round is the assumption the docstring warns about, and it
  # produces a chart that still looks plausible.
  grid <- lag_grid(function() lag.plot(SERIES, lags = 2, do.lines = FALSE))

  first <- lag_points(lag_cell(grid, 1, 1))
  testthat::expect_length(first, 11)
  testthat::expect_equal(first[[1]], c(7, 5))
  testthat::expect_equal(first[[2]], c(6, 7))
  testthat::expect_equal(first[[11]], c(17, 14))

  second <- lag_points(lag_cell(grid, 2, 1))
  testthat::expect_length(second, 10)
  testthat::expect_equal(second[[1]], c(6, 5))
  testthat::expect_equal(second[[10]], c(17, 15))
})


test_that("a zero or negative lag pairs from the same expression", {
  # `set.lags` accepts them and the drawing handles them without a special
  # case, so the reading does too: measured, lag 0 is the series against
  # itself and lag -1 puts the *earlier* reading across.
  grid <- lag_grid(function() {
    lag.plot(SERIES, set.lags = c(-1, 0), do.lines = FALSE)
  })

  behind <- lag_points(lag_cell(grid, 1, 1))
  testthat::expect_equal(behind[[1]], c(5, 7))
  testthat::expect_equal(behind[[11]], c(14, 17))

  same <- lag_points(lag_cell(grid, 2, 1))
  testthat::expect_length(same, 12)
  testthat::expect_equal(same[[1]], c(5, 5))
  testthat::expect_equal(same[[12]], c(17, 17))
})


test_that("a matrix draws a panel per column and lag, series outermost", {
  # Measured against a `grid.echo()` export: a two-column matrix at `lags = 2`
  # writes four panels for `(a,1) (a,2) (b,1) (b,2)`, filled row by row into
  # the 2x2 grid `n2mfrow(4)` gives. So a column owns a row of the reading.
  columns <- cbind(a = SERIES, b = rev(SERIES))
  grid <- lag_grid(function() lag.plot(columns, lags = 2, do.lines = FALSE))

  testthat::expect_length(grid, 2)
  testthat::expect_length(grid[[1]], 2)
  testthat::expect_equal(lag_points(lag_cell(grid, 1, 1))[[1]], c(7, 5))
  testthat::expect_equal(lag_points(lag_cell(grid, 2, 1))[[1]], c(14, 17))
})


test_that("each panel is named by its lag and by the series it plots", {
  # `xlab = paste("lag", ll)` and `ylab = nam`, which is the column's name for
  # a matrix and the deparsed argument for a vector. The deparsed one survives
  # only in `call_expr`: the wrapper records evaluated values, so the name the
  # caller wrote is gone from the arguments by the time this reads them.
  columns <- cbind(a = SERIES, b = rev(SERIES))
  named <- lag_grid(function() lag.plot(columns, lags = 2, do.lines = FALSE))

  testthat::expect_equal(lag_cell(named, 1, 1)$axes$x$label, "lag 1")
  testthat::expect_equal(lag_cell(named, 1, 2)$axes$x$label, "lag 2")
  testthat::expect_equal(lag_cell(named, 1, 1)$axes$y$label, "a")
  testthat::expect_equal(lag_cell(named, 2, 1)$axes$y$label, "b")

  readings <- SERIES
  vector_form <- lag_grid(function() lag.plot(readings, do.lines = FALSE))
  testthat::expect_equal(lag_cell(vector_form, 1, 1)$axes$y$label, "readings")
})


test_that("an unnamed matrix is announced by its lag alone", {
  # `lag.plot()` takes `dimnames(x)[[2L]][i]` for a matrix, which is NULL when
  # the columns were never named -- so the panel carries no y label either.
  # Inventing one would name a series the chart does not.
  grid <- lag_grid(function() {
    lag.plot(matrix(c(SERIES, rev(SERIES)), ncol = 2), lags = 1, do.lines = FALSE)
  })

  testthat::expect_equal(lag_cell(grid, 1, 1)$axes$x$label, "lag 1")
  testthat::expect_null(lag_cell(grid, 1, 1)$axes$y$label)
})


test_that("a panel drawn with points is outlined, one selector per panel", {
  # Every panel writes its own `points` grob and `find_graphics_plot_grob()`
  # answers with the first, so the selectors are built from the panel number
  # rather than searched for -- a search would give every panel the first
  # panel's marks.
  grid <- lag_grid(function() lag.plot(SERIES, lags = 2, do.lines = FALSE))

  testthat::expect_equal(
    lag_cell(grid, 1, 1)$selectors,
    list("g#graphics-plot-1-points-1\\.1 > use")
  )
  testthat::expect_equal(
    lag_cell(grid, 2, 1)$selectors,
    list("g#graphics-plot-2-points-1\\.1 > use")
  )
})


test_that("a labelled panel outlines its labels instead of its symbols", {
  # `labels` defaults to `do.lines`, which defaults to `n <= 150`, so a short
  # series is drawn as the time index at each pair -- measured, `text` and
  # `brokenline` grobs and no `points` at all. The labels are one group per
  # pair in the export, so they are what a reader on that pair is shown.
  grid <- lag_grid(function() lag.plot(SERIES, lags = 2))

  testthat::expect_equal(
    lag_cell(grid, 1, 1)$selectors,
    list("g#graphics-plot-1-text-1\\.1 > g")
  )
  testthat::expect_equal(
    lag_cell(grid, 2, 1)$selectors,
    list("g#graphics-plot-2-text-1\\.1 > g")
  )
  # The reading itself is unaffected: the same pairs, announced the same way.
  testthat::expect_equal(lag_points(lag_cell(grid, 1, 1))[[1]], c(7, 5))
})


test_that("labels alone decides the mark, and do.lines only adds the line", {
  # The two are read separately because the default ties them together and
  # the drawing does not. Measured, all four combinations: `labels` false
  # gives `points`, true gives `text`, whatever `do.lines` says.
  joined <- lag_grid(function() {
    lag.plot(SERIES, lags = 1, do.lines = TRUE, labels = FALSE)
  })
  testthat::expect_equal(
    lag_cell(joined, 1, 1)$selectors,
    list("g#graphics-plot-1-points-1\\.1 > use")
  )

  bare <- lag_grid(function() {
    lag.plot(SERIES, lags = 1, do.lines = FALSE, labels = TRUE)
  })
  testthat::expect_equal(
    lag_cell(bare, 1, 1)$selectors,
    list("g#graphics-plot-1-text-1\\.1 > g")
  )
})


test_that("a long series takes the symbol marks without being asked", {
  # The same default from the other side: past 150 readings `do.lines` is
  # false, so `labels` is too and the panels are drawn with symbols.
  long <- as.numeric(seq_len(200))
  grid <- lag_grid(function() lag.plot(long, lags = 1))

  testthat::expect_equal(
    lag_cell(grid, 1, 1)$selectors,
    list("g#graphics-plot-1-points-1\\.1 > use")
  )
})


test_that("the caller's own layout is the grid the panels are placed in", {
  # `lag.plot()` takes `layout` when the caller writes one and
  # `n2mfrow(nser * lags)` otherwise. Reading the default where the caller
  # asked for something else would put every panel in the wrong cell.
  grid <- lag_grid(function() {
    lag.plot(SERIES, lags = 2, layout = c(1, 2), do.lines = FALSE)
  })

  testthat::expect_length(grid, 1)
  testthat::expect_length(grid[[1]], 2)
  testthat::expect_equal(lag_points(lag_cell(grid, 1, 1))[[1]], c(7, 5))
  testthat::expect_equal(lag_points(lag_cell(grid, 1, 2))[[1]], c(6, 5))
})


test_that("a lag with no pair to make leaves its cell empty", {
  # Measured: a lag as long as the series makes `ts.intersect()` warn
  # "non-intersecting series" and the panel comes out with its axes and no
  # marks. A layer with no data would be a chart the reader could enter and
  # find empty, so the cell is left as one instead.
  grid <- suppressWarnings(lag_grid(function() {
    lag.plot(c(1, 2, 3), set.lags = c(1, 9), do.lines = FALSE)
  }))

  testthat::expect_equal(lag_points(lag_cell(grid, 1, 1))[[1]], c(2, 1))
  testthat::expect_null(lag_cell(grid, 2, 1))
})


test_that("one reading against itself is a panel, because it is drawn", {
  # `set.lags = 0` pairs a series with itself, so even a single reading makes
  # a mark -- measured, `plot.xy` is handed `x = 5, y = 5`. Requiring two
  # readings before the series is read at all would decline a chart that is
  # on the page.
  grid <- lag_grid(function() lag.plot(5, set.lags = 0, do.lines = FALSE))

  testthat::expect_equal(lag_points(lag_cell(grid, 1, 1)), list(c(5, 5)))
})


test_that("a series of something other than numbers is declined", {
  # Driven at the processor, because the drawing stops before it finishes:
  # measured, a character series warns "NAs introduced by coercion" and then
  # `plot.window()` refuses the resulting `xlim`. The arguments are recorded
  # anyway, and coercing them would announce a grid of `NA`s that was never
  # on the page.
  result <- BaseRLagLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(
      call_expr = "lag.plot(letters[1:3])",
      plot_call = list(args = list(c("a", "b", "c"), do.lines = FALSE))
    )
  )

  testthat::expect_null(result)
})


test_that("a series with a missing reading never reaches the drawing", {
  # Recorded here because it is why nothing in the reading filters for `NA`:
  # the panel takes `xlim` from `range(X)`, so one missing value makes the
  # limits `NA` and `plot.window()` stops before a mark is drawn. A reading
  # that dropped the pair would be describing a chart that does not exist.
  testthat::expect_error(
    lag.plot(c(1, NA, 3, 4), lags = 1, do.lines = FALSE),
    "finite"
  )
})


test_that("the caller's spelling of x is read either way round", {
  # The name a vector call carries comes from the source text, because the
  # wrapper records evaluated values. `x` is the first formal with nothing
  # ahead of it, so a named `x` and a bare first argument are the two
  # spellings there are -- and a named argument written first must not be
  # mistaken for the series.
  readings <- SERIES

  named <- lag_grid(function() lag.plot(x = readings, do.lines = FALSE))
  testthat::expect_equal(lag_cell(named, 1, 1)$axes$y$label, "readings")

  after <- lag_grid(function() lag.plot(lags = 1, readings, do.lines = FALSE))
  testthat::expect_equal(lag_cell(after, 1, 1)$axes$y$label, "readings")
})
