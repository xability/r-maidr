# The layer type of `plot()` of a ROCR `performance` object

Read (`"rocr_performance"`) only when ROCR draws one polyline per run
from the object's own values, which is what its plot method does unless
told otherwise. Declined (`"unknown"`, so the chart is shown as a
picture) when the drawing is something else:

## Usage

``` r
rocr_performance_layer_type(args)
```

## Arguments

- args:

  The recorded arguments of the
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call

## Value

`"rocr_performance"` or `"unknown"`

## Details

- `avg` other than `"none"` draws averaged curves and, with
  `spread.estimate`, error bars or boxes – values the object does not
  hold;

- `colorize = TRUE` draws each curve as one segment per pair of points,
  so there is no polyline per run to outline;

- `downsampling` draws a subset of the points;

- `add = TRUE` draws over an earlier plot, as `curve(add = TRUE)` does,
  and starts no plot of its own;

- a `type` other than `"l"` draws points or steps the line reading does
  not outline;

- a measure with no x values, such as `"auc"`, ROCR does not plot.
