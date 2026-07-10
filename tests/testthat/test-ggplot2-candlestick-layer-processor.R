# Tests for Ggplot2CandlestickProcessor
# Covers initialization, layer-type detection, factory registration,
# OHLC data extraction (Bull / Bear / Neutral), trend & volatility,
# selector generation, axis labels, and end-to-end orchestration.

# ==============================================================================
# Helpers (local — not added to global helper.R because tidyquant is Suggests)
# ==============================================================================

create_test_candlestick_df <- function() {
  data.frame(
    date  = as.Date(c("2023-01-02", "2023-01-03", "2023-01-04", "2023-01-05")),
    open  = c(100, 105, 110, 108),
    high  = c(115, 108, 112, 110),
    low   = c( 95, 102, 105, 100),
    # Bull (close>open), Bear (close<open), Bull, Neutral (close==open)
    close = c(110, 103, 111, 108),
    volume = c(1000, 1500, 1200, 800)
  )
}

create_test_ggplot_candlestick <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  df <- create_test_candlestick_df()
  ggplot2::ggplot(
    df,
    ggplot2::aes(
      x = date, open = open, high = high, low = low, close = close
    )
  ) +
    tidyquant::geom_candlestick() +
    ggplot2::labs(title = "Test Candlestick", x = "Date", y = "Price")
}

# Locate the GeomRectCS (body) layer index in a candlestick plot. tidyquant
# usually adds the wick layer first and the body layer second, but tests
# should not rely on a fixed index.
candlestick_body_index <- function(plot) {
  for (i in seq_along(plot$layers)) {
    if (inherits(plot$layers[[i]]$geom, "GeomRectCS")) return(i)
  }
  NA_integer_
}

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2CandlestickProcessor initializes correctly", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2CandlestickProcessor")
  testthat::expect_equal(processor$get_layer_index(), 2)
})

# ==============================================================================
# Tier 2: Adapter detection & Factory wiring
# ==============================================================================

test_that("adapter detects GeomRectCS as 'candlestick'", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  adapter <- maidr:::Ggplot2Adapter$new()
  body_idx <- candlestick_body_index(p)
  testthat::expect_false(is.na(body_idx))

  layer_type <- adapter$detect_layer_type(p$layers[[body_idx]], p)
  testthat::expect_equal(layer_type, "candlestick")
})

test_that("adapter detects GeomLinerangeBC as 'skip'", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  adapter <- maidr:::Ggplot2Adapter$new()

  wick_idx <- which(vapply(p$layers, function(l) {
    inherits(l$geom, "GeomLinerangeBC")
  }, logical(1)))
  testthat::expect_true(length(wick_idx) >= 1)

  layer_type <- adapter$detect_layer_type(p$layers[[wick_idx[1]]], p)
  testthat::expect_equal(layer_type, "skip")
})

test_that("factory creates Ggplot2CandlestickProcessor for 'candlestick'", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  layer_info <- list(index = 1)
  processor <- factory$create_processor("candlestick", layer_info)

  testthat::expect_true(
    inherits(processor, "Ggplot2CandlestickProcessor")
  )
})

test_that("factory advertises 'candlestick' as a supported type", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  testthat::expect_true("candlestick" %in% factory$get_supported_types())
})

# ==============================================================================
# Tier 3: Data Extraction
# ==============================================================================

test_that("extract_data returns one CandlestickPoint per input row", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), nrow(create_test_candlestick_df()))

  required_fields <- c(
    "value", "open", "high", "low", "close", "trend", "volatility"
  )
  for (pt in data) {
    for (f in required_fields) {
      testthat::expect_true(f %in% names(pt))
    }
  }
})

test_that("extract_data preserves OHLC values from original data", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  df <- create_test_candlestick_df()
  p <- create_test_ggplot_candlestick()
  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  data <- processor$extract_data(p)

  for (i in seq_along(data)) {
    testthat::expect_equal(data[[i]]$open,  df$open[i])
    testthat::expect_equal(data[[i]]$high,  df$high[i])
    testthat::expect_equal(data[[i]]$low,   df$low[i])
    testthat::expect_equal(data[[i]]$close, df$close[i])
  }
})

test_that("extract_data formats Date x-values as character", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  df <- create_test_candlestick_df()
  p <- create_test_ggplot_candlestick()
  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  data <- processor$extract_data(p)

  for (i in seq_along(data)) {
    testthat::expect_type(data[[i]]$value, "character")
    testthat::expect_equal(data[[i]]$value, format(df$date[i]))
  }
})

