# Is quantmod attached ahead of maidr on the search path?

[`library(quantmod)`](https://www.quantmod.com/) after
[`library(maidr)`](https://github.com/xability/r-maidr) puts
`package:quantmod` in front of `package:maidr`, so an unqualified
[`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md) binds
to quantmod's own function and maidr's recording wrapper is never
entered.

## Usage

``` r
quantmod_masks_maidr()
```

## Value

`TRUE` when both packages are attached and quantmod comes first.

## Details

maidr deliberately does not reach into quantmod's namespace to win this
race: overwriting a foreign package's binding would also redirect
quantmod's *internal*
[`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls
through maidr's `...`- forwarding wrapper, which corrupts the
`match.call(expand.dots = TRUE)` that quantmod relies on. maidr reports
the condition instead.
