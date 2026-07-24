# Strip the right y-axis vertical line from chartSeries candlestick SVG

quantmod::chartSeries() draws a right-hand y-axis with a vertical axis
line, tick marks, and numeric price labels (e.g. 101..106). On sparse
OHLC inputs (few candles spread across the plot region), the right-axis
vertical line is positioned within the candle area and visually overlaps
the rightmost candle, reading like a stray "axis through the middle" of
the chart. This helper removes only the \`right-axis-line-\*\` polyline;
the tick marks and the price labels themselves are preserved so the
chart still communicates the y-axis scale visually.

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
\`svg_content\` unchanged.

## Details

The matched group has an ID of the form
\`graphics-plot-N-right-axis-line-...\`; matched by substring with
\`contains(@id, 'right-axis-line-')\`.

Safety: no-op when \`maidr_data\` contains no candlestick layers (ggplot
candlestick / non-candlestick plots use different SVG IDs and are
unaffected), when xml2 is unavailable, when SVG parsing fails, or when
no matching groups are found.
