# The size a chart is drawn at: R/chart_size.R, and the entry points that
# take one -- show() and save_html() (`width`, `height`), render_maidr() and
# the widget (`fig_width`, `fig_height`), and a knitted chunk's `fig.width`
# and `fig.height`.
#
# A chart is drawn on a canvas measured in inches and exported at 72 pixels
# to the inch. The canvas is the room the chart is laid out in and nothing a
# reader hears, so every kind of chart here is drawn at four sizes and its
# maidr-data compared across them. The browser's side -- nothing drawn
# outside the viewBox, tick labels apart, the highlight on the first mark --
# is checked by .github/scripts/knitr-smoke.mjs.

# ==============================================================================
# Helpers
# ==============================================================================

#' The sizes every chart is drawn at, in inches
chart_sizes <- list(c(4, 3), c(7, 5), c(10, 4), c(5, 8))

#' The root `<svg>` element of some markup that holds one chart
chart_svg_root <- function(markup) {
  markup <- paste(as.character(markup), collapse = "\n")
  regmatches(markup, regexpr("<svg[^>]*>", markup))
}

#' The width, height and viewBox of a chart's svg, as written
svg_size <- function(markup) {
  root <- chart_svg_root(markup)
  # Any case: an HTML parser reads `viewbox` on an svg as `viewBox`, and
  # Quarto writes it so.
  attr_of <- function(name) {
    sub(sprintf('(?i)^.*\\s%s="([^"]*)".*$', name), "\\1", root, perl = TRUE)
  }
  c(width = attr_of("width"), height = attr_of("height"), viewBox = attr_of("viewBox"))
}

#' The svg attributes a chart of `size` inches is written with
svg_size_for <- function(size) {
  px <- size * 72
  c(
    width = paste0(px[1], "px"),
    height = paste0(px[2], "px"),
    viewBox = sprintf("0 0 %s %s", px[1], px[2])
  )
}

#' Markup or text as it reads once its entities are decoded
#'
#' A chart's maidr-data is escaped in its attribute, and a chart in a frame
#' is escaped as a whole in the frame's `srcdoc`.
unescape_markup <- function(x) {
  for (pair in list(
    c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"), c("&#39;", "'"), c("&amp;", "&")
  )) {
    x <- gsub(pair[1], pair[2], x, fixed = TRUE)
  }
  x
}

#' The maidr-data of a chart's svg, leaving out what names its elements
#'
#' Ids name the build that made them. Selectors name grobs, and a grob's name
#' carries a counter every build in a session advances, so two renders of a
#' chart never share them; a selector is kept with its numbers taken out,
#' which still says which marks it addresses. A violin's density points
#' carry `svg_x` and `svg_y`, where on the page each one is drawn
#' (`inject_violin_kde_svg_coords()`): the one part of the data that is a
#' position on the page, and so the one that changes with the size.
size_free_schema <- function(markup) {
  root <- chart_svg_root(markup)
  json <- unescape_markup(sub('^.*\\smaidr-data="([^"]*)".*$', "\\1", root))
  strip <- function(x) {
    if (!is.list(x)) {
      return(x)
    }
    x$id <- NULL
    x$svg_x <- NULL
    x$svg_y <- NULL
    if (!is.null(x$selectors)) {
      x$selectors <- rapply(
        list(x$selectors),
        function(s) gsub("[0-9]+", "N", s),
        how = "replace"
      )[[1]]
    }
    lapply(x, strip)
  }
  strip(jsonlite::parse_json(json))
}

#' A chart's SVG at a size, as save_html() and show() build it
#'
#' @param chart A ggplot2 or lattice chart, or a function drawing Base R
#'   calls, which are drawn on a device of their own
#' @param size The width and height asked for, or `NULL` for none
render_sized <- function(chart, size) {
  if (!is.function(chart)) {
    return(maidr:::create_maidr_html(chart, shiny = TRUE, width = size[1], height = size[2]))
  }
  # Room for the tallest grid drawn here: the device a chart is drawn on is
  # not the size maidr draws it at.
  grDevices::pdf(NULL, width = 50, height = 50)
  device <- grDevices::dev.cur()
  # A device number is used again once its device is closed, and what an
  # earlier test recorded under it would be read as part of this chart.
  maidr:::clear_device_storage(device)
  on.exit(
    {
      maidr:::clear_device_storage(device)
      grDevices::dev.off(device)
    },
    add = TRUE
  )
  chart()
  maidr:::create_maidr_html(NULL, shiny = TRUE, width = size[1], height = size[2])
}

#' Draw a chart at every size and check each against the one at 7 x 5
#'
#' @param minimum The smallest size the chart is drawn at
expect_sized_alike <- function(name, chart, minimum = c(0, 0)) {
  rendered <- lapply(chart_sizes, function(size) {
    suppressMessages(suppressWarnings(render_sized(chart, size)))
  })
  reference <- size_free_schema(rendered[[2]])
  testthat::expect_gt(length(unlist(reference$subplots)), 0L, label = name)
  for (i in seq_along(chart_sizes)) {
    size <- chart_sizes[[i]]
    label <- sprintf("%s at %g x %g in", name, size[1], size[2])
    testthat::expect_identical(
      svg_size(rendered[[i]]), svg_size_for(pmax(size, minimum)),
      label = label
    )
    testthat::expect_identical(size_free_schema(rendered[[i]]), reference, label = label)
  }
}

#' R's own error drawing a Base R chart at a size, or NA when R draws it
native_error <- function(draw, size) {
  grDevices::pdf(NULL, width = size[1], height = size[2])
  on.exit(grDevices::dev.off(), add = TRUE)
  tryCatch(
    {
      draw()
      NA_character_
    },
    error = conditionMessage
  )
}

#' The size of each plot R draws, in pixels, as R lays them out at a size,
#' or NULL when R cannot draw the chart at that size
native_plots <- function(draw, size) {
  plots <- list()
  hooks <- getHook("plot.new")
  setHook("plot.new", function() plots[[length(plots) + 1L]] <<- graphics::par("pin") * 72)
  on.exit(setHook("plot.new", hooks, "replace"), add = TRUE)
  if (!is.na(native_error(draw, size))) {
    return(NULL)
  }
  plots
}

#' A function drawing a `par(mfrow)` grid of Base R plots
grid_of <- function(rows, cols = 1) {
  function() {
    par(mfrow = c(rows, cols))
    for (i in seq_len(rows * cols)) plot(1:5, main = paste("Panel", i))
  }
}

