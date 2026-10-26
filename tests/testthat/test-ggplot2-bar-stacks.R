# A bar drawn as a stack of segments is read as one bar
#
# `ggplot(mtcars, aes(factor(cyl), mpg)) + geom_bar(stat = "identity")`, the
# chart the getting-started vignette shows, draws three bars: `geom_bar()` and
# `geom_col()` stack the rows that share a category, and with nothing mapped
# to `fill` every segment is drawn alike. ggplot2 keeps one built row per
# segment, and the bar processor took each for a bar: maidr.js was handed 32
# bars, the first three labelled 4, 6 and 8 by position (each belonging to
# another row), the other 29 with no category ("factor(cyl) is missing"), and
# every value the running total of its stack.
#
# Each stack is now one bar, its value the sum of its segments, and the export
# draws an invisible rect over each stack for the highlight to name, since the
# segments are more rects than there are bars.

skip_slow_file_on_cran()

stack_plot <- function() {
  ggplot2::ggplot(mtcars, ggplot2::aes(x = factor(cyl), y = mpg)) +
    ggplot2::geom_bar(stat = "identity")
}

bar_points <- function(data) {
  vapply(data, function(p) sprintf("%s=%g", p$x, p$y), character(1))
}

# The elements a `#id rect` selector names in a rendering.
selected_rects <- function(html, selector) {
  id <- sub(" rect$", "", sub("^#", "", gsub("\\", "", selector, fixed = TRUE)))
  doc <- xml2::read_html(html)
  xml2::xml_find_all(doc, sprintf("//*[@id='%s']/rect", id))
}

test_that("a stack of segments is read as one bar, its value the stack's total", {
  plot <- stack_plot()
  processor <- maidr:::Ggplot2BarLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(plot, ggplot2::ggplot_build(plot))

  totals <- tapply(mtcars$mpg, mtcars$cyl, sum)
  expect_equal(bar_points(data), sprintf("%s=%g", names(totals), totals))
})

test_that("a stack below zero counts its negative segments down", {
  # ggplot2 stacks a category's negative segments down from zero and its
  # positive ones up, so "a" is drawn from -2 to 3. One value cannot say
  # both ends; the bar is read as the sum of its segments, 1, the total a
  # stacked bar adds up to, as for an all-negative stack, -1.
  frame <- data.frame(g = c("a", "a", "b", "b", "c"), v = c(3, -2, 5, 4, -1))
  plot <- ggplot2::ggplot(frame, ggplot2::aes(g, v)) + ggplot2::geom_col()
  processor <- maidr:::Ggplot2BarLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(plot, ggplot2::ggplot_build(plot))

  expect_equal(bar_points(data), c("a=1", "b=9", "c=-1"))
})

test_that("a segment with no value is no part of its bar", {
  # ggplot2 draws no rect for a missing value, and says so: "Removed 1 rows
  # containing missing values". The bar is the segments it drew, and each
  # outline spans only those.
  skip_if_not_installed("xml2")
  frame <- data.frame(g = c("a", "a", "a", "b", "b"), v = c(3, NA, 2, 5, 4))
  plot <- ggplot2::ggplot(frame, ggplot2::aes(g, v)) + ggplot2::geom_col()
  html <- rendered(plot)
  layer <- layers_from(html)[[1]]

  expect_equal(bar_points(layer$data), c("a=5", "b=9"))
  heights <- as.numeric(xml2::xml_attr(selected_rects(html, layer$selectors), "height"))
  expect_equal(heights / heights[2], c(5, 9) / 9, tolerance = 1e-3)
})

