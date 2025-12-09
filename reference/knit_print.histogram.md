# Custom knit_print Method for histogram Objects

Suppresses the default printing of histogram return values in RMarkdown.
The plot is already rendered via the plot hook; this prevents the
histogram object structure from being printed as text output.

## Usage

``` r
knit_print.histogram(x, options = list(), ...)
```

## Arguments

- x:

  A histogram object (from hist())

- options:

  Chunk options from knitr

- ...:

  Additional arguments (ignored)

## Value

An invisible empty string
