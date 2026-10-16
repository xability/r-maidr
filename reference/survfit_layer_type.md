# The layer type of `plot()` of a `survfit` object

Read (`"survival"`) when the plot draws Kaplan-Meier survival curves
from the object's own estimates. Declined (`"unknown"`, so the chart is
shown as a picture) when it draws something else:

## Usage

``` r
survfit_layer_type(args)
```

## Arguments

- args:

  The recorded arguments of the
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call

## Value

`"survival"` or `"unknown"`

## Details

- `fun` or `cumhaz` transforms the estimate (cumulative hazard, events,
  log-log), so the curve is no longer a survival probability;

- a multi-state (`survfitms`) or multi-column fit – several curves per
  stratum, as `survfit()` of a Cox model over several new subjects is;

- `conf.int = "only"` draws the band without the curve, and a numeric
  `conf.int` other than the fit's own level draws bounds the object does
  not hold;

- `conf.times` draws the band as error bars at chosen times;

- a band asked for of a fit that kept no bounds (`conf.type = "none"`).
