# A base R `mosaicplot()` fell back to a picture (#242).
#
# `mosaicplot` is classified HIGH, so its calls are recorded, but the adapter
# had no branch for it and the factory no processor -- which is the
# documented decline: the figure takes the static-image path (#176). Not a
# wrong reading, but a whole chart unread, and MAIDR has had
# `TraceType.MOSAIC` for exactly this shape.
#
# A mosaic is a two-way contingency table drawn as tiles. What separates it
# from a stacked bar is that the **column widths encode data too**: each
# column's width is that category's share of all observations. A reader given
# only the segment heights has half the table -- the conditional proportions
# without the group sizes they were computed from -- so a category of six
# observations and one of six hundred read identically, and the whole point
# of the chart is that they do not look the same.
#
# Nothing here is inferred from the drawing. `mosaicplot()` is handed the
# table itself, so the recorded call carries every number the trace wants.

# `base_r_layers` and `base_r_layer_types` live in `helper.R` (#241).
mosaic_layers <- base_r_layers
mosaic_types <- base_r_layer_types

# 4 hair colours x 4 eye colours, the textbook example. Column totals
# 56 / 143 / 34 / 46 out of 279.
HAIR_EYE <- HairEyeColor[, , 1]

test_that("a base R mosaic plot is read rather than pictured", {
  testthat::expect_equal(mosaic_types(function() mosaicplot(HAIR_EYE)), "mosaic")
})

test_that("a mosaic is emitted fill-major, the way a stack is", {
  # `MosaicTrace` extends `SegmentedTrace`, which navigates
  # category-then-series and reads `data[[fill]][[category]]`. Getting this
  # transposed would put the eye colours on the category axis.
  layer <- mosaic_layers(function() mosaicplot(HAIR_EYE))[[1]]

  testthat::expect_length(layer$data, ncol(HAIR_EYE))
  testthat::expect_length(layer$data[[1]], nrow(HAIR_EYE))
  testthat::expect_identical(
    vapply(layer$data, function(series) series[[1]]$z, ""),
    colnames(HAIR_EYE)
  )
  testthat::expect_identical(
    vapply(layer$data[[1]], function(cell) cell$x, ""),
    rownames(HAIR_EYE)
  )
})

test_that("a tile's y is its conditional proportion within its column", {
  # The tile's drawn height, and what a stack's value would be. 32 of the 56
  # black-haired people have brown eyes.
  first <- mosaic_layers(function() mosaicplot(HAIR_EYE))[[1]]$data[[1]][[1]]

  testthat::expect_equal(first$y, 32 / 56)
  testthat::expect_equal(first$count, 32)
})

test_that("every cell of a column carries that column's share", {
  # The number the layer exists for. The grammar's unit is the point and a
  # flat list has nowhere else to put it, so `width` travels on each cell --
  # and `MosaicTrace` reads it from the first series that declares one.
  layer <- mosaic_layers(function() mosaicplot(HAIR_EYE))[[1]]

  black <- vapply(layer$data, function(series) series[[1]]$width, 0)
  testthat::expect_equal(black, rep(56 / 279, ncol(HAIR_EYE)))

  widths <- vapply(layer$data[[1]], function(cell) cell$width, 0)
  testthat::expect_equal(widths, unname(rowSums(HAIR_EYE) / sum(HAIR_EYE)))
})

test_that("the counts the chart was drawn from travel with it", {
  # A mosaic is drawn *from* counts, and they are the numbers a reader would
  # quote back. `MosaicPoint.count` is optional precisely because a producer
  # working from proportions does not have them -- this one does.
  layer <- mosaic_layers(function() mosaicplot(HAIR_EYE))[[1]]

  counts <- vapply(layer$data[[2]], function(cell) cell$count, 0)
  testthat::expect_equal(counts, unname(HAIR_EYE[, 2]))
})

