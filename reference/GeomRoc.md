# A path geom that admits a `threshold` aesthetic

[`ggplot2::GeomPath`](https://ggplot2.tidyverse.org/reference/Geom.html)
with one optional aesthetic added, so that a `threshold` mapped to a
[`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) layer
survives
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
as a column of the built data rather than being dropped with
`Ignoring unknown aesthetics`. Nothing about the drawing changes; the
aesthetic reaches no grob.

## Usage

``` r
GeomRoc
```

## Format

A ggproto object inheriting from
[`ggplot2::GeomPath`](https://ggplot2.tidyverse.org/reference/Geom.html)
