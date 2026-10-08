# A path geom for precision-recall curves that admits a `threshold` aesthetic

[`ggplot2::GeomPath`](https://ggplot2.tidyverse.org/reference/Geom.html)
with one optional aesthetic added, so that a `threshold` mapped to a
[`maidr_pr_curve()`](https://r.maidr.ai/reference/maidr_pr_curve.md)
layer survives
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
as a column of the built data. Nothing about the drawing changes; the
aesthetic reaches no grob.

## Usage

``` r
GeomPrCurve
```

## Format

A ggproto object inheriting from
[`ggplot2::GeomPath`](https://ggplot2.tidyverse.org/reference/Geom.html)
