# Which axis a layer's segments lay their lanes on

A segment whose two ends share a coordinate is a **span** along the
other axis, at one position on this one – an interval in a lane, which
is a gantt. A segment whose ends share nothing is an edge in a node-link
diagram: it has no lane to sit in and no interval to announce.

## Usage

``` r
segment_lane_axis(built_data)
```

## Arguments

- built_data:

  A layer's computed data, carrying `x`, `xend`, `y` and `yend`, one row
  per drawn segment

## Value

`"y"` when the lanes run up the y axis and the spans along x, `"x"` for
the mirror image, or `NULL` when the layer is not a gantt

## Details

The question is asked of the **whole layer** rather than of each row,
which is the rule xability/maidr#1100 settled for the same reading in
the Observable adapter. One
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
call can hold spans and edges together, and reading three spans out of
four segments would announce a gantt quietly missing a quarter of its
chart.

A layer whose segments are level on *both* axes is every span reduced to
a point. That is not a schedule with milestones in it – a milestone sits
in a lane beside intervals that have length – so it is refused rather
than announced as a chart of zero-length work.
