# The page a Base R chart too small for a size no one asked for is drawn on

Before maidr drew a Base R chart at its size it laid every one out on
the 7 x 7 in page
[`ggplotify::as.grob()`](https://rdrr.io/pkg/ggplotify/man/as-grob.html)
draws on (see
[`base_r_drawing_grob()`](https://r.maidr.ai/reference/base_r_drawing_grob.md)),
so a chart too tall for maidr's own 7 x 5 in – a `par(mfrow)` grid of
five rows – was drawn. Such a chart still is, on that page, or on one as
large as the canvas on a side where the canvas is larger. A chart too
large for that page as well, as a grid of six rows is, is drawn on the
smallest page larger than the canvas that gives each of its plots at
least a sixth of an inch, 12 px, each way: about what a five-row grid's
plots have on the 7 x 7 in page, and enough to be seen, where the least
R draws on leaves a plot a pixel high. Each side is the canvas's own or
a whole number of inches: it grows an inch at a time to the least that
gives the plots their room while the other side has all it could want,
and then both together for as long as the chart still does not fit, as a
layout that keeps its panels' shape (`respect = TRUE`) may need. A chart
no page gives that room, a grid of forty rows, is drawn on the smallest
page R draws it on.

## Usage

``` r
base_r_page_that_fits(draw, size)
```

## Arguments

- draw:

  A function of no arguments that draws the chart

- size:

  The canvas it is too small for, from
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

## Value

The page, a named numeric vector, `width` and `height`, in inches

## Details

Called once the chart has failed for its size, with a
`maidr_chart_draw_error`: it then fits the largest page a chart is drawn
on,
[MAIDR_MAX_CHART_SIZE](https://r.maidr.ai/reference/MAIDR_MAX_CHART_SIZE.md)
on each side, which is as large as this grows the page.
