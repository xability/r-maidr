# One line of a strip, as text

A labeller gives each line as a vector over the panels, of text or, from
`label_parsed` and `label_bquote`, of expressions; an expression is
written out as R would print it.

## Usage

``` r
strip_label_text(line, row)
```

## Arguments

- line:

  One element of a labeller's result

- row:

  The panel's row of the facet's layout

## Value

A string, or NA when the line has none for the panel
