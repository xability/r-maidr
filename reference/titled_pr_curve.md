# Whether a line layer is a precision-recall curve by its axis titles

A precision-recall curve drawn with Base R's
`plot(recall, precision, type = "l")` or lattice's
`xyplot(precision ~ recall, type = "l")` carries no evidence of what it
is except its axis titles, which both systems default to the names of
the variables drawn. Titled exactly `Recall` and `Precision` (any case,
surrounding space ignored), with every point a pair of numbers from 0 to
1, those titles are the claim, as the column names `recall` and
`precision` are for a ggplot2 line
([`layer_maps_pr_rates()`](https://r.maidr.ai/reference/layer_maps_pr_rates.md))
and the axis titles are in py-maidr; the layer is then the `pr_curve`
trace, whose data is the line's own shape. Nothing else is read as one,
and nothing is when the bundled maidr.js predates the trace
([`pr_curve_trace_available()`](https://r.maidr.ai/reference/pr_curve_trace_available.md)).

## Usage

``` r
titled_pr_curve(axes, data)
```

## Arguments

- axes:

  The layer's canonical axes list

- data:

  The layer's series: a list of lists of points with `x` and `y`

## Value

TRUE when the layer is a precision-recall curve by its titles
