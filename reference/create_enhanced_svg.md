# Create enhanced SVG with maidr data

The chart is drawn on an svglite page of the size
[`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)
gives, at 72 pixels to the inch: the SVG's `width`, `height` and
`viewBox` are that size.

## Usage

``` r
create_enhanced_svg(gt, maidr_data, width = NULL, height = NULL)
```

## Arguments

- gt:

  A gtable object

- maidr_data:

  The maidr-data structure

- width, height:

  The size to draw the chart at, in inches, or `NULL` for maidr's own. A
  chart with a candlestick layer is drawn at least 12 x 6 in, which
  keeps quantmod
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s
  title, its bracketed date range and its date labels inside the SVG
  (quantmod issue \#129).

## Value

Character vector of SVG content