test_that("a built row drawn as no rect is left out of its stack", {
  # ggplot2 3.4.4 drops the missing row while it stacks. Kept in the built
  # data, as a build that drops it only when drawing would keep it, the row
  # has no rect, so counting it in its stack would put every later rect of
  # the panel one place out: "b" would be outlined over rects 4 and 5, of
  # which the rect grob has four.
  frame <- data.frame(g = c("a", "a", "b", "b"), v = c(3, 2, 5, 4))
  plot <- ggplot2::ggplot(frame, ggplot2::aes(g, v)) + ggplot2::geom_col()
  built <- ggplot2::ggplot_build(plot)
  rows <- built$data[[1]]
  missing <- rows[1, ]
  missing$y <- NA
  missing$ymin <- NA
  missing$ymax <- NA
  built$data[[1]] <- rbind(rows[1, ], missing, rows[-1, ])
  processor <- maidr:::Ggplot2BarLayerProcessor$new(list(index = 1))

  expect_equal(bar_points(processor$extract_data(plot, built)), c("a=5", "b=9"))
  # The rects of the drawn rows, in the order the rect grob holds them.
  expect_equal(processor$stack_rows(plot, built), list(1:2, 3:4))
})

test_that("a horizontal stack is read along y, one bar per category", {
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(y = factor(cyl), x = mpg)) +
    ggplot2::geom_col()
  layers <- layers_from(rendered(plot))

  expect_equal(layers[[1]]$orientation, "horz")
  expect_equal(
    vapply(layers[[1]]$data, function(p) sprintf("%s=%g", p$y, p$x), ""),
    c("4=293.3", "6=138.2", "8=211.4")
  )
})

test_that("bars of one row each keep their rects as their selectors", {
  plot <- ggplot2::ggplot(
    data.frame(x = c("a", "b"), y = c(1, 2)),
    ggplot2::aes(x, y)
  ) + ggplot2::geom_col()
  html <- rendered(plot)
  layer <- layers_from(html)[[1]]

  expect_match(layer$selectors, "^#geom_rect\\\\\\.rect\\\\\\.[0-9]+\\\\\\.1 rect$")
  expect_false(grepl(".stacked.", html, fixed = TRUE))
})

test_that("each stack gets one invisible rect spanning it, which the selector names", {
  skip_if_not_installed("xml2")
  html <- rendered(stack_plot())
  layer <- layers_from(html)[[1]]

  expect_length(layer$data, 3)
  expect_null(layer$.bar_stacks)
  expect_false(grepl("bar_stacks", html, fixed = TRUE))

  outlines <- selected_rects(html, layer$selectors)
  expect_length(outlines, 3)
  expect_equal(xml2::xml_attr(outlines, "fill"), rep("none", 3))
  expect_equal(xml2::xml_attr(outlines, "stroke"), rep("none", 3))

  # The segments are still drawn as they were, one rect per car, and each
  # outline is as tall as the segments it covers.
  segments <- xml2::xml_find_all(
    xml2::read_html(html),
    "//*[contains(@id, 'geom_rect.rect.') and not(contains(@id, 'bars'))]/rect"
  )
  expect_length(segments, nrow(mtcars))
  heights <- as.numeric(xml2::xml_attr(outlines, "height"))
  totals <- as.numeric(tapply(mtcars$mpg, mtcars$cyl, sum))
  expect_equal(heights / heights[1], totals / totals[1], tolerance = 1e-3)
  # In reading order: left to right.
  expect_false(is.unsorted(as.numeric(xml2::xml_attr(outlines, "x"))))
})

test_that("each facet panel reads its own stacks and names its own outlines", {
  skip_if_not_installed("xml2")
  plot <- stack_plot() + ggplot2::facet_wrap(~am)
  html <- rendered(plot)
  schema <- schema_from(html)
  layers <- list(
    schema$subplots[[1]][[1]]$layers[[1]],
    schema$subplots[[1]][[2]]$layers[[1]]
  )

  for (k in 1:2) {
    rows <- mtcars[mtcars$am == k - 1, ]
    totals <- tapply(rows$mpg, rows$cyl, sum)
    expect_equal(
      bar_points(layers[[k]]$data),
      sprintf("%s=%g", names(totals), totals)
    )
    expect_length(selected_rects(html, layers[[k]]$selectors), length(totals))
  }
  expect_false(identical(layers[[1]]$selectors, layers[[2]]$selectors))
})
