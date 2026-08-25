# Every base R reader asked `isTRUE()` of a recorded flag, and the base R
# drawing functions ask `if (x)` (#256).
#
# The two agree on `TRUE`, on `FALSE` and on absent, and disagree on every
# other truthy value R accepts in an `if`:
#
#   written              stripchart draws    maidr read it as
#   vertical = TRUE      vertical            vertical
#   vertical = FALSE     horizontal          horizontal
#   vertical = 1         VERTICAL            HORIZONTAL
#   vertical = "TRUE"    VERTICAL            HORIZONTAL
#
# So a chart written `vertical = 1` was announced with its two axes the wrong
# way round -- the values on the group axis and the group positions on the
# value axis -- silently, on a chart that renders as an interactive one
# rather than as a fallback. That is the class of defect this project keeps
# finding, and the fix is one helper rather than one processor.
#
# Which flags are in scope was measured by reading each drawing function's
# own body rather than assumed, because some base R functions do call
# `isTRUE()` themselves and for those the old reading was exactly right:
#
#   barplot.default       if (beside), (logx && horiz)
#   bxp                   if (horizontal)
#   hist.default          if (freq1)
#   stripchart.default    if (vertical)
#   qqnorm.default        if (datax)
#   qqline                if (datax)
#   vioplot.default       if (horizontal | ...)
#
# All seven ask R's own truthiness, so all seven are read through
# `recorded_flag()`.

flag <- function(...) maidr:::recorded_flag(...)

#' What R's own `if` makes of a value, or "error" where it refuses
r_truthiness <- function(value) {
  tryCatch(if (value) TRUE else FALSE, error = function(e) "error")
}


test_that("recorded_flag agrees with R's own if() on every value R accepts", {
  # The whole contract, stated as the comparison rather than as a table of
  # remembered answers: for anything `if` will take, the reading is what the
  # drawing function would have done with it.
  accepted <- list(TRUE, FALSE, 1, 0, 2, -1, 0.5, "TRUE", "true", "T", "FALSE", "false", "F")

  for (value in accepted) {
    testthat::expect_identical(
      flag(list(v = value), "v"),
      r_truthiness(value),
      info = paste("value:", paste(format(value), collapse = ","))
    )
  }
})


test_that("a value R's if() refuses gives the caller's default, not an error", {
  # `if (NA)` stops in R, and a reader that stops takes the whole figure with
  # it. A chart read under its default is better than no chart at all.
  refused <- list(NA, NA_character_, "banana", c(1, 2), list(1), character(0))

  for (value in refused) {
    testthat::expect_identical(r_truthiness(value), "error",
                               info = "fixture must actually be refused")
    testthat::expect_false(flag(list(v = value), "v"))
    testthat::expect_true(flag(list(v = value), "v", default = TRUE))
  }
})


test_that("an absent argument gives the caller's default", {
  testthat::expect_false(flag(list(), "v"))
  testthat::expect_true(flag(list(), "v", default = TRUE))
  testthat::expect_false(flag(NULL, "v"))
  testthat::expect_true(flag(NULL, "v", default = TRUE))
})


test_that("a stripchart written vertical = 1 is read the way it is drawn", {
  # The issue's own case. `stripchart.default` asks `if (vertical)`, so this
  # chart is drawn vertically; read through `isTRUE()` it was announced
  # horizontally, with both axes exchanged.
  len <- c(1, 2, 3, 10, 11, 12)
  supp <- rep(c("OJ", "VC"), each = 3)

  axes_of <- function(draw) {
    layer <- base_r_layers(draw)[[1]]
    c(x = layer$axes$x$label, y = layer$axes$y$label)
  }

  drawn_vertically <- axes_of(function() stripchart(len ~ supp, vertical = TRUE))
  written_as_one <- axes_of(function() stripchart(len ~ supp, vertical = 1))
  drawn_horizontally <- axes_of(function() stripchart(len ~ supp))

  testthat::expect_equal(written_as_one, drawn_vertically)
  testthat::expect_false(isTRUE(all.equal(written_as_one, drawn_horizontally)))
})


