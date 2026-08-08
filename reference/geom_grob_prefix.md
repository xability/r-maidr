# Grob-name prefix ggplot2 gives a geom's layer grob

ggplot2 names a layer's grob after the snake-cased class of its geom, so
`GeomSmooth` draws `geom_smooth.gTree.<n>` and `GeomDensity` draws
`geom_density.gTree.<n>`.

## Usage

``` r
geom_grob_prefix(geom)
```

## Arguments

- geom:

  A ggproto Geom object

## Value

Character scalar prefix
