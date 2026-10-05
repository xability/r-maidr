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

# Every line an SVG page draws: where it runs, and its style. Ticks and axis
# lines are lines, which drawn_strings() does not see.
drawn_lines <- function(file) {
  page <- xml2::read_xml(file)
  lines <- xml2::xml_find_all(page, "//*[local-name()='line' or local-name()='polyline']")
  attribute <- function(name) xml2::xml_attr(lines, name, default = "")
  sort(paste(
    xml2::xml_name(lines),
    attribute("x1"), attribute("y1"), attribute("x2"), attribute("y2"),
    attribute("points"), attribute("style"),
    sep = " | "
  ))
}

svglite_page <- function(size, draw, read = drawn_strings) {
  file <- tempfile(fileext = ".svg")
  svglite::svglite(
    file,
    width = size[["width"]], height = size[["height"]],
    bg = "transparent", pointsize = 12, fix_text_size = FALSE
  )
  draw()
  grDevices::dev.off()
  on.exit(unlink(file), add = TRUE)
  read(file)
}

# R's drawing, with the graphical parameters maidr draws it with.
r_drawing <- function(draw, size, read = drawn_strings) {
  svglite_page(size, maidr:::ggplotify_drawing(draw), read)
}

# maidr's drawing of the same code, as it is exported.
maidr_drawing <- function(draw, size, read = drawn_strings) {
  drawing <- maidr:::base_r_drawing_grob(draw, size)
  svglite_page(size, function() {
    grid::grid.newpage()
    grid::grid.draw(drawing)
  }, read)
}

expect_drawn_as_r <- function(draw, size = c(width = 7, height = 5)) {
  drawn <- r_drawing(draw, size)
  testthat::expect_gt(length(drawn), 0)
  testthat::expect_identical(maidr_drawing(draw, size), drawn)
}

