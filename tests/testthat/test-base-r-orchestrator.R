# Comprehensive tests for BaseRPlotOrchestrator
# Testing call capture, layer detection, and processing for Base R plots

# ==============================================================================
# Basic Orchestrator Initialization
# ==============================================================================

test_that("BaseRPlotOrchestrator initializes with barplot", {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")
  testthat::expect_true(R6::is.R6(orchestrator))

  clear_base_r_state()
})

test_that("BaseRPlotOrchestrator initializes with hist", {
  hist(mtcars$mpg)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

test_that("BaseRPlotOrchestrator initializes with boxplot", {
  boxplot(mpg ~ cyl, data = mtcars)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

# ==============================================================================
# Layer Detection Tests
# ==============================================================================

test_that("Orchestrator detects layers in barplot", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  testthat::expect_type(layers, "list")
  testthat::expect_gte(length(layers), 1)

  clear_base_r_state()
})

test_that("Orchestrator detects correct layer type for barplot", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  layer1 <- layers[[1]]

  testthat::expect_true("type" %in% names(layer1))
  testthat::expect_equal(layer1$type, "bar")

  clear_base_r_state()
})

test_that("Layer info contains required fields", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  layer1 <- layers[[1]]

  # Check required fields
  testthat::expect_true("index" %in% names(layer1))
  testthat::expect_true("type" %in% names(layer1))
  testthat::expect_true("function_name" %in% names(layer1))
  testthat::expect_true("args" %in% names(layer1))

  clear_base_r_state()
})

test_that("Orchestrator detects histogram layers", {
  hist(mtcars$mpg)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  testthat::expect_gte(length(layers), 1)
  testthat::expect_equal(layers[[1]]$type, "hist")

  clear_base_r_state()
})

test_that("Orchestrator detects boxplot layers", {
  boxplot(mpg ~ cyl, data = mtcars)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  testthat::expect_gte(length(layers), 1)
  testthat::expect_equal(layers[[1]]$type, "box")

  clear_base_r_state()
})

# ==============================================================================
# Layer Processor Creation Tests
# ==============================================================================

test_that("Orchestrator creates layer processors", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()

  testthat::expect_type(processors, "list")
  testthat::expect_gte(length(processors), 1)

  clear_base_r_state()
})

test_that("Layer processor inherits from LayerProcessor", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "LayerProcessor")
  testthat::expect_true(R6::is.R6(processor1))

  clear_base_r_state()
})

test_that("Correct processor created for barplot", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "BaseRBarplotLayerProcessor")

  clear_base_r_state()
})

test_that("Correct processor created for histogram", {
  hist(mtcars$mpg)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "BaseRHistogramLayerProcessor")

  clear_base_r_state()
})

test_that("Correct processor created for boxplot", {
  boxplot(mpg ~ cyl, data = mtcars)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  processors <- orchestrator$get_layer_processors()
  processor1 <- processors[[1]]

  testthat::expect_s3_class(processor1, "BaseRBoxplotLayerProcessor")

  clear_base_r_state()
})

# ==============================================================================
# Layer Processing Tests
# ==============================================================================

test_that("Orchestrator processes layers successfully", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  # Processing happens in initialize, verify it worked
  data <- orchestrator$get_combined_data()

  testthat::expect_type(data, "list")
  testthat::expect_gte(length(data), 1)

  clear_base_r_state()
})

test_that("Combined data is generated", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  data <- orchestrator$get_combined_data()

  testthat::expect_type(data, "list")

  clear_base_r_state()
})

test_that("Orchestrator generates MAIDR data", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  maidr_data <- orchestrator$generate_maidr_data()

  testthat::expect_type(maidr_data, "list")

  clear_base_r_state()
})

# ==============================================================================
# Different Plot Type Tests
# ==============================================================================

