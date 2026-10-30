# A heatmap's tiles are read from the values ggplot2 drew them from.
#
# ggplot2 evaluates each aesthetic in the layer's data, so
# `aes(fill = score * 2)` draws each tile from twice its score. maidr looked
# each value up as a column named after its mapping instead: "score * 2"
# names none, so every cell was read missing, and an expression for x or y,
# or a geom_tile() drawn from data of its own, stopped `show()` and
# `save_html()` with "attempt to set an attribute on NULL".

scores <- expand.grid(x = c("a", "b", "c"), y = c("p", "q"), stringsAsFactors = FALSE)
scores$score <- c(1, 2, 3, 4, 5, 6)

#' Each panel's cells, as a y-by-x matrix named by the axis labels
heat_cells <- function(plot) {
  figure <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  lapply(unlist(figure$subplots, recursive = FALSE), function(cell) {
    data <- cell$layers[[1]]$data
    matrix(
      unlist(data$points),
      nrow = length(data$y), byrow = TRUE,
      dimnames = list(unlist(data$y), unlist(data$x))
    )
  })
}

#' The cells `scores` draws, read through `transform`
expected_cells <- function(transform = identity, x = c("a", "b", "c")) {
  matrix(
    transform(c(4, 5, 6, 1, 2, 3)),
    nrow = 2, byrow = TRUE, dimnames = list(c("q", "p"), x)
  )
}

test_that("a heatmap filled by an expression is read with the values it was drawn from", {
  tiles <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = score * 2)) + ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(tiles), list(expected_cells(function(s) s * 2)))

  logged <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = log(score))) + ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(logged), list(expected_cells(log)))

  raster <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = score / 10)) + ggplot2::geom_raster()
  testthat::expect_equal(heat_cells(raster), list(expected_cells(function(s) s / 10)))
})

test_that("a heatmap with an expression for an axis is read with that axis' levels", {
  upper <- ggplot2::ggplot(scores, ggplot2::aes(toupper(x), y, fill = score)) + ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(upper), list(expected_cells(x = c("A", "B", "C"))))

  reordered <- ggplot2::ggplot(
    scores, ggplot2::aes(factor(x, levels = c("c", "b", "a")), y, fill = score)
  ) + ggplot2::geom_tile()
  testthat::expect_equal(
    heat_cells(reordered),
    list(expected_cells()[, c("c", "b", "a")])
  )
})

test_that("a heatmap layer is read from its own data and its own mapping", {
  own_data <- ggplot2::ggplot() +
    ggplot2::geom_tile(data = scores, ggplot2::aes(x, y, fill = score))
  testthat::expect_equal(heat_cells(own_data), list(expected_cells()))

  # Not inheriting the plot's mapping, the layer draws from its own.
  own_mapping <- ggplot2::ggplot(scores, ggplot2::aes(y, x, fill = -score)) +
    ggplot2::geom_tile(ggplot2::aes(x, y, fill = score + 100), inherit.aes = FALSE)
  testthat::expect_equal(heat_cells(own_mapping), list(expected_cells(function(s) s + 100)))
})

test_that("each panel of a faceted heatmap is read from its own rows", {
  panels <- rbind(
    transform(scores, panel = "one"),
    transform(scores, panel = "two", score = score * 10)
  )
  plot <- ggplot2::ggplot(panels, ggplot2::aes(x, y, fill = score / 2)) +
    ggplot2::geom_tile() +
    ggplot2::facet_wrap(~panel)
  testthat::expect_equal(
    heat_cells(plot),
    list(expected_cells(function(s) s / 2), expected_cells(function(s) s * 5))
  )
})

test_that("a pronoun, a constant and a value the stat computes are read as ggplot2 reads them", {
  # `.data$score` names the column as plainly as `score` does.
  pronoun <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = .data$score)) + ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(pronoun), list(expected_cells()))

  # A constant is every tile's value.
  constant <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = 5)) + ggplot2::geom_tile()
  testthat::expect_equal(heat_cells(constant), list(expected_cells(function(s) rep(5, length(s)))))

  # `group` is computed by the stat and is no column of the layer's data, so
  # the cells are read as missing rather than guessed.
  computed <- ggplot2::ggplot(scores, ggplot2::aes(x, y, fill = ggplot2::after_stat(group))) +
    ggplot2::geom_tile()
  testthat::expect_true(all(is.na(unlist(heat_cells(computed)))))
})
