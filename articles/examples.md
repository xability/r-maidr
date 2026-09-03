# Examples

Making accessible data representation with **maidr** is easy and
straightforward. If you already have data visualization code using
**ggplot2** or **Base R**, you can make your plots accessible with maidr
in just a few lines of code.

Simply load the maidr package and call
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md). When plots are
printed in a document, maidr will automatically generate accessible
versions. You can then interact with the accessible versions using
keyboard shortcuts (refer to the table below).

|       Key        | Action                              |
|:----------------:|-------------------------------------|
| **Left / Right** | Navigate between data points        |
|      **B**       | Toggle braille mode                 |
|      **T**       | Toggle text mode                    |
|      **S**       | Toggle sonification (hear the data) |
|      **R**       | Toggle review mode                  |

## When to Use Each Plot Type

| Plot Type | Best For | Example Use Case |
|----|----|----|
| **Bar Chart** | Comparing categories | Sales by product |
| **Pie Chart** | Parts of a whole | Market share by brand |
| **Histogram** | Showing distributions | Test score frequencies |
| **Scatter Plot** | Relationships between variables | Height vs weight |
| **Line Plot** | Trends over time/order | Stock prices |
| **Step Plot** | Piecewise-constant state over time | A sleep-stage hypnogram |
| **Box Plot** | Distribution comparison | Salary by department |
| **Violin Plot** | Distribution shape comparison | Gene expression by group |
| **Candlestick (OHLC)** | Financial OHLC time-series | Stock price movements |
| **Heatmap** | Matrix relationships | Correlation matrices |
| **Density** | Smooth distributions | Probability density |
| **Faceted** | Comparing subgroups | Regional sales trends |
| **Multi-Panel** | Multiple related views | Dashboard layouts |
| **Multi-Layered** | Combining visualizations | Histogram + density overlay |

------------------------------------------------------------------------

## Bar Plots

### Simple Bar Chart

A simple bar chart compares values across categories. Each bar
represents one category with its height proportional to its value.

#### ggplot2

``` r

bar_data <- data.frame(
  Product = c("Laptop", "Tablet", "Phone", "Monitor"),
  Sales = c(150, 230, 180, 290)
)

p <- ggplot(bar_data, aes(x = Product, y = Sales)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(
    title = "Product Sales by Category",
    x = "Product",
    y = "Sales (units)"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

products <- c("Laptop", "Tablet", "Phone", "Monitor")
sales <- c(150, 230, 180, 290)

barplot(sales,
  names.arg = products,
  col = "steelblue",
  main = "Product Sales by Category",
  xlab = "Product",
  ylab = "Sales (units)"
)
```

### Dodged / Grouped Bar Chart

A dodged bar chart places bars for each sub-group side by side, making
it easy to compare values within and across categories.

#### ggplot2

``` r

dodged_data <- data.frame(
  Region = rep(c("North", "South", "East"), each = 2),
  Quarter = rep(c("Q1", "Q2"), 3),
  Revenue = c(120, 150, 200, 180, 160, 210)
)

p <- ggplot(dodged_data, aes(x = Region, y = Revenue, fill = Quarter)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8)) +
  labs(title = "Quarterly Revenue by Region") +
  scale_fill_manual(values = c("steelblue", "coral")) +
  theme_minimal()

p
```

#### Base R

``` r

revenue_matrix <- matrix(c(120, 150, 200, 180, 160, 210), nrow = 2)
rownames(revenue_matrix) <- c("Q1", "Q2")
barplot(revenue_matrix,
  beside = TRUE,
  names.arg = c("North", "South", "East"),
  col = c("steelblue", "coral"),
  legend.text = rownames(revenue_matrix),
  main = "Quarterly Revenue by Region",
  xlab = "Region",
  ylab = "Revenue"
)
```

### Stacked Bar Chart

A stacked bar chart layers sub-groups on top of each other within each
category, showing both individual contributions and the total.

#### ggplot2

``` r

stacked_data <- data.frame(
  Year = rep(c("2022", "2023", "2024"), each = 3),
  Source = rep(c("Solar", "Wind", "Hydro"), 3),
  Output = c(40, 30, 50, 55, 45, 48, 70, 60, 52)
)

p <- ggplot(stacked_data, aes(x = Year, y = Output, fill = Source)) +
  geom_bar(stat = "identity", position = position_stack()) +
  labs(
    title = "Renewable Energy Output by Source",
    y = "Output (GWh)"
  ) +
  scale_fill_manual(values = c("#2ecc71", "#3498db", "#9b59b6")) +
  theme_minimal()

p
```

