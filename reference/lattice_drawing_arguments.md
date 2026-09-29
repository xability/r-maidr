# The arguments a trellis object is drawn with

A chart can carry its place on a shared page in its `plot.args`, set by
`xyplot(plot.args = )` or
[`update()`](https://rdrr.io/r/stats/update.html). `plot.trellis()`
takes an argument from there only by its exact name and only when the
call did not give it, so they are added after the call's own are
matched, never matched by place or partial name themselves.

## Usage

``` r
lattice_drawing_arguments(args, stored = NULL)
```

## Arguments

- args:

  The arguments [`print()`](https://rdrr.io/r/base/print.html) or
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) was given
  besides the object.

- stored:

  The object's `plot.args`.

## Value

The arguments named as `plot.trellis()` draws with them, or `NULL` when
the call's own do not match it at all.
