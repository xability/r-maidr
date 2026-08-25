# `assocplot()` fell back to a picture, though every number it draws is in
# the call (#266).
#
# A Cohen--Friendly association plot states one signed Pearson residual per
# cell of a two-way table. It is read as a `heat` -- a named grid of one
# number per cell, navigated row then column, which is how a contingency
# table is read.
#
# The grid's relation to the table is measured rather than chosen. From the
# drawn rects: the FIRST dimension runs across the x axis, the SECOND up the
# y axis, and the bands are drawn bottom to top -- so the emitted grid is the
# table transposed, read top-down, with the selectors undoing the drawing's
# bottom-up order.

hair_eye <- function() as.matrix(HairEyeColor[, , 1])

residuals_of <- function(table) {
  counts <- matrix(as.numeric(table), nrow = nrow(table), ncol = ncol(table))
  expected <- outer(rowSums(counts), colSums(counts)) / sum(counts)
  (counts - expected) / sqrt(expected)
}

layer_info_for <- function(table, extra = list(), index = 1) {
  list(
    plot_call = list(args = c(list(table), extra), fname = "assocplot"),
    function_name = "assocplot",
    group_index = index,
    index = index
  )
}

test_that("an association plot is read as a heat layer rather than declined", {
  info <- layer_info_for(hair_eye())

  result <- BaseRAssocplotLayerProcessor$new(info)$process(
    NULL, NULL, layer_info = info
  )

  expect_equal(result$type, "heat")
})

test_that("every cell carries its own Pearson residual", {
  table <- hair_eye()
  expected <- residuals_of(table)
  info <- layer_info_for(table)

  data <- BaseRAssocplotLayerProcessor$new(info)$extract_data(info)

  # The grid is the table TRANSPOSED: rows are the second dimension.
  for (r in seq_len(ncol(table))) {
    for (cc in seq_len(nrow(table))) {
      expect_equal(data$points[[r]][[cc]], expected[cc, r])
    }
  }
})

test_that("the grid's rows are the second dimension and its columns the first", {
  table <- hair_eye()
  info <- layer_info_for(table)

  data <- BaseRAssocplotLayerProcessor$new(info)$extract_data(info)

  # Measured from the drawing: the band at the TOP is the table's first
  # column, and the grid reads top-down -- so the rows are NOT reversed.
  expect_equal(unlist(data$y), colnames(table))
  expect_equal(unlist(data$x), rownames(table))
})

test_that("the axes are named from the table, and z for what the numbers are", {
  info <- layer_info_for(hair_eye())

  axes <- BaseRAssocplotLayerProcessor$new(info)$extract_axis_titles(info)

  expect_equal(axes$x$label, "Hair")
  expect_equal(axes$y$label, "Eye")
  # Not a dimension of the table. A reader told "Eye" for the value would be
  # given a level name where a number is.
  expect_equal(axes$z$label, "Pearson residual")
})

test_that("the caller's own axis labels win over the dimension names", {
  info <- layer_info_for(hair_eye(), list(xlab = "Hair colour", ylab = "Eye colour"))

  axes <- BaseRAssocplotLayerProcessor$new(info)$extract_axis_titles(info)

  expect_equal(axes$x$label, "Hair colour")
  expect_equal(axes$y$label, "Eye colour")
})

test_that("a cell with no expectation is 0 rather than NaN", {
  # A zero margin makes the expected count zero and the residual 0/0.
  # `assocplot()` draws no tile there; the grid keeps the cell.
  table <- matrix(c(5, 0, 7, 0), nrow = 2,
                  dimnames = list(c("a", "b"), c("p", "q")))
  info <- layer_info_for(table)

  data <- BaseRAssocplotLayerProcessor$new(info)$extract_data(info)

  values <- unlist(data$points)
  expect_true(all(is.finite(values)))
  expect_equal(values[c(2, 4)], c(0, 0))
})

test_that("each cell is addressed on its own, bottom band last", {
  table <- hair_eye()
  info <- layer_info_for(table)
  processor <- BaseRAssocplotLayerProcessor$new(info)
  data <- processor$extract_data(info)

  selectors <- processor$generate_selectors(info, NULL, data)

  # `assocplot()` draws every cell into ONE rect grob -- measured, sixteen
  # rects in `graphics-plot-1-rect-1` -- bottom band first. The grid's first
  # row is the TOP band, so it addresses the LAST four rects.
  expect_length(selectors, 4)
  expect_equal(
    unlist(selectors[[1]]),
    paste0("g#graphics-plot-1-rect-1 > rect:nth-of-type(", 13:16, ")")
  )
  expect_equal(
    unlist(selectors[[4]]),
    paste0("g#graphics-plot-1-rect-1 > rect:nth-of-type(", 1:4, ")")
  )
})

test_that("a table that is not two-way is declined rather than flattened", {
  info <- layer_info_for(HairEyeColor)

  data <- BaseRAssocplotLayerProcessor$new(info)$extract_data(info)

  expect_equal(data$points, list())
})

test_that("an association plot renders interactively rather than as a picture", {
  skip_on_cran()
  file <- withr::local_tempfile(fileext = ".html")

  warnings <- character()
  withCallingHandlers({
    assocplot(hair_eye())
    maidr::save_html(file = file)
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  html <- gsub("&quot;", '"', paste(readLines(file, warn = FALSE), collapse = "\n"),
               fixed = TRUE)

  # Not a static image, and silent: gridSVG warns on a rect drawn with a
  # negative height, which is every tile below expectation, and a plot that
  # warns falls back to a picture.
  expect_equal(warnings, character())
  expect_true(grepl('"type":"heat"', html, fixed = TRUE))
  # One drawn rect per cell.
  expect_equal(length(gregexpr("<rect", html)[[1]]), 16)
})
