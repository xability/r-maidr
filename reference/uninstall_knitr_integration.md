# Take maidr's knitr integration out of the running knit

Called by [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md),
and by maidr's `document` hook once the knit is done. Puts back each
hook maidr installed over, and removes the marker, so a later
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) in the same
document installs them again. A hook of the document's own set over
maidr's is left alone; maidr's hook under it acts as the one it replaced
once interception is off. Outside a knit it removes what a knit that
stopped with an error left behind.

## Usage

``` r
uninstall_knitr_integration()
```

## Value

NULL (invisible)
