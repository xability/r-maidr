# Page-unique ids for a chart inlined into a page
#
# Charts inlined into one knitr page share one document, so every id of a
# chart gets a prefix of its own and everything that points at an id is
# rewritten with it: `url(#..)` and `href` references, the selectors in the
# maidr-data and the figure id. Nothing else may change -- a title, a data
# label or a data value that looks like a reference is the reader's text --
# and a selector the rewrite cannot scope to its chart refuses the chart
# rather than letting it reach into another one.

prefix <- "mtest-"

# The markup inside a fixture <svg>: definitions referenced every way the
# rewrite reads, a reference to an id the SVG lacks, and a title whose text
# reads like references to ids the SVG has.
fixture_body <- paste0(
  '<defs><symbol id="gridSVG.pch19"/><clipPath id="clip.1"/>',
  '<linearGradient id="pat-0"/></defs>',
  '<g id="g.rect.2.1" clip-path="url(#clip.1)">',
  '<rect id="g.rect.2.1.1" fill="url(#pat-0)"/>',
  "<rect id=\"g.rect.2.1.2\" fill=\"url('#pat-0')\" mask='url(\"#clip.1\")'/>",
  '<rect id="g.rect.2.1.3" fill="url( #pat-0 )" style="clip-path: url(#clip.1)"/>',
  '<rect id="g.rect.2.1.4" fill="url(#elsewhere)"/></g>',
  '<g id="pts.1"><use id="pts.1.1" xlink:href="#gridSVG.pch19"/>',
  '<use id="pts.1.2" href="#gridSVG.pch19"/><use href="#elsewhere"/></g>',
  '<text id="t.1">id="pat-0" url(#pat-0) href="#gridSVG.pch19"</text>'
)

# A maidr SVG with `json` as its maidr-data.
fixture_svg <- function(json, body = fixture_body) {
  paste0(
    '<?xml version="1.0" encoding="UTF-8"?>\n',
    '<svg xmlns="http://www.w3.org/2000/svg" ',
    'xmlns:xlink="http://www.w3.org/1999/xlink" width="10px" height="10px" ',
    'maidr-data="', htmltools::htmlEscape(json, attribute = TRUE), '">',
    body, "</svg>"
  )
}

# maidr-data with one layer carrying `selectors`, and data that reads like
# selectors and references, encoded as the package encodes it.
fixture_json <- function(selectors, pretty = FALSE) {
  layer <- list(
    id = 1L,
    type = "bar",
    title = 'say "#g" \\',
    selectors = selectors,
    data = list(
      list(x = '"selectors":"#g.rect.2.1"', y = 1),
      list(x = "#pts.1", y = NULL),
      list(x = "url(#pat-0)", y = 2)
    )
  )
  as.character(jsonlite::toJSON(
    list(
      id = "maidr-plot-1-2",
      subplots = list(list(list(
        id = "maidr-subplot-1-2",
        layers = list(layer),
        selector = "#pts\\.1"
      )))
    ),
    auto_unbox = TRUE, null = "null", digits = NA, pretty = pretty
  ))
}

# The maidr-data of an SVG string, however long.
maidr_data_of <- function(svg) {
  xml2::xml_attr(xml2::read_xml(svg, options = "HUGE"), "maidr-data")
}

test_that("every id, and every reference to one, gets the prefix", {
  json <- fixture_json("#g\\.rect\\.2\\.1 rect")
  out <- maidr:::inline_prefix_svg_ids(fixture_svg(json), prefix)

  expect_true(startsWith(out, "<svg"))
  expect_false(grepl("<?xml", out, fixed = TRUE))
  doc <- xml2::read_xml(out)
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  expect_length(ids, 12L)
  expect_true(all(startsWith(ids, prefix)))

  expect_match(out, 'clip-path="url(#mtest-clip.1)"', fixed = TRUE)
  expect_match(out, 'fill="url(#mtest-pat-0)"', fixed = TRUE)
  expect_match(out, "fill=\"url('#mtest-pat-0')\"", fixed = TRUE)
  expect_match(out, 'mask="url(&quot;#mtest-clip.1&quot;)"', fixed = TRUE)
  expect_match(out, 'fill="url( #mtest-pat-0 )"', fixed = TRUE)
  expect_match(out, 'style="clip-path: url(#mtest-clip.1)"', fixed = TRUE)
  expect_match(out, 'xlink:href="#mtest-gridSVG.pch19"', fixed = TRUE)
  expect_match(out, ' href="#mtest-gridSVG.pch19"', fixed = TRUE)

  got <- jsonlite::parse_json(xml2::xml_attr(doc, "maidr-data"))
  expect_identical(got$id, "mtest-maidr-plot-1-2")
  expect_identical(
    got$subplots[[1]][[1]]$layers[[1]]$selectors, "#mtest-g\\.rect\\.2\\.1 rect"
  )
  expect_identical(got$subplots[[1]][[1]]$selector, "#mtest-pts\\.1")
})

