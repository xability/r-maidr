# Every auto-named polyline inside a grob, in draw order

Scoped to the grob handed in, so a caller that has already established
which tree belongs to its layer cannot pick up a sibling layer's curve.

## Usage

``` r
polylines_within(grob)
```

## Arguments

- grob:

  A grob to walk.

## Value

List of polyline grobs, in the order they are drawn.
