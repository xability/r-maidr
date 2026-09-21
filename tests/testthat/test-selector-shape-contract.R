# The shape of `selectors` in the payload is a contract with the bundled
# maidr.js, and 4.x reads it differently from 3.x (issue #316).
#
# A plain string is handed to `document.querySelectorAll()` and the matches
# are aligned to the layer's points in document order. An ARRAY means
# something else for the types listed in `SINGLE_SELECTOR_LAYER_TYPES`: one
# selector per data point for `bar` and `hist` (`src/model/bar.ts`), a
# per-series grid for the segmented bars (`src/model/segmented.ts`), and
# nothing at all for `point` and `pie`, whose models read
# `layer.selectors as string`. Every processor built its selectors with
# `list()`, so a single selector serialised as a one-element array, 4.x
# resolved it to one element for seven bars and declined the layer, and
# bar, point, histogram, dodged, stacked and pie charts -- ggplot2 and Base R
# -- announced every value and highlighted nothing. Measured in headless
# Chromium against the bundled 4.9.0 before this contract existed:
#
#   chart                     owned clones after Right Arrow   visible
#   ggplot2 bar / point / hist / dodged / stacked / pie      0        0
#   Base R barplot / hist / plot / pie / dotchart / type h   0        0
#   ggplot2 line / smooth / heat                          31/81/1     1
#
# and, with the JSON rewritten to a string and nothing else changed, every
# row in the first two lines gained a visible clone filled with the
# highlight colour.
#
# These tests read the rendered payload rather than a processor's return
# value, because the processors are allowed to keep returning lists: the
# shape is decided once, at serialisation, against the bundle actually
# shipped. Each string is then resolved against the exported SVG the way a
# browser would, so the test says not only "a string" but "a string that
# finds one mark per point" -- the two conditions the frontend checks before
# it keeps the highlight.

skip_if_no_contract <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

# One simple selector (`tag`, `#id`, `tag#id`, `tag[id^='prefix']`,
# `*[id='x']`) as an XPath node test
css_step_xpath <- function(token) {
  m <- regmatches(token, regexec("^([a-zA-Z*]+)?(.*)$", token))[[1]]
  tag <- if (nzchar(m[2]) && m[2] != "*") m[2] else "*"
  rest <- m[3]
  predicates <- character(0)
  while (nzchar(rest)) {
    if (startsWith(rest, "#")) {
      id <- sub("^#([^[]*).*$", "\\1", rest)
      rest <- sub("^#[^[]*", "", rest)
      predicates <- c(predicates, sprintf("@id='%s'", gsub("\\\\", "", id)))
    } else if (grepl("^\\[id\\^='", rest)) {
      prefix <- sub("^\\[id\\^='([^']*)'\\].*$", "\\1", rest)
      rest <- sub("^\\[id\\^='[^']*'\\]", "", rest)
      predicates <- c(
        predicates, sprintf("starts-with(@id,'%s')", gsub("\\\\", "", prefix))
      )
    } else if (grepl("^\\[id='", rest)) {
      id <- sub("^\\[id='([^']*)'\\].*$", "\\1", rest)
      rest <- sub("^\\[id='[^']*'\\]", "", rest)
      predicates <- c(predicates, sprintf("@id='%s'", gsub("\\\\", "", id)))
    } else {
      stop("unsupported selector token: ", token)
    }
  }
  node <- if (tag == "*") "*" else sprintf("*[local-name()='%s']", tag)
  if (length(predicates)) {
    node <- paste0(node, "[", paste(predicates, collapse = " and "), "]")
  }
  node
}

# Resolve the selector shapes this package emits against an SVG document,
# returning the matched nodes. `selectr` is not a dependency; the grammar
# covered is exactly what the processors write: simple selectors joined by
# descendant (" ") or child (" > ") combinators, several of them joined
# with ", ".
resolve_css <- function(doc, selector) {
  one <- function(part) {
    tokens <- strsplit(trimws(part), "\\s+")[[1]]
    xpath <- ""
    axis <- "//"
    for (token in tokens) {
      if (token == ">") {
        axis <- "/"
        next
      }
      xpath <- paste0(xpath, axis, css_step_xpath(token))
      axis <- "//"
    }
    xml2::xml_find_all(doc, xpath)
  }

  parts <- strsplit(selector, ",\\s*")[[1]]
  do.call(c, lapply(parts, one))
}

payload_and_doc <- function(html) {
  list(schema = schema_from(html), doc = xml2::read_html(html))
}

