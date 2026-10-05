# The layer a drawing by `curve()` is read as

Shared by [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md)
and by [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
function, which
[`graphics::plot.function()`](https://rdrr.io/r/graphics/curve.html)
draws by calling
[`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md): one
drawing, so one reading. See the `curve` branch of `detect_layer_type()`
for why only an unadded polyline is read.

## Usage

``` r
curve_layer_type(args)
```

## Arguments

- args:

  The arguments recorded from the call.

## Value

`"line"`, or `"unknown"` for an overlay (`add = TRUE`) or a draw type
other than `"l"` and `"o"`.
