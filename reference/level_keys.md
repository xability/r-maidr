# Key aesthetic values so a missing one stays distinct from the string "NA"

[`paste()`](https://rdrr.io/r/base/paste.html) stringifies `NA` to "NA",
which collapses a missing value onto a level that is literally those two
characters – so a grid keyed that way cannot tell the two apart, and a
duplicate test built on it does not see the collision. Every present
value is prefixed with "=", so the missing key is one nothing else can
produce.

## Usage

``` r
level_keys(values)
```

## Arguments

- values:

  A vector of aesthetic values

## Value

Character vector of keys, one per value, never `NA`

## Details

The missing key is a non-empty string on purpose. `""` would read as the
obvious sentinel and is a trap: R lets `"" %in% names(x)` answer TRUE
and then throws "subscript out of bounds" on `x[[""]]`, because empty is
how a name-less element is spelled. A lookup guarded by `%in%` – which
is how both bar processors read their cells – would pass the guard and
abort.