test_that("text, data and references to other documents are left alone", {
  json <- fixture_json("#g\\.rect\\.2\\.1 rect")
  out <- maidr:::inline_prefix_svg_ids(fixture_svg(json), prefix)

  # A title that reads like references to ids the SVG has.
  expect_match(out, '>id="pat-0" url(#pat-0) href="#gridSVG.pch19"<', fixed = TRUE)
  # References to ids the SVG lacks.
  expect_match(out, 'fill="url(#elsewhere)"', fixed = TRUE)
  expect_match(out, '<use href="#elsewhere"/>', fixed = TRUE)

  got <- jsonlite::parse_json(maidr_data_of(out))
  layer <- got$subplots[[1]][[1]]$layers[[1]]
  expect_identical(layer$title, 'say "#g" \\')
  expect_identical(layer$data[[1]]$x, '"selectors":"#g.rect.2.1"')
  expect_identical(layer$data[[2]]$x, "#pts.1")
  expect_identical(layer$data[[3]]$x, "url(#pat-0)")
  # Subplot and layer ids never reach the page.
  expect_identical(got$subplots[[1]][[1]]$id, "maidr-subplot-1-2")
  expect_identical(layer$id, 1L)
})

test_that("the maidr-data changes only by the prefixes inserted into it", {
  for (pretty in c(FALSE, TRUE)) {
    json <- fixture_json(
      list(
        "#g\\.rect\\.2\\.1 rect",
        list(list("#g\\.rect\\.2\\.1\\.1", NULL), "rect[id^=\"g.rect\"]"),
        list(iq = "g#pts\\.1 > use", q2 = list("#pts\\.1\\.1"), empty = "")
      ),
      pretty = pretty
    )
    out <- maidr:::inline_prefix_svg_ids(fixture_svg(json), prefix)
    rewritten <- maidr_data_of(out)

    expect_identical(gsub(prefix, "", rewritten, fixed = TRUE), json)
    selectors <- jsonlite::parse_json(rewritten)$subplots[[1]][[1]]$layers[[1]]$selectors
    expect_identical(selectors[[1]], "#mtest-g\\.rect\\.2\\.1 rect")
    expect_identical(selectors[[2]][[1]][[1]], "#mtest-g\\.rect\\.2\\.1\\.1")
    expect_null(selectors[[2]][[1]][[2]])
    expect_identical(selectors[[2]][[2]], "rect[id^=\"mtest-g.rect\"]")
    expect_identical(selectors[[3]]$iq, "g#mtest-pts\\.1 > use")
    expect_identical(selectors[[3]]$q2[[1]], "#mtest-pts\\.1\\.1")
    expect_identical(selectors[[3]]$empty, "")
  }
})

