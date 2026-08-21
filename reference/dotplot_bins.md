# Collapse a dot stack into the bins it counts

A Wilkinson dot plot is a histogram drawn one dot per observation: the
values are binned, and each bin's dots are stacked so the stack's height
*is* the bin's count.
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
says so directly – it returns one row per observation carrying that
observation's bin centre, the bin width, and the bin's count – so the
histogram is read off rather than reconstructed:

## Usage

``` r
dotplot_bins(built_data, horizontal = FALSE)
```

## Arguments

- built_data:

  A layer's computed data, carrying the bin centre on `x` or `y` plus
  `binwidth` and `count`

- horizontal:

  `TRUE` when the bins run up the y axis

## Value

A list of bins, each with `centre`, `half` and `count`, ascending; empty
when the layer drew nothing readable

## Details


       y x binwidth count countidx
    1  0 1        1     3        1
    2  0 1        1     3        2
    3  0 1        1     3        3
    4  0 2        1     2        1

Three rows for the bin at 1, each saying `count = 3`. Collapsing on the
centre gives four bins of 3, 2, 1 and 4.

The count is taken from the `count` column rather than by counting rows.
Measured, the two agree everywhere ggplot2 will build a dot plot –
`aes(weight = w)` expands a bin to one row per weighted unit, and a
fractional weight is refused outright ("`weight` must be nonnegative
integers") – so this is not a correction, it is a preference for the
stat's own answer over a count of the rows that happen to represent it.

Bin bounds come from the centre and the width rather than from
`xmin`/`xmax`, which name the bin only in one of the two orientations:
measured, `binaxis = "y"` puts the panel's whole range in `ymin`/`ymax`
and the dot's own width in `xmin`/`xmax`, so neither pair is the bin
there.
