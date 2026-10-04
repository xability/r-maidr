# The size a chart is laid out at.

test_that("a Base R chart is laid out on a page of the size it is drawn at", {
  testthat::skip_on_cran()
  # Base R sets a title in the top margin, a fixed distance below the top of
  # the page. Laid out on a page of another size and then stretched onto the
  # canvas, as ggplotify::as.grob() lays every drawing out on a 7 x 7 in
  # page, the distance stretched with it, and at 4 x 3 in the title was cut
  # off at the top.
  from_top <- function(size) {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    grob <- maidr:::base_r_drawing_grob(
      function() graphics::plot(1:10, main = "Title"),
      c(width = size[1], height = size[2])
    )
    svg <- svglite::svgstring(width = size[1], height = size[2])
    grid::grid.newpage()
    grid::grid.draw(grob)
    grDevices::dev.off()
    svg <- as.character(svg())
    title <- regmatches(svg, regexpr("<text[^>]*>Title</text>", svg))
    as.numeric(sub("^.*\\sy='([^']*)'.*$", "\\1", title))
  }
  distances <- vapply(list(c(4, 3), c(7, 5), c(10, 4), c(5, 8)), from_top, numeric(1))
  testthat::expect_true(all(abs(distances - distances[[1]]) < 0.5), info = toString(distances))
  testthat::expect_true(all(distances > 0))
})

test_that("drawn at 7 x 7 in, a Base R chart is the drawing ggplotify makes of it", {
  testthat::skip_on_cran()
  # base_r_drawing_grob() is ggplotify::as.grob() with the page sized; at
  # as.grob()'s own 7 x 7 in, the two draw the same.
  draw <- function() {
    graphics::plot(1:10, (1:10)^2, main = "Legend")
    graphics::legend("topleft", legend = c("first series", "second"), pch = 1:2)
  }
  svg_of <- function(grob) {
    svg <- svglite::svgstring(width = 7, height = 7)
    grid::grid.newpage()
    grid::grid.draw(grob)
    grDevices::dev.off()
    as.character(svg())
  }
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ours <- maidr:::base_r_drawing_grob(draw, c(width = 7, height = 7))
  theirs <- ggplotify::as.grob(draw)
  testthat::expect_identical(svg_of(ours), svg_of(theirs))
})
