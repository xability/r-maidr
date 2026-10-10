# The chart's starting hover mode: `hoverMode` at the top level of the
# schema, set by `hover_mode` and by `options(maidr.hover_mode)`
# (xability/maidr#1382).

hover_schema <- function(markup) {
  schema_from(paste(as.character(markup), collapse = "\n"))
}

# A frame's srcdoc holds the chart's markup escaped once more.
unescape_hover_markup <- function(x) {
  for (pair in list(
    c("&quot;", '"'), c("&lt;", "<"), c("&gt;", ">"), c("&#39;", "'"), c("&amp;", "&")
  )) {
    x <- gsub(pair[1], pair[2], x, fixed = TRUE)
  }
  x
}

saved_schema <- function(plot = NULL, ...) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file, ...)))
  schema_from(paste(readLines(file, warn = FALSE), collapse = "\n"))
}

test_that("a chart carries no hoverMode unless one is asked for", {
  skip_if_no_render()
  withr::local_options(maidr.hover_mode = NULL)

  schema <- saved_schema(create_test_ggplot_bar())
  expect_false(is.null(schema))
  expect_false("hoverMode" %in% names(schema))

  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  schema <- saved_schema()
  expect_false("hoverMode" %in% names(schema))
  clear_base_r_state()
})

test_that("save_html() writes each hover mode at the top of a ggplot2 schema", {
  skip_if_no_render()
  withr::local_options(maidr.hover_mode = NULL)

  for (mode in c("pointermove", "click", "off")) {
    schema <- saved_schema(create_test_ggplot_bar(), hover_mode = mode)
    expect_identical(schema$hoverMode, mode)
    # Beside the id and the subplots, not inside them.
    expect_true(all(c("id", "subplots") %in% names(schema)))
    expect_false(grepl("hoverMode", jsonlite::toJSON(schema$subplots, auto_unbox = TRUE)))
  }
})

test_that("save_html() and show() write each hover mode for a Base R chart", {
  skip_if_no_render()
  withr::local_options(maidr.hover_mode = NULL)

  for (mode in c("pointermove", "click", "off")) {
    barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
    expect_identical(saved_schema(hover_mode = mode)$hoverMode, mode)
    clear_base_r_state()

    barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
    html <- show(shiny = TRUE, hover_mode = mode)
    expect_identical(hover_schema(html)$hoverMode, mode)
    clear_base_r_state()
  }
})

test_that("show() writes it for ggplot2, in a page, a Shiny fragment and a widget", {
  skip_if_no_render()
  withr::local_options(maidr.hover_mode = NULL)
  p <- create_test_ggplot_bar()

  shown <- NULL
  testthat::local_mocked_bindings(
    display_html = function(html_doc) shown <<- html_doc,
    .package = "maidr"
  )
  show(p, hover_mode = "off")
  expect_identical(hover_schema(shown)$hoverMode, "off")

  expect_identical(hover_schema(show(p, shiny = TRUE, hover_mode = "click"))$hoverMode, "click")

  widget <- show(p, as_widget = TRUE, use_cdn = FALSE, hover_mode = "pointermove")
  expect_identical(
    hover_schema(unescape_hover_markup(widget$x$iframe_content))$hoverMode,
    "pointermove"
  )
  widget <- show(p, as_widget = TRUE, use_cdn = FALSE)
  expect_false("hoverMode" %in% names(hover_schema(unescape_hover_markup(widget$x$iframe_content))))
})

test_that("render_maidr() writes it into its widget's chart", {
  testthat::skip_if_not_installed("shiny")
  skip_if_no_render()
  withr::local_options(maidr.hover_mode = NULL)
  maidr:::clear_all_device_storage()
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)
  testthat::local_mocked_bindings(maidr_internet_available = function() FALSE, .package = "maidr")
  mode_of <- function(value) {
    payload <- jsonlite::parse_json(as.character(value))
    hover_schema(unescape_hover_markup(payload$x$iframe_content))$hoverMode
  }
  server <- function(input, output, session) {
    output$gg <- render_maidr(create_test_ggplot_bar(), hover_mode = "click")
    output$base <- render_maidr(barplot(c(a = 1, b = 2)), hover_mode = "off")
    output$plain <- render_maidr(create_test_ggplot_bar())
  }
  shiny::testServer(server, {
    expect_identical(mode_of(output$gg), "click")
    expect_identical(mode_of(output$base), "off")
    expect_null(mode_of(output$plain))
  })
})