#' The value of some code, and the messages it gave, which are kept off the
#' console
with_messages <- function(code) {
  said <- character()
  value <- withCallingHandlers(
    code,
    message = function(m) {
      said <<- c(said, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  list(value = value, said = said)
}

#' A Base R chartSeries() chart of ten days, as maidr reads it
draw_chartseries <- function() {
  ohlc <- xts::xts(
    cbind(
      Open = c(100, 105, 110, 108, 104, 107, 111, 109, 113, 115),
      High = c(115, 108, 112, 110, 109, 112, 114, 113, 118, 119),
      Low = c(95, 102, 105, 100, 101, 104, 108, 106, 110, 112),
      Close = c(110, 103, 111, 108, 107, 111, 109, 112, 116, 114)
    ),
    order.by = as.Date("2023-01-02") + 0:9
  )
  maidr::chartSeries(ohlc, type = "candlesticks", theme = "white", name = "CANDLES", TA = NULL)
}

#' The root `<svg>` element of every inline chart of a knitted page
#'
#' A self-contained page carries knitr-inline.js, whose comments name such an
#' element too; a chart's has a size.
inline_svg_roots <- function(page) {
  roots <- regmatches(page, gregexpr("<svg[^>]*>", page))[[1]]
  roots[grepl("data-maidr-knitr=", roots, fixed = TRUE) & grepl("\\swidth=", roots)]
}

#' Render an R Markdown document in an R session of its own
#'
#' As an author does: maidr is loaded by the document, which knits it in a
#' session of its own.
#'
#' @return The HTML file it rendered
render_in_session <- function(rmd) {
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    sprintf("rmarkdown::render(%s, quiet = TRUE)", deparse(rmd))
  ), script)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), script,
    stdout = TRUE, stderr = TRUE, timeout = 300
  ))
  testthat::expect_null(attr(out, "status"), info = paste(out, collapse = "\n"))
  sub("\\.Rmd$", ".html", rmd)
}

#' The PNG a page embeds, as its width and height in pixels
#'
#' Read from the PNG's header: its IHDR chunk, after the 8-byte signature and
#' the chunk's length and type, holds the width and then the height, each a
#' 4-byte big-endian integer.
embedded_png_size <- function(html) {
  uri <- regmatches(html, regexpr("data:image/png;base64,[A-Za-z0-9+/=]+", html))
  raw <- base64enc::base64decode(sub("^data:image/png;base64,", "", uri))
  testthat::expect_identical(rawToChar(raw[13:16]), "IHDR")
  readBin(raw[17:24], "integer", n = 2L, size = 4L, endian = "big")
}

# ==============================================================================
# The size asked for
# ==============================================================================

test_that("a size is NULL or one positive number of inches, named when it is not", {
  testthat::expect_silent(maidr:::check_chart_size(NULL, "width"))
  testthat::expect_silent(maidr:::check_chart_size(4, "width"))
  testthat::expect_silent(maidr:::check_chart_size(2L, "height"))
  testthat::expect_silent(maidr:::check_chart_size(0.5, "fig_width"))
  bad <- list(0, -1, Inf, NA_real_, NaN, "4", c(4, 5), TRUE, numeric(0), list(4))
  for (value in bad) {
    testthat::expect_error(
      maidr:::check_chart_size(value, "fig_height"),
      "`fig_height` must be NULL or a single positive number of inches",
      label = deparse(value)
    )
  }
  testthat::expect_error(maidr:::check_chart_size(-1, "width"), "not -1\\.$")
  testthat::expect_error(maidr:::check_chart_size("4", "width"), 'not "4"\\.$')
  testthat::expect_error(maidr:::check_chart_size(c(4, 5), "width"), "not numeric of length 2\\.$")
})

test_that("a size over 50 in is refused, as ggsave() refuses one, saying it is not pixels", {
  testthat::expect_silent(maidr:::check_chart_size(50, "width"))
  testthat::expect_error(
    maidr:::check_chart_size(800, "width"),
    paste(
      "`width` is 800 inches, larger than the 50 a chart can be. A chart's size",
      "is in inches, not pixels: 800 pixels would be 11.11 in, at 72 pixels to the inch."
    ),
    fixed = TRUE
  )
  testthat::expect_error(
    maidr:::check_chart_size(50.5, "fig_height"),
    "`fig_height` is 50.5 inches"
  )

  skip_if_no_render()
  p <- create_test_ggplot_bar()
  file <- withr::local_tempfile(fileext = ".html")
  testthat::expect_error(save_html(p, file, width = 800, height = 600), "`width` is 800 inches")
  testthat::expect_false(file.exists(file))
  testthat::expect_error(maidr:::maidr_widget(p, fig_height = 400), "`fig_height` is 400 inches")
})

test_that("a side not asked for is maidr's own, and a candlestick is at least 12 x 6 in", {
  size <- maidr:::chart_canvas_size
  testthat::expect_identical(size(), c(width = 7, height = 5))
  testthat::expect_identical(size(10), c(width = 10, height = 5))
  testthat::expect_identical(size(height = 2.5), c(width = 7, height = 2.5))
  testthat::expect_identical(size(4, 3), c(width = 4, height = 3))

  # Unasked, a candlestick chart is 12 x 6 in, and nothing is said.
  testthat::expect_silent(
    testthat::expect_identical(size(candlestick = TRUE), c(width = 12, height = 6))
  )
  testthat::expect_silent(size(14, 7, candlestick = TRUE))
  # Asked smaller on either side, it is enlarged on that side, and says so.
  testthat::expect_message(
    testthat::expect_identical(size(4, 3, candlestick = TRUE), c(width = 12, height = 6)),
    "drawn at 12 x 6 in rather than the 4 x 3 in asked for",
    class = "maidr_chart_size_message"
  )
  testthat::expect_message(
    testthat::expect_identical(size(5, 8, candlestick = TRUE), c(width = 12, height = 8)),
    "drawn at 12 x 8 in rather than the 5 x 8 in asked for"
  )
  testthat::expect_message(
    testthat::expect_identical(size(20, candlestick = TRUE), c(width = 20, height = 6)),
    NA
  )
  # A size not asked for -- a knitted document's figure size -- is enlarged
  # without a word.
  testthat::expect_silent(
    testthat::expect_identical(
      size(4, 3, candlestick = TRUE, asked = FALSE),
      c(width = 12, height = 6)
    )
  )
})

test_that("every entry point checks the size it is given before drawing anything", {
  skip_if_no_render()
  p <- create_test_ggplot_bar()
  file <- withr::local_tempfile(fileext = ".html")
  testthat::expect_error(save_html(p, file, width = -1), "`width` must be NULL")
  testthat::expect_false(file.exists(file))
  testthat::expect_error(save_html(p, file, height = "3in"), "`height` must be NULL")
  testthat::expect_error(maidr::show(p, width = 0), "`width` must be NULL")
  testthat::expect_error(maidr::show(p, as_widget = TRUE, height = Inf), "`height` must be NULL")
  testthat::expect_error(maidr:::maidr_widget(p, fig_width = NA), "`fig_width` must be NULL")
  testthat::expect_error(
    render_maidr(p, fig_height = c(4, 5)),
    "`fig_height` must be NULL"
  )
})

