# The titles written in the margins of each plot, by the axis they title

A title written after a plot, with
[`title()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
[`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md), is drawn
in a margin, and titles the axis drawn on that side of it:
`title(xlab =)` is drawn on side 1, `title(ylab =)` on side 2, and
[`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) on the side
it is given. A chart of two y axes draws its second series over the
first, with `par(new = TRUE)` and `axes = FALSE`, gives it an axis of
its own on the right with `axis(4)`, and often writes every title after
it: `mtext("Squares", side = 2)` for the first series' axis and
`mtext("Roots", side = 4)` for the second's. Read on the plot each was
written after, the second series was titled "Squares", after the axis of
the first, and the first had no title at all.

## Usage

``` r
margin_titles(groups, layout_calls)
```

## Arguments

- groups:

  The plot groups, from
  [`group_device_calls()`](https://r.maidr.ai/reference/group_device_calls.md)

- layout_calls:

  The recorded LAYOUT calls, from
  [`group_device_calls()`](https://r.maidr.ai/reference/group_device_calls.md)

## Value

One list per group: the titles written on its axes, in the order they
were written. Each is a list with the `axis` it titles, `"x"` or `"y"`,
the `side` it is drawn on, its `text`, its `kind`, `"title"` or
`"mtext"`, and the `line` it is written on.

## Details

So each title goes to the plots, of those drawn over one another
(`overlay_runs()`) in the plot R draws it on
([`plot_drawn_on()`](https://r.maidr.ai/reference/plot_drawn_on.md)),
whose axis is drawn on its side
([`axis_sides()`](https://r.maidr.ai/reference/axis_sides.md)), and
nearest it where several are
([`nearest_axes()`](https://r.maidr.ai/reference/nearest_axes.md)), and
to each chart drawn onto them with `add = TRUE`, as
`contour(add = TRUE)` draws onto an
[`image()`](https://r.maidr.ai/reference/base-r-wrappers.md). A plot
placed beside another or inset in it, with `par(fig = , new = TRUE)`, is
drawn in a plot region of its own, not over the other, and the titles
written after it are its own. Where none of them draws an axis on the
bottom or the left, a title there titles the plot R draws it on, as
`plot(x, y, axes = FALSE); title(xlab = "Time")` does; on the top or the
right, it titles none. Either one in the outer margin (`outer = TRUE`)
titles the page rather than a plot, and is not read.