expect_lines_drawn_as_r <- function(draw, size = c(width = 7, height = 5)) {
  drawn <- r_drawing(draw, size, drawn_lines)
  testthat::expect_identical(maidr_drawing(draw, size, drawn_lines), drawn)
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

test_that("a list title's colour, font and size are read by their first value, as R reads them", {
  # title() was handed the whole vector ("graphical parameter "col.main" has
  # the wrong length"), and the chart fell back to a picture.
  expect_drawn_as_r(function() {
    graphics::plot(
      1:5,
      main = list("Speed", col = c("red", "blue")),
      sub = list("s", cex = c(2, 1)),
      xlab = list("x", col = c(NA, "blue")),
      ylab = list("y", font = c(2, 3))
    )
  })
  expect_drawn_as_r(function() {
    graphics::plot(1:5, main = list(c("a", "b"), col = c(2, 4), font = c(3, 1)))
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

# A chart exported through `save_html()`: the strings it draws, its layers,
# and the warnings the export gave.
exported_chart <- function(draw) {
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
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  warnings <- character(0)
  withCallingHandlers(
    suppressMessages(save_html(file = file)),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  page <- xml2::read_html(file)
  schema <- schema_from(html)
  list(
    text = sort(xml2::xml_text(xml2::xml_find_all(page, "//*[local-name()='text']"))),
    title = schema$title,
    layers = unlist(
      lapply(unlist(schema$subplots, recursive = FALSE), function(cell) cell$layers),
      recursive = FALSE
    ),
    warnings = warnings
  )
}

test_that("margin text of several values is drawn as R draws it, whatever it is spread over", {
  # gridGraphics stopped on a `side`, `outer`, `adj` or `padj` of several
  # values and on a missing `outer`, and drew fewer values than R where `at`
  # and `line` hold fewer, or `at` is missing.
  expect_drawn_as_r(function() {
    graphics::plot(1:5)
    graphics::mtext(c("Left axis", "Right axis"), side = c(2, 4), line = 2)
    graphics::mtext(c("low", "high"), side = 1, line = 2, adj = c(0, 1))
    graphics::mtext(c("a", "b"), side = 3, at = c(1, 3), padj = c(0, 1))
  })
  expect_drawn_as_r(function() {
    graphics::par(oma = c(2, 2, 2, 2), las = 2)
    graphics::plot(1:5)
    graphics::mtext(c("a", "b"), side = c(1, 3), outer = TRUE)
    graphics::mtext(c("c", "d"), side = 3, outer = c(TRUE, FALSE), adj = c(0, 1))
    graphics::mtext("e", outer = NA)
  })
  expect_drawn_as_r(function() {
    graphics::plot(1:5)
    graphics::mtext(c("a", "b"), at = 2)
    graphics::mtext(c("c", "d"), side = 1, at = c(1, NA), line = 2)
    graphics::mtext("e", side = 4, cex = c(1, 2))
    graphics::mtext(c(1, NA, 3), side = 1:3, line = 1, col = c("red", "blue"), font = c(1, 2))
    graphics::mtext(expression(alpha, beta), side = c(2, 4))
  })
  expect_drawn_as_r(function() {
    graphics::par(mfrow = c(2, 2))
    for (k in 1:4) {
      graphics::plot(1:5, main = k)
      graphics::mtext(c("units", k), side = c(2, 1), line = c(2.5, 3))
    }
  })
})

test_that("a chart with margin text of several values stays interactive", {
  chart <- exported_chart(function() {
    plot(1:5)
    mtext(c("Left axis", "Right axis"), side = c(2, 4), line = 2)
  })
  testthat::expect_identical(chart$warnings, character(0))
  testthat::expect_true(all(c("Left axis", "Right axis") %in% chart$text))
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)

  # One panel's margin text no longer takes the other panel's data with it.
  chart <- exported_chart(function() {
    par(mfrow = c(1, 2))
    plot(1:5, main = "ok")
    plot(5:1)
    mtext(c("a", "b"), side = c(2, 4), line = 2)
  })
  testthat::expect_identical(chart$warnings, character(0))
  testthat::expect_length(chart$layers, 2)
  for (layer in chart$layers) {
    testthat::expect_true(length(unlist(layer$selectors)) > 0)
  }
})

test_that("an axis given no positions is drawn as R draws it, and the chart stays interactive", {
  # R draws nothing for it; gridGraphics stopped ("'x' and 'units' must have
  # length > 0"), and the chart fell back to a picture.
  expect_drawn_as_r(function() {
    graphics::plot(1:5, axes = FALSE, main = "empty at")
    graphics::axis(1, at = numeric(0))
    graphics::axis(2, at = numeric(0), labels = character(0))
    graphics::axis(3, at = c(1, NA, 3))
  })

  chart <- exported_chart(function() {
    par(mfrow = c(1, 2))
    plot(1:5, main = "ok")
    plot(5:1, xaxt = "n")
    axis(1, at = numeric(0))
  })
  testthat::expect_identical(chart$warnings, character(0))
  testthat::expect_length(chart$layers, 2)
  for (layer in chart$layers) {
    testthat::expect_true(length(unlist(layer$selectors)) > 0)
  }
})

test_that("a plotmath title given in a list is drawn as the formula R draws", {
  # The call was handed to title() bare, which evaluated it: a call that
  # could be evaluated drew its value, "Mean:  3.14159265358979", and one
  # that could not stopped the drawing, and the chart fell back to a picture.
  expect_drawn_as_r(function() {
    graphics::plot(1:5, main = list(quote(paste("Mean: ", pi)), col = "blue"))
  })
  expect_drawn_as_r(function() {
    graphics::plot(
      1:5,
      main = list(quote(pi)), sub = list(quote(x[i]), col = "red"),
      xlab = list(quote(beta[1]), cex = 1.2), ylab = list(expression(alpha), font = 2)
    )
  })
  expect_drawn_as_r(function() {
    graphics::plot(1:5)
    graphics::title(main = list(bquote(R^2 == .(0.87)), cex = 1.2))
  })
  expect_drawn_as_r(function() graphics::barplot(1:3, main = list(quote(mu == 2), col = "red")))

  main <- list(quote(x^2), col = "red")
  xlab <- list(quote(beta[1]), cex = 1.2)
  chart <- exported_chart(function() plot(1:5, main = main, xlab = xlab))
  r_text <- r_drawing(
    function() graphics::plot(1:5, main = main, xlab = xlab),
    c(width = 7, height = 5)
  )
  testthat::expect_identical(chart$warnings, character(0))
  testthat::expect_identical(chart$text, sort(sub(" \\|.*$", "", r_text)))
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)
  # Read as it was written, as the same title given alone is.
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "beta[1]")
})

test_that("a title R was handed as a call is drawn as the formula R draws", {
  # curve() hands its titles to title() as evaluated, a call among them.
  # gridGraphics stopped on a call of more than one part ("'length = 3' in
  # coercion to 'logical(1)'"), and the chart fell back to a picture. It
  # warns of any plotmath title as it reads it, which is its own reading.
  suppressWarnings({
    expect_drawn_as_r(function() graphics::curve(x^2, 0, 2, ylab = quote(x^2)))
    expect_drawn_as_r(function() {
      k <- 2
      graphics::curve(x^k, 0, 2, main = bquote(x^.(k)), xlab = quote(bar(x)))
    })
  })

  chart <- exported_chart(function() curve(x^2, 0, 2, ylab = quote(x^2)))
  testthat::expect_false(any(grepl("rendered interactively", chart$warnings)))
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)
})

test_that("a formula plot titled with plotmath is drawn again as R draws it", {
  # plot()'s formula method evaluates its `...` with eval(), which ran the
  # expression vector the title was recorded as: the drawing again, and the
  # picture drawn in its place, both stopped ("object 'alpha' not found"),
  # and save_html() stopped with "Failed to create fallback image".
  d <- data.frame(x = 1:6, y = c(2, 4, 3, 5, 1, 6))
  chart <- exported_chart(function() {
    plot(y ~ x, data = d, main = expression(alpha), xlab = quote(beta[1]))
  })
  r_text <- suppressWarnings(r_drawing(
    function() graphics::plot(y ~ x, data = d, main = expression(alpha), xlab = quote(beta[1])),
    c(width = 7, height = 5)
  ))
  testthat::expect_false(any(grepl("rendered interactively", chart$warnings)))
  testthat::expect_identical(chart$text, sort(sub(" \\|.*$", "", r_text)))
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)
})

test_that("a plotmath title given in a list is announced as it was written", {
  # It was announced as no title, where the same value given as an axis
  # title is read as it was written, and where reading the list as text
  # had announced it before.
  r2 <- 0.87
  chart <- exported_chart(function() plot(1:5, main = list(quote(pi))))
  testthat::expect_identical(chart$title, "pi")
  testthat::expect_identical(chart$layers[[1]]$title, "pi")
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "Index")

  chart <- exported_chart(function() barplot(c(3, 5, 2), main = list(quote(Total), col = "red")))
  testthat::expect_identical(chart$layers[[1]]$title, "Total")

  chart <- exported_chart(function() hist(c(1, 2, 2, 3), main = list(quote(bar(x)), col = "red")))
  testthat::expect_identical(chart$layers[[1]]$title, "bar(x)")

  chart <- exported_chart(function() plot(1:5, main = list(expression(alpha, beta), font = 2)))
  testthat::expect_identical(chart$layers[[1]]$title, "alpha")

  chart <- exported_chart(function() {
    plot(1:5)
    title(main = list(bquote(R^2 == .(r2)), cex = 1.2), sub = list(quote(x[i])))
  })
  testthat::expect_identical(chart$title, "R^2 == 0.87")
  testthat::expect_identical(chart$warnings, character(0))
})