# ==============================================================================
# The SVG at each size, and its data the same at every one
# ==============================================================================

test_that("ggplot2 charts are drawn at the size asked for, their data the same at every size", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("patchwork")
  bars <- data.frame(kind = c("alpha", "beta", "gamma", "delta"), n = c(11, 12, 13, 14))
  heat <- data.frame(
    x = rep(c("a", "b", "c"), 3),
    y = rep(c("p", "q", "r"), each = 3),
    v = as.numeric(1:9)
  )
  line <- data.frame(
    x = 1:20,
    y = c(5, 7, 6, 9, 8, 11, 10, 12, 14, 13, 15, 17, 16, 18, 20, 19, 21, 23, 22, 24)
  )
  charts <- list(
    bar = ggplot2::ggplot(bars, ggplot2::aes(kind, n)) + ggplot2::geom_col() +
      ggplot2::labs(title = "Bar chart"),
    point = ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point(),
    line = ggplot2::ggplot(line, ggplot2::aes(x, y)) + ggplot2::geom_line(),
    histogram = ggplot2::ggplot(mtcars, ggplot2::aes(mpg)) + ggplot2::geom_histogram(bins = 10),
    boxplot = ggplot2::ggplot(iris, ggplot2::aes(Petal.Length, Species)) + ggplot2::geom_boxplot(),
    violin = ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl), mpg)) + ggplot2::geom_violin(),
    heatmap = ggplot2::ggplot(heat, ggplot2::aes(x, y, fill = v)) + ggplot2::geom_tile(),
    facet_wrap = ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point() +
      ggplot2::facet_wrap(~cyl),
    patchwork = (ggplot2::ggplot(bars, ggplot2::aes(kind, n)) + ggplot2::geom_col()) +
      (ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()) +
      patchwork::plot_annotation(title = "Two charts")
  )
  for (name in names(charts)) {
    expect_sized_alike(paste("ggplot2", name), charts[[name]])
  }
})

test_that("Base R charts are drawn at the size asked for, their data the same at every size", {
  testthat::skip_on_cran()
  skip_if_no_render()
  charts <- list(
    barplot = function() {
      barplot(c(11, 12, 13, 14), names.arg = c("alpha", "beta", "gamma", "delta"))
    },
    hist = function() hist(mtcars$mpg, main = "Miles per gallon", xlab = "mpg"),
    plot = function() plot(mtcars$wt, mtcars$mpg, xlab = "wt", ylab = "mpg"),
    boxplot = function() boxplot(mpg ~ cyl, data = mtcars),
    mfrow = function() {
      par(mfrow = c(1, 2))
      barplot(c(3, 5, 7), names.arg = c("x", "y", "z"), main = "Left")
      plot(1:10, (1:10)^2, main = "Right")
    },
    image = function() image(matrix(1:12, 3, 4), main = "Cells")
  )
  for (name in names(charts)) {
    expect_sized_alike(paste("Base R", name), charts[[name]])
  }
})

test_that("lattice charts are drawn at the size asked for, their data the same at every size", {
  testthat::skip_on_cran()
  skip_if_no_render()
  skip_if_no_lattice()
  bars <- data.frame(kind = c("alpha", "beta", "gamma", "delta"), n = c(11, 12, 13, 14))
  expect_sized_alike(
    "lattice barchart",
    lattice::barchart(n ~ kind, data = bars, origin = 0, main = "Bars")
  )
  expect_sized_alike("lattice xyplot", lattice::xyplot(mpg ~ wt, data = mtcars))
})

test_that("candlestick charts are drawn at least 12 x 6 in, their data the same at every size", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("quantmod")
  testthat::skip_if_not_installed("xts")
  expect_sized_alike("Base R chartSeries", draw_chartseries, minimum = c(12, 6))

  testthat::skip_if_not_installed("tidyquant")
  ohlc <- data.frame(
    date = as.Date("2023-01-02") + 0:3,
    open = c(100, 105, 110, 108),
    high = c(115, 108, 112, 110),
    low = c(95, 102, 105, 100),
    close = c(110, 103, 111, 108)
  )
  candles <- ggplot2::ggplot(
    ohlc,
    ggplot2::aes(x = date, open = open, high = high, low = low, close = close)
  ) +
    tidyquant::geom_candlestick()
  expect_sized_alike("ggplot2 candlestick", candles, minimum = c(12, 6))
})

test_that("a candlestick chart asked to be smaller says the size it is drawn at, once", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("quantmod")
  testthat::skip_if_not_installed("xts")
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device), add = TRUE)
  maidr:::clear_device_storage(device)
  draw_chartseries()

  file <- withr::local_tempfile(fileext = ".html")
  said <- character()
  withCallingHandlers(
    save_html(file = file, width = 8, height = 4),
    message = function(m) {
      said <<- c(said, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  testthat::expect_length(said, 1L)
  testthat::expect_match(said, "drawn at 12 x 6 in rather than the 8 x 4 in asked for")
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  testthat::expect_identical(svg_size(html), svg_size_for(c(12, 6)))
})

# ==============================================================================
# What the size changes: the layout
# ==============================================================================

test_that("a Base R chart is laid out on a page of the size it is drawn at", {
  testthat::skip_on_cran()
  skip_if_no_render()
  # Base R sets a title in the top margin, a fixed distance below the top of
  # the page. Laid out on a page of another size and then stretched onto the
  # canvas, as ggplotify::as.grob() lays every drawing out on a 7 x 7 in
  # page, the distance stretched with it, and at 4 x 3 in the title was cut
  # off at the top.
  from_top <- function(size) {
    svg <- render_sized(function() plot(1:10, main = "Title"), size)
    svg <- paste(as.character(svg), collapse = "\n")
    title <- 'id="graphics-plot-1-main-1\\.1\\.1" transform="translate\\([^)]*\\)'
    group <- regmatches(svg, regexpr(title, svg))
    y <- as.numeric(sub("^.*translate\\([^,]+, ([^)]+)\\)$", "\\1", group))
    # The page is drawn upward from its bottom edge.
    size[2] * 72 - y
  }
  distances <- vapply(chart_sizes, from_top, numeric(1))
  testthat::expect_true(all(abs(distances - distances[[1]]) < 0.5), info = toString(distances))
  testthat::expect_true(all(distances > 0))
})

test_that("a Base R chart too small for its margins stops, naming the size and R's reason", {
  skip_if_no_render()
  # Base R gives a chart's margins and text the same room in inches on any
  # page, and R stops when a page leaves the plot none. maidr draws the
  # chart again at the size asked for, so it meets this where the device
  # the chart was drawn on did not. Each case here stops in R at its size;
  # maidr answered with an empty chart, for several panels after the same
  # warning a few times over.
  too_small <- list(
    list(draw = function() barplot(c(a = 1, b = 2, c = 3)), size = c(6, 1.5)),
    list(draw = function() hist(mtcars$mpg), size = c(1.2, 4)),
    list(
      draw = function() {
        par(mfrow = c(2, 2))
        for (i in 1:4) plot(1:5)
      },
      size = c(4, 3)
    ),
    list(
      draw = function() {
        par(mfcol = c(2, 1))
        barplot(c(a = 1, b = 2))
        plot(1:5)
      },
      size = c(6, 1.5)
    )
  )
  for (case in too_small) {
    reason <- native_error(case$draw, case$size)
    testthat::expect_false(is.na(reason))
    said <- NULL
    testthat::expect_no_warning(
      said <- testthat::expect_error(
        render_sized(case$draw, case$size),
        class = "maidr_chart_draw_error"
      )
    )
    expected <- sprintf(
      "maidr could not draw this chart at %g x %g in: %s.",
      case$size[1], case$size[2], reason
    )
    testthat::expect_match(conditionMessage(said), expected, fixed = TRUE)
  }

  # Not a picture in its place either, which is drawn at the same size.
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device), add = TRUE)
  maidr:::clear_device_storage(device)
  on.exit(maidr:::clear_device_storage(device), add = TRUE)
  barplot(c(a = 1, b = 2, c = 3))
  file <- withr::local_tempfile(fileext = ".html")
  testthat::expect_error(
    save_html(file = file, width = 6, height = 1.5),
    class = "maidr_chart_draw_error"
  )
  testthat::expect_false(file.exists(file))

  # A chart R draws at the size is drawn: three panels in a row leave each
  # smaller margins, which fit 6 x 1.5 in.
  three <- function() {
    layout(matrix(1:3, 1))
    for (i in 1:3) plot(1:5)
  }
  testthat::expect_true(is.na(native_error(three, c(6, 1.5))))
  testthat::expect_identical(
    size_free_schema(render_sized(three, c(6, 1.5))),
    size_free_schema(render_sized(three, c(7, 5)))
  )
})

