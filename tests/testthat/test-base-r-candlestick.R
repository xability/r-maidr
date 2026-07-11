# Tests for BaseRCandlestickLayerProcessor (quantmod-driven chartSeries)
# Covers initialization, adapter detection, factory registration, OHLC
# data extraction (Bull / Bear / Neutral), trend & volatility, volume
# embedding, addVo() multi-layer emission, axis labels, and graceful
# fallback when quantmod / xts is unavailable.

# ==============================================================================
# Helpers (local — quantmod, xts and zoo are Suggests)
# ==============================================================================

skip_if_no_quantmod <- function() {
  testthat::skip_if_not_installed("quantmod")
  testthat::skip_if_not_installed("xts")
  testthat::skip_if_not_installed("zoo")
}

create_test_ohlc_xts <- function(with_volume = TRUE) {
  skip_if_no_quantmod()
  dates <- as.Date(c(
    "2023-01-02", "2023-01-03", "2023-01-04", "2023-01-05"
  ))
  # Row 1: Bull (close > open), Row 2: Bear (close < open),
  # Row 3: Bull, Row 4: Neutral (close == open)
  m <- cbind(
    Open  = c(100, 105, 110, 108),
    High  = c(115, 108, 112, 110),
    Low   = c( 95, 102, 105, 100),
    Close = c(110, 103, 111, 108)
  )
  if (with_volume) {
    m <- cbind(m, Volume = c(1000, 1500, 1200, 800))
  }
  # quantmod's has.OHLC checks for column names like *.Open / *.Close;
  # using a series stub gives them a recognizable prefix.
  colnames(m) <- paste0("TST.", colnames(m))
  xts::xts(m, order.by = dates)
}

create_test_layer_info <- function(with_volume = TRUE,
                                   ta = NULL,
                                   name = NULL,
                                   main = NULL) {
  x <- create_test_ohlc_xts(with_volume = with_volume)
  args <- list(x = x, type = "candlesticks")
  if (!is.null(ta)) args$TA <- ta
  if (!is.null(name)) args$name <- name
  if (!is.null(main)) args$main <- main
  list(
    index = 1L,
    type = "candlestick",
    function_name = "chartSeries",
    args = args,
    plot_call = list(function_name = "chartSeries", args = args)
  )
}

# ==============================================================================
# Tier 1: Initialization
# ==============================================================================

test_that("BaseRCandlestickLayerProcessor initializes correctly", {
  layer_info <- list(index = 1L)
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "BaseRCandlestickLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1L)
})

# ==============================================================================
# Tier 2: Adapter detection & Factory wiring
# ==============================================================================

test_that("adapter detects chartSeries(type='candlesticks') as 'candlestick'", {
  adapter <- maidr:::BaseRAdapter$new()
  plot_call <- list(
    function_name = "chartSeries",
    args = list(x = NULL, type = "candlesticks")
  )
  testthat::expect_equal(adapter$detect_layer_type(plot_call), "candlestick")
})

test_that("adapter does NOT detect chartSeries(type='bars') as candlestick", {
  adapter <- maidr:::BaseRAdapter$new()
  plot_call <- list(
    function_name = "chartSeries",
    args = list(x = NULL, type = "bars")
  )
  testthat::expect_equal(adapter$detect_layer_type(plot_call), "unknown")
})

test_that("adapter handles chartSeries with no type argument", {
  adapter <- maidr:::BaseRAdapter$new()
  plot_call <- list(
    function_name = "chartSeries",
    args = list(x = NULL)
  )
  testthat::expect_equal(adapter$detect_layer_type(plot_call), "unknown")
})

test_that("chartSeries is registered as a HIGH function", {
  testthat::expect_true("chartSeries" %in% maidr:::get_functions_by_class("HIGH"))
  testthat::expect_equal(maidr:::classify_function("chartSeries"), "HIGH")
})

test_that("factory creates a BaseRCandlestickLayerProcessor for 'candlestick'", {
  factory <- maidr:::BaseRProcessorFactory$new()
  layer_info <- list(index = 1L)
  processor <- factory$create_processor("candlestick", layer_info)
  testthat::expect_s3_class(processor, "BaseRCandlestickLayerProcessor")
})

test_that("factory advertises 'candlestick' in supported types", {
  factory <- maidr:::BaseRProcessorFactory$new()
  testthat::expect_true("candlestick" %in% factory$get_supported_types())
})

# ==============================================================================
# Tier 3: extract_data — trend, volatility, volume
# ==============================================================================

