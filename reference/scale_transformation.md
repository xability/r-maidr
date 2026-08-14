# Read a ggplot2 scale's transformation

ggplot2 3.5 renamed the accessor; the field it reads is the same one.
Returns NULL when the scale carries no transformation at all, which is
the case for a discrete scale.

## Usage

``` r
scale_transformation(scale)
```

## Arguments

- scale:

  A panel scale from `built$layout$panel_scales_x` or `panel_scales_y`

## Value

The transformation object, or NULL
