# The largest a chart is drawn, on either side, in inches

As
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
refuses a larger size: one given in pixels by mistake –
[`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md) and the
widget take pixels – would draw a chart hundreds of inches across, which
nobody who cannot see it would notice.

## Usage

``` r
MAIDR_MAX_CHART_SIZE
```
