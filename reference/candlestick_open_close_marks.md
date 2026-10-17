# The invisible open and close lines of a candlestick layer

One pair per candle rect, at the rect's open and close edges: in the
flipped local space the export draws in, a smaller raw y is a lower data
value. A Bull candle (close \> open) opens at its lower edge `y` and
closes at `y + h`, a Bear one the other way round, and a neutral one
(open == close) has both at `y`. A rect whose geometry does not read as
numbers gets none.

## Usage

``` r
candlestick_open_close_marks(x, y, width, height, layer, rect_index)
```

## Arguments

- x, y, width, height:

  The rects' attributes, as strings.

- layer:

  The candlestick layer, whose `data[[i]]$trend` is read.

- rect_index:

  The index naming the layer's groups and lines.

## Value

A list of `opens` and `closes`, each a list of the lines' attributes as
named character vectors.

## Details

Shared by the xml2 path and the one under webR
([`finish_svg_markup()`](https://r.maidr.ai/reference/finish_svg_markup.md)),
so the two write the same lines.