#### Base R

``` r

energy_matrix <- matrix(
  c(40, 30, 50, 55, 45, 48, 70, 60, 52),
  nrow = 3
)
rownames(energy_matrix) <- c("Solar", "Wind", "Hydro")
barplot(energy_matrix,
  beside = FALSE,
  names.arg = c("2022", "2023", "2024"),
  col = c("#2ecc71", "#3498db", "#9b59b6"),
  legend.text = rownames(energy_matrix),
  main = "Renewable Energy Output by Source",
  xlab = "Year",
  ylab = "Output (GWh)"
)
```

------------------------------------------------------------------------

## Pie Chart

A pie chart splits a whole into wedges, one per category, each wedge’s
angle proportional to its share. maidr announces every slice by name and
value, and derives its percentage of the total for you.

#### ggplot2

ggplot2 has no pie geom: a pie is a single stacked column bent around by
`coord_polar("y")`, so `x` is the literal `""` and the categories go on
`fill`. `coord_radial(theta = "y")` works the same way. Note that
`coord_polar("x")` draws a coxcomb instead, which maidr still describes
as a bar chart.

``` r

market_share <- data.frame(
  Browser = c("Chrome", "Safari", "Edge", "Firefox"),
  Share = c(64, 19, 5, 3)
)

p <- ggplot(market_share, aes(x = "", y = Share, fill = Browser)) +
  geom_col(width = 1) +
  coord_polar("y") +
  labs(
    title = "Browser Market Share",
    fill = "Browser",
    y = "Share (%)"
  ) +
  theme_void()

p
```

#### Base R

``` r

shares <- c(Chrome = 64, Safari = 19, Edge = 5, Firefox = 3)
pie(shares,
  col = c("#3498db", "#2ecc71", "#9b59b6", "#e67e22"),
  main = "Browser Market Share",
  xlab = "Browser",
  ylab = "Share (%)"
)
```

------------------------------------------------------------------------

## Word Cloud

A word cloud is the extreme case of a chart that carries real data while
being readable only by eye: each term’s weight is drawn as **glyph
size** and written down nowhere on the page. Structurally it is a
categorical label and a magnitude, so maidr reads it as a term and its
number.

> **Experimental.** `word_cloud` is one of the experimental layer types.
> It has not been through a user study, and it may change without a
> deprecation period. See the experimental table in the README.

> **Note:** Word clouds are a Base R feature. ggplot2 has no word cloud
> geom, and the packages that add one draw through their own devices
> rather than through a layer maidr can read.

> **Requires the {wordcloud} package.** Install with
> `install.packages("wordcloud")`.

#### Base R

The counts you pass survive into the reading, so the weight axis
honestly says **Occurrences**. (The Python binding cannot:
`wordcloud.WordCloud` divides every frequency by the largest and keeps
only the ratio, so py-maidr announces a *relative* frequency. Same
chart, two different honest readings.)

``` r

mentions <- c(
  accessibility = 412, sonification = 300, braille = 250,
  screenreader = 190, keyboard = 155, contrast = 120
)

maidr::wordcloud(
  words = names(mentions),
  freq = mentions,
  min.freq = 1,
  random.order = FALSE,
  colors = c(
    "#3498db", "#2ecc71", "#9b59b6",
    "#e67e22", "#e74c3c", "#16a085"
  )
)
```

