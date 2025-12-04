# Comprehensive tests for Base R Selector Utilities
# Testing robust grob searching and CSS selector generation

# ==============================================================================
# find_graphics_plot_grob Tests
# ==============================================================================

test_that("find_graphics_plot_grob finds matching grob name", {
  grob <- list(name = "graphics-plot-1-rect-1")

  result <- maidr:::find_graphics_plot_grob(grob, "rect")

  testthat::expect_equal(result, "graphics-plot-1-rect-1")
})

test_that("find_graphics_plot_grob returns NULL for non-matching grob", {
  grob <- list(name = "other-grob-name")

  result <- maidr:::find_graphics_plot_grob(grob, "rect")

  testthat::expect_null(result)
})

test_that("find_graphics_plot_grob matches different element types", {
  grob_rect <- list(name = "graphics-plot-1-rect-1")
  grob_lines <- list(name = "graphics-plot-2-lines-1")
  grob_points <- list(name = "graphics-plot-3-points-1")

  testthat::expect_equal(
    maidr:::find_graphics_plot_grob(grob_rect, "rect"),
    "graphics-plot-1-rect-1"
  )
  testthat::expect_equal(
    maidr:::find_graphics_plot_grob(grob_lines, "lines"),
    "graphics-plot-2-lines-1"
  )
  testthat::expect_equal(
    maidr:::find_graphics_plot_grob(grob_points, "points"),
    "graphics-plot-3-points-1"
  )
})

test_that("find_graphics_plot_grob respects plot_index", {
  # grob with plot index 1
  grob1 <- list(name = "graphics-plot-1-rect-1")
  # grob with plot index 2
  grob2 <- list(name = "graphics-plot-2-rect-1")

  testthat::expect_equal(
    maidr:::find_graphics_plot_grob(grob1, "rect", plot_index = 1),
    "graphics-plot-1-rect-1"
  )

  testthat::expect_null(
    maidr:::find_graphics_plot_grob(grob1, "rect", plot_index = 2)
  )

  testthat::expect_equal(
    maidr:::find_graphics_plot_grob(grob2, "rect", plot_index = 2),
    "graphics-plot-2-rect-1"
  )
})

test_that("find_graphics_plot_grob searches gList recursively", {
  grob <- structure(
    list(
      list(name = "other-grob"),
      list(name = "graphics-plot-1-rect-2")
    ),
    class = "gList"
  )

  result <- maidr:::find_graphics_plot_grob(grob, "rect")

  testthat::expect_equal(result, "graphics-plot-1-rect-2")
})

test_that("find_graphics_plot_grob searches gTree children", {
  grob <- structure(
    list(
      name = "parent-grob",
      children = list(
        list(name = "child-1"),
        list(name = "graphics-plot-3-lines-1")
      )
    ),
    class = c("gTree", "grob")
  )

  result <- maidr:::find_graphics_plot_grob(grob, "lines")

  testthat::expect_equal(result, "graphics-plot-3-lines-1")
})

test_that("find_graphics_plot_grob searches grobs field", {
  grob <- list(
    name = "container",
    grobs = list(
      list(name = "other"),
      list(name = "graphics-plot-1-points-1")
    )
  )

  result <- maidr:::find_graphics_plot_grob(grob, "points")

  testthat::expect_equal(result, "graphics-plot-1-points-1")
})

test_that("find_graphics_plot_grob handles NULL grob", {
  result <- maidr:::find_graphics_plot_grob(NULL, "rect")

  testthat::expect_null(result)
})

test_that("find_graphics_plot_grob handles grob without name", {
  grob <- list(data = 1:10)

  result <- maidr:::find_graphics_plot_grob(grob, "rect")

  testthat::expect_null(result)
})

# ==============================================================================
# generate_robust_css_selector Tests
# ==============================================================================

test_that("generate_robust_css_selector creates valid selector", {
  result <- maidr:::generate_robust_css_selector(
    "graphics-plot-1-rect-1",
    "rect"
  )

  testthat::expect_type(result, "character")
  testthat::expect_true(grepl("rect", result))
  testthat::expect_true(grepl("graphics-plot-1-rect-1", result))
})

test_that("generate_robust_css_selector escapes dots", {
  result <- maidr:::generate_robust_css_selector(
    "graphics-plot-1-rect-1",
    "rect"
  )

  # Should have escaped dots for CSS
  testthat::expect_true(grepl("\\\\\\.1", result))
})

test_that("generate_robust_css_selector returns NULL for NULL input", {
  testthat::expect_null(
    maidr:::generate_robust_css_selector(NULL, "rect")
  )
})

