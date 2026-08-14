# Put built positions back into the space the reader sees

ggplot2 applies a scale transformation *before* the stat runs, so
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)'s
data is in transformed space. Read straight through, a
[`scale_x_log10()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html)
chart announces log10 coordinates under the original axis label: a
scatter of prices from \$5.50 to \$9,403 reads as 0.744 to 3.973 under
"Price (USD)" (#158).

## Usage

``` r
untransform_positions(values, built, axis = "x", panel_id = NULL)
```

## Arguments

- values:

  Positions read from the built data

- built:

  Built plot from
  [`ggplot2::ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)

- axis:

  `"x"` or `"y"`

- panel_id:

  Panel index for faceted plots, or NULL for the first

## Value

The values in data space, unchanged when there is nothing to undo

## Details

Nothing is missing from such a chart and nothing errors. The structure
is right, the point count is right, the label is right, and the numbers
are false – with no signal a reader could catch, since "these look
small" is not checkable without the chart you cannot see.

[`coord_trans()`](https://ggplot2.tidyverse.org/reference/coord_transform.html)
needs no special case and deliberately gets none. It transforms at draw
time, after the stat, so its built data is already in data space *and*
its scale reports `identity` – the same comparison that skips an
untransformed chart skips it too. Testing for "is there a log axis"
would have inverted it wrongly.

Applied at the point a value is emitted rather than to the frame as a
whole, and that placement is load-bearing: `scale_*_reverse()` negates,
so a frame inverted before a sort would order rows opposite to the way
they were drawn, and selectors indexed by that order would land on the
wrong element. Ordering follows the drawn scale; only the announced
number is put back.