test_that("empty selectors, and maidr-data without selectors or a figure id, are read", {
  rewrite <- function(json) {
    svg <- fixture_svg(json, '<g id="a"/>')
    maidr_data_of(maidr:::inline_prefix_svg_ids(svg, prefix))
  }
  layer <- function(selectors) {
    sprintf('{"id":"f","subplots":[[{"layers":[{"selectors":%s}]}]]}', selectors)
  }

  for (empty in c("[]", "{}", "null", '""', "[[],[null]]")) {
    expect_identical(rewrite(layer(empty)), sub('"f"', '"mtest-f"', layer(empty)), info = empty)
  }
  expect_identical(rewrite('{"id":"f","subplots":[]}'), '{"id":"mtest-f","subplots":[]}')
  # The figure id is the top-level `id` wherever it stands, and only that.
  expect_identical(
    rewrite('{"subplots":[[{"id":"s","layers":[{"selectors":"#a"}]}]],"id":"f"}'),
    '{"subplots":[[{"id":"s","layers":[{"selectors":"#mtest-a"}]}]],"id":"mtest-f"}'
  )
  expect_identical(
    rewrite('{"subplots":[[{"id":"s","layers":[{"selectors":"#a"}]}]]}'),
    '{"subplots":[[{"id":"s","layers":[{"selectors":"#mtest-a"}]}]]}'
  )
  expect_identical(rewrite('{"id":7,"subplots":[]}'), '{"id":7,"subplots":[]}')
})

test_that("a selector jsonlite escapes is written back the way jsonlite wrote it", {
  json <- fixture_json(c("#g\\.rect\\.2\\.1\trect", "#\u00e9t\u00e9 rect"))
  out <- maidr:::inline_prefix_svg_ids(fixture_svg(json), prefix)
  rewritten <- maidr_data_of(out)

  expect_identical(gsub(prefix, "", rewritten, fixed = TRUE), json)
  expect_identical(
    unlist(jsonlite::parse_json(rewritten)$subplots[[1]][[1]]$layers[[1]]$selectors),
    c("#mtest-g\\.rect\\.2\\.1\trect", "#mtest-\u00e9t\u00e9 rect")
  )
})

test_that("every selector form the package builds is scoped to its chart", {
  forms <- c(
    # ggplot2 bars, histograms and areas; Base R bars, lines and contours
    "#geom_rect\\.rect\\.29\\.1 rect" = "#mtest-geom_rect\\.rect\\.29\\.1 rect",
    # ggplot2 lines and smooths; lattice shapes
    "#GRID\\.polyline\\.141\\.1\\.1" = "#mtest-GRID\\.polyline\\.141\\.1\\.1",
    # Base R assocplot
    "#graphics-plot-1-rect-1\\.1 > rect:nth-of-type(3)" =
      "#mtest-graphics-plot-1-rect-1\\.1 > rect:nth-of-type(3)",
    # Base R stacked bars and pies
    "#a-1\\.1 rect, #a-2\\.1 rect" = "#mtest-a-1\\.1 rect, #mtest-a-2\\.1 rect",
    # lattice; ggplot2 points and heat maps; Base R points
    "g#maidr\\.barchart\\.rect\\.panel\\.1\\.1\\.1 > rect" =
      "g#mtest-maidr\\.barchart\\.rect\\.panel\\.1\\.1\\.1 > rect",
    # box plots, violins, error bars, Base R image()
    "g#b\\.1 > *:nth-child(3n+2)" = "g#mtest-b\\.1 > *:nth-child(3n+2)",
    "g#b\\.1 > rect:nth-child(-n+4)" = "g#mtest-b\\.1 > rect:nth-child(-n+4)",
    "g#b\\.1 > path:nth-child(n+2)" = "g#mtest-b\\.1 > path:nth-child(n+2)",
    "g#b\\.1 > rect:nth-child(12)" = "g#mtest-b\\.1 > rect:nth-child(12)",
    # ggplot2 hexbins
    "polygon#geom_hex\\.polygon\\.943\\.1\\.1" =
      "polygon#mtest-geom_hex\\.polygon\\.943\\.1\\.1",
    # Base R histograms, box plots, violins and dodged bars
    "rect[id^='graphics-plot-1-rect-1\\.1']" = "rect[id^='mtest-graphics-plot-1-rect-1\\.1']",
    "polygon[id^='graphics-plot-1-polygon-1.1']" =
      "polygon[id^='mtest-graphics-plot-1-polygon-1.1']",
    "rect[id^='graphics-plot-1-rect-1.1']:nth-child(-n+5)" =
      "rect[id^='mtest-graphics-plot-1-rect-1.1']:nth-child(-n+5)",
    # ggplot2 contours, Gantt charts and rugs
    "*[id='GRID.segments.870.1.1']" = "*[id='mtest-GRID.segments.870.1.1']",
    # candlesticks
    "#maidr-cs-opens-1 line" = "#mtest-maidr-cs-opens-1 line",
    # lattice ids holding spaces
    "#density\\ rug\\.x\\.1" = "#mtest-density\\ rug\\.x\\.1",
    # the same grammar, written other ways
    "rect[id^=\"a\"]" = "rect[id^=\"mtest-a\"]",
    "rect[ id ^= 'a' ]" = "rect[ id ^= 'mtest-a' ]",
    "*[id=a]" = "*[id=mtest-a]",
    "rect[id|='a']" = "rect[id|='mtest-a']",
    "#a + rect" = "#mtest-a + rect",
    "#a ~ rect" = "#mtest-a ~ rect",
    "#a>rect:first-child" = "#mtest-a>rect:first-child",
    "#a rect[fill]" = "#mtest-a rect[fill]",
    "#\\31 23 rect" = "#mtest-\\31 23 rect",
    # an id the chart lacks, scoped all the same so it cannot reach the page
    "#gone\\.1 rect" = "#mtest-gone\\.1 rect"
  )

  expect_identical(maidr:::prefix_selectors(names(forms), prefix), unname(forms))
  # Not a name above: a name is translated to the native encoding.
  expect_identical(
    maidr:::prefix_selectors("#\u00e9t\u00e9 rect", prefix),
    "#mtest-\u00e9t\u00e9 rect"
  )
  expect_identical(maidr:::prefix_selectors(c("", " "), prefix), c("", " "))
})

