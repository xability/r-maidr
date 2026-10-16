# A layer whose `censored` aesthetic does not split its curves

ggplot2 groups a layer's rows by every discrete aesthetic, and a logical
is discrete: `aes(censored = status == 0)` would cut each curve in two,
its censored rows one curve and the rest another. The layer's aesthetics
are computed as ggplot2 computes them, and then, unless `group` is
mapped, grouped again without `censored`, which is made a number (1 for
a censored time) so nothing further groups by it.

## Usage

``` r
survival_censoring_ungrouped(layer)
```

## Arguments

- layer:

  A layer drawn with `GeomSurvival`

## Value

A child of the layer that groups so
