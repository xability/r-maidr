# Where lattice keeps its record of the chart it drew last

lattice's own environment, which it does not export. Read in one place,
so that
[`lattice_keep_status()`](https://r.maidr.ai/reference/lattice_keep_status.md)
and
[`lattice_page_open()`](https://r.maidr.ai/reference/lattice_page_open.md)
find it, or find it gone, the same way.

## Usage

``` r
lattice_status_env()
```

## Value

The environment, or `NULL` should lattice no longer have it.