test_that("a stripchart written vertical = \"TRUE\" is read the same way", {
  len <- c(1, 2, 3, 10, 11, 12)
  supp <- rep(c("OJ", "VC"), each = 3)

  axes_of <- function(draw) {
    layer <- base_r_layers(draw)[[1]]
    c(x = layer$axes$x$label, y = layer$axes$y$label)
  }

  testthat::expect_equal(
    axes_of(function() stripchart(len ~ supp, vertical = "TRUE")),
    axes_of(function() stripchart(len ~ supp, vertical = TRUE))
  )
})


test_that("a box plot written horizontal = 1 is read the way it is drawn", {
  # `bxp` asks `if (horizontal)`, and `boxplot.default` hands its own
  # argument straight through.
  orientation_of <- function(draw) base_r_layers(draw)[[1]]$orientation

  testthat::expect_equal(
    orientation_of(function() boxplot(list(a = c(1, 2, 3), b = c(4, 5, 6)), horizontal = 1)),
    orientation_of(function() boxplot(list(a = c(1, 2, 3), b = c(4, 5, 6)), horizontal = TRUE))
  )
})


test_that("a bar chart written horiz = 1 is read the way it is drawn", {
  orientation_of <- function(draw) base_r_layers(draw)[[1]]$orientation

  testthat::expect_equal(
    orientation_of(function() barplot(c(a = 1, b = 2), horiz = 1)),
    orientation_of(function() barplot(c(a = 1, b = 2), horiz = TRUE))
  )
  testthat::expect_false(isTRUE(all.equal(
    orientation_of(function() barplot(c(a = 1, b = 2), horiz = 1)),
    orientation_of(function() barplot(c(a = 1, b = 2)))
  )))
})


test_that("a stacked bar written beside = 1 is read as the dodged one it draws", {
  # `barplot.default` asks `if (beside)`, so this draws dodged bars. Read
  # through `isTRUE()` it was typed as a stacked bar, which announces a
  # running total the chart does not draw.
  counts <- matrix(c(1, 2, 3, 4), nrow = 2,
                   dimnames = list(c("p", "q"), c("a", "b")))

  testthat::expect_equal(
    base_r_layer_types(function() barplot(counts, beside = 1)),
    base_r_layer_types(function() barplot(counts, beside = TRUE))
  )
  testthat::expect_false(identical(
    base_r_layer_types(function() barplot(counts, beside = 1)),
    base_r_layer_types(function() barplot(counts))
  ))
})


test_that("a histogram written freq = 0 is read as the density it draws", {
  # `hist.default` sets `freq1 <- freq` and asks `if (freq1)`, so `freq = 0`
  # draws densities. Read through `isTRUE()` it already came out FALSE here,
  # so this pins the agreement rather than a change -- and `freq = 1`, which
  # did change, is the case below.
  x <- c(1, 2, 2, 3, 3, 3, 4, 4, 5)

  testthat::expect_equal(
    base_r_layers(function() hist(x, freq = 0))[[1]]$axes$y$label,
    base_r_layers(function() hist(x, freq = FALSE))[[1]]$axes$y$label
  )
})


test_that("a histogram written freq = 1 is read as the counts it draws", {
  x <- c(1, 2, 2, 3, 3, 3, 4, 4, 5)

  testthat::expect_equal(
    base_r_layers(function() hist(x, freq = 1))[[1]]$axes$y$label,
    base_r_layers(function() hist(x, freq = TRUE))[[1]]$axes$y$label
  )
})


test_that("a qqnorm written datax = 1 swaps its axes the way the chart does", {
  # `qqnorm.default` asks `if (datax)`. Read through `isTRUE()` the pairs
  # came back unswapped over a chart drawn the other way round.
  sample <- c(4.1, 2.3, 5.6, 3.3, 6.9, 1.2, 4.8, 3.9)

  first_of <- function(draw) {
    point <- base_r_layers(draw)[[1]]$data[[1]]
    c(x = point$x, y = point$y)
  }

  testthat::expect_equal(
    first_of(function() qqnorm(sample, datax = 1)),
    first_of(function() qqnorm(sample, datax = TRUE))
  )
  testthat::expect_false(isTRUE(all.equal(
    first_of(function() qqnorm(sample, datax = 1)),
    first_of(function() qqnorm(sample))
  )))
})
