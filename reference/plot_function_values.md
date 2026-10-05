# Keep the points `plot()` drew a function at

`plot(f)` dispatches to
[`graphics::plot.function()`](https://rdrr.io/r/graphics/curve.html),
which draws `f` by calling
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md). That call
is made from inside graphics, where the
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) wrapper
never sees it, so only the
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call is
recorded, and its first argument is the function rather than any
coordinates. Read as the data of a scatter, `plot(sin, -pi, pi)` stopped
the save with "object of type 'builtin' is not subsettable", and
`plot(sin)` was announced as a scatter with no points.

## Usage

``` r
plot_function_values(target, args, arg_text, written, value)
```

## Arguments

- target:

  [`graphics::plot.function()`](https://rdrr.io/r/graphics/curve.html),
  which the call dispatched to

- args:

  Recorded argument list, as
  [`match_recorded_args()`](https://r.maidr.ai/reference/match_recorded_args.md)
  names it

- arg_text:

  The text each argument was written as, from
  [`written_arg_text()`](https://r.maidr.ai/reference/written_arg_text.md)

- written:

  The expressions the arguments were written as

- value:

  The value [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  returned

## Value

List with `args` and `arg_text`. When `value` is what
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) returns,
`args` holds the function that returns its y values in place of the one
plotted, R's y title as `ylab` when no symbol can carry it, and the
points under `.maidr_curve_data` when they can be read.

## Details

[`plot.function()`](https://rdrr.io/r/graphics/curve.html) returns what
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) returned,
the x and y it drew, so they are kept as the
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) wrapper
keeps its own
([`curve_recorded_values()`](https://r.maidr.ai/reference/curve_recorded_values.md)),
and `detect_layer_type()` reads the call as it reads
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md). Values
that wrapper cannot read as numbers, such as dates, are not kept, and
the call is shown as a picture of the chart.

The replay that draws maidr's chart, or that picture, is given, in place
of the function, one that returns the y values R drew
([`drawn_values_function()`](https://r.maidr.ai/reference/drawn_values_function.md)):
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) evaluates
it at the x it drew at, so maidr draws what R drew and what is
announced. Called again, the function itself would be evaluated against
whatever its free variables hold by then: after
`for (k in 1:2) plot(function(x) sin(k * x), 0, pi)` both panels were
drawn as `sin(2 * x)`, and once `k` was removed the chart was drawn
blank. Left in the recorded call, a function of dates was read as the
points of a scatter, which stopped the save with "object of type
'closure' is not subsettable".

The axis titles are
[`plot.function()`](https://rdrr.io/r/graphics/curve.html)'s. The x axis
is `xname`, which it hands on to
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md). The y axis
is the first line of the function as written,
`deparse(substitute(x))[1L]`: "sin" for `plot(sin)`, where `curve(sin)`
writes "sin(x)". The replay passes the function under a symbol named by
its `arg_text` entry, so that entry is set to the same first line: a
function written over several lines is titled as R titled it, in the
drawing and in the data, and so is one handed over as a value, as
[`do.call()`](https://rdrr.io/r/base/do.call.html) does. A title no
symbol can carry, "..1" for `plot(..1)` in a function of `...`, is
handed to the replay as its `ylab` instead: passed as a value, the
stand-in was drawn titled "function (x)". Neither title is announced
where R draws none
([`drawn_default_titles()`](https://r.maidr.ai/reference/drawn_default_titles.md)),
as with `ylab = ""`, `ann = FALSE` or `par(ann = FALSE)`, which is read
here, on the device R drew on.