# Every layer in every cell of a payload
all_layers <- function(schema) {
  out <- list()
  for (row in schema$subplots) {
    for (cell in row) {
      out <- c(out, cell$layers)
    }
  }
  out
}

# One string that resolves to exactly `count` marks
expect_single_selector <- function(layer, doc, count, label) {
  testthat::expect_true(
    is.character(layer$selectors) && length(layer$selectors) == 1L,
    info = paste(label, "selectors must serialise as one string")
  )
  if (!is.character(layer$selectors)) {
    return(invisible(NULL))
  }
  marks <- resolve_css(doc, layer$selectors)
  testthat::expect_equal(
    length(marks), count,
    info = paste(label, "selector must find one mark per point")
  )
}

point_count <- function(layer) {
  length(layer$data)
}

grid_count <- function(layer) {
  sum(vapply(layer$data, length, integer(1)))
}

render_base_r <- function(draw) {
  testthat::skip_if_not_installed("gridGraphics")
  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  draw()
  suppressWarnings(suppressMessages(save_html(file = file)))
  paste(readLines(file, warn = FALSE), collapse = "\n")
}

# ---------------------------------------------------------------------------
# The normaliser on its own
# ---------------------------------------------------------------------------

test_that("join_selector_list collapses a flat list of strings and nothing else", {
  testthat::expect_identical(maidr:::join_selector_list(list("#a rect")), "#a rect")
  testthat::expect_identical(maidr:::join_selector_list("#a rect"), "#a rect")
  testthat::expect_identical(
    maidr:::join_selector_list(list("#a polygon", "#b polygon")),
    "#a polygon, #b polygon"
  )
  testthat::expect_identical(
    maidr:::join_selector_list(c("#a polygon", "#b polygon")),
    "#a polygon, #b polygon"
  )

  # A per-cell grid is a shape the frontend reads as such
  grid <- list(list("#g > rect:nth-child(1)", "#g > rect:nth-child(2)"))
  testthat::expect_identical(maidr:::join_selector_list(grid), grid)

  # A BoxSelector object, and a list with an empty or non-string entry
  box <- list(list(iq = "#a polygon", q2 = "#b polyline"))
  testthat::expect_identical(maidr:::join_selector_list(box), box)
  named <- list(body = "#a rect")
  testthat::expect_identical(maidr:::join_selector_list(named), named)
  mixed <- list("#a rect", 3)
  testthat::expect_identical(maidr:::join_selector_list(mixed), mixed)
  blank <- list("#a rect", "")
  testthat::expect_identical(maidr:::join_selector_list(blank), blank)
  testthat::expect_identical(maidr:::join_selector_list(list()), list())
  testthat::expect_null(maidr:::join_selector_list(NULL))
})

test_that("flatten_single_selectors is keyed on the layer type", {
  payload <- list(subplots = list(list(list(layers = list(
    list(type = "bar", selectors = list("#a rect")),
    list(type = "point", selectors = list("g#p > use")),
    list(type = "pie", selectors = list("#w1 polygon", "#w2 polygon")),
    list(type = "line", selectors = list("#l polyline")),
    list(type = "smooth", selectors = list("#s1 polyline", "#s2 polyline")),
    list(type = "box", selectors = list(list(iq = "#a polygon"))),
    list(type = "heat", selectors = list(list("#g > rect:nth-child(1)"))),
    list(type = "bar")
  )))))
  out <- maidr:::flatten_single_selectors(payload)
  layers <- out$subplots[[1]][[1]]$layers

  testthat::expect_identical(layers[[1]]$selectors, "#a rect")
  testthat::expect_identical(layers[[2]]$selectors, "g#p > use")
  testthat::expect_identical(layers[[3]]$selectors, "#w1 polygon, #w2 polygon")
  # One selector per series stays an array
  testthat::expect_identical(layers[[4]]$selectors, list("#l polyline"))
  testthat::expect_identical(layers[[5]]$selectors, list("#s1 polyline", "#s2 polyline"))
  testthat::expect_identical(layers[[6]]$selectors, list(list(iq = "#a polygon")))
  testthat::expect_identical(layers[[7]]$selectors, list(list("#g > rect:nth-child(1)")))
  testthat::expect_false("selectors" %in% names(layers[[8]]))
})

