# The frame round a Base R panel, as a selector

[`box()`](https://rdrr.io/r/graphics/box.html), which
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draw by
default, outlines the plot region, and gridGraphics names it
`graphics-plot-<n>-box-<k>`. Named as a subplot's own `selector`, it is
what the frontend outlines in the lobby of a figure of several panels,
as lattice's panel borders are. A panel with no frame of its own was
outlined round the one element holding all of its marks, where there was
one: a bar chart's bars are one grob, but a box plot's boxes, whiskers
and outliers are several, and nothing on the page held them and no other
panel's marks, so its panel had no outline.

## Usage

``` r
base_r_panel_frame(page, plot_number)
```

## Arguments

- page:

  The page's drawing
  ([`base_r_drawing_grob()`](https://r.maidr.ai/reference/base_r_drawing_grob.md))

- plot_number:

  The panel's plot number on the page, which names its grobs

## Value

A selector for the group of the first frame drawn, or NULL where the
panel drew none
