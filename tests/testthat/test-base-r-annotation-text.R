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
