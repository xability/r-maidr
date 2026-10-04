# The axis titles a Base R call writes after how its arguments were written

`hist(x)` titles its x axis after how `x` was written, `qqplot(x, y)`
both its axes, and `plot(x, y)` whatever
[`xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html) makes of the
two: `plot(v)` is titled "Index" against `v`, and a matrix by its column
names. The recorded call keeps that text
([`written_arg_text()`](https://r.maidr.ai/reference/written_arg_text.md)),
so these are the titles R drew rather than a guess at them, and an axis
is named in the data as it is in the picture.

## Usage

``` r
written_axis_titles(plot_call)
```

## Arguments

- plot_call:

  A recorded call

## Value

List with `x` and `y`, each NULL when the call writes no such title

## Details

[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is read only
when it reached
[`plot.default()`](https://rdrr.io/r/graphics/plot.default.html); a
method of a class titles its axes its own way.
