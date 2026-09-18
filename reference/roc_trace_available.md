# Whether the bundled maidr.js can build a `roc` trace

The `roc` trace first shipped in maidr.js 4.9.0. Emitted to an older
bundle it is not declined but *fatal*: the core's factory throws on a
trace type it does not know, so the page renders nothing (#214). Until
`MAIDR_VERSION` reaches 4.9.0 a ROC curve therefore keeps the line
reading it had –
[`pROC::ggroc()`](https://rdrr.io/pkg/pROC/man/ggroc.html) and
yardstick's
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) in
particular, which are detected without any change on the author's side
and must not lose a chart they rendered yesterday. The moment the bundle
moves, the reading switches with no other change.

## Usage

``` r
roc_trace_available()
```

## Value

TRUE when the pinned bundle carries the trace
