# Group a layer's segments into the lanes they were drawn in

Group a layer's segments into the lanes they were drawn in

## Usage

``` r
segment_lanes(built_data, lane_axis, lane_names = NULL)
```

## Arguments

- built_data:

  A layer's computed data, one row per drawn segment

- lane_axis:

  `"y"` or `"x"`, as
  [`segment_lane_axis()`](https://r.maidr.ai/reference/segment_lane_axis.md)
  returns

- lane_names:

  The lane names in drawn order, or NULL on a continuous lane axis.
  Position `i` on the axis is `lane_names[[i]]`

## Value

A list with `data` (lanes, each a list of `x`/`start`/`end` intervals),
`lanes` (the names of every lane in drawn order, or NULL) and `order`
(the built-data row behind each interval, in emission order)
