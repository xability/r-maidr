# Rows of a layer's own data that belong to one facet panel

The obvious `values == group` is wrong the moment the facet column holds
an `NA`: `==` answers `NA` for that row, and `[` turns an `NA` index
into a fabricated all-`NA` row. One missing facet value therefore
injects junk rows into EVERY panel's subset, not only the panel the `NA`
belongs to.

## Usage

``` r
facet_group_rows(values, group)
```

## Arguments

- values:

  The facet column of the layer's data

- group:

  The panel's own facet group, possibly `NA`

## Value

A logical vector, one element per row, never `NA`

## Details

`NA` is a panel, not an absence. ggplot2 lays out a real panel for it
and draws "NA" on its strip, so the matching rows have to be selected
for that panel rather than dropped everywhere. `%in%` handles the
ordinary levels (it scores an `NA` value as `FALSE` instead of `NA`),
and [`is.na()`](https://rdrr.io/r/base/NA.html) picks out the `NA`
panel's own rows. A facet column that literally contains the string "NA"
stays distinct from a missing value:
[`as.character()`](https://rdrr.io/r/base/character.html) leaves the
former as `"NA"` and the latter as `NA_character_`.
