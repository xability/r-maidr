# Tests for candlestick + volume / candlestick + MA in patchwork composition.
# Phase 2: Volume bar charts are combined with candlestick price plots via
# patchwork (the canonical financial-chart pattern, since tidyquant has no
# dedicated volume geom).
#
# The orchestrator post-processes the patchwork subplot grid so that:
#   1. Multiple moving-average line layers in one panel collapse to a single
#      multi-series "line" layer entry (matching py-maidr's single multiline
#      layer for overlaid MAs).
#   2. A candlestick panel stacked over a volume-only bar panel collapses to
#      a single subplot with up to three layers (candlestick + bar + line),
#      and volume y-values are embedded into each candlestick data point.

# ==============================================================================
# Helpers (local — tidyquant and patchwork are Suggests)
# ==============================================================================

create_test_ohlcv_df <- function() {
  set.seed(7)
  n <- 12
  data.frame(
    date   = seq(as.Date("2024-01-02"), by = "day", length.out = n),
    open   = round(100 + cumsum(stats::rnorm(n, 0, 1)), 2),
    high   = round(100 + cumsum(stats::rnorm(n, 0, 1)) + 2, 2),
    low    = round(100 + cumsum(stats::rnorm(n, 0, 1)) - 2, 2),
    close  = round(100 + cumsum(stats::rnorm(n, 0, 1)), 2),
    volume = as.integer(stats::runif(n, 1e5, 5e5))
  )
}

create_test_ggplot_candlestick_only <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  df <- create_test_ohlcv_df()
  ggplot2::ggplot(
    df,
    ggplot2::aes(x = date, open = open, high = high, low = low, close = close)
  ) +
    tidyquant::geom_candlestick()
}

create_test_ggplot_candlestick_with_two_ma <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  testthat::skip_if_not_installed("TTR")
  # See note in test-ggplot2-adapter-geom-ma.R: tidyquant captures
  # `ma_fun` symbolically via deparse(substitute()), so we use a bare
  # `SMA` symbol bound locally to the function. SMA is exported by TTR.
  SMA <- TTR::SMA

  df <- create_test_ohlcv_df()
  ggplot2::ggplot(
    df,
    ggplot2::aes(x = date, open = open, high = high, low = low, close = close)
  ) +
    tidyquant::geom_candlestick() +
    tidyquant::geom_ma(ggplot2::aes(y = close), ma_fun = SMA, n = 3,
                       colour = "blue", linetype = "dashed") +
    tidyquant::geom_ma(ggplot2::aes(y = close), ma_fun = SMA, n = 5,
                       colour = "orange", linetype = "dotted")
}

create_test_ggplot_volume <- function() {
  testthat::skip_if_not_installed("ggplot2")

  df <- create_test_ohlcv_df()
  ggplot2::ggplot(df, ggplot2::aes(x = date, y = volume)) +
    ggplot2::geom_col(fill = "steelblue")
}

# ==============================================================================
# Tier 1: Single-panel candlestick + 2 MAs
# ==============================================================================

test_that("candlestick + 2 MA layers in same panel collapse into 2 layers (candlestick + multi-series line)", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick_with_two_ma()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()

  panel <- maidr_data$subplots[[1]][[1]]
  layer_types <- vapply(panel$layers, function(l) l$type, character(1))

  # Wick layer is skipped, and 2 MA line layers are merged into one
  # multi-series "line" layer entry.
  testthat::expect_equal(length(panel$layers), 2)
  testthat::expect_equal(sum(layer_types == "candlestick"), 1)
  testthat::expect_equal(sum(layer_types == "line"), 1)

  # The merged line layer should carry 2 series (one per MA).
  line_layer <- panel$layers[[which(layer_types == "line")]]
  testthat::expect_equal(length(line_layer$data), 2)
  testthat::expect_equal(length(line_layer$selectors), 2)
})

# ==============================================================================
# Tier 2: Multi-panel candlestick / volume via patchwork
# ==============================================================================

