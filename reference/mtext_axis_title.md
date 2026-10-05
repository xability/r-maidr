# The axis title an `mtext()` call writes, if it writes one

The axis title an
[`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
writes, if it writes one

## Usage

``` r
mtext_axis_title(args)
```

## Arguments

- args:

  The recorded arguments of the
  [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) call. Its
  `text`, the formal it is dispatched on, is left unnamed when written
  first, as
  [`match_recorded_args()`](https://r.maidr.ai/reference/match_recorded_args.md)
  leaves it.

## Value

List with the `axis` one string centred on a side titles, `"x"` on side
1 or 3 and `"y"` on side 2 or 4, that `side`, its `text`, and the `line`
of the margin it is written on; or NULL
