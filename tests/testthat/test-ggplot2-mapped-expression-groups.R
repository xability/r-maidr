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

  # By the levels the expression gives, as ggplot2 stacks them, not by name.
  pts$h_rev <- factor(pts$wt %% 2, levels = c("1", "0"))
  testthat::expect_identical(drawn_order(h_rev), 1:6)
  testthat::expect_identical(drawn_order(factor(wt %% 2, levels = c("1", "0"))), drawn_order(h_rev))
})

test_that("each facet panel of a stack filled by an expression is read as with a column", {
  # The rows are sorted across the whole layer, and ggplot2 draws each
  # panel's rects in its own rows' order: within a panel that is sorted by
  # category and fill too, as it is for a column.
  faceted <- data.frame(
    g = rep(rep(c("a", "b", "c"), each = 2), 2),
    am = rep(c(0, 1), each = 6),
    wt = 1:12,
    n = c(3, 5, 2, 4, 6, 1, 2, 3, 4, 5, 1, 6)
  )
  faceted$h <- factor(faceted$wt %% 2)
  chart <- function(fill) {
    ggplot2::ggplot(faceted, ggplot2::aes(g, n, fill = {{ fill }})) +
      ggplot2::geom_col() +
      ggplot2::facet_wrap(~am)
  }
  panels <- function(plot) {
    figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
    lapply(unlist(figure$subplots, recursive = FALSE), function(cell) cell$layers[[1]])
  }
  by_expression <- panels(chart(factor(wt %% 2)))
  by_column <- panels(chart(h))
  testthat::expect_length(by_expression, 2L)
  for (i in seq_along(by_expression)) {
    expression_points <- points_json(by_expression[[i]])
    testthat::expect_identical(expression_points, points_json(by_column[[i]]), info = i)
  }

  processor <- maidr:::Ggplot2StackedBarProcessor$new(list(index = 1L))
  sorted <- processor$reorder_layer_data(faceted, chart(factor(wt %% 2)))
  testthat::expect_identical(sorted$wt, processor$reorder_layer_data(faceted, chart(h))$wt)
  testthat::expect_identical(sorted$wt[sorted$am == 0], c(2L, 1L, 4L, 3L, 6L, 5L))
  testthat::expect_identical(sorted$wt[sorted$am == 1], c(8L, 7L, 10L, 9L, 12L, 11L))
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

  # An expression that is no factor makes a discrete scale too, as a
  # logical one does, and its bands are named "FALSE" and "TRUE" as its
  # legend names them.
  pts$odd <- pts$wt %% 2 == 1
  logical_expression <- first_layer(
    ggplot2::ggplot(pts, ggplot2::aes(yr, n, fill = wt %% 2 == 1)) + ggplot2::geom_area()
  )
  logical_column <- first_layer(
    ggplot2::ggplot(pts, ggplot2::aes(yr, n, fill = odd)) + ggplot2::geom_area()
  )
  testthat::expect_identical(points_json(logical_expression), points_json(logical_column))
  testthat::expect_identical(
    vapply(logical_expression$data, function(series) series[[1]]$z, ""),
    c("FALSE", "TRUE")
  )
})

#' Each band's heights, by the name it is read under
named_bands <- function(layer) {
  stats::setNames(
    lapply(layer$data, function(series) vapply(series, function(point) point$y, 0)),
    vapply(layer$data, function(series) series[[1]]$z, "")
  )
}

test_that("areas filled by an expression are named as drawn, whatever the scale's limits", {
  # ggplot2 numbers the groups from the fill's values, not from a scale's
  # `limits`. The band of even weights, 5, 4 and 1, is the "0" band however
  # the legend orders the levels, or lists one no row holds.
  for (limits in list(c("1", "0"), c("9", "0", "1"))) {
    layer <- first_layer(
      ggplot2::ggplot(pts, ggplot2::aes(yr, n, fill = factor(wt %% 2))) +
        ggplot2::geom_area() +
        ggplot2::scale_fill_discrete(limits = limits)
    )
    testthat::expect_identical(
      named_bands(layer),
      list(`0` = c(5, 4, 1), `1` = c(3, 2, 6))
    )
  }
})

test_that("areas filled by a factor are named as drawn, past a level no row holds", {
  # Levels a, b and c with no row of b: ggplot2 numbers the c band 2.
  frame <- data.frame(
    yr = rep(c(2001, 2002, 2003), 2),
    n = c(3, 2, 6, 5, 4, 1),
    k = factor(rep(c("a", "c"), each = 3), levels = c("a", "b", "c"))
  )
  layer <- first_layer(
    ggplot2::ggplot(frame, ggplot2::aes(yr, n, fill = k)) + ggplot2::geom_area()
  )

  testthat::expect_identical(named_bands(layer), list(a = c(3, 2, 6), c = c(5, 4, 1)))
})

test_that("a chart grouped by an expression is written as a chart", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(pts, ggplot2::aes(g, n, fill = factor(wt %% 2))) + ggplot2::geom_col()
  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  testthat::expect_identical(schema_from(html)$subplots[[1]][[1]]$layers[[1]]$type, "stacked_bar")
})