test_that("the serialised payload carries a string where the type wants one", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  svg <- c(
    '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">',
    "<rect/>",
    "</svg>"
  )
  payload <- list(id = "p", subplots = list(list(list(layers = list(
    list(id = 1, type = "bar", selectors = list("#a rect"), data = list()),
    list(id = 2, type = "line", selectors = list("#l polyline"), data = list())
  )))))
  out <- paste(maidr:::add_maidr_data_to_svg(svg, payload), collapse = "\n")
  raw <- regmatches(out, regexpr('maidr-data="[^"]*"', out))
  json <- gsub("&quot;", '"', sub('"$', "", sub('^maidr-data="', "", raw)), fixed = TRUE)

  testthat::expect_match(json, '"selectors":"#a rect"', fixed = TRUE)
  testthat::expect_match(json, '"selectors":["#l polyline"]', fixed = TRUE)
})

# ---------------------------------------------------------------------------
# ggplot2, through the whole pipeline
# ---------------------------------------------------------------------------

three_bars <- data.frame(x = c("a", "b", "c"), y = c(3, 5, 2))

crossed <- data.frame(
  cat = rep(c("a", "b", "c"), times = 2),
  grp = rep(c("u", "v"), each = 3),
  val = c(10, 20, 30, 55, 65, 75)
)

test_that("a ggplot2 bar layer emits one string that finds every bar", {
  skip_if_no_contract()
  plot <- ggplot2::ggplot(three_bars, ggplot2::aes(x, y)) + ggplot2::geom_col()
  r <- payload_and_doc(rendered(plot))
  layer <- all_layers(r$schema)[[1]]
  testthat::expect_identical(layer$type, "bar")
  expect_single_selector(layer, r$doc, point_count(layer), "bar")
})

test_that("a horizontal ggplot2 bar layer does too", {
  skip_if_no_contract()
  plot <- ggplot2::ggplot(three_bars, ggplot2::aes(y, x)) + ggplot2::geom_col()
  r <- payload_and_doc(rendered(plot))
  layer <- all_layers(r$schema)[[1]]
  testthat::expect_identical(layer$type, "bar")
  expect_single_selector(layer, r$doc, point_count(layer), "horizontal bar")
})

test_that("a ggplot2 point layer emits one string that finds every point", {
  skip_if_no_contract()
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  r <- payload_and_doc(rendered(plot))
  layer <- all_layers(r$schema)[[1]]
  testthat::expect_identical(layer$type, "point")
  expect_single_selector(layer, r$doc, point_count(layer), "point")
})

test_that("a ggplot2 histogram emits one string that finds every bin", {
  skip_if_no_contract()
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg)) + ggplot2::geom_histogram(bins = 8)
  r <- payload_and_doc(rendered(plot))
  layer <- all_layers(r$schema)[[1]]
  testthat::expect_identical(layer$type, "hist")
  expect_single_selector(layer, r$doc, point_count(layer), "hist")
})

test_that("dodged, stacked and normalized ggplot2 bars emit one string for the grid", {
  skip_if_no_contract()
  for (position in c("dodge", "stack", "fill")) {
    plot <- ggplot2::ggplot(crossed, ggplot2::aes(cat, val, fill = grp)) +
      ggplot2::geom_col(position = position)
    r <- payload_and_doc(rendered(plot))
    layer <- all_layers(r$schema)[[1]]
    testthat::expect_true(
      layer$type %in% c("dodged_bar", "stacked_bar", "stacked_normalized_bar"),
      info = position
    )
    expect_single_selector(layer, r$doc, grid_count(layer), position)
  }
})

test_that("a ggplot2 pie emits one string that finds every wedge", {
  skip_if_no_contract()
  plot <- ggplot2::ggplot(three_bars, ggplot2::aes(x = "", y = y, fill = x)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")
  r <- payload_and_doc(rendered(plot))
  layer <- all_layers(r$schema)[[1]]
  testthat::expect_identical(layer$type, "pie")
  expect_single_selector(layer, r$doc, point_count(layer), "pie")
})

test_that("every panel of a faceted bar chart emits its own string", {
  skip_if_no_contract()
  df <- data.frame(
    x = rep(c("a", "b"), 2), y = c(1, 2, 3, 4), f = rep(c("p", "q"), each = 2)
  )
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~f)
  r <- payload_and_doc(rendered(plot))
  layers <- all_layers(r$schema)
  testthat::expect_length(layers, 2)
  selectors <- character(0)
  for (layer in layers) {
    testthat::expect_identical(layer$type, "bar")
    expect_single_selector(layer, r$doc, point_count(layer), "facet panel")
    selectors <- c(selectors, layer$selectors)
  }
  # Two panels, two different rect groups
  testthat::expect_length(unique(selectors), 2)
})