> **Attach order matters.**
> [`library(wordcloud)`](http://blog.fellstat.com/?cat=11) after
> [`library(maidr)`](https://github.com/xability/r-maidr) puts
> `package:wordcloud` ahead of `package:maidr` on the search path, so a
> bare [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md)
> call reaches the wordcloud package directly and maidr never records it
> — the chart draws, but
> [`show()`](https://r.maidr.ai/reference/show.md) and
> [`save_html()`](https://r.maidr.ai/reference/save_html.md) then report
> that no Base R plot was found. Measured on a three-term cloud:
>
> | How it is called | Recorded? |
> |----|----|
> | [`library(maidr)`](https://github.com/xability/r-maidr) then [`library(wordcloud)`](http://blog.fellstat.com/?cat=11), bare [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) | **no** |
> | [`library(wordcloud)`](http://blog.fellstat.com/?cat=11) then [`library(maidr)`](https://github.com/xability/r-maidr), bare [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) | yes |
> | [`maidr::wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) | yes |
>
> Either attach `wordcloud` **before** `maidr`, or call
> [`maidr::wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md)
> explicitly as above, which works in either order.

> **No highlighting.**
> [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
> each term with a bare
> [`text()`](https://r.maidr.ai/reference/base-r-wrappers.md) call at a
> rotation chosen by `rot.per`, and nothing names those — the exported
> SVG carries no `id` attributes at all. So a word cloud is read without
> a visual highlight, rather than pairing the terms with whatever else
> happened to resolve.

Two of
[`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s
arguments decide **which** terms are drawn, and the reading replicates
both so it never announces a term the chart left out: `min.freq`
(default 3) drops anything rarer, and `max.words` keeps only the
heaviest.
[`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) also
lowers `min.freq` to 0 when it exceeds every frequency, which is what
stops a cloud of rare terms coming out empty; that rule is copied rather
than approximated.

------------------------------------------------------------------------

## Histogram

A histogram shows the frequency distribution of a continuous variable by
grouping values into bins. The height of each bar indicates how many
observations fall within that range.

#### ggplot2

``` r

exam_scores <- data.frame(score = c(
  rnorm(500, mean = 72, sd = 10),
  rnorm(500, mean = 85, sd = 8)
))

p <- ggplot(exam_scores, aes(x = score)) +
  geom_histogram(bins = 25, fill = "skyblue", color = "white") +
  labs(
    title = "Distribution of Exam Scores",
    x = "Score",
    y = "Frequency"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

scores <- c(rnorm(500, mean = 72, sd = 10), rnorm(500, mean = 85, sd = 8))
hist(scores,
  breaks = 25,
  col = "skyblue",
  border = "white",
  main = "Distribution of Exam Scores",
  xlab = "Score",
  ylab = "Frequency"
)
```

------------------------------------------------------------------------

## Scatter Plot

A scatter plot displays the relationship between two continuous
variables. Each point represents one observation, and color can encode a
third categorical variable.

#### ggplot2

``` r

car_data <- data.frame(
  weight = mtcars$wt,
  mpg = mtcars$mpg,
  cylinders = factor(mtcars$cyl)
)

p <- ggplot(car_data, aes(x = weight, y = mpg, color = cylinders)) +
  geom_point(size = 3, alpha = 0.8) +
  labs(
    title = "Fuel Efficiency vs Vehicle Weight",
    x = "Weight (1000 lbs)",
    y = "Miles per Gallon",
    color = "Cylinders"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

colors <- c("4" = "steelblue", "6" = "coral", "8" = "forestgreen")
plot(mtcars$wt, mtcars$mpg,
  pch = 19,
  col = colors[as.character(mtcars$cyl)],
  main = "Fuel Efficiency vs Vehicle Weight",
  xlab = "Weight (1000 lbs)",
  ylab = "Miles per Gallon"
)
legend("topright",
  legend = c("4 cyl", "6 cyl", "8 cyl"),
  col = colors, pch = 19
)
```

------------------------------------------------------------------------

## Line Plots

### Single Line

A line plot connects ordered data points, making it ideal for showing
trends over time or sequential categories.

#### ggplot2

``` r

temp_data <- data.frame(
  Month = factor(month.abb, levels = month.abb),
  Temperature = c(2, 4, 10, 15, 20, 25, 28, 27, 22, 15, 8, 3)
)

p <- ggplot(temp_data, aes(x = Month, y = Temperature, group = 1)) +
  geom_line(color = "tomato", linewidth = 1.2) +
  labs(
    title = "Average Monthly Temperature",
    y = "Temperature (C)"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

months <- 1:12
temps <- c(2, 4, 10, 15, 20, 25, 28, 27, 22, 15, 8, 3)
plot(months, temps,
  type = "l", col = "tomato", lwd = 2,
  main = "Average Monthly Temperature",
  xlab = "Month", ylab = "Temperature (C)",
  xaxt = "n"
)
axis(1, at = 1:12, labels = month.abb)
```

### Multiple Lines

A multi-line plot overlays several series on the same axes, enabling
direct comparison of trends across groups.

#### ggplot2

``` r

multi_line <- data.frame(
  Year = rep(2015:2024, 3),
  Users = c(
    10, 15, 22, 35, 50, 72, 95, 120, 150, 180,
    8, 12, 18, 25, 38, 55, 70, 88, 110, 135,
    5, 8, 14, 20, 30, 42, 58, 75, 95, 118
  ),
  Platform = rep(c("Mobile", "Desktop", "Tablet"), each = 10)
)

p <- ggplot(multi_line, aes(x = Year, y = Users, color = Platform)) +
  geom_line(linewidth = 1.2) +
  labs(
    title = "Platform Users Over Time",
    y = "Users (millions)"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

years <- 2015:2024
users <- cbind(
  Mobile  = c(10, 15, 22, 35, 50, 72, 95, 120, 150, 180),
  Desktop = c(8, 12, 18, 25, 38, 55, 70, 88, 110, 135),
  Tablet  = c(5, 8, 14, 20, 30, 42, 58, 75, 95, 118)
)

matplot(years, users,
  type = "l", lwd = 2,
  col = c("steelblue", "coral", "forestgreen"),
  lty = 1,
  main = "Platform Users Over Time",
  xlab = "Year", ylab = "Users (millions)"
)
legend("topleft",
  legend = colnames(users),
  col = c("steelblue", "coral", "forestgreen"),
  lwd = 2
)
```

------------------------------------------------------------------------

## Box Plot

A box plot summarizes a distribution using its five-number summary:
minimum, first quartile (Q1), median (Q2), third quartile (Q3), and
maximum. Outliers appear as individual points.

#### ggplot2

``` r

p <- ggplot(iris, aes(x = Species, y = Sepal.Length)) +
  geom_boxplot(fill = "lightblue", alpha = 0.7) +
  labs(
    title = "Sepal Length by Iris Species",
    x = "Species",
    y = "Sepal Length (cm)"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

boxplot(Sepal.Length ~ Species,
  data = iris,
  col = "lightblue",
  main = "Sepal Length by Iris Species",
  xlab = "Species",
  ylab = "Sepal Length (cm)"
)
```

------------------------------------------------------------------------

## Violin Plot

A violin plot combines kernel density estimation (KDE) curves with
box-summary statistics, providing a richer view of the data distribution
than a box plot alone. MAIDR renders each violin as two navigable
layers: a **box** layer (min, Q1, median, Q3, max) and a **KDE** layer
(density curve).

> **Note:** Violin plots are a ggplot2-only feature.

``` r

p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_violin(fill = "lightblue", alpha = 0.7) +
  labs(
    title = "MPG Distribution by Cylinder Count",
    x = "Cylinders",
    y = "Miles per Gallon"
  ) +
  theme_minimal()

p
```

------------------------------------------------------------------------

## Step Plot

A step plot suits a value that is **piecewise constant**: it is held
across an interval and then jumps, rather than drifting between samples
the way a line implies. The canonical case is a **hypnogram** — the
sleep stage a sleep study scores for each epoch of the night.

MAIDR reports the layer’s step convention (`hv`, `vh`, or `mid`) so the
description says where the value jumps, and offers a **Transitions**
rotor mode that moves between the moments the level changes rather than
sample by sample.

When the y aesthetic is an ordinal factor, the level *name* is announced
(“REM”, “N2”, “Awake”) while the numeric level still drives sonification
and braille — so the shape of the night is audible and the stage is
speakable.

#### ggplot2

``` r

hypnogram <- data.frame(
  hour = seq(0, 7.5, by = 0.5),
  stage = factor(
    c(
      "Awake", "N1", "N2", "N3", "N3", "N2", "REM", "N2",
      "N3", "N3", "N2", "REM", "N2", "N1", "REM", "Awake"
    ),
    levels = c("N3", "N2", "N1", "REM", "Awake")
  )
)

p <- ggplot(hypnogram, aes(x = hour, y = stage, group = 1)) +
  geom_step(direction = "hv", color = "steelblue", linewidth = 1) +
  scale_x_continuous(breaks = 0:8) +
  labs(
    title = "Overnight Hypnogram",
    x = "Hours after lights out",
    y = "Sleep stage"
  ) +
  theme_minimal()

p
```

`geom_step(direction = )` accepts `"hv"` (the default — hold, then jump
at the next x), `"vh"` (jump at the current x, then hold), and `"mid"`
(jump midway between x values). All three are passed through to MAIDR
unchanged.

#### Base R

`plot(type = "s")` draws the horizontal segment first, matching `"hv"`;
`plot(type = "S")` draws the vertical segment first, matching `"vh"`.

``` r

hours <- seq(0, 7.5, by = 0.5)
stage_names <- c("N3", "N2", "N1", "REM", "Awake")
stage <- c(
  5, 3, 2, 1, 1, 2, 4, 2,
  1, 1, 2, 4, 2, 3, 4, 5
)

plot(hours, stage,
  type = "s", col = "steelblue", lwd = 2,
  main = "Overnight Hypnogram",
  xlab = "Hours after lights out", ylab = "Sleep stage",
  yaxt = "n"
)
axis(2, at = seq_along(stage_names), labels = stage_names, las = 1)
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

------------------------------------------------------------------------

## Heat Map

A heatmap uses color intensity to represent values in a two-dimensional
matrix. It is useful for spotting patterns, clusters, and outliers
across two categorical dimensions.

#### ggplot2

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

#### Base R

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

## KDE (Kernel Density Estimation) Plots

A density curve shows the estimated probability distribution of a
continuous variable. It provides a smooth alternative to histograms for
understanding the shape of data.

#### ggplot2

``` r

density_values <- data.frame(value = c(
  rnorm(400, mean = 25, sd = 5),
  rnorm(600, mean = 40, sd = 8)
))

p <- ggplot(density_values, aes(x = value)) +
  geom_density(fill = "lightblue", alpha = 0.5, color = "steelblue") +
  labs(
    title = "Age Distribution of Survey Respondents",
    x = "Age",
    y = "Density"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

ages <- c(rnorm(400, mean = 25, sd = 5), rnorm(600, mean = 40, sd = 8))
d <- density(ages)
plot(d,
  col = "steelblue", lwd = 2,
  main = "Age Distribution of Survey Respondents",
  xlab = "Age",
  ylab = "Density"
)
polygon(d, col = rgb(0.678, 0.847, 0.902, 0.5), border = "steelblue")
```

![Plot](data:image/png;base64,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)

------------------------------------------------------------------------

## Regression Plots

A scatter plot with a fitted regression line shows the relationship
between two variables along with the best-fit model.

#### ggplot2

``` r

p <- ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point(color = "steelblue", size = 3) +
  geom_smooth(method = "lm", color = "red", se = TRUE) +
  labs(
    title = "Weight vs MPG with Linear Fit",
    x = "Weight (1000 lbs)",
    y = "Miles per Gallon"
  ) +
  theme_minimal()

p
```

#### Base R

``` r

plot(mtcars$wt, mtcars$mpg,
  pch = 19, col = "steelblue",
  main = "Weight vs MPG with Linear Fit",
  xlab = "Weight (1000 lbs)", ylab = "Miles per Gallon"
)
abline(lm(mpg ~ wt, data = mtcars), col = "red", lwd = 2)
```

------------------------------------------------------------------------

## Multi-Layered Plots

Multi-layered plots combine multiple visualization types in a single
chart. For example, a histogram overlaid with a density curve, or a bar
chart with a line overlay.

### Histogram with Density Overlay

#### ggplot2

``` r

p <- ggplot(mtcars, aes(x = mpg)) +
  geom_histogram(
    aes(y = after_stat(density)),
    bins = 15, fill = "lightblue", color = "white"
  ) +
  geom_density(color = "red", linewidth = 1.2) +
  labs(title = "MPG: Histogram with Density Curve") +
  theme_minimal()

p
```

#### Base R

``` r

hist(mtcars$mpg,
  breaks = 15, freq = FALSE,
  col = "lightblue", border = "white",
  main = "MPG: Histogram with Density Curve",
  xlab = "Miles per Gallon",
  ylab = "Density"
)
lines(density(mtcars$mpg), col = "red", lwd = 2)
```

### Bar Chart with Line Overlay

#### ggplot2

``` r

combo_data <- data.frame(
  month = factor(month.abb[1:6], levels = month.abb[1:6]),
  sales = c(100, 120, 90, 150, 130, 160),
  target = c(110, 110, 110, 140, 140, 140)
)

p <- ggplot(combo_data, aes(x = month)) +
  geom_bar(aes(y = sales), stat = "identity", fill = "steelblue", alpha = 0.7) +
  geom_line(aes(y = target, group = 1), color = "red", linewidth = 1.5) +
  labs(title = "Monthly Sales vs Target", y = "Value") +
  theme_minimal()

p
```

------------------------------------------------------------------------

## Multi-Panel Plots (Multiple Subplots)

Multi-panel layouts arrange several independent plots in a grid. This is
useful for dashboards or comparing different views of the same dataset.

#### ggplot2 (patchwork)

``` r

library(patchwork)

# Line plot with currency formatting
line_df <- data.frame(
  Month = 1:8,
  Revenue = c(2500, 4200, 3100, 5500, 4300, 6700, 5600, 7800)
)
pw_line <- ggplot(line_df, aes(Month, Revenue)) +
  geom_line(color = "steelblue", linewidth = 1) +
  labs(title = "Monthly Revenue", x = "Month", y = "Revenue") +
  theme_minimal()

# Bar plot with rates
bar_df1 <- data.frame(
  Category = c("A", "B", "C", "D", "E"),
  Rate = c(0.15, 0.22, 0.18, 0.28, 0.17)
)
pw_bar1 <- ggplot(bar_df1, aes(Category, Rate)) +
  geom_bar(stat = "identity", fill = "forestgreen", alpha = 0.7) +
  labs(title = "Conversion Rates", x = "Category", y = "Rate") +
  theme_minimal()

# Bar plot with large numbers
bar_df2 <- data.frame(
  Category = c("A", "B", "C", "D", "E"),
  Count = c(125000, 98000, 145000, 112000, 88000)
)
pw_bar2 <- ggplot(bar_df2, aes(Category, Count)) +
  geom_bar(stat = "identity", fill = "royalblue", alpha = 0.7) +
  labs(title = "User Counts", x = "Category", y = "Count") +
  theme_minimal()

# Line plot with exponential growth
line_df2 <- data.frame(
  x = 1:8,
  y = 10^(seq(3, 6.5, length.out = 8))
)
pw_line2 <- ggplot(line_df2, aes(x, y)) +
  geom_line(color = "tomato", linewidth = 1) +
  labs(title = "Exponential Growth", x = "Time", y = "Value") +
  theme_minimal()

combined <- (pw_line + pw_bar1 + pw_bar2 + pw_line2) +
  plot_layout(ncol = 2)
combined
```

#### Base R (par)

``` r

par(mfrow = c(2, 2))

barplot(table(mtcars$cyl),
  col = "steelblue",
  main = "Cars by Cylinder Count",
  xlab = "Cylinders"
)

hist(mtcars$mpg,
  breaks = 12, col = "coral", border = "white",
  main = "MPG Distribution", xlab = "MPG"
)

plot(mtcars$wt, mtcars$mpg,
  pch = 19, col = "forestgreen",
  main = "MPG vs Weight",
  xlab = "Weight (1000 lbs)", ylab = "MPG"
)

boxplot(hp ~ gear,
  data = mtcars, col = "plum",
  main = "Horsepower by Gear Count",
  xlab = "Gears", ylab = "Horsepower"
)
```

``` r

invisible(par(mfrow = c(1, 1)))
```

------------------------------------------------------------------------

## Facet Plots

Faceted plots split data into a grid of subplots by one or more grouping
variables. Each panel shows the same type of chart for a different
subset of the data. This is a ggplot2-only feature using
[`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
or
[`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html).

### facet_wrap

``` r

facet_data <- data.frame(
  x = rep(c("A", "B", "C", "D"), 4),
  y = c(
    30, 25, 35, 20,
    45, 30, 25, 40,
    20, 35, 30, 45,
    35, 40, 20, 30
  ),
  panel = rep(c("Group 1", "Group 2", "Group 3", "Group 4"), each = 4)
)

p <- ggplot(facet_data, aes(x = x, y = y)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  facet_wrap(~panel, ncol = 2) +
  labs(title = "Sales by Category Across Groups", x = "Category", y = "Sales") +
  theme_minimal()

p
```

### facet_grid

``` r

p <- ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point(size = 2, color = "steelblue") +
  facet_grid(vs ~ am,
    labeller = labeller(
      vs = c("0" = "V-engine", "1" = "Straight"),
      am = c("0" = "Automatic", "1" = "Manual")
    )
  ) +
  labs(
    title = "MPG vs Weight by Engine Type and Transmission",
    x = "Weight (1000 lbs)",
    y = "Miles per Gallon"
  ) +
  theme_minimal()

p
```

------------------------------------------------------------------------

## Experimental Base R Charts

Base R draws a long tail of statistical charts that have no ggplot2
equivalent maidr reads — a correlogram, a periodogram, a biplot, a star
plot. maidr reads each of them by mapping it onto a layer type it
already knows, so a chart drawn for the eye becomes a series a reader
can walk.

> **Experimental.** Every layer type in this section is one of the
> experimental types. None has been through a user study, and each may
> change without a deprecation period. See the experimental table in the
> README.

> **Note:** Everything below is Base R, so no `#### ggplot2` counterpart
> is shown. Each section names the reading its chart gets, because the
> mapping is not always the one the chart’s name suggests — a
> correlogram is read as a lollipop, a conditional density plot as a
> 100% stacked area.

### Correlogram

[`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md) draw a spike
per lag, and maidr reads each as a **lollipop**: one term per lag,
carrying the correlation at that lag. The axes come from the function
itself, so the reading says `Lag` against `ACF`, `Partial ACF` or `CCF`
without being told.

[`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md) starts at lag
0, whose autocorrelation is always exactly 1, so the first term of an
ACF is a constant rather than a measurement.
[`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md) has no lag 0
and starts at lag 1.

``` r

acf(lh, lag.max = 5, main = "Luteinizing hormone: autocorrelation")
```

``` r

pacf(lh, lag.max = 5, main = "Luteinizing hormone: partial autocorrelation")
```

[`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md) correlates
two series across negative and positive lags, so its terms are signed
and the sign says which series leads.

``` r

ccf(mdeaths, fdeaths, lag.max = 4, main = "Male vs female deaths")
```

### Spectral Density

[`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md)
estimates how a series’ variance is distributed across frequencies.
maidr reads the periodogram as a **line** of `spectrum` against
`frequency`.

``` r

spectrum(lh, main = "Luteinizing hormone: spectral density")
```

### Cumulative Periodogram

[`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws the
cumulative periodogram against its confidence band. The cumulative curve
is read as a **step**; the band is drawing rather than data, and is not
announced.

> **Note:**
> [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md) labels
> only its x axis, so the reading carries `frequency` and no y label. It
> takes no `ylab` argument to supply one.

``` r

cpgram(lh, main = "Luteinizing hormone: cumulative periodogram")
```

### Seasonal Subseries

[`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) breaks
a seasonal series into one segment per cycle position, so every January
sits together and the seasonal shape is read directly. maidr reads it as
a **line**.

> **Note:**
> [`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has
> no default for `xlab` – the axis it writes carries the cycle labels,
> not a quantity – so x is named only when the call names it. Left out,
> y falls back to the series name — `nottem` here.

``` r

monthplot(
  nottem,
  xlab = "Month", ylab = "Temperature (F)",
  main = "Nottingham temperatures by month"
)
```

### Lag Plot

[`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) plots a
series against itself shifted by *k*, which is how serial dependence is
read by eye. maidr reads it as a **point** layer whose x axis is named
for the shift — `lag 1` against the series.

``` r

lag.plot(lh, lags = 1, main = "Luteinizing hormone against its own lag")
```

### Partial Effects

[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
each term’s fitted contribution against its own predictor, holding the
rest fixed. maidr reads each panel as a **line**, labelled
`partial for <term>` so the reading says it is a contribution rather
than a fitted value.

``` r

termplot(lm(mpg ~ wt, data = mtcars), main = "Partial effect of weight")
```

### Biplot

[`biplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) puts
observations and variable loadings on one pair of principal component
axes. maidr reads the observations as a **point** layer on `PC1` and
`PC2`, and each point carries its own row name, so a reader hears which
observation they are on rather than a bare coordinate pair.

``` r

biplot(prcomp(USArrests, scale. = TRUE), main = "US arrests: PC1 vs PC2")
```

### Radar

[`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws one
star per row, with a ray per variable. maidr reads it as a **radar**:
one series per observation, each carrying a value per variable.

> **Note:** A star plot has no x and y axes to name, so the reading
> carries no axis labels — the variable names come through as the rays
> themselves.

``` r

stars(mtcars[1:5, 1:4], main = "Five cars over four measures")
```

### Interaction Plot

[`interaction.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
draws a line per level of the trace factor, so a non-parallel pair is
the interaction. maidr reads one **line** per level and puts
`trace.label` on the z axis, which is what names the two series apart.

``` r

interaction.plot(ToothGrowth$dose, ToothGrowth$supp, ToothGrowth$len,
  xlab = "Dose (mg/day)", ylab = "Mean tooth length", trace.label = "Supplement"
)
```

### Box Plot from Summary Statistics

[`bxp()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws a box
plot from statistics already computed, rather than from raw data — which
is exactly what `boxplot(plot = FALSE)` hands back. maidr reads it as a
**box**, the same reading
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) gets, so
a pre-summarised box is not a second-class one.

``` r

bxp(boxplot(count ~ spray, data = InsectSprays, plot = FALSE),
  main = "Insect counts by spray"
)
```

### Strip Chart

[`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) is the
one-dimensional scatter you reach for when a box plot would hide too few
points. maidr reads **one point layer per group**, so the groups are
navigated as separate series rather than flattened together.

``` r

stripchart(count ~ spray,
  data = InsectSprays, method = "jitter",
  xlab = "Count", ylab = "Spray"
)
```

### Dot Chart

[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
Cleveland’s alternative to a bar chart for labelled values. maidr reads
it as a **dot** layer.

``` r

dotchart(VADeaths[, "Rural Male"],
  xlab = "Deaths per 1000", ylab = "Age group",
  main = "Virginia death rates, rural males"
)
```

### Lollipop

`plot(type = "h")` draws a vertical spike down to each value. maidr
reads it as a **lollipop**, the same type the correlogram uses.

``` r

plot(1:8, c(2, 5, 3, 9, 4, 7, 6, 8),
  type = "h", xlab = "Index", ylab = "Value", main = "Spikes"
)
```

### Mosaic and Spine Plots

Both tile a contingency table so that area is proportion, and maidr
reads both as a **mosaic**: the y axis is `Proportion`, and the second
factor is named on z.
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes
a two-way table.

``` r

mosaicplot(HairEyeColor[, , "Male"], main = "Hair and eye colour, males")
```

[`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes a
factor response against one predictor, which makes it the two-column
case of the same reading.

``` r

spineplot(factor(am) ~ wt, data = mtcars, xlab = "Weight", ylab = "Transmission")
```

### Conditional Density

[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is the
continuous-predictor counterpart to a spine plot: it draws how the
conditional distribution of a factor shifts along a numeric axis. maidr
reads it as a **100% stacked area**, since every vertical slice sums to
one.

``` r

cdplot(factor(am) ~ mpg, data = mtcars, xlab = "Miles per gallon")
```

### Association Plot

[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) states
one signed Pearson residual per cell of a contingency table — how far
that cell sits from independence. maidr reads it as a **heat**: a named
grid navigated row then column, with the residual on z, so the sign and
size of each departure are read out per cell.

``` r

assocplot(HairEyeColor[, , "Male"], main = "Hair and eye colour: residuals")
```

### Filled Contour

[`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
shades the bands between contour lines. maidr reads the **contour**
levels themselves, so a reader walks the level curves rather than the
shading.

> **Note:** Passing `x` and `y` is worth doing here. Given only `z`,
> [`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
> positions the grid on 0–1 and the reading has no axis labels at all;
> given real coordinates it announces them in their own units.

``` r

filled.contour(
  x = 10 * (1:nrow(volcano)), y = 10 * (1:ncol(volcano)), z = volcano,
  xlab = "Easting (m)", ylab = "Northing (m)", main = "Maunga Whau"
)
```

### Q-Q Plot

[`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) plots
sample quantiles against theoretical ones, and
[`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) adds the
reference line through the quartiles. Both are read — the points as a
**point** layer and the reference as a **line** — so the line a sighted
reader compares against is navigable rather than decoration.

``` r

z <- rnorm(50)
qqnorm(z, main = "Normal Q-Q plot")
qqline(z)
```

### 100% Stacked Bar

A [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
proportion table draws columns that each sum to one. maidr reads it as a
**100% stacked bar**, so a segment is announced as its share rather than
as a raw count.

``` r

barplot(prop.table(table(mtcars$cyl, mtcars$gear), 2),
  xlab = "Gears", ylab = "Proportion", legend.text = TRUE
)
```
