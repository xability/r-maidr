# Build a canonical axes object

Convenience constructor for a per-axis axes list. Drops NULL axes.

## Usage

``` r
build_axes(x = NULL, y = NULL, z = NULL)
```

## Arguments

- x:

  Label string or AxisConfig list for the x axis (or NULL)

- y:

  Label string or AxisConfig list for the y axis (or NULL)

- z:

  Label string or AxisConfig list for the z axis (or NULL)

## Value

A canonical axes list with only non-NULL axes set
