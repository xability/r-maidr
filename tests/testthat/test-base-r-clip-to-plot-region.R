# A Base R chart is clipped to its plot region where R clips it
#
# maidr drew a Base R chart with the graphical parameters
# `ggplotify::as.grob()` sets, among them `xpd = NA`, which lets everything
# be drawn past the plot region. R draws a plot with `xpd = FALSE` unless the
# author says otherwise, and clips to the plot region: the spikes of
# `plot(type = "h")` ran from zero through the x axis and its labels to the
# edge of the chart, `abline()` and a density curve drawn with `lines()` ran
# across the axes, and the reader's highlight was drawn there too.

skip_if_not_installed("xml2")

# What `save_html()` exports for `draw()`, as an xml2 document.
clipped_export <- function(draw) {
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
  xml2::read_html(file)
}

# Whether the element whose id begins with `prefix` is drawn under a clip.
clipped <- function(doc, prefix) {
  element <- xml2::xml_find_first(doc, sprintf("//*[starts-with(@id, '%s')]", prefix))
  testthat::expect_false(inherits(element, "xml_missing"), label = prefix)
  ancestors <- xml2::xml_find_all(element, "ancestor-or-self::*[@clip-path]")
  length(ancestors) > 0
}

# The clip-path of the nearest element around `node` that has one, or NA.
clip_of <- function(node) {
  holder <- xml2::xml_find_first(node, "ancestor-or-self::*[@clip-path][1]")
  if (inherits(holder, "xml_missing")) NA_character_ else xml2::xml_attr(holder, "clip-path")
}

test_that("the spikes of plot(type = 'h') are clipped to the plot", {
  skip_if_no_render()
  doc <- clipped_export(function() {
    plot(1:8, c(2, 5, 3, 9, 4, 7, 6, 8), type = "h", main = "Spikes")
  })

  expect_true(clipped(doc, "graphics-plot-1-spike-"))
})

test_that("a line drawn over a plot is clipped to it", {
  skip_if_no_render()
  doc <- clipped_export(function() {
    plot(mtcars$wt, mtcars$mpg)
    abline(stats::lm(mpg ~ wt, data = mtcars), col = "red")
  })

  expect_true(clipped(doc, "graphics-plot-1-abline"))
})

test_that("a par(xpd = NA) the author set is drawn again", {
  skip_if_no_render()
  doc <- clipped_export(function() {
    plot(mtcars$wt, mtcars$mpg)
    par(xpd = NA)
    abline(h = 20, col = "red")
  })

  expect_false(clipped(doc, "graphics-plot-1-abline"))
})

test_that("a legend drawn with xpd = TRUE is not clipped to the plot", {
  # `legend(xpd = TRUE)` sets `xpd` as it draws, the usual way to put a
  # legend in the margin; it is clipped, if at all, to the figure.
  skip_if_no_render()
  doc <- clipped_export(function() {
    par(mar = c(5, 4, 4, 9))
    plot(mtcars$wt, mtcars$mpg)
    legend("topright", inset = c(-0.45, 0), legend = c("first", "second"), pch = 1:2, xpd = TRUE)
  })
  points <- xml2::xml_find_first(doc, "//*[starts-with(@id, 'graphics-plot-1-points')]")
  label <- xml2::xml_find_first(doc, "//*[local-name()='text'][contains(., 'second')]")

  expect_false(inherits(label, "xml_missing"))
  legend_clip <- clip_of(label)
  expect_true(is.na(legend_clip) || !identical(legend_clip, clip_of(points)))
})
