# Whether the maidr.js a widget loads reads ECharts' `percentileBands`

The option shipped in the ECharts adapter after maidr.js 4.14.0, the
version bundled with this package. An older maidr.js ignores an option
it does not know, so emitting it would do no harm, but nothing would be
read either and the author would never learn why; the option is
therefore dropped with a warning on the R side instead, as the
`*_trace_available()` checks drop a trace the bundle cannot build. The
moment the bundle, or the CDN version, reaches the release that carries
it, the option goes through.

## Usage

``` r
echarts_percentile_bands_available(use_cdn = FALSE)
```

## Arguments

- use_cdn:

  Logical, as in
  [`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md).

## Value

TRUE when the loaded maidr.js reads the option
