# The Suggests packages whose S4 `plot()` generic masks maidr's wrapper

ROCR exports an S4 generic for
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
(`exportMethods(plot)` in its NAMESPACE, ROCR 1.0.11) so that
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
`performance` object draws its curve. Attached after maidr, that generic
sits ahead of maidr's
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) wrapper on
the search path, and every bare
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) – of a
`performance` object or of anything else, since the generic's default is
base [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) – goes
around the wrapper unrecorded. Measured:
`library(maidr); library(ROCR); plot(1:10); save_html()` stopped with
"No Base R plots detected". Attached before maidr, maidr's wrapper is
found first and hands a `performance` object on to the S3 method ROCR
also registers (`S3method(plot, performance)`), so the call is recorded.

## Usage

``` r
PLOT_MASKING_SUGGESTS
```

## Details

Named by package, valued by the function it masks, as
[WRAPPED_SUGGESTS](https://r.maidr.ai/reference/WRAPPED_SUGGESTS.md) is;
maidr wraps nothing of these packages, so they are kept apart from it.
