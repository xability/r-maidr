# Base R titles and labels that are not one string, drawn as R draws them
#
# `i <- 3; plot(1:5, main = i)` was exported as an empty drawing: R draws a
# title given as a number, a logical, a vector of several values or a list,
# and gridGraphics, which draws the chart again for maidr, stopped on it
# ("Unrecognised text argument type"). It also drew a missing `mtext()` text
# or tick label as "NA", where R draws nothing. Each drawing here is held to
# R's own: the same code drawn by svglite on a page of the same size, every
# string compared with where and how it is drawn.

skip_if_not_installed("svglite")
skip_if_not_installed("xml2")

# Every string an SVG page draws: its text, position, anchor and style.
drawn_strings <- function(file) {
  page <- xml2::read_xml(file)
  texts <- xml2::xml_find_all(page, "//*[local-name()='text']")
  attribute <- function(name) xml2::xml_attr(texts, name, default = "")
  sort(paste(
    xml2::xml_text(texts),
    attribute("x"), attribute("y"), attribute("transform"),
    attribute("text-anchor"), attribute("style"),
    sep = " | "
  ))
}

svglite_page <- function(size, draw) {
  file <- tempfile(fileext = ".svg")
  svglite::svglite(
    file,
    width = size[["width"]], height = size[["height"]],
    bg = "transparent", pointsize = 12, fix_text_size = FALSE
  )
  draw()
  grDevices::dev.off()
  on.exit(unlink(file), add = TRUE)
  drawn_strings(file)
}

# R's drawing, with the graphical parameters maidr draws it with.
r_drawing <- function(draw, size) {
  svglite_page(size, maidr:::ggplotify_drawing(draw))
}

# maidr's drawing of the same code, as it is exported.
maidr_drawing <- function(draw, size) {
  drawing <- maidr:::base_r_drawing_grob(draw, size)
  svglite_page(size, function() {
    grid::grid.newpage()
    grid::grid.draw(drawing)
  })
}

expect_drawn_as_r <- function(draw, size = c(width = 7, height = 5)) {
  drawn <- r_drawing(draw, size)
  testthat::expect_gt(length(drawn), 0)
  testthat::expect_identical(maidr_drawing(draw, size), drawn)
}

test_that("a title given as a number, a logical or a classed value is drawn as R draws it", {
  values <- list(
    3, 1 / 3, 1e5, 3L, TRUE, 1 + 2i, NA, character(0),
    factor("level"), as.Date("2024-01-02")
  )
  for (value in values) {
    for (name in c("main", "sub", "xlab", "ylab")) {
      args <- stats::setNames(list(1:5, value), c("", name))
      expect_drawn_as_r(function() do.call(graphics::plot, args))
    }
  }

  expect_drawn_as_r(function() graphics::barplot(c(1, 2, 3), xlab = 2024))
  expect_drawn_as_r(function() graphics::hist(c(1, 2, 2, 3), main = 3, ylab = 1 / 3))
  expect_drawn_as_r(function() graphics::boxplot(c(1, 2, 2, 3), main = TRUE))
  expect_drawn_as_r(function() graphics::image(matrix(1:4, 2), main = 2024L))
  expect_drawn_as_r(function() graphics::pie(c(1, 2), main = 3))
  expect_drawn_as_r(function() graphics::dotchart(c(a = 1, b = 2), main = 3))
  expect_drawn_as_r(function() {
    graphics::plot(1:5, ann = FALSE)
    graphics::title(3, sub = 1 / 3)
  })
  expect_drawn_as_r(function() {
    graphics::par(oma = c(0, 0, 2, 0))
    graphics::plot(1:5)
    graphics::title(main = 2024, outer = TRUE)
  })
  expect_drawn_as_r(
    function() graphics::plot(1:5, main = 1 / 3, xlab = 2024, ylab = TRUE),
    size = c(width = 4, height = 3)
  )
})

test_that("a title of several values, or given as a list, is drawn as R draws it", {
  values <- list(
    c("first", "second"), c(1, 2), c("first", NA, "third"), factor(c("u", "v")),
    list("titled", font = 2), list(c("first", "second"), col = "red", cex = 1.5),
    list(font = 3, "titled")
  )
  for (value in values) {
    for (name in c("main", "sub", "xlab", "ylab")) {
      args <- stats::setNames(list(1:5, value), c("", name))
      expect_drawn_as_r(function() do.call(graphics::plot, args))
    }
  }

  # R draws the first of several expressions. gridGraphics warns of any
  # expression title as it reads it, which is its own reading of `title()`.
  suppressWarnings(expect_drawn_as_r(function() {
    graphics::plot(1:5, main = expression(alpha, beta), xlab = expression(x[1], x[2]))
  }))
  expect_drawn_as_r(function() {
    graphics::plot(1:5, ann = FALSE)
    graphics::title(main = c("a", "b"), xlab = c(1, 2), ylab = c("c", "d"), line = 3)
  })
  expect_drawn_as_r(function() {
    graphics::par(oma = c(4, 4, 3, 2))
    graphics::plot(1:5, ann = FALSE)
    graphics::title(
      main = c("a", "b"), sub = c("e", "f"), xlab = c("g", "h"), ylab = c("i", "j"),
      outer = TRUE
    )
  })
  expect_drawn_as_r(function() {
    graphics::par(mfrow = c(2, 2), las = 2, mex = 1.5, adj = 0)
    for (k in 1:4) {
      graphics::plot(1:5, main = c(k, k + 10), xlab = c("x", "y"), ylab = c(k, NA, "z"))
    }
  })
  expect_drawn_as_r(function() {
    graphics::barplot(
      c(1, 2), main = c(2024, 2025), cex.main = 2, col.main = "blue", font.main = 3
    )
  })
})