test_that("a column that observed nothing reports no proportion", {
  # Dividing by its total would give NaN for every cell, which reaches the
  # reader as a broken number rather than as an empty column. The chart draws
  # a column of zero width and no tiles; that is what this says.
  empty <- as.table(matrix(
    c(3, 0, 5, 0),
    nrow = 2,
    dimnames = list(c("a", "b"), c("u", "v"))
  ))

  layer <- mosaic_layers(function() mosaicplot(empty))[[1]]
  cells <- c(layer$data[[1]][[2]], layer$data[[2]][[2]])

  testthat::expect_equal(layer$data[[1]][[2]]$y, 0)
  testthat::expect_equal(layer$data[[1]][[2]]$width, 0)
  testthat::expect_equal(layer$data[[1]][[2]]$count, 0)
  testthat::expect_false(any(is.nan(vapply(cells, function(v) {
    if (is.numeric(v)) v else NA_real_
  }, 0))))
})

test_that("a column drawn with no tiles is announced but not addressed", {
  # A zero-width column has no tiles, so `mosaicplot()` draws fewer polygons
  # than the table has cells: measured, 2 grobs for this 2x2. Mapping the
  # cells onto them positionally would put every later highlight on the wrong
  # tile, so the layer takes none -- it still reads, with audio, braille and
  # text, which is the outcome #145 established for a layer with nothing to
  # point at.
  #
  # The cells are still all emitted: a reader navigating to the empty column
  # should hear that it is empty, not find it missing.
  empty <- as.table(matrix(
    c(3, 0, 5, 0),
    nrow = 2,
    dimnames = list(c("a", "b"), c("u", "v"))
  ))

  layer <- mosaic_layers(function() mosaicplot(empty))[[1]]

  testthat::expect_length(layer$selectors, 0)
  testthat::expect_length(layer$data, 2)
  testthat::expect_length(layer$data[[1]], 2)
})

test_that("the dimensions are named from the table's own dimnames", {
  # `mosaicplot()` labels its axes with `names(dimnames(x))` -- "Hair" and
  # "Eye" -- so those are the words a reader should be given.
  #
  # Which grammar axis each lands on is not the chart's own arrangement. The
  # second dimension is what `mosaicplot()` draws up the y axis, but a
  # segmented layer's `y` holds the *magnitude* and its `z` the fill, so the
  # second dimension is named on `z` and `y` says what its numbers are.
  axes <- mosaic_layers(function() mosaicplot(HAIR_EYE))[[1]]$axes

  testthat::expect_equal(axes$x$label, "Hair")
  testthat::expect_equal(axes$y$label, "Proportion")
  testthat::expect_equal(axes$z$label, "Eye")
})

test_that("the author's own labels win, each on its own dimension", {
  # `ylab` names `mosaicplot()`'s second dimension, which the layer carries
  # as `z` -- so it follows the dimension it names rather than the axis it
  # shares a letter with.
  axes <- mosaic_layers(function() {
    mosaicplot(HAIR_EYE, xlab = "Hair colour", ylab = "Eye colour")
  })[[1]]$axes

  testthat::expect_equal(axes$x$label, "Hair colour")
  testthat::expect_equal(axes$y$label, "Proportion")
  testthat::expect_equal(axes$z$label, "Eye colour")
})

test_that("an unnamed table leaves the dimensions to the renderer", {
  # A matrix built without `names(dimnames())` names nothing, and inventing
  # "Category"/"Fill" would put words in the chart that its author did not.
  bare <- as.table(matrix(
    c(3, 7, 5, 1),
    nrow = 2,
    dimnames = list(c("a", "b"), c("u", "v"))
  ))

  axes <- mosaic_layers(function() mosaicplot(bare))[[1]]$axes

  testthat::expect_null(axes$x)
  testthat::expect_equal(axes$y$label, "Proportion")
  testthat::expect_null(axes$z)
})

test_that("the title is the one the author wrote", {
  titled <- mosaic_layers(function() {
    mosaicplot(HAIR_EYE, main = "Hair and eye colour")
  })[[1]]

  testthat::expect_equal(titled$title, "Hair and eye colour")
  testthat::expect_equal(mosaic_layers(function() mosaicplot(HAIR_EYE))[[1]]$title, "")
})

