# Disable MAIDR Plot Interception

Disables automatic MAIDR rendering and restores normal plot behavior.
After calling this, Base R plots display in the standard graphics
window, ggplot2 objects render with the default ggplot2 method, and
lattice charts print as lattice draws them:
`lattice.options(print.function = )` is set back to what it was before
maidr set it.

## Usage

``` r
maidr_off()
```

## Value

Invisible TRUE on success

## See also

[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) to enable MAIDR
rendering
