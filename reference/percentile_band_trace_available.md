# Whether the bundled maidr.js can build a `percentile_band` trace

The `percentile_band` trace first shipped in maidr.js 4.14.0. Unlike the
ROC and PR curves there is no older reading to keep: a lineribbon was
not read at all before, so without the trace it stays unread.

## Usage

``` r
percentile_band_trace_available()
```

## Value

TRUE when the pinned bundle carries the trace
