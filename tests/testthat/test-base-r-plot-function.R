# plot() of a function.
#
# `plot(sin, -pi, pi)` dispatches to `graphics::plot.function()`, which
# draws the function by calling `curve()` from inside graphics, where
# maidr's `curve()` wrapper never sees it. Only the `plot()` call was
# recorded, with the function where `plot.default()` takes its points, and
# read as a scatter of it: `save_html()` stopped with "object of type
# 'builtin' is not subsettable" (or 'closure'), and `plot(sin)`, with no
# range given, was announced as a scatter with no points at all.
#
# These compare what maidr exports for such a call with what R itself
# draws: the points `plot.function()` returns, the strings R draws on the
# page, and the reading the same drawing gets through `curve()`.

skip_slow_file_on_cran()
skip_if_not_installed("svglite")
skip_if_not_installed("xml2")
skip_if_not_installed("jsonlite")

# Every string an SVG document draws, in order.
pf_strings <- function(document) {
  trimws(xml2::xml_text(
    xml2::xml_find_all(document, "//*[local-name()='text']")
  ))
}

# The strings R draws for `call` at maidr's own size, with every function
# maidr wraps bound to its original, so nothing is recorded.
pf_native_strings <- function(call, env = parent.frame()) {
  old <- options(maidr.base_r = FALSE)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".svg")
  on.exit(unlink(file), add = TRUE)

  named <- intersect(maidr:::get_all_function_names(), all.names(call))
  reference <- list2env(
    stats::setNames(lapply(named, maidr:::get_original_function), named),
    parent = env
  )

  svglite::svglite(file, width = 7, height = 5)
  tryCatch(eval(call, reference), finally = grDevices::dev.off())
  pf_strings(xml2::read_xml(file))
}

# The points R's own `plot.function()` draws for these arguments.
pf_native_points <- function(...) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot.function(...)
}

