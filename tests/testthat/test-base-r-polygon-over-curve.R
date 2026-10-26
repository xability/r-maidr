# A polygon that shades the area under a curve the chart reads is not data
#
# `d <- density(x); plot(d); polygon(d, col = ...)` is how Base R fills the
# area under a density curve, and the distribution article draws its Base R
# density that way. The polygon is drawn through the curve's own points, so
# it says nothing the curve does not, but it counted as an overlay maidr
# could not read: the whole chart was saved as a picture, with "This plot
# contains unsupported elements and is rendered as a static image", and a
# reader got no chart at all. It is now left out of the reading, as a legend
# is, and drawn as it was; a polygon that is not the curve still is.

skip_if_not_installed("xml2")
skip_if_not_installed("jsonlite")

# What `save_html()` exports for `draw()`: the HTML, and its layers.
polygon_export <- function(draw) {
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
  warned <- character(0)
  withCallingHandlers(
    suppressMessages(save_html(file = file)),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  list(
    html = html,
    warned = warned,
    layers = schema_from(html)$subplots[[1]][[1]]$layers
  )
}

ages <- local({
  set.seed(42)
  c(stats::rnorm(400, mean = 25, sd = 5), stats::rnorm(600, mean = 40, sd = 8))
})

test_that("a density filled with polygon() is read as its curve", {
  skip_if_no_render()
  d <- stats::density(ages)
  chart <- polygon_export(function() {
    plot(d, main = "Age Distribution", xlab = "Age", ylab = "Density")
    polygon(d, col = grDevices::rgb(0.678, 0.847, 0.902, 0.5), border = "steelblue")
  })

  expect_false(fell_back(chart$html))
  expect_length(chart$warned, 0)
  expect_length(chart$layers, 1)
  expect_equal(chart$layers[[1]]$type, "smooth")
  expect_equal(chart$layers[[1]]$axes$x$label, "Age")
  # The shading is still drawn.
  expect_match(chart$html, "graphics-plot-1-polygon-1", fixed = TRUE)
})

test_that("a curve drawn with lines() over a histogram is shaded the same way", {
  skip_if_no_render()
  d <- stats::density(ages)
  chart <- polygon_export(function() {
    hist(ages, freq = FALSE, main = "Ages")
    lines(d)
    polygon(d$x, d$y, col = grDevices::rgb(0, 0, 1, 0.2))
  })

  expect_false(fell_back(chart$html))
  expect_equal(
    vapply(chart$layers, function(layer) layer$type, ""),
    c("hist", "smooth")
  )
})

test_that("a polygon through a line's own points is read as the line", {
  skip_if_no_render()
  x <- 1:10
  y <- c(3, 5, 4, 6, 8, 7, 9, 8, 10, 9)
  chart <- polygon_export(function() {
    plot(x, y, type = "l")
    polygon(x, y, col = "grey")
  })

  expect_false(fell_back(chart$html))
  expect_equal(vapply(chart$layers, function(layer) layer$type, ""), "line")
})

test_that("a polygon that is not a curve of the chart is still not read", {
  skip_if_no_render()
  d <- stats::density(ages)
  chart <- polygon_export(function() {
    plot(d)
    polygon(c(10, 20, 30), c(0, 0.02, 0))
  })

  expect_true(fell_back(chart$html))
})

test_that("a polygon closed down to a baseline is not taken for the curve", {
  # It has points the curve does not: the baseline it is closed along.
  skip_if_no_render()
  d <- stats::density(ages)
  chart <- polygon_export(function() {
    plot(d)
    polygon(c(d$x, rev(d$x)), c(d$y, rep(0, length(d$y))), col = "grey")
  })

  expect_true(fell_back(chart$html))
})
