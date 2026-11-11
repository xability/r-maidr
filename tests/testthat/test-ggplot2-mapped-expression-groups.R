# Bars and areas grouped by an expression of the data are read as their
# legend shows them.
#
# `aes(fill = factor(wt %% 2))` maps an expression, and the stacked bar and
# area processors took the argument of `factor()` for a column's name. Made
# a string, the expression was one per part, "%%", "wt" and "2", and testing
# them against the data's names stopped `show()` and `save_html()` with
# "'length = 3' in coercion to 'logical(1)'": stacked, filled and counted
# bars, and stacked areas, by fill or by x. A dodged bar evaluates its
# mappings and was read.

pts <- data.frame(
  g = rep(c("a", "b", "c"), each = 2),
  wt = 1:6,
  n = c(3, 5, 2, 4, 6, 1),
  yr = c(2001, 2001, 2002, 2002, 2003, 2003)
)
# The expression's values as a column of their own.
pts$h <- factor(pts$wt %% 2)

#' The first layer the plot is read as
first_layer <- function(plot) {
  maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]
}

#' A layer's points as JSON, to compare two layers' readings whole
points_json <- function(layer) {
  as.character(jsonlite::toJSON(layer$data, auto_unbox = TRUE, digits = NA))
}

test_that("a mapping names its column, or none where it is an expression", {
  testthat::expect_identical(maidr:::mapping_column(quote(cyl)), "cyl")
  testthat::expect_identical(maidr:::mapping_column(quote(factor(cyl))), "cyl")
  testthat::expect_identical(maidr:::mapping_column(ggplot2::aes(fill = factor(cyl))$fill), "cyl")
  testthat::expect_identical(maidr:::mapping_column(quote(factor(wt %% 2))), "factor(wt%%2)")
  testthat::expect_identical(maidr:::mapping_column(quote(factor(-wt))), "factor(-wt)")
  testthat::expect_null(maidr:::mapping_column(NULL))
})

test_that("bars filled by an expression are read as when it is a column", {
  charts <- list(
    stacked = function(fill) {
      ggplot2::ggplot(pts, ggplot2::aes(g, n, fill = {{ fill }})) + ggplot2::geom_col()
    },
    filled = function(fill) {
      ggplot2::ggplot(pts, ggplot2::aes(g, n, fill = {{ fill }})) +
        ggplot2::geom_col(position = "fill")
    },
    counted = function(fill) {
      ggplot2::ggplot(pts, ggplot2::aes(g, fill = {{ fill }})) + ggplot2::geom_bar()
    }
  )
  for (kind in names(charts)) {
    by_expression <- first_layer(charts[[kind]](factor(wt %% 2)))
    by_column <- first_layer(charts[[kind]](h))
    testthat::expect_identical(points_json(by_expression), points_json(by_column), info = kind)
    testthat::expect_identical(by_expression$axes$z$label, "factor(wt%%2)", info = kind)
  }
  # The legend's names, "0" and "1", name the series.
  stacked <- first_layer(charts$stacked(factor(wt %% 2)))
  testthat::expect_setequal(vapply(stacked$data, function(series) series[[1]]$z, ""), c("0", "1"))
})

test_that("a stack's rows are drawn in one order, its fill a column or an expression", {
  # ggplot2 draws a stack's rects in the order of its rows, and the series
  # are paired with the rects in that order: unsorted, the highlight of the
  # "1" series fell on the "0" rects.
  processor <- maidr:::Ggplot2StackedBarProcessor$new(list(index = 1L))
  drawn_order <- function(fill) {
    plot <- ggplot2::ggplot(pts, ggplot2::aes(g, n, fill = {{ fill }})) + ggplot2::geom_col()
    processor$reorder_layer_data(pts, plot)$wt
  }
  testthat::expect_identical(drawn_order(h), c(2L, 1L, 4L, 3L, 6L, 5L))
  testthat::expect_identical(drawn_order(factor(wt %% 2)), drawn_order(h))
})

test_that("bars whose categories are an expression are read as when it is a column", {
  pts$third <- factor(pts$wt %% 3)
  by_expression <- first_layer(
    ggplot2::ggplot(pts, ggplot2::aes(factor(wt %% 3), n, fill = h)) + ggplot2::geom_col()
  )
  by_column <- first_layer(
    ggplot2::ggplot(pts, ggplot2::aes(third, n, fill = h)) + ggplot2::geom_col()
  )
  testthat::expect_identical(points_json(by_expression), points_json(by_column))
})

test_that("areas filled by an expression name their series as its legend does", {
  by_expression <- first_layer(
    ggplot2::ggplot(pts, ggplot2::aes(yr, n, fill = factor(wt %% 2))) + ggplot2::geom_area()
  )
  by_column <- first_layer(
    ggplot2::ggplot(pts, ggplot2::aes(yr, n, fill = h)) + ggplot2::geom_area()
  )
  testthat::expect_identical(points_json(by_expression), points_json(by_column))
  testthat::expect_identical(
    vapply(by_expression$data, function(series) series[[1]]$z, ""),
    c("0", "1")
  )
})

test_that("a chart grouped by an expression is written as a chart", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(pts, ggplot2::aes(g, n, fill = factor(wt %% 2))) + ggplot2::geom_col()
  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  testthat::expect_identical(schema_from(html)$subplots[[1]][[1]]$layers[[1]]$type, "stacked_bar")
})