test_that("Orchestrator handles dodged barplot", {
  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  barplot(test_matrix, beside = TRUE)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  # Dodged bar may be detected as regular bar or dodged_bar
  testthat::expect_true(layers[[1]]$type %in% c("bar", "dodged_bar"))

  processors <- orchestrator$get_layer_processors()
  # Processor class depends on detection
  testthat::expect_true(inherits(processors[[1]], "LayerProcessor"))

  clear_base_r_state()
})

test_that("Orchestrator handles stacked barplot", {
  test_matrix <- matrix(c(10, 20, 15, 25), nrow = 2)
  barplot(test_matrix, beside = FALSE)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()
  testthat::expect_equal(layers[[1]]$type, "stacked_bar")

  processors <- orchestrator$get_layer_processors()
  testthat::expect_s3_class(processors[[1]], "BaseRStackedBarLayerProcessor")

  clear_base_r_state()
})

# ==============================================================================
# Call Capture Tests
# ==============================================================================

test_that("Orchestrator captures plot calls", {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  plot_calls <- orchestrator$get_plot_calls()

  testthat::expect_type(plot_calls, "list")
  testthat::expect_gte(length(plot_calls), 1)

  clear_base_r_state()
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Orchestrator handles barplot with custom parameters", {
  barplot(c(10, 20, 30),
    names.arg = c("A", "B", "C"),
    col = "blue",
    main = "Test Plot"
  )

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

test_that("Orchestrator handles histogram with breaks", {
  hist(mtcars$mpg, breaks = 10)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

test_that("Orchestrator handles boxplot with notch", {
  boxplot(mpg ~ cyl, data = mtcars, notch = TRUE)

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  testthat::expect_s3_class(orchestrator, "BaseRPlotOrchestrator")

  clear_base_r_state()
})

# ==============================================================================
# Multiple Layer Tests
# ==============================================================================

test_that("Orchestrator handles plots with low-level additions", {
  barplot(c(10, 20, 30))
  # Add low-level call
  abline(h = 15, col = "red")

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  layers <- orchestrator$get_layers()

  # Should detect both high-level (barplot) and potentially low-level (abline)
  testthat::expect_gte(length(layers), 1)

  clear_base_r_state()
})

# ==============================================================================
# Grob Management Tests
# ==============================================================================

test_that("Orchestrator can generate gtable", {
  barplot(c(10, 20, 30))

  device_id <- grDevices::dev.cur()
  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)

  gt <- orchestrator$get_gtable()

  testthat::expect_true(!is.null(gt))

  clear_base_r_state()
})

# ==============================================================================
# Multipanel selectors must follow the SVG's panel numbering (issue #60)
#
# A multipanel replay redraws only the panel-visible groups, so gridSVG
# numbers the panels 1..n in replay order. Processors were resolving their
# grob names against the group's own index instead, so one skipped group --
# a plot drawn before the layout call, or a page that scrolled off -- shifted
# every later panel:
#
#   plot(...); par(mfrow = c(1, 2)); barplot(a); barplot(b)
#
# emitted panel 1 (a's data) pointing at the panel that draws b, and panel 2
# (b's data) with no selectors at all.
# ==============================================================================

render_base_r_html <- function(draw) {
  maidr:::clear_all_device_storage()
  grDevices::pdf(NULL)
  file <- tempfile(fileext = ".html")
  drawn <- FALSE
  on.exit(
    {
      if (!drawn) grDevices::dev.off()
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  draw()
  suppressWarnings(save_html(file = file))
  grDevices::dev.off()
  drawn <- TRUE

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  raw <- regmatches(
    html, gregexpr('maidr-data="([^"]*)"', html, perl = TRUE)
  )[[1]]
  testthat::expect_gt(length(raw), 0)
  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  list(
    data = jsonlite::fromJSON(json, simplifyVector = FALSE),
    doc = xml2::read_html(html)
  )
}

# The element id a maidr selector addresses, unescaped.
first_selector_id <- function(layer) {
  flat <- unlist(layer$selectors, use.names = FALSE)
  flat <- flat[vapply(flat, is.character, logical(1))]
  if (length(flat) == 0) {
    return(NA_character_)
  }
  gsub("\\\\", "", sub("^[a-zA-Z]*#", "", sub(" .*$", "", flat[1])))
}

# Heights of the bar rects a selector resolves to. barplot() draws from a
# zero baseline, so these are proportional to the values the panel plots.
selector_rect_heights <- function(doc, id) {
  node <- xml2::xml_find_first(doc, sprintf("//*[@id='%s']", id))
  if (inherits(node, "xml_missing")) {
    return(numeric(0))
  }
  rects <- xml2::xml_find_all(node, ".//*[local-name()='rect']")
  as.numeric(xml2::xml_attr(rects, "height"))
}

expect_panel_draws <- function(payload, row, col, values) {
  layers <- payload$data$subplots[[row]][[col]]$layers
  testthat::expect_equal(length(layers), 1L)
  layer <- layers[[1]]

  testthat::expect_equal(
    vapply(layer$data, function(pt) as.numeric(pt$y), numeric(1)),
    values
  )

  id <- first_selector_id(layer)
  testthat::expect_false(is.na(id))

  heights <- selector_rect_heights(payload$doc, id)
  testthat::expect_equal(length(heights), length(values))
  testthat::expect_equal(
    heights / max(heights),
    values / max(values),
    tolerance = 0.01
  )
}

test_that("a plot drawn before par(mfrow) does not shift the panel selectors", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  payload <- render_base_r_html(function() {
    plot(1:5, 1:5)
    par(mfrow = c(1, 2))
    barplot(c(10, 20, 30))
    barplot(c(40, 50, 60))
  })

  # The pre-layout plot is not replayed, so the two barplots are SVG panels
  # 1 and 2 even though they are plot groups 2 and 3.
  expect_panel_draws(payload, 1, 1, c(10, 20, 30))
  expect_panel_draws(payload, 1, 2, c(40, 50, 60))

  layers <- payload$data$subplots[[1]][[1]]$layers
  testthat::expect_match(
    first_selector_id(layers[[1]]),
    "^graphics-plot-1-"
  )
})

test_that("panels on an earlier page do not shift the visible selectors", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  # Three plots in a 1x2 grid: the third starts a new page, and only that
  # page is exported, so the visible panel is SVG panel 1 while its plot
  # group is the third.
  payload <- render_base_r_html(function() {
    par(mfrow = c(1, 2))
    barplot(c(1, 2, 3))
    barplot(c(4, 5, 6))
    barplot(c(7, 8, 9))
  })

  expect_panel_draws(payload, 1, 1, c(7, 8, 9))
  testthat::expect_equal(
    length(payload$data$subplots[[1]][[2]]$layers), 0L
  )
})

test_that("an exactly filled panel grid still resolves its selectors", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  payload <- render_base_r_html(function() {
    par(mfrow = c(1, 2))
    barplot(c(10, 20, 30))
    barplot(c(40, 50, 60))
  })

  expect_panel_draws(payload, 1, 1, c(10, 20, 30))
  expect_panel_draws(payload, 1, 2, c(40, 50, 60))
})

# ==============================================================================
# layout() spans must not advertise phantom empty cells (issue #96)
#
# A layout matrix of c(1, 1, 1, 2, 3, 4) over two rows and three columns
# draws panel 1 across the whole top row -- par("fig") is [0, 1, 0.5, 1] and
# nothing is blank. Padding every unclaimed cell turned the two cells the span
# covers into empty subplots, so a four-panel figure advertised six and two
# arrow stops had no data, no title and no selector. A cell is genuinely blank
# only where the layout matrix holds a 0 (or names a panel that was never
# drawn).
# ==============================================================================

# Per-cell layer counts and titles of an emitted grid, as matrices.
panel_layer_counts <- function(payload) {
  subplots <- payload$data$subplots
  matrix(
    unlist(lapply(subplots, function(row) {
      vapply(row, function(cell) length(cell$layers), integer(1))
    })),
    nrow = length(subplots),
    byrow = TRUE
  )
}

panel_titles <- function(payload) {
  subplots <- payload$data$subplots
  matrix(
    unlist(lapply(subplots, function(row) {
      vapply(
        row,
        function(cell) {
          if (length(cell$layers) == 0) "" else cell$layers[[1]]$title
        },
        character(1)
      )
    })),
    nrow = length(subplots),
    byrow = TRUE
  )
}

test_that("panel_slot_positions returns every cell a layout panel spans", {
  row_span <- list(
    type = "layout",
    nrows = 2,
    ncols = 3,
    matrix = matrix(c(1, 1, 1, 2, 3, 4), nrow = 2, ncol = 3, byrow = TRUE)
  )

  # Reading order: top-to-bottom, then left-to-right.
  testthat::expect_equal(
    maidr:::panel_slot_positions(1, row_span),
    list(c(1L, 1L), c(1L, 2L), c(1L, 3L))
  )
  testthat::expect_equal(
    maidr:::panel_slot_positions(3, row_span),
    list(c(2L, 2L))
  )

  # A column span: panel 1 owns both rows of column 1.
  col_span <- list(
    type = "layout",
    nrows = 2,
    ncols = 2,
    matrix = matrix(c(1, 2, 1, 3), nrow = 2, ncol = 2, byrow = TRUE)
  )
  testthat::expect_equal(
    maidr:::panel_slot_positions(1, col_span),
    list(c(1L, 1L), c(2L, 1L))
  )

  # A panel number absent from the matrix owns no cell.
  testthat::expect_equal(maidr:::panel_slot_positions(9, row_span), list())

  # mfrow/mfcol grids cannot span: always exactly one cell.
  testthat::expect_equal(
    maidr:::panel_slot_positions(4, list(type = "mfrow", nrows = 2, ncols = 3)),
    list(c(2L, 1L))
  )
  testthat::expect_equal(
    maidr:::panel_slot_positions(4, list(type = "mfcol", nrows = 2, ncols = 3)),
    list(c(2L, 2L))
  )
})

test_that("a spanned layout() panel fills every cell of its span", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  payload <- render_base_r_html(function() {
    layout(matrix(c(1, 1, 1, 2, 3, 4), nrow = 2, ncol = 3, byrow = TRUE))
    plot(1:10, main = "A")
    plot(11:20, main = "B")
    plot(21:30, main = "C")
    plot(31:40, main = "D")
  })

  # The whole top row is panel A; no cell is left blank.
  testthat::expect_equal(
    panel_layer_counts(payload),
    matrix(1L, nrow = 2, ncol = 3)
  )
  testthat::expect_equal(
    panel_titles(payload),
    matrix(c("A", "A", "A", "B", "C", "D"), nrow = 2, byrow = TRUE)
  )

  # The span is one drawn panel repeated, not three panels: the cells carry
  # the same layer, selector included, so navigating across the span keeps
  # announcing and highlighting A.
  top <- lapply(payload$data$subplots[[1]], function(cell) cell$layers[[1]])
  testthat::expect_identical(top[[2]], top[[1]])
  testthat::expect_identical(top[[3]], top[[1]])
  testthat::expect_gt(length(unlist(top[[1]]$selectors)), 0)
})

test_that("a 0 in the layout() matrix still emits one empty cell", {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")

  # R itself leaves the bottom-left quadrant blank here, so that cell is the
  # one place an empty subplot is honest.
  payload <- render_base_r_html(function() {
    layout(matrix(c(1, 2, 0, 3), nrow = 2, ncol = 2, byrow = TRUE))
    plot(1:10, main = "A")
    plot(11:20, main = "B")
    plot(21:30, main = "C")
  })

  testthat::expect_equal(
    panel_layer_counts(payload),
    matrix(c(1L, 1L, 0L, 1L), nrow = 2, byrow = TRUE)
  )
  testthat::expect_equal(
    panel_titles(payload),
    matrix(c("A", "B", "", "C"), nrow = 2, byrow = TRUE)
  )
})
