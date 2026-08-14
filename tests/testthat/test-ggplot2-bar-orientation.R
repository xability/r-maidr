# A horizontal ggplot2 bar chart lost every label and every value (#162).
#
# `ggplot(df, aes(y = g, x = n)) + geom_col()` is the ordinary spelling.
# `ggplot_build()` marks the layer `flipped_aes` and swaps which computed
# column holds what, and the processor read `x` as the category and `y` as the
# measure unconditionally, so it picked up exactly the wrong pair:
#
#   truth      apple = 30   banana = 70   cherry = 50
#   announced  "30" -> 1    "50" -> 3     "70" -> 2
#
# Three things at once. The labels were gone -- `apple`/`banana`/`cherry`
# appeared nowhere in the layer, and what sat in `x` was the measure coerced
# to a string. The values were factor codes rather than counts. And the rows
# came out sorted by the measure rather than in the chart's own order, so even
# the sequence a reader navigates did not match the bars.
#
# The `axes` block was correct throughout -- `x: "n"`, `y: "g"` -- which makes
# it worse rather than better: the axis names say which way round the chart is
# and the data underneath contradicted them.

bar_schema <- function(plot) {
  maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
}

bar_layer <- function(plot) {
  bar_schema(plot)$subplots[[1]][[1]]$layers[[1]]
}

# `label:value` per bar, in emitted order.
bar_pairs <- function(layer) {
  vapply(
    layer$data,
    function(d) sprintf("%s:%s", d$x, d$y),
    character(1)
  )
}

fruit <- function() {
  data.frame(
    g = c("apple", "banana", "cherry"),
    n = c(30, 70, 50),
    stringsAsFactors = FALSE
  )
}

test_that("a horizontal bar chart keeps its labels and its values", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- bar_layer(
    ggplot2::ggplot(fruit(), ggplot2::aes(y = g, x = n)) + ggplot2::geom_col()
  )

  testthat::expect_equal(
    bar_pairs(layer),
    c("apple:30", "banana:70", "cherry:50")
  )
  testthat::expect_equal(layer$orientation, "horz")
})

test_that("a vertical bar chart is unchanged, and says it is vertical", {
  testthat::skip_if_not_installed("ggplot2")

  layer <- bar_layer(
    ggplot2::ggplot(fruit(), ggplot2::aes(x = g, y = n)) + ggplot2::geom_col()
  )

  testthat::expect_equal(
    bar_pairs(layer),
    c("apple:30", "banana:70", "cherry:50")
  )
  testthat::expect_equal(layer$orientation, "vert")
})

test_that("the two orientations describe the same chart", {
  testthat::skip_if_not_installed("ggplot2")

  # The strongest form of the assertion: same data, drawn both ways, has to
  # come out identical apart from the orientation key. Anything that read one
  # axis for the labels and the other for the values shows up here.
  frame <- fruit()
  upright <- bar_layer(
    ggplot2::ggplot(frame, ggplot2::aes(x = g, y = n)) + ggplot2::geom_col()
  )
  sideways <- bar_layer(
    ggplot2::ggplot(frame, ggplot2::aes(y = g, x = n)) + ggplot2::geom_col()
  )

  testthat::expect_equal(bar_pairs(sideways), bar_pairs(upright))
})

test_that("a horizontal stat_count bar chart counts the right thing", {
  testthat::skip_if_not_installed("ggplot2")

  # `geom_bar()` derives its own rows rather than reading a measure column, so
  # it reaches the label recovery by a different route than `geom_col()`.
  counts <- data.frame(
    g = rep(c("a", "b", "c"), times = c(2, 5, 3)),
    stringsAsFactors = FALSE
  )
  layer <- bar_layer(
    ggplot2::ggplot(counts, ggplot2::aes(y = g)) + ggplot2::geom_bar()
  )

  testthat::expect_equal(bar_pairs(layer), c("a:2", "b:5", "c:3"))
  testthat::expect_equal(layer$orientation, "horz")
})