test_that("extract_data computes trend correctly (Bull / Bear / Neutral)", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # df designed for: Bull, Bear, Bull, Neutral
  expected_trend <- c("Bull", "Bear", "Bull", "Neutral")
  actual_trend <- vapply(data, function(pt) pt$trend, character(1))
  testthat::expect_equal(actual_trend, expected_trend)
})

test_that("extract_data computes volatility = round(high - low, 2)", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  df <- create_test_candlestick_df()
  p <- create_test_ggplot_candlestick()
  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  data <- processor$extract_data(p)
  expected_vol <- round((df$high - df$low) * 100) / 100
  actual_vol <- vapply(data, function(pt) pt$volatility, numeric(1))
  testthat::expect_equal(actual_vol, expected_vol)
})

test_that("extract_data optionally includes volume when mapped", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  df <- create_test_candlestick_df()
  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(
      x = date, open = open, high = high, low = low,
      close = close, volume = volume
    )
  ) +
    tidyquant::geom_candlestick()

  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  data <- processor$extract_data(p)
  for (i in seq_along(data)) {
    testthat::expect_true("volume" %in% names(data[[i]]))
    testthat::expect_equal(data[[i]]$volume, df$volume[i])
  }
})

test_that("extract_data omits volume when not mapped", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  data <- processor$extract_data(p)
  for (pt in data) {
    testthat::expect_false("volume" %in% names(pt))
  }
})

# ==============================================================================
# Tier 4: Selector Generation
# ==============================================================================

test_that("generate_selectors returns a single CandlestickSelector object", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  gt <- ggplot2::ggplotGrob(p)

  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  sel <- processor$generate_selectors(p, gt)
  testthat::expect_type(sel, "list")
  testthat::expect_true("body" %in% names(sel))
  testthat::expect_true("wick" %in% names(sel))
})

test_that("generate_selectors emits single-string body and wick selectors", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  gt <- ggplot2::ggplotGrob(p)

  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  sel <- processor$generate_selectors(p, gt)

  # Single-string group selectors (not per-candle arrays).
  testthat::expect_type(sel$body, "character")
  testthat::expect_length(sel$body, 1)
  testthat::expect_match(sel$body, "geom_rect")
  testthat::expect_match(sel$body, "rect$")

  testthat::expect_type(sel$wick, "character")
  testthat::expect_length(sel$wick, 1)
  testthat::expect_match(sel$wick, "geom_linerange")
  testthat::expect_match(sel$wick, "polyline$")
})

test_that("generate_selectors emits open/close group selectors", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  gt <- ggplot2::ggplotGrob(p)

  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  sel <- processor$generate_selectors(p, gt)

  # Open/close selectors point at the post-export-injected `<g>` containers
  # (one line per candle inside each).
  testthat::expect_type(sel$open, "character")
  testthat::expect_match(sel$open,  "^#maidr-cs-opens-\\d+ line$")
  testthat::expect_type(sel$close, "character")
  testthat::expect_match(sel$close, "^#maidr-cs-closes-\\d+ line$")
})

# ==============================================================================
# Tier 5: Axes
# ==============================================================================

test_that("extract_layer_axes uses x mapping and 'Price' for y", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()

  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  layout <- list(axes = list(x = "", y = ""))
  axes <- processor$extract_layer_axes(p, layout)

  testthat::expect_equal(axes$x$label, "date")
  testthat::expect_equal(axes$y$label, "Price")
})

# ==============================================================================
# Tier 6: Process (full layer output)
# ==============================================================================

test_that("process() returns a candlestick layer with all fields", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)

  body_idx <- candlestick_body_index(p)
  layer_info <- list(index = body_idx)
  processor <- maidr:::Ggplot2CandlestickProcessor$new(layer_info)

  layout <- list(
    title = "Test Candlestick",
    axes = list(x = "Date", y = "Price")
  )
  result <- processor$process(p, layout, built = built, gt = gt)

  testthat::expect_equal(result$type, "candlestick")
  testthat::expect_equal(result$orientation, "vert")
  testthat::expect_equal(result$title, "Test Candlestick")

  testthat::expect_type(result$data, "list")
  testthat::expect_true(length(result$data) > 0)

  testthat::expect_type(result$selectors, "list")
  testthat::expect_true("body" %in% names(result$selectors))

  testthat::expect_true("axes" %in% names(result))
})

# ==============================================================================
# Tier 7: Orchestrator integration (skip + body)
# ==============================================================================

test_that("orchestrator produces exactly one candlestick layer", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()

  subplot <- maidr_data$subplots[[1]][[1]]

  # Wick layer was tagged 'skip' -> only the candlestick layer remains.
  testthat::expect_equal(length(subplot$layers), 1)
  testthat::expect_equal(subplot$layers[[1]]$type, "candlestick")
  testthat::expect_equal(
    length(subplot$layers[[1]]$data),
    nrow(create_test_candlestick_df())
  )
})

