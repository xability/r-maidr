# Point geoms for volcano and Manhattan plots

[`ggplot2::GeomPoint`](https://ggplot2.tidyverse.org/reference/Geom.html)
with two optional aesthetics added, `label` and `region`, so that both
survive
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
as columns of the built data rather than being dropped with
`Ignoring unknown aesthetics`. Nothing about the drawing changes;
neither aesthetic reaches a grob.

## Usage

``` r
GeomVolcano

GeomManhattan
```

## Format

ggproto objects inheriting from
[`ggplot2::GeomPoint`](https://ggplot2.tidyverse.org/reference/Geom.html)
