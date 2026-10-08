# Whether the bundled maidr.js can build a `directed_graph` trace

The `directed_graph` trace first shipped in maidr.js 4.14.0. A ggraph
chart was not read at all before, so without the trace it stays unread.

## Usage

``` r
directed_graph_trace_available()
```

## Value

TRUE when the pinned bundle carries the trace
