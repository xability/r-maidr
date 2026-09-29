# Draw a trellis object the way lattice would without MAIDR

With the print function lattice's
[`print()`](https://rdrr.io/r/base/print.html) would call if MAIDR had
not set its own – the one set now, or while MAIDR's is set, the one set
before it – or with `plot.trellis()`, lattice's own drawer, when there
is none. Never with [`print()`](https://rdrr.io/r/base/print.html),
which would come back through the hook, and never with a bare
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md): inside this
namespace that is MAIDR's recording wrapper for Base R's
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md).

## Usage

``` r
print_trellis_natively(x, ...)
```

## Arguments

- x:

  A trellis object

- ...:

  Passed to the drawing function

## Value

`x`, invisibly

## Details

The option is read each time rather than the function stored when MAIDR
set its hook: after
[`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) that function
is only a record of what was set once, and the user may have set another
since.
