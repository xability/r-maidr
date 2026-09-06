# Heat Map and Candlestick Examples

Heat maps and candlestick charts are the grid and financial family. A
heat map is navigated cell by cell, row then column, with the cell value
on the z axis and mapped to pitch; a candlestick chart is walked candle
by candle, each announcing its open, high, low, close, trend and
volatility. Both are stable plot types (see “Supported plot types” in
the README); the candlestick support matrix below records which overlays
each system reads. The [examples
hub](https://r.maidr.ai/articles/examples.md) lists every other plot
family.

## Heat Map

A heatmap uses color intensity to represent values in a two-dimensional
matrix. It is useful for spotting patterns, clusters, and outliers
across two categorical dimensions.

### ggplot2

``` r

heatmap_data <- expand.grid(
  Day = c("Mon", "Tue", "Wed", "Thu", "Fri"),
  Hour = c("9am", "10am", "11am", "12pm", "1pm", "2pm", "3pm", "4pm")
)
heatmap_data$Visitors <- c(
  20, 35, 50, 45, 30,
  25, 40, 60, 55, 35,
  30, 55, 75, 70, 45,
  40, 65, 90, 85, 60,
  35, 50, 70, 65, 40,
  30, 45, 60, 55, 38,
  25, 40, 55, 50, 32,
  15, 30, 40, 35, 22
)

p <- ggplot(heatmap_data, aes(x = Day, y = Hour, fill = Visitors)) +
  geom_tile(color = "white") +
  scale_fill_gradient(low = "#f7fbff", high = "#08306b") +
  labs(title = "Website Visitors by Day and Hour") +
  theme_minimal()

p
```

### Base R

``` r

visitors <- matrix(
  c(
    20, 35, 50, 45, 30,
    25, 40, 60, 55, 35,
    30, 55, 75, 70, 45,
    40, 65, 90, 85, 60,
    35, 50, 70, 65, 40,
    30, 45, 60, 55, 38,
    25, 40, 55, 50, 32,
    15, 30, 40, 35, 22
  ),
  nrow = 5
)
image(visitors,
  col = hcl.colors(20, "Blues"),
  main = "Website Visitors by Day and Hour",
  xlab = "Day",
  ylab = "Hour",
  axes = FALSE
)
axis(1,
  at = seq(0, 1, length.out = 5),
  labels = c("Mon", "Tue", "Wed", "Thu", "Fri")
)
axis(2,
  at = seq(0, 1, length.out = 8),
  labels = c("9am", "10am", "11am", "12pm", "1pm", "2pm", "3pm", "4pm")
)
```

------------------------------------------------------------------------

## Candlestick (OHLC) Charts

A candlestick chart visualizes Open-High-Low-Close (OHLC) financial
data. Each candle represents one trading period and exposes the four
price fields plus a computed **trend** (Bull / Bear / Neutral) and
**volatility** (high − low). When volume data is present and combined
with a volume panel via patchwork, each candle’s `volume` is also
embedded in the data point.

> **Note:** Requires the {tidyquant} package for the ggplot2 path and
> {quantmod} for the Base R path. Install with
> `install.packages(c("tidyquant", "patchwork", "quantmod"))`.

### Support matrix: what works in each system

The accessible HTML pipeline supports different sets of overlays for the
ggplot2 and Base R candlestick paths. Use the ggplot2 + tidyquant +
patchwork path whenever you need moving averages or a volume sub-panel.

| Feature | ggplot2 ([`tidyquant::geom_candlestick`](https://business-science.github.io/tidyquant/reference/geom_chart.html)) | Base R ([`quantmod::chartSeries`](https://rdrr.io/pkg/quantmod/man/chartSeries.html)) |
|----|----|----|
| Plain OHLC candlestick | ✅ Supported | ✅ Supported (OHLC-only input) |
| Moving-average overlay | ✅ via [`tidyquant::geom_ma()`](https://business-science.github.io/tidyquant/reference/geom_ma.html) (one or more layers; auto-collapsed into a single multi-series line layer) | ❌ `TA = "addSMA()"` / `"addEMA()"` not supported |
| Volume sub-panel | ✅ via separate [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html) + [`patchwork::plot_layout()`](https://patchwork.data-imaginist.com/reference/plot_layout.html) (collapsed into the candlestick subplot, with `volume` embedded into each candle point) | ❌ `TA = "addVo()"` not supported; default `TA` with a `Volume` column also unsupported |
| Behavior when unsupported | n/a | One-time warning + fall back to native (non-accessible) graphics; advisory points users to the ggplot2 pipeline |

### Simple OHLC Candlestick

#### ggplot2

``` r

library(tidyquant)

ohlc_simple <- data.frame(
  date  = as.Date(c("2023-01-02", "2023-01-03", "2023-01-04", "2023-01-05")),
  open  = c(100, 105, 110, 108),
  high  = c(115, 108, 112, 110),
  low   = c(95, 102, 105, 100),
  # Bull, Bear, Bull, Neutral
  close = c(110, 103, 111, 108)
)

p <- ggplot(
  ohlc_simple,
  aes(x = date, open = open, high = high, low = low, close = close)
) +
  geom_candlestick(
    colour_up = "darkgreen", colour_down = "red",
    fill_up = "darkgreen", fill_down = "red"
  ) +
  labs(
    title = "Sample OHLC Candlestick",
    subtitle = "Four trading days",
    x = "Date",
    y = "Price"
  ) +
  theme_minimal()

p
```

### Candlestick with Moving Averages and Volume (ggplot2)

This example exercises the full accessible price + MA + volume pipeline:
a candlestick layer, two
[`geom_ma()`](https://business-science.github.io/tidyquant/reference/geom_ma.html)
overlays (5- and 10-day SMAs), and a separate volume bar panel composed
via patchwork. MAIDR collapses the two
[`geom_ma()`](https://business-science.github.io/tidyquant/reference/geom_ma.html)
overlays into a single multi-series line layer, and the candlestick +
bar + line panels collapse to a single navigable subplot in which each
candle also carries its `volume` field.

``` r

library(tidyquant)
library(patchwork)

set.seed(42)
n_days <- 20
dates  <- seq(as.Date("2024-01-02"), by = "day", length.out = n_days)
opens  <- 100 + cumsum(rnorm(n_days, 0, 1.5))
closes <- opens + rnorm(n_days, 0, 1.2)
highs  <- pmax(opens, closes) + abs(rnorm(n_days, 1, 0.5))
lows   <- pmin(opens, closes) - abs(rnorm(n_days, 1, 0.5))
vols   <- as.integer(runif(n_days, 1e5, 5e5))

ohlcv <- data.frame(
  date   = dates,
  open   = round(opens, 2),
  high   = round(highs, 2),
  low    = round(lows, 2),
  close  = round(closes, 2),
  volume = vols
)

p_price <- ggplot(
  ohlcv,
  aes(x = date, open = open, high = high, low = low, close = close)
) +
  geom_candlestick(
    colour_up = "darkgreen", colour_down = "red",
    fill_up = "darkgreen", fill_down = "red"
  ) +
  geom_ma(aes(y = close), ma_fun = SMA, n = 5,
          colour = "blue", linetype = "dashed", linewidth = 0.8) +
  geom_ma(aes(y = close), ma_fun = SMA, n = 10,
          colour = "orange", linetype = "dotted", linewidth = 0.8) +
  labs(title = "OHLC with 5- and 10-day SMA", x = NULL, y = "Price") +
  theme_minimal()

p_volume <- ggplot(ohlcv, aes(x = date, y = volume)) +
  geom_col(fill = "steelblue", alpha = 0.7) +
  labs(x = "Date", y = "Volume") +
  theme_minimal()

p_price / p_volume + plot_layout(heights = c(3, 1), axes = "collect_x")
```

### Base R Candlestick (quantmod)

The Base R path supports a plain OHLC candlestick via
`quantmod::chartSeries(x, type = "candlesticks")`. Each row of the
`xts`/`zoo` input is emitted as a navigable candle point with `value`
(ISO date), `open`, `high`, `low`, `close`, computed `trend`, and
`volatility`.

> **Limitations.** Technical-analysis overlays via the `TA` argument
> (e.g. [`addVo()`](https://rdrr.io/pkg/quantmod/man/addVo.html),
> [`addSMA()`](https://rdrr.io/pkg/quantmod/man/addMA.html),
> [`addEMA()`](https://rdrr.io/pkg/quantmod/man/addMA.html)) are **not
> supported** by the accessible HTML pipeline. The same applies to
> [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s
> *default* `TA` whenever the input `xts` has a `Volume` column, since
> the default auto-adds
> [`addVo()`](https://rdrr.io/pkg/quantmod/man/addVo.html). In all these
> cases maidr falls back to native (non-accessible) graphics with a
> one-time advisory pointing users to the ggplot2 + tidyquant +
> patchwork pipeline shown above. To opt in to accessible HTML for a
> Base R candlestick, supply OHLC data **without** a `Volume` column
> (default `TA` then becomes a no-op), or pass `TA = NULL` explicitly.

> **Attach order matters.**
> [`library(quantmod)`](https://www.quantmod.com/) after
> [`library(maidr)`](https://github.com/xability/r-maidr) puts
> `package:quantmod` ahead of `package:maidr` on the search path, so a
> bare
> [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
> call reaches quantmod directly and maidr never records it — the chart
> draws, but [`show()`](https://r.maidr.ai/reference/show.md) and
> [`save_html()`](https://r.maidr.ai/reference/save_html.md) then report
> that no Base R plot was found. Either attach `quantmod` **before**
> `maidr`, or call
> [`maidr::chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
> explicitly as below, which works in either order.

``` r

library(quantmod)

# OHLC-only xts (no Volume column) so the default TA is a no-op.
TST <- xts::xts(
  cbind(
    Open  = c(101.00, 102.00, 105.00, 103.50),
    High  = c(102.50, 105.50, 105.80, 104.50),
    Low   = c(100.50, 101.80, 103.00, 102.50),
    Close = c(102.00, 105.00, 103.50, 104.00)
  ),
  order.by = as.Date(c(
    "2024-01-12", "2024-01-13", "2024-01-14", "2024-01-15"
  ))
)
colnames(TST) <- c("TST.Open", "TST.High", "TST.Low", "TST.Close")

maidr::chartSeries(TST, type = "candlesticks", theme = "white", name = "TST")
```