test_that("a selector that cannot be scoped to its chart refuses the chart", {
  unscopable <- c(
    # no id: it would match the same shapes in every chart on the page
    "rect", "#a rect, rect", "[id]", "#a,", ",#a", "#a, ",
    # ids matched inside or at the end
    "rect[id*='g']", "rect[id$='1']", "rect[id~='g']",
    # tests of a value the rewrite may change: an href, an ARIA reference,
    # anything holding `#`
    "#a rect[fill='url(#g)']", "#a rect[fill='#fff']", "#a use[href='#s']",
    "#a use[aria-labelledby='t']",
    # forms the package does not build
    ".bar rect", "#a.b rect", "#a:not(.x)", "#a:is(rect)", "#a:has(rect)",
    "#a::before", "svg|rect", "rect[id='a' i]", "#a :nth-child(2 of rect)",
    "#", "#a[", "\\"
  )

  for (selector in unscopable) {
    expect_error(
      maidr:::inline_prefix_svg_ids(fixture_svg(fixture_json(selector)), prefix),
      class = "maidr_inline_unsupported",
      info = selector
    )
  }
})

test_that("a chart that is not one plain maidr SVG is refused", {
  json <- fixture_json("#pts\\.1")
  refused <- list(
    "chart.svg",
    "<svg><g></svg>",
    "<div><img src='x.png'/></div>",
    sub(' maidr-data="[^"]*"', "", fixture_svg(json)),
    fixture_svg("{\"id\": "),
    fixture_svg("[{\"id\": \"f\"}]"),
    fixture_svg(json, paste0("<style>#t\\.1 { fill: red; }</style>", fixture_body)),
    fixture_svg(json, paste0("<script>1</script>", fixture_body)),
    fixture_svg(json, paste0("<foreignObject/>", fixture_body)),
    fixture_svg(json, paste0('<g id="x" xlink:title="url(#x)"/>', fixture_body))
  )

  for (svg in refused) {
    expect_error(
      maidr:::inline_prefix_svg_ids(svg, prefix),
      class = "maidr_inline_unsupported",
      info = svg
    )
  }
})

test_that("the SVG may come as HTML or as lines, and without references", {
  svg <- fixture_svg(fixture_json("#pts\\.1"))
  expected <- maidr:::inline_prefix_svg_ids(svg, prefix)

  expect_identical(maidr:::inline_prefix_svg_ids(htmltools::HTML(svg), prefix), expected)
  expect_identical(
    maidr:::inline_prefix_svg_ids(strsplit(svg, "\n", fixed = TRUE)[[1]], prefix),
    expected
  )

  plain <- fixture_svg(fixture_json("#a rect"), '<g id="a"><rect/></g>')
  expect_match(
    maidr:::inline_prefix_svg_ids(plain, prefix),
    '<g id="mtest-a">',
    fixed = TRUE
  )
})

