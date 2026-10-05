# The y title R draws beside the series maidr reads of several time series

[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of several
time series draws them a panel each
([`plot.ts()`](https://rdrr.io/r/stats/plot.ts.html)'s
`plot.type = "multiple"`, its default), titles each panel after its
series, and draws no `ylab`, whatever it is given. maidr reads only the
first series, which is what
[`grDevices::xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html)
makes of them, so its y title is that series' name, the one R draws
beside it, rather than a `ylab` R never drew:
`plot(cbind(mdeaths, fdeaths), ylab = c("Male", "Female"))` is titled
"mdeaths".

## Usage

``` r
plot_ts_panel_title(plot_call)
```

## Arguments

- plot_call:

  A recorded call

## Value

The first series' name, or NULL when the call is not a
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of several
time series a panel each
