# One group's rows as the `"hv"` staircase a survival curve is drawn as

The estimate holds from each time to the next and drops there, so the
`n` rows become `2n - 1` vertices: ggplot2's own `"hv"` stairstep, every
column but `y` taken from the row the vertex's x belongs to.

## Usage

``` r
survival_stairstep(rows, y = "y")
```

## Arguments

- rows:

  One group's rows, sorted by x

- y:

  The column the staircase holds level, `"y"` unless a band edge

## Value

The staircase's rows
