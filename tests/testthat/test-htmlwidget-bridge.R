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