test_that("a Base R chart is drawn with the margins its par() calls set", {
  skip_if_no_render()
  # The size of each plot's box in a chart's SVG, in pixels.
  drawn_plots <- function(markup) {
    box <- '<polygon id="graphics-plot-[0-9]+-box-[^>]*>'
    boxes <- regmatches(markup, gregexpr(box, markup))[[1]]
    lapply(boxes, function(polygon) {
      points <- sub('^.*points="([^"]*)".*$', "\\1", polygon)
      xy <- matrix(as.numeric(unlist(strsplit(points, "[ ,]"))), ncol = 2, byrow = TRUE)
      c(diff(range(xy[, 1])), diff(range(xy[, 2])))
    })
  }
  expect_plots_as_r_draws <- function(draw, size) {
    markup <- paste(render_sized(draw, size), collapse = "\n")
    testthat::expect_equal(drawn_plots(markup), native_plots(draw, size), tolerance = 1e-3)
    invisible(markup)
  }

  # Each plot has the room the margins in effect when it was drawn leave
  # it, and a margin set after the last plot -- putting the device back --
  # changes nothing.
  expect_plots_as_r_draws(function() {
    op <- par(mar = rep(0.5, 4))
    plot(1:5)
    par(op)
  }, c(7, 5))
  expect_plots_as_r_draws(function() {
    par(mfrow = c(1, 2), oma = c(0, 0, 2, 0))
    plot(1:5)
    par(mai = c(0.3, 0.3, 0.1, 0.1))
    plot(1:5)
  }, c(7, 5))
  expect_plots_as_r_draws(function() {
    par(cex = 0.6, mex = 0.8)
    plot(1:5)
  }, c(7, 5))

  # So a grid R draws at a size with margins of its own is drawn there, as
  # a size asked for, not called too small for R's own margins.
  five <- function() {
    par(mfrow = c(5, 1), mar = c(1, 2, 1, 1))
    for (i in 1:5) plot(1:5)
  }
  drawn <- NULL
  testthat::expect_no_message(drawn <- expect_plots_as_r_draws(five, c(7, 5)))
  testthat::expect_identical(svg_size(drawn), svg_size_for(c(7, 5)))
  testthat::expect_identical(size_free_schema(drawn), size_free_schema(render_sized(five, c(7, 7))))

  # A grid set up after the text was made smaller puts it back, as R does,
  # and a grid R then cannot draw stops.
  smaller_first <- function() {
    par(cex = 0.4)
    par(mfrow = c(5, 1))
    for (i in 1:5) plot(1:5)
  }
  testthat::expect_false(is.na(native_error(smaller_first, c(7, 5))))
  testthat::expect_error(render_sized(smaller_first, c(7, 5)), class = "maidr_chart_draw_error")
})

