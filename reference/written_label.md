# The text an argument was written as, when a symbol can carry it

[`deparse1()`](https://rdrr.io/r/base/deparse.html), as nearly every
Base R chart deparses its arguments. NA for a constant, whose value
deparses to what was written anyway; for text longer than R allows a
symbol's name (10,000 bytes); and for `...` and `..1`, which R reads as
the dots of the frame they are evaluated in.

## Usage

``` r
written_label(expr)
```

## Arguments

- expr:

  The expression an argument was written as

## Value

A string, or NA