test_that("extract_data returns one point per OHLC row with required fields", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info()
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)

  data <- processor$extract_data(layer_info)
  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 4L)

  point1 <- data[[1L]]
  testthat::expect_named(
    point1[c("value", "open", "high", "low", "close", "trend", "volatility")],
    c("value", "open", "high", "low", "close", "trend", "volatility")
  )
  testthat::expect_equal(point1$open, 100)
  testthat::expect_equal(point1$high, 115)
  testthat::expect_equal(point1$low, 95)
  testthat::expect_equal(point1$close, 110)
})

test_that("extract_data computes trend correctly (Bull / Bear / Neutral)", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info()
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(data[[1L]]$trend, "Bull")    # 110 > 100
  testthat::expect_equal(data[[2L]]$trend, "Bear")    # 103 < 105
  testthat::expect_equal(data[[3L]]$trend, "Bull")    # 111 > 110
  testthat::expect_equal(data[[4L]]$trend, "Neutral") # 108 == 108
})

test_that("extract_data computes volatility = high - low", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info()
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(data[[1L]]$volatility, 20) # 115 - 95
  testthat::expect_equal(data[[2L]]$volatility, 6)  # 108 - 102
})

test_that("extract_data emits ISO date strings for the value field", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info()
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(data[[1L]]$value, "2023-01-02")
  testthat::expect_equal(data[[4L]]$value, "2023-01-05")
})

test_that("extract_data embeds volume when xts has a Volume column", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info(with_volume = TRUE)
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_equal(data[[1L]]$volume, 1000)
  testthat::expect_equal(data[[2L]]$volume, 1500)
  testthat::expect_equal(data[[4L]]$volume, 800)
})

test_that("extract_data omits volume when xts has no Volume column", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info(with_volume = FALSE)
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  data <- processor$extract_data(layer_info)

  testthat::expect_false("volume" %in% names(data[[1L]]))
})

test_that("extract_data returns empty list with NULL layer_info", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  testthat::expect_equal(processor$extract_data(NULL), list())
})

test_that("extract_data warns and returns empty list for non-OHLC input", {
  skip_if_no_quantmod()
  layer_info <- list(
    index = 1L,
    plot_call = list(
      function_name = "chartSeries",
      args = list(x = xts::xts(1:5, order.by = as.Date("2023-01-01") + 0:4))
    )
  )
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  testthat::expect_warning(
    result <- processor$extract_data(layer_info),
    "OHLC"
  )
  testthat::expect_equal(result, list())
})

# ==============================================================================
# Tier 4: addVo() detection & multi-layer emission
# ==============================================================================

test_that("has_add_vo returns TRUE for TA='addVo()'", {
  layer_info <- list(plot_call = list(args = list(TA = "addVo()")))
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  testthat::expect_true(processor$has_add_vo(layer_info))
})

test_that("has_add_vo returns FALSE for TA=NULL", {
  layer_info <- list(plot_call = list(args = list(TA = NULL)))
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  testthat::expect_false(processor$has_add_vo(layer_info))
})

test_that("has_add_vo returns FALSE for TA='addSMA()'", {
  layer_info <- list(plot_call = list(args = list(TA = "addSMA()")))
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  testthat::expect_false(processor$has_add_vo(layer_info))
})

test_that("process() returns single layer when no addVo", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info()
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  result <- processor$process(NULL, NULL, NULL, gt = NULL, layer_info = layer_info)

  testthat::expect_false(isTRUE(result$multi_layer))
  testthat::expect_equal(result$type, "candlestick")
  testthat::expect_equal(length(result$data), 4L)
})

test_that("process() returns multi_layer = TRUE when TA='addVo()'", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info(ta = "addVo()")
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  result <- processor$process(NULL, NULL, NULL, gt = NULL, layer_info = layer_info)

  testthat::expect_true(isTRUE(result$multi_layer))
  testthat::expect_equal(length(result$layers), 2L)
  testthat::expect_equal(result$layers[[1L]]$type, "candlestick")
  testthat::expect_equal(result$layers[[2L]]$type, "bar")
})

test_that("addVo volume layer carries per-row volume values", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info(ta = "addVo()")
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  result <- processor$process(NULL, NULL, NULL, gt = NULL, layer_info = layer_info)
  vol_layer <- result$layers[[2L]]

  testthat::expect_equal(length(vol_layer$data), 4L)
  testthat::expect_equal(vol_layer$data[[1L]]$y, 1000)
  testthat::expect_equal(vol_layer$data[[2L]]$y, 1500)
  testthat::expect_equal(vol_layer$data[[1L]]$x, "2023-01-02")
  testthat::expect_equal(vol_layer$axes$x$label, "Date")
  testthat::expect_equal(vol_layer$axes$y$label, "Volume")
})

