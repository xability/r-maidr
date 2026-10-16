# Measure positions pheatmap gives in units of its legend's height

`pheatmap`'s legend places its colour bands and labels at
`h * p + (1npc - h)`, `h` being `min(1npc, 150bigpts)` and `p` a
position from 0 at the lowest break to 1 at the highest. Measured in a
viewport one inch high, `h` is one inch and each unit is `p` itself.

## Usage

``` r
pheatmap_legend_positions(units)
```

## Arguments

- units:

  A list of grid units

## Value

A list of numeric vectors, one per unit
