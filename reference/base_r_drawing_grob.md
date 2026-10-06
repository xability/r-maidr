# A Base R drawing as a grob, laid out on a page of the chart's size

What
[`ggplotify::as.grob()`](https://rdrr.io/pkg/ggplotify/man/as-grob.html)
makes of a drawing function – the base graphics echoed as grid grobs by
gridGraphics, drawn with the graphical parameters it sets (`xpd = NA`, a
transparent background, axis titles two lines out) – with the page the
drawing is made on sized as the chart's canvas. `as.grob()` makes every
drawing on a 7 x 7 in page of its own, whatever device is open, and the
echo keeps what base graphics laid out on that page: margins, the lines
of text around a plot and a legend's box are fixed in inches. Drawn on a
canvas of another shape they no longer fit – measured at 4 x 3 in, the
title was cut off at the top of the SVG, the axis titles were lost and a
legend's text ran out of its box, and even maidr's own 7 x 5 in squeezed
a legend's lines together. Made on a page of the canvas's size, the
drawing is the one R draws at that size.

## Usage

``` r
base_r_drawing_grob(draw, size, cells_in_cm = FALSE)
```

## Arguments

- draw:

  A function of no arguments that draws the chart

- size:

  The chart's canvas, from
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- cells_in_cm:

  Whether the chart's own
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
  sizes cells with [`lcm()`](https://rdrr.io/r/graphics/layout.html),
  which the error then names when they do not fit

## Value

A gTree

## Details

The grob names, which every selector is written against, are those
`as.grob()` gives. The drawing is recorded and echoed with its titles,
margin texts and axis labels as R drew them
(`base_r_echoable_recording()`), and keeps only the tick labels R draws
([`thin_axis_labels()`](https://r.maidr.ai/reference/thin_axis_labels.md)).
A drawing gridGraphics cannot echo stops, with an error of class
`maidr_chart_echo_error` giving gridGraphics' reason. `as.grob()` grabs
such a drawing as drawn instead, which for Base R graphics is an empty
drawing, and maidr exported that without a word.

A chart too small to draw stops, with an error of class
`maidr_chart_draw_error` that names the size and R's reason. Base R
gives a chart's margins and text the same room in inches on any page, so
a page too small for them – 6 x 1.5 in for a
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md), 4 x 3 in
for a 2 x 2 `par(mfrow)` – leaves the plot none and R stops with "figure
margins too large". The cells a
[`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) call sizes
with [`lcm()`](https://rdrr.io/r/graphics/layout.html) keep their size
on any page too, and R stops with "figure region too large" on a page
smaller than they are. The device the author drew on may have had the
room, and maidr draws the chart again at a size of its own. An empty
chart in its place would not say so, and a picture is drawn at the same
size, so neither is made. A drawing is taken to have failed for its size
when it fits the largest page a chart is drawn on,
[MAIDR_MAX_CHART_SIZE](https://r.maidr.ai/reference/MAIDR_MAX_CHART_SIZE.md)
on each side; any other failure is raised as R raised it, for the caller
to handle as before. A size no one asked for is the orchestrator's to
enlarge
([`base_r_page_that_fits()`](https://r.maidr.ai/reference/base_r_page_that_fits.md)).