test_that("a Base R chart too small for a size no one asked for is drawn larger, saying so once", {
  testthat::skip_on_cran()
  skip_if_no_render()
  # maidr laid every Base R chart out on a 7 x 7 in page before it drew one
  # at its size, so a grid of five rows, which R cannot draw at maidr's own
  # 7 x 5 in, was drawn. With no size asked for it still is, on that page.
  five <- grid_of(5)
  testthat::expect_false(is.na(native_error(five, c(7, 5))))
  testthat::expect_true(is.na(native_error(five, c(7, 7))))
  drawn <- NULL
  testthat::expect_no_warning(drawn <- with_messages(render_sized(five, NULL)))
  testthat::expect_identical(svg_size(drawn$value), svg_size_for(c(7, 7)))
  testthat::expect_length(drawn$said, 1L)
  testthat::expect_match(
    drawn$said,
    paste(
      "maidr: this Base R chart is drawn at 7 x 7 in rather than 7 x 5 in, where",
      "its margins and text leave the plot no room. Give it a size of its own"
    ),
    fixed = TRUE
  )
  # The chart asked for at 7 x 7 in, which says nothing.
  asked <- with_messages(render_sized(five, c(7, 7)))
  testthat::expect_length(asked$said, 0L)
  testthat::expect_identical(size_free_schema(drawn$value), size_free_schema(asked$value))

  # One that page is too small for too is drawn on the smallest page larger
  # than 7 x 5 in, in whole inches, on which R gives each of its plots a
  # sixth of an inch, 12 px, each way, grown only on the side it needs.
  # The least page R draws a grid of six rows on, 7 x 8 in, leaves each
  # plot 8.6 px high; of nine rows, 0.6 px.
  smallest <- function(draw, side) {
    page <- c(7, 5)
    repeat {
      plots <- native_plots(draw, page)
      if (!is.null(plots) && min(unlist(plots)) >= 12) {
        return(page)
      }
      page[side] <- page[side] + 1
    }
  }
  expect_drawn_at <- function(draw, page) {
    drawn <- with_messages(render_sized(draw, NULL))
    testthat::expect_identical(svg_size(drawn$value), svg_size_for(page))
    testthat::expect_length(drawn$said, 1L)
    testthat::expect_match(
      drawn$said,
      sprintf("drawn at %g x %g in rather than 7 x 5 in", page[1], page[2]),
      fixed = TRUE
    )
  }
  for (case in list(
    list(draw = grid_of(6), side = 2),
    list(draw = grid_of(9), side = 2),
    list(draw = grid_of(1, 12), side = 1)
  )) {
    page <- smallest(case$draw, case$side)
    testthat::expect_gt(page[case$side], 7)
    expect_drawn_at(case$draw, page)
  }
  # A grid no page up to the largest gives that room is drawn on the
  # smallest page R draws it on.
  forty <- grid_of(40)
  page <- c(7, 5)
  while (!is.na(native_error(forty, page))) {
    page[2] <- page[2] + 1
  }
  testthat::expect_lt(min(unlist(native_plots(forty, c(7, 50)))), 12)
  expect_drawn_at(forty, page)

  # The same through every entry point that takes no size, each saying it
  # once.
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device), add = TRUE)
  maidr:::clear_device_storage(device)
  on.exit(maidr:::clear_device_storage(device), add = TRUE)
  shown <- NULL
  testthat::local_mocked_bindings(
    display_html = function(html_doc) shown <<- html_doc,
    maidr_internet_available = function() FALSE,
    .package = "maidr"
  )
  file <- withr::local_tempfile(fileext = ".html")
  entry_points <- list(
    save_html = function() {
      save_html(file = file)
      readLines(file, warn = FALSE)
    },
    show = function() {
      maidr::show()
      shown
    },
    shiny = function() maidr::show(shiny = TRUE),
    widget = function() {
      widget <- maidr::show(as_widget = TRUE, use_cdn = FALSE)
      unescape_markup(widget$x$iframe_content)
    }
  )
  for (name in names(entry_points)) {
    five()
    drawn <- with_messages(entry_points[[name]]())
    testthat::expect_identical(svg_size(drawn$value), svg_size_for(c(7, 7)), label = name)
    testthat::expect_length(drawn$said, 1L)
  }
})

test_that("only the page a Base R chart shows settles its size", {
  skip_if_no_render()
  # Of two charts drawn one after the other on a device of one panel, R
  # shows the second, on a page of its own, and so does maidr. A heatmap
  # with wide margins, which R cannot draw at 7 x 5 in, settles the size
  # when it is shown, and says nothing of the chart drawn after it.
  m <- matrix(1:20, 4)
  heat <- function() heatmap(m, margins = c(25, 25))
  # R warns as well as stops, of the plot it then has not started.
  testthat::expect_false(is.na(suppressWarnings(native_error(heat, c(7, 5)))))
  heat_last <- function() {
    plot(1:5)
    heat()
  }
  drawn <- with_messages(render_sized(heat_last, NULL))
  testthat::expect_identical(svg_size(drawn$value), svg_size_for(c(7, 7)))
  testthat::expect_length(drawn$said, 1L)
  testthat::expect_error(
    suppressWarnings(render_sized(heat_last, c(7, 5))),
    class = "maidr_chart_draw_error"
  )
  # Drawn before the chart shown, the heatmap neither enlarges it nor stops it.
  heat_first <- function() {
    heat()
    plot(1:5)
  }
  for (size in list(NULL, c(7, 5))) {
    drawn <- with_messages(render_sized(heat_first, size))
    testthat::expect_identical(svg_size(drawn$value), svg_size_for(c(7, 5)))
    testthat::expect_length(drawn$said, 0L)
  }
})

test_that("a size asked for that a Base R chart is too small for still stops", {
  skip_if_no_render()
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device), add = TRUE)
  maidr:::clear_device_storage(device)
  on.exit(maidr:::clear_device_storage(device), add = TRUE)
  five <- grid_of(5)
  file <- withr::local_tempfile(fileext = ".html")

  # maidr's own size, asked for, is not enlarged: the author is told why it
  # cannot be drawn there.
  five()
  testthat::expect_no_message(
    testthat::expect_error(
      save_html(file = file, width = 7, height = 5),
      "maidr could not draw this chart at 7 x 5 in: figure margins too large.",
      fixed = TRUE,
      class = "maidr_chart_draw_error"
    )
  )
  testthat::expect_false(file.exists(file))
  # Nor is one side asked for, the other maidr's own.
  testthat::expect_error(
    maidr::show(shiny = TRUE, height = 5),
    "maidr could not draw this chart at 7 x 5 in",
    class = "maidr_chart_draw_error"
  )
  testthat::expect_error(
    maidr::show(shiny = TRUE, width = 6),
    "maidr could not draw this chart at 6 x 5 in",
    class = "maidr_chart_draw_error"
  )
})

