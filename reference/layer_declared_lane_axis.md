# Which axis a declared schedule runs its lanes up

`maidr_gantt(lane_axis = )` is an argument rather than an inference, and
this reads it back. `"y"` when the author said nothing, which is the
ordinary horizontal schedule: lanes stacked up y, spans running along x.
Also `"y"` when only the constructor survived – the lane axis cannot be
recovered from a call whose argument may be a variable – which matches
the default the author most likely took.

## Usage

``` r
layer_declared_lane_axis(layer)
```

## Arguments

- layer:

  A ggplot2 layer object

## Value

`"y"` or `"x"`
