# Split a lattice grob name into what it is and where it was drawn

Split a lattice grob name into what it is and where it was drawn

## Usage

``` r
lattice_parse_grob_name(name, prefix = LATTICE_PREFIX)
```

## Arguments

- name:

  Grob names

- prefix:

  The grob-name prefix

## Value

A data frame with `what`, `group`, `column` and `row`; `what` is `NA`
for a name that is not a lattice panel grob.
