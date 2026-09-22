# Is quantmod attached ahead of maidr on the search path?

[`package_masks_maidr()`](https://r.maidr.ai/reference/package_masks_maidr.md)
for quantmod, the first package this was noticed with (#97).

## Usage

``` r
quantmod_masks_maidr()
```

## Value

`TRUE` when both packages are attached and quantmod comes first.
