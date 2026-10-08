# Whether the bundled maidr.js can build a `pr_curve` trace

The `pr_curve` trace first shipped in maidr.js 4.14.0. Emitted to an
older bundle it is fatal rather than declined, as
[`roc_trace_available()`](https://r.maidr.ai/reference/roc_trace_available.md)
explains for the ROC trace, so until `MAIDR_VERSION` reaches 4.14.0 a
precision-recall curve keeps the line reading it had.

## Usage

``` r
pr_curve_trace_available()
```

## Value

TRUE when the pinned bundle carries the trace
