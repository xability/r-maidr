# Tests for R/htmlwidget_bridge.R
#
# The widgets below are built with htmlwidgets::createWidget() under the names
# plotly, highcharter and echarts4r give theirs, so the class each one carries
# is the real one without those packages having to be installed. Rendering a
# widget does need its package, and those tests skip without it.

stub_widget <- function(name, x = list()) {
  htmlwidgets::createWidget(name = name, x = x, package = name)
}

dependency_names <- function(widget) {
  vapply(widget$dependencies, function(dep) dep$name, character(1))
}

test_that("each supported widget is read by its library's adapter", {
  expect_identical(maidr:::maidr_htmlwidget_adapter(stub_widget("plotly")), "plotly")
  expect_identical(maidr:::maidr_htmlwidget_adapter(stub_widget("highchart")), "highcharts")
  expect_identical(maidr:::maidr_htmlwidget_adapter(stub_widget("echarts4r")), "echarts")
})

test_that("anything else is refused with a message naming what is supported", {
  expect_error(
    maidr_htmlwidget(ggplot2::ggplot()),
    "must be an htmlwidget from plotly, highcharter or echarts4r"
  )
  expect_error(
    maidr_htmlwidget(stub_widget("leaflet")),
    "cannot read a `leaflet` htmlwidget"
  )
})

test_that("use_cdn must be TRUE or FALSE", {
  for (bad in list(NULL, NA, "yes", c(TRUE, FALSE))) {
    expect_error(
      maidr_htmlwidget(stub_widget("plotly"), use_cdn = bad),
      "must be TRUE or FALSE"
    )
  }
})

test_that("a plotly widget gets the core and no adapter", {
  # The core detects a Plotly chart on the page by itself.
  w <- maidr_htmlwidget(stub_widget("plotly"))

  expect_true("maidr" %in% dependency_names(w))
  expect_false(any(startsWith(dependency_names(w), "maidr-plotly")))
})

test_that("a re-rendered plotly chart is offered to the core again", {
  # The core marks a plotly div it has bound and never looks at it again, so
  # a chart Shiny draws afresh into the same div would stay unread.
  w <- maidr_htmlwidget(stub_widget("plotly"))

  hooks <- w$jsHooks$render
  expect_length(hooks, 1)
  expect_identical(hooks[[1]]$data$adapter, "plotly")
  expect_match(
    hooks[[1]]$code,
    "el.removeAttribute('data-maidr-auto')",
    fixed = TRUE
  )
})

test_that("highcharter and echarts4r widgets get their adapter and a bind hook", {
  cases <- list(highchart = "highcharts", echarts4r = "echarts")
  for (name in names(cases)) {
    adapter <- cases[[name]]
    w <- maidr_htmlwidget(stub_widget(name))

    deps <- dependency_names(w)
    expect_true("maidr" %in% deps)
    expect_true(paste0("maidr-", adapter) %in% deps)

    hooks <- w$jsHooks$render
    expect_length(hooks, 1)
    expect_identical(hooks[[1]]$data$adapter, adapter)
    expect_match(hooks[[1]]$code, "maidr:bindchart", fixed = TRUE)
  }
})

test_that("the bind hook hands the payload over and then drops the attribute", {
  # Left on the element, `maidr-data` is found again by the scan maidr.js
  # runs at DOMContentLoaded, which binds the chart twice and skips the
  # automatic detection of any plotly widget on the same page.
  js <- maidr:::MAIDR_HTMLWIDGET_BIND_JS
  set_at <- regexpr("setAttribute('maidr-data'", js, fixed = TRUE)
  dispatched_at <- regexpr("dispatchEvent(", js, fixed = TRUE)
  removed_at <- regexpr("removeAttribute('maidr-data')", js, fixed = TRUE)

  expect_true(all(c(set_at, dispatched_at, removed_at) > 0))
  expect_true(set_at < dispatched_at && dispatched_at < removed_at)
})

