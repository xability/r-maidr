# MAIDR Example: Candlestick + Moving Averages + Volume (ggplot2 + tidyquant + patchwork)
# Demonstrates a canonical financial chart with three accessible layers:
#   1. Candlestick (OHLC) bodies and wicks
#   2. Two moving averages (geom_ma) overlaid on the price panel
#   3. Volume bar chart in a separate sub-panel (combined via patchwork)
#
# Requires the {tidyquant} and {patchwork} packages:
#   install.packages(c("tidyquant", "patchwork"))

library(maidr)
library(ggplot2)
library(tidyquant)
library(patchwork)

# --- Synthetic OHLCV data (20 trading days) ----------------------------------
set.seed(42)
n <- 20
dates <- seq(as.Date("2024-01-02"), by = "day", length.out = n)
opens <- 100 + cumsum(rnorm(n, 0, 1.5))
closes <- opens + rnorm(n, 0, 1.2)
highs <- pmax(opens, closes) + abs(rnorm(n, 1, 0.5))
lows  <- pmin(opens, closes) - abs(rnorm(n, 1, 0.5))
volumes <- as.integer(runif(n, 1e5, 5e5))

ohlcv <- data.frame(
  date   = dates,
  open   = round(opens,  2),
  high   = round(highs,  2),
  low    = round(lows,   2),
  close  = round(closes, 2),
  volume = volumes
)

# --- Price panel: candlestick + 2 moving averages ----------------------------
p_price <- ggplot(
  ohlcv,
  aes(x = date, open = open, high = high, low = low, close = close)
) +
  geom_candlestick(
    colour_up = "darkgreen",
    colour_down = "red",
    fill_up   = "darkgreen",
    fill_down = "red"
  ) +
  # Note: geom_ma captures ma_fun symbolically — pass a bare `SMA` symbol
  # (exported from tidyquant) rather than a string.
  geom_ma(aes(y = close), ma_fun = SMA, n = 5,
          colour = "blue", linetype = "dashed", linewidth = 0.8) +
  geom_ma(aes(y = close), ma_fun = SMA, n = 10,
          colour = "orange", linetype = "dotted", linewidth = 0.8) +
  labs(
    title = "OHLC with 5- and 10-day SMA",
    x = NULL,
    y = "Price"
  ) +
  theme_minimal()

# --- Volume panel: separate bar chart ----------------------------------------
p_volume <- ggplot(ohlcv, aes(x = date, y = volume)) +
  geom_col(fill = "steelblue", alpha = 0.7) +
  labs(x = "Date", y = "Volume") +
  theme_minimal()

# --- Combine via patchwork ---------------------------------------------------
p_combined <- p_price / p_volume +
  plot_layout(heights = c(3, 1), axes = "collect_x")

show(p_combined)
