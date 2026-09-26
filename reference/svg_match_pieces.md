# Which of an arrowed line's shapes are its pieces

The device writes each piece of a line and then that piece's arrow
heads, so pieces and heads interleave. A shape is the next expected
piece when it is a line with that piece's point count starting at its
first point (to svglite's two decimals); everything else is a head.

## Usage

``` r
svg_match_pieces(lines, pieces)
```

## Arguments

- lines:

  svglite lines for the element's shapes, in order.

- pieces:

  Data frame of expected pieces (`n`, `x0`, `y0`).

## Value

Logical vector: the shape is a piece.
