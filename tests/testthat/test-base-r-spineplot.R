# A base R spine plot fell back to a picture (#251).
#
# `spineplot()` is one of the eight #216 put in HIGH so a recorded call would
# stop failing the save, but it had no branch in `detect_layer_type()` and no
# processor, so the figure took the static-image path.
#
# **It is a mosaic, and it is read as one.** A spine plot draws one column per
# level of `x`, its width that level's share of all observations, split
# vertically by `y`'s conditional proportions inside it -- which is exactly
# the shape `BaseRMosaicLayerProcessor` was written for in #247. So the
# reading is the mosaic's, and only two things differ.
#
# **The table has to be replayed.** `mosaicplot()` is handed its table;
# `spineplot()` is handed the two variables and builds one, and unlike
# `cdplot()` it has **no `plot` argument** to be asked for the table without
# drawing. It does return what it drew, so the call is replayed on a
# throwaway device -- through `graphics::spineplot`, the qualified name, so
# maidr's own patched name is not re-entered and the replay is not recorded
# as a second chart.
#
# That matters most for a numeric `x`, which `spineplot` cuts into bins by
# its own rule. Measured on sixty standard normals, the announced categories
# are the intervals the chart labels its axis with -- `[-2,-1.5]`,
# `(-1.5,-1]`, and so on -- which no re-derivation here would have got right
# by accident.
#
# **The tiles are one grob, not many.** `mosaicplot()` writes one `polygon`
# grob per cell; `spineplot()` writes one `rect` grob for the whole panel,
# and gridSVG exports it as one `<rect>` per tile. Measured on a 3x2 table:
#
#     graphics-plot-1-rect-1.1.1   x  59.04   w 152.86   h 118.71
#     graphics-plot-1-rect-1.1.2   x  59.04   w 152.86   h 108.81
#     graphics-plot-1-rect-1.1.3   x 219.88   w 139.57   h 151.68
#     graphics-plot-1-rect-1.1.4   x 219.88   w 139.57   h  75.84
#     graphics-plot-1-rect-1.1.5   x 367.42   w 106.34   h  56.88
#     graphics-plot-1-rect-1.1.6   x 367.42   w 106.34   h 170.64
#
# Six elements for six cells, sharing an x within a column, the widths in the
# marginals' ratio 23 : 21 : 16 -- and **within a column the last fill level
# is drawn first**, since 118.71 : 108.81 pairs with 12 : 11, which is `yes`
# above `no`. That is the opposite of the mosaic's order, and it is why the
# index is computed rather than inherited.
#
# Every emitted selector was then resolved against a real `save_html()`
# rendering in Chromium. All six matched exactly one `<rect>`, and their
# heights paired with the counts:
#
#     low/no=11   126.9      low/yes=12   138.4     ratio 1.091 = 12/11
#     mid/no=7     88.5      mid/yes=14   176.9     ratio 2.000 = 14/7
#     high/no=12  199.0      high/yes=4    66.3     ratio 3.000 = 12/4

# `base_r_layers` lives in `helper.R` (#241).
spine_layers <- base_r_layers

#' Three levels against two, with no two cells equal.
LEVELS <- factor(
  c(rep("low", 5), rep("mid", 4), rep("high", 3),
    rep("low", 2), rep("mid", 6), rep("high", 1)),
  levels = c("low", "mid", "high")
)
ANSWERS <- factor(c(rep("no", 12), rep("yes", 9)))

#' Draw a spine plot off-screen and return its grob tree
#'
#' `grid.echo()` comes from gridGraphics, which reaches this package only as
#' a transitive dependency, so it is skipped rather than assumed -- the same
#' line `violin_grobs()` draws in `test-base-r-violin.R`.
spine_grobs <- function(drawn) {
  if (!requireNamespace("gridGraphics", quietly = TRUE)) {
    return(NULL)
  }
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path, width = 7, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  grDevices::dev.control("enable")
  graphics::spineplot(drawn)
  tryCatch(
    {
      suppressMessages(gridGraphics::grid.echo())
      grid::grid.grab()
    },
    error = function(e) NULL
  )
}

#' The layer a recorded `spineplot()` argument list produces
processed <- function(args, gt = NULL) {
  info <- list(plot_call = list(args = args), group_index = 1)
  BaseRSpineplotLayerProcessor$new(info)$process(
    NULL, NULL, NULL, gt, NULL, NULL, NULL, info
  )
}

#' Every cell of a layer as "x/z=count"
cells <- function(layer) {
  vapply(
    unlist(layer$data, recursive = FALSE),
    function(cell) sprintf("%s/%s=%s", cell$x, cell$z, cell$count),
    character(1)
  )
}

test_that("a spine plot is read as the mosaic it draws", {
  layers <- spine_layers(function() spineplot(table(LEVELS, ANSWERS)))

  expect_equal(length(layers), 1)
  expect_equal(layers[[1]]$type, "mosaic")
})

test_that("the table is the one spineplot drew, replayed out of the call", {
  layer <- processed(list(table(LEVELS, ANSWERS)))

  expect_equal(
    cells(layer),
    c("low/no=5", "mid/no=4", "high/no=3",
      "low/yes=2", "mid/yes=6", "high/yes=1")
  )
})

test_that("each cell carries its column's width as well as its proportion", {
  # The half of the table a stacked bar would lose: the conditional
  # proportions arrive with the group sizes they were computed from.
  first <- processed(list(table(LEVELS, ANSWERS)))$data[[1]][[1]]

  expect_equal(first$count, 5)
  expect_equal(first$y, 5 / 7)
  expect_equal(first$width, 7 / 21)
})

