# Sum a table over the variables a formula names

The branch `mosaicplot.formula()` takes when `data` is already a table:
the formula selects which margins to keep, and `~ .` keeps all of them.

## Usage

``` r
formula_margin_table(formula, data)
```

## Arguments

- formula:

  The recorded formula

- data:

  The recorded table

## Value

A table, or NULL