# ==============================================================================
# Tier 5: Axis labels & title extraction
# ==============================================================================

test_that("extract_axis_titles defaults to Date / Price", {
  layer_info <- list(plot_call = list(args = list()))
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  axes <- processor$extract_axis_titles(layer_info)
  testthat::expect_equal(axes$x$label, "Date")
  testthat::expect_equal(axes$y$label, "Price")
})

test_that("extract_axis_titles honors user-supplied xlab/ylab", {
  layer_info <- list(plot_call = list(args = list(xlab = "Time", ylab = "USD")))
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  axes <- processor$extract_axis_titles(layer_info)
  testthat::expect_equal(axes$x$label, "Time")
  testthat::expect_equal(axes$y$label, "USD")
})

test_that("extract_main_title prefers `name` over `main`", {
  layer_info <- list(plot_call = list(args = list(name = "Apple", main = "Stock")))
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  testthat::expect_equal(processor$extract_main_title(layer_info), "Apple")
})

test_that("extract_main_title falls back to `main` when `name` is missing", {
  layer_info <- list(plot_call = list(args = list(main = "Stock Chart")))
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  testthat::expect_equal(processor$extract_main_title(layer_info), "Stock Chart")
})

test_that("extract_main_title falls back to xts column-name stub", {
  skip_if_no_quantmod()
  layer_info <- create_test_layer_info()
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(layer_info)
  testthat::expect_equal(processor$extract_main_title(layer_info), "TST")
})

test_that("extract_main_title returns empty string with NULL layer_info", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  testthat::expect_equal(processor$extract_main_title(NULL), "")
})

# ==============================================================================
# Tier 6: Per-item selector generation
#
# generate_selectors() and generate_volume_selectors() must emit one selector
# entry per data point so the JS frontend can highlight a single candle / bar
# on arrow-key navigation. We stub the grob tree with plain nested lists that
# the processor's collect_grob_names() / find_grob_by_name() / coord helpers
# can traverse via the `$grobs` branch.
# ==============================================================================

make_stub_grob <- function(name, n = 0L, x = NULL) {
  list(
    name = name,
    x = if (!is.null(x)) x else if (n > 0L) seq_len(n) else NULL
  )
}

make_stub_gt <- function(plot_index = 1L, n_candles = 4L, n_wicks = 4L,
                        vol_plot_index = NULL, n_vols = 4L) {
  rect_grob <- make_stub_grob(
    sprintf("graphics-plot-%d-rect-2", plot_index),
    n = n_candles
  )
  seg1 <- make_stub_grob(
    sprintf("graphics-plot-%d-segments-1", plot_index),
    n = n_wicks
  )
  seg2 <- make_stub_grob(
    sprintf("graphics-plot-%d-segments-2", plot_index),
    n = n_wicks
  )
  grobs <- list(rect_grob, seg1, seg2)
  if (!is.null(vol_plot_index)) {
    vol_rect <- make_stub_grob(
      sprintf("graphics-plot-%d-rect-1", vol_plot_index),
      n = n_vols
    )
    grobs <- c(grobs, list(vol_rect))
  }
  list(grobs = grobs)
}

test_that("generate_selectors emits a single CandlestickSelector with per-candle arrays", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  gt <- make_stub_gt(plot_index = 1L, n_candles = 4L, n_wicks = 4L)
  fake_data <- list(list(), list(), list(), list())
  selectors <- processor$generate_selectors(
    layer_info = list(index = 1L),
    gt = gt,
    extracted_data = fake_data
  )
  # Must be ONE CandlestickSelector object (named list), NOT an array of dicts.
  # The JS frontend (src/model/candlestick.ts::mapToSvgElements) expects this
  # shape; an array of objects triggers `querySelectorAll('[object Object]')`.
  testthat::expect_type(selectors, "list")
  testthat::expect_true(!is.null(names(selectors)))
  testthat::expect_true("body" %in% names(selectors))
  # Two segments groups in the stub → wickHigh + wickLow keys present.
  testthat::expect_true("wickHigh" %in% names(selectors))
  testthat::expect_true("wickLow" %in% names(selectors))
  # `wick` (the fallback key) should NOT be present when both wickHigh/Low are.
  testthat::expect_false("wick" %in% names(selectors))

  # body is a character vector of length N (one per-candle selector).
  testthat::expect_type(selectors$body, "character")
  testthat::expect_equal(length(selectors$body), 4L)
  for (i in seq_along(selectors$body)) {
    testthat::expect_match(
      selectors$body[[i]],
      sprintf("graphics-plot-1-rect-2\\\\.1\\\\.%d$", i)
    )
  }
  # wickHigh / wickLow are length-N character vectors targeting the two
  # distinct segments groups. quantmod chartSeries (chartSeries.chob.R
  # L169-173) calls segments() for LOWER wick FIRST, then UPPER wick:
  #   seg_ids[[1L]] = "...-segments-1" = LOWER wick (→ wickLow)
  #   seg_ids[[2L]] = "...-segments-2" = UPPER wick (→ wickHigh)
  testthat::expect_type(selectors$wickHigh, "character")
  testthat::expect_equal(length(selectors$wickHigh), 4L)
  testthat::expect_type(selectors$wickLow, "character")
  testthat::expect_equal(length(selectors$wickLow), 4L)
  for (i in seq_len(4L)) {
    testthat::expect_match(
      selectors$wickLow[[i]],
      sprintf("graphics-plot-1-segments-1\\\\.1\\\\.%d$", i)
    )
    testthat::expect_match(
      selectors$wickHigh[[i]],
      sprintf("graphics-plot-1-segments-2\\\\.1\\\\.%d$", i)
    )
  }
})

