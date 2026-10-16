# A step geom for Kaplan-Meier curves

[`ggplot2::GeomStep`](https://ggplot2.tidyverse.org/reference/Geom.html)
drawn `"hv"`, as a survival estimate is held until the next event, with
three optional aesthetics – `ymin`, `ymax` and `censored` – and, from
them, the confidence band beneath the curve and a mark at each censored
time. The band, the curve and the marks are one grob tree named
`geom_survival`, the curve a bare polyline inside it with one line per
group.

## Usage

``` r
GeomSurvival
```

## Format

A ggproto object inheriting from
[`ggplot2::GeomStep`](https://ggplot2.tidyverse.org/reference/Geom.html)