test_that("an echarts4r widget is switched to the SVG renderer", {
  w <- maidr_htmlwidget(stub_widget("echarts4r", x = list(renderer = "canvas")))
  expect_identical(w$x$renderer, "svg")

  # Nothing else is touched.
  h <- maidr_htmlwidget(stub_widget("highchart", x = list(renderer = "canvas")))
  expect_identical(h$x$renderer, "canvas")
})

test_that("applying it twice leaves the widget as the first call left it", {
  once <- maidr_htmlwidget(stub_widget("highchart"))
  twice <- maidr_htmlwidget(once)

  expect_identical(twice, once)
})

test_that("the bundled adapters are declared alone, not with the core beside them", {
  for (adapter in c("highcharts", "echarts")) {
    dep <- maidr:::maidr_adapter_dependency(adapter, use_cdn = FALSE)

    expect_identical(dep$name, paste0("maidr-", adapter))
    expect_identical(dep$version, maidr:::MAIDR_VERSION)
    expect_identical(dep$script, paste0(adapter, ".js"))
    expect_false(dep$all_files)
    expect_true(file.exists(
      system.file(dep$src$file, dep$script, package = "maidr")
    ))
  }
})

test_that("the bundled adapters are the UMD builds that define their globals", {
  globals <- c(highcharts = "maidrHighcharts", echarts = "maidrECharts")
  for (adapter in names(globals)) {
    dep <- maidr:::maidr_adapter_dependency(adapter, use_cdn = FALSE)
    path <- system.file(dep$src$file, dep$script, package = "maidr")
    head <- readChar(path, 600L, useBytes = TRUE)

    expect_match(head, paste0("e.", globals[[adapter]], "={}"), fixed = TRUE)
  }
})

test_that("use_cdn = TRUE loads the core and the adapter from the same release", {
  previous <- options(maidr.cdn_version = "4.10.0")
  on.exit(options(previous), add = TRUE)

  w <- maidr_htmlwidget(stub_widget("echarts4r"), use_cdn = TRUE)
  hrefs <- vapply(w$dependencies, function(dep) {
    if (is.null(dep$src$href)) NA_character_ else dep$src$href
  }, character(1))
  names(hrefs) <- dependency_names(w)

  expect_identical(hrefs[["maidr"]], "https://cdn.jsdelivr.net/npm/maidr@4.10.0/dist")
  expect_identical(hrefs[["maidr-echarts"]], hrefs[["maidr"]])
})

test_that("a rendered highcharter widget loads the adapter after Highcharts", {
  skip_if_not_installed("highcharter")

  w <- highcharter::hchart(
    data.frame(day = c("Mon", "Tue"), n = c(20, 14)),
    "column",
    highcharter::hcaes(day, n)
  ) |>
    maidr_htmlwidget()

  deps <- htmltools::resolveDependencies(
    htmltools::renderTags(w)$dependencies
  )
  names <- vapply(deps, function(dep) dep$name, character(1))

  expect_true(all(c("highcharts", "maidr", "maidr-highcharts") %in% names))
  expect_lt(match("highcharts", names), match("maidr-highcharts", names))
})

test_that("real plotly and echarts4r widgets are accepted", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("echarts4r")

  p <- maidr_htmlwidget(plotly::plot_ly(x = c("a", "b"), y = c(1, 2), type = "bar"))
  expect_true("maidr" %in% dependency_names(p))

  e <- data.frame(x = c("a", "b"), y = c(1, 2)) |>
    echarts4r::e_charts(x) |>
    echarts4r::e_bar(y) |>
    maidr_htmlwidget()
  expect_identical(e$x$renderer, "svg")
  expect_true("maidr-echarts" %in% dependency_names(e))
})

# percentile_bands: ECharts' adapter-level `percentileBands` option
# (xability/maidr#1369), which maidr.js reads from 4.15.0.

one_fan <- function(...) {
  list(
    median = "Median",
    bands = data.frame(
      series = c("90% interval", "50% interval"),
      lower = c(0.05, 0.25),
      upper = c(0.95, 0.75)
    ),
    ...
  )
}

