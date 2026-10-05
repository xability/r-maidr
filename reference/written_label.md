# The text an argument was written as, when a symbol can carry it

[`deparse1()`](https://rdrr.io/r/base/deparse.html), as nearly every
Base R chart deparses its arguments. NA for a constant, whose value
deparses to what was written anyway, and for a text no symbol can carry
([`symbol_text()`](https://r.maidr.ai/reference/symbol_text.md)).

## Usage

``` r
written_label(expr)
```

## Arguments

- expr:

  The expression an argument was written as

## Value

A string, or NA
