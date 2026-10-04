# Base R charts titled with plotmath calls.
#
# `main = bquote(mu == .(n))` and `xlab = quote(x[i])` hand the chart a call,
# and every reader of a recorded call passes the values on through
# `do.call()`, which evaluates a call it is handed. The replay stopped
# looking up `mu` and the exported chart had nothing on it; a box plot or a
# Q-Q plot titled that way was read with no data; and `barplot()` failed at
# the reader's own call with maidr attached. The call is now recorded as the
# expression vector holding it, which R draws as the same plotmath.

skip_slow_file_on_cran()
skip_if_not_installed("xml2")

# The text and the layers of the chart `save_html()` exports for `draw()`.
exported_plotmath_chart <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off(device_id)
      unlink(file)
    },
    add = TRUE
  )
  draw()
  # gridGraphics warns about an expression title while it converts it.
  suppressWarnings(suppressMessages(save_html(file = file)))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  document <- xml2::read_html(file)
  # Run together: plotmath may draw a name a glyph at a time.
  list(
    text = paste(
      xml2::xml_text(xml2::xml_find_all(document, "//*[local-name()='text']")),
      collapse = ""
    ),
    layers = layers_from(html)
  )
}

drawn <- function(chart, strings) {
  all(vapply(strings, grepl, logical(1), x = chart$text, fixed = TRUE))
}

test_that("a chart titled with plotmath is exported with its drawing", {
  skip_if_no_render()
  n <- 3

  chart <- exported_plotmath_chart(function() {
    plot(1:3, main = bquote(Speed[.(n)]), xlab = quote(Miles[gallon]))
    text(2, 2, labels = bquote(Fuel == .(n)))
  })

  testthat::expect_true(drawn(chart, c("Speed3", "Milesgallon", "Fuel=3")))
  testthat::expect_length(chart$layers[[1]]$data, 3)
  testthat::expect_identical(chart$layers[[1]]$axes$x$label, "Miles[gallon]")

  chart <- exported_plotmath_chart(function() {
    hist(mtcars$mpg, main = bquote(Cars == .(nrow(mtcars))))
  })
  testthat::expect_true(drawn(chart, "Cars=32"))
  testthat::expect_equal(
    vapply(chart$layers[[1]]$data, function(bar) bar$y, numeric(1)),
    graphics::hist(mtcars$mpg, plot = FALSE)$counts
  )
})

test_that("barplot() titled with plotmath draws with maidr attached", {
  skip_if_no_render()
  n <- 3

  chart <- exported_plotmath_chart(function() {
    testthat::expect_no_error(
      barplot(c(a = 1, b = 2), main = bquote(Total == .(n)))
    )
  })

  testthat::expect_true(drawn(chart, "Total=3"))
  testthat::expect_length(chart$layers[[1]]$data, 2)
})

test_that("charts read by computing them are still read under a plotmath title", {
  skip_if_no_render()
  n <- 3

  box <- exported_plotmath_chart(function() {
    boxplot(mtcars$mpg, main = bquote(mu == .(n)))
  })
  qq <- exported_plotmath_chart(function() {
    qqnorm(mtcars$mpg, main = bquote(mu == .(n)))
  })

  testthat::expect_length(box$layers[[1]]$data, 1)
  testthat::expect_length(qq$layers[[1]]$data, 32)
})

test_that("only calls are recorded as expressions", {
  formula <- y ~ x
  recorded <- calls_as_expressions(list(
    1:3,
    main = quote(mu == 3),
    xlab = quote(alpha),
    sub = expression(beta),
    formula,
    "text"
  ))

  testthat::expect_identical(recorded[[1]], 1:3)
  testthat::expect_identical(recorded$main, expression(mu == 3))
  testthat::expect_identical(recorded$xlab, expression(alpha))
  testthat::expect_identical(recorded$sub, expression(beta))
  testthat::expect_identical(recorded[[5]], formula)
  testthat::expect_identical(recorded[[6]], "text")
})