test_that("a Base R chart keeps the tick labels R draws at its size, and only those", {
  testthat::skip_on_cran()
  skip_if_no_render()
  # R's axis() leaves out a tick label that would come too close to the last
  # one it drew; gridGraphics echoed them all, and they ran into each other.
  # What R draws is read from its own pdf device, whose font metrics are the
  # ones maidr measures with: each text it shows, as a string.
  drawn_by_r <- function(draw, size) {
    file <- withr::local_tempfile(fileext = ".pdf")
    grDevices::pdf(file, width = size[1], height = size[2], compress = FALSE)
    draw()
    grDevices::dev.off()
    # The file's streams are binary; its text lines are ASCII.
    shown <- grep("T[jJ]$", readLines(file, warn = FALSE), value = TRUE, useBytes = TRUE)
    strings <- regmatches(shown, gregexpr("\\(([^)]*)\\)", shown, useBytes = TRUE))
    sort(vapply(strings, function(parts) {
      paste(substr(parts, 2L, nchar(parts) - 1L), collapse = "")
    }, character(1)))
  }
  drawn_by_maidr <- function(draw, size) {
    svg <- paste(as.character(render_sized(draw, size)), collapse = "")
    shown <- regmatches(svg, gregexpr("<text[^>]*>[^<]*</text>", svg))[[1]]
    sort(unescape_markup(gsub("<[^>]+>", "", shown)))
  }
  numbers <- c(11, 12, 13, 14)
  reversed <- function() plot(1:10, xlim = c(10, 1), main = "Reversed", xlab = "x", ylab = "y")
  # Short panels, whose y axes R thins at 7 x 5 in and more at 10 x 4.
  grid_of_four <- function() {
    par(mfrow = c(2, 2))
    for (i in 1:4) {
      plot(1:10, seq(10, 14, length.out = 10), main = letters[i], xlab = "x", ylab = "y")
    }
  }
  charts <- list(
    list(function() barplot(numbers, names.arg = c("a", "b", "c", "d"), main = "Bars"), c(4, 3)),
    list(function() barplot(numbers * 1000, las = 1, main = "Across"), c(4, 3)),
    list(function() image(matrix(1:12, 3, 4), main = "Cells"), c(4, 3)),
    list(reversed, c(4, 3)),
    list(grid_of_four, c(10, 4)),
    list(grid_of_four, c(7, 5))
  )
  for (chart in charts) {
    drawing <- deparse(body(chart[[1]]))[1]
    testthat::expect_identical(
      drawn_by_maidr(chart[[1]], chart[[2]]),
      drawn_by_r(chart[[1]], chart[[2]]),
      label = sprintf("%s at %g x %g in", drawing, chart[[2]][1], chart[[2]][2])
    )
  }
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

test_that("lattice lays a conditioned chart's panels out for the page it is drawn on", {
  testthat::skip_on_cran()
  skip_if_no_render()
  skip_if_no_lattice()
  # With no `layout =`, lattice picks the columns of a chart conditioned on
  # one variable from the shape of the page. That is the one part of the
  # data a size changes: the subplot grid is the panels as lattice lays them
  # out at that size.
  three <- data.frame(
    x = rep(1:5, 3),
    y = c(1:5, 5:1, 3, 3, 3, 3, 3),
    g = rep(c("a", "b", "c"), each = 5)
  )
  chart <- lattice::xyplot(y ~ x | g, data = three)
  native_layout <- function(size) {
    grDevices::pdf(NULL, width = size[1], height = size[2])
    on.exit(grDevices::dev.off(), add = TRUE)
    utils::getS3method("plot", "trellis")(chart)
    dim(lattice::trellis.currentLayout())
  }
  grid_shape <- function(size) {
    data <- size_free_schema(render_sized(chart, size))
    c(length(data$subplots), max(lengths(data$subplots)))
  }
  testthat::expect_identical(grid_shape(c(7, 5)), c(1L, 3L))
  testthat::expect_identical(grid_shape(c(5, 8)), c(2L, 2L))
  for (size in list(c(7, 5), c(5, 8))) {
    testthat::expect_identical(grid_shape(size), as.integer(native_layout(size)))
  }
})

# ==============================================================================
# The entry points
# ==============================================================================

test_that("save_html() and show() draw the chart at width x height", {
  skip_if_no_render()
  p <- create_test_ggplot_bar()
  file <- withr::local_tempfile(fileext = ".html")

  save_html(p, file)
  testthat::expect_identical(svg_size(readLines(file)), svg_size_for(c(7, 5)))
  save_html(p, file, width = 4, height = 3)
  testthat::expect_identical(svg_size(readLines(file)), svg_size_for(c(4, 3)))
  # A side not given is maidr's own.
  save_html(p, file, width = 10)
  testthat::expect_identical(svg_size(readLines(file)), svg_size_for(c(10, 5)))

  shown <- NULL
  testthat::local_mocked_bindings(
    display_html = function(html_doc) shown <<- html_doc,
    .package = "maidr"
  )
  maidr::show(p, width = 10, height = 4)
  testthat::expect_identical(svg_size(shown), svg_size_for(c(10, 4)))
  testthat::expect_identical(
    svg_size(maidr::show(p, shiny = TRUE, width = 5, height = 8)),
    svg_size_for(c(5, 8))
  )
})

test_that("a Base R chart drawn and then shown is drawn at width x height", {
  skip_if_no_render()
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device), add = TRUE)
  maidr:::clear_device_storage(device)
  on.exit(maidr:::clear_device_storage(device), add = TRUE)

  barplot(c(3, 5, 7), names.arg = c("x", "y", "z"))
  file <- withr::local_tempfile(fileext = ".html")
  save_html(file = file, width = 10, height = 4)
  testthat::expect_identical(svg_size(readLines(file)), svg_size_for(c(10, 4)))

  # The size of the device it was drawn on is not the chart's.
  grDevices::pdf(NULL, width = 3, height = 9)
  other <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(other), add = TRUE)
  maidr:::clear_device_storage(other)
  barplot(c(3, 5, 7), names.arg = c("x", "y", "z"))
  save_html(file = file)
  testthat::expect_identical(svg_size(readLines(file)), svg_size_for(c(7, 5)))
})

test_that("the widget's fig_width and fig_height size the chart, and width its frame", {
  skip_if_no_render()
  p <- create_test_ggplot_bar()
  widget <- maidr:::maidr_widget(
    p,
    use_cdn = FALSE,
    width = "300px",
    height = "200px",
    fig_width = 10,
    fig_height = 4
  )
  testthat::expect_identical(widget$width, "300px")
  testthat::expect_identical(widget$height, "200px")
  frame <- unescape_markup(widget$x$iframe_content)
  testthat::expect_identical(svg_size(frame), svg_size_for(c(10, 4)))

  # show(as_widget = TRUE) takes the size as show() does.
  widget <- maidr::show(p, as_widget = TRUE, use_cdn = FALSE, width = 5, height = 8)
  frame <- unescape_markup(widget$x$iframe_content)
  testthat::expect_identical(svg_size(frame), svg_size_for(c(5, 8)))

  # Its `width` once reached the widget as a CSS size; one given so is told
  # how to size the widget now, which works.
  testthat::expect_error(
    maidr::show(p, as_widget = TRUE, width = "300px"),
    "not a CSS size. Size the widget that `show(as_widget = TRUE)` returns",
    fixed = TRUE
  )
  testthat::expect_error(
    maidr::show(p, as_widget = TRUE, fig_width = 3),
    "show() takes the size to draw the chart at as `width` and `height`.",
    fixed = TRUE
  )
  widget$width <- "300px"
  testthat::expect_match(
    as.character(htmltools::as.tags(widget)),
    'style="width:300px;',
    fixed = TRUE
  )
})

test_that("render_maidr() draws its chart at fig_width x fig_height, a Base R one too", {
  testthat::skip_if_not_installed("shiny")
  skip_if_no_render()
  maidr:::clear_all_device_storage()
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)
  testthat::local_mocked_bindings(maidr_internet_available = function() FALSE, .package = "maidr")
  frame_size <- function(value) {
    payload <- jsonlite::parse_json(as.character(value))
    svg_size(unescape_markup(payload$x$iframe_content))
  }
  server <- function(input, output, session) {
    output$gg <- render_maidr(create_test_ggplot_bar(), fig_width = 10, fig_height = 4)
    output$base <- render_maidr(barplot(c(a = 1, b = 2)), fig_width = 5, fig_height = 8)
    output$plain <- render_maidr(create_test_ggplot_bar())
  }
  shiny::testServer(server, {
    testthat::expect_identical(frame_size(output$gg), svg_size_for(c(10, 4)))
    testthat::expect_identical(frame_size(output$base), svg_size_for(c(5, 8)))
    testthat::expect_identical(frame_size(output$plain), svg_size_for(c(7, 5)))
  })
})

