# Build a single AxisConfig

Drops the fields that are absent, so an axis only carries what its
caller could establish. Returns a named empty list when nothing could
be: passed to \[build_axes()\], that drops the axis key entirely.

## Usage

``` r
build_axis_config(label = NULL, min = NULL, max = NULL, tickStep = NULL)
```

## Arguments

- label:

  Axis label, or NULL

- min:

  Axis minimum, or NULL

- max:

  Axis maximum, or NULL

- tickStep:

  Distance between ticks, or NULL

## Value

A named list (AxisConfig), possibly empty