test_that("a title's line and outer are read by their first value, as R reads them", {
  # gridGraphics tested them as given, and stopped on several values, on
  # none and on a missing outer ("the condition has length > 1"); a line
  # given as text was drawn as no line. The chart fell back to a picture.
  expect_drawn_as_r(function() {
    graphics::plot(1:5)
    graphics::title(main = "Speed", line = c(1, 2))
  })
  expect_drawn_as_r(function() {
    graphics::plot(1:5)
    graphics::title(main = 3, line = "1")
  })
  expect_drawn_as_r(function() {
    graphics::plot(1:5)
    graphics::title(main = "Speed", line = numeric(0), outer = logical(0))
  })
  expect_drawn_as_r(function() {
    graphics::par(oma = c(2, 2, 3, 2))
    graphics::plot(1:5)
    graphics::title(main = "Outer", outer = c(TRUE, FALSE))
    graphics::title(main = "Inner", outer = NA, line = c(NA, 2))
  })

  chart <- exported_chart(function() {
    plot(1:5)
    title(main = "Speed", line = c(1, 2))
  })
  testthat::expect_identical(chart$warnings, character(0))
  testthat::expect_true("Speed" %in% chart$text)
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)
})

test_that("an axis's tick, line, pos and outer are read by their first value, as R reads them", {
  # gridGraphics tested them as given, and stopped on several values of tick,
  # pos or outer and on a missing outer ("missing value where TRUE/FALSE
  # needed"); the chart fell back to a picture. It reads a missing tick as
  # TRUE itself, as R does.
  expect_drawn_as_r(function() {
    graphics::plot(1:5, axes = FALSE)
    graphics::axis(1, tick = c(FALSE, TRUE), line = c(1, 2))
    graphics::axis(2, pos = c(2, 3), outer = NA)
    graphics::axis(3, tick = NA, line = "1", outer = c(FALSE, TRUE))
  })

  # Ticks are lines. R draws them by tick's first value, for a missing one
  # too, and none for `tick = 0`, which heatmap() draws its axes with.
  for (tick in list(FALSE, NA, c(FALSE, TRUE), c(TRUE, FALSE), 0, logical(0))) {
    expect_lines_drawn_as_r(function() {
      graphics::plot(1:5, xaxt = "n")
      graphics::axis(1, tick = tick)
    })
  }
  # A heatmap's dendrograms are drawn a hundredth of a pixel from R's, so
  # its lines are counted.
  size <- c(width = 7, height = 5)
  heat <- function() stats::heatmap(as.matrix(datasets::mtcars[1:6, 1:4]))
  testthat::expect_length(
    maidr_drawing(heat, size, drawn_lines),
    length(r_drawing(heat, size, drawn_lines))
  )

  chart <- exported_chart(function() {
    plot(1:5, xaxt = "n")
    axis(1, outer = NA)
  })
  testthat::expect_identical(chart$warnings, character(0))
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)
})