test_that("candlestick / volume patchwork collapses into single subplot with candlestick + bar layers", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("patchwork")

  p_price  <- create_test_ggplot_candlestick_only()
  p_volume <- create_test_ggplot_volume()

  combined <- p_price / p_volume

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(combined)
  testthat::expect_true(orchestrator$is_patchwork_plot())

  maidr_data <- orchestrator$generate_maidr_data()
  testthat::expect_false(is.null(maidr_data$subplots))

  # Grid collapses to 1x1: candlestick + bar in a single subplot.
  testthat::expect_equal(length(maidr_data$subplots), 1L)
  testthat::expect_equal(length(maidr_data$subplots[[1]]), 1L)

  panel <- maidr_data$subplots[[1]][[1]]
  layer_types <- vapply(panel$layers, function(l) l$type, character(1))

  testthat::expect_equal(length(panel$layers), 2L)
  testthat::expect_equal(sum(layer_types == "candlestick"), 1L)
  testthat::expect_equal(sum(layer_types == "bar"), 1L)

  # Volume should be embedded in candlestick data points
  candle_layer <- panel$layers[[which(layer_types == "candlestick")]]
  has_volume <- vapply(candle_layer$data, function(pt) {
    !is.null(pt$volume)
  }, logical(1))
  testthat::expect_true(all(has_volume))

  # Each bar layer point's x must be an ISO date string sourced from the
  # original Date column, not a sparse axis-break label.
  bar_layer <- panel$layers[[which(layer_types == "bar")]]
  for (pt in bar_layer$data) {
    testthat::expect_match(pt$x, "^\\d{4}-\\d{2}-\\d{2}$")
  }
})

test_that("orchestrator does not flag candlestick / volume patchwork as unsupported", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("patchwork")

  p_price  <- create_test_ggplot_candlestick_only()
  p_volume <- create_test_ggplot_volume()
  combined <- p_price / p_volume

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(combined)

  testthat::expect_false(orchestrator$has_unsupported_layers())
  testthat::expect_false(orchestrator$should_fallback())
})

test_that("candlestick + 2 MAs + separate volume patchwork collapses into 3-layer subplot", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("patchwork")

  p_price  <- create_test_ggplot_candlestick_with_two_ma()
  p_volume <- create_test_ggplot_volume()
  combined <- p_price / p_volume

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(combined)
  maidr_data <- orchestrator$generate_maidr_data()

  # Grid collapses to 1x1, single subplot with 3 layers (candlestick + bar + multi-series line)
  testthat::expect_equal(length(maidr_data$subplots), 1L)
  testthat::expect_equal(length(maidr_data$subplots[[1]]), 1L)

  panel <- maidr_data$subplots[[1]][[1]]
  layer_types <- vapply(panel$layers, function(l) l$type, character(1))

  testthat::expect_equal(length(panel$layers), 3L)
  testthat::expect_equal(sum(layer_types == "candlestick"), 1L)
  testthat::expect_equal(sum(layer_types == "bar"), 1L)
  testthat::expect_equal(sum(layer_types == "line"), 1L)

  # Layer order: candlestick first, then bar, then line
  testthat::expect_equal(panel$layers[[1]]$type, "candlestick")
  testthat::expect_equal(panel$layers[[2]]$type, "bar")
  testthat::expect_equal(panel$layers[[3]]$type, "line")

  # Merged line layer carries 2 series (one per MA)
  testthat::expect_equal(length(panel$layers[[3]]$data), 2L)

  # Candlestick data has embedded volume on every point
  candle_layer <- panel$layers[[1]]
  has_volume <- vapply(candle_layer$data, function(pt) {
    !is.null(pt$volume)
  }, logical(1))
  testthat::expect_true(all(has_volume))
})

test_that("candlestick + MA + separate volume patchwork serializes to valid JSON", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")
  testthat::skip_if_not_installed("patchwork")
  testthat::skip_if_not_installed("jsonlite")

  p_price  <- create_test_ggplot_candlestick_with_two_ma()
  p_volume <- create_test_ggplot_volume()
  combined <- p_price / p_volume

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(combined)
  maidr_data <- orchestrator$generate_maidr_data()

  json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)
  testthat::expect_type(json, "character")

  parsed <- jsonlite::fromJSON(as.character(json), simplifyVector = FALSE)
  testthat::expect_false(is.null(parsed$subplots))

  # 1x1 grid with single subplot of 3 layers
  testthat::expect_equal(length(parsed$subplots), 1L)
  testthat::expect_equal(length(parsed$subplots[[1]]), 1L)
  testthat::expect_equal(length(parsed$subplots[[1]][[1]]$layers), 3L)
})