test_that("missing margin text and tick labels, and logical labels, are drawn as R draws them", {
  expect_drawn_as_r(function() {
    graphics::plot(1:5, axes = FALSE, ann = FALSE)
    graphics::mtext(c("a", NA), at = c(2, 4))
    graphics::mtext(c(1, NA), side = 1, at = c(2, 4))
  })
  expect_drawn_as_r(function() {
    graphics::plot(1:5, axes = FALSE, ann = FALSE)
    graphics::axis(1, at = 1:3, labels = c("a", NA, "c"))
    graphics::axis(2, at = 1:2, labels = c(1, NA))
  })
  # Logical labels are read by the first: TRUE labels the ticks, FALSE or
  # NA draws none.
  expect_drawn_as_r(function() {
    graphics::plot(1:5, axes = FALSE, ann = FALSE)
    graphics::axis(1, at = 1:2, labels = NA)
    graphics::axis(2, at = 1:2, labels = c(TRUE, FALSE))
    graphics::axis(3, at = 1:2, labels = c(NA, TRUE))
  })
})

test_that("a chart titled with a number is exported with its drawing", {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device_id), add = TRUE)
  clear_base_r_device(device_id)
  on.exit(clear_base_r_device(device_id), add = TRUE)

  exported <- function(draw) {
    clear_base_r_device(device_id)
    draw()
    file <- tempfile(fileext = ".html")
    on.exit(unlink(file), add = TRUE)
    suppressMessages(save_html(file = file))
    html <- paste(readLines(file, warn = FALSE), collapse = "\n")
    page <- xml2::read_html(file)
    list(
      text = sort(xml2::xml_text(xml2::xml_find_all(page, "//*[local-name()='text']"))),
      layer = layers_from(html)[[1]]
    )
  }
  r_text <- function(draw) {
    sub(" \\|.*$", "", r_drawing(draw, c(width = 7, height = 5)))
  }

  i <- 3
  chart <- exported(function() plot(1:5, main = i))
  testthat::expect_identical(chart$text, sort(r_text(function() graphics::plot(1:5, main = 3))))
  testthat::expect_true(length(unlist(chart$layer$selectors)) > 0)

  chart <- exported(function() barplot(c(1, 2, 3), xlab = 2024))
  testthat::expect_identical(
    chart$text,
    sort(r_text(function() graphics::barplot(c(1, 2, 3), xlab = 2024)))
  )
  testthat::expect_true(length(unlist(chart$layer$selectors)) > 0)
})

test_that("the title and axis titles announced are the text R draws", {
  schema <- function(draw) {
    grDevices::pdf(NULL)
    device_id <- grDevices::dev.cur()
    on.exit(
      {
        clear_base_r_device(device_id)
        grDevices::dev.off(device_id)
      },
      add = TRUE
    )
    clear_base_r_device(device_id)
    draw()
    maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
  }
  first_layer <- function(chart) chart$subplots[[1]][[1]]$layers[[1]]

  # R draws each value on a line of its own and leaves out a missing one.
  chart <- schema(function() {
    plot(
      1:5,
      main = c("Sales", NA, "2024"), sub = c(1, 2), xlab = factor(c("a", "b")),
      ylab = list(font = 2, "Units")
    )
  })
  testthat::expect_identical(chart$title, "Sales\n2024")
  testthat::expect_identical(chart$subtitle, "1\n2")
  testthat::expect_identical(first_layer(chart)$title, "Sales\n2024")
  testthat::expect_identical(first_layer(chart)$axes$x$label, "a\nb")
  testthat::expect_identical(first_layer(chart)$axes$y$label, "Units")

  chart <- schema(function() barplot(c(1, 2), main = 1 / 3, xlab = 2024, ylab = TRUE))
  testthat::expect_identical(first_layer(chart)$title, "0.333333333333333")
  testthat::expect_identical(first_layer(chart)$axes$x$label, "2024")
  testthat::expect_identical(first_layer(chart)$axes$y$label, "TRUE")

  chart <- schema(function() {
    interaction.plot(c(1, 1, 2, 2), c(1, 2, 1, 2), c(3, 4, 5, 6), xlab = 2024, ylab = c("m", "n"))
  })
  testthat::expect_identical(first_layer(chart)$axes$x$label, "2024")
  testthat::expect_identical(first_layer(chart)$axes$y$label, "m\nn")

  chart <- schema(function() monthplot(ts(1:24, frequency = 12), xlab = 2024L, ylab = TRUE))
  testthat::expect_identical(first_layer(chart)$axes$x$label, "2024")
  testthat::expect_identical(first_layer(chart)$axes$y$label, "TRUE")
})
