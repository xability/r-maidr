# Disable MAIDR Plot Interception

Disables automatic MAIDR rendering and restores normal plot behavior.
After calling this, Base R plots display in the standard graphics
window, ggplot2 objects render with the default ggplot2 method, and
lattice charts print as lattice draws them:
`lattice.options(print.function = )` is set back to what it was before
maidr set it. In an R Markdown or Quarto document, the chunks after it
are knitted as they would be without maidr, and maidr's knitr hooks are
taken out until
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md).

## Usage

``` r
maidr_off()
```

## Value

Invisible TRUE on success

## Details

It lasts for the R session, not only the document that calls it: the
documents rendered after it in the same session – the later vignettes of
`R CMD build`, which renders them all in one process – and the console
stay off too. A document that turns maidr off should end with
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md).

## See also

[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) to enable MAIDR
rendering
