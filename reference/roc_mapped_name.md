# The name an aesthetic is mapped to, as the ROC vocabulary would spell it

[`rlang::as_label()`](https://rlang.r-lib.org/reference/as_label.html)
renders `aes(x = specificity)` as `specificity`,
`aes(x = 1 - specificity)` as `1 - specificity`, and the
`.data[["1-specificity"]]` that
[`pROC::ggroc()`](https://rdrr.io/pkg/pROC/man/ggroc.html) writes as
`.data[["1-specificity"]]`. Stripping the pronoun and the whitespace
makes the three spellings of one rate compare equal.

## Usage

``` r
roc_mapped_name(mapping, aesthetic)
```

## Arguments

- mapping:

  An aesthetic mapping, or NULL

- aesthetic:

  Which aesthetic to read

## Value

The normalised name, or NULL when nothing is mapped
