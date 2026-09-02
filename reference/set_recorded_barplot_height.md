# Write a `height` back into a recorded `barplot()` call

The counterpart of
[`recorded_barplot_height()`](https://r.maidr.ai/reference/recorded_barplot_height.md):
the value goes back into the slot it was read from, named or positional.

## Usage

``` r
set_recorded_barplot_height(args, height)
```

## Arguments

- args:

  Recorded argument list

- height:

  The replacement height

## Value

The argument list with `height` replaced
