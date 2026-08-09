# Document-level implementation of [`inject_candlestick_open_close()`](https://r.maidr.ai/reference/inject_candlestick_open_close.md)

Mutates `svg_doc` in place (xml2 documents are references).

## Usage

``` r
inject_candlestick_open_close_doc(svg_doc, maidr_data)
```

## Arguments

- svg_doc:

  Parsed SVG document (xml2)

- maidr_data:

  The maidr-data structure

## Value

TRUE if the document was modified
