# Custom knit_print Method for density Objects

Suppresses the default printing of density return values in RMarkdown.
The density() function is not patched (it's in stats, not graphics), so
we need this method to suppress its output.

## Usage

``` r
knit_print.density(x, options = list(), ...)
```

## Arguments

- x:

  A density object (from density())

- options:

  Chunk options from knitr

- ...:

  Additional arguments (ignored)

## Value

An invisible empty string
