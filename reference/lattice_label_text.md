# The text a lattice label is drawn with

A re-implementation of lattice's `getLabelList()`: `NULL` draws nothing;
a character vector, expression, call or symbol is the label; a list
whose first element is unnamed takes that element, and a `label =`
element overrides it; anything else – `TRUE`, `list(cex = 2)` – draws
the default. A grob draws itself, and is read when it is a text grob.

## Usage

``` r
lattice_label_text(label, default = NULL)
```

## Arguments

- label:

  A `main`, `sub`, `xlab` or `ylab` field

- default:

  The label lattice draws in place of `TRUE`

## Value

A string, or `NULL` when nothing would be drawn.

## Details

A label taken out of a list is drawn whatever it is, so a number there
reads as the number grid prints – `list(2024, cex = 2)` draws "2024" –
where a bare number, `main = 2024`, is not a label and draws the
default.