test_that("a wrapped expression on the flipped axis still yields labels", {
  testthat::skip_if_not_installed("ggplot2")

  # `factor(g)` is not a column name, so the label recovery falls through to
  # its second strategy -- which has to look at the flipped aesthetic too.
  layer <- bar_layer(
    ggplot2::ggplot(fruit(), ggplot2::aes(y = factor(g), x = n)) +
      ggplot2::geom_col()
  )

  testthat::expect_equal(
    bar_pairs(layer),
    c("apple:30", "banana:70", "cherry:50")
  )
})

test_that("every panel of a faceted horizontal bar chart is labelled", {
  testthat::skip_if_not_installed("ggplot2")

  # The faceted path reads its labels from the panel's own scale rather than
  # from the mapping, so it needs the swap independently of the branch above.
  counts <- data.frame(
    g = rep(c("a", "b", "c"), times = c(2, 5, 3)),
    stringsAsFactors = FALSE
  )
  counts$f <- rep(c("p", "q"), length.out = nrow(counts))

  panels <- unlist(
    bar_schema(
      ggplot2::ggplot(counts, ggplot2::aes(y = g)) +
        ggplot2::geom_bar() +
        ggplot2::facet_wrap(~f)
    )$subplots,
    recursive = FALSE
  )
  testthat::expect_gt(length(panels), 1)

  for (panel in panels) {
    layer <- panel$layers[[1]]
    testthat::expect_equal(layer$orientation, "horz")
    # Labels, not factor codes: the codes would be "1", "2", "3".
    testthat::expect_true(all(grepl("^[abc]:", bar_pairs(layer))))
  }
})

test_that("coord_flip is left vertical, because its data is not flipped", {
  testthat::skip_if_not_installed("ggplot2")

  # `coord_flip()` rotates the coordinate system and leaves `flipped_aes`
  # alone, so the columns are already the right way round. Swapping them here
  # would break the announcement in exactly the way this issue is about, from
  # the other side.
  layer <- bar_layer(
    ggplot2::ggplot(fruit(), ggplot2::aes(x = g, y = n)) +
      ggplot2::geom_col() +
      ggplot2::coord_flip()
  )

  testthat::expect_equal(layer$orientation, "vert")
  testthat::expect_equal(
    bar_pairs(layer),
    c("apple:30", "banana:70", "cherry:50")
  )
})

test_that("orientation = 'y' is read from the built data, not the argument", {
  testthat::skip_if_not_installed("ggplot2")

  # Spelled the sensible way -- category on `y` -- this is the same chart as
  # the first test and has to read the same.
  layer <- bar_layer(
    ggplot2::ggplot(fruit(), ggplot2::aes(y = g, x = n)) +
      ggplot2::geom_col(orientation = "y")
  )

  testthat::expect_equal(
    bar_pairs(layer),
    c("apple:30", "banana:70", "cherry:50")
  )
  testthat::expect_equal(layer$orientation, "horz")
})

test_that("a degenerate orientation is described rather than corrected", {
  testthat::skip_if_not_installed("ggplot2")

  # `aes(x = g, y = n)` with `orientation = "y"` asks for something odd, and
  # ggplot2 obliges: it leaves the fruit names on x and draws bars running
  # 0 to 1, 0 to 2 and 0 to 3 at heights 30, 70 and 50 -- the category codes
  # became the lengths. Checked against `ggplot_build()`, whose panel labels
  # are apple/banana/cherry on x and 20/40/60/80 on y.
  #
  # So the announcement below is not the chart the author meant, and it is
  # the chart ggplot2 drew. Pinned deliberately: making this read
  # "apple:30" would describe bars that are not there, which is the defect
  # this file is about rather than a fix for it.
  layer <- bar_layer(
    ggplot2::ggplot(fruit(), ggplot2::aes(x = g, y = n)) +
      ggplot2::geom_col(orientation = "y")
  )

  testthat::expect_equal(layer$orientation, "horz")
  testthat::expect_equal(bar_pairs(layer), c("30:1", "50:3", "70:2"))
})

test_that("is_flipped declines rather than erroring on a missing layer", {
  testthat::skip_if_not_installed("ggplot2")

  processor <- maidr:::Ggplot2BarLayerProcessor$new(list(index = 99))
  plot <- ggplot2::ggplot(fruit(), ggplot2::aes(x = g, y = n)) +
    ggplot2::geom_col()

  testthat::expect_false(processor$is_flipped(plot))
})
