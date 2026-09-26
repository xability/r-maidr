# The dependency carrying a MAIDR chart-library adapter

The adapters are UMD bundles published beside `maidr.js` –
`highcharts.js` defines `window.maidrHighcharts`, `echarts.js` defines
`window.maidrECharts` – and are bundled in the same directory, so the
local and CDN copies are always the same release as the core they run
against. Only the adapter's own file is declared (`all_files = FALSE`):
the directory also holds the multi-megabyte core, which the `maidr`
dependency already copies.

## Usage

``` r
maidr_adapter_dependency(adapter, use_cdn = FALSE)
```

## Arguments

- adapter:

  `"highcharts"` or `"echarts"`.

- use_cdn:

  Logical, as in
  [`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md).

## Value

A single htmltools::htmlDependency()
