# Read a rectangle layer's bounds as the spans and lanes they draw

A declared
[`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md) layer
builds `xmin`, `xmax`, `ymin` and `ymax`, and none of the four columns
[`segment_lane_axis()`](https://r.maidr.ai/reference/segment_lane_axis.md)
is keyed on. Measured, today's processor fed a rect frame unchanged
answers `data lanes: 0 | lanes: NULL | selectors: 0` – a confident empty
schedule, which is a false claim of a different kind from the one \#197
is about. So the frame is renamed into the segment spelling here and
every landed function downstream runs unchanged.

## Usage

``` r
rect_gantt_frame(built_data, lane_axis = "y")
```

## Arguments

- built_data:

  A layer's computed data, carrying `xmin`, `xmax`, `ymin` and `ymax`,
  one row per drawn rectangle

- lane_axis:

  `"y"` when the lanes run up y and the spans along x, `"x"` for the
  mirror image, as the author declared it

## Value

The frame with `x`, `xend`, `y` and `yend` added, or NULL when it is not
a rectangle layer's frame

## Details

The lane is the band's midpoint rather than either edge, so a lane sits
where a reader sees it and a band drawn upside down (`ymin > ymax`)
lands in the same place. The span keeps both bounds;
[`segment_lanes()`](https://r.maidr.ai/reference/segment_lanes.md)
already sorts a span written backwards.

Measured on the repository's own four-interval schedule
(`ymin = 0.6, 1.6, 2.6, 1.6`), the normalised frame gives
`segment_lane_axis() = "y"`, lane sizes `1, 2, 1` and emission order
`1, 2, 4, 3`; the processed layer's `data`, `lanes`, `orientation` and
`axes` come back [`identical()`](https://rdrr.io/r/base/identical.html)
to the
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
spelling of the same schedule, and only the grob the selectors name
differs.

The degenerate guard falls out of the renaming rather than being a rule:
rectangles of zero width normalise to level on both axes, which
[`segment_lane_axis()`](https://r.maidr.ai/reference/segment_lane_axis.md)
already refuses.
