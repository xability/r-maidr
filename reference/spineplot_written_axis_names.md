# Name a replayed `spineplot(x, y)`'s axes the way the caller's call did

`spineplot.default()` titles its axes `deparse1(substitute(x))` and
`deparse1(substitute(y))` when no `xlab`/`ylab` is given. Replayed
through [`do.call()`](https://rdrr.io/r/base/do.call.html) on the
recorded *values*, the substitute is the data itself, and a reader was
told the axis was called `c(1, 2, 3, ...)` for as many characters as the
vector took to write. The names the caller wrote are in the recorded
call text, so they are matched against the default method's formals and
passed as the titles. A table or a formula names its own axes and is
left alone.

## Usage

``` r
spineplot_written_axis_names(args, call_expr)
```

## Arguments

- args:

  Recorded argument list

- call_expr:

  The recorded call, deparsed

## Value

`args`, with `xlab`/`ylab` filled in where the call named them
