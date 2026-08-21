# One curve grob per row of a vectorised one

Recycling is by position, which is grid's own rule for a gpar shorter
than the positions it styles, so a layer given one colour for four rows
keeps that colour on all four rather than losing three of them.

## Usage

``` r
split_one_curve(curve)
```

## Arguments

- curve:

  A `curve` grob

## Value

A gTree of one curve per row, or the grob itself when it has one row

## Details

A single-row curve is returned untouched: it already satisfies gridSVG,
and wrapping it would change the element id its selector is built from.
