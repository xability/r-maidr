# knitr Plot Hook for Base R Plots

Intercepts Base R plot output and converts to MAIDR iframe. Uses
iframe-based isolation to ensure each plot has its own MAIDR.js context.
Automatically falls back to image rendering for unsupported plot types
or non-HTML output formats (PDF, EPUB). This replaces knitr's default
plot hook when maidr_on() is called.

## Usage

``` r
maidr_plot_hook(x, options)
```

## Arguments

- x:

  The plot file path from knitr

- options:

  Chunk options

## Value

HTML string for the plot
