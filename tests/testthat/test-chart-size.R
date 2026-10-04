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
render_sized <- function(chart, size) {
  if (!is.function(chart)) {
    return(maidr:::create_maidr_html(chart, shiny = TRUE, width = size[1], height = size[2]))
  }
  grDevices::pdf(NULL)
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
embedded_png_size <- function(html) {
  uri <- regmatches(html, regexpr("data:image/png;base64,[A-Za-z0-9+/=]+", html))
  raw <- base64enc::base64decode(sub("^data:image/png;base64,", "", uri))
  dims <- dim(png::readPNG(raw))
  c(dims[2], dims[1])
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
  testthat::skip_if_not_installed("png")
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
    "```{r candles, fig.width = 8, fig.height = 4}",
    "ohlc <- data.frame(",
    "  date = as.Date('2023-01-02') + 0:3, open = c(100, 105, 110, 108),",
    "  high = c(115, 108, 112, 110), low = c(95, 102, 105, 100), close = c(110, 103, 111, 108)",
    ")",
    "ggplot2::ggplot(",
    "  ohlc, ggplot2::aes(date, open = open, high = high, low = low, close = close)",
    ") +",
    "  tidyquant::geom_candlestick()",
    "```"
  ), dir)
  said <- "drawn at 12 x 6 in rather than the 8 x 4 in asked for"
  testthat::expect_match(page, said, fixed = TRUE)
  testthat::expect_identical(lapply(inline_svg_roots(page), svg_size), list(svg_size_for(c(12, 6))))
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
