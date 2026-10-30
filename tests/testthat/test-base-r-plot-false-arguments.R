# A chart drawn from a call that only computes is read on the plot it drew
#
# `bxp(boxplot(count ~ spray, data = InsectSprays, plot = FALSE))` draws one
# plot: `boxplot()` only computes the summaries `bxp()` draws. Both are
# recorded calls, and the computing one was followed as a call that draws
# until the next call started -- after `bxp()` had started its plot, which was
# then taken for the computing call's. `bxp()` was recorded as having started
# no plot, and read as drawn on a plot after the last: every selector named
# `graphics-plot-2-...` on a page whose only plot is `graphics-plot-1`, and the
# box plot had no highlight. `barplot(hist(x, plot = FALSE)$counts)` was read
# the same way.

skip_if_not_installed("xml2")
skip_if_not_installed("jsonlite")

# The schema `save_html()` exports for `draw()`, and the ids of the drawing.
plot_false_export <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      clear_base_r_device(device_id)
      if (device_id %in% grDevices::dev.list()) grDevices::dev.off(device_id)
      unlink(file)
    },
    add = TRUE
  )
  draw()
  suppressWarnings(suppressMessages(save_html(file = file)))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  document <- xml2::read_html(file)
  subplots <- schema_from(html)$subplots
  list(
    layers = subplots[[1]][[1]]$layers,
    subplots = subplots,
    ids = xml2::xml_attr(xml2::xml_find_all(document, "//*[@id]"), "id")
  )
}

# The element ids a layer's selectors name, unescaped, without the part of a
# selector after the id.
named_ids <- function(layer) {
  flat <- unlist(layer$selectors, use.names = FALSE)
  ids <- unlist(regmatches(
    flat,
    gregexpr("graphics-plot-[0-9]+-[a-z]+-[0-9.\\\\]+[0-9]", flat)
  ))
  unique(gsub("\\\\", "", ids))
}

expect_named_on_plot_one <- function(chart, type) {
  expect_length(chart$layers, 1L)
  layer <- chart$layers[[1]]
  expect_equal(layer$type, type)
  ids <- named_ids(layer)
  expect_gt(length(ids), 0L)
  expect_true(all(startsWith(ids, "graphics-plot-1-")), label = paste(ids, collapse = " "))
  for (id in ids) {
    expect_true(any(startsWith(chart$ids, id)), label = id)
  }
}

test_that("bxp() of a boxplot(plot = FALSE) is read on the plot it draws", {
  skip_if_no_render()
  chart <- plot_false_export(function() {
    bxp(boxplot(count ~ spray, data = InsectSprays, plot = FALSE))
  })
  expect_named_on_plot_one(chart, "box")
})

test_that("barplot() of a hist(plot = FALSE) is read on the plot it draws", {
  skip_if_no_render()
  chart <- plot_false_export(function() {
    barplot(hist(mtcars$mpg, plot = FALSE)$counts)
  })
  expect_named_on_plot_one(chart, "bar")
})

test_that("a plot of barplot(plot = FALSE)'s midpoints is read on the plot it draws", {
  # barplot() has a wrapper of its own, with its own computation-only
  # return.
  skip_if_no_render()
  heights <- c(3, 5, 2, 6)
  chart <- plot_false_export(function() {
    plot(barplot(heights, plot = FALSE), heights)
  })
  expect_named_on_plot_one(chart, "point")
})

test_that("the summaries computed first and drawn after are read the same way", {
  skip_if_no_render()
  nested <- plot_false_export(function() {
    bxp(boxplot(count ~ spray, data = InsectSprays, plot = FALSE))
  })
  apart <- plot_false_export(function() {
    z <- boxplot(count ~ spray, data = InsectSprays, plot = FALSE)
    bxp(z)
  })
  expect_equal(named_ids(nested$layers[[1]]), named_ids(apart$layers[[1]]))
  expect_equal(nested$layers[[1]]$data, apart$layers[[1]]$data)
})

test_that("in a grid, each panel is read on its own plot", {
  # Only the computing call is let go as it returns: the call it was made
  # for still starts its plot, and the panels around it keep theirs.
  skip_if_no_render()
  chart <- plot_false_export(function() {
    par(mfrow = c(1, 3))
    bxp(boxplot(count ~ spray, data = InsectSprays, plot = FALSE))
    hist(mtcars$mpg)
    barplot(hist(mtcars$hp, plot = FALSE)$counts)
  })

  cells <- chart$subplots[[1]]
  expect_length(cells, 3L)
  expect_equal(
    vapply(cells, function(cell) cell$layers[[1]]$type, character(1)),
    c("box", "hist", "bar")
  )
  for (k in seq_along(cells)) {
    ids <- named_ids(cells[[k]]$layers[[1]])
    expect_gt(length(ids), 0L)
    expect_true(
      all(startsWith(ids, paste0("graphics-plot-", k, "-"))),
      label = paste(ids, collapse = " ")
    )
    for (id in ids) {
      expect_true(any(startsWith(chart$ids, id)), label = id)
    }
  }
})