# What `save_html()` exports for `call`: the strings it draws, its schema
# (NULL when it fell back to a picture), and every warning it raised.
pf_exported <- function(call, env = parent.frame()) {
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

  warnings_seen <- character(0)
  withCallingHandlers(
    {
      eval(call, env)
      suppressMessages(save_html(file = file))
    },
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  list(
    strings = pf_strings(xml2::read_html(file)),
    schema = schema_from(html),
    html = html,
    warnings = warnings_seen
  )
}

pf_layer <- function(schema, row = 1, column = 1) {
  schema$subplots[[row]][[column]]$layers[[1]]
}

# A line layer's one series, as numbers.
pf_xy <- function(layer) {
  points <- layer$data[[1]]
  list(
    x = vapply(points, function(p) as.numeric(p$x), numeric(1)),
    y = vapply(points, function(p) as.numeric(p$y), numeric(1))
  )
}

# The function's line, read from the polyline R drew: the points
# `plot.function()` returned and the selector of the polyline it drew.
pf_expect_line <- function(layer, points, group = 1, label = NULL) {
  testthat::expect_identical(layer$type, "line", label = label)
  xy <- pf_xy(layer)
  testthat::expect_equal(xy$x, points$x, label = label)
  testthat::expect_equal(xy$y, points$y, label = label)
  testthat::expect_identical(
    unlist(layer$selectors),
    sprintf("#graphics-plot-%d-lines-1\\.1 polyline", group),
    label = label
  )
}

sq <- function(x) x^2

test_that("plot() of a function exports the line curve() exports for it", {
  plotted <- pf_exported(quote(plot(sin, -pi, pi)))
  curved <- pf_exported(quote(curve(sin, -pi, pi)))

  layer <- pf_layer(plotted$schema)
  pf_expect_line(layer, pf_native_points(sin, -pi, pi))
  testthat::expect_identical(layer$data, pf_layer(curved$schema)$data)
  testthat::expect_identical(layer$selectors, pf_layer(curved$schema)$selectors)
  testthat::expect_true(grepl(
    'id="graphics-plot-1-lines-1.1"', plotted$html,
    fixed = TRUE
  ))

  # Titled as plot.function() titles it, which is not as curve() does.
  testthat::expect_identical(plotted$strings, pf_native_strings(quote(plot(sin, -pi, pi))))
  testthat::expect_identical(c(layer$axes$x$label, layer$axes$y$label), c("x", "sin"))
  testthat::expect_identical(pf_layer(curved$schema)$axes$y$label, "sin(x)")
})

test_that("a builtin, a closure, a named function and a stats function read as R draws them", {
  cases <- list(
    list(call = quote(plot(sin, -pi, pi)), f = sin, from = -pi, to = pi, ylab = "sin"),
    list(
      call = quote(plot(function(x) x^2, -2, 2)), f = function(x) x^2, from = -2, to = 2,
      ylab = "function(x) x^2"
    ),
    list(call = quote(plot(sq, -2, 2)), f = sq, from = -2, to = 2, ylab = "sq"),
    list(call = quote(plot(dnorm, -3, 3)), f = stats::dnorm, from = -3, to = 3, ylab = "dnorm"),
    list(
      call = quote(plot(splinefun(1:5, c(1, 3, 2, 5, 4)), 1, 5)),
      f = stats::splinefun(1:5, c(1, 3, 2, 5, 4)), from = 1, to = 5,
      ylab = "splinefun(1:5, c(1, 3, 2, 5, 4))"
    )
  )

  for (case in cases) {
    label <- deparse1(case$call)
    chart <- pf_exported(case$call)
    native <- pf_native_strings(case$call)
    layer <- pf_layer(chart$schema)

    pf_expect_line(layer, pf_native_points(case$f, case$from, case$to), label = label)
    testthat::expect_identical(chart$strings, native, label = label)
    testthat::expect_identical(layer$axes$x$label, "x", label = label)
    testthat::expect_identical(layer$axes$y$label, case$ylab, label = label)
    testthat::expect_true(case$ylab %in% native, label = label)
  }

  # A function with a plot() method of its own is not plot.function()'s.
  v <- c(3, 1, 2)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_base_r_device(grDevices::dev.cur())
  on.exit(clear_base_r_device(grDevices::dev.cur()), add = TRUE)
  plot(stats::ecdf(v))
  recorded <- maidr:::get_device_calls(grDevices::dev.cur())
  testthat::expect_null(recorded[[1]]$args$.maidr_curve_data)
})

test_that("the range and resolution are plot.function()'s: default, from, to, n, xlim and log", {
  cases <- list(
    list(call = quote(plot(sin)), points = pf_native_points(sin)),
    list(
      call = quote(plot(sin, from = -1, to = 2, n = 11)),
      points = pf_native_points(sin, from = -1, to = 2, n = 11)
    ),
    list(call = quote(plot(sin, xlim = c(0, 2))), points = pf_native_points(sin, xlim = c(0, 2))),
    list(
      call = quote(plot(exp, 1, 100, log = "x")),
      points = pf_native_points(exp, 1, 100, log = "x")
    )
  )

  for (case in cases) {
    label <- deparse1(case$call)
    chart <- pf_exported(case$call)
    pf_expect_line(pf_layer(chart$schema), case$points, label = label)
    testthat::expect_identical(chart$strings, pf_native_strings(case$call), label = label)
  }

  # plot(sin) runs from 0 to 1, as R draws it.
  testthat::expect_equal(range(cases[[1]]$points$x), c(0, 1))
  testthat::expect_length(cases[[2]]$points$x, 11)
})

test_that("type, the axis titles, the main title and xname are taken as R takes them", {
  overplotted <- pf_exported(quote(plot(sin, -pi, pi, type = "o", n = 21)))
  pf_expect_line(pf_layer(overplotted$schema), pf_native_points(sin, -pi, pi, n = 21))

  titled_call <- quote(plot(sin, -pi, pi, ylab = "Y", xlab = "X", main = "M"))
  titled <- pf_exported(titled_call)
  layer <- pf_layer(titled$schema)
  testthat::expect_identical(c(layer$axes$x$label, layer$axes$y$label), c("X", "Y"))
  testthat::expect_identical(layer$title, "M")
  testthat::expect_identical(titled$strings, pf_native_strings(titled_call))

  renamed_call <- quote(plot(cos, 0, pi, xname = "t"))
  renamed <- pf_exported(renamed_call)
  layer <- pf_layer(renamed$schema)
  testthat::expect_identical(c(layer$axes$x$label, layer$axes$y$label), c("t", "cos"))
  testthat::expect_identical(renamed$strings, pf_native_strings(renamed_call))

  # Points are not the polyline the line selector addresses, so the chart
  # is a picture, as curve(type = "p") is.
  pointed <- pf_exported(quote(plot(sin, -pi, pi, type = "p")))
  testthat::expect_null(pointed$schema)
  testthat::expect_true(any(grepl("Rendering as static image", pointed$warnings, fixed = TRUE)))
})

test_that("a function written over several lines is titled with its first, as R draws it", {
  call <- quote(plot(function(x) {
    y <- x^2
    y + 1
  }, -1, 1))
  chart <- pf_exported(call)
  native <- pf_native_strings(call)

  testthat::expect_true("function(x) {" %in% native)
  testthat::expect_identical(chart$strings, native)
  layer <- pf_layer(chart$schema)
  testthat::expect_identical(layer$axes$y$label, "function(x) {")
  pf_expect_line(layer, pf_native_points(function(x) x^2 + 1, -1, 1))
})

test_that("plot(f, add = TRUE) over a chart is shown as its picture, as curve(add = TRUE) is", {
  # The function is drawn over the chart before it, and the chart exported
  # is the first drawing alone: read as a chart, the function would be
  # missing from it.
  added <- pf_exported(quote({
    plot(1:10 / 10)
    plot(sin, add = TRUE)
  }))
  curved <- pf_exported(quote({
    plot(1:10 / 10)
    curve(sin, add = TRUE)
  }))

  for (chart in list(added, curved)) {
    testthat::expect_null(chart$schema)
    testthat::expect_true(fell_back(chart$html))
    testthat::expect_true(any(grepl("Rendering as static image", chart$warnings, fixed = TRUE)))
    testthat::expect_false(any(grepl("Failed to replay", chart$warnings, fixed = TRUE)))
  }
})

test_that("each panel of a par(mfrow) grid reads its own function", {
  call <- quote({
    par(mfrow = c(1, 2))
    plot(sin, -pi, pi)
    plot(function(x) x^3, -1, 1, n = 21)
  })
  chart <- pf_exported(call)

  testthat::expect_length(chart$schema$subplots[[1]], 2)
  left <- pf_layer(chart$schema, 1, 1)
  right <- pf_layer(chart$schema, 1, 2)
  pf_expect_line(left, pf_native_points(sin, -pi, pi), group = 1)
  pf_expect_line(right, pf_native_points(function(x) x^3, -1, 1, n = 21), group = 2)
  testthat::expect_identical(c(left$axes$y$label, right$axes$y$label), c("sin", "function(x) x^3"))
  testthat::expect_identical(chart$strings, pf_native_strings(call))
})

test_that("show(), its Shiny and widget forms and render_maidr() read plot(f) as a line", {
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(device), add = TRUE)
  clear_base_r_device(device)
  on.exit(clear_base_r_device(device), add = TRUE)
  shown <- NULL
  testthat::local_mocked_bindings(
    display_html = function(html_doc) shown <<- as.character(html_doc),
    maidr_internet_available = function() FALSE,
    .package = "maidr"
  )
  unescaped <- function(x) {
    for (pair in list(
      c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"), c("&#39;", "'"), c("&amp;", "&")
    )) {
      x <- gsub(pair[1], pair[2], x, fixed = TRUE)
    }
    x
  }
  entry_points <- list(
    show = function() {
      maidr::show()
      shown
    },
    shiny = function() as.character(maidr::show(shiny = TRUE)),
    widget = function() {
      widget <- maidr::show(as_widget = TRUE, use_cdn = FALSE)
      unescaped(widget$x$iframe_content)
    }
  )
  points <- pf_native_points(sin, -pi, pi)
  for (name in names(entry_points)) {
    plot(sin, -pi, pi)
    html <- entry_points[[name]]()
    layer <- pf_layer(schema_from(html))
    pf_expect_line(layer, points, label = name)
    testthat::expect_identical(layer$axes$y$label, "sin", label = name)
  }

  testthat::skip_if_not_installed("shiny")
  server <- function(input, output, session) {
    output$chart <- render_maidr(plot(sin, -pi, pi))
  }
  shiny::testServer(server, {
    payload <- jsonlite::parse_json(as.character(output$chart))
    layer <- pf_layer(schema_from(unescaped(payload$x$iframe_content)))
    pf_expect_line(layer, points, label = "render_maidr")
    testthat::expect_identical(layer$axes$y$label, "sin")
  })
})

test_that("a knitted chunk shows plot(f) as its chart", {
  testthat::skip_if_not_installed("knitr")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")

  page <- knit_for(c(
    "```{r builtin}",
    "plot(sin, -pi, pi)",
    "```",
    "```{r closure}",
    "plot(function(x) x^2, -1, 1)",
    "```"
  ), dir)

  testthat::expect_identical(chart_summaries(page), c("line:1", "line:1"))
  labels <- vapply(inline_charts(page), function(svg) {
    data <- jsonlite::parse_json(xml2::xml_attr(svg, "data-maidr-knitr"))
    data$subplots[[1]][[1]]$layers[[1]]$axes$y$label
  }, character(1))
  testthat::expect_identical(labels, c("sin", "function(x) x^2"))
})
