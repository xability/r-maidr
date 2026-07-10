# Tests for tidyquant::geom_ma() detection
# Phase 2: Moving averages should be detected as ordinary line layers so they
# can be overlaid on candlestick (or any other) plots without being routed to
# the unknown processor.

# ==============================================================================
# Helpers (local — tidyquant is in Suggests)
# ==============================================================================

create_test_candlestick_ma_df <- function() {
  set.seed(123)
  n <- 12
  data.frame(
    date  = seq(as.Date("2024-01-02"), by = "day", length.out = n),
    open  = round(100 + cumsum(stats::rnorm(n, 0, 1)), 2),
    high  = round(100 + cumsum(stats::rnorm(n, 0, 1)) + 2, 2),
    low   = round(100 + cumsum(stats::rnorm(n, 0, 1)) - 2, 2),
    close = round(100 + cumsum(stats::rnorm(n, 0, 1)), 2)
  )
}

create_test_ggplot_candlestick_with_ma <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  testthat::skip_if_not_installed("TTR")
  # tidyquant::geom_ma captures `ma_fun` via deparse(substitute()) and
  # compares the resulting string against "SMA"/"EMA"/etc. in get_ma().
  # Assigning to a local symbol named `SMA` ensures deparse yields "SMA".
  # SMA itself is exported by TTR (which tidyquant depends on).
  SMA <- TTR::SMA

  df <- create_test_candlestick_ma_df()
  ggplot2::ggplot(
    df,
    ggplot2::aes(x = date, open = open, high = high, low = low, close = close)
  ) +
    tidyquant::geom_candlestick() +
    tidyquant::geom_ma(ggplot2::aes(y = close), ma_fun = SMA, n = 3,
                       colour = "blue", linetype = "dashed")
}

# ==============================================================================
# Tier 1: Adapter detection
# ==============================================================================

test_that("adapter detects GeomMA as 'line'", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick_with_ma()
  adapter <- maidr:::Ggplot2Adapter$new()

  ma_idx <- which(vapply(p$layers, function(l) {
    inherits(l$geom, "GeomMA")
  }, logical(1)))
  testthat::expect_true(length(ma_idx) >= 1)

  layer_type <- adapter$detect_layer_type(p$layers[[ma_idx[1]]], p)
  testthat::expect_equal(layer_type, "line")
})

# ==============================================================================
# Tier 2: Orchestrator end-to-end
# ==============================================================================

test_that("geom_ma overlaid on geom_candlestick produces candlestick + line layers", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick_with_ma()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()

  panel <- maidr_data$subplots[[1]][[1]]
  layer_types <- vapply(panel$layers, function(l) l$type, character(1))

  testthat::expect_true("candlestick" %in% layer_types)
  testthat::expect_true("line" %in% layer_types)

  # Wick layer is skipped, so we should have exactly: 1 candlestick + 1 MA line.
  testthat::expect_equal(length(panel$layers), 2)
})

test_that("orchestrator does not flag candlestick + geom_ma as unsupported", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("tidyquant")

  p <- create_test_ggplot_candlestick_with_ma()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_false(orchestrator$has_unsupported_layers())
  testthat::expect_false(orchestrator$should_fallback())
})
