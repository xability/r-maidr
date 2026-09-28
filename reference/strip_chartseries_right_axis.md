# Strip the right y-axis line and ticks from chartSeries candlestick SVG

quantmod::chartSeries() draws a right-hand y-axis (`axis(4)`) with a
vertical axis line, tick marks, and numeric price labels (e.g.
101..106). In the tree
[`gridGraphics::grid.echo()`](https://rdrr.io/pkg/gridGraphics/man/grid.echo.html)
rebuilds from it, the line and the ticks land inside the plot region,
well left of its right border, reading like a stray "axis through the
middle" of the chart, while the labels stay where R draws them. This
helper removes the `right-axis-line-*` and `right-axis-ticks-*` groups;
the price labels are preserved so the chart still communicates the
y-axis scale visually.

## Usage

``` r
strip_chartseries_right_axis(svg_content, maidr_data)
```

## Arguments

- svg_content:

  Character vector of SVG lines

- maidr_data:

  The maidr-data structure (read-only; used to detect candlestick
  layers)

## Value

Modified SVG content (character vector). If any guard fails, returns
`svg_content` unchanged.

## Details

The matched groups have IDs of the form
`graphics-plot-N-right-axis-line-...` and
`graphics-plot-N-right-axis-ticks-...`, matched by substring.

Safety: no-op when `maidr_data` contains no candlestick layers (ggplot
candlestick / non-candlestick plots use different SVG IDs and are
unaffected), when xml2 is unavailable, when SVG parsing fails, or when
no matching groups are found.