test_that("maidr-data longer than libxml2's default limit is read", {
  skip_on_cran()
  json <- fixture_json("#pts\\.1")
  long <- sub('"type":"bar"', paste0('"type":"bar","note":"', strrep("x", 1.1e7), '"'), json)
  out <- maidr:::inline_prefix_svg_ids(fixture_svg(long), prefix)

  expect_identical(gsub(prefix, "", maidr_data_of(out), fixed = TRUE), long)
})

test_that("only the prefix shape inline_id_prefix() makes is accepted", {
  svg <- fixture_svg(fixture_json("#pts\\.1"))
  bad_prefixes <- list(
    "maidr-", "axes_1-", "tick-", "m1", "m-1-", "m_1-", "mX-", NA, c("ma-", "mb-")
  )
  for (bad in bad_prefixes) {
    expect_error(
      maidr:::inline_prefix_svg_ids(svg, bad),
      "prefix",
      info = paste(format(bad), collapse = " ")
    )
  }
})

test_that("prefixes are one token of fixed width, unique, and leave the RNG alone", {
  set.seed(1)
  seed <- .Random.seed
  made <- replicate(200, maidr:::inline_id_prefix())

  expect_identical(.Random.seed, seed)
  expect_true(all(grepl("^m[0-9a-z]{20}-$", made)))
  expect_identical(anyDuplicated(made), 0L)
  for (one in made[1:3]) {
    expect_silent(maidr:::check_inline_prefix(one))
  }
})

test_that("the prefix fields keep their width whatever the number", {
  expect_identical(maidr:::base36_fixed(0, 5L), "00000")
  expect_identical(maidr:::base36_fixed(35, 5L), "0000z")
  # A process id that is `tick` in base 36 stays inside the prefix's one token.
  expect_identical(maidr:::base36_fixed(1376804, 5L), "0tick")
  expect_identical(maidr:::base36_fixed(36^5 + 36, 5L), "00010")
  expect_identical(nchar(maidr:::base36_fixed(as.numeric(Sys.time()) * 1000, 9L)), 9L)
})

# ---------------------------------------------------------------------------
# Real charts
# ---------------------------------------------------------------------------

# The SVG a Base R chart drawn by `draw` is exported as.
base_r_svg <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)
  draw()
  suppressWarnings(maidr:::create_maidr_html(NULL, shiny = TRUE))
}

# The strings under every `selectors` or `selector` key of parsed maidr-data.
selector_strings <- function(x) {
  if (!is.list(x)) {
    return(character())
  }
  keys <- if (is.null(names(x))) character(length(x)) else names(x)
  keyed <- keys %in% c("selectors", "selector")
  c(
    unlist(x[keyed], use.names = FALSE),
    unlist(lapply(x[!keyed], selector_strings), use.names = FALSE)
  )
}