test_that("an axis's side, font, line widths, colours and line type are read as R reads them", {
  # R reads each by its first value, and draws no line for a missing width.
  # gridGraphics stopped on several values of side, font, lwd or lwd.ticks
  # ("the condition has length > 1") and on a missing width, and the chart
  # fell back to a picture; it drew the ticks in each col.ticks and lty in
  # turn.
  axes <- list(
    list(c(1, 3)), list("1"), list(c(2, 4), font = c(2, 1)), list(1, font = c(9, 2)),
    list(1, lwd = c(1, 3)), list(1, lwd = NA), list(1, lwd.ticks = c(3, 1)),
    list(1, lwd.ticks = NA), list(1, col = c("red", "blue")),
    list(1, col.ticks = c("red", "blue")), list(1, lty = c("dashed", "solid"))
  )
  for (axis_args in axes) {
    draw <- function() {
      graphics::plot(1:5, xaxt = "n", yaxt = "n")
      do.call(graphics::axis, axis_args)
    }
    expect_drawn_as_r(draw)
    expect_lines_drawn_as_r(draw)
  }

  chart <- exported_chart(function() {
    plot(1:5, xaxt = "n", main = "Speed")
    axis(c(1, 3), font = c(2, 1), lwd = c(1, 3))
  })
  testthat::expect_identical(chart$warnings, character(0))
  testthat::expect_true("Speed" %in% chart$text)
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)
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

test_that("a title given as a classed list is announced as the lines R draws", {
  # title() makes a classed value text with as.character() first. A data
  # frame row and a POSIXlt date are lists underneath, and were read as a
  # list title: the data frame's last column, the date's first value.
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
  info <- data.frame(site = "North", year = 2024)
  when <- as.POSIXlt(c("2024-01-02", "2024-02-03"), tz = "UTC")
  plot(1:5, main = info, xlab = when)
  chart <- maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
  layer <- chart$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_identical(chart$title, "North\n2024")
  testthat::expect_identical(layer$title, "North\n2024")
  testthat::expect_identical(layer$axes$x$label, "2024-01-02\n2024-02-03")
  expect_drawn_as_r(function() graphics::plot(1:5, main = info, xlab = when))
})

test_that("a factor or date given in a list title is drawn and announced as the number R draws", {
  # title() makes text of a classed value given alone, but not of one in a
  # list: R draws the value under the class, a factor's code and a date's
  # day number. maidr drew and announced the factor's label and the date.
  values <- list(
    factor("Group A"), factor(c("lo", "hi")), as.Date("2024-03-15"),
    as.POSIXct("2024-03-15 10:00", tz = "UTC")
  )
  for (value in values) {
    for (name in c("main", "sub", "xlab", "ylab")) {
      args <- stats::setNames(list(1:5, list(value, col = "red")), c("", name))
      expect_drawn_as_r(function() do.call(graphics::plot, args))
    }
  }
  expect_drawn_as_r(function() graphics::plot(1:5, main = list(as.POSIXlt("2024-03-15"))))

  main <- list(factor("Group A"), col = "red")
  xlab <- list(as.Date("2024-03-15"))
  chart <- exported_chart(function() plot(1:5, main = main, xlab = xlab))
  r_text <- r_drawing(
    function() graphics::plot(1:5, main = main, xlab = xlab),
    c(width = 7, height = 5)
  )
  testthat::expect_identical(chart$text, sort(sub(" \\|.*$", "", r_text)))
  testthat::expect_identical(chart$title, "1")
  testthat::expect_identical(chart$layers[[1]]$title, "1")
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "19797")

  chart <- exported_chart(function() barplot(c(3, 5, 2), xlab = list(factor("Year"), font = 2)))
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "1")
})

