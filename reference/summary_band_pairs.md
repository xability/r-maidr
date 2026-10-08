# The `median_hilow` ribbons of a plot and the median lines drawn on them

A `stat_summary(geom = "ribbon", fun.data = median_hilow)` layer is a
percentile band of one interval. Its median is computed by the stat but
not kept: `GeomRibbon` overwrites the built `y` with `ymin` when it sets
its data up. So the plot is built once more with each such ribbon drawn
as
[`geom_blank()`](https://ggplot2.tidyverse.org/reference/geom_blank.html),
which leaves the stat's rows as they were computed – after the scales'
transformations, as the drawn ribbon's are.

## Usage

``` r
summary_band_pairs(plot_object)
```

## Arguments

- plot_object:

  A ggplot object

## Value

A list of `rows` (a list, by layer index, of data frames of `x`, `y`
(the median), `ymin`, `ymax`, `.width` and `PANEL`) and `median_line`
(an integer vector naming each ribbon's line, NA for none), or NULL when
the plot has no such ribbon

## Details

A ribbon is kept only where it draws one series a panel along x (no
flipped orientation, no position adjustment, one row per panel and x).
Its median line is the one
[`stat_summary()`](https://ggplot2.tidyverse.org/reference/stat_summary.html)
median line whose built rows sit on the ribbon's medians at every x of
every panel, when exactly one does and that line sits on no other
ribbon; a line the two readings do not pin down stays a line of its own.
