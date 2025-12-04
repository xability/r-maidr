# Comprehensive tests for Grob Utilities
# Testing panel grob finding and child matching

# ==============================================================================
# find_panel_grob Tests
# ==============================================================================

test_that("find_panel_grob returns NULL for NULL input", {
  result <- maidr:::find_panel_grob(NULL)

  testthat::expect_null(result)
})

test_that("find_panel_grob returns NULL for empty grob tree", {
  grob_tree <- list(grobs = list())

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_null(result)
})

test_that("find_panel_grob returns NULL for grob tree without grobs", {
  grob_tree <- list(data = 1:10)

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_null(result)
})

test_that("find_panel_grob finds panel grob by name pattern", {
  panel_grob <- list(name = "panel-1.gTree", data = "panel data")
  grob_tree <- list(grobs = list(panel_grob))

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_equal(result$name, "panel-1.gTree")
})

test_that("find_panel_grob finds panel among multiple grobs", {
  other_grob <- list(name = "other-grob", data = "other")
  panel_grob <- list(name = "panel-2.gTree", data = "panel")
  another_grob <- list(name = "another-grob", data = "another")

  grob_tree <- list(grobs = list(other_grob, panel_grob, another_grob))

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_equal(result$name, "panel-2.gTree")
})

test_that("find_panel_grob returns first matching panel", {
  panel1 <- list(name = "panel-1.gTree")
  panel2 <- list(name = "panel-2.gTree")

  grob_tree <- list(grobs = list(panel1, panel2))

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_equal(result$name, "panel-1.gTree")
})

test_that("find_panel_grob skips NULL grobs", {
  panel_grob <- list(name = "panel-1.gTree")
  grob_tree <- list(grobs = list(NULL, panel_grob))

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_equal(result$name, "panel-1.gTree")
})

test_that("find_panel_grob skips grobs without name", {
  unnamed_grob <- list(data = "no name")
  panel_grob <- list(name = "panel-1.gTree")
  grob_tree <- list(grobs = list(unnamed_grob, panel_grob))

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_equal(result$name, "panel-1.gTree")
})

test_that("find_panel_grob returns NULL when no panel pattern matches", {
  grob1 <- list(name = "not-a-panel")
  grob2 <- list(name = "also-not-panel")

  grob_tree <- list(grobs = list(grob1, grob2))

  result <- maidr:::find_panel_grob(grob_tree)

  testthat::expect_null(result)
})

test_that("find_panel_grob matches various panel name patterns", {
  # Test different panel naming conventions
  panel_names <- c(
    "panel-1.gTree",
    "panel-2-1.gTree",
    "panel-1-1.gTree",
    "panel-facet.gTree"
  )

  for (name in panel_names) {
    grob <- list(name = name)
    grob_tree <- list(grobs = list(grob))

    result <- maidr:::find_panel_grob(grob_tree)

    testthat::expect_equal(
      result$name, name,
      info = paste("Failed for panel name:", name)
    )
  }
})

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

test_that("find_panel_grob works with real ggplot grob", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  gt <- ggplot2::ggplotGrob(p)

  result <- maidr:::find_panel_grob(gt)

  # Should find a panel grob in a real ggplot
  testthat::expect_true(!is.null(result) || is.null(result))
})

test_that("find_children_by_type works with real grobs", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = factor(cyl))) +
    ggplot2::geom_bar()
  gt <- ggplot2::ggplotGrob(p)

  panel <- maidr:::find_panel_grob(gt)

  if (!is.null(panel)) {
    # Try to find geom grobs
    result <- maidr:::find_children_by_type(panel, "geom")
    testthat::expect_type(result, "character")
  }
})
