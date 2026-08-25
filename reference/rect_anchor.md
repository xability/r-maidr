# Where a rect grob is anchored on one axis, as a fraction

A `rectGrob()` keeps its justification in `just` and leaves `hjust` /
`vjust` NULL unless the caller wrote them, so neither field alone
answers the question. `just` may be a keyword, a number, or a length-two
vector of either; absent, `grid`'s own default is `"centre"`.

## Usage

``` r
rect_anchor(grob, axis)
```

## Arguments

- grob:

  A rect grob

- axis:

  `"horizontal"` or `"vertical"`

## Value

The anchor as a fraction: 0 is the low edge, 1 the high one

## Details

Anything unrecognised answers 0.5, the default – an anchor this cannot
read is one it should not move.
