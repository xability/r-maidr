# Finish the chart's SVG without libxml2

Does what
[`create_enhanced_svg()`](https://r.maidr.ai/reference/create_enhanced_svg.md)
does with xml2 once the chart is drawn: for a candlestick chart the open
and close marks, the chartSeries header and the stripped axes, then the
`maidr-data` attribute.

## Usage

``` r
finish_svg_markup(svg_content, maidr_data, candlestick = FALSE)
```

## Arguments

- svg_content:

  Character vector of SVG lines.

- maidr_data:

  The maidr-data structure.

- candlestick:

  Whether the chart has a candlestick layer.

## Value

The SVG lines, as the xml2 path writes them.
