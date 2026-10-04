# Whether a print of a trellis object composes a page

Places the chart on a page other charts share – `split`, `more = TRUE`,
`position`, `newpage = FALSE`, `draw.in`, by name, partial name or
place, or carried in the chart's `plot.args` – which is lattice's own
idiom for arranging several. A print lattice will refuse counts too: it
is lattice's to refuse, with its own error.

## Usage

``` r
lattice_print_composes(args, stored = NULL)
```

## Arguments

- args:

  The arguments [`print()`](https://rdrr.io/r/base/print.html) was given
  besides the object.

- stored:

  The object's `plot.args`.

## Value

`TRUE` for a print that composes a page, or that lattice refuses.