test_that("two bar layers in one panel each address only their own rects", {
  skip_if_no_contract()
  df <- data.frame(x = c("a", "b", "c"), total = c(3, 5, 2), part = c(1, 2, 1))
  plot <- ggplot2::ggplot(df, ggplot2::aes(x)) +
    ggplot2::geom_col(ggplot2::aes(y = total)) +
    ggplot2::geom_col(ggplot2::aes(y = part))
  r <- payload_and_doc(rendered(plot))
  layers <- all_layers(r$schema)
  testthat::expect_length(layers, 2)
  for (layer in layers) {
    testthat::expect_identical(layer$type, "bar")
    expect_single_selector(layer, r$doc, point_count(layer), "overlaid bar")
  }
  testthat::expect_false(identical(layers[[1]]$selectors, layers[[2]]$selectors))
})

test_that("a pie inside a patchwork composition names its wedges", {
  skip_if_no_contract()
  testthat::skip_if_not_installed("patchwork")

  # `coord_polar()` fixes the aspect ratio, and patchwork then places the
  # leaf as a nested gtable named "panel; panel, ..." holding a bare "panel"
  # -- which the panel walk dropped, so the pie had no selectors at all.
  pie <- ggplot2::ggplot(three_bars, ggplot2::aes(x = "", y = y, fill = x)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")
  hist <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg)) + ggplot2::geom_histogram(bins = 8)
  plot <- patchwork::wrap_plots(pie, hist)
  r <- payload_and_doc(rendered(plot))
  layers <- all_layers(r$schema)
  types <- vapply(layers, function(layer) layer$type, "")
  testthat::expect_setequal(types, c("pie", "hist"))
  for (layer in layers) {
    expect_single_selector(layer, r$doc, point_count(layer), paste("patchwork", layer$type))
  }
})

test_that("line and smooth layers keep one selector per series", {
  skip_if_no_contract()
  df <- data.frame(x = rep(1:5, 2), y = c(1:5, 5:1), g = rep(c("u", "v"), each = 5))
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y, colour = g)) + ggplot2::geom_line()
  layer <- all_layers(schema_from(rendered(plot)))[[1]]
  testthat::expect_identical(layer$type, "line")
  testthat::expect_true(is.list(layer$selectors))
  testthat::expect_length(layer$selectors, length(layer$data))
})

# ---------------------------------------------------------------------------
# Base R, through the whole pipeline
# ---------------------------------------------------------------------------

test_that("Base R barplot, hist, plot, pie and dotchart each emit one string", {
  skip_if_no_contract()
  testthat::skip_if_not(maidr:::is_patching_active())

  charts <- list(
    bar = function() barplot(c(a = 3, b = 5, c = 2)),
    horizontal = function() barplot(c(a = 3, b = 5, c = 2), horiz = TRUE),
    hist = function() hist(mtcars$mpg),
    point = function() plot(mtcars$wt, mtcars$mpg),
    pie = function() pie(c(a = 3, b = 5, c = 2)),
    dot = function() dotchart(c(a = 3, b = 5, c = 2)),
    lollipop = function() plot(1:5, c(2, 4, 1, 5, 3), type = "h")
  )
  for (name in names(charts)) {
    r <- payload_and_doc(render_base_r(charts[[name]]))
    layer <- all_layers(r$schema)[[1]]
    testthat::expect_true(
      layer$type %in% c("bar", "hist", "point", "pie", "dot", "lollipop"),
      info = name
    )
    expect_single_selector(layer, r$doc, point_count(layer), paste("Base R", name))
  }
})

test_that("Base R dodged and stacked barplots emit one string for the grid", {
  skip_if_no_contract()
  testthat::skip_if_not(maidr:::is_patching_active())

  counts <- matrix(1:6, 2, dimnames = list(c("u", "v"), c("a", "b", "c")))
  for (beside in c(TRUE, FALSE)) {
    r <- payload_and_doc(render_base_r(function() {
      barplot(counts, beside = beside, legend.text = TRUE)
    }))
    layer <- all_layers(r$schema)[[1]]
    testthat::expect_true(layer$type %in% c("dodged_bar", "stacked_bar"), info = beside)
    expect_single_selector(
      layer, r$doc, grid_count(layer), if (beside) "dodged" else "stacked"
    )
  }
})

test_that("a par(mfrow) layout emits one string per panel", {
  skip_if_no_contract()
  testthat::skip_if_not(maidr:::is_patching_active())

  r <- payload_and_doc(render_base_r(function() {
    par(mfrow = c(1, 2))
    barplot(c(a = 3, b = 5))
    plot(1:5, 5:1)
  }))
  layers <- all_layers(r$schema)
  testthat::expect_length(layers, 2)
  for (layer in layers) {
    expect_single_selector(layer, r$doc, point_count(layer), paste("mfrow", layer$type))
  }
})
