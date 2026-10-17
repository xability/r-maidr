# Under webR, show() and save_html() finish the chart's SVG without xml2
# (finish_svg_markup(), #388). These hold that path to the xml2 one byte for
# byte, on the SVG real charts export, so neither can change without the
# other.

# The SVG and data a chart reaches finish_svg() with.
finish_inputs <- function(draw) {
  got <- NULL
  finish <- maidr:::finish_svg
  testthat::local_mocked_bindings(
    finish_svg = function(svg_content, maidr_data, candlestick = FALSE) {
      got <<- list(svg = svg_content, data = maidr_data, candlestick = candlestick)
      finish(svg_content, maidr_data, candlestick = candlestick)
    },
    .package = "maidr"
  )
  file <- withr::local_tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  draw(file)
  got
}

expect_same_svg <- function(inputs) {
  testthat::expect_false(is.null(inputs))
  via_xml2 <- maidr:::finish_svg_xml2(inputs$svg, inputs$data, inputs$candlestick)
  via_markup <- maidr:::finish_svg_markup(inputs$svg, inputs$data, inputs$candlestick)
  testthat::expect_identical(via_markup, via_xml2)
  invisible(via_markup)
}

test_that("a ggplot2 bar chart is finished as xml2 finishes it", {
  rows <- data.frame(x = c("a", "b & <c>", "é \"q\""), y = c(3, 5, 2))
  inputs <- finish_inputs(function(file) {
    maidr::save_html(
      ggplot2::ggplot(rows, ggplot2::aes(x, y)) + ggplot2::geom_col() +
        ggplot2::ggtitle("Title 'quoted' > here  "),
      file
    )
  })
  svg <- expect_same_svg(inputs)
  expect_match(svg[[2]], "maidr-data=", fixed = TRUE)
})

test_that("a faceted ggplot2 scatter plot is finished as xml2 finishes it", {
  rows <- data.frame(x = 1:30, y = sin(1:30), g = rep(c("p", "q", "r"), 10))
  expect_same_svg(finish_inputs(function(file) {
    maidr::save_html(
      ggplot2::ggplot(rows, ggplot2::aes(x, y)) + ggplot2::geom_point() +
        ggplot2::facet_wrap(~g),
      file
    )
  }))
})

test_that("Base R plots are finished as xml2 finishes them", {
  maidr:::clear_all_device_storage()
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)
  expect_same_svg(finish_inputs(function(file) {
    barplot(c(a = 3, b = 5, c = 2), main = " spaced  title ")
    maidr::save_html(file = file)
  }))
  expect_same_svg(finish_inputs(function(file) {
    plot(1:20, (1:20)^2, main = "points")
    maidr::save_html(file = file)
  }))
})

test_that("a pheatmap is finished as xml2 finishes it", {
  skip_if_not_installed("pheatmap")
  m <- matrix(c(1.5, -2, 0.25, 3, 4, -1, 2, 0.5, 1, -3, 2.5, 0), nrow = 3)
  expect_same_svg(finish_inputs(function(file) {
    suppressMessages(maidr::save_html(pheatmap::pheatmap(m, silent = TRUE), file))
  }))
})

test_that("a chartSeries candlestick chart is finished as xml2 finishes it", {
  skip_if_not_installed("quantmod")
  skip_if_not_installed("xts")
  maidr:::clear_all_device_storage()
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)
  m <- cbind(
    Open = c(100, 105, 110, 108), High = c(115, 108, 112, 110),
    Low = c(95, 102, 105, 100), Close = c(110, 103, 111, 108),
    Volume = c(1000, 1500, 1200, 800)
  )
  colnames(m) <- paste0("TST.", colnames(m))
  ohlc <- xts::xts(m, order.by = as.Date("2023-01-02") + 0:3)

  inputs <- finish_inputs(function(file) {
    maidr::chartSeries(ohlc, type = "candlesticks")
    maidr::save_html(plot = NULL, file = file)
  })
  expect_true(inputs$candlestick)
  svg <- paste(expect_same_svg(inputs), collapse = "\n")
  # The header and axis edits were made, so they were compared.
  expect_match(svg, 'text-anchor="end"', fixed = TRUE)
  expect_false(grepl("bottom-axis-ticks-", svg, fixed = TRUE))
  expect_false(grepl("right-axis-line-", svg, fixed = TRUE))
})

