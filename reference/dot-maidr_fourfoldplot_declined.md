# fourfoldplot() Decline Advisory State

Environment holding the decline reasons already explained in this
session, so the advisory below is not repeated for every call.

## Usage

``` r
.maidr_fourfoldplot_declined
```

## Details

A character vector rather than the single flag
`.maidr_chartseries_ta_warned` carries, because
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
declines for three different reasons and a session that draws a
default-`std` chart and then a 2x2xk one should hear both explanations
rather than only the first.