# Prefix a real chart's ids and check the result against the original.
expect_chart_scoped <- function(svg) {
  testthat::expect_match(as.character(svg), "maidr-data=", fixed = TRUE)
  chart_prefix <- maidr:::inline_id_prefix()
  out <- maidr:::inline_prefix_svg_ids(svg, chart_prefix)

  # Removing the prefix gives the original back: the original as xml2 writes
  # it, and its maidr-data exactly as the producer wrote it.
  original <- xml2::read_xml(
    paste(as.character(svg), collapse = "\n"),
    options = c("NOBLANKS", "HUGE")
  )
  written <- as.character(original, options = c("format", "no_declaration"))
  testthat::expect_identical(gsub(chart_prefix, "", out, fixed = TRUE), sub("\\s+$", "", written))
  testthat::expect_identical(
    gsub(chart_prefix, "", maidr_data_of(out), fixed = TRUE),
    xml2::xml_attr(original, "maidr-data")
  )
  # Replacing the prefix is the same as prefixing with the other one.
  other <- maidr:::inline_id_prefix()
  testthat::expect_identical(
    gsub(chart_prefix, other, out, fixed = TRUE),
    maidr:::inline_prefix_svg_ids(svg, other)
  )

  doc <- xml2::read_xml(out)
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  testthat::expect_true(all(startsWith(ids, chart_prefix)))

  # Every reference resolves to an id of this chart.
  values <- xml2::xml_text(
    xml2::xml_find_all(doc, "//@*[name() != 'maidr-data' and contains(., 'url(')]")
  )
  urls <- unlist(regmatches(
    values, gregexpr("url\\(\\s*['\"]?\\s*#[^)'\"\\s]+", values, perl = TRUE)
  ))
  hrefs <- xml2::xml_text(xml2::xml_find_all(
    doc, "//@href | //@xlink:href", c(xlink = "http://www.w3.org/1999/xlink")
  ))
  targets <- c(sub(".*#", "", urls), substring(hrefs[startsWith(hrefs, "#")], 2L))
  testthat::expect_true(all(targets %in% ids))

  # Every id a selector names is an id of this chart.
  maidr_data <- jsonlite::parse_json(maidr_data_of(out))
  testthat::expect_true(startsWith(maidr_data$id, chart_prefix))
  selectors <- selector_strings(maidr_data)
  testthat::expect_gt(length(selectors), 0L)
  unescape <- function(x) gsub("\\\\(.)", "\\1", x)
  named <- unescape(unlist(regmatches(
    selectors, gregexpr("(?<=#)(?:[A-Za-z0-9_-]|\\\\.)+", selectors, perl = TRUE)
  )))
  testthat::expect_true(all(named %in% ids))
  exact <- unescape(unlist(regmatches(
    selectors, gregexpr("(?<=\\[id=')[^']*", selectors, perl = TRUE)
  )))
  testthat::expect_true(all(exact %in% ids))
  starts <- unescape(unlist(regmatches(
    selectors, gregexpr("(?<=\\[id\\^=')[^']*", selectors, perl = TRUE)
  )))
  testthat::expect_true(all(vapply(starts, function(s) any(startsWith(ids, s)), logical(1))))
  testthat::expect_true(all(startsWith(c(named, exact, starts), chart_prefix)))

  invisible(out)
}

test_that("ggplot2 charts are scoped and come back unchanged without the prefix", {
  skip_if_no_render()
  bar <- suppressWarnings(maidr:::create_maidr_html(create_test_ggplot_bar(), shiny = TRUE))
  out <- expect_chart_scoped(bar)
  expect_match(out, "clip-path=\"url(#", fixed = TRUE)

  # Points are <use>s of one <symbol>; a rug's selectors are `*[id='..']`.
  points <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::geom_rug()
  out <- expect_chart_scoped(suppressWarnings(maidr:::create_maidr_html(points, shiny = TRUE)))
  expect_match(out, "xlink:href=\"#m", fixed = TRUE)
  expect_match(out, "*[id='m", fixed = TRUE)
})

test_that("two Base R charts that share ids share none once prefixed", {
  first <- base_r_svg(function() barplot(c(A = 3, B = 5, C = 2)))
  second <- base_r_svg(function() barplot(c(W = 4, X = 1, Y = 6, Z = 2)))
  ids_of <- function(svg) {
    xml2::xml_attr(xml2::xml_find_all(xml2::read_xml(svg), "//*[@id]"), "id")
  }
  # The collision the prefix exists for.
  expect_gt(length(intersect(ids_of(first), ids_of(second))), 0L)

  first <- expect_chart_scoped(first)
  second <- expect_chart_scoped(second)
  expect_length(intersect(ids_of(first), ids_of(second)), 0L)

  # A histogram's selectors are `rect[id^='..']`.
  out <- expect_chart_scoped(base_r_svg(function() hist(c(1, 2, 2, 3, 3, 3, 4, 4, 5))))
  expect_match(out, "rect[id^='m", fixed = TRUE)
})

test_that("lattice charts are scoped and come back unchanged without the prefix", {
  skip_if_no_lattice()
  chart <- lattice::barchart(c(Apples = 3, Pears = 5, Plums = 2))
  expect_chart_scoped(suppressWarnings(maidr:::create_maidr_html(chart, shiny = TRUE)))
})
