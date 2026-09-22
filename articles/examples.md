# Examples

Making accessible data representation with **maidr** is easy and
straightforward. If you already have data visualization code using
**ggplot2** or **Base R**, you can make your plots accessible with maidr
in just a few lines of code.

In an R Markdown or Quarto document, load the maidr package and call
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) once in a setup
chunk, as every page here does; from then on each plot the document
prints comes out as an accessible chart. At the console
[`library(maidr)`](https://github.com/xability/r-maidr) alone is enough
(see “How maidr hooks into your session” in the [getting-started
vignette](https://r.maidr.ai/articles/getting-started.md)). You can then
explore each chart with the keyboard shortcuts below.

| Key | Action |
|----|----|
| **Tab** | Focus the chart; **Shift + Tab** leaves it |
| **Left / Right** | Move between data points |
| **Up / Down** | Move between series, stacked segments, heat map rows or box plot sections, on a chart that has them |
| **Page Up / Page Down** | Switch between the layers of a chart that has several |
| **B** | Toggle braille mode |
| **T** | Toggle text mode |
| **S** | Toggle sonification |
| **R** | Toggle review mode |
| **C** | Toggle high contrast mode |
| **L**, then **X**, **Y** or **T** | Announce the x axis label, the y axis label or the title |
| **Space** | Repeat the current sound |
| **Ctrl + /** (**Cmd + /** on macOS) | Show or hide the full keyboard shortcut help |

Every other shortcut, including autoplay, jumping to the ends, the
command palette, settings and the AI chat, is on the [MAIDR controls
reference](https://maidr.ai/docs/CONTROLS.html).

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

## Examples by plot family

Each family page renders every example interactively, so you can explore
the charts with the keyboard shortcuts above. The stable and
experimental labels follow “Supported plot types” in the README.

- [Bar, Pie and Word Cloud
  Examples](https://r.maidr.ai/articles/examples-bar-pie.md): simple,
  dodged and stacked bar charts, pie charts, and the experimental word
  cloud.
- [Histogram, Density, Box and Violin
  Examples](https://r.maidr.ai/articles/examples-distribution.md): the
  distribution family, including kernel density curves and violin plots.
- [Scatter, Line, Step and Regression
  Examples](https://r.maidr.ai/articles/examples-scatter-line.md): x-y
  plots, single and multi-line charts, hypnogram step plots and fitted
  regression lines.
- [Heat Map and Candlestick
  Examples](https://r.maidr.ai/articles/examples-heatmap-candlestick.md):
  matrix heat maps and OHLC candlestick charts, with the candlestick
  support matrix for ggplot2 and Base R.
- [Multi-Layered, Multi-Panel and Facet
  Examples](https://r.maidr.ai/articles/examples-multi.md): layered
  geoms, patchwork and `par(mfrow)` layouts,
  [`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
  and
  [`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html).
- [Base R Time-Series and Diagnostic
  Examples](https://r.maidr.ai/articles/examples-base-r-timeseries.md):
  correlograms, spectral density, cumulative periodograms, seasonal
  subseries, lag plots, partial effects and Q-Q plots (experimental).
- [Experimental Base R Chart
  Examples](https://r.maidr.ai/articles/examples-base-r-experimental.md):
  biplots, radar charts, interaction plots, summary box plots, strip and
  dot charts, lollipops, mosaic and spine plots, conditional density,
  association plots, filled contours and 100% stacked bars
  (experimental).

Every example is also runnable locally:
[`run_example()`](https://r.maidr.ai/reference/run_example.md) lists the
scripts shipped with the package.
