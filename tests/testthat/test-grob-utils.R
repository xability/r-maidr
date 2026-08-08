# Comprehensive tests for Grob Utilities
# Testing child matching by grob name pattern

# ==============================================================================
# find_children_by_type Tests
# ==============================================================================

test_that("find_children_by_type returns empty for NULL parent", {
  result <- maidr:::find_children_by_type(NULL, "pattern")

  testthat::expect_type(result, "character")
  testthat::expect_equal(length(result), 0)
})

test_that("find_children_by_type returns empty for parent without children", {
  parent_grob <- list(data = "no children")

  result <- maidr:::find_children_by_type(parent_grob, "pattern")

  testthat::expect_type(result, "character")
  testthat::expect_equal(length(result), 0)
})

test_that("find_children_by_type returns empty for NULL children", {
  parent_grob <- list(children = NULL)

  result <- maidr:::find_children_by_type(parent_grob, "pattern")

  testthat::expect_type(result, "character")
  testthat::expect_equal(length(result), 0)
})

test_that("find_children_by_type returns empty when children have no names", {
  parent_grob <- list(children = list(1, 2, 3))

  result <- maidr:::find_children_by_type(parent_grob, "pattern")

  testthat::expect_type(result, "character")
  testthat::expect_equal(length(result), 0)
})

test_that("find_children_by_type finds matching children", {
  parent_grob <- list(
    children = list(
      rect_1 = list(data = 1),
      rect_2 = list(data = 2),
      line_1 = list(data = 3)
    )
  )

  result <- maidr:::find_children_by_type(parent_grob, "rect")

  testthat::expect_equal(length(result), 2)
  testthat::expect_true("rect_1" %in% result)
  testthat::expect_true("rect_2" %in% result)
})

test_that("find_children_by_type returns empty when no matches", {
  parent_grob <- list(
    children = list(
      line_1 = list(data = 1),
      point_1 = list(data = 2)
    )
  )

  result <- maidr:::find_children_by_type(parent_grob, "rect")

  testthat::expect_equal(length(result), 0)
})

test_that("find_children_by_type uses regex patterns", {
  parent_grob <- list(
    children = list(
      geom_bar_1 = list(data = 1),
      geom_bar_2 = list(data = 2),
      geom_point_1 = list(data = 3),
      bar_simple = list(data = 4)
    )
  )

  # Match "geom_bar" pattern
  result <- maidr:::find_children_by_type(parent_grob, "^geom_bar")

  testthat::expect_equal(length(result), 2)
  testthat::expect_true("geom_bar_1" %in% result)
  testthat::expect_true("geom_bar_2" %in% result)
})

test_that("find_children_by_type is case-sensitive", {
  parent_grob <- list(
    children = list(
      Rect = list(data = 1),
      rect = list(data = 2)
    )
  )

  result <- maidr:::find_children_by_type(parent_grob, "rect")

  testthat::expect_equal(length(result), 1)
  testthat::expect_true("rect" %in% result)
})

# ==============================================================================
# Integration Tests with ggplot2
# ==============================================================================

test_that("find_children_by_type works with real grobs", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = factor(cyl))) +
    ggplot2::geom_bar()
  gt <- ggplot2::ggplotGrob(p)

  panel <- maidr:::find_gtable_panel_grob(gt)

  if (!is.null(panel)) {
    # Try to find geom grobs
    result <- maidr:::find_children_by_type(panel, "geom")
    testthat::expect_type(result, "character")
  }
})
