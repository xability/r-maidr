# Map a Base R `type` argument onto a MAIDR step direction

`type = "s"` draws the horizontal segment first, which is MAIDR's
`"hv"`; `type = "S"` draws the vertical segment first, which is `"vh"`.
Any other value returns NULL so the caller can omit `stepDirection`
rather than assert a convention the call never asked for.

## Usage

``` r
base_r_step_direction(plot_type)
```

## Arguments

- plot_type:

  The `type` argument recorded from the plot call.

## Value

`"hv"`, `"vh"`, or NULL.