test_that("generate_robust_css_selector returns NULL for empty string", {
  testthat::expect_null(
    maidr:::generate_robust_css_selector("", "rect")
  )
})

test_that("generate_robust_css_selector returns NULL for zero-length input", {
  testthat::expect_null(
    maidr:::generate_robust_css_selector(character(0), "rect")
  )
})

test_that("generate_robust_css_selector works with different element types", {
  rect_sel <- maidr:::generate_robust_css_selector(
    "graphics-plot-1-rect-1",
    "rect"
  )
  polyline_sel <- maidr:::generate_robust_css_selector(
    "graphics-plot-1-lines-1",
    "polyline"
  )
  circle_sel <- maidr:::generate_robust_css_selector(
    "graphics-plot-1-points-1",
    "circle"
  )

  testthat::expect_true(grepl("^rect", rect_sel))
  testthat::expect_true(grepl("^polyline", polyline_sel))
  testthat::expect_true(grepl("^circle", circle_sel))
})

# ==============================================================================
# generate_robust_selector Tests
# ==============================================================================

test_that("generate_robust_selector returns selector for matching grob", {
  grob <- list(name = "graphics-plot-1-rect-1")

  result <- maidr:::generate_robust_selector(grob, "rect", "rect")

  testthat::expect_type(result, "character")
  testthat::expect_true(grepl("rect", result))
})

test_that("generate_robust_selector returns NULL for non-matching grob", {
  grob <- list(name = "other-grob")

  result <- maidr:::generate_robust_selector(grob, "rect", "rect")

  testthat::expect_null(result)
})

test_that("generate_robust_selector respects plot_index", {
  grob <- list(name = "graphics-plot-2-rect-1")

  # Should find when plot_index matches
  result_match <- maidr:::generate_robust_selector(
    grob, "rect", "rect",
    plot_index = 2
  )
  testthat::expect_true(!is.null(result_match))

  # Should not find when plot_index doesn't match
  result_nomatch <- maidr:::generate_robust_selector(
    grob, "rect", "rect",
    plot_index = 1
  )
  testthat::expect_null(result_nomatch)
})

test_that("generate_robust_selector applies max_elements limit", {
  grob <- list(name = "graphics-plot-1-rect-1")

  result <- maidr:::generate_robust_selector(
    grob, "rect", "rect",
    max_elements = 5
  )

  testthat::expect_true(grepl(":nth-child\\(-n\\+5\\)", result))
})

test_that("generate_robust_selector ignores max_elements when 0", {
  grob <- list(name = "graphics-plot-1-rect-1")

  result <- maidr:::generate_robust_selector(
    grob, "rect", "rect",
    max_elements = 0
  )

  # Should return base selector without :nth-child
  testthat::expect_false(grepl(":nth-child", result))
})

test_that("generate_robust_selector ignores max_elements when NULL", {
  grob <- list(name = "graphics-plot-1-rect-1")

  result <- maidr:::generate_robust_selector(
    grob, "rect", "rect",
    max_elements = NULL
  )

  testthat::expect_false(grepl(":nth-child", result))
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Deeply nested grob structures are searched", {
  grob <- structure(
    list(
      name = "level1",
      children = list(
        structure(
          list(
            name = "level2",
            children = list(
              list(name = "graphics-plot-1-rect-1")
            )
          ),
          class = c("gTree", "grob")
        )
      )
    ),
    class = c("gTree", "grob")
  )

  result <- maidr:::find_graphics_plot_grob(grob, "rect")

  testthat::expect_equal(result, "graphics-plot-1-rect-1")
})

test_that("First matching grob is returned when multiple exist", {
  grob <- structure(
    list(
      list(name = "graphics-plot-1-rect-1"),
      list(name = "graphics-plot-2-rect-1")
    ),
    class = "gList"
  )

  result <- maidr:::find_graphics_plot_grob(grob, "rect")

  testthat::expect_equal(result, "graphics-plot-1-rect-1")
})

test_that("Pattern matching is strict", {
  # Should not match partial patterns
  grob1 <- list(name = "graphics-plot-1-rect") # Missing trailing number
  grob2 <- list(name = "my-graphics-plot-1-rect-1") # Has prefix
  grob3 <- list(name = "graphics-plot-1-rect-1-extra") # Has suffix

  testthat::expect_null(maidr:::find_graphics_plot_grob(grob1, "rect"))
  testthat::expect_null(maidr:::find_graphics_plot_grob(grob2, "rect"))
  testthat::expect_null(maidr:::find_graphics_plot_grob(grob3, "rect"))
})
