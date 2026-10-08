# Warn about fan series the echarts4r widget does not draw

maidr.js reports a series it cannot find in the browser console, where
an R author is unlikely to look, so a name that matches none of the
widget's series names or ids is said here too. Only a widget whose
series are in its options (`x$opts$series`) is checked; a name may still
match a series added later, as a Shiny proxy adds them, so this warns
rather than stops.

## Usage

``` r
warn_unknown_echarts_series(widget, fans)
```

## Arguments

- widget:

  The echarts4r widget

- fans:

  Fans from
  [`validate_percentile_bands()`](https://r.maidr.ai/reference/validate_percentile_bands.md)

## Value

NULL, invisibly