test_that("a title written as code on a call recorded as written is announced as R draws it", {
  # curve(), and a formula plot whose subset names the data's columns, are
  # recorded as written. A title given as anything but a literal was then
  # announced as its code, `c("x", "(units)")`, or as no title, where R drew
  # its value.
  d <- data.frame(x = 1:6, y = c(2, 4, 3, 5, 1, 6), g = rep(1:2, 3))
  size <- c(width = 7, height = 5)
  r_text <- function(draw) sort(sub(" \\|.*$", "", r_drawing(draw, size)))

  chart <- exported_chart(function() {
    par(mfrow = c(1, 2))
    for (grp in 1:2) {
      plot(y ~ x, data = d, subset = g == grp, main = grp, xlab = c("x", "(units)"))
    }
  })
  testthat::expect_identical(chart$text, r_text(function() {
    graphics::par(mfrow = c(1, 2))
    for (grp in 1:2) {
      graphics::plot(y ~ x, data = d, subset = g == grp, main = grp, xlab = c("x", "(units)"))
    }
  }))
  testthat::expect_identical(vapply(chart$layers, `[[`, "", "title"), c("1", "2"))
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "x\n(units)")

  # plot()'s formula method reads main, sub and xlab within its data.
  chart <- exported_chart(function() {
    plot(y ~ x, data = d, subset = g == 1, main = paste("n =", length(y)), xlab = paste("g", g[1]))
  })
  testthat::expect_identical(chart$text, r_text(function() {
    graphics::plot(
      y ~ x, data = d, subset = g == 1, main = paste("n =", length(y)), xlab = paste("g", g[1])
    )
  }))
  testthat::expect_identical(chart$layers[[1]]$title, "n = 6")
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "g 1")

  # Drawn again from the expression R drew, handed over quoted: the formula
  # method evaluates an expression vector it is handed, and would look up
  # alpha.
  chart <- exported_chart(function() {
    plot(y ~ x, data = d, subset = g == 1, main = expression(alpha))
  })
  testthat::expect_false(any(grepl("rendered interactively", chart$warnings)))
  testthat::expect_true(length(unlist(chart$layers[[1]]$selectors)) > 0)

  chart <- exported_chart(function() {
    s <- 2
    curve(dnorm(x, sd = s), -5, 5, main = s, ylab = c("density", "(sd 2)"))
  })
  testthat::expect_identical(chart$title, "2")
  testthat::expect_identical(chart$layers[[1]]$axes$y$label, "density\n(sd 2)")

  chart <- exported_chart(function() {
    curve(sin, 0, pi, xlab = list("angle", col = "red"), ylab = list(2024))
  })
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "angle")
  testthat::expect_identical(chart$layers[[1]]$axes$y$label, "2024")

  chart <- exported_chart(function() curve(x^2, 0, 2, xlab = expression(x), ylab = quote(x^2)))
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "x")
  testthat::expect_identical(chart$layers[[1]]$axes$y$label, "x^2")

  chart <- exported_chart(function() {
    boxplot(y ~ g, data = d, subset = x > 1, ylab = list("y", font = 2))
  })
  testthat::expect_identical(chart$layers[[1]]$axes$y$label, "y")
})