test_that("generate_selectors emits `wick` (fallback) when only one segments group present", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  # Stub with only one segments group
  rect_grob <- list(
    name = "graphics-plot-1-rect-2",
    x = seq_len(4L)
  )
  seg1 <- list(
    name = "graphics-plot-1-segments-1",
    x = seq_len(4L)
  )
  gt <- list(grobs = list(rect_grob, seg1))
  fake_data <- list(list(), list(), list(), list())
  selectors <- processor$generate_selectors(
    layer_info = list(index = 1L),
    gt = gt,
    extracted_data = fake_data
  )
  testthat::expect_true("body" %in% names(selectors))
  testthat::expect_true("wick" %in% names(selectors))
  testthat::expect_false("wickHigh" %in% names(selectors))
  testthat::expect_false("wickLow" %in% names(selectors))
  testthat::expect_type(selectors$wick, "character")
  testthat::expect_equal(length(selectors$wick), 4L)
  for (i in seq_len(4L)) {
    testthat::expect_match(
      selectors$wick[[i]],
      sprintf("graphics-plot-1-segments-1\\\\.1\\\\.%d$", i)
    )
  }
})

test_that("generate_selectors returned object is NOT an array of dicts (frontend contract)", {
  # Defensive regression test for the `[object Object]` SyntaxError.
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  gt <- make_stub_gt(plot_index = 1L, n_candles = 3L, n_wicks = 3L)
  selectors <- processor$generate_selectors(
    layer_info = list(index = 1L),
    gt = gt,
    extracted_data = list(list(), list(), list())
  )
  # The list must be NAMED at the top level; the values must be character
  # vectors (or absent), never further nested lists/dicts.
  testthat::expect_true(!is.null(names(selectors)))
  for (key in names(selectors)) {
    testthat::expect_type(selectors[[key]], "character")
  }
})

test_that("generate_selectors returns empty list when gt is NULL", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  res <- processor$generate_selectors(
    layer_info = list(index = 1L),
    gt = NULL,
    extracted_data = list(list(), list())
  )
  testthat::expect_equal(res, list())
})

test_that("generate_selectors returns empty list when extracted_data is empty", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  gt <- make_stub_gt(plot_index = 1L, n_candles = 4L, n_wicks = 4L)
  res <- processor$generate_selectors(
    layer_info = list(index = 1L),
    gt = gt,
    extracted_data = list()
  )
  testthat::expect_equal(res, list())
})

test_that("generate_volume_selectors returns one selector per bar", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  gt <- make_stub_gt(
    plot_index = 1L, n_candles = 4L, n_wicks = 4L,
    vol_plot_index = 2L, n_vols = 4L
  )
  sels <- processor$generate_volume_selectors(
    layer_info = list(index = 1L), gt = gt, n_bars = 4L
  )
  testthat::expect_equal(length(sels), 4L)
  for (i in seq_along(sels)) {
    testthat::expect_match(
      sels[[i]],
      sprintf("graphics-plot-2-rect-1\\\\.1\\\\.%d$", i)
    )
  }
})

test_that("generate_volume_selectors returns empty when only one plot panel", {
  processor <- maidr:::BaseRCandlestickLayerProcessor$new(list(index = 1L))
  gt <- make_stub_gt(plot_index = 1L, n_candles = 4L, n_wicks = 4L)
  sels <- processor$generate_volume_selectors(
    layer_info = list(index = 1L), gt = gt, n_bars = 4L
  )
  testthat::expect_equal(sels, list())
})
