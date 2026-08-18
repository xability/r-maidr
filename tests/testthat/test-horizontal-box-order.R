# Which end of a horizontal box or violin chart a reader starts at (#187)
#
# `BoxTrace`, `ViolinBoxTrace` and `ViolinTrace` each reverse a horizontal
# layer on the way in -- "reverse points to match visual order (lower-left
# start)", as src/model/box.ts puts it -- and the reversal is unconditional.
# A producer that emits its categories in their own bottom-to-top order
# therefore gets them read from the top down.
#
# Measured on ggplot2 3.4.4 with gridSVG, `aes(v, grp)` over a, b, c. In the
# exported SVG y runs upward, so a smaller y is nearer the bottom:
#
#   GRID.segments.6.1    y 62 - 166     <- category a, the bottom box
#   GRID.segments.14.1   y 200 - 305    <- category b
#   GRID.segments.22.1   y 339 - 443    <- category c, the top box
#
# and the layer was emitted a, b, c -- bottom first. After the frontend's
# reversal a reader landed on c, the top box, and walked downwards, while the
# same chart drawn by py-maidr started at the bottom.

skip_if_not_installed("ggplot2")

library(ggplot2)

hb_data <- function() {
  data.frame(grp = rep(c("a", "b", "c"), each = 3), v = c(1, 2, 2, 3, 3, 3, 4, 4, 5))
}

hb_box <- function(plot) {
  processor <- maidr:::Ggplot2BoxplotLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  built <- ggplot2::ggplot_build(plot)
  processor$process(
    plot, list(axes = list(x = "v", y = "grp")), built, ggplot2::ggplotGrob(plot)
  )
}

hb_violin <- function(plot) {
  processor <- maidr:::Ggplot2ViolinLayerProcessor$new(
    list(layer_index = 1, index = 1, plot = plot)
  )
  built <- ggplot2::ggplot_build(plot)
  processor$process(
    plot, list(axes = list(x = "v", y = "grp")), built, ggplot2::ggplotGrob(plot)
  )
}

# The categories a layer announces, in the order it emits them.
hb_order <- function(data) {
  vapply(data, function(d) as.character(d$z), character(1))
}

# The grob number each box's median selector addresses. ggplot2 numbers its
# grobs in the order it draws them, so these run upward in the layer's own
# category order -- which makes the sequence a direct read of whether the
# selectors moved with the data.
hb_grob_numbers <- function(selectors) {
  vapply(selectors, function(s) {
    as.integer(sub(".*segments\\\\\\.([0-9]+)\\\\\\.1.*", "\\1", s$q2))
  }, integer(1))
}

# What the frontend does with a horizontal layer on the way in.
hb_as_read <- function(x) rev(x)

# ==============================================================================
# Box plots
# ==============================================================================

test_that("a horizontal box plot is emitted for a lower-left start", {
  out <- hb_box(ggplot(hb_data(), aes(v, grp)) + geom_boxplot())

  testthat::expect_equal(out$orientation, "horz")
  testthat::expect_equal(hb_order(out$data), c("c", "b", "a"))
  # Which is what the reader actually gets, the frontend having reversed it.
  testthat::expect_equal(hb_order(hb_as_read(out$data))[[1]], "a")
})

test_that("a vertical box plot is emitted in its own order", {
  out <- hb_box(ggplot(hb_data(), aes(grp, v)) + geom_boxplot())

  testthat::expect_equal(out$orientation, "vert")
  testthat::expect_equal(hb_order(out$data), c("a", "b", "c"))
})

test_that("a horizontal box plot's marks move with its data", {
  # Reversing the data alone would trade a correct outline for a wrong one:
  # the frontend reverses the resolved highlight alongside the points, so a
  # layer whose two halves disagree stays disagreeing.
  out <- hb_box(ggplot(hb_data(), aes(v, grp)) + geom_boxplot())
  grobs <- hb_grob_numbers(out$selectors)

  testthat::expect_length(grobs, 3)
  testthat::expect_true(all(diff(grobs) < 0))
  # Category a is the first box ggplot2 drew, so it carries the lowest grob
  # number -- and it is what the reader lands on.
  testthat::expect_equal(hb_as_read(grobs)[[1]], min(grobs))
})

test_that("a vertical box plot's marks are left in drawing order", {
  out <- hb_box(ggplot(hb_data(), aes(grp, v)) + geom_boxplot())

  testthat::expect_true(all(diff(hb_grob_numbers(out$selectors)) > 0))
})

# ==============================================================================
# Violins
# ==============================================================================

test_that("a horizontal violin turns both of its layers round", {
  set.seed(1)
  df <- data.frame(grp = rep(c("a", "b", "c"), each = 20),
                   v = c(rnorm(20, 1), rnorm(20, 3), rnorm(20, 5)))
  out <- hb_violin(ggplot(df, aes(v, grp)) + geom_violin())

  box <- out$layers[[1]]
  kde <- out$layers[[2]]
  testthat::expect_equal(box$type, "violin_box")
  testthat::expect_equal(kde$type, "violin_kde")
  testthat::expect_equal(hb_order(box$data), c("c", "b", "a"))
  # The KDE rows carry no z, so they are read by the values they cover: the
  # densest part of a's violin sits near 1 and c's near 5.
  kde_middle <- vapply(kde$data, function(rows) {
    mean(vapply(rows, function(pt) as.numeric(pt$y), numeric(1)))
  }, numeric(1))
  testthat::expect_true(all(diff(kde_middle) < 0))
})

test_that("a vertical violin is left alone", {
  set.seed(1)
  df <- data.frame(grp = rep(c("a", "b", "c"), each = 20),
                   v = c(rnorm(20, 1), rnorm(20, 3), rnorm(20, 5)))
  out <- hb_violin(ggplot(df, aes(grp, v)) + geom_violin())

  testthat::expect_equal(hb_order(out$layers[[1]]$data), c("a", "b", "c"))
  kde_middle <- vapply(out$layers[[2]]$data, function(rows) {
    mean(vapply(rows, function(pt) as.numeric(pt$y), numeric(1)))
  }, numeric(1))
  testthat::expect_true(all(diff(kde_middle) > 0))
})

# ==============================================================================
# The helper itself
# ==============================================================================

test_that("a vertical layer passes through untouched", {
  layer <- list(data = list("a", "b"), selectors = list("s1", "s2"),
                orientation = "vert")

  testthat::expect_equal(maidr:::reverse_horizontal_box_layer(layer), layer)
})

test_that("selectors that do not pair with the data are left alone", {
  # A layer whose selectors did not all resolve cannot be paired by position,
  # and reversing half of a pairing is worse than leaving it.
  layer <- list(data = list("a", "b", "c"), selectors = list("s1"),
                orientation = "horz")
  out <- maidr:::reverse_horizontal_box_layer(layer)

  testthat::expect_equal(out$data, list("c", "b", "a"))
  testthat::expect_equal(out$selectors, list("s1"))
})