test_that("a chart shown as a picture is drawn at the size asked for", {
  skip_if_no_render()
  # A text layer maidr does not read.
  p <- ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y, label = x)) +
    ggplot2::geom_text()
  file <- withr::local_tempfile(fileext = ".html")
  suppressWarnings(save_html(p, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  testthat::expect_equal(embedded_png_size(html), c(7, 5) * 150)
  suppressWarnings(save_html(p, file, width = 4, height = 3))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  testthat::expect_equal(embedded_png_size(html), c(4, 3) * 150)
})

test_that("a Base R chart shown as a picture is held to its size as its chart is", {
  skip_if_no_render()
  # maidr does not read persp(), so the chart is a picture, drawn by R from
  # every recorded call. R cannot draw five of them in a column at 7 x 5 in,
  # and the picture was left blank, warning once a panel.
  five <- function() {
    par(mfrow = c(5, 1))
    for (i in 1:5) persp(volcano)
  }
  testthat::expect_false(is.na(native_error(five, c(7, 5))))
  grDevices::pdf(NULL, width = 50, height = 50)
  device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device), add = TRUE)
  maidr:::clear_device_storage(device)
  on.exit(maidr:::clear_device_storage(device), add = TRUE)
  file <- withr::local_tempfile(fileext = ".html")
  saved <- function(...) {
    warned <- character()
    drawn <- withCallingHandlers(
      with_messages(save_html(file = file, ...)),
      warning = function(w) {
        warned <<- c(warned, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    testthat::expect_identical(
      warned,
      paste(
        "Plot contains unsupported elements. Rendering as static image instead of",
        "interactive MAIDR plot."
      )
    )
    list(
      said = drawn$said,
      picture = embedded_png_size(paste(readLines(file, warn = FALSE), collapse = "\n"))
    )
  }

  # With no size asked for, it is drawn larger, as its chart would be, and
  # says so once.
  five()
  drawn <- saved()
  testthat::expect_equal(drawn$picture, c(7, 7) * 150)
  testthat::expect_length(drawn$said, 1L)
  testthat::expect_match(drawn$said, "drawn at 7 x 7 in rather than 7 x 5 in", fixed = TRUE)

  # A size asked for stops, naming it, rather than draw a blank picture.
  five()
  unlink(file)
  testthat::expect_error(
    save_html(file = file, width = 7, height = 5),
    "maidr could not draw this chart at 7 x 5 in: figure margins too large.",
    fixed = TRUE,
    class = "maidr_chart_draw_error"
  )
  testthat::expect_false(file.exists(file))
  maidr:::clear_device_storage(device)

  # A picture R draws at the size is drawn there, saying nothing. The device
  # is put back to one panel first: under the grid five() left on it, R
  # draws the plot in the top fifth of the page, and so does maidr.
  par(mfrow = c(1, 1))
  persp(volcano)
  drawn <- saved()
  testthat::expect_equal(drawn$picture, c(7, 5) * 150)
  testthat::expect_length(drawn$said, 0L)
})

# ==============================================================================
# knitr: the chunk's fig.width and fig.height
# ==============================================================================

test_that("a knitted chart is drawn at its chunk's fig.width and fig.height", {
  testthat::skip_on_cran()
  skip_if_no_render()
  skip_if_no_lattice()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")

  page <- knit_for(c(
    "```{r gg, fig.width = 10, fig.height = 4}",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "```",
    "",
    "```{r loop, fig.width = 5, fig.height = 8}",
    "for (i in 1:2) print(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point())",
    "```",
    "",
    "```{r lat, fig.width = 6, fig.asp = 0.5}",
    "lattice::xyplot(mpg ~ wt, data = mtcars)",
    "```",
    "",
    "```{r base, fig.dim = c(4, 3)}",
    "barplot(c(3, 5, 7), names.arg = c('x', 'y', 'z'))",
    "```",
    "",
    "```{r asked, fig.width = 9, fig.height = 3, results = 'asis'}",
    "scatter <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()",
    "cat(knitr::knit_print(scatter))",
    "```",
    "",
    "```{r unset}",
    "ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()",
    "```"
  ), dir)

  testthat::expect_identical(lapply(inline_svg_roots(page), svg_size), list(
    svg_size_for(c(10, 4)),
    svg_size_for(c(5, 8)),
    svg_size_for(c(5, 8)),
    svg_size_for(c(6, 3)),
    svg_size_for(c(4, 3)),
    svg_size_for(c(9, 3)),
    # knitr::knit()'s own default; R Markdown's html_document and Quarto
    # set 7 x 5.
    svg_size_for(c(7, 7))
  ))
})

test_that("a knitted chart in an iframe is drawn at its chunk's figure size", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  testthat::local_mocked_bindings(maidr_internet_available = function() FALSE, .package = "maidr")
  hooks <- knitr::knit_hooks$get()
  knitr::knit_hooks$restore()
  on.exit(knitr::knit_hooks$restore(hooks), add = TRUE)
  withr::local_dir(dir)

  writeLines(c(
    "<html><body>",
    "<!--begin.rcode chart, fig.width = 10, fig.height = 4",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "end.rcode-->",
    "</body></html>"
  ), "chart.Rhtml")
  out <- knitr::knit("chart.Rhtml", quiet = TRUE, envir = new.env())
  page <- paste(readLines(out), collapse = "\n")
  testthat::expect_match(page, "<iframe", fixed = TRUE)
  testthat::expect_identical(svg_size(unescape_markup(page)), svg_size_for(c(10, 4)))
})

test_that("a knitted candlestick chart enlarged past its chunk's size says so in the document", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("tidyquant")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  page <- knit_for(c(
    "```{r data}",
    "ohlc <- data.frame(",
    "  date = as.Date('2023-01-02') + 0:3, open = c(100, 105, 110, 108),",
    "  high = c(115, 108, 112, 110), low = c(95, 102, 105, 100), close = c(110, 103, 111, 108)",
    ")",
    "candles <- ggplot2::ggplot(",
    "  ohlc, ggplot2::aes(date, open = open, high = high, low = low, close = close)",
    ") +",
    "  tidyquant::geom_candlestick()",
    "```",
    "",
    "```{r unset}",
    "candles",
    "```",
    "",
    "```{r asked, fig.width = 8, fig.height = 4}",
    "candles",
    "```",
    "",
    "```{r document-size}",
    "knitr::opts_chunk$set(fig.width = 6, fig.asp = 0.5)",
    "```",
    "",
    "```{r document}",
    "candles",
    "```"
  ), dir)
  # Only the chunk that asked for a size of its own is told: the document's
  # figure size, knitr's 7 x 7 in here and then one opts_chunk$set() sets,
  # is every chart's, and a candlestick chart is drawn larger than it
  # without a word, as it was before maidr read the chunk's size.
  said <- regmatches(page, gregexpr("maidr: this candlestick chart is drawn at [^:]*", page))[[1]]
  testthat::expect_identical(
    said,
    "maidr: this candlestick chart is drawn at 12 x 6 in rather than the 8 x 4 in asked for"
  )
  # Each still at least 12 x 6 in, and as tall as knitr's 7 in where that
  # is taller.
  testthat::expect_identical(
    lapply(inline_svg_roots(page), svg_size),
    list(svg_size_for(c(12, 7)), svg_size_for(c(12, 6)), svg_size_for(c(12, 6)))
  )
})