test_that("a mosaic addresses the tile it is standing on", {
  # Measured on a rendered `mosaicplot(HairEyeColor[, , 1])`: gridGraphics
  # draws one `-polygon-N` grob per cell and nothing else as a polygon -- 16
  # for a 4x4 table, no frame among them. Their geometry gives the order:
  # `polygon-1`..`-4` share the leftmost column's x extent (50 to 219.8),
  # `-5`..`-8` the next (237.8 to 671.4), and within a column the grob number
  # runs down the fill levels in the table's own order. The emitted data is
  # fill-major, so cell (fill f, column c) is grob (c - 1) * fills + f.
  selectors <- unlist(mosaic_layers(function() mosaicplot(HAIR_EYE))[[1]]$selectors)

  testthat::expect_length(selectors, nrow(HAIR_EYE) * ncol(HAIR_EYE))
  testthat::expect_equal(
    selectors[1:4],
    paste0("#graphics-plot-1-polygon-", c(1, 5, 9, 13), "\\.1 polygon")
  )
  testthat::expect_equal(
    selectors[5],
    "#graphics-plot-1-polygon-2\\.1 polygon"
  )
  testthat::expect_length(unique(selectors), length(selectors))
})

test_that("a three-way table is declined rather than flattened", {
  # `mosaicplot()` splits recursively for three dimensions and more, and a
  # `mosaic` layer has one category axis and one fill -- so a deeper table
  # has nowhere to put its later dimensions. Read flat it would announce a
  # cross-classification the chart does not claim.
  #
  # No layer at all, which is what "unknown" produces: the type never reaches
  # the schema and routes the figure to the static-image fallback (#176).
  # Asserted on the adapter too, so a call that yielded nothing for some
  # *other* reason could not pass this.
  testthat::expect_length(mosaic_types(function() mosaicplot(HairEyeColor)), 0)

  adapter <- maidr:::BaseRAdapter$new()
  declines <- function(args) {
    adapter$detect_layer_type(list(function_name = "mosaicplot", args = args))
  }

  testthat::expect_equal(declines(list(HairEyeColor)), "unknown")
  testthat::expect_equal(declines(list(HAIR_EYE)), "mosaic")
})

test_that("a plain matrix is read with the levels base R gives it", {
  # `mosaicplot()` coerces with `as.table()`, which supplies "A", "B", ...
  # for a matrix that carries no dimnames -- and then draws those letters
  # beside the tiles. So they are the chart's own labels rather than an
  # invention, and reading them is reading what is there.
  #
  # Only the dimension *names* are missing, so the axes stay unnamed while
  # the levels arrive.
  layer <- mosaic_layers(function() {
    mosaicplot(matrix(c(10, 20, 30, 40), nrow = 2))
  })[[1]]

  testthat::expect_equal(layer$type, "mosaic")
  testthat::expect_identical(
    vapply(layer$data[[1]], function(cell) cell$x, ""),
    c("A", "B")
  )
  testthat::expect_null(layer$axes$x)
})

test_that("a table whose margins have no levels at all is declined", {
  # The levels are what a reader navigates by, and positions are not levels.
  # Reachable only for a table whose dimnames were cleared after coercion --
  # `as.table()` supplies them for anything it converts, per the test above.
  adapter <- maidr:::BaseRAdapter$new()
  unnamed <- as.table(matrix(c(1, 2, 3, 4), nrow = 2))
  dimnames(unnamed) <- NULL

  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "mosaicplot", args = list(unnamed))),
    "unknown"
  )
})

test_that("a mosaic given an xlab still reads its table", {
  # `$` on a list partial-matches, so `args$x` handed back `xlab` -- the trap
  # #245 was about. Dispatch and extraction both read the table through
  # `recorded_two_way_table()`, so this exercises the pair.
  layer <- mosaic_layers(function() mosaicplot(HAIR_EYE, xlab = "Hair colour"))[[1]]

  testthat::expect_equal(layer$type, "mosaic")
  testthat::expect_length(layer$data, ncol(HAIR_EYE))
  testthat::expect_equal(layer$data[[1]][[1]]$count, 32)
})

test_that("a stacked bar is unchanged", {
  # The control. A mosaic emits the same nested shape a stacked bar does and
  # differs only in what each cell carries, so a change made one level too
  # high would show up here.
  heights <- matrix(
    c(30, 20, 40, 10),
    nrow = 2,
    dimnames = list(c("u", "v"), c("apple", "banana"))
  )
  layer <- mosaic_layers(function() barplot(heights))[[1]]

  testthat::expect_equal(layer$type, "stacked_bar")
  testthat::expect_equal(layer$data[[1]][[1]]$y, 30)
  testthat::expect_null(layer$data[[1]][[1]]$width)
})
