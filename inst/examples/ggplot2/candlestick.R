# MAIDR Example: Candlestick Plot (ggplot2 + tidyquant)
# Demonstrates accessible OHLC candlestick plot with keyboard navigation.
# Each candle exposes open / high / low / close + computed trend
# (Bull / Bear / Neutral) and volatility (high - low).
#
# Requires the {tidyquant} package:
#   install.packages("tidyquant")

library(maidr)
library(ggplot2)
library(tidyquant)

# --- Sample OHLC data (4 trading days) ----------------------------------------
ohlc <- data.frame(
  date  = as.Date(c("2023-01-02", "2023-01-03", "2023-01-04", "2023-01-05")),
  open  = c(100, 105, 110, 108),
  high  = c(115, 108, 112, 110),
  low   = c( 95, 102, 105, 100),
  # Bull, Bear, Bull, Neutral
  close = c(110, 103, 111, 108)
)

# --- Vertical candlestick chart ----------------------------------------------
p_candle <- ggplot(
  ohlc,
  aes(x = date, open = open, high = high, low = low, close = close)
) +
  geom_candlestick(
    colour_up = "darkgreen",
    colour_down = "red",
    fill_up   = "darkgreen",
    fill_down = "red"
  ) +
  labs(
    title = "Sample Candlestick Chart",
    subtitle = "OHLC over 4 trading days",
    x = "Date",
    y = "Price"
  ) +
  theme_minimal()

show(p_candle)