with_bands_available <- function(available, code) {
  testthat::local_mocked_bindings(
    echarts_percentile_bands_available = function(use_cdn = FALSE) available,
    .package = "maidr"
  )
  force(code)
}

test_that("a fan is normalised to the shape maidr.js reads", {
  fans <- maidr:::validate_percentile_bands(one_fan(title = "Forecast"))

  expect_length(fans, 1)
  expect_identical(fans[[1]]$median, "Median")
  expect_identical(fans[[1]]$title, "Forecast")
  expect_null(fans[[1]]$name)
  expect_identical(
    fans[[1]]$bands,
    list(
      list(series = "90% interval", lower = 0.05, upper = 0.95),
      list(series = "50% interval", lower = 0.25, upper = 0.75)
    )
  )

  # A list of fans, and bands written as a list of lists, read the same.
  listed <- maidr:::validate_percentile_bands(list(list(
    median = "Median",
    bands = list(
      list(series = "90% interval", lower = 0.05, upper = 0.95),
      list(series = "50% interval", lower = 0.25, upper = 0.75)
    )
  )))
  expect_identical(listed[[1]]$bands, fans[[1]]$bands)
})

test_that("levels must be fractions either side of the median", {
  bad_levels <- list(
    c(5, 95), # percentages
    c(0.5, 0.95), # lower not below the median
    c(0.05, 0.5), # upper not above it
    c(-0.1, 0.9),
    c(0.1, 1.2),
    c(NA, 0.9)
  )
  for (levels in bad_levels) {
    expect_error(
      maidr:::validate_percentile_bands(list(
        median = "Median",
        bands = list(list(series = "b", lower = levels[1], upper = levels[2]))
      )),
      "expected a `lower` from 0 to below 0.5"
    )
  }
  # The edges themselves are allowed.
  expect_silent(maidr:::validate_percentile_bands(list(
    median = "Median",
    bands = list(list(series = "b", lower = 0, upper = 1))
  )))
})

test_that("bands must nest", {
  expect_error(
    maidr:::validate_percentile_bands(list(
      median = "Median",
      bands = data.frame(series = c("a", "b"), lower = c(0.05, 0.1), upper = c(0.8, 0.9))
    )),
    "do not nest"
  )
  expect_error(
    maidr:::validate_percentile_bands(list(
      median = "Median",
      bands = data.frame(series = c("a", "b"), lower = c(0.1, 0.1), upper = c(0.9, 0.8))
    )),
    "do not nest"
  )
})

test_that("a fan without a median, bands or series is refused", {
  expect_error(maidr:::validate_percentile_bands("Median"), "must be a list of fans")
  expect_error(maidr:::validate_percentile_bands(list()), "must be a list of fans")
  expect_error(
    maidr:::validate_percentile_bands(list(median = "", bands = one_fan()$bands)),
    "must name its median series"
  )
  expect_error(
    maidr:::validate_percentile_bands(list(median = "Median", bands = list())),
    "at least one band"
  )
  expect_error(
    maidr:::validate_percentile_bands(list(
      median = "Median",
      bands = list(list(series = NA_character_, lower = 0.1, upper = 0.9))
    )),
    "must name its filled series"
  )
  expect_error(
    maidr:::validate_percentile_bands(list(
      median = "Median",
      bands = data.frame(series = "a", lower = 0.1)
    )),
    "lacks the column"
  )
  expect_error(
    maidr:::validate_percentile_bands(list(median = "Median", band = list())),
    "unknown element"
  )
  expect_error(
    maidr:::validate_percentile_bands(one_fan(title = 3)),
    "`title` that is not a non-empty string"
  )
})

test_that("percentile_bands is refused for a widget other than echarts4r", {
  expect_error(
    maidr_htmlwidget(stub_widget("highchart"), percentile_bands = one_fan()),
    "only for an echarts4r widget"
  )
})