test_that("a formula is resolved the way spineplot resolves it", {
  formula <- local({
    answer <- ANSWERS
    level <- LEVELS
    answer ~ level
  })

  expect_equal(
    cells(processed(list(formula))),
    c("low/no=5", "mid/no=4", "high/no=3",
      "low/yes=2", "mid/yes=6", "high/yes=1")
  )
})

test_that("a numeric x is announced in the bins the chart labelled", {
  # The case a re-derivation here would have had to guess at: `spineplot`
  # cuts a numeric x by its own rule, and the categories it draws are the
  # interval names.
  formula <- local({
    set.seed(11)
    measure <- stats::rnorm(60)
    answer <- factor(sample(c("no", "yes"), 60, TRUE))
    answer ~ measure
  })

  categories <- unique(vapply(
    unlist(processed(list(formula))$data, recursive = FALSE),
    function(cell) cell$x, character(1)
  ))

  expect_gt(length(categories), 3)
  expect_true(all(grepl("^[\\[(].*,.*\\]$", categories)))
})

test_that("the axes are named from the table's own dimensions", {
  axes <- processed(list(table(LEVELS, ANSWERS)))$axes

  expect_equal(axes$x$label, "LEVELS")
  expect_equal(axes$y$label, "Proportion")
  expect_equal(axes$z$label, "ANSWERS")
})

test_that("the caller's own labels and title win", {
  layer <- processed(list(
    table(LEVELS, ANSWERS),
    main = "Answers", xlab = "Level", ylab = "Answer"
  ))

  expect_equal(layer$title, "Answers")
  expect_equal(layer$axes$x$label, "Level")
  expect_equal(layer$axes$z$label, "Answer")
})

test_that("each cell points at the tile it was drawn into", {
  # Column-major, and within a column the LAST fill level first -- the order
  # measured off the drawing. The payload runs fill-major, so the two are
  # deliberately not the same walk.
  gt <- spine_grobs(table(LEVELS, ANSWERS))
  skip_if(is.null(gt), "gridGraphics could not echo the drawing")

  selectors <- processed(list(table(LEVELS, ANSWERS)), gt)$selectors

  expect_equal(
    unlist(selectors),
    c(
      "#graphics-plot-1-rect-1\\.1\\.2",
      "#graphics-plot-1-rect-1\\.1\\.4",
      "#graphics-plot-1-rect-1\\.1\\.6",
      "#graphics-plot-1-rect-1\\.1\\.1",
      "#graphics-plot-1-rect-1\\.1\\.3",
      "#graphics-plot-1-rect-1\\.1\\.5"
    )
  )
})

test_that("a cell of zero is drawn, so no later tile shifts", {
  # The hazard this shape invites, and the one xability/maidr#1002 found
  # elsewhere: a count of zero skipped rather than drawn would move every
  # later tile's index by one and hand each cell its neighbour's rectangle.
  # Measured -- `spineplot` draws it with `height="0"`.
  zeroed <- as.table(matrix(
    c(5, 0, 3, 7, 2, 4), nrow = 3, byrow = TRUE,
    dimnames = list(f = c("a", "b", "c"), g = c("no", "yes"))
  ))
  gt <- spine_grobs(zeroed)
  skip_if(is.null(gt), "gridGraphics could not echo the drawing")

  layer <- processed(list(zeroed), gt)

  expect_equal(
    cells(layer),
    c("a/no=5", "b/no=3", "c/no=2", "a/yes=0", "b/yes=7", "c/yes=4")
  )
  expect_equal(length(layer$selectors), 6)
  expect_equal(layer$selectors[[4]], "#graphics-plot-1-rect-1\\.1\\.1")
})

test_that("a panel holding more than one rect grob is declined", {
  # A spineplot draws exactly one, so this is a guard against a drawing
  # nobody has seen rather than one anybody has -- but it is the difference
  # between highlighting nothing and highlighting whatever the first rect
  # happens to be, and a guard no test can reach is a branch nobody can hold
  # to account. Two are put in front of it directly.
  two <- grid::grobTree(
    grid::rectGrob(name = "graphics-plot-1-rect-1"),
    grid::rectGrob(name = "graphics-plot-1-rect-2")
  )

  expect_equal(length(processed(list(table(LEVELS, ANSWERS)), two)$selectors), 0)
})

test_that("a panel holding exactly one rect grob is addressed", {
  # The other side of the same guard: one is enough, and the tiles are its
  # sub-elements rather than grobs of their own.
  one <- grid::grobTree(grid::rectGrob(name = "graphics-plot-1-rect-1"))

  expect_equal(length(processed(list(table(LEVELS, ANSWERS)), one)$selectors), 6)
})

test_that("no selector is emitted without a drawing to check against", {
  expect_equal(length(processed(list(table(LEVELS, ANSWERS)))$selectors), 0)
})

test_that("a call with nothing to replay is declined", {
  # `spineplot` stops with "a 2-way table has to be specified" on both of
  # these, so the replay comes back with nothing rather than with a shape to
  # check.
  expect_equal(length(processed(list())$data), 0)
  expect_equal(length(processed(list("not a table"))$data), 0)
  expect_equal(length(processed(list(HairEyeColor))$data), 0)
})

test_that("a table with no names for its categories is declined", {
  # Measured: `spineplot(matrix(1:6, nrow = 3))` draws, and returns a 3x2
  # table whose rows and columns are unnamed. Announcing it would give a
  # reader six cells with nothing to call them, which is what the mosaic
  # declines an unnamed table for as well.
  expect_equal(length(processed(list(matrix(1:6, nrow = 3)))$data), 0)
})

test_that("the factory knows the type and the adapter routes to it", {
  factory <- BaseRProcessorFactory$new()

  expect_true("spine" %in% factory$get_supported_types())
  expect_s3_class(
    factory$create_processor("spine", list(plot_call = list(args = list()))),
    "BaseRSpineplotLayerProcessor"
  )
})