test_that("a title written as code is read without repeating what R said drawing it", {
  # Its value was read again when the call was recorded, and a warning or a
  # message R gave while drawing it was given a second time.
  said <- character(0)
  chart <- exported_chart(function() {
    withCallingHandlers(
      curve(sin, 0, pi, main = {
        warning("careful")
        message("drawing")
        "Sine"
      }),
      warning = function(w) {
        said <<- c(said, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        said <<- c(said, trimws(conditionMessage(m)))
        invokeRestart("muffleMessage")
      }
    )
  })
  testthat::expect_identical(said, c("careful", "drawing"))
  testthat::expect_identical(chart$title, "Sine")
})

test_that("a title written as code is read as R drew it, without running it again", {
  # It was evaluated again when the call was recorded, and the chart was
  # drawn again from its code: what the code does was done again -- the next
  # random numbers, a counter, a print -- and the title announced and the
  # title drawn were other values than the one R drew.
  withr::local_preserve_seed()

  after <- NULL
  chart <- exported_chart(function() {
    set.seed(1)
    curve(dnorm, -3, 3, main = sprintf("draw %.2f", stats::rnorm(1)))
    after <<- stats::rnorm(3)
  })
  set.seed(1)
  drawn <- sprintf("draw %.2f", stats::rnorm(1))
  testthat::expect_identical(after, stats::rnorm(3))
  testthat::expect_identical(chart$title, drawn)
  testthat::expect_true(drawn %in% chart$text)

  i <- 0
  count <- function() {
    i <<- i + 1
    paste("call", i)
  }
  chart <- exported_chart(function() curve(sin, 0, pi, main = count()))
  testthat::expect_identical(i, 1)
  testthat::expect_identical(chart$title, "call 1")
  testthat::expect_true("call 1" %in% chart$text)
  # R draws no title here, and never evaluates it.
  chart <- exported_chart(function() curve(sin, 0, pi, ann = FALSE, main = count()))
  testthat::expect_identical(i, 1)

  printed <- utils::capture.output(
    chart <- exported_chart(function() {
      curve(sin, 0, pi, main = {
        cat("computing the title\n")
        "Sine"
      })
    })
  )
  testthat::expect_identical(printed, "computing the title")
  testthat::expect_identical(chart$title, "Sine")

  # A formula plot whose subset names the data's columns is drawn by a call
  # rebuilt in the caller's frame. Its title is the one that call drew, and
  # the chart is drawn again for maidr without running the title again.
  d <- data.frame(x = 1:6, y = c(2, 4, 3, 5, 1, 6), g = rep(1:2, 3))
  k <- 0
  label <- function() {
    k <<- k + 1
    paste("draw", sample(100, 1))
  }
  plotted <- NULL
  chart <- exported_chart(function() {
    plot(y ~ x, data = d, subset = g == 1, main = label())
    plotted <<- k
  })
  testthat::expect_identical(k, plotted)
  testthat::expect_true(chart$layers[[1]]$title %in% chart$text)
})

test_that("recording a call drawn from its code runs none of its titles again", {
  # The titles of a call recorded as written were evaluated again when it
  # was recorded, and for a formula plot the data they are read within was
  # built again for them, repeating the warnings building it gave, and its
  # cost. The data is still read once, for the rows the chart drew
  # (`recorded_formula_frame()`).
  built <- 0
  titled <- 0
  env <- new.env()
  env$d <- data.frame(x = 1:6, y = c(2, 4, 3, 5, 1, 6), g = rep(1:2, 3))
  env$mk <- function() {
    built <<- built + 1
    env$d
  }
  env$label <- function() {
    titled <<- titled + 1
    "Title"
  }
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

  args <- as.list(quote(plot(y ~ x, data = mk(), subset = g == 1, main = label())))[-1L]
  log_plot_call_to_device("plot", NULL, args, device_id, call_env = env)
  testthat::expect_identical(titled, 0)
  testthat::expect_identical(built, 1)

  args <- as.list(quote(curve(sin, 0, pi, main = label(), ylab = label())))[-1L]
  log_plot_call_to_device("curve", NULL, args, device_id, call_env = env)
  testthat::expect_identical(titled, 0)
})

test_that("a formula plot's ylab is read where R reads it, in the caller, not within data", {
  # plot()'s formula method reads main, sub and xlab within its data, and
  # its ylab, which is one of its own arguments, in the caller.
  lab <- "Response (caller)"
  d <- data.frame(x = 1:6, y = c(2, 4, 3, 5, 1, 6), g = rep(1:2, 3), lab = "column")
  chart <- exported_chart(function() plot(y ~ x, data = d, subset = g == 1, ylab = lab))
  testthat::expect_identical(chart$layers[[1]]$axes$y$label, "Response (caller)")
  testthat::expect_true("Response (caller)" %in% chart$text)
  testthat::expect_false("column" %in% chart$text)
})

test_that("several time series a panel each are announced by the series R titles them with", {
  # plot.ts() draws no ylab for several series a panel each: it titles each
  # panel after its series. maidr reads the first series, and announced the
  # ylab R never drew, every value of it.
  y_label <- function(draw) {
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
    chart <- maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
    chart$subplots[[1]][[1]]$layers[[1]]$axes$y$label
  }
  deaths <- cbind(mdeaths, fdeaths)

  testthat::expect_identical(
    y_label(function() plot(deaths, ylab = c("Male", "Female"), main = "Deaths")),
    "mdeaths"
  )
  testthat::expect_identical(
    y_label(function() plot(deaths, ylab = "Count", type = "p")),
    "mdeaths"
  )
  testthat::expect_identical(
    y_label(function() plot(ts(matrix(1:10, 5)), ylab = "Count")),
    "Series 1"
  )
  # Drawn as one panel, the series share the ylab R draws.
  testthat::expect_identical(
    y_label(function() plot(deaths, plot.type = "single", ylab = c("Male", "Female"))),
    "Male\nFemale"
  )
})
