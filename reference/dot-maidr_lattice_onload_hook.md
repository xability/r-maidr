# Set MAIDR's lattice print hook when lattice's namespace loads

Named rather than anonymous so `.onUnload()` can remove exactly this
hook. After [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md)
it sets nothing, and
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) sets it later.
The options are not read here but at every print (see
[`lattice_print_opens_viewer()`](https://r.maidr.ai/reference/lattice_print_opens_viewer.md)),
as ggplot2's and Base R's are: read here, a `maidr.lattice` or
`maidr.auto_show` that was `FALSE` when lattice loaded – from an
`.Rprofile`, or before a package that imports lattice loaded it – would
keep lattice out of the viewer after it was set back to `TRUE`.

## Usage

``` r
.maidr_lattice_onload_hook(...)
```

## Arguments

- ...:

  Ignored; passed by
  [`setHook()`](https://rdrr.io/r/base/userhooks.html).

## Value

NULL (invisible)
