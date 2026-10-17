# Post-process the exported SVG and add the maidr-data attribute

Under webR, libxml2 may be systemfonts' copy, which aborts the wasm when
xml2 parses with it (#388), so the SVG is finished there without it, to
the same bytes: see
[`finish_svg_markup()`](https://r.maidr.ai/reference/finish_svg_markup.md).
Everywhere else xml2 does it, in
[`finish_svg_xml2()`](https://r.maidr.ai/reference/finish_svg_xml2.md).

## Usage

``` r
finish_svg(svg_content, maidr_data, candlestick = FALSE)
```

## Arguments

- svg_content:

  Character vector of SVG lines, as exported

- maidr_data:

  The maidr-data structure

- candlestick:

  Whether the chart has a candlestick layer

## Value

Character vector of SVG lines
