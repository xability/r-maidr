# The sides a plot draws its axes on

A plot draws its x axis on side 1 and its y axis on side 2, unless the
call turns them off, with `axes = FALSE`, `xaxt = "n"` or `yaxt = "n"`.
[`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws one on
the side it is given. A chart drawn onto the plot with `add = TRUE`
draws none of its own, and an
[`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) written
after it is drawn against the plot's axes.

## Usage

``` r
axis_sides(groups)
```

## Arguments

- groups:

  The plot group that drew the plot, from
  [`group_device_calls()`](https://r.maidr.ai/reference/group_device_calls.md),
  and those drawn onto it (`shared_plots()`)

## Value

List with `x`, 1 or 3, and `y`, 2 or 4: the side the axis is drawn on,
the bottom or the left where it is drawn on both; NA where it is drawn
on neither. Its `lines` hold, for `x` and `y`, the margin lines the axes
on that side are drawn on: 0, the edge of the plot, for the plot's own,
and the `line` an
[`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) call is
given.