test_that("candlestick open and close marks are added as xml2 adds them", {
  # A ggplot2 candlestick's body group (tidyquant's geom_candlestick()); the
  # base R one names its rects directly and gets none.
  svg <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>\n',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50">\n',
    '<g id="panel.1">\n<g id="geom_rect.rect.57.1">\n',
    '<rect id="geom_rect.rect.57.1.1" x="1" y="2" width="3" height="4.5"/>\n',
    '<rect id="geom_rect.rect.57.1.2" x="11" y="12" width="3" height="4"/>\n',
    '<rect id="geom_rect.rect.57.1.3" x="21.25" y="22" width="3" height="0"/>\n',
    '<rect id="geom_rect.rect.57.1.4" x="31" y="bad" width="3" height="4"/>\n',
    "</g>\n</g>\n</svg>"
  )
  data <- list(subplots = list(list(list(layers = list(list(
    type = "candlestick",
    selectors = list(body = "#geom_rect\\.rect\\.57\\.1 rect"),
    data = list(
      list(trend = "Bull"), list(trend = "Bear"), list(trend = "Neutral"),
      list(trend = "Bull")
    )
  ))))))

  out <- paste(maidr:::finish_svg_markup(svg, data, candlestick = TRUE), collapse = "\n")

  expect_identical(out, paste(maidr:::finish_svg_xml2(svg, data, candlestick = TRUE), collapse = "\n"))
  expect_match(out, '<g id="maidr-cs-opens-57">', fixed = TRUE)
  expect_match(out, '<line id="maidr-cs-close-57-2" x1="11" y1="12" x2="14" y2="12"', fixed = TRUE)
  expect_false(grepl("maidr-cs-open-57-4", out, fixed = TRUE))
})

test_that("markup is read and written as libxml2 reads and writes it", {
  data <- list(id = "cé \"q\" <&> 'a'\n")
  cases <- c(
    no_declaration = paste0(
      '<svg xmlns="http://www.w3.org/2000/svg"><g id="a"><rect x="1"/></g></svg>'
    ),
    layout = paste0(
      '<?xml version="1.0" encoding="UTF-8"?>\n',
      '<svg xmlns="http://www.w3.org/2000/svg">\n<!-- c -->\n<g>\n<!-- d -->\n',
      "<a/></g>\n<g> </g>\n<g>\n</g>\n<g></g>\n",
      "<text>x<tspan>y</tspan>\n<b><c/></b></text>\n</svg>"
    ),
    attributes = paste0(
      "<svg version='1.1' xmlns='http://www.w3.org/2000/svg' ",
      'x="&#233;&apos;&#10;a\tb\nc &gt; d > e" y = \'q"r\' ',
      'xmlns:xlink="http://www.w3.org/1999/xlink" ><g id="&#x41;&#38;lt;" /></svg>'
    ),
    text = paste0(
      "<svg><text>é &quot;q&quot; &#13; &gt; > &#60; &apos;</text>",
      '<text xml:space="preserve">  two  </text></svg>'
    ),
    preserve = paste0(
      '<svg><text xml:space="preserve"><a/>\n<b/></text>\n',
      '<g xml:space="preserve">\n<a/>\n</g>\n',
      '<g xml:space="preserve"><h>\n<a/>\n<i xml:space="default">\n<j/>\n</i></h></g></svg>'
    ),
    deep = paste0("<svg>", strrep("<g>\n", 35), "<a/>", strrep("\n</g>", 35), "</svg>")
  )
  for (name in names(cases)) {
    expect_identical(
      maidr:::finish_svg_markup(cases[[name]], data),
      maidr:::finish_svg_xml2(cases[[name]], data),
      label = name
    )
  }
})

test_that("markup the export never writes is refused, not guessed at", {
  data <- list(id = "x")
  expect_error(maidr:::finish_svg_markup("<!DOCTYPE svg><svg/>", data), "without libxml2")
  expect_error(maidr:::finish_svg_markup("<svg><![CDATA[x]]></svg>", data), "without libxml2")
  expect_error(maidr:::finish_svg_markup("<svg><t>&nbsp;</t></svg>", data), "without libxml2")
  expect_error(maidr:::finish_svg_markup("<svg><g></svg>", data), "without libxml2")
  expect_error(maidr:::finish_svg_markup("<svg><g>a < b</g></svg>", data), "without libxml2")
})
