# Custom knit_print Method for ggplot Objects

Converts ggplot objects to MAIDR widgets for accessible rendering in
RMarkdown. Uses iframe-based isolation to ensure each plot has its own
MAIDR.js context.

## Usage

``` r
knit_print.ggplot(x, options = list(), ...)
```

## Arguments

- x:

  A ggplot object

- options:

  Chunk options from knitr

- ...:

  Additional arguments (ignored)

## Value

A knit_asis object containing the iframe HTML
