# Which of several axes on one side a title is written beside

A chart of three series can draw two y axes on the right, one at the
edge of the plot with `axis(4)` and one farther out with
`axis(4, line = 3.5)`, each titled with
[`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) on a line
just outside it. A title is written beside the axis nearest it of those
drawn inside its line, or, where none is, the innermost.

## Usage

``` r
nearest_axes(owners, sides, title)
```

## Arguments

- owners:

  The plots whose axis is drawn on the title's side

- sides:

  Each plot's axes, from
  [`axis_sides()`](https://r.maidr.ai/reference/axis_sides.md)

- title:

  The title, from
  [`titles_written()`](https://r.maidr.ai/reference/titles_written.md)

## Value

Those of `owners` whose axis on that side the title is written beside
