# The title, subtitle and caption of a patchwork composition

`plot_annotation()` keeps them on the composition, in
`patches$annotation`, and patchwork draws them over and under all its
plots. Only the outermost composition's are drawn: those of a
composition nested in it are not. A composition's `labels` are those of
the plot added last, whose title is drawn over that plot alone.

## Usage

``` r
patchwork_annotation_text(plot)
```

## Arguments

- plot:

  A patchwork composition

## Value

A list of `title`, `subtitle` and `caption`, each one non-empty string
or NULL