test_that("options(maidr.hover_mode) is the default, and an argument wins over it", {
  skip_if_no_render()
  withr::local_options(maidr.hover_mode = "off")
  p <- create_test_ggplot_bar()

  expect_identical(saved_schema(p)$hoverMode, "off")
  expect_identical(saved_schema(p, hover_mode = "click")$hoverMode, "click")

  # The path knitr and the console print methods take, with no argument.
  expect_identical(hover_schema(maidr:::create_maidr_html(p, shiny = TRUE))$hoverMode, "off")

  barplot(c(10, 20, 30))
  expect_identical(saved_schema()$hoverMode, "off")
  clear_base_r_state()
})

test_that("a hover mode that is not one of the three is an error", {
  p <- create_test_ggplot_bar()
  withr::local_options(maidr.hover_mode = NULL)
  message <- 'must be one of "pointermove", "click" or "off", or NULL'

  for (bad in list("hover", "Click", "", NA_character_, c("click", "off"), TRUE, 1)) {
    expect_error(save_html(p, tempfile(fileext = ".html"), hover_mode = bad), message, fixed = TRUE)
    expect_error(show(p, hover_mode = bad), message, fixed = TRUE)
    expect_error(show(p, as_widget = TRUE, hover_mode = bad), message, fixed = TRUE)
    expect_error(render_maidr(p, hover_mode = bad), message, fixed = TRUE)
  }
  expect_error(
    save_html(p, tempfile(fileext = ".html"), hover_mode = "hover"),
    '`hover_mode` must be one of "pointermove", "click" or "off", or NULL, not "hover".',
    fixed = TRUE
  )
})

test_that("an option that is not one of the three is an error naming the option", {
  skip_if_no_render()
  withr::local_options(maidr.hover_mode = "hover")
  expect_error(
    save_html(create_test_ggplot_bar(), tempfile(fileext = ".html")),
    "`options(maidr.hover_mode)` must be one of",
    fixed = TRUE
  )
})

# htmlwidget adapters build the schema in the browser, so the mode is handed
# to the bind hook, which writes it at the top of the schema.

hover_stub_widget <- function(name, x = list()) {
  htmlwidgets::createWidget(name = name, x = x, package = name)
}

test_that("highcharter and echarts4r widgets hand the hover mode to the bind hook", {
  withr::local_options(maidr.hover_mode = NULL)
  for (name in c("highchart", "echarts4r")) {
    w <- maidr_htmlwidget(hover_stub_widget(name), hover_mode = "click")
    hook <- w$jsHooks$render[[1]]
    expect_identical(hook$data$hoverMode, "click")

    w <- maidr_htmlwidget(hover_stub_widget(name))
    expect_null(w$jsHooks$render[[1]]$data$hoverMode)
  }

  js <- maidr:::MAIDR_HTMLWIDGET_BIND_JS
  written_at <- regexpr("maidr.hoverMode = data.hoverMode", js, fixed = TRUE)
  handed_at <- regexpr("setAttribute('maidr-data'", js, fixed = TRUE)
  expect_true(written_at > 0 && written_at < handed_at)
})

test_that("a widget takes the option, a plotly widget neither it nor the argument", {
  withr::local_options(maidr.hover_mode = "off")
  w <- maidr_htmlwidget(hover_stub_widget("echarts4r"))
  expect_identical(w$jsHooks$render[[1]]$data$hoverMode, "off")

  w <- maidr_htmlwidget(hover_stub_widget("plotly"))
  expect_null(w$jsHooks$render[[1]]$data$hoverMode)
  expect_error(
    maidr_htmlwidget(hover_stub_widget("plotly"), hover_mode = "click"),
    "read only for a highcharter or echarts4r widget",
    fixed = TRUE
  )
  expect_error(
    maidr_htmlwidget(hover_stub_widget("highchart"), hover_mode = "none"),
    'must be one of "pointermove", "click" or "off"',
    fixed = TRUE
  )
})