test_that("orchestrator does not flag candlestick as unsupported", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_false(orchestrator$has_unsupported_layers())
  testthat::expect_false(orchestrator$should_fallback())
})

# ==============================================================================
# Tier 8: JSON serialization
# ==============================================================================

test_that("candlestick maidr data serializes to valid JSON", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("jsonlite")

  p <- create_test_ggplot_candlestick()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()

  json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)
  testthat::expect_type(json, "character")

  parsed <- jsonlite::fromJSON(as.character(json), simplifyVector = FALSE)
  layers <- parsed$subplots[[1]][[1]]$layers

  testthat::expect_equal(layers[[1]]$type, "candlestick")

  pt <- layers[[1]]$data[[1]]
  for (f in c("value", "open", "high", "low", "close", "trend", "volatility")) {
    testthat::expect_true(f %in% names(pt))
  }

  sel <- layers[[1]]$selectors
  testthat::expect_true("body" %in% names(sel))
  testthat::expect_true("wick" %in% names(sel))
  testthat::expect_true("open" %in% names(sel))
  testthat::expect_true("close" %in% names(sel))
  # JSON-roundtripped: body/wick/open/close should be single strings.
  testthat::expect_type(sel$body, "character")
  testthat::expect_type(sel$wick, "character")
  testthat::expect_type(sel$open, "character")
  testthat::expect_type(sel$close, "character")
})

# ==============================================================================
# Tier 9: SVG injection of open/close virtual line elements
# ==============================================================================

test_that("save_html injects maidr-cs-opens / maidr-cs-closes groups", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("xml2")

  p <- create_test_ggplot_candlestick()
  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  maidr::save_html(p, out)

  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Both injected group containers exist
  testthat::expect_match(txt, "maidr-cs-opens-\\d+")
  testthat::expect_match(txt, "maidr-cs-closes-\\d+")

  # Each group holds one <line> per candle
  n <- nrow(create_test_candlestick_df())
  open_lines  <- length(regmatches(
    txt, gregexpr("id=\"maidr-cs-open-\\d+-\\d+\"", txt))[[1]])
  close_lines <- length(regmatches(
    txt, gregexpr("id=\"maidr-cs-close-\\d+-\\d+\"", txt))[[1]])
  testthat::expect_equal(open_lines, n)
  testthat::expect_equal(close_lines, n)
})

test_that("Bull candle's injected close line sits at higher raw y than open", {
  # In gridSVG's flipped local space, larger raw y = higher data value.
  # Test data: candle 1 is Bull (open=100, close=110), so the injected
  # `close` <line> must have a larger y attribute than its `open` partner.
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("xml2")

  p <- create_test_ggplot_candlestick()
  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  maidr::save_html(p, out)

  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Pull y1 attribute from the first open and close lines (candle index 1).
  open_match  <- regmatches(
    txt,
    regexpr("id=\"maidr-cs-open-\\d+-1\"[^/>]*y1=\"([0-9.eE+-]+)\"", txt)
  )
  close_match <- regmatches(
    txt,
    regexpr("id=\"maidr-cs-close-\\d+-1\"[^/>]*y1=\"([0-9.eE+-]+)\"", txt)
  )

  open_y  <- as.numeric(sub('.*y1="([0-9.eE+-]+)".*', "\\1", open_match))
  close_y <- as.numeric(sub('.*y1="([0-9.eE+-]+)".*', "\\1", close_match))

  testthat::expect_false(is.na(open_y))
  testthat::expect_false(is.na(close_y))
  testthat::expect_true(close_y > open_y)
})

# ==============================================================================
# Tier 10: Volume field JSON round-trip (Phase 2)
# ==============================================================================

test_that("volume field round-trips through JSON serialization", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("jsonlite")

  df <- create_test_candlestick_df()
  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(
      x = date, open = open, high = high, low = low,
      close = close, volume = volume
    )
  ) +
    tidyquant::geom_candlestick()

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()

  json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)
  parsed <- jsonlite::fromJSON(as.character(json), simplifyVector = FALSE)

  layers <- parsed$subplots[[1]][[1]]$layers
  candle_layer <- NULL
  for (l in layers) {
    if (identical(l$type, "candlestick")) {
      candle_layer <- l
      break
    }
  }
  testthat::expect_false(is.null(candle_layer))

  # Each data point must have a volume field equal to the source df.
  for (i in seq_along(candle_layer$data)) {
    pt <- candle_layer$data[[i]]
    testthat::expect_true("volume" %in% names(pt))
    testthat::expect_equal(pt$volume, df$volume[i])
  }
})