test_that("percentile_bands reaches createMaidrFromEChart as percentileBands", {
  with_bands_available(TRUE, {
    w <- maidr_htmlwidget(stub_widget("echarts4r"), percentile_bands = one_fan())
  })

  hook <- w$jsHooks$render[[1]]
  expect_identical(
    hook$data$options$percentileBands,
    maidr:::validate_percentile_bands(one_fan())
  )
  expect_match(
    hook$code,
    "createMaidrFromEChart(instance, el, data.options || {})",
    fixed = TRUE
  )

  # Serialised as htmlwidgets serialises a hook's data: a list of fans, each
  # band an object, every level a number.
  json <- as.character(htmlwidgets:::toJSON(hook$data))
  expect_match(
    json,
    paste0(
      '"percentileBands":[{"median":"Median","bands":[',
      '{"series":"90% interval","lower":0.05,"upper":0.95},',
      '{"series":"50% interval","lower":0.25,"upper":0.75}]}]'
    ),
    fixed = TRUE
  )
})

test_that("without percentile_bands the hook carries no options", {
  w <- maidr_htmlwidget(stub_widget("echarts4r"))
  expect_null(w$jsHooks$render[[1]]$data$options)
})

test_that("percentile_bands is checked, then ignored with a warning, on an older maidr.js", {
  with_bands_available(FALSE, {
    expect_warning(
      w <- maidr_htmlwidget(stub_widget("echarts4r"), percentile_bands = one_fan()),
      "needs maidr.js 4.15.0 or later"
    )
    expect_null(w$jsHooks$render[[1]]$data$options)

    # Still validated: a mistake is an error whatever the bundle.
    expect_error(
      maidr_htmlwidget(
        stub_widget("echarts4r"),
        percentile_bands = list(median = "Median", bands = list(list(series = "b", lower = 5, upper = 95)))
      ),
      "as fractions"
    )
  })
})

test_that("the option goes through from the maidr.js release that reads it", {
  local_mocked_bindings(maidr_cdn_version = function() "4.14.0", .package = "maidr")
  expect_false(maidr:::echarts_percentile_bands_available(use_cdn = TRUE))

  local_mocked_bindings(maidr_cdn_version = function() "4.15.0", .package = "maidr")
  expect_true(maidr:::echarts_percentile_bands_available(use_cdn = TRUE))

  local_mocked_bindings(maidr_cdn_version = function() "latest", .package = "maidr")
  expect_true(maidr:::echarts_percentile_bands_available(use_cdn = TRUE))

  # The bundled copy decides when the CDN is not used.
  expect_identical(
    maidr:::echarts_percentile_bands_available(use_cdn = FALSE),
    utils::compareVersion(maidr:::MAIDR_VERSION, "4.15.0") >= 0
  )
})

test_that("a real echarts4r fan chart carries its percentile bands", {
  skip_if_not_installed("echarts4r")

  fan <- data.frame(
    week = c("W1", "W2", "W3", "W4"),
    median = c(10, 12, 13, 15),
    lower = c(8, 9, 9, 10),
    width = c(4, 6, 8, 10)
  )
  chart <- fan |>
    echarts4r::e_charts(week) |>
    echarts4r::e_line(median, name = "Median") |>
    echarts4r::e_line(lower, stack = "band", name = "lower") |>
    echarts4r::e_area(width, stack = "band", name = "90% interval")
  bands <- list(
    median = "Median",
    bands = data.frame(series = "90% interval", lower = 0.05, upper = 0.95)
  )

  with_bands_available(TRUE, {
    w <- maidr_htmlwidget(chart, percentile_bands = bands)
  })
  expect_identical(w$x$renderer, "svg")
  expect_identical(
    w$jsHooks$render[[1]]$data$options$percentileBands[[1]]$bands[[1]]$series,
    "90% interval"
  )

  # A series the chart does not have is said in R, not only in the browser.
  with_bands_available(TRUE, {
    expect_warning(
      maidr_htmlwidget(chart, percentile_bands = list(
        median = "median line",
        bands = bands$bands
      )),
      "\"median line\", which the chart has no series of"
    )
  })
})