test_that("a knitted Base R chart is drawn larger than the document's size, not its chunk's", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  # R draws these six panels in their chunk, in the plot region par(plt = )
  # gives each. maidr draws a Base R chart again with the margins R had,
  # not with a plot region par(plt = ) set: it draws these with R's own
  # margins, which six panels do not fit on a page 7 in high or less, and
  # are drawn on one 9 in high.
  unrecorded <- c(
    "par(mfrow = c(6, 1))", "par(plt = c(0.1, 0.95, 0.15, 0.85))", "for (i in 1:6) plot(1:5)"
  )
  recorded <- c("par(mfrow = c(6, 1), mar = c(1, 2, 1, 1))", "for (i in 1:6) plot(1:5)")
  # Margins set by a par() maidr does not record, called by name, are
  # those R had too.
  by_name <- c(
    "par(mfrow = c(6, 1))", "graphics::par(mar = c(1, 2, 1, 1))", "for (i in 1:6) plot(1:5)"
  )
  warned <- character()
  knitted <- withCallingHandlers(
    with_messages(knit_for(c(
      "```{r unset}", unrecorded, "```", "",
      "```{r document-size}", "knitr::opts_chunk$set(fig.height = 6)", "```", "",
      "```{r document}", unrecorded, "```", "",
      "```{r asked, fig.height = 6.5}", unrecorded, "```", "",
      "```{r recorded, fig.height = 6.5}", recorded, "```", "",
      "```{r by-name, fig.height = 6.5}", by_name, "```"
    ), dir)),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  # The document's figure size, knitr's 7 x 7 in and then the 7 x 6 in
  # opts_chunk$set() sets, was not asked of the chart: it is drawn larger,
  # and says so, once each.
  testthat::expect_identical(
    grep("^maidr: this Base R chart", knitted$said, value = TRUE),
    c(
      paste(
        "maidr: this Base R chart is drawn at 7 x 9 in rather than 7 x 7 in, where",
        "its margins and text leave the plot no room. Give it a size of its own to",
        "draw it at another.\n"
      ),
      paste(
        "maidr: this Base R chart is drawn at 7 x 9 in rather than 7 x 6 in, where",
        "its margins and text leave the plot no room. Give it a size of its own to",
        "draw it at another.\n"
      )
    )
  )
  # The chunks that set their margins with par() are drawn at their own
  # size.
  testthat::expect_identical(
    lapply(inline_svg_roots(knitted$value), svg_size),
    list(
      svg_size_for(c(7, 9)), svg_size_for(c(7, 9)), svg_size_for(c(7, 6.5)),
      svg_size_for(c(7, 6.5))
    )
  )
  # A size the chunk asked for is not changed: its figure stays knitr's
  # picture, and the warning says why.
  testthat::expect_length(warned, 1L)
  testthat::expect_match(
    warned,
    "a chart in chunk 'asked' could not be made accessible",
    fixed = TRUE
  )
  testthat::expect_match(warned, "maidr could not draw this chart at 7 x 6.5 in", fixed = TRUE)
})

test_that("R Markdown and Quarto draw their charts at the figure size they set", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  dir <- withr::local_tempdir("maidr-sized-")
  chunks <- c(
    "```{r}", maidr_loader(), "library(ggplot2)", "```",
    "```{r}", "ggplot(mtcars, aes(wt, mpg)) + geom_point()", "```",
    "```{r, fig.width = 10, fig.height = 4}",
    "ggplot(mtcars, aes(factor(cyl))) + geom_bar()",
    "```",
    "```{r, fig.width = 5, fig.asp = 1.6}", "barplot(c(a = 1, b = 2))", "```"
  )
  page_sizes <- function(file) {
    lapply(inline_svg_roots(paste(readLines(file, warn = FALSE), collapse = "\n")), svg_size)
  }

  # html_document's own figure size is maidr's, 7 x 5 in.
  rmd <- file.path(dir, "plain.Rmd")
  writeLines(c("---", "title: plain", "output: html_document", "---", chunks), rmd)
  html <- render_in_session(rmd)
  testthat::expect_identical(
    page_sizes(html),
    list(svg_size_for(c(7, 5)), svg_size_for(c(10, 4)), svg_size_for(c(5, 8)))
  )

  # One set in the YAML is every chunk's that sets none.
  rmd <- file.path(dir, "yaml.Rmd")
  writeLines(c(
    "---", "title: yaml", "output:", "  html_document:",
    "    fig_width: 6", "    fig_height: 4", "---", chunks
  ), rmd)
  testthat::expect_identical(
    page_sizes(render_in_session(rmd)),
    list(svg_size_for(c(6, 4)), svg_size_for(c(10, 4)), svg_size_for(c(5, 8)))
  )

  quarto <- Sys.which("quarto")
  testthat::skip_if(!nzchar(quarto), "Quarto is not installed")
  withr::local_envvar(QUARTO_R = R.home("bin"))
  qmd <- file.path(dir, "sized.qmd")
  writeLines(c(
    "---", "title: sized", "format: html", "---",
    "```{r}", "#| message: false",
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    maidr_loader(), "library(ggplot2)", "```",
    "```{r}", "ggplot(mtcars, aes(wt, mpg)) + geom_point()", "```",
    "```{r}", "#| fig-width: 10", "#| fig-height: 4",
    "lattice::xyplot(mpg ~ wt, data = mtcars)", "```",
    "```{r}", "#| fig-width: 5", "#| fig-height: 8", "barplot(c(a = 1, b = 2))", "```"
  ), qmd)
  status <- system2(quarto, c("render", shQuote(qmd), "--quiet"), stdout = TRUE, stderr = TRUE)
  testthat::expect_null(attr(status, "status"), info = paste(status, collapse = "\n"))
  testthat::expect_identical(
    page_sizes(file.path(dir, "sized.html")),
    list(svg_size_for(c(7, 5)), svg_size_for(c(10, 4)), svg_size_for(c(5, 8)))
  )
})
