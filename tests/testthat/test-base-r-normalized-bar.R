# Base R has no `position = "fill"`. `barplot()` takes no normalisation
# argument at all, so the idiomatic 100% stacked bar is written by normalising
# the matrix first — `barplot(prop.table(m, 2))` — and the only signal left to
# read is the drawn geometry.
#
# That makes the classification here a reading of what the chart shows rather
# than of what the author declared, which is a weaker footing than the ggplot2
# side has and is worth pinning from both directions: the shapes that must be
# claimed, and the ones that must not.

# Counts: category "a" splits 10/30, category "b" splits 50/50. Deliberately
# different column totals (40 vs 100), so a normalized reading of the raw
# matrix would be plainly wrong.
COUNTS <- matrix(
  c(10, 30, 50, 50),
  nrow = 2,
  dimnames = list(c("u", "v"), c("a", "b"))
)

# Build the layer shape `detect_layer_type()` reads.
barplot_layer <- function(height, ...) {
  list(function_name = "barplot", args = c(list(height), list(...)))
}

classify <- function(height, ...) {
  maidr:::BaseRAdapter$new()$detect_layer_type(barplot_layer(height, ...))
}

test_that("a raw count matrix is a plain stacked bar", {
  expect_equal(classify(COUNTS), "stacked_bar")
})

test_that("a column-normalized matrix is a 100% stacked bar", {
  expect_equal(classify(prop.table(COUNTS, 2)), "stacked_normalized_bar")
})

test_that("beside = TRUE stays dodged even when the columns sum to one", {
  # The dodge check runs first, and must: side-by-side bars are not a stack at
  # all, whatever their columns add up to.
  expect_equal(classify(prop.table(COUNTS, 2), beside = TRUE), "dodged_bar")
})

test_that("a single-series matrix is not claimed as normalized", {
  # One row of ones sums to 1 per column, but a single series stacked against
  # nothing is not a stack — reading it as "100% stacked" would announce a
  # composition that has no parts.
  single <- matrix(c(1, 1, 1), nrow = 1, dimnames = list("u", c("a", "b", "c")))
  expect_equal(classify(single), "stacked_bar")
})

test_that("columns summing to 100 are not claimed as normalized", {
  # Percentages and raw counts are indistinguishable at 100, and a count
  # matrix reaching 100 by coincidence is entirely ordinary. Claiming those as
  # shares would be a guess rather than a reading.
  hundreds <- matrix(
    c(25, 75, 40, 60),
    nrow = 2,
    dimnames = list(c("u", "v"), c("a", "b"))
  )
  expect_equal(classify(hundreds), "stacked_bar")
})

test_that("a vector barplot is unaffected", {
  # Only a matrix stacks; a bare vector is a plain bar chart whatever it sums
  # to, and must not be dragged into either stacked branch.
  expect_equal(classify(c(0.25, 0.75)), "bar")
})

test_that("floating point drift still reads as normalized", {
  # `prop.table()` divides, so the columns land near 1 rather than exactly on
  # it. An equality test would reject the very charts this exists to catch.
  drifted <- matrix(
    c(1 / 3, 1 / 3, 1 / 3, 0.2, 0.3, 0.5),
    nrow = 3,
    dimnames = list(c("u", "v", "w"), c("a", "b"))
  )
  expect_equal(classify(drifted), "stacked_normalized_bar")
})

test_that("the base R factory can build a processor for the new type", {
  factory <- maidr:::BaseRProcessorFactory$new()

  expect_true("stacked_normalized_bar" %in% factory$get_supported_types())
  processor <- factory$create_processor(
    "stacked_normalized_bar",
    list(type = "stacked_normalized_bar")
  )
  expect_s3_class(processor, "BaseRStackedBarLayerProcessor")
})
